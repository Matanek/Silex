const Source = @import("Source.zig");

pub const Type = enum {
    void,
    float32,
    str,

    pub fn name(self: Type) []const u8 {
        return switch (self) {
            .void => "void",
            .float32 => "float",
            .str => "str",
        };
    }
};

pub const Parameter = struct {
    position: Source.Position,
    name: []const u8,
    type: Type,
};

pub const Function = struct {
    position: Source.Position,
    name_position: Source.Position,
    name: []const u8,
    parameters: []const Parameter,
    return_type: Type,
};

pub const Program = struct {
    functions: []const Function,
};
