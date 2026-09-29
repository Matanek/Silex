const std = @import("std");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");
const CallSummary = @import("CallSummary.zig");

// Inlined readers can retain a receiver, inspect it and immediately drop the
// same root again. No instruction in this region can release its original
// owner, publish an alias, call unproven code or observe the reference count.
// Keep all effectful regions and every control-flow boundary untouched.
pub fn optimize(allocator: std.mem.Allocator, function: Ir.Function) !Ir.Function {
    return optimizeWithReaders(allocator, function, .{ .functions = &.{} }, &.{});
}

// Compute a closed, non-recursive set of readers. Summaries guard transitive
// effects; typed instructions prove failure freedom and exclude allocations
// and operations not represented by those summaries.
pub fn readers(allocator: std.mem.Allocator, program: Ir.Program) ![]bool {
    const summaries = try CallSummary.analyze(allocator, program);
    defer allocator.free(summaries);
    const result = try allocator.alloc(bool, program.functions.len);
    @memset(result, false);
    var changed = true;
    while (changed) {
        changed = false;
        for (program.functions, summaries, 0..) |function, summary, index| {
            if (result[index] or summary.recursive or
                summary.effects.writes_memory or summary.effects.manages_ownership or
                summary.effects.crosses_boundary or summary.effects.synchronizes or
                summary.effects.observes_output) continue;
            var safe = true;
            for (function.blocks) |block| for (block.instructions) |instruction| {
                const infallible = switch (instruction) {
                    .structure_init => |value| value.structure < program.structures.len and
                        plainValue(program, Ir.Type.structure(value.structure), 0),
                    .enum_init => |value| value.values.len == 0 and
                        value.enumeration < program.enums.len and program.enums[value.enumeration].raw_type == null,
                    // FP arithmetic is IEEE, even when the IR's generic checked
                    // bit is set. Checked integer operations can still fail.
                    .binary => |value| !value.checked or switch (value.operator) {
                        .add, .subtract, .multiply, .divide, .remainder, .shift_left, .shift_right => value.left < function.value_types.len and function.value_types[value.left].isFloat(),
                        else => true,
                    },
                    .unary => |value| value.result < function.value_types.len and
                        (function.value_types[value.result].isFloat() or function.value_types[value.result] == .bool),
                    .convert => |value| !value.checked,
                    .collection_load => |value| !value.checked,
                    else => readOnly(instruction, result),
                };
                if (!infallible) safe = false;
            };
            if (safe) {
                result[index] = true;
                changed = true;
            }
        }
    }
    return result;
}

pub fn optimizeWithReaders(allocator: std.mem.Allocator, function: Ir.Function, program: Ir.Program, read_only_calls: []const bool) !Ir.Function {
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
                if (!preservesOwner(program, function, instruction, read_only_calls) or resultOf(instruction) == root) retained = null;
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

// Numeric value construction and stores cannot release an owner or publish
// a managed edge. Keep resource-valued stores and unknown references opaque.
fn preservesOwner(program: Ir.Program, function: Ir.Function, instruction: Ir.Instruction, calls: []const bool) bool {
    return switch (instruction) {
        .structure_init => |value| value.result < function.value_types.len and
            plainValue(program, function.value_types[value.result], 0),
        .field_store => |value| value.base < function.value_types.len and
            function.value_types[value.base].structureIndex() != null and
            function.value_types[value.base].structureIndex().? < program.structures.len and
            value.replacement < function.value_types.len and
            plainValue(program, function.value_types[value.replacement], 0),
        .local_store => |value| value.local < function.local_types.len and
            plainValue(program, function.local_types[value.local], 0),
        else => readOnly(instruction, calls),
    };
}

fn plainValue(program: Ir.Program, value_type: Ir.Type, depth: usize) bool {
    if (value_type.isNumeric() or value_type == .bool) return true;
    if (depth > 16) return false;
    const index = value_type.structureIndex() orelse return false;
    if (index >= program.structures.len) return false;
    const structure = program.structures[index];
    if (structure.is_class or structure.is_static or structure.collection != null) return false;
    for (structure.fields) |field| if (!plainValue(program, field.type, depth + 1)) return false;
    return true;
}

fn readOnly(instruction: Ir.Instruction, read_only_calls: []const bool) bool {
    return switch (instruction) {
        .call => |call| call.function < read_only_calls.len and read_only_calls[call.function],
        .reference_load,
        .reference_field,
        .enum_test,
        .enum_payload,
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

test "balanced roots cross only proven transitive readers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const receiver = Ir.Type.structure(0);
    const read: Ir.Instruction = .{ .field_load = .{ .result = 1, .base = 0, .field = 0 } };
    const reader: Ir.Function = .{
        .name = "reader",
        .parameter_types = &.{receiver},
        .return_type = .float32,
        .value_types = &.{ receiver, .float32, receiver },
        .blocks = &.{.{ .instructions = &.{read}, .terminator = .{ .return_value = 1 } }},
    };
    var functions = [_]Ir.Function{ reader, reader, reader, reader, reader };
    functions[1].blocks = &.{.{ .instructions = &.{.{ .call = .{ .result = 1, .function = 0, .arguments = &.{0} } }}, .terminator = .{ .return_value = 1 } }};
    functions[2].blocks = &.{.{ .instructions = &.{ read, .{ .field_store = .{ .result = 2, .base = 0, .field = 0, .replacement = 1 } } }, .terminator = .{ .return_value = 1 } }};
    functions[3].blocks = &.{.{ .instructions = &.{ read, .{ .structure_init = .{ .result = 2, .structure = 0, .fields = &.{1} } } }, .terminator = .{ .return_value = 1 } }};
    functions[4].blocks = &.{.{ .instructions = &.{.{ .call = .{ .result = 1, .function = 4, .arguments = &.{0} } }}, .terminator = .{ .return_value = 1 } }};
    const program: Ir.Program = .{
        .structures = &.{.{ .name = "State", .is_class = true, .fields = &.{.{ .name = "value", .type = .float32, .mutable = true }} }},
        .functions = &functions,
    };
    const proven = try readers(allocator, program);
    try std.testing.expectEqualSlices(bool, &.{ true, true, false, false, false }, proven);
    for (0..6) |callee| {
        var caller = reader;
        caller.blocks = &.{.{ .instructions = &.{
            .{ .class_retain = .{ .operand = 0 } },
            .{ .call = .{ .result = 1, .function = callee, .arguments = &.{0} } },
            .{ .class_drop = .{ .operand = 0, .static_type = 0, .plans = &.{} } },
        }, .terminator = .{ .return_value = 1 } }};
        const after = try optimizeWithReaders(allocator, caller, program, proven);
        try std.testing.expectEqual(@as(usize, if (callee < 2) 1 else 3), after.blocks[0].instructions.len);
    }
}

test "reader proof distinguishes IEEE arithmetic from fallible integer operations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const arithmetic: Ir.Function = .{
        .name = "divide",
        .parameter_types = &.{ .float32, .float32 },
        .return_type = .float32,
        .value_types = &.{ .float32, .float32, .float32 },
        .blocks = &.{.{ .instructions = &.{.{ .binary = .{
            .result = 2,
            .left = 0,
            .right = 1,
            .operator = .divide,
            .checked = true,
        } }}, .terminator = .{ .return_value = 2 } }},
    };
    var integer = arithmetic;
    integer.parameter_types = &.{ .int, .int };
    integer.value_types = &.{ .int, .int, .int };
    integer.return_type = .int;
    const result = try readers(allocator, .{ .functions = &.{ arithmetic, integer } });
    try std.testing.expectEqualSlices(bool, &.{ true, false }, result);
}

test "balanced roots allow numeric stores but preserve resource ownership barriers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const owner = Ir.Type.structure(0);
    const vector = Ir.Type.structure(1);
    const managed = Ir.Type.structure(2);
    const program: Ir.Program = .{ .functions = &.{}, .structures = &.{
        .{ .name = "Owner", .is_class = true, .fields = &.{
            .{ .name = "value", .type = vector, .mutable = true },
            .{ .name = "child", .type = owner, .mutable = true },
        } },
        .{ .name = "Vector", .fields = &.{.{ .name = "x", .type = .float32, .mutable = true }} },
        .{ .name = "Managed", .fields = &.{.{ .name = "child", .type = owner, .mutable = true }} },
    } };
    const operations = [_]Ir.Instruction{
        .{ .field_store = .{ .result = 3, .base = 0, .field = 0, .replacement = 1 } },
        .{ .local_store = .{ .local = 0, .operand = 1 } },
        .{ .structure_init = .{ .result = 1, .structure = 1, .fields = &.{4} } },
        .{ .field_store = .{ .result = 3, .base = 0, .field = 1, .replacement = 2 } },
        .{ .local_store = .{ .local = 1, .operand = 2 } },
        .{ .structure_init = .{ .result = 5, .structure = 2, .fields = &.{2} } },
        .{ .class_drop = .{ .operand = 2, .static_type = 0, .plans = &.{} } },
    };
    for (operations, 0..) |operation, index| {
        const function: Ir.Function = .{
            .name = "update",
            .parameter_types = &.{ owner, vector, owner },
            .return_type = .void,
            .local_types = &.{ vector, owner },
            .value_types = &.{ owner, vector, owner, owner, .float32, managed },
            .blocks = &.{.{ .instructions = &.{
                .{ .class_retain = .{ .operand = 0 } },                                operation,
                .{ .class_drop = .{ .operand = 0, .static_type = 0, .plans = &.{} } },
            }, .terminator = .return_void }},
        };
        const result = try optimizeWithReaders(allocator, function, program, &.{});
        try std.testing.expectEqual(@as(usize, if (index < 3) 1 else 3), result.blocks[0].instructions.len);
    }
}
