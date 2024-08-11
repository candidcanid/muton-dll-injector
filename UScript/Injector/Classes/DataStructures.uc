class DataStructures extends Object;

struct UnpackedName {
    var int Index;
    var int Suffix;
};

struct UnpackedArray {
    var int Data;
    var int Length;
    var int Capacity;
};

struct UnpackedVector {
    var int X;
    var int Y;
    var int Z;
};

struct Address {
    var int Low;
};

static function string FormatAddr(Address Addr) {
    return "0x" $ ToHex(Addr.Low);
}

static final function Address AddressFromString(string InStr) {
    local Address Addr;
    local int Idx, Shift, CurByte, AsciiOff, Addend;

    // normalise numbers like 0xdeadbeef to 0xDEADBEEF
    InStr = Locs(InStr);

    if(Left(InStr, 2) != "0x") {
        `log("[error]: AddressFromString only accepts base16 numbers starting with '0x', got '" $ InStr $ "'");
        return Addr;
    }

    // strip '0x'
    InStr = Mid(InStr, 2);

    if(Len(InStr) > 8) {
        `log("[error]: number '0x" $ InStr $ "' cannot fit into a 64bit word");
        return Addr;
    }

    `log("[verbose]: converting '" $ InStr $ "'");

    Shift = 0x0;
    for(Idx = Len(InStr) - 1; Idx >= 0; Idx--) {
        CurByte = Asc(Mid(InStr, Idx, 1));
        if(CurByte > 0xff) {
            `log("[error]: non-utf8 character encountered");
            return Addr;
        }

        // '0'..'9'
        if(CurByte >= 0x30 && CurByte <= 0x39) {
            AsciiOff = 0x30;
            Addend = 0;
        // 'a'..'f'
        } else if(CurByte >= 0x61 && CurByte <= 0x66) {
            AsciiOff = 0x61;
            Addend = 10;
        } else {
            `log("[error]: cannot convert character '" $ Chr(CurByte) $ "' at index " $ Idx $ "to number");
            return Addr;
        }

        Addr.Low = Addr.Low | ((CurByte - AsciiOff + Addend) << Shift);
        Shift += 4;
    }

    `log("[verbose]: converted to 0x" $ ToHex(Addr.Low));
    return Addr;
}

static final function Address Address_AddI32(Address Addr, int Value) {
    Addr.Low += Value;
    return Addr;
}

static final function Address Address_AddAddr(Address Lhs, Address Rhs) {
    Lhs.Low += Rhs.Low;
    return Lhs;
}

static final function Address Address_SubAddr(Address Lhs, Address Rhs) {
    local Address Blah;
    Blah.Low = Lhs.Low - Rhs.Low;
    return Blah;
}

static final function Address AddressFromI32(int Low) {
    local Address Addr;
    Addr.Low = Low;
    return Addr;
}
