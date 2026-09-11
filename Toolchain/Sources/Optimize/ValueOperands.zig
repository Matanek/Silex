const std = @import("std");
const Ir = @import("../Ir.zig");
const Allocator = std.mem.Allocator;

pub fn canonical(aliases: []const Ir.ValueId, value: Ir.ValueId) Ir.ValueId {
    var current = value;
    while (aliases[current] != current) current = aliases[current];
    return current;
}

pub fn rewriteInstruction(allocator: Allocator, instruction: Ir.Instruction, aliases: []const Ir.ValueId) !Ir.Instruction {
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
        => instruction,
        .function_reference => |value| .{ .function_reference = .{
            .result = value.result,
            .function = value.function,
            .captures = try rewriteValues(allocator, value.captures, aliases),
        } },
        .string_address => |value| .{ .string_address = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
        } },
        .string_byte_count => |value| .{ .string_byte_count = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
        } },
        .string_byte_at => |value| .{ .string_byte_at = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .index = canonical(aliases, value.index),
        } },
        .string_from_bytes => |value| .{ .string_from_bytes = .{
            .result = value.result,
            .bytes = canonical(aliases, value.bytes),
        } },
        .optional_some => |value| .{ .optional_some = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .optional_unwrap => |value| .{ .optional_unwrap = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .copy => |value| .{ .copy = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .deep_copy => |value| .{ .deep_copy = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .class_cast => |value| .{ .class_cast = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .class_test => |value| .{ .class_test = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .class_retain => |value| .{ .class_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .class_drop => |value| .{ .class_drop = .{
            .operand = canonical(aliases, value.operand),
            .ownership = value.ownership,
            .skip_cycle = value.skip_cycle,
            .static_type = value.static_type,
            .plans = value.plans,
        } },
        .list_retain => |value| .{ .list_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .string_retain => |value| .{ .string_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .string_drop => |value| .{ .string_drop = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .list_drop => |value| .{ .list_drop = .{
            .operand = canonical(aliases, value.operand),
            .ownership = value.ownership,
            .deallocate = value.deallocate,
        } },
        .global_store => |value| .{ .global_store = .{ .global = value.global, .operand = canonical(aliases, value.operand) } },
        .structure_init => |value| .{ .structure_init = .{
            .result = value.result,
            .structure = value.structure,
            .fields = try rewriteValues(allocator, value.fields, aliases),
        } },
        .protocol_init => |value| .{ .protocol_init = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .protocol_test => |value| .{ .protocol_test = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .protocol_extract => |value| .{ .protocol_extract = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .list_init => |value| .{ .list_init = .{
            .result = value.result,
            .values = try rewriteValues(allocator, value.values, aliases),
        } },
        .enum_init => |value| .{ .enum_init = .{
            .result = value.result,
            .enumeration = value.enumeration,
            .variant = value.variant,
            .values = try rewriteValues(allocator, value.values, aliases),
        } },
        .enum_test => |value| .{ .enum_test = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
            .variant = value.variant,
        } },
        .enum_payload => |value| .{ .enum_payload = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
            .variant = value.variant,
            .index = value.index,
        } },
        .enum_raw => |value| .{ .enum_raw = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
        } },
        .field_load => |value| .{ .field_load = .{
            .result = value.result,
            .base = canonical(aliases, value.base),
            .field = value.field,
        } },
        .field_store => |value| .{ .field_store = .{
            .result = value.result,
            .base = canonical(aliases, value.base),
            .field = value.field,
            .replacement = canonical(aliases, value.replacement),
        } },
        .collection_load => |value| .{ .collection_load = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .index = canonical(aliases, value.index),
            .checked = value.checked,
            .position = value.position,
        } },
        .collection_reference => |value| .{ .collection_reference = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .reference = rewriteOptional(value.reference, aliases),
            .index = canonical(aliases, value.index),
            .checked = value.checked,
            .ownership = value.ownership,
            .position = value.position,
        } },
        .collection_replace => |value| .{ .collection_replace = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .index = canonical(aliases, value.index),
            .replacement = canonical(aliases, value.replacement),
            .checked = value.checked,
            .ownership = value.ownership,
            .position = value.position,
        } },
        .collection_count => |value| .{ .collection_count = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
        } },
        .list_edit => |value| .{ .list_edit = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .ownership = value.ownership,
            .kind = value.kind,
            .index = rewriteOptional(value.index, aliases),
            .argument = rewriteOptional(value.argument, aliases),
            .argument_transferred = value.argument_transferred,
            .removed = value.removed,
            .position = value.position,
        } },
        .collection_slice => |value| .{ .collection_slice = try rewriteSlice(value, aliases) },
        .collection_view => |value| .{ .collection_view = try rewriteSlice(value, aliases) },
        .local_load => |value| .{ .local_load = value },
        .local_store => |value| .{ .local_store = .{ .local = value.local, .operand = canonical(aliases, value.operand) } },
        .reference_load => |value| .{ .reference_load = .{ .result = value.result, .reference = canonical(aliases, value.reference) } },
        .address_load => |value| .{ .address_load = .{
            .result = value.result,
            .address = canonical(aliases, value.address),
            .byte_offset = canonical(aliases, value.byte_offset),
            .type = value.type,
        } },
        .address_store => |value| .{ .address_store = .{
            .address = canonical(aliases, value.address),
            .byte_offset = canonical(aliases, value.byte_offset),
            .operand = canonical(aliases, value.operand),
            .type = value.type,
        } },
        .reference_store => |value| .{ .reference_store = .{
            .reference = canonical(aliases, value.reference),
            .operand = canonical(aliases, value.operand),
        } },
        .reference_field => |value| .{ .reference_field = .{
            .result = value.result,
            .reference = canonical(aliases, value.reference),
            .structure = value.structure,
            .field = value.field,
        } },
        .reference_optional => |value| .{ .reference_optional = .{
            .result = value.result,
            .reference = canonical(aliases, value.reference),
        } },
        .convert => |value| .{ .convert = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .source = value.source,
            .target = value.target,
            .position = value.position,
            .checked = value.checked,
        } },
        .format_value => |value| .{ .format_value = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .string_concat => |value| .{ .string_concat = .{
            .result = value.result,
            .left = canonical(aliases, value.left),
            .right = canonical(aliases, value.right),
        } },
        .string_count => |value| .{ .string_count = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .unary => |value| .{ .unary = .{
            .result = value.result,
            .operator = value.operator,
            .operand = canonical(aliases, value.operand),
        } },
        .binary => |value| .{ .binary = .{
            .result = value.result,
            .operator = value.operator,
            .left = canonical(aliases, value.left),
            .right = canonical(aliases, value.right),
            .checked = value.checked,
            .left_non_negative = value.left_non_negative,
        } },
        .call => |value| .{ .call = .{
            .result = value.result,
            .function = value.function,
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .indirect_call => |value| .{ .indirect_call = .{
            .result = value.result,
            .callee = canonical(aliases, value.callee),
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .boundary_call => |value| .{ .boundary_call = .{
            .result = value.result,
            .function = value.function,
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .boundary_indirect_call => |value| .{ .boundary_indirect_call = .{
            .result = value.result,
            .callee = canonical(aliases, value.callee),
            .signature = value.signature,
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .dynamic_call => |value| .{ .dynamic_call = .{
            .result = value.result,
            .function = value.function,
            .receiver = canonical(aliases, value.receiver),
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
            .implementations = value.implementations,
        } },
        .print => |value| .{ .print = .{ .value = canonical(aliases, value.value), .newline = value.newline } },
        .assert => |value| .{ .assert = .{
            .condition = canonical(aliases, value.condition),
            .message = canonical(aliases, value.message),
            .position = value.position,
        } },
    };
}

fn rewriteSlice(value: Ir.Instruction.CollectionSlice, aliases: []const Ir.ValueId) !Ir.Instruction.CollectionSlice {
    return .{
        .result = value.result,
        .collection = canonical(aliases, value.collection),
        .start = canonical(aliases, value.start),
        .end = canonical(aliases, value.end),
        .reference = rewriteOptional(value.reference, aliases),
    };
}

fn rewriteValues(allocator: Allocator, values: []const Ir.ValueId, aliases: []const Ir.ValueId) ![]const Ir.ValueId {
    const rewritten = try allocator.alloc(Ir.ValueId, values.len);
    for (values, 0..) |value, index| rewritten[index] = canonical(aliases, value);
    return rewritten;
}

fn rewriteOptional(value: ?Ir.ValueId, aliases: []const Ir.ValueId) ?Ir.ValueId {
    return if (value) |present| canonical(aliases, present) else null;
}

pub fn countUses(instruction: Ir.Instruction, uses: []usize) void {
    switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_str,
        .constant_bytes,
        .constant_float32,
        .constant_float64,
        .optional_null,
        .global_load,
        .storage_init,
        .local_load,
        .local_address,
        => {},
        .function_reference => |value| useValues(uses, value.captures),
        .optional_some => |value| useValue(uses, value.operand),
        .optional_unwrap => |value| useValue(uses, value.operand),
        .copy => |value| useValue(uses, value.operand),
        .deep_copy => |value| useValue(uses, value.operand),
        .class_cast => |value| useValue(uses, value.operand),
        .class_test => |value| useValue(uses, value.operand),
        .class_retain => |value| useValue(uses, value.operand),
        .class_drop => |value| useValue(uses, value.operand),
        .list_retain, .list_drop, .string_retain, .string_drop => |value| useValue(uses, value.operand),
        .global_store => |value| useValue(uses, value.operand),
        .structure_init => |value| useValues(uses, value.fields),
        .protocol_init => |value| useValue(uses, value.operand),
        .protocol_test => |value| useValue(uses, value.operand),
        .protocol_extract => |value| useValue(uses, value.operand),
        .list_init => |value| useValues(uses, value.values),
        .enum_init => |value| useValues(uses, value.values),
        .enum_test => |value| useValue(uses, value.operand),
        .enum_payload => |value| useValue(uses, value.operand),
        .enum_raw => |value| useValue(uses, value.operand),
        .field_load => |value| useValue(uses, value.base),
        .field_store => |value| {
            useValue(uses, value.base);
            useValue(uses, value.replacement);
        },
        .collection_load => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.index);
        },
        .collection_reference => |value| {
            useValue(uses, value.collection);
            useOptional(uses, value.reference);
            useValue(uses, value.index);
        },
        .collection_replace => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.index);
            useValue(uses, value.replacement);
        },
        .collection_count => |value| useValue(uses, value.collection),
        .list_edit => |value| {
            useValue(uses, value.collection);
            useOptional(uses, value.index);
            useOptional(uses, value.argument);
        },
        .collection_slice, .collection_view => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.start);
            useValue(uses, value.end);
            useOptional(uses, value.reference);
        },
        .string_address, .string_byte_count => |value| useValue(uses, value.operand),
        .string_byte_at => |value| {
            useValue(uses, value.operand);
            useValue(uses, value.index);
        },
        .string_from_bytes => |value| useValue(uses, value.bytes),
        .local_store => |value| useValue(uses, value.operand),
        .reference_load => |value| useValue(uses, value.reference),
        .address_load => |value| {
            useValue(uses, value.address);
            useValue(uses, value.byte_offset);
        },
        .address_store => |value| {
            useValue(uses, value.address);
            useValue(uses, value.byte_offset);
            useValue(uses, value.operand);
        },
        .reference_store => |value| {
            useValue(uses, value.reference);
            useValue(uses, value.operand);
        },
        .reference_field => |value| useValue(uses, value.reference),
        .reference_optional => |value| useValue(uses, value.reference),
        .convert => |value| useValue(uses, value.operand),
        .format_value => |value| useValue(uses, value.operand),
        .string_concat => |value| {
            useValue(uses, value.left);
            useValue(uses, value.right);
        },
        .string_count => |value| useValue(uses, value.operand),
        .unary => |value| useValue(uses, value.operand),
        .binary => |value| {
            useValue(uses, value.left);
            useValue(uses, value.right);
        },
        .call => |value| useValues(uses, value.arguments),
        .indirect_call => |value| {
            useValue(uses, value.callee);
            useValues(uses, value.arguments);
        },
        .boundary_call => |value| useValues(uses, value.arguments),
        .boundary_indirect_call => |value| {
            useValue(uses, value.callee);
            useValues(uses, value.arguments);
        },
        .dynamic_call => |value| {
            useValue(uses, value.receiver);
            useValues(uses, value.arguments);
        },
        .print => |value| useValue(uses, value.value),
        .assert => |value| {
            useValue(uses, value.condition);
            useValue(uses, value.message);
        },
        .mutex_lock, .mutex_unlock => {},
    }
}

pub fn countTerminatorUses(terminator: Ir.Terminator, uses: []usize) void {
    switch (terminator) {
        .return_value => |value| useValue(uses, value),
        .branch => |value| useValue(uses, value.condition),
        .panic => |value| useValue(uses, value.message),
        else => {},
    }
}

fn useValue(uses: []usize, value: Ir.ValueId) void {
    uses[value] += 1;
}

fn useValues(uses: []usize, values: []const Ir.ValueId) void {
    for (values) |value| useValue(uses, value);
}

fn useOptional(uses: []usize, value: ?Ir.ValueId) void {
    if (value) |present| useValue(uses, present);
}

pub fn instructionResult(instruction: Ir.Instruction) ?Ir.ValueId {
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
        .list_edit => |value| value.result,
        .call => |value| value.result,
        .indirect_call => |value| value.result,
        .boundary_call => |value| value.result,
        .boundary_indirect_call => |value| value.result,
        .dynamic_call => |value| value.result,
        inline else => |value| value.result,
    };
}
