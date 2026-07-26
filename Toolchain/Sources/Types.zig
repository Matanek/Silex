pub const Type = enum(u32) {
    void = 0,
    int8 = 1,
    int16 = 2,
    int32 = 3,
    int = 4,
    uint8 = 5,
    uint16 = 6,
    uint32 = 7,
    uint = 8,
    bool = 9,
    float32 = 10,
    float64 = 11,
    str = 12,
    _,

    const structure_base = 0x100;
    const generic_instantiation_base = 0x20000000;
    const generic_parameter_base = 0x40000000;
    const optional_flag = 0x80000000;

    pub fn structure(index: usize) Type {
        return @enumFromInt(structure_base + @as(u32, @intCast(index)));
    }

    pub fn structureIndex(self: Type) ?usize {
        const value = @intFromEnum(self);
        return if (value >= structure_base and value < generic_instantiation_base) value - structure_base else null;
    }

    pub fn genericInstantiation(index: usize) Type {
        return @enumFromInt(generic_instantiation_base + @as(u32, @intCast(index)));
    }

    pub fn genericInstantiationIndex(self: Type) ?usize {
        const value = @intFromEnum(self);
        return if (value >= generic_instantiation_base and value < generic_parameter_base) value - generic_instantiation_base else null;
    }

    pub fn genericParameter(index: usize) Type {
        return @enumFromInt(generic_parameter_base + @as(u32, @intCast(index)));
    }

    pub fn genericParameterIndex(self: Type) ?usize {
        const value = @intFromEnum(self);
        return if (value >= generic_parameter_base and value < optional_flag) value - generic_parameter_base else null;
    }

    pub fn optional(child: Type) Type {
        return @enumFromInt(optional_flag | @intFromEnum(child));
    }

    pub fn optionalChild(self: Type) ?Type {
        const value = @intFromEnum(self);
        return if (value & optional_flag != 0) @enumFromInt(value & ~@as(u32, optional_flag)) else null;
    }

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
            _ => if (self.optionalChild() != null)
                "optional"
            else if (self.genericInstantiationIndex() != null)
                "generic type"
            else if (self.genericParameterIndex() != null)
                "type parameter"
            else
                "structure",
        };
    }

    pub fn hasRuntimeValue(self: Type) bool {
        return switch (self) {
            .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint, .float32, .float64, .bool, .str => true,
            .void => false,
            _ => true,
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
