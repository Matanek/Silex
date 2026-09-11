const std = @import("std");
const Ir = @import("../Ir.zig");

const Key = struct {
    operator: Ir.BinaryOperator,
    type: Ir.Type,
    left: Ir.ValueId,
    right: Ir.ValueId,
    checked: bool,
    left_non_negative: bool,
};

// Value numbering uses immutable scalar snapshots, never memory locations.
// Keep operand order and every arithmetic flag exact; no reassociation or
// commutativity is inferred. A call ends availability, including FP environment
// assumptions. Every replacement is dominated by its original in this block.
pub fn optimize(allocator: std.mem.Allocator, function: Ir.Function) !Ir.Function {
    var binary_count: usize = 0;
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .binary) binary_count += 1;
    };
    if (binary_count < 2) return function;

    const definitions = try allocator.alloc(usize, function.value_types.len);
    @memset(definitions, 0);
    for (0..function.parameter_types.len + function.capture_types.len) |value| definitions[value] += 1;
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (resultOf(instruction)) |result| definitions[result] += 1;
        if (instruction == .list_edit) {
            if (instruction.list_edit.removed) |result| definitions[result] += 1;
        }
    };
    const roots = try allocator.alloc(Ir.ValueId, function.value_types.len);
    var available = std.AutoHashMap(Key, Ir.ValueId).init(allocator);
    defer available.deinit();
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    for (blocks) |*block| {
        for (roots, 0..) |*root, value| root.* = value;
        available.clearRetainingCapacity();
        const instructions = try allocator.dupe(Ir.Instruction, block.instructions);
        for (instructions) |*instruction| switch (instruction.*) {
            .copy => |copy| {
                if (definitions[copy.result] == 1 and definitions[copy.operand] == 1 and
                    scalar(function.value_types[copy.result]) and
                    function.value_types[copy.result] == function.value_types[copy.operand])
                    roots[copy.result] = roots[copy.operand];
            },
            .binary => |binary| {
                if (definitions[binary.result] != 1 or definitions[binary.left] != 1 or definitions[binary.right] != 1 or
                    !scalar(function.value_types[binary.result]) or
                    !scalar(function.value_types[binary.left]) or !scalar(function.value_types[binary.right])) continue;
                const key: Key = .{
                    .operator = binary.operator,
                    .type = function.value_types[binary.result],
                    .left = roots[binary.left],
                    .right = roots[binary.right],
                    .checked = binary.checked,
                    .left_non_negative = binary.left_non_negative,
                };
                const entry = try available.getOrPut(key);
                if (entry.found_existing) {
                    roots[binary.result] = entry.value_ptr.*;
                    instruction.* = .{ .copy = .{ .result = binary.result, .operand = entry.value_ptr.* } };
                } else entry.value_ptr.* = binary.result;
            },
            .call,
            .indirect_call,
            .boundary_call,
            .boundary_indirect_call,
            .dynamic_call,
            .class_drop,
            .list_drop,
            .string_drop,
            .mutex_lock,
            .mutex_unlock,
            => available.clearRetainingCapacity(),
            else => {},
        };
        block.instructions = instructions;
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn scalar(value_type: Ir.Type) bool {
    return value_type.isInteger() or value_type.isFloat() or value_type == .bool;
}

fn resultOf(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        .class_retain,
        .class_drop,
        .list_retain,
        .list_drop,
        .string_retain,
        .string_drop,
        .global_store,
        .local_store,
        .address_store,
        .reference_store,
        .print,
        .assert,
        .mutex_lock,
        .mutex_unlock,
        => null,
        inline .call, .indirect_call, .boundary_call, .boundary_indirect_call, .dynamic_call => |call| call.result,
        inline else => |value| value.result,
    };
}
