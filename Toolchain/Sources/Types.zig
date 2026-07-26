pub const Type = enum {
    void,
    int8,
    int16,
    int32,
    int,
    uint8,
    uint16,
    uint32,
    uint,
    bool,
    float32,
    float64,
    str,

    pub fn name(self: Type) []const u8 {
        return switch (self) {
            .void => "void",
            .int8 => "int8",
            .int16 => "int16",
            .int32 => "int32",
            .int => "int",
            .uint8 => "uint8",
            .uint16 => "uint16",
            .uint32 => "uint32",
            .uint => "uint",
            .bool => "bool",
            .float32 => "float",
            .float64 => "float64",
            .str => "str",
        };
    }

    pub fn hasRuntimeValue(self: Type) bool {
        return switch (self) {
            .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint, .float32, .float64, .bool, .str => true,
            .void => false,
        };
    }

    pub fn isInteger(self: Type) bool {
        return switch (self) {
            .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint => true,
            else => false,
        };
    }

    pub fn isSignedInteger(self: Type) bool {
        return switch (self) {
            .int8, .int16, .int32, .int => true,
            else => false,
        };
    }

    pub fn isFloat(self: Type) bool {
        return self == .float32 or self == .float64;
    }

    pub fn isNumeric(self: Type) bool {
        return self.isInteger() or self.isFloat();
    }

    pub fn bitWidth(self: Type) u7 {
        return switch (self) {
            .int8, .uint8 => 8,
            .int16, .uint16 => 16,
            .int32, .uint32, .float32 => 32,
            .int, .uint, .float64 => 64,
            else => 0,
        };
    }
};
