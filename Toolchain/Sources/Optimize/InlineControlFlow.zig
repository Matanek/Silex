const std = @import("std");
const Ir = @import("../Ir.zig");

const Allocator = std.mem.Allocator;
const maximum_cost = 128;

const Info = struct {
    state: enum { unresolved, visiting, rejected, eligible } = .unresolved,
    cost: usize = 0,
};

/// Inlines small direct callees with arbitrary control flow. Returns are
/// lowered to copies into the call result followed by a shared continuation.
pub fn optimize(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const information = try allocator.alloc(Info, program.functions.len);
    @memset(information, .{});
    for (program.functions, 0..) |_, index| resolve(program, information, index);

    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        var current = function;
        var expansions: usize = 0;
        while (expansions < 64) : (expansions += 1) {
            const next = try inlineOnce(allocator, program, information, current, index);
            if (next == null) break;
            current = next.?;
        }
        functions[index] = current;
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn resolve(program: Ir.Program, information: []Info, function_index: usize) void {
    var info = &information[function_index];
    if (info.state != .unresolved) return;
    info.state = .visiting;
    const function = program.functions[function_index];
    if (function.capture_types.len != 0 or function.blocks.len < 2 or
        (function.return_type != .void and !isValueType(program, function.return_type, 0)))
    {
        info.state = .rejected;
        return;
    }
    for (function.parameter_types) |parameter_type| if (!isParameterType(program, parameter_type)) {
        info.state = .rejected;
        return;
    };
    for (function.value_types) |value_type| if (!isInlineValueType(program, value_type)) {
        info.state = .rejected;
        return;
    };

    var cost: usize = function.blocks.len;
    var returns: usize = 0;
    for (function.blocks) |block| {
        switch (block.terminator) {
            .jump, .branch => {},
            .return_value => {
                if (function.return_type == .void) {
                    info.state = .rejected;
                    return;
                }
                returns += 1;
            },
            .return_void => {
                if (function.return_type != .void) {
                    info.state = .rejected;
                    return;
                }
                returns += 1;
            },
            .panic => {
                info.state = .rejected;
                return;
            },
        }
        for (block.instructions) |instruction| {
            switch (instruction) {
                .constant_int,
                .constant_bool,
                .constant_float32,
                .constant_float64,
                .copy,
                .local_load,
                .local_store,
                .local_address,
                .field_load,
                .collection_count,
                .structure_init,
                .unary,
                .binary,
                .convert,
                .address_load,
                .address_store,
                => cost += 1,
                .boundary_call => |call| {
                    if (call.result == null) {
                        info.state = .rejected;
                        return;
                    }
                    cost += 4;
                },
                .call => |call| {
                    if (call.function >= program.functions.len or call.function == function_index) {
                        info.state = .rejected;
                        return;
                    }
                    resolve(program, information, call.function);
                    if (information[call.function].state == .visiting) {
                        info.state = .rejected;
                        return;
                    }
                    cost += if (information[call.function].state == .eligible)
                        information[call.function].cost
                    else
                        8;
                },
                else => {
                    info.state = .rejected;
                    return;
                },
            }
            if (cost > maximum_cost) {
                info.state = .rejected;
                return;
            }
        }
    }
    if (returns == 0) {
        info.state = .rejected;
        return;
    }
    info.cost = cost;
    info.state = .eligible;
}

fn isParameterType(program: Ir.Program, value_type: Ir.Type) bool {
    if (isValueType(program, value_type, 0)) return true;
    const structure_index = value_type.structureIndex() orelse return false;
    if (structure_index >= program.structures.len) return false;
    const structure = program.structures[structure_index];
    return !structure.is_static and (structure.is_class or structure.collection == null);
}

fn isInlineValueType(program: Ir.Program, value_type: Ir.Type) bool {
    if (isValueType(program, value_type, 0)) return true;
    const structure_index = value_type.structureIndex() orelse return false;
    return structure_index < program.structures.len and !program.structures[structure_index].is_static;
}

fn isValueType(program: Ir.Program, value_type: Ir.Type, depth: usize) bool {
    if (depth > 16) return false;
    if (value_type.isNumeric() or value_type == .bool) return true;
    const structure_index = value_type.structureIndex() orelse return false;
    if (structure_index >= program.structures.len) return false;
    const structure = program.structures[structure_index];
    if (structure.is_class or structure.is_static or structure.collection != null) return false;
    for (structure.fields) |field| if (!isValueType(program, field.type, depth + 1)) return false;
    return true;
}

fn inlineOnce(
    allocator: Allocator,
    program: Ir.Program,
    information: []const Info,
    function: Ir.Function,
    function_index: usize,
) !?Ir.Function {
    for (function.blocks, 0..) |block, block_index| for (block.instructions, 0..) |instruction, instruction_index| {
        const call = switch (instruction) {
            .call => |value| value,
            else => continue,
        };
        if (call.function == function_index or call.function >= information.len or
            information[call.function].state != .eligible) continue;
        return try expandCall(allocator, program, function, block_index, instruction_index, call);
    };
    return null;
}

fn expandCall(
    allocator: Allocator,
    program: Ir.Program,
    caller: Ir.Function,
    caller_block: Ir.BlockId,
    call_index: usize,
    call: Ir.Instruction.Call,
) !Ir.Function {
    const callee = program.functions[call.function];
    if (call.arguments.len != callee.parameter_types.len) return error.InvalidProgram;
    const clone_start = caller.blocks.len;
    const continuation = clone_start + callee.blocks.len;
    const local_start = caller.local_types.len;

    var value_types: std.ArrayList(Ir.Type) = .empty;
    try value_types.appendSlice(allocator, caller.value_types);
    const values = try allocator.alloc(Ir.ValueId, callee.value_types.len);
    for (call.arguments, 0..) |argument, index| values[index] = argument;
    for (callee.value_types[call.arguments.len..], call.arguments.len..) |value_type, value| {
        values[value] = value_types.items.len;
        try value_types.append(allocator, value_type);
    }
    var local_types: std.ArrayList(Ir.Type) = .empty;
    try local_types.appendSlice(allocator, caller.local_types);
    try local_types.appendSlice(allocator, callee.local_types);

    var blocks: std.ArrayList(Ir.Block) = .empty;
    try blocks.appendSlice(allocator, caller.blocks);
    const original = caller.blocks[caller_block];
    blocks.items[caller_block] = .{
        .instructions = original.instructions[0..call_index],
        .terminator = .{ .jump = clone_start },
    };
    for (callee.blocks) |block| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |instruction| {
            try instructions.append(allocator, try mapInstruction(allocator, instruction, values, local_start));
        }
        const terminator = switch (block.terminator) {
            .jump => |target| Ir.Terminator{ .jump = clone_start + target },
            .branch => |branch| Ir.Terminator{ .branch = .{
                .condition = values[branch.condition],
                .then_block = clone_start + branch.then_block,
                .else_block = clone_start + branch.else_block,
            } },
            .return_value => |returned| returned: {
                const result = call.result orelse return error.InvalidProgram;
                try instructions.append(allocator, .{ .copy = .{ .result = result, .operand = values[returned] } });
                break :returned Ir.Terminator{ .jump = continuation };
            },
            .return_void => returned: {
                if (call.result != null) return error.InvalidProgram;
                break :returned Ir.Terminator{ .jump = continuation };
            },
            .panic => return error.InvalidProgram,
        };
        try blocks.append(allocator, .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = terminator,
        });
    }
    try blocks.append(allocator, .{
        .instructions = original.instructions[call_index + 1 ..],
        .terminator = original.terminator,
    });
    var result = caller;
    result.value_types = try value_types.toOwnedSlice(allocator);
    result.local_types = try local_types.toOwnedSlice(allocator);
    result.blocks = try blocks.toOwnedSlice(allocator);
    return result;
}

fn mapInstruction(
    allocator: Allocator,
    instruction: Ir.Instruction,
    values: []const Ir.ValueId,
    local_start: Ir.LocalId,
) !Ir.Instruction {
    return switch (instruction) {
        .constant_int => |value| .{ .constant_int = .{ .result = values[value.result], .bits = value.bits } },
        .constant_bool => |value| .{ .constant_bool = .{ .result = values[value.result], .value = value.value } },
        .constant_float32 => |value| .{ .constant_float32 = .{ .result = values[value.result], .bits = value.bits } },
        .constant_float64 => |value| .{ .constant_float64 = .{ .result = values[value.result], .bits = value.bits } },
        .copy => |value| .{ .copy = .{ .result = values[value.result], .operand = values[value.operand] } },
        .local_load => |value| .{ .local_load = .{
            .result = values[value.result],
            .local = local_start + value.local,
        } },
        .local_store => |value| .{ .local_store = .{
            .local = local_start + value.local,
            .operand = values[value.operand],
        } },
        .local_address => |value| .{ .local_address = .{
            .result = values[value.result],
            .local = local_start + value.local,
        } },
        .field_load => |value| .{ .field_load = .{
            .result = values[value.result],
            .base = values[value.base],
            .field = value.field,
        } },
        .collection_count => |value| .{ .collection_count = .{
            .result = values[value.result],
            .collection = values[value.collection],
        } },
        .structure_init => |value| .{ .structure_init = .{
            .result = values[value.result],
            .structure = value.structure,
            .fields = try mapValues(allocator, values, value.fields),
        } },
        .unary => |value| .{ .unary = .{
            .result = values[value.result],
            .operator = value.operator,
            .operand = values[value.operand],
        } },
        .binary => |value| .{ .binary = .{
            .result = values[value.result],
            .operator = value.operator,
            .left = values[value.left],
            .right = values[value.right],
            .checked = value.checked,
        } },
        .convert => |value| .{ .convert = .{
            .result = values[value.result],
            .operand = values[value.operand],
            .source = value.source,
            .target = value.target,
            .position = value.position,
            .checked = value.checked,
        } },
        .address_load => |value| .{ .address_load = .{
            .result = values[value.result],
            .address = values[value.address],
            .byte_offset = values[value.byte_offset],
            .type = value.type,
        } },
        .address_store => |value| .{ .address_store = .{
            .address = values[value.address],
            .byte_offset = values[value.byte_offset],
            .operand = values[value.operand],
            .type = value.type,
        } },
        .call => |value| .{ .call = .{
            .result = if (value.result) |result| values[result] else null,
            .function = value.function,
            .arguments = try mapValues(allocator, values, value.arguments),
        } },
        .boundary_call => |value| .{ .boundary_call = .{
            .result = if (value.result) |result| values[result] else null,
            .function = value.function,
            .arguments = try mapValues(allocator, values, value.arguments),
        } },
        else => return error.InvalidProgram,
    };
}

fn mapValues(allocator: Allocator, mapping: []const Ir.ValueId, source: []const Ir.ValueId) ![]const Ir.ValueId {
    const result = try allocator.alloc(Ir.ValueId, source.len);
    for (source, 0..) |value, index| result[index] = mapping[value];
    return result;
}

test "inline a scalar branch with locals through a shared continuation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const choose_blocks = [_]Ir.Block{
        .{ .instructions = &.{.{ .local_store = .{ .local = 0, .operand = 1 } }}, .terminator = .{ .branch = .{ .condition = 0, .then_block = 1, .else_block = 2 } } },
        .{ .instructions = &.{.{ .local_load = .{ .result = 3, .local = 0 } }}, .terminator = .{ .return_value = 3 } },
        .{ .instructions = &.{}, .terminator = .{ .return_value = 2 } },
    };
    const main_blocks = [_]Ir.Block{.{
        .instructions = &.{.{ .call = .{ .result = 3, .function = 0, .arguments = &.{ 0, 1, 2 } } }},
        .terminator = .{ .return_value = 3 },
    }};
    const program: Ir.Program = .{ .functions = &.{
        .{
            .name = "choose",
            .parameter_types = &.{ .bool, .int, .int },
            .return_type = .int,
            .value_types = &.{ .bool, .int, .int, .int },
            .local_types = &.{.int},
            .blocks = &choose_blocks,
        },
        .{
            .name = "main",
            .parameter_types = &.{ .bool, .int, .int },
            .return_type = .int,
            .value_types = &.{ .bool, .int, .int, .int },
            .blocks = &main_blocks,
        },
    } };
    const optimized = try optimize(allocator, program);
    const text = try Ir.writeText(allocator, optimized);
    const main = std.mem.indexOf(u8, text, "func @main") orelse return error.TestUnexpectedResult;
    try std.testing.expect(!std.mem.containsAtLeast(u8, text[main..], 1, "call @choose"));
    try std.testing.expectEqual(@as(usize, 5), optimized.functions[1].blocks.len);
    try std.testing.expectEqualSlices(Ir.Type, &.{.int}, optimized.functions[1].local_types);
}
