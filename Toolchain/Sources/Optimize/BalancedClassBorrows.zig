const std = @import("std");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");

// Inlined readers can retain a receiver, inspect it and immediately drop the
// same root again. No instruction in this region can release its original
// owner, publish an alias, call user code or observe the reference count.
// Keep all effectful regions and every control-flow boundary untouched.
pub fn optimize(allocator: std.mem.Allocator, function: Ir.Function) !Ir.Function {
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        const removed = try allocator.alloc(bool, block.instructions.len);
        defer allocator.free(removed);
        @memset(removed, false);
        var retained: ?usize = null;
        for (block.instructions, 0..) |instruction, index| {
            if (instruction == .class_retain) {
                retained = if (instruction.class_retain.ownership == .root) index else null;
                continue;
            }
            if (retained) |start| {
                const root = block.instructions[start].class_retain.operand;
                if (instruction == .class_drop and instruction.class_drop.ownership == .root and
                    instruction.class_drop.operand == root)
                {
                    removed[start] = true;
                    removed[index] = true;
                    retained = null;
                    continue;
                }
                if (!readOnly(instruction) or resultOf(instruction) == root) retained = null;
            }
        }
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        var positions: std.ArrayList(?Source.Position) = .empty;
        for (block.instructions, 0..) |instruction, index| {
            if (removed[index]) continue;
            try instructions.append(allocator, instruction);
            if (block.instruction_positions.len != 0) try positions.append(allocator, block.instruction_positions[index]);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .instruction_positions = try positions.toOwnedSlice(allocator),
            .terminator = block.terminator,
            .terminator_position = block.terminator_position,
        };
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn readOnly(instruction: Ir.Instruction) bool {
    return switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .local_load,
        .field_load,
        .collection_load,
        .collection_count,
        .unary,
        .binary,
        .convert,
        => true,
        else => false,
    };
}

fn resultOf(instruction: Ir.Instruction) ?Ir.ValueId {
    switch (instruction) {
        inline else => |value| {
            if (@typeInfo(@TypeOf(value)) != .@"struct" or !@hasField(@TypeOf(value), "result")) return null;
            return value.result;
        },
    }
}

test "balanced class roots are removed only across readers in one block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const retain: Ir.Instruction = .{ .class_retain = .{ .operand = 0 } };
    const drop: Ir.Instruction = .{ .class_drop = .{ .operand = 0, .static_type = 0, .plans = &.{} } };
    const read: Ir.Instruction = .{ .field_load = .{ .result = 2, .base = 0, .field = 0 } };
    const function: Ir.Function = .{
        .name = "reader",
        .parameter_types = &.{ Ir.Type.structure(0), Ir.Type.structure(0) },
        .return_type = .float32,
        .value_types = &.{ Ir.Type.structure(0), Ir.Type.structure(0), .float32 },
        .blocks = &.{.{ .instructions = &.{ retain, read, drop }, .terminator = .{ .return_value = 2 } }},
    };
    const result = try optimize(allocator, function);
    try std.testing.expectEqual(@as(usize, 1), result.blocks[0].instructions.len);
    try std.testing.expect(result.blocks[0].instructions[0] == .field_load);
    const barriers = [_]Ir.Instruction{
        .{ .call = .{ .result = null, .function = 0, .arguments = &.{0} } },
        .{ .reference_store = .{ .reference = 1, .operand = 2 } },
        .{ .local_store = .{ .local = 0, .operand = 2 } },
        .{ .class_drop = .{ .operand = 1, .static_type = 0, .plans = &.{} } },
        .{ .copy = .{ .result = 0, .operand = 1 } },
    };
    for (barriers) |barrier| {
        var blocked = function;
        blocked.blocks = &.{.{ .instructions = &.{ retain, read, barrier, drop }, .terminator = function.blocks[0].terminator }};
        const unchanged = try optimize(allocator, blocked);
        try std.testing.expectEqual(@as(usize, 4), unchanged.blocks[0].instructions.len);
    }
    var crossing = function;
    crossing.blocks = &.{
        .{ .instructions = &.{retain}, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{ read, drop }, .terminator = function.blocks[0].terminator },
    };
    const untouched = try optimize(allocator, crossing);
    try std.testing.expectEqual(@as(usize, 1), untouched.blocks[0].instructions.len);
    try std.testing.expectEqual(@as(usize, 2), untouched.blocks[1].instructions.len);
}
