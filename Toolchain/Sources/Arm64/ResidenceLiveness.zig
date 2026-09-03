const std = @import("std");
const Machine = @import("Machine.zig");
const MemoryResidence = @import("MemoryResidence.zig");

pub const Interval = struct {
    slot: Machine.Slot,
    first: usize,
    last: usize,
    weight: u64,
};

pub fn successorLive(
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
    index: usize,
    slot: usize,
) bool {
    return switch (instructions[index]) {
        .jump => |target| live[target * slot_count + slot],
        .branch => |branch_value| live[branch_value.then_instruction * slot_count + slot] or
            live[branch_value.else_instruction * slot_count + slot],
        .return_value, .return_void => false,
        else => if (index + 1 < instructions.len) live[(index + 1) * slot_count + slot] else false,
    };
}

pub fn instructionUses(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .copy => |value| value.operand == slot,
        .copy_range => |value| spanContains(value.operand, slot),
        .aggregate_init => |value| for (value.fields) |field| {
            if (spanContains(field, slot)) break true;
        } else false,
        .unary => |value| value.operand == slot,
        .binary => |value| value.left == slot or value.right == slot,
        .convert => |value| value.operand == slot,
        .collection_load => |value| value.index == slot or spanContains(value.collection, slot),
        .collection_count => |value| spanContains(value.collection, slot),
        .call => |call| for (call.arguments) |argument| {
            if (spanContains(argument, slot)) break true;
        } else false,
        .return_value => |value| spanContains(value, slot),
        .branch => |value| value.condition == slot,
        else => MemoryResidence.uses(instruction, slot),
    };
}

pub fn instructionDefines(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .constant_int => |value| value.result == slot,
        .constant_bool => |value| value.result == slot,
        .constant_float32 => |value| value.result == slot,
        .constant_float64 => |value| value.result == slot,
        .copy => |value| value.result == slot,
        .copy_range => |value| spanContains(value.result, slot),
        .storage_init => |value| spanContains(value, slot),
        .aggregate_init => |value| spanContains(value.result, slot),
        .unary => |value| value.result == slot,
        .binary => |value| value.result == slot,
        .convert => |value| value.result == slot,
        .collection_load => |value| spanContains(value.result, slot),
        .collection_count => |value| value.result == slot,
        .call => |call| if (call.result) |result| spanContains(result, slot) else false,
        else => MemoryResidence.defines(instruction, slot),
    };
}

pub fn spanContains(span: Machine.Span, slot: usize) bool {
    return slot >= span.start and slot < @as(usize, span.start) + span.width;
}

pub fn heavierThan(_: void, left: Interval, right: Interval) bool {
    return left.weight > right.weight or (left.weight == right.weight and left.slot < right.slot);
}
