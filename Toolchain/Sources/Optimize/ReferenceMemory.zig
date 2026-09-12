const std = @import("std");
const Ir = @import("../Ir.zig");
const KnownCollections = @import("KnownCollections.zig");
const PrivateClassState = @import("PrivateClassState.zig");

const Definition = struct {
    instruction: ?Ir.Instruction = null,
    count: usize = 0,
};

pub fn optimize(allocator: std.mem.Allocator, program: Ir.Program) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| functions[index] = try optimizeFunction(allocator, program, function);
    var result = program;
    result.functions = functions;
    return result;
}

fn optimizeFunction(allocator: std.mem.Allocator, program: Ir.Program, function: Ir.Function) !Ir.Function {
    const definitions = try collectDefinitions(allocator, function);
    const pruned = try removeOverwrittenStores(allocator, function, definitions);
    const forwarded = try forwardStoredValues(allocator, pruned, definitions);
    const views = try simplifyExactViewStores(allocator, program, forwarded);
    const collections = try KnownCollections.optimize(allocator, program, views);
    return PrivateClassState.optimize(allocator, program, collections);
}

const ViewStore = struct {
    instruction: usize,
    collection: Ir.ValueId,
    index: Ir.ValueId,
    replacement: Ir.ValueId,
};

fn simplifyExactViewStores(allocator: std.mem.Allocator, program: Ir.Program, function: Ir.Function) !Ir.Function {
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
        for (aliases, 0..) |*alias, value| alias.* = value;
        const instructions = try allocator.dupe(Ir.Instruction, block.instructions);
        var available: ?ViewStore = null;
        for (instructions, 0..) |*instruction, instruction_index| switch (instruction.*) {
            .collection_replace => |replacement| {
                if (!isScalarViewStore(program, function, replacement)) {
                    available = null;
                    continue;
                }
                const collection = canonical(aliases, replacement.collection);
                const index = canonical(aliases, replacement.index);
                instruction.collection_replace.collection = collection;
                instruction.collection_replace.index = index;
                if (available) |previous| {
                    if (previous.collection == collection and previous.index == index) {
                        const overwritten = instructions[previous.instruction].collection_replace;
                        instructions[previous.instruction] = .{ .copy = .{
                            .result = overwritten.result,
                            .operand = overwritten.collection,
                        } };
                    }
                }
                aliases[replacement.result] = collection;
                available = .{
                    .instruction = instruction_index,
                    .collection = collection,
                    .index = index,
                    .replacement = canonical(aliases, replacement.replacement),
                };
            },
            .collection_load => |load| {
                const store = available orelse continue;
                if (canonical(aliases, load.collection) != store.collection or
                    canonical(aliases, load.index) != store.index or
                    function.value_types[load.result] != function.value_types[store.replacement])
                {
                    available = null;
                    continue;
                }
                instruction.* = .{ .copy = .{ .result = load.result, .operand = store.replacement } };
                aliases[load.result] = store.replacement;
            },
            else => available = null,
        };
        blocks[block_index] = .{
            .instructions = instructions,
            .instruction_positions = block.instruction_positions,
            .terminator = block.terminator,
            .terminator_position = block.terminator_position,
        };
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn isScalarViewStore(program: Ir.Program, function: Ir.Function, replacement: Ir.Instruction.CollectionReplace) bool {
    if (replacement.ownership != .root or
        replacement.collection >= function.value_types.len or
        replacement.result >= function.value_types.len or
        replacement.index >= function.value_types.len or
        replacement.replacement >= function.value_types.len)
    {
        return false;
    }
    const collection_type = function.value_types[replacement.collection];
    const element_type = function.value_types[replacement.replacement];
    const structure = collection_type.structureIndex() orelse return false;
    if (structure >= program.structures.len) return false;
    const collection = program.structures[structure].collection orelse return false;
    return collection_type == function.value_types[replacement.result] and
        function.value_types[replacement.index] == .int and
        collection.view and collection.element == element_type and
        (element_type.isNumeric() or element_type == .bool);
}

fn canonical(aliases: []const Ir.ValueId, initial: Ir.ValueId) Ir.ValueId {
    if (initial >= aliases.len) return initial;
    var value = initial;
    var remaining = aliases.len;
    while (aliases[value] != value and remaining != 0) : (remaining -= 1) value = aliases[value];
    return value;
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

test "view memory preserves a store observed through a possibly aliasing view" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const position: @import("../Source.zig").Position = .{ .offset = 0, .line = 1, .column = 1 };
    const view_type = Ir.Type.structure(0);
    const function: Ir.Function = .{
        .name = "observed_view",
        .parameter_types = &.{ view_type, view_type, .int, .int, .int },
        .return_type = .int,
        .value_types = &.{ view_type, view_type, .int, .int, .int, view_type, .int, view_type, .int, .int },
        .blocks = &.{.{
            .instructions = &.{
                .{ .collection_replace = .{ .result = 5, .collection = 0, .index = 2, .replacement = 3, .position = position } },
                .{ .collection_load = .{ .result = 6, .collection = 1, .index = 2, .position = position } },
                .{ .collection_replace = .{ .result = 7, .collection = 5, .index = 2, .replacement = 4, .position = position } },
                .{ .collection_load = .{ .result = 8, .collection = 7, .index = 2, .position = position } },
                .{ .binary = .{ .result = 9, .operator = .add, .left = 6, .right = 8 } },
            },
            .terminator = .{ .return_value = 9 },
        }},
    };
    const program: Ir.Program = .{
        .structures = &.{.{
            .name = "int[..]",
            .fields = &.{},
            .collection = .{ .element = .int, .length = null, .view = true },
        }},
        .functions = &.{function},
    };
    const result = try optimize(arena.allocator(), program);
    const instructions = result.functions[0].blocks[0].instructions;
    try std.testing.expect(instructions[0] == .collection_replace);
    try std.testing.expect(instructions[1] == .collection_load);
    try std.testing.expect(instructions[2] == .collection_replace);
    try std.testing.expect(instructions[3] == .copy);
    try std.testing.expectEqual(@as(Ir.ValueId, 4), instructions[3].copy.operand);
}

test "view memory does not coalesce owning collection replacements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const position: @import("../Source.zig").Position = .{ .offset = 0, .line = 1, .column = 1 };
    const list_type = Ir.Type.structure(0);
    const function: Ir.Function = .{
        .name = "owning_values",
        .parameter_types = &.{ list_type, .int, .int, .int },
        .return_type = .int,
        .value_types = &.{ list_type, .int, .int, .int, list_type, list_type, .int },
        .blocks = &.{.{
            .instructions = &.{
                .{ .collection_replace = .{ .result = 4, .collection = 0, .index = 1, .replacement = 2, .position = position } },
                .{ .collection_replace = .{ .result = 5, .collection = 4, .index = 1, .replacement = 3, .position = position } },
                .{ .collection_load = .{ .result = 6, .collection = 5, .index = 1, .position = position } },
            },
            .terminator = .{ .return_value = 6 },
        }},
    };
    const program: Ir.Program = .{
        .structures = &.{.{
            .name = "int[]",
            .fields = &.{},
            .collection = .{ .element = .int, .length = null, .view = false },
        }},
        .functions = &.{function},
    };
    const result = try optimize(arena.allocator(), program);
    const instructions = result.functions[0].blocks[0].instructions;
    try std.testing.expectEqual(@as(usize, 3), instructions.len);
    try std.testing.expect(instructions[0] == .collection_replace);
    try std.testing.expect(instructions[1] == .collection_replace);
    try std.testing.expect(instructions[2] == .collection_load);
}

test "owning collection values forward known literal and replacement elements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const position: @import("../Source.zig").Position = .{ .offset = 0, .line = 1, .column = 1 };
    const list_type = Ir.Type.structure(0);
    const function: Ir.Function = .{
        .name = "known_values",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{ .int, .int, .int, list_type, .int, .int, list_type, .int, .int, .int },
        .blocks = &.{.{
            .instructions = &.{
                .{ .constant_int = .{ .result = 0, .bits = 3 } },
                .{ .constant_int = .{ .result = 1, .bits = 5 } },
                .{ .constant_int = .{ .result = 2, .bits = 8 } },
                .{ .list_init = .{ .result = 3, .values = &.{ 0, 1, 2 } } },
                .{ .constant_int = .{ .result = 4, .bits = 1 } },
                .{ .constant_int = .{ .result = 5, .bits = 13 } },
                .{ .collection_replace = .{ .result = 6, .collection = 3, .index = 4, .replacement = 5, .position = position } },
                .{ .collection_load = .{ .result = 7, .collection = 3, .index = 4, .position = position } },
                .{ .collection_load = .{ .result = 8, .collection = 6, .index = 4, .position = position } },
                .{ .binary = .{ .result = 9, .operator = .add, .left = 7, .right = 8 } },
            },
            .terminator = .{ .return_value = 9 },
        }},
    };
    const program: Ir.Program = .{
        .structures = &.{.{
            .name = "int[]",
            .fields = &.{},
            .collection = .{ .element = .int, .length = null, .view = false },
        }},
        .functions = &.{function},
    };
    const result = try optimize(arena.allocator(), program);
    const instructions = result.functions[0].blocks[0].instructions;
    try std.testing.expect(instructions[7] == .copy);
    try std.testing.expectEqual(@as(Ir.ValueId, 1), instructions[7].copy.operand);
    try std.testing.expect(instructions[8] == .copy);
    try std.testing.expectEqual(@as(Ir.ValueId, 5), instructions[8].copy.operand);
    try std.testing.expect(instructions[6] == .collection_replace);
    try std.testing.expect(!instructions[6].collection_replace.checked);
}

test "owning collection replacement retains an unproved bounds failure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const position: @import("../Source.zig").Position = .{ .offset = 0, .line = 1, .column = 1 };
    const list_type = Ir.Type.structure(0);
    const function: Ir.Function = .{
        .name = "invalid_replace",
        .parameter_types = &.{},
        .return_type = list_type,
        .value_types = &.{ .int, .int, .int, list_type, .int, .int, list_type },
        .blocks = &.{.{
            .instructions = &.{
                .{ .constant_int = .{ .result = 0, .bits = 3 } },
                .{ .constant_int = .{ .result = 1, .bits = 5 } },
                .{ .constant_int = .{ .result = 2, .bits = 8 } },
                .{ .list_init = .{ .result = 3, .values = &.{ 0, 1, 2 } } },
                .{ .constant_int = .{ .result = 4, .bits = @bitCast(@as(i64, -4)) } },
                .{ .constant_int = .{ .result = 5, .bits = 13 } },
                .{ .collection_replace = .{ .result = 6, .collection = 3, .index = 4, .replacement = 5, .position = position } },
            },
            .terminator = .{ .return_value = 6 },
        }},
    };
    const program: Ir.Program = .{
        .structures = &.{.{
            .name = "int[]",
            .fields = &.{},
            .collection = .{ .element = .int, .length = null, .view = false },
        }},
        .functions = &.{function},
    };
    const result = try optimize(arena.allocator(), program);
    try std.testing.expect(result.functions[0].blocks[0].instructions[6].collection_replace.checked);
}
