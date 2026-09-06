const std = @import("std");
const Ir = @import("../Ir.zig");

const Definition = struct {
    instruction: ?Ir.Instruction = null,
    count: usize = 0,
};

pub fn optimize(allocator: std.mem.Allocator, program: Ir.Program) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| functions[index] = try optimizeFunction(allocator, function);
    var result = program;
    result.functions = functions;
    return result;
}

fn optimizeFunction(allocator: std.mem.Allocator, function: Ir.Function) !Ir.Function {
    const definitions = try collectDefinitions(allocator, function);
    const pruned = try removeOverwrittenStores(allocator, function, definitions);
    return forwardStoredValues(allocator, pruned, definitions);
}

fn collectDefinitions(allocator: std.mem.Allocator, function: Ir.Function) ![]Definition {
    const definitions = try allocator.alloc(Definition, function.value_types.len);
    for (definitions) |*definition| definition.* = .{};
    for (function.blocks) |block| for (block.instructions) |instruction| {
        const result = resultOf(instruction) orelse continue;
        if (result >= definitions.len) continue;
        definitions[result].instruction = instruction;
        definitions[result].count += 1;
    };
    return definitions;
}

fn removeOverwrittenStores(
    allocator: std.mem.Allocator,
    function: Ir.Function,
    definitions: []const Definition,
) !Ir.Function {
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        var overwritten: std.ArrayList(Ir.ValueId) = .empty;
        var remove = try allocator.alloc(bool, block.instructions.len);
        @memset(remove, false);
        var index = block.instructions.len;
        while (index != 0) {
            index -= 1;
            const instruction = block.instructions[index];
            switch (instruction) {
                .reference_store => |store| {
                    if (containsAddress(function, definitions, overwritten.items, store.reference)) {
                        remove[index] = true;
                    } else {
                        try overwritten.append(allocator, store.reference);
                    }
                },
                .reference_load => overwritten.clearRetainingCapacity(),
                else => if (memoryBarrier(instruction)) overwritten.clearRetainingCapacity(),
            }
        }
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions, remove) |instruction, removed| {
            if (!removed) try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn forwardStoredValues(
    allocator: std.mem.Allocator,
    function: Ir.Function,
    definitions: []const Definition,
) !Ir.Function {
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        var available: ?Ir.Instruction.ReferenceStore = null;
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |instruction| {
            var replacement = instruction;
            switch (instruction) {
                .reference_store => |store| available = store,
                .reference_load => |load| if (available) |store| {
                    if (sameAddress(function, definitions, load.reference, store.reference, definitions.len)) {
                        replacement = .{ .copy = .{ .result = load.result, .operand = store.operand } };
                    }
                },
                else => if (memoryBarrier(instruction)) {
                    available = null;
                },
            }
            try instructions.append(allocator, replacement);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn containsAddress(
    function: Ir.Function,
    definitions: []const Definition,
    addresses: []const Ir.ValueId,
    candidate: Ir.ValueId,
) bool {
    for (addresses) |address| if (sameAddress(function, definitions, address, candidate, definitions.len)) return true;
    return false;
}

fn sameAddress(
    function: Ir.Function,
    definitions: []const Definition,
    left_value: Ir.ValueId,
    right_value: Ir.ValueId,
    remaining: usize,
) bool {
    if (left_value == right_value) return true;
    if (remaining == 0 or left_value >= definitions.len or right_value >= definitions.len) return false;
    const left = uniqueDefinition(definitions, left_value) orelse return false;
    const right = uniqueDefinition(definitions, right_value) orelse return false;
    if (left == .copy and function.value_types[left_value] == .address)
        return sameAddress(function, definitions, left.copy.operand, right_value, remaining - 1);
    if (right == .copy and function.value_types[right_value] == .address)
        return sameAddress(function, definitions, left_value, right.copy.operand, remaining - 1);
    return switch (left) {
        .local_address => |left_address| switch (right) {
            .local_address => |right_address| left_address.local == right_address.local,
            else => false,
        },
        .reference_field => |left_field| switch (right) {
            .reference_field => |right_field| left_field.structure == right_field.structure and
                left_field.field == right_field.field and
                sameAddress(function, definitions, left_field.reference, right_field.reference, remaining - 1),
            else => false,
        },
        .reference_optional => |left_optional| switch (right) {
            .reference_optional => |right_optional| sameAddress(
                function,
                definitions,
                left_optional.reference,
                right_optional.reference,
                remaining - 1,
            ),
            else => false,
        },
        else => false,
    };
}

fn uniqueDefinition(definitions: []const Definition, value: Ir.ValueId) ?Ir.Instruction {
    if (value >= definitions.len or definitions[value].count != 1) return null;
    return definitions[value].instruction;
}

fn memoryBarrier(instruction: Ir.Instruction) bool {
    return switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_str,
        .constant_bytes,
        .constant_float32,
        .constant_float64,
        .storage_init,
        .optional_null,
        .optional_some,
        .optional_unwrap,
        .copy,
        .structure_init,
        .enum_init,
        .enum_test,
        .enum_payload,
        .enum_raw,
        .reference_field,
        .reference_optional,
        .local_address,
        .function_reference,
        .unary,
        .binary,
        .convert,
        .print,
        .assert,
        => false,
        else => true,
    };
}

fn resultOf(instruction: Ir.Instruction) ?Ir.ValueId {
    switch (instruction) {
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
        => return null,
        .list_edit => |edit| return edit.result,
        .call => |call| return call.result,
        .indirect_call => |call| return call.result,
        .boundary_call => |call| return call.result,
        .boundary_indirect_call => |call| return call.result,
        .dynamic_call => |call| return call.result,
        inline else => |value| return value.result,
    }
}

test "reference memory forwards exact stores and preserves possible alias observations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const function: Ir.Function = .{
        .name = "observed",
        .parameter_types = &.{ .address, .address, .int, .int },
        .return_type = .int,
        .value_types = &.{ .address, .address, .int, .int, .address, .address, .int, .address, .address, .int, .int },
        .blocks = &.{.{
            .instructions = &.{
                .{ .reference_field = .{ .result = 4, .reference = 0, .structure = 0, .field = 0 } },
                .{ .reference_store = .{ .reference = 4, .operand = 2 } },
                .{ .reference_field = .{ .result = 5, .reference = 1, .structure = 0, .field = 0 } },
                .{ .reference_load = .{ .result = 6, .reference = 5 } },
                .{ .reference_field = .{ .result = 7, .reference = 0, .structure = 0, .field = 0 } },
                .{ .reference_store = .{ .reference = 7, .operand = 3 } },
                .{ .reference_field = .{ .result = 8, .reference = 0, .structure = 0, .field = 0 } },
                .{ .reference_load = .{ .result = 9, .reference = 8 } },
                .{ .binary = .{ .result = 10, .operator = .add, .left = 6, .right = 9 } },
            },
            .terminator = .{ .return_value = 10 },
        }},
    };
    const program: Ir.Program = .{ .functions = &.{function} };
    const result = try optimize(arena.allocator(), program);
    const instructions = result.functions[0].blocks[0].instructions;
    try std.testing.expectEqual(@as(usize, 9), instructions.len);
    try std.testing.expect(instructions[3] == .reference_load);
    try std.testing.expect(instructions[7] == .copy);
    try std.testing.expectEqual(@as(Ir.ValueId, 3), instructions[7].copy.operand);
}

test "reference memory removes an exact overwritten store" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const function: Ir.Function = .{
        .name = "overwrite",
        .parameter_types = &.{ .address, .int, .int },
        .return_type = .void,
        .value_types = &.{ .address, .int, .int, .address, .address },
        .blocks = &.{.{
            .instructions = &.{
                .{ .reference_field = .{ .result = 3, .reference = 0, .structure = 0, .field = 0 } },
                .{ .reference_store = .{ .reference = 3, .operand = 1 } },
                .{ .reference_field = .{ .result = 4, .reference = 0, .structure = 0, .field = 0 } },
                .{ .reference_store = .{ .reference = 4, .operand = 2 } },
            },
            .terminator = .return_void,
        }},
    };
    const program: Ir.Program = .{ .functions = &.{function} };
    const result = try optimize(arena.allocator(), program);
    const instructions = result.functions[0].blocks[0].instructions;
    try std.testing.expectEqual(@as(usize, 3), instructions.len);
    try std.testing.expect(instructions[2] == .reference_store);
    try std.testing.expectEqual(@as(Ir.ValueId, 2), instructions[2].reference_store.operand);
}
