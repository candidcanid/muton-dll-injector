class Instance extends Object dependsOn(
    Symbols,
    DataStructures,
    ReadWritePrimitive
);

struct ModifiedUFunc {
    var Address Addr;
    var int SavedFlagsLow, SavedFlagsHigh;
    var Address PtrNativeFunc;
};

struct NativeExecShim {
    var string CxxSymbol;
    var array<string> CxxArgs;
    var array<string> UScriptArgs;
    var string UScriptRetVal;
    var int VtableOffset;
    var Address LoadAddr;
    var name UFuncName;
};

// cxx: struct FUniqueNetId { QWORD Uid; };
struct UnpackedUniqueNetId {
    //  used by 32bit shim 'FourArgShim',
    //  to confuse a QWORD into two DWORD arguments in a __thiscall
    var int LowUid;
    var int HighUid;
};

var bool IsInitialised;
var NativeExecShim ZeroArgShim;
var NativeExecShim OneArgShim;
var NativeExecShim TwoArgShim;
var NativeExecShim ThreeArgShim;
var NativeExecShim FourArgShim;
// TODO: this could possibly be handled more elegantly with a define?
// used for keeping track of UFunction's to clean up
var ModifiedUFunc ActiveUFuncs[5];

var ReadWritePrimitive Prim;
// address of 'this/self' in memory
var Address SelfAddr;
var array<int> FakeVtable;
var Address FakeFtableDataAddr;

var Address SelfUClassAddr;
var Address SelfUClassFuncMapDataAddr;
var int SelfUClassFuncMapLen;

var Address UObjectVftAddr;
var Address SharedLibSlide;

function bool Init() {
    local int Idx;
    Prim = new Class'ReadWritePrimitive';
    if(Prim.Init() != True) {
        return False;
    }

    SelfAddr = Prim.LeakObjectAddress(Self);
    `log("Instance:SelfAddr=" $ `UTIL.FormatAddr(SelfAddr));
    SelfUClassAddr = Prim.LeakObjectAddress(Self.Class);
    `log("[i] SelfUClassAddr: " $ `UTIL.FormatAddr(SelfUClassAddr));
    // read vtable for Prim (vft__UObject)
    UObjectVftAddr = Prim.ReadAddress(SelfAddr, 0x0);
    `log("[i] UObjectVftAddr = " $ `UTIL.FormatAddr(UObjectVftAddr));
    // since vft__UObject resides in XComEW:__data, we can use it to calc any active ASLR slide
    SharedLibSlide = `UTIL.Address_SubAddr(UObjectVftAddr, `LDR.UObjectVft);
    `log("[i] SharedLibSlide = " $ `UTIL.FormatAddr(SharedLibSlide) $ " (using vft__UObject " $ `UTIL.FormatAddr(`LDR.UObjectVft) $ ")");

    // make sure FakeVtable has a buffer of ~0x800 bytes
    //  to prevent TArray<...>.Data realloc making .Data pointer stale
    FakeVtable.Insert(0x0, 0x800 / 0x4);
    FakeFtableDataAddr.Low = Prim.LeakIntArray(FakeVtable).Data;
    `log("[i] FakeFtableDataAddr = " $ `UTIL.FormatAddr(FakeFtableDataAddr));

    // memcpy(FakeVTable.Data, (UObject*)Self.__vtable, 0x700)
    for(Idx = 0; Idx < 0x700; Idx += 0x4) {
        FakeVtable[Idx / 0x4] = Prim.ReadI32(UObjectVftAddr, Idx);
    }

    `log("[x] set (UObject*)Self.__vtable = &FakeVtable.Data");
    Prim.WriteAddress(SelfAddr, 0x0, FakeFtableDataAddr);

    // FuncMap = TMap<FName, UFunction*>
    SelfUClassFuncMapDataAddr = Prim.ReadAddress(SelfUClassAddr, `OFF.UFunctionFuncMapData);
    `log("[i] SelfUClassFuncMapDataAddr: " $ `UTIL.FormatAddr(SelfUClassFuncMapDataAddr));
    SelfUClassFuncMapLen = Prim.ReadI32(SelfUClassAddr, `OFF.UFUnctionFuncMapLength);
    if(SelfUClassFuncMapLen < 0 || SelfUClassFuncMapLen > 0x300) {
        `log("err: SelfUClassFuncMapLen looks incorrect, got " $ ToHex(SelfUClassFuncMapLen) $ "?");
        return False;
    }

    // TODO: mb use define here?
    SetupShim(ZeroArgShim, ActiveUFuncs[0]);
    SetupShim(OneArgShim, ActiveUFuncs[1]);
    SetupShim(TwoArgShim, ActiveUFuncs[2]);
    SetupShim(ThreeArgShim, ActiveUFuncs[3]);
    SetupShim(FourArgShim, ActiveUFuncs[4]);

    IsInitialised = True;
    return IsInitialised;
}

private function bool SetupShim(const out NativeExecShim CurShim, out ModifiedUFunc CurUFunc) {
    local int Idx;
    local int TmpInt;
    local Address UFuncVftAddr;
    local UnpackedName FuncOverrideTargetName;

    FuncOverrideTargetName = Prim.LeakName(CurShim.UFuncName);
    `log("[i] FuncOverrideTargetName{.index = 0x" $ ToHex(FuncOverrideTargetName.Index) $ ", .suffix = 0x" $ ToHex(FuncOverrideTargetName.Suffix) $ "}");

    `log("[x] identify " $ CurShim.UFuncName $ " in Instance.UClass.FuncMap");
    // we want to find sparse entry for shim
    //  so we can mess with the paired UFunction*
    for(Idx = 0; Idx < SelfUClassFuncMapLen; Idx++) {
        // what makes up a sparse entry?
        // 0x0: FName.Index
        // 0x4: Fname.Suffix
        // 0x8: UFunction *
        // 0xC: SparseEntry.next (can be -1/0xFFFFFFFF)
        // why Idx * 20? sparse entries are aligned to 20/0x14 bytes (i think?)
        if(Prim.ReadI32(SelfUClassFuncMapDataAddr, (Idx * 20) + 0x0) == FuncOverrideTargetName.Index &&
            Prim.ReadI32(SelfUClassFuncMapDataAddr, (Idx * 20) + 0x4) == FuncOverrideTargetName.Suffix) {
            `log("[i] identified FuncMap entry for 'FuncOverrideTarget' at idx " $ Idx);
            CurUFunc.Addr = Prim.ReadAddress(SelfUClassFuncMapDataAddr, (Idx * 20) + 0x8);
            break;
        }
    }

    `log("[i] CurUFunc.Addr = " $ `UTIL.FormatAddr(CurUFunc.Addr));
    UFuncVftAddr = Prim.ReadAddress(CurUFunc.Addr, 0x0);
    `log("[i] UFuncVftAddr = " $ `UTIL.FormatAddr(UFuncVftAddr));

    `log("[x] confusing FuncOverrideTarget into thinking it's 'Native'");
    // set Native flag where appropriate in UFunction
    TmpInt = Prim.ReadI32(CurUFunc.Addr, `OFF.UFunctionLowFlags);
    CurUFunc.SavedFlagsLow = TmpInt;
    TmpInt = TmpInt | 0x400;
    Prim.WriteI32(CurUFunc.Addr, `OFF.UFunctionLowFlags, TmpInt);

    TmpInt = Prim.ReadI32(CurUFunc.Addr, `OFF.UFunctionHighFlags);
    CurUFunc.SavedFlagsHigh = TmpInt;
    TmpInt = TmpInt | 0x4000;
    Prim.WriteI32(CurUFunc.Addr, `OFF.UFunctionHighFlags, TmpInt);

    Prim.WriteAddress(CurUFunc.Addr,
        `OFF.UFunctionFunc,
        `UTIL.Address_AddAddr(CurShim.LoadAddr, SharedLibSlide)
    );

    // local int Idx, RetVal;
    // local UnpackedUniqueNetId Arg0;
    // local Address FuncPtrVirtualAlloc, AllocPageAddr;
    // `log("--> VirtualAlloc");
    // FuncPtrVirtualAlloc = Prim.ReadAddress(`UTIL.Address_AddAddr(`PLT.VirtualAlloc, SharedLibSlide), 0x0);
    // Arg0.LowUid = 0x0;
    // Arg0.HighUid = 0x1000;
    // AllocPageAddr.Low = Self.CallFuncPtrFourArgs(FuncPtrVirtualAlloc, Arg0, 0x1000 | 0x2000, 0x40);
    // `log("<-- VirtualAlloc");

    // `log("[i] AllocPageAddr: " $ `UTIL.FormatAddr(AllocPageAddr));
    // for(Idx = 0; Idx < ArrayCount(`FUNCLET.TestRWX); Idx += 1) {
    //     Prim.WriteI32(AllocPageAddr, (Idx * 0x4), `FUNCLET.TestRWX[Idx]);
    // }

    // Arg0.LowUid = 0x0;
    // Arg0.HighUid = 0x0;
    // RetVal = Self.CallFuncPtrFourArgs(AllocPageAddr, Arg0, 0x0, 0x0);
    // `log("[i] AfterJIT:RetVal=0x" $ ToHex(RetVal));

    return True;
}

function bool InjectDllWithStem(const out string DllName) {
    // TODO: assert initialized
    local int LibHandle;
    local string PathBuf;
    local UnpackedArray UnpackedPathBuf;
    local Address FuncPtrLoadLibraryW;

    PathBuf = GetXComEWBinaryDir() $ DllName $ Chr(0x0) $ Chr(0x0);
    `log("[i] InjectDllWithStem:'" $ PathBuf $"'");
    UnpackedPathBuf = Prim.LeakFString(PathBuf);

    FuncPtrLoadLibraryW = Prim.ReadAddress(`UTIL.Address_AddAddr(`PLT.LoadLibraryW, SharedLibSlide), 0x0);
    `log("[i] FuncPtrLoadLibraryW: " $ `UTIL.FormatAddr(FuncPtrLoadLibraryW));
    LibHandle = Self.CallFuncPtrOneArgs(FuncPtrLoadLibraryW, UnpackedPathBuf.Data);
    `log("[i] FuncPtrLoadLibraryW:LibHandle= " $ `UTIL.ToHex(LibHandle));
    // "If the function succeeds, the return value is a handle to the module."
    return LibHandle != 0;
}

private function string GetXComEWBinaryDir() {
    // TODO: assert initialized
    local int Idx, RetVal;
    local Address FuncPtrGetModuleFileNameW;
    local string PathBuf;
    local UnpackedArray UnpackedPathBuf;
    // for emulating dirname(GetModuleFileNameW(null, &PathBuf.Data, PathBuf.Length))
    local array<string> Stems;

    for(Idx = 0; Idx < 256 + 10; Idx += 1) {
        PathBuf $= "A";
    }
    UnpackedPathBuf = Prim.LeakFString(PathBuf);
    `log("[i] PathBufData=0x" $ ToHex(UnpackedPathBuf.Data));
    `log("[i] PathBufLength=" $ UnpackedPathBuf.Length);

    FuncPtrGetModuleFileNameW = Prim.ReadAddress(`UTIL.Address_AddAddr(`PLT.GetModuleFileNameW, SharedLibSlide), 0x0);
    `log("[i] FuncPtrGetModuleFileNameW: " $ `UTIL.FormatAddr(FuncPtrGetModuleFileNameW));

    RetVal = Self.CallFuncPtrThreeArgs(FuncPtrGetModuleFileNameW, 0x0, UnpackedPathBuf.Data, UnpackedPathBuf.Length);
    `log("[i] RetVal: " $ RetVal);
    PathBuf = Left(PathBuf, RetVal);

    ParseStringIntoArray(PathBuf, Stems, "\\", true);
    `log("[i] Stems: " $ Stems[0]);
    Stems.Length = Stems.Length - 1;
    JoinArray(Stems, PathBuf, "\\", true);

    return PathBuf$"\\";
}

final function int ZeroArgShimTarget() {
    `log("WARNING: calling stub:ZeroArgShimTarget");
    return 0;
}

final function int CallFuncPtrOneArgs(Address FuncPtr, int Arg0) {
    local int RetVal;
    local Address PrevEntry;
    // save -> restore Self.__vtable entry, to head off any mystery crashes from clobbering
    PrevEntry.Low = Self.FakeVtable[OneArgShim.VtableOffset / 0x4];
    Self.FakeVtable[OneArgShim.VtableOffset / 0x4] = FuncPtr.Low;
    RetVal = Self.OneArgShimTarget(Arg0);
    Self.FakeVtable[ThreeArgShim.VtableOffset / 0x4] = PrevEntry.Low;
    return RetVal;
}


final function int OneArgShimTarget(int Arg0) {
    `log("WARNING: calling stub:OneArgShimTarget");
    return 0;
}

final function int TwoArgShimTarget(int Arg0, int Arg1) {
    `log("WARNING: calling stub:TwoArgShimTarget");
    return 0;
}

final function int CallFuncPtrThreeArgs(Address FuncPtr, int Arg0, int Arg1, int Arg2) {
    local int RetVal;
    local Address PrevEntry;
    // save -> restore Self.__vtable entry, to head off any mystery crashes from clobbering
    PrevEntry.Low = Self.FakeVtable[ThreeArgShim.VtableOffset / 0x4];
    Self.FakeVtable[ThreeArgShim.VtableOffset / 0x4] = FuncPtr.Low;
    RetVal = Self.ThreeArgShimTarget(Arg0, Arg1, Arg2);
    Self.FakeVtable[ThreeArgShim.VtableOffset / 0x4] = PrevEntry.Low;
    return RetVal;
}


final function int ThreeArgShimTarget(int Arg0, int Arg1, int Arg2) {
    `log("WARNING: calling stub:ThreeArgShimTarget");
    return 0;
}

final function int CallFuncPtrFourArgs(Address FuncPtr, UnpackedUniqueNetId Arg0, int Arg2, int Arg3) {
    local int RetVal;
    local Address PrevEntry;
    // save -> restore Self.__vtable entry, to head off any mystery crashes from clobbering
    PrevEntry.Low = Self.FakeVtable[FourArgShim.VtableOffset / 0x4];
    Self.FakeVtable[FourArgShim.VtableOffset / 0x4] = FuncPtr.Low;
    RetVal = Self.FourArgShimTarget(Arg0, Arg2, Arg3);
    Self.FakeVtable[FourArgShim.VtableOffset / 0x4] = PrevEntry.Low;
    return RetVal;
}

final function int FourArgShimTarget(UnpackedUniqueNetId Arg0, int Arg2, int Arg3) {
    `log("WARNING: calling stub:FourArgShimTarget");
    return 0;
}

static final function ForceExit() {
    local int I;
    // the unreal vm cannot abide big ass for-loops
    for(I = 0; I < 0x10000000; I++) {}
}

static final function Panic(const string Msg) {
    `log("PANIC: " $ Msg);
    ForceExit();
}

defaultproperties
{
    ZeroArgShim={(
        CxxSymbol="UMeshComponent::execGetNumElements",
        CxxArgs=(),
        UScriptArgs=(),
        UScriptRetVal="int",
        VtableOffset=0x228,
        LoadAddr=(Low=0x576180),
        UFuncName=ZeroArgShimTarget
    )};
    OneArgShim={(
        CxxSymbol="UMultiFont::execGetResolutionTestTableIndex",
        CxxArgs=("int32_t"),
        UScriptArgs=("float"),
        UScriptRetVal="int",
        VtableOffset=0x150,
        LoadAddr=(Low=0xF577A0),
        UFuncName=OneArgShimTarget
    )};
    TwoArgShim={(
        CxxSymbol="UOnlinePlayerStorage::execSetProfileSettingValueInt",
        CxxArgs=("int32_t","int32_t"),
        UScriptArgs=("int","int"),
        UScriptRetVal="bool",
        VtableOffset=0x16C,
        LoadAddr=(Low=0x50FCD0),
        UFuncName=TwoArgShimTarget
    )};
    ThreeArgShim={(
        CxxSymbol="UCloudStorageBase::execSaveDocumentWithObject",
        CxxArgs=("int32_t","int32_t","int32_t"),
        UScriptArgs=("int","Object","int"),
        UScriptRetVal="bool",
        VtableOffset=0x168,
        LoadAddr=(Low=0xF32F10),
        UFuncName=ThreeArgShimTarget
    )};
    FourArgShim={(
        CxxSymbol="UOnlineStatsRead::execSetIntStatValueForPlayer",
        CxxArgs=("int32_t","int32_t","int32_t","int32_t"),
        UScriptArgs=("UniqueNetId","int","int"),
        UScriptRetVal="bool",
        VtableOffset=0x13C,
        LoadAddr=(Low=0x69B020),
        UFuncName=FourArgShimTarget
    )};
}
