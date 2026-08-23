const std = @import("std");
const Ir = @import("../Ir.zig");

const Allocator = std.mem.Allocator;
const maximum_cost = 128;

const Info = struct {
    state: enum { unresolved, visiting, rejected, eligible } = .unresolved,
    cost: usize = 0,
};

pub fn optimize(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const information = try allocator.alloc(Info, program.functions.len);
    @memset(information, .{});
    for (program.functions, 0..) |_, index| resolve(program, information, index);

    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        functions[index] = try inlineFunction(allocator, program, information, function, index);
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
    if (function.capture_types.len != 0 or function.blocks.len != 1 or
        (function.return_type != .void and !isValueType(program, function.return_type, 0)))
    {
        info.state = .rejected;
        return;
    }
    for (function.parameter_types) |parameter_type| if (!isParameterType(program, parameter_type)) {
        info.state = .rejected;
        return;
    };
    if (function.value_types.len < function.parameter_types.len) {
        info.state = .rejected;
        return;
    }
    for (function.value_types[function.parameter_types.len..]) |value_type| if (!isInlineValueType(program, value_type)) {
        info.state = .rejected;
        return;
    };
    switch (function.blocks[0].terminator) {
        .return_value => if (function.return_type == .void) {
            info.state = .rejected;
            return;
        },
        .return_void => if (function.return_type != .void) {
            info.state = .rejected;
            return;
        },
        else => {
            info.state = .rejected;
            return;
        },
    }

    var cost: usize = 0;
    for (function.blocks[0].instructions) |instruction| {
        switch (instruction) {
            .constant_int, .constant_bool, .constant_float32, .constant_float64, .field_load, .collection_count, .structure_init, .unary, .binary, .convert, .address_load, .address_store => cost += 1,
            .boundary_call => |call| {
                if (call.result == null) {
                    info.state = .rejected;
                    return;
                }
                cost += 1;
            },
            .copy, .local_load, .local_store => {},
            .call => |call| {
                if (call.function >= program.functions.len or call.function == function_index) {
                    info.state = .rejected;
                    return;
                }
                resolve(program, information, call.function);
                const callee = information[call.function];
                if (callee.state == .visiting) {
                    info.state = .rejected;
                    return;
                }
                if (callee.state != .eligible and call.result == null) {
                    info.state = .rejected;
                    return;
                }
                cost += if (callee.state == .eligible) callee.cost else 1;
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

fn inlineFunction(
    allocator: Allocator,
    program: Ir.Program,
    information: []const Info,
    function: Ir.Function,
    function_index: usize,
) !Ir.Function {
    var value_types: std.ArrayList(Ir.Type) = .empty;
    try value_types.appendSlice(allocator, function.value_types);
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |instruction| {
            if (instruction == .call) {
                const call = instruction.call;
                if (call.function < information.len and call.function != function_index and
                    information[call.function].state == .eligible)
                {
                    const returned = try emitCall(
                        allocator,
                        program,
                        information,
                        call.function,
                        call.arguments,
                        &value_types,
                        &instructions,
                    );
                    if (call.result) |result| {
                        const value = returned orelse return error.InvalidProgram;
                        try instructions.append(allocator, .{ .copy = .{ .result = result, .operand = value } });
                    } else if (returned != null) return error.InvalidProgram;
                    continue;
                }
            }
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    var result = function;
    result.value_types = try value_types.toOwnedSlice(allocator);
    result.blocks = blocks;
    return result;
}

fn emitCall(
    allocator: Allocator,
    program: Ir.Program,
    information: []const Info,
    function_index: usize,
    arguments: []const Ir.ValueId,
    caller_types: *std.ArrayList(Ir.Type),
    output: *std.ArrayList(Ir.Instruction),
) !?Ir.ValueId {
    const function = program.functions[function_index];
    const mapping = try allocator.alloc(?Ir.ValueId, function.value_types.len);
    @memset(mapping, null);
    for (arguments, 0..) |argument, index| mapping[index] = argument;
    const locals = try allocator.alloc(?Ir.ValueId, function.local_types.len);
    @memset(locals, null);

    for (function.blocks[0].instructions) |instruction| switch (instruction) {
        .constant_int => |value| try emitResult(allocator, function, mapping, caller_types, output, value.result, .{
            .constant_int = .{ .result = undefined, .bits = value.bits },
        }),
        .constant_bool => |value| try emitResult(allocator, function, mapping, caller_types, output, value.result, .{
            .constant_bool = .{ .result = undefined, .value = value.value },
        }),
        .constant_float32 => |value| try emitResult(allocator, function, mapping, caller_types, output, value.result, .{
            .constant_float32 = .{ .result = undefined, .bits = value.bits },
        }),
        .constant_float64 => |value| try emitResult(allocator, function, mapping, caller_types, output, value.result, .{
            .constant_float64 = .{ .result = undefined, .bits = value.bits },
        }),
        .copy => |value| mapping[value.result] = mapped(mapping, value.operand),
        .local_store => |value| locals[value.local] = mapped(mapping, value.operand),
        .local_load => |value| mapping[value.result] = locals[value.local] orelse unreachable,
        .field_load => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .field_load = .{
                .result = result,
                .base = mapped(mapping, value.base),
                .field = value.field,
            } });
        },
        .collection_count => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .collection_count = .{
                .result = result,
                .collection = mapped(mapping, value.collection),
            } });
        },
        .address_load => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .address_load = .{
                .result = result,
                .address = mapped(mapping, value.address),
                .byte_offset = mapped(mapping, value.byte_offset),
                .type = value.type,
            } });
        },
        .address_store => |value| try output.append(allocator, .{ .address_store = .{
            .address = mapped(mapping, value.address),
            .byte_offset = mapped(mapping, value.byte_offset),
            .operand = mapped(mapping, value.operand),
            .type = value.type,
        } }),
        .structure_init => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .structure_init = .{
                .result = result,
                .structure = value.structure,
                .fields = try mappedValues(allocator, mapping, value.fields),
            } });
        },
        .unary => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .unary = .{
                .result = result,
                .operator = value.operator,
                .operand = mapped(mapping, value.operand),
            } });
        },
        .binary => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .binary = .{
                .result = result,
                .operator = value.operator,
                .left = mapped(mapping, value.left),
                .right = mapped(mapping, value.right),
                .checked = value.checked,
            } });
        },
        .convert => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .convert = .{
                .result = result,
                .operand = mapped(mapping, value.operand),
                .source = value.source,
                .target = value.target,
                .position = value.position,
                .checked = value.checked,
            } });
        },
        .call => |call| {
            const call_arguments = try mappedValues(allocator, mapping, call.arguments);
            if (information[call.function].state == .eligible) {
                const returned = try emitCall(
                    allocator,
                    program,
                    information,
                    call.function,
                    call_arguments,
                    caller_types,
                    output,
                );
                if (call.result) |result| {
                    mapping[result] = returned orelse return error.InvalidProgram;
                } else if (returned != null) return error.InvalidProgram;
            } else {
                const emitted_result = if (call.result) |result| result: {
                    const emitted = try appendType(allocator, function, caller_types, result);
                    mapping[result] = emitted;
                    break :result emitted;
                } else null;
                try output.append(allocator, .{ .call = .{
                    .result = emitted_result,
                    .function = call.function,
                    .arguments = call_arguments,
                } });
            }
        },
        .boundary_call => |call| {
            const result = call.result orelse unreachable;
            const emitted_result = try appendType(allocator, function, caller_types, result);
            mapping[result] = emitted_result;
            try output.append(allocator, .{ .boundary_call = .{
                .result = emitted_result,
                .function = call.function,
                .arguments = try mappedValues(allocator, mapping, call.arguments),
            } });
        },
        else => unreachable,
    };
    return switch (function.blocks[0].terminator) {
        .return_value => |value| mapped(mapping, value),
        .return_void => null,
        else => unreachable,
    };
}

fn emitResult(
    allocator: Allocator,
    function: Ir.Function,
    mapping: []?Ir.ValueId,
    caller_types: *std.ArrayList(Ir.Type),
    output: *std.ArrayList(Ir.Instruction),
    callee_result: Ir.ValueId,
    instruction: Ir.Instruction,
) !void {
    const result = try appendType(allocator, function, caller_types, callee_result);
    mapping[callee_result] = result;
    var emitted = instruction;
    switch (emitted) {
        .constant_int => |*value| value.result = result,
        .constant_bool => |*value| value.result = result,
        .constant_float32 => |*value| value.result = result,
        .constant_float64 => |*value| value.result = result,
        else => unreachable,
    }
    try output.append(allocator, emitted);
}

fn appendType(
    allocator: Allocator,
    function: Ir.Function,
    caller_types: *std.ArrayList(Ir.Type),
    callee_result: Ir.ValueId,
) !Ir.ValueId {
    const result = caller_types.items.len;
    try caller_types.append(allocator, function.value_types[callee_result]);
    return result;
}

fn mapped(mapping: []const ?Ir.ValueId, value: Ir.ValueId) Ir.ValueId {
    return mapping[value] orelse unreachable;
}

fn mappedValues(allocator: Allocator, mapping: []const ?Ir.ValueId, values: []const Ir.ValueId) ![]const Ir.ValueId {
    const result = try allocator.alloc(Ir.ValueId, values.len);
    for (values, 0..) |value, index| result[index] = mapped(mapping, value);
    return result;
}

test "inline small void memory writers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const writer_values = [_]Ir.Type{ .uint, .uint, .float32 };
    const writer_instructions = [_]Ir.Instruction{.{ .address_store = .{
        .address = 0,
        .byte_offset = 1,
        .operand = 2,
        .type = .float32,
    } }};
    const writer_blocks = [_]Ir.Block{.{
        .instructions = &writer_instructions,
        .terminator = .return_void,
    }};
    const main_values = [_]Ir.Type{ .uint, .uint, .float32 };
    const main_instructions = [_]Ir.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 0 } },
        .{ .constant_int = .{ .result = 1, .bits = 0 } },
        .{ .constant_float32 = .{ .result = 2, .bits = @bitCast(@as(f32, 1.5)) } },
        .{ .call = .{ .result = null, .function = 0, .arguments = &.{ 0, 1, 2 } } },
    };
    const main_blocks = [_]Ir.Block{.{
        .instructions = &main_instructions,
        .terminator = .return_void,
    }};
    const program: Ir.Program = .{ .functions = &.{
        .{
            .name = "write_float",
            .parameter_types = &writer_values,
            .return_type = .void,
            .value_types = &writer_values,
            .blocks = &writer_blocks,
        },
        .{
            .name = "main",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &main_values,
            .blocks = &main_blocks,
        },
    } };

    const optimized = try optimize(allocator, program);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @main") orelse return error.TestUnexpectedResult;
    const body = text[start..];
    try std.testing.expect(!std.mem.containsAtLeast(u8, body, 1, "call @write_float"));
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "boundary.store"));
}

test "inline numeric reads from aggregates that contain resources" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const resource_type = Ir.Type.structure(0);
    const drawing_type = Ir.Type.structure(1);
    const structures = [_]Ir.Structure{
        .{
            .name = "Resource",
            .fields = &.{.{ .name = "value", .type = .int, .mutable = false }},
            .is_class = true,
        },
        .{
            .name = "Drawing",
            .fields = &.{
                .{ .name = "resource", .type = resource_type, .mutable = false },
                .{ .name = "width", .type = .int, .mutable = false },
            },
        },
    };
    const read_values = [_]Ir.Type{ drawing_type, .int };
    const read_instructions = [_]Ir.Instruction{.{ .field_load = .{
        .result = 1,
        .base = 0,
        .field = 1,
    } }};
    const read_blocks = [_]Ir.Block{.{
        .instructions = &read_instructions,
        .terminator = .{ .return_value = 1 },
    }};
    const main_values = [_]Ir.Type{ drawing_type, .int };
    const main_instructions = [_]Ir.Instruction{.{ .call = .{
        .result = 1,
        .function = 0,
        .arguments = &.{0},
    } }};
    const main_blocks = [_]Ir.Block{.{
        .instructions = &main_instructions,
        .terminator = .{ .return_value = 1 },
    }};
    const program: Ir.Program = .{
        .structures = &structures,
        .functions = &.{
            .{
                .name = "width",
                .parameter_types = &.{drawing_type},
                .return_type = .int,
                .value_types = &read_values,
                .blocks = &read_blocks,
            },
            .{
                .name = "main",
                .parameter_types = &.{drawing_type},
                .return_type = .int,
                .value_types = &main_values,
                .blocks = &main_blocks,
            },
        },
    };

    const optimized = try optimize(allocator, program);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @main") orelse return error.TestUnexpectedResult;
    const body = text[start..];
    try std.testing.expect(!std.mem.containsAtLeast(u8, body, 1, "call @width"));
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "field %0, .width"));
}
