class ExpectedConfusedObject extends Object dependsOn(
    DataStructures
);

function UnpackedName UnpackName(name NameVal) {
    local UnpackedName Unpacked;
    `log("[WARNING] calling 'assumed' API function .. will not do anything interesting!");
    Unpacked.Index = 0x11111111;
    Unpacked.Suffix = 0x11111111;
    return Unpacked;
}

function UnpackedArray UnpackIntArray(out array<int> InArray) {
    local UnpackedArray Unpacked;
    `log("[WARNING] calling 'assumed' API function .. will not do anything interesting!");
    Unpacked.Data = 0x11111111;
    Unpacked.Length = 0x11111111;
    Unpacked.Capacity = 0x11111111;
    return Unpacked;
}

function UnpackedArray UnpackObjectArray(out array<Object> InArray) {
    local UnpackedArray Unpacked;
    `log("[WARNING] calling 'assumed' API function .. will not do anything interesting!");
    Unpacked.Data = 0x11111111;
    Unpacked.Length = 0x11111111;
    Unpacked.Capacity = 0x11111111;
    return Unpacked;
}

function UnpackedArray UnpackFString(out string InString) {
    local UnpackedArray Unpacked;
    `log("[WARNING] calling 'assumed' API function .. will not do anything interesting!");
    Unpacked.Data = 0x11111111;
    Unpacked.Length = 0x11111111;
    Unpacked.Capacity = 0x11111111;
    return Unpacked;
}

function int RepackArrayAndReadInt32(out UnpackedArray Unpacked, optional int Idx=0) {
    `log("[WARNING] calling 'assumed' API function .. will not do anything interesting!");
    return 0x11111111;
}

function RepackArrayAndWriteInt32(out UnpackedArray Unpacked, int Value, optional int Idx=0) {
    `log("[WARNING] calling 'assumed' API function .. will not do anything interesting!");
}

