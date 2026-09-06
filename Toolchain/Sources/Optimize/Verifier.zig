const std = @import("std");
const Ir = @import("../Ir.zig");

const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || Ir.Error || error{
    InvalidDefinition,
    MissingDefinition,
    DefinitionDoesNotDominateUse,
    InvalidPhi,
};

const Location = struct {
    block: Ir.BlockId,
    instruction: usize,
};

/// Validate the portable IR contract relied upon by every Release pass.
/// `Ir.writeText` owns the complete type, ownership, width and reference
/// checks. This verifier adds the CFG facts that serialization cannot prove.
pub fn verify(allocator: Allocator, program: Ir.Program) Error!void {
    var validation_arena = std.heap.ArenaAllocator.init(allocator);
    defer validation_arena.deinit();
    _ = try Ir.writeText(validation_arena.allocator(), program);
    for (program.functions) |function| try verifyFunction(allocator, program, function);
}

pub fn verifyFunction(allocator: Allocator, program: Ir.Program, function: Ir.Function) Error!void {
    if (function.blocks.len == 0 or
        function.capture_types.len + function.parameter_types.len > function.value_types.len)
    {
        return error.InvalidProgram;
    }
    for (function.capture_types, 0..) |type_value, index| {
        if (function.value_types[index] != type_value) return error.InvalidProgram;
    }
    for (function.parameter_types, 0..) |type_value, index| {
        if (function.value_types[function.capture_types.len + index] != type_value) return error.InvalidProgram;
    }

    const value_count = function.value_types.len;
    const initial_count = function.capture_types.len + function.parameter_types.len;
    const definition_counts = try allocator.alloc(usize, value_count);
    defer allocator.free(definition_counts);
    @memset(definition_counts, 0);
    const first_definitions = try allocator.alloc(?Location, value_count);
    defer allocator.free(first_definitions);
    @memset(first_definitions, null);
    for (0..initial_count) |value| definition_counts[value] = 1;

    for (function.blocks, 0..) |block, block_index| {
        for (block.instructions, 0..) |instruction, instruction_index| {
            try verifyInstructionType(program, function, instruction);
            if (instructionResult(instruction)) |result| {
                if (result >= value_count) return error.InvalidProgram;
                definition_counts[result] += 1;
                if (first_definitions[result] == null) first_definitions[result] = .{
                    .block = block_index,
                    .instruction = instruction_index,
                };
            }
            if (instructionSecondaryResult(instruction)) |result| {
                if (result >= value_count) return error.InvalidProgram;
                definition_counts[result] += 1;
                if (first_definitions[result] == null) first_definitions[result] = .{
                    .block = block_index,
                    .instruction = instruction_index,
                };
            }
        }
    }

    const predecessors = try predecessorMatrix(allocator, function);
    defer allocator.free(predecessors);
    const dominators = try dominatorMatrix(allocator, function, predecessors);
    defer allocator.free(dominators);
    const multiple_definition_entries = try allocator.alloc(bool, value_count * function.blocks.len);
    defer allocator.free(multiple_definition_entries);
    @memset(multiple_definition_entries, false);
    for (0..initial_count) |value| if (definition_counts[value] != 1) return error.InvalidDefinition;
    for (initial_count..value_count) |value| {
        if (definition_counts[value] > 1) {
            try validateMultipleDefinitions(
                allocator,
                function,
                predecessors,
                value,
                multiple_definition_entries[value * function.blocks.len ..][0..function.blocks.len],
            );
        }
    }

    for (function.blocks, 0..) |block, block_index| {
        for (block.instructions, 0..) |instruction, instruction_index| {
            try verifyInstructionUses(
                function,
                definition_counts,
                first_definitions,
                multiple_definition_entries,
                dominators,
                instruction,
                .{ .block = block_index, .instruction = instruction_index },
            );
        }
        try verifyTerminatorUses(
            function,
            definition_counts,
            first_definitions,
            multiple_definition_entries,
            dominators,
            block.terminator,
            .{ .block = block_index, .instruction = block.instructions.len },
        );
        try verifyTerminatorType(function, block.terminator);
    }
}

pub fn verifyInstructionType(program: Ir.Program, function: Ir.Function, instruction: Ir.Instruction) Error!void {
    const types = function.value_types;
    switch (instruction) {
        .constant_int => |value| {
            const result_type = types[value.result];
            if (!result_type.isInteger() and result_type != .address and result_type.functionIndex() == null)
                return error.InvalidProgram;
        },
        .constant_bool => |value| if (types[value.result] == .bool) {} else return error.InvalidProgram,
        .constant_str => |value| if (types[value.result] == .str) {} else return error.InvalidProgram,
        .constant_float32 => |value| if (types[value.result] == .float32) {} else return error.InvalidProgram,
        .constant_float64 => |value| if (types[value.result] == .float64) {} else return error.InvalidProgram,
        // A plain copy is also the explicit representation bridge used by
        // C.address_bits, C.pointer_bits, C.function_address and
        // C.object_from_address. Ir.writeText validates both value ids; only
        // deep copies promise to preserve the declared Silex type.
        .copy => {},
        .deep_copy => |value| if (types[value.result] == types[value.operand]) {} else return error.InvalidProgram,
        inline .class_retain, .class_drop => |value| {
            const structure = types[value.operand].structureIndex() orelse return error.InvalidProgram;
            if (structure >= program.structures.len or !program.structures[structure].is_class)
                return error.InvalidProgram;
        },
        inline .list_retain, .list_drop => |value| {
            const structure = types[value.operand].structureIndex() orelse return error.InvalidProgram;
            if (structure >= program.structures.len) return error.InvalidProgram;
            const collection = program.structures[structure].collection orelse return error.InvalidProgram;
            if (collection.length != null or collection.view) return error.InvalidProgram;
        },
        inline .string_retain, .string_drop => |value| if (types[value.operand] == .str) {} else return error.InvalidProgram,
        .unary => |value| {
            if (!types[value.operand].isNumeric() or types[value.result] != types[value.operand])
                return error.InvalidProgram;
        },
        .binary => |value| {
            if (value.operator == .shift_left or value.operator == .shift_right) {
                if (!types[value.left].isInteger() or !types[value.right].isInteger() or
                    types[value.result] != types[value.left]) return error.InvalidProgram;
                return;
            }
            if (types[value.left] != types[value.right]) return error.InvalidProgram;
            const comparison = switch (value.operator) {
                .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => true,
                else => false,
            };
            if (types[value.result] != if (comparison) Ir.Type.bool else types[value.left])
                return error.InvalidProgram;
        },
        .call => |value| try verifyCall(function, program.functions[value.function], value.result, value.arguments),
        .indirect_call => |value| {
            const signature_index = types[value.callee].functionIndex() orelse return error.InvalidProgram;
            if (signature_index >= program.function_types.len) return error.InvalidProgram;
            try verifySignature(function, program.function_types[signature_index], value.result, value.arguments);
        },
        .boundary_indirect_call => |value| {
            if (value.signature >= program.function_types.len) return error.InvalidProgram;
            try verifySignature(function, program.function_types[value.signature], value.result, value.arguments);
        },
        .dynamic_call => |value| {
            if (value.function >= program.functions.len) return error.InvalidProgram;
            try verifyCall(function, program.functions[value.function], value.result, value.arguments);
            for (value.implementations) |implementation| {
                if (implementation.structure >= program.structures.len or implementation.function >= program.functions.len)
                    return error.InvalidProgram;
            }
        },
        .assert => |value| {
            if (types[value.condition] != .bool or types[value.message] != .str) return error.InvalidProgram;
        },
        else => {},
    }
}

fn verifyCall(
    caller: Ir.Function,
    callee: Ir.Function,
    result: ?Ir.ValueId,
    arguments: []const Ir.ValueId,
) Error!void {
    try verifyArguments(caller, callee.parameter_types, arguments);
    try verifyCallResult(caller, callee.return_type, result);
}

fn verifySignature(
    caller: Ir.Function,
    signature: Ir.FunctionType,
    result: ?Ir.ValueId,
    arguments: []const Ir.ValueId,
) Error!void {
    try verifyArguments(caller, signature.parameter_types, arguments);
    try verifyCallResult(caller, signature.return_type, result);
}

fn verifyArguments(caller: Ir.Function, expected: []const Ir.Type, arguments: []const Ir.ValueId) Error!void {
    if (arguments.len != expected.len) return error.InvalidProgram;
    for (arguments, expected) |argument, type_value| {
        if (argument >= caller.value_types.len or caller.value_types[argument] != type_value)
            return error.InvalidProgram;
    }
}

fn verifyCallResult(caller: Ir.Function, return_type: Ir.Type, result: ?Ir.ValueId) Error!void {
    if (return_type == .void) {
        if (result != null) return error.InvalidProgram;
    } else {
        const value = result orelse return error.InvalidProgram;
        if (value >= caller.value_types.len or caller.value_types[value] != return_type)
            return error.InvalidProgram;
    }
}

pub fn verifyTerminatorType(function: Ir.Function, terminator: Ir.Terminator) Error!void {
    switch (terminator) {
        .return_value => |value| {
            if (function.return_type == .void or function.value_types[value] != function.return_type)
                return error.InvalidProgram;
        },
        .return_void => if (function.return_type != .void) return error.InvalidProgram,
        .branch => |value| if (function.value_types[value.condition] != .bool) return error.InvalidProgram,
        .panic => |value| if (function.value_types[value.message] != .str) return error.InvalidProgram,
        .jump => {},
    }
}

fn predecessorMatrix(allocator: Allocator, function: Ir.Function) Error![]bool {
    const block_count = function.blocks.len;
    const result = try allocator.alloc(bool, block_count * block_count);
    @memset(result, false);
    for (function.blocks, 0..) |block, source| switch (block.terminator) {
        .jump => |target| {
            if (target >= block_count) return error.InvalidProgram;
            result[target * block_count + source] = true;
        },
        .branch => |branch_value| {
            if (branch_value.then_block >= block_count or branch_value.else_block >= block_count)
                return error.InvalidProgram;
            result[branch_value.then_block * block_count + source] = true;
            result[branch_value.else_block * block_count + source] = true;
        },
        else => {},
    };
    return result;
}

fn dominatorMatrix(
    allocator: Allocator,
    function: Ir.Function,
    predecessors: []const bool,
) Error![]bool {
    const block_count = function.blocks.len;
    const reachable = try allocator.alloc(bool, block_count);
    defer allocator.free(reachable);
    @memset(reachable, false);
    reachable[0] = true;
    var reachability_changed = true;
    while (reachability_changed) {
        reachability_changed = false;
        for (function.blocks, 0..) |block, source| {
            if (!reachable[source]) continue;
            switch (block.terminator) {
                .jump => |target| {
                    if (!reachable[target]) {
                        reachable[target] = true;
                        reachability_changed = true;
                    }
                },
                .branch => |branch_value| {
                    if (!reachable[branch_value.then_block]) {
                        reachable[branch_value.then_block] = true;
                        reachability_changed = true;
                    }
                    if (!reachable[branch_value.else_block]) {
                        reachable[branch_value.else_block] = true;
                        reachability_changed = true;
                    }
                },
                else => {},
            }
        }
    }
    const result = try allocator.alloc(bool, block_count * block_count);
    @memset(result, true);
    for (0..block_count) |candidate| result[candidate] = candidate == 0;
    for (1..block_count) |block| if (!reachable[block]) {
        for (0..block_count) |candidate| result[block * block_count + candidate] = candidate == block;
    };

    var changed = true;
    while (changed) {
        changed = false;
        for (1..block_count) |block| {
            if (!reachable[block]) continue;
            var has_predecessor = false;
            for (0..block_count) |candidate| {
                var dominated = true;
                for (0..block_count) |predecessor| {
                    if (!reachable[predecessor] or !predecessors[block * block_count + predecessor]) continue;
                    has_predecessor = true;
                    dominated = dominated and result[predecessor * block_count + candidate];
                }
                if (!has_predecessor) dominated = false;
                if (candidate == block) dominated = true;
                const index = block * block_count + candidate;
                if (result[index] != dominated) {
                    result[index] = dominated;
                    changed = true;
                }
            }
        }
    }
    return result;
}

fn reachableBlocks(allocator: Allocator, function: Ir.Function) Error![]bool {
    const reachable = try allocator.alloc(bool, function.blocks.len);
    @memset(reachable, false);
    reachable[0] = true;
    var changed = true;
    while (changed) {
        changed = false;
        for (function.blocks, 0..) |block, source| {
            if (!reachable[source]) continue;
            switch (block.terminator) {
                .jump => |target| {
                    if (!reachable[target]) {
                        reachable[target] = true;
                        changed = true;
                    }
                },
                .branch => |branch_value| {
                    if (!reachable[branch_value.then_block]) {
                        reachable[branch_value.then_block] = true;
                        changed = true;
                    }
                    if (!reachable[branch_value.else_block]) {
                        reachable[branch_value.else_block] = true;
                        changed = true;
                    }
                },
                else => {},
            }
        }
    }
    return reachable;
}

fn validateMultipleDefinitions(
    allocator: Allocator,
    function: Ir.Function,
    predecessors: []const bool,
    value: Ir.ValueId,
    definite_entry: []bool,
) Error!void {
    const block_count = function.blocks.len;
    const reachable = try reachableBlocks(allocator, function);
    defer allocator.free(reachable);
    const block_defines = try allocator.alloc(bool, block_count);
    defer allocator.free(block_defines);
    @memset(block_defines, false);
    for (function.blocks, 0..) |block, block_index| {
        for (block.instructions) |instruction| {
            if (instructionResult(instruction) != value and instructionSecondaryResult(instruction) != value) continue;
            if (block_defines[block_index]) return error.InvalidDefinition;
            block_defines[block_index] = true;
        }
    }
    const definite_exit = try allocator.alloc(bool, block_count);
    defer allocator.free(definite_exit);
    for (0..block_count) |block| {
        definite_entry[block] = reachable[block] and block != 0;
        definite_exit[block] = definite_entry[block] or block_defines[block];
    }
    var changed = true;
    while (changed) {
        changed = false;
        for (0..block_count) |block| {
            if (!reachable[block]) continue;
            var next_entry = false;
            if (block != 0) {
                next_entry = true;
                var has_predecessor = false;
                for (0..block_count) |predecessor| {
                    if (!reachable[predecessor] or !predecessors[block * block_count + predecessor]) continue;
                    has_predecessor = true;
                    next_entry = next_entry and definite_exit[predecessor];
                }
                if (!has_predecessor) next_entry = false;
            }
            const next_exit = next_entry or block_defines[block];
            if (definite_entry[block] != next_entry or definite_exit[block] != next_exit) {
                definite_entry[block] = next_entry;
                definite_exit[block] = next_exit;
                changed = true;
            }
        }
    }
}

test "verifier accepts direct constants as complete lowered phi definitions" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "constant_phi",
        .parameter_types = &.{.bool},
        .return_type = .bool,
        .value_types = &.{ .bool, .bool },
        .blocks = &.{
            .{ .instructions = &.{}, .terminator = .{ .branch = .{ .condition = 0, .then_block = 1, .else_block = 2 } } },
            .{ .instructions = &.{.{ .constant_bool = .{ .result = 1, .value = true } }}, .terminator = .{ .jump = 3 } },
            .{ .instructions = &.{.{ .constant_bool = .{ .result = 1, .value = false } }}, .terminator = .{ .jump = 3 } },
            .{ .instructions = &.{}, .terminator = .{ .return_value = 1 } },
        },
    }} };
    try verify(std.testing.allocator, program);
}

test "verifier ignores unreachable predecessors when proving dominance" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "unreachable_predecessor",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{.int},
        .blocks = &.{
            .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
            .{ .instructions = &.{.{ .constant_int = .{ .result = 0, .bits = 42 } }}, .terminator = .{ .jump = 3 } },
            .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
            .{ .instructions = &.{}, .terminator = .{ .return_value = 0 } },
        },
    }} };
    try verify(std.testing.allocator, program);
}

fn verifyUse(
    function: Ir.Function,
    definition_counts: []const usize,
    first_definitions: []const ?Location,
    multiple_definition_entries: []const bool,
    dominators: []const bool,
    value: Ir.ValueId,
    use: Location,
) Error!void {
    if (value >= function.value_types.len) return error.InvalidProgram;
    if (definition_counts[value] == 0) return error.MissingDefinition;
    const block_count = function.blocks.len;
    if (definition_counts[value] > 1) {
        if (multiple_definition_entries[value * block_count + use.block] or
            definedBeforeUse(function, value, use)) return;
        return error.DefinitionDoesNotDominateUse;
    }
    const definition = first_definitions[value] orelse return;
    if (definition.block == use.block) {
        if (definition.instruction >= use.instruction) {
            return error.DefinitionDoesNotDominateUse;
        }
    } else if (!dominators[use.block * block_count + definition.block]) {
        return error.DefinitionDoesNotDominateUse;
    }
}

fn definedBeforeUse(function: Ir.Function, value: Ir.ValueId, use: Location) bool {
    for (function.blocks[use.block].instructions[0..use.instruction]) |instruction| {
        if (instructionResult(instruction) == value or instructionSecondaryResult(instruction) == value) return true;
    }
    return false;
}

fn verifyInstructionUses(
    function: Ir.Function,
    definition_counts: []const usize,
    first_definitions: []const ?Location,
    multiple_definition_entries: []const bool,
    dominators: []const bool,
    instruction: Ir.Instruction,
    location: Location,
) Error!void {
    const Context = struct {
        function: Ir.Function,
        definition_counts: []const usize,
        first_definitions: []const ?Location,
        multiple_definition_entries: []const bool,
        dominators: []const bool,
        location: Location,

        fn one(self: @This(), value: Ir.ValueId) Error!void {
            try verifyUse(
                self.function,
                self.definition_counts,
                self.first_definitions,
                self.multiple_definition_entries,
                self.dominators,
                value,
                self.location,
            );
        }
        fn many(self: @This(), values: []const Ir.ValueId) Error!void {
            for (values) |value| try self.one(value);
        }
        fn optional(self: @This(), value: ?Ir.ValueId) Error!void {
            if (value) |present| try self.one(present);
        }
    };
    const context: Context = .{
        .function = function,
        .definition_counts = definition_counts,
        .first_definitions = first_definitions,
        .multiple_definition_entries = multiple_definition_entries,
        .dominators = dominators,
        .location = location,
    };
    switch (instruction) {
        .constant_int, .constant_bool, .constant_str, .constant_bytes, .constant_float32, .constant_float64, .optional_null, .global_load, .storage_init, .local_load, .local_address, .mutex_lock, .mutex_unlock => {},
        .function_reference => |value| try context.many(value.captures),
        inline .optional_some, .optional_unwrap, .copy, .deep_copy, .class_cast, .class_retain, .class_drop, .list_retain, .list_drop, .string_retain, .string_drop, .global_store, .protocol_init, .protocol_test, .protocol_extract, .enum_test, .enum_payload, .enum_raw, .string_address, .string_byte_count, .convert, .format_value, .string_count, .unary => |value| try context.one(value.operand),
        .field_load => |value| try context.one(value.base),
        .string_from_bytes => |value| try context.one(value.bytes),
        .local_store => |value| try context.one(value.operand),
        .reference_load => |value| try context.one(value.reference),
        .reference_field => |value| try context.one(value.reference),
        .reference_optional => |value| try context.one(value.reference),
        .print => |value| try context.one(value.value),
        .structure_init => |value| try context.many(value.fields),
        .list_init => |value| try context.many(value.values),
        .enum_init => |value| try context.many(value.values),
        .field_store => |value| {
            try context.one(value.base);
            try context.one(value.replacement);
        },
        .collection_load => |value| {
            try context.one(value.collection);
            try context.one(value.index);
        },
        .collection_reference => |value| {
            try context.one(value.collection);
            try context.optional(value.reference);
            try context.one(value.index);
        },
        .collection_replace => |value| {
            try context.one(value.collection);
            try context.one(value.index);
            try context.one(value.replacement);
        },
        .collection_count => |value| try context.one(value.collection),
        .list_edit => |value| {
            try context.one(value.collection);
            try context.optional(value.index);
            try context.optional(value.argument);
        },
        .collection_slice, .collection_view => |value| {
            try context.one(value.collection);
            try context.one(value.start);
            try context.one(value.end);
            try context.optional(value.reference);
        },
        .string_byte_at => |value| {
            try context.one(value.operand);
            try context.one(value.index);
        },
        .address_load => |value| {
            try context.one(value.address);
            try context.one(value.byte_offset);
        },
        .address_store => |value| {
            try context.one(value.address);
            try context.one(value.byte_offset);
            try context.one(value.operand);
        },
        .reference_store => |value| {
            try context.one(value.reference);
            try context.one(value.operand);
        },
        .string_concat => |value| {
            try context.one(value.left);
            try context.one(value.right);
        },
        .binary => |value| {
            try context.one(value.left);
            try context.one(value.right);
        },
        inline .call, .boundary_call => |value| try context.many(value.arguments),
        inline .indirect_call, .boundary_indirect_call => |value| {
            try context.one(value.callee);
            try context.many(value.arguments);
        },
        .dynamic_call => |value| {
            try context.one(value.receiver);
            try context.many(value.arguments);
        },
        .assert => |value| {
            try context.one(value.condition);
            try context.one(value.message);
        },
    }
}

fn verifyTerminatorUses(
    function: Ir.Function,
    definition_counts: []const usize,
    first_definitions: []const ?Location,
    multiple_definition_entries: []const bool,
    dominators: []const bool,
    terminator: Ir.Terminator,
    location: Location,
) Error!void {
    const value = switch (terminator) {
        .return_value => |value| value,
        .branch => |value| value.condition,
        .panic => |value| value.message,
        else => return,
    };
    try verifyUse(function, definition_counts, first_definitions, multiple_definition_entries, dominators, value, location);
}

fn instructionResult(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        .class_retain, .class_drop, .list_retain, .list_drop, .string_retain, .string_drop, .global_store, .local_store, .address_store, .reference_store, .print, .assert, .mutex_lock, .mutex_unlock => null,
        .list_edit => |value| value.result,
        .call => |value| value.result,
        .indirect_call => |value| value.result,
        .boundary_call => |value| value.result,
        .boundary_indirect_call => |value| value.result,
        .dynamic_call => |value| value.result,
        inline else => |value| value.result,
    };
}

fn instructionSecondaryResult(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        .list_edit => |value| value.removed,
        else => null,
    };
}

test "verifier rejects an undefined value use" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "missing",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{.int},
        .blocks = &.{.{ .instructions = &.{}, .terminator = .{ .return_value = 0 } }},
    }} };
    try std.testing.expectError(error.MissingDefinition, verify(std.testing.allocator, program));
}

test "verifier rejects a use before its definition" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "ordering",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{ .int, .int },
        .blocks = &.{.{
            .instructions = &.{
                .{ .copy = .{ .result = 1, .operand = 0 } },
                .{ .constant_int = .{ .result = 0, .bits = 1 } },
            },
            .terminator = .{ .return_value = 1 },
        }},
    }} };
    try std.testing.expectError(error.DefinitionDoesNotDominateUse, verify(std.testing.allocator, program));
}

test "verifier accepts edge copies as a complete lowered phi" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "phi",
        .parameter_types = &.{.bool},
        .return_type = .int,
        .value_types = &.{ .bool, .int, .int, .int },
        .blocks = &.{
            .{ .instructions = &.{}, .terminator = .{ .branch = .{ .condition = 0, .then_block = 1, .else_block = 2 } } },
            .{ .instructions = &.{
                .{ .constant_int = .{ .result = 1, .bits = 1 } },
                .{ .copy = .{ .result = 3, .operand = 1 } },
            }, .terminator = .{ .jump = 3 } },
            .{ .instructions = &.{
                .{ .constant_int = .{ .result = 2, .bits = 2 } },
                .{ .copy = .{ .result = 3, .operand = 2 } },
            }, .terminator = .{ .jump = 3 } },
            .{ .instructions = &.{}, .terminator = .{ .return_value = 3 } },
        },
    }} };
    try verify(std.testing.allocator, program);
}

test "verifier rejects an incomplete lowered phi" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "phi",
        .parameter_types = &.{.bool},
        .return_type = .int,
        .value_types = &.{ .bool, .int, .int },
        .blocks = &.{
            .{ .instructions = &.{}, .terminator = .{ .branch = .{ .condition = 0, .then_block = 1, .else_block = 2 } } },
            .{ .instructions = &.{
                .{ .constant_int = .{ .result = 1, .bits = 1 } },
                .{ .copy = .{ .result = 2, .operand = 1 } },
            }, .terminator = .{ .jump = 3 } },
            .{ .instructions = &.{}, .terminator = .{ .jump = 3 } },
            .{ .instructions = &.{}, .terminator = .{ .return_value = 2 } },
        },
    }} };
    try std.testing.expectError(error.DefinitionDoesNotDominateUse, verify(std.testing.allocator, program));
}

test "verifier rejects a result whose declared type disagrees with its operation" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "type",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{.int},
        .blocks = &.{.{
            .instructions = &.{.{ .constant_bool = .{ .result = 0, .value = true } }},
            .terminator = .{ .return_value = 0 },
        }},
    }} };
    try std.testing.expectError(error.InvalidProgram, verify(std.testing.allocator, program));
}

test "verifier accepts an explicit representation-changing copy" {
    const runtime_type = Ir.Type.structure(0);
    const program: Ir.Program = .{
        .structures = &.{.{ .name = "Runtime", .fields = &.{}, .is_class = true }},
        .functions = &.{.{
            .name = "from_address",
            .parameter_types = &.{.uint},
            .return_type = .void,
            .value_types = &.{ .uint, runtime_type },
            .blocks = &.{.{
                .instructions = &.{
                    .{ .copy = .{ .result = 1, .operand = 0 } },
                    .{ .class_retain = .{ .operand = 1 } },
                },
                .terminator = .return_void,
            }},
        }},
    };
    try verify(std.testing.allocator, program);
}

test "verifier accepts an integer shift count with an independent width" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "shift",
        .parameter_types = &.{ .uint16, .int },
        .return_type = .uint16,
        .value_types = &.{ .uint16, .int, .uint16 },
        .blocks = &.{.{
            .instructions = &.{.{ .binary = .{
                .result = 2,
                .operator = .shift_left,
                .left = 0,
                .right = 1,
            } }},
            .terminator = .{ .return_value = 2 },
        }},
    }} };
    try verify(std.testing.allocator, program);
}

test "verifier accepts the null representation of a function value" {
    const function_type = Ir.Type.function(0);
    const program: Ir.Program = .{
        .function_types = &.{.{ .parameter_types = &.{}, .return_type = .void }},
        .functions = &.{.{
            .name = "callback_default",
            .parameter_types = &.{},
            .return_type = function_type,
            .value_types = &.{function_type},
            .blocks = &.{.{
                .instructions = &.{.{ .constant_int = .{ .result = 0, .bits = 0 } }},
                .terminator = .{ .return_value = 0 },
            }},
        }},
    };
    try verify(std.testing.allocator, program);
}

test "verifier records a removed list element as a secondary definition" {
    const list_type = Ir.Type.structure(0);
    const program: Ir.Program = .{
        .structures = &.{.{
            .name = "IntList",
            .fields = &.{},
            .collection = .{ .element = .int, .length = null },
        }},
        .functions = &.{.{
            .name = "take_last",
            .parameter_types = &.{list_type},
            .return_type = .int,
            .value_types = &.{ list_type, .int, list_type },
            .blocks = &.{.{
                .instructions = &.{.{ .list_edit = .{
                    .result = 2,
                    .collection = 0,
                    .kind = .take_last,
                    .removed = 1,
                    .position = .{ .offset = 0, .line = 1, .column = 1 },
                } }},
                .terminator = .{ .return_value = 1 },
            }},
        }},
    };
    try verify(std.testing.allocator, program);
}

test "verifier rejects an ownership operation on an incompatible value" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "ownership",
        .parameter_types = &.{.int},
        .return_type = .void,
        .value_types = &.{.int},
        .blocks = &.{.{
            .instructions = &.{.{ .class_retain = .{ .operand = 0 } }},
            .terminator = .return_void,
        }},
    }} };
    try std.testing.expectError(error.InvalidProgram, verify(std.testing.allocator, program));
}

test "verifier rejects a call whose argument contract is false" {
    const program: Ir.Program = .{ .functions = &.{
        .{
            .name = "callee",
            .parameter_types = &.{.int},
            .return_type = .int,
            .value_types = &.{.int},
            .blocks = &.{.{ .instructions = &.{}, .terminator = .{ .return_value = 0 } }},
        },
        .{
            .name = "caller",
            .parameter_types = &.{.bool},
            .return_type = .int,
            .value_types = &.{ .bool, .int },
            .blocks = &.{.{
                .instructions = &.{.{ .call = .{ .result = 1, .function = 0, .arguments = &.{0} } }},
                .terminator = .{ .return_value = 1 },
            }},
        },
    } };
    try std.testing.expectError(error.InvalidProgram, verify(std.testing.allocator, program));
}

test "verifier rejects an invalid control target" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "control",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{},
        .blocks = &.{.{ .instructions = &.{}, .terminator = .{ .jump = 1 } }},
    }} };
    try std.testing.expectError(error.InvalidProgram, verify(std.testing.allocator, program));
}

test "verifier rejects a native-width address load with a mismatched result" {
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "width",
        .parameter_types = &.{ .address, .uint },
        .return_type = .int,
        .value_types = &.{ .address, .uint, .int },
        .blocks = &.{.{
            .instructions = &.{.{ .address_load = .{
                .result = 2,
                .address = 0,
                .byte_offset = 1,
                .type = .float64,
            } }},
            .terminator = .{ .return_value = 2 },
        }},
    }} };
    try std.testing.expectError(error.InvalidProgram, verify(std.testing.allocator, program));
}
