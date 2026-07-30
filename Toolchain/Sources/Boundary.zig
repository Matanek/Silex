const Types = @import("Types.zig");

pub const Function = struct {
    name: []const u8,
    provider: []const u8,
    source_name: []const u8,
    parameters: []const Types.Type,
    return_type: Types.Type,
    owner: usize = 0,
    package_private: bool = false,
};
