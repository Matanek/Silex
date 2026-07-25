pub const Type = enum {
    void,
    int,
    bool,
    float32,
    str,

    pub fn name(self: Type) []const u8 {
        return switch (self) {
            .void => "void",
            .int => "int",
            .bool => "bool",
            .float32 => "float",
            .str => "str",
        };
    }

    pub fn hasRuntimeValue(self: Type) bool {
        return switch (self) {
            .int, .bool => true,
            .void, .float32, .str => false,
        };
    }
};
