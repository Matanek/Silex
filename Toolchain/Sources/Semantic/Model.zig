const std = @import("std");
const Ir = @import("../Ir.zig");
const Types = @import("../Types.zig");
const Ast = @import("../Ast.zig");

pub const LexicalBorrow = struct {
    root: []const u8,
    mode: Ast.Parameter.Mode,
};

pub const Binding = struct {
    name: []const u8,
    type: Types.Type,
    value: ?Ir.ValueId = null,
    local: ?Ir.LocalId = null,
    global: ?usize = null,
    reference: ?Ir.ValueId = null,
    mutable: bool = false,
    parameter: bool = false,
    parameter_mode: Ast.Parameter.Mode = .value,
    borrowed_root: ?[]const u8 = null,
    borrowed_mode: Ast.Parameter.Mode = .value,
    available: bool = true,
    refined_type: ?Types.Type = null,
    refined_value: ?Ir.ValueId = null,
    lexical_captures: bool = false,
    lexical_borrows: []const LexicalBorrow = &.{},
};

pub const TypedValue = struct {
    type: Types.Type,
    value: Ir.ValueId,
    transferred: bool = false,
    borrowed_root: ?[]const u8 = null,
    borrowed_mode: Ast.Parameter.Mode = .value,
    reference: ?Ir.ValueId = null,
    lexical_captures: bool = false,
    lexical_borrows: []const LexicalBorrow = &.{},
};

pub const BlockBuilder = struct {
    instructions: std.ArrayList(Ir.Instruction) = .empty,
    instruction_positions: std.ArrayList(?@import("../Source.zig").Position) = .empty,
    terminator: ?Ir.Terminator = null,
    terminator_position: ?@import("../Source.zig").Position = null,
};

pub const LoopContext = struct {
    continue_block: Ir.BlockId,
    break_block: Ir.BlockId,
    availability_count: usize = 0,
    drop_binding_count: usize = 0,
    header_availability: []const bool = &.{},
    break_availabilities: std.ArrayList([]const bool) = .empty,
    mutex_depth: usize = 0,
};

pub const FunctionBuilder = struct {
    return_type: ?Types.Type = null,
    value_types: std.ArrayList(Types.Type) = .empty,
    local_types: std.ArrayList(Types.Type) = .empty,
    blocks: std.ArrayList(BlockBuilder) = .empty,
    current_block: Ir.BlockId = 0,
    bindings: std.ArrayList(Binding) = .empty,
    loops: std.ArrayList(LoopContext) = .empty,
    mutex_depth: usize = 0,
    current_position: ?@import("../Source.zig").Position = null,
};
