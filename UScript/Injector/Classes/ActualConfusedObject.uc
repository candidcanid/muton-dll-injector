class ActualConfusedObject extends Object dependsOn(
    DataStructures
);

function UnpackedName UnpackName(out UnpackedName Unpacked) {
    return Unpacked;
}

function UnpackedArray UnpackIntArray(out UnpackedArray Unpacked) {
    return Unpacked;
}

function UnpackedArray UnpackFString(out UnpackedArray Unpacked) {
    return Unpacked;
}

function UnpackedArray UnpackObjectArray(out UnpackedArray Unpacked) {
    return Unpacked;
}

function int RepackArrayAndReadInt32(out array<int> Unpacked, optional int Idx=0) {
    return Unpacked[Idx];
}

function RepackArrayAndWriteInt32(out array<int> Unpacked, int Value, optional int Idx=0) {
    Unpacked[Idx] = Value;
}
