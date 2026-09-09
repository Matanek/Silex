const std = @import("std");
const Machine = @import("Machine.zig");

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
        .constant_int,
        .constant_bool,
        .constant_str,
        .constant_bytes,
        .constant_float32,
        .constant_float64,
        .optional_null,
        .global_load,
        .storage_init,
        .local_address,
        .mutex_lock,
        .mutex_unlock,
        .return_void,
        .jump,
        => false,
        .optional_some => |value| spanContains(value.operand, slot),
        .optional_unwrap => |value| spanContains(value.operand, slot),
        .copy => |value| value.operand == slot,
        .copy_range => |value| spanContains(value.operand, slot),
        .deep_copy => |value| spanContains(value.operand, slot),
        .global_store => |value| spanContains(value.operand, slot),
        .reference_load => |value| value.reference == slot,
        .address_load => |value| value.address == slot or value.byte_offset == slot,
        .address_store => |value| value.address == slot or value.byte_offset == slot or value.operand == slot,
        .reference_store => |value| value.reference == slot or spanContains(value.operand, slot),
        .reference_offset, .reference_indirect_offset => |value| value.reference == slot,
        .aggregate_init => |value| for (value.fields) |field| {
            if (spanContains(field, slot)) break true;
        } else false,
        .protocol_init => |value| spanContains(value.operand, slot),
        .protocol_test => |value| value.operand == slot,
        .protocol_extract => |value| spanContains(value.operand, slot),
        .class_init => |value| for (value.fields) |field| {
            if (spanContains(field, slot)) break true;
        } else false,
        .class_test => |value| value.operand == slot,
        .class_load => |value| value.base == slot,
        .class_store => |value| value.base == slot or spanContains(value.replacement, slot),
        .class_retain => |value| value.operand == slot,
        .class_drop => |value| value.operand == slot,
        .list_retain, .list_drop, .string_retain, .string_drop => |value| value.operand == slot,
        .list_init => |value| for (value.values) |element| {
            if (spanContains(element, slot)) break true;
        } else false,
        .enum_init => |value| for (value.values) |element| {
            if (spanContains(element, slot)) break true;
        } else false,
        .enum_test => |value| spanContains(value.operand, slot),
        .unary => |value| value.operand == slot,
        .binary => |value| value.left == slot or value.right == slot,
        .convert => |value| value.operand == slot,
        .collection_load => |value| value.index == slot or spanContains(value.collection, slot),
        .collection_reference => |value| value.index == slot or spanContains(value.collection, slot) or
            (if (value.reference) |reference| reference == slot else false),
        .collection_replace => |value| value.index == slot or spanContains(value.collection, slot) or
            spanContains(value.replacement, slot),
        .collection_count => |value| spanContains(value.collection, slot),
        .list_edit => |value| value.collection == slot or
            (if (value.index) |index| index == slot else false) or
            (if (value.argument) |argument| spanContains(argument, slot) else false),
        .collection_slice => |value| value.start == slot or value.end == slot or spanContains(value.collection, slot),
        .collection_view => |value| value.start == slot or value.end == slot or spanContains(value.collection, slot) or
            (if (value.reference) |reference| reference == slot else false),
        .aggregate_equal => |value| spanContains(value.left, slot) or spanContains(value.right, slot),
        .format_value => |value| value.operand == slot,
        .string_concat => |value| value.left == slot or value.right == slot,
        .string_count, .string_byte_count => |value| value.operand == slot,
        .string_byte_at => |value| value.operand == slot or value.index == slot,
        .string_from_bytes => |value| spanContains(value.bytes, slot),
        .function_address => |value| for (value.captures) |capture| {
            if (capture == slot) break true;
        } else false,
        .call => |call| for (call.arguments) |argument| {
            if (spanContains(argument, slot)) break true;
        } else false,
        .indirect_call => |call| call.callee == slot or for (call.arguments) |argument| {
            if (spanContains(argument, slot)) break true;
        } else false,
        .external_call => |call| for (call.arguments) |argument| {
            if (argument == slot) break true;
        } else false,
        .external_indirect_call => |call| call.callee == slot or for (call.arguments) |argument| {
            if (argument == slot) break true;
        } else false,
        .dynamic_call => |call| call.receiver == slot or for (call.arguments) |argument| {
            if (spanContains(argument, slot)) break true;
        } else false,
        .print => |value| value.value == slot,
        .assert => |value| value.condition == slot or value.message == slot,
        .panic => |value| value.message == slot,
        .return_value => |value| spanContains(value, slot),
        .branch => |value| value.condition == slot,
    };
}

pub fn instructionDefines(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .constant_int => |value| value.result == slot,
        .constant_bool => |value| value.result == slot,
        .constant_str => |value| value.result == slot,
        .constant_bytes => |value| value.result == slot,
        .constant_float32 => |value| value.result == slot,
        .constant_float64 => |value| value.result == slot,
        .optional_null => |value| spanContains(value.result, slot),
        .optional_some => |value| spanContains(value.result, slot),
        .optional_unwrap => |value| spanContains(value.result, slot),
        .copy => |value| value.result == slot,
        .copy_range => |value| spanContains(value.result, slot),
        .deep_copy => |value| spanContains(value.result, slot),
        .global_load => |value| spanContains(value.result, slot),
        .local_address => |value| value.result == slot,
        .reference_load => |value| spanContains(value.result, slot),
        .address_load => |value| value.result == slot,
        .reference_offset, .reference_indirect_offset => |value| value.result == slot,
        .storage_init => |value| spanContains(value, slot),
        .aggregate_init => |value| spanContains(value.result, slot),
        .protocol_init => |value| spanContains(value.result, slot),
        .protocol_test => |value| value.result == slot,
        .protocol_extract => |value| spanContains(value.result, slot),
        .class_init => |value| value.result == slot,
        .class_test => |value| value.result == slot,
        .class_load => |value| spanContains(value.result, slot),
        .class_store => |value| value.result == slot,
        .list_init => |value| value.result == slot,
        .enum_init => |value| spanContains(value.result, slot),
        .enum_test => |value| value.result == slot,
        .unary => |value| value.result == slot,
        .binary => |value| value.result == slot,
        .convert => |value| value.result == slot,
        .collection_load => |value| spanContains(value.result, slot),
        .collection_reference => |value| value.result == slot,
        .collection_replace => |value| spanContains(value.result, slot),
        .collection_count => |value| value.result == slot,
        .list_edit => |value| value.result == slot or (if (value.removed) |removed| spanContains(removed, slot) else false),
        .collection_slice => |value| value.result == slot,
        .collection_view => |value| spanContains(value.result, slot),
        .aggregate_equal => |value| value.result == slot,
        .format_value => |value| value.result == slot,
        .string_concat => |value| value.result == slot,
        .string_count, .string_byte_count => |value| value.result == slot,
        .string_byte_at => |value| value.result == slot,
        .string_from_bytes => |value| value.result == slot,
        .function_address => |value| spanContains(value.result, slot) or
            (if (value.environment) |environment| spanContains(environment, slot) else false),
        .call => |call| if (call.result) |result| spanContains(result, slot) else false,
        .indirect_call => |call| if (call.result) |result| spanContains(result, slot) else false,
        .external_call => |call| if (call.result) |result| result == slot else false,
        .external_indirect_call => |call| if (call.result) |result| result == slot else false,
        .dynamic_call => |call| if (call.result) |result| spanContains(result, slot) else false,
        .global_store,
        .address_store,
        .reference_store,
        .class_retain,
        .class_drop,
        .list_retain,
        .list_drop,
        .string_retain,
        .string_drop,
        .print,
        .assert,
        .mutex_lock,
        .mutex_unlock,
        .panic,
        .return_value,
        .return_void,
        .jump,
        .branch,
        => false,
    };
}

pub fn spanContains(span: Machine.Span, slot: usize) bool {
    return slot >= span.start and slot < @as(usize, span.start) + span.width;
}

pub fn heavierThan(_: void, left: Interval, right: Interval) bool {
    return left.weight > right.weight or (left.weight == right.weight and left.slot < right.slot);
}
