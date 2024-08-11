class Symbols extends Object dependsOn(DataStructures);

struct OffsetDef {
    var int UFunctionFuncMapData;
    var int UFUnctionFuncMapLength;
    var int UFunctionLowFlags;
    var int UFunctionHighFlags;
    var int UFunctionFunc;
};

struct LoadAddrDef {
    var Address __HEADER_BASE;
    var Address GNatives;
    var Address GPropAddr;
    var Address GPropObject;
    var Address GProperty;
    var Address GetProcAddress;
    var Address GMalloc;
    var Address UObjectVft;
};

struct PltLoadAddrDef {
    // HMODULE (__stdcall *LoadLibraryW)(LPCWSTR lpLibFileName)
    var Address LoadLibraryW;
    // DWORD (__stdcall *GetModuleFileNameW)(HMODULE hModule, LPWSTR lpFilename, DWORD nSize)
    var Address GetModuleFileNameW;
    // HANDLE (__stdcall *GetCurrentProcess)()
    var Address GetCurrentProcess;
    // DWORD (__stdcall *GetCurrentProcessId)()
    var Address GetCurrentProcessId;
    // HMODULE (__stdcall *GetModuleHandleW)(LPCWSTR lpModuleName)
    var Address GetModuleHandleW;
    // FARPROC (__stdcall *GetProcAddress)(HMODULE hModule, LPCSTR lpProcName)
    var Address GetProcAddress;
    // LPVOID (__stdcall *VirtualAlloc)(LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect)
    var Address VirtualAlloc;
};

struct FuncletDef {
    // __Funclet_TestRWX:+0x0: sub     esp, 0x8
    // __Funclet_TestRWX:+0x3: push    ebp
    // __Funclet_TestRWX:+0x4: mov     eax, 0x3333
    // __Funclet_TestRWX:+0x9: pop     ebp
    // __Funclet_TestRWX:+0xa: add     esp, 0x8
    // __Funclet_TestRWX:+0xd: retn    0x10
    var int TestRWX[4];
};

var OffsetDef Offset;
var LoadAddrDef LoadAddr;
var PltLoadAddrDef PltLoadAddr;
var FuncletDef Funclet;

defaultproperties
{(
    Offset={(
        UFunctionFuncMapData=0x90,
        UFUnctionFuncMapLength=0x94,
        UFunctionLowFlags=0x84,
        UFunctionHighFlags=0xcc,
        UFunctionFunc=0xa0
    )};
    LoadAddr={(
        __HEADER_BASE=(Low=0x400000),
        GNatives=(Low=0x1c6fd70),
        GPropAddr=(Low=0x1c49d5c),
        GPropObject=(Low=0x1c49d60),
        GProperty=(Low=0x1c49d44),
        GMalloc=(Low=0x1c49d30),
        UObjectVft=(Low=0x189dff0)
    )};
    PltLoadAddr={(
        LoadLibraryW=(Low=0x1395380),
        GetModuleFileNameW=(Low=0x1395394),
        GetCurrentProcess=(Low=0x1395270),
        GetCurrentProcessId=(Low=0x1395328),
        GetModuleHandleW=(Low=0x1395308),
        GetProcAddress=(Low=0x1395304),
        VirtualAlloc=(Low=0x13951DC)
    )};
    Funclet={(
        TestRWX[0]=0x5508ec83,
        TestRWX[1]=0x003333b8,
        TestRWX[2]=0xc4835d00,
        TestRWX[3]=0x0010c208,
    )};
)}
