const std = @import("std");
const Ir = @import("../Ir.zig");
const Types = @import("../Types.zig");

pub const Binding = struct {
    name: []const u8,
    type: Types.Type,
    value: ?Ir.ValueId = null,
    local: ?Ir.LocalId = null,
    mutable: bool = false,
    parameter: bool = false,
    available: bool = true,
    refined_type: ?Types.Type = null,
    refined_value: ?Ir.ValueId = null,
};

pub const TypedValue = struct {
    type: Types.Type,
    value: Ir.ValueId,
};

pub const BlockBuilder = struct {
    instructions: std.ArrayList(Ir.Instruction) = .empty,
    terminator: ?Ir.Terminator = null,
};

pub const LoopContext = struct {
    continue_block: Ir.BlockId,
    break_block: Ir.BlockId,
    availability_count: usize = 0,
    header_availability: []const bool = &.{},
    break_availabilities: std.ArrayList([]const bool) = .empty,
};

pub const FunctionBuilder = struct {
    return_type: ?Types.Type = null,
    value_types: std.ArrayList(Types.Type) = .empty,
    local_types: std.ArrayList(Types.Type) = .empty,
    blocks: std.ArrayList(BlockBuilder) = .empty,
    current_block: Ir.BlockId = 0,
    bindings: std.ArrayList(Binding) = .empty,
    loops: std.ArrayList(LoopContext) = .empty,
};
