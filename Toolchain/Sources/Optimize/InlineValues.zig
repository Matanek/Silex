const std = @import("std");
const Ir = @import("../Ir.zig");
const CallSummary = @import("CallSummary.zig");

const Allocator = std.mem.Allocator;
const maximum_cost = 128;

const Info = struct {
    state: enum { unresolved, visiting, rejected, eligible } = .unresolved,
    cost: usize = 0,
    previously_eligible: bool = false,
};

pub fn optimize(allocator: Allocator, program: Ir.Program) !Ir.Program {
    return optimizeWithMode(allocator, program, false);
}

// Memory and SSA cleanup can expose scalar leaves after the first inline pass.
// Revisit only these leaves: no aggregate, reference or call expansion.
pub fn optimizeScalarLeaves(allocator: Allocator, program: Ir.Program) !Ir.Program {
    return optimizeWithMode(allocator, program, true);
}

fn optimizeWithMode(allocator: Allocator, program: Ir.Program, scalar_leaves_only: bool) !Ir.Program {
    const information = try allocator.alloc(Info, program.functions.len);
    @memset(information, .{});
    for (program.functions, 0..) |_, index| resolve(program, information, index);
    if (scalar_leaves_only) {
        for (program.functions, information) |function, *info| {
            if (!scalarLeaf(function)) info.state = .rejected;
        }
        const has_call = found: {
            for (program.functions) |function| for (function.blocks) |block| for (block.instructions) |instruction| {
                if (instruction == .call and information[instruction.call.function].state == .eligible)
                    break :found true;
            };
            break :found false;
        };
        if (!has_call) return program;
    }
    const summaries = try CallSummary.analyze(allocator, program);

    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        functions[index] = try inlineFunction(allocator, program, information, summaries, function, index);
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn scalarLeaf(function: Ir.Function) bool {
    if (!function.return_type.isNumeric() and function.return_type != .bool) return false;
    for (function.parameter_types) |value_type| {
        if (!value_type.isNumeric() and value_type != .bool) return false;
    }
    for (function.blocks) |block| for (block.instructions) |instruction| {
        switch (instruction) {
            .constant_int, .constant_bool, .constant_float32, .constant_float64, .copy, .local_load, .local_store, .unary, .binary, .convert => {},
            else => return false,
        }
        // SSA cleanup can leave unused descriptor types in the value table.
        // Only operands/results still used by this leaf constrain its domain.
        switch (instruction) {
            inline .constant_int, .constant_bool, .constant_float32, .constant_float64, .copy, .local_load, .local_store, .unary, .binary, .convert => |value| {
                if (@TypeOf(value) != void) {
                    inline for (.{ "result", "operand", "left", "right" }) |field| {
                        if (@hasField(@TypeOf(value), field)) {
                            const value_type = function.value_types[@field(value, field)];
                            if (!value_type.isNumeric() and value_type != .bool) return false;
                        }
                    }
                }
            },
            else => unreachable,
        }
    };
    return true;
}

fn resolve(program: Ir.Program, information: []Info, function_index: usize) void {
    var info = &information[function_index];
    if (info.state != .unresolved) return;
    info.state = .visiting;
    const function = program.functions[function_index];
    const scalar_class_leaf = scalarClassLeaf(program, function);
    if (function.capture_types.len != 0 or function.blocks.len != 1 or
        (function.return_type != .void and !isValueType(program, function.return_type, 0) and !scalar_class_leaf))
    {
        info.state = .rejected;
        return;
    }
    var previously_eligible = !scalar_class_leaf;
    for (function.parameter_types) |parameter_type| {
        if (!isParameterType(program, parameter_type)) {
            info.state = .rejected;
            return;
        }
        previously_eligible = previously_eligible and isPreviousParameterType(program, parameter_type);
    }
    if (function.value_types.len < function.parameter_types.len) {
        info.state = .rejected;
        return;
    }
    for (function.value_types[function.parameter_types.len..]) |value_type| {
        if (!isInlineValueType(program, value_type)) {
            info.state = .rejected;
            return;
        }
        previously_eligible = previously_eligible and isPreviousInlineValueType(program, value_type);
    }
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
            .constant_int,
            .constant_bool,
            .constant_float32,
            .constant_float64,
            .field_load,
            .collection_count,
            .structure_init,
            .unary,
            .binary,
            .convert,
            .address_load,
            .address_store,
            => cost += 1,
            .local_address,
            .reference_load,
            .reference_store,
            .reference_field,
            .reference_optional,
            => {
                previously_eligible = false;
                cost += 1;
            },
            .collection_load, .collection_reference, .collection_replace => {
                previously_eligible = false;
                cost += 4;
            },
            .boundary_call => |call| {
                if (call.result == null) {
                    info.state = .rejected;
                    return;
                }
                cost += 1;
            },
            .copy, .local_load, .local_store => {},
            .field_store => {
                if (!scalar_class_leaf) {
                    info.state = .rejected;
                    return;
                }
                cost += 1;
            },
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
                if (callee.state == .eligible and !callee.previously_eligible) previously_eligible = false;
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
    info.previously_eligible = previously_eligible;
    info.state = .eligible;
}

// Class identities may be returned by a scalar mutator without transferring
// an allocation across a call boundary. Admit only leaves that cannot create,
// retain, drop, derive an address or replace a resource; class values have one type
// and can originate only from parameters, local copies and scalar field stores.
fn scalarClassLeaf(program: Ir.Program, function: Ir.Function) bool {
    const index = function.return_type.structureIndex() orelse return false;
    if (index >= program.structures.len or !program.structures[index].is_class or
        program.structures[index].is_static or function.blocks.len != 1) return false;
    for (function.value_types) |value_type| {
        if (value_type != function.return_type and !value_type.isNumeric() and value_type != .bool) return false;
    }
    for (function.local_types) |value_type| {
        if (value_type != function.return_type and !value_type.isNumeric() and value_type != .bool) return false;
    }
    for (function.blocks[0].instructions) |instruction| switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .local_load,
        .local_store,
        .unary,
        .binary,
        .convert,
        => {},
        .field_load => |value| {
            if (function.value_types[value.base] != function.return_type or
                (!function.value_types[value.result].isNumeric() and function.value_types[value.result] != .bool)) return false;
        },
        .field_store => |value| {
            if (function.value_types[value.base] != function.return_type or
                (!function.value_types[value.replacement].isNumeric() and function.value_types[value.replacement] != .bool)) return false;
        },
        else => return false,
    };
    return true;
}

fn isPreviousParameterType(program: Ir.Program, value_type: Ir.Type) bool {
    if (isValueType(program, value_type, 0)) return true;
    const structure_index = value_type.structureIndex() orelse return false;
    if (structure_index >= program.structures.len) return false;
    const structure = program.structures[structure_index];
    return !structure.is_static and (structure.is_class or structure.collection == null);
}

fn isPreviousInlineValueType(program: Ir.Program, value_type: Ir.Type) bool {
    if (isValueType(program, value_type, 0)) return true;
    const structure_index = value_type.structureIndex() orelse return false;
    return structure_index < program.structures.len and !program.structures[structure_index].is_static;
}

fn isParameterType(program: Ir.Program, value_type: Ir.Type) bool {
    if (value_type == .address) return true;
    if (isValueType(program, value_type, 0)) return true;
    const structure_index = value_type.structureIndex() orelse return false;
    if (structure_index >= program.structures.len) return false;
    const structure = program.structures[structure_index];
    return !structure.is_static and
        (structure.is_class or structure.collection == null or structure.collection.?.view);
}

fn isInlineValueType(program: Ir.Program, value_type: Ir.Type) bool {
    if (value_type == .address) return true;
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
    summaries: []const CallSummary.Summary,
    function: Ir.Function,
    function_index: usize,
) !Ir.Function {
    var value_types: std.ArrayList(Ir.Type) = .empty;
    try value_types.appendSlice(allocator, function.value_types);
    var local_types: std.ArrayList(Ir.Type) = .empty;
    try local_types.appendSlice(allocator, function.local_types);
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |instruction| {
            if (instruction == .call) {
                const call = instruction.call;
                if (call.function < information.len and call.function != function_index and
                    information[call.function].state == .eligible and
                    CallSummary.shouldInline(
                        summaries[call.function],
                        information[call.function].cost,
                        CallSummary.isHotBlock(function, block_index),
                        information[call.function].previously_eligible,
                    ))
                {
                    const returned = try emitCall(
                        allocator,
                        program,
                        information,
                        call.function,
                        call.arguments,
                        &value_types,
                        &local_types,
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
    result.local_types = try local_types.toOwnedSlice(allocator);
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
    caller_locals: *std.ArrayList(Ir.Type),
    output: *std.ArrayList(Ir.Instruction),
) !?Ir.ValueId {
    const function = program.functions[function_index];
    const mapping = try allocator.alloc(?Ir.ValueId, function.value_types.len);
    @memset(mapping, null);
    for (arguments, 0..) |argument, index| mapping[index] = argument;
    const local_start = caller_locals.items.len;
    try caller_locals.appendSlice(allocator, function.local_types);

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
        .local_store => |value| try output.append(allocator, .{ .local_store = .{
            .local = local_start + value.local,
            .operand = mapped(mapping, value.operand),
        } }),
        .local_load => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .local_load = .{
                .result = result,
                .local = local_start + value.local,
            } });
        },
        .local_address => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .local_address = .{
                .result = result,
                .local = local_start + value.local,
            } });
        },
        .field_load => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .field_load = .{
                .result = result,
                .base = mapped(mapping, value.base),
                .field = value.field,
            } });
        },
        .field_store => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .field_store = .{
                .result = result,
                .base = mapped(mapping, value.base),
                .field = value.field,
                .replacement = mapped(mapping, value.replacement),
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
        .collection_load => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .collection_load = .{
                .result = result,
                .collection = mapped(mapping, value.collection),
                .index = mapped(mapping, value.index),
                .checked = value.checked,
                .position = value.position,
            } });
        },
        .collection_reference => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .collection_reference = .{
                .result = result,
                .collection = mapped(mapping, value.collection),
                .reference = if (value.reference) |reference| mapped(mapping, reference) else null,
                .index = mapped(mapping, value.index),
                .checked = value.checked,
                .ownership = value.ownership,
                .position = value.position,
            } });
        },
        .collection_replace => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .collection_replace = .{
                .result = result,
                .collection = mapped(mapping, value.collection),
                .index = mapped(mapping, value.index),
                .replacement = mapped(mapping, value.replacement),
                .checked = value.checked,
                .ownership = value.ownership,
                .position = value.position,
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
        .reference_load => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .reference_load = .{
                .result = result,
                .reference = mapped(mapping, value.reference),
            } });
        },
        .reference_store => |value| try output.append(allocator, .{ .reference_store = .{
            .reference = mapped(mapping, value.reference),
            .operand = mapped(mapping, value.operand),
        } }),
        .reference_field => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .reference_field = .{
                .result = result,
                .reference = mapped(mapping, value.reference),
                .structure = value.structure,
                .field = value.field,
            } });
        },
        .reference_optional => |value| {
            const result = try appendType(allocator, function, caller_types, value.result);
            mapping[value.result] = result;
            try output.append(allocator, .{ .reference_optional = .{
                .result = result,
                .reference = mapped(mapping, value.reference),
            } });
        },
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
                .left_non_negative = value.left_non_negative,
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
                    caller_locals,
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

test "preserve previous boundary inlining while gating new reference forms" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const previous_blocks = [_]Ir.Block{.{
        .instructions = &.{.{ .boundary_call = .{ .result = 0, .function = 0, .arguments = &.{} } }},
        .terminator = .{ .return_value = 0 },
    }};
    const extended_blocks = [_]Ir.Block{.{
        .instructions = &.{
            .{ .boundary_call = .{ .result = 1, .function = 0, .arguments = &.{} } },
            .{ .reference_store = .{ .reference = 0, .operand = 1 } },
        },
        .terminator = .return_void,
    }};
    const main_blocks = [_]Ir.Block{.{
        .instructions = &.{
            .{ .call = .{ .result = 1, .function = 0, .arguments = &.{} } },
            .{ .call = .{ .result = null, .function = 1, .arguments = &.{0} } },
        },
        .terminator = .{ .return_value = 1 },
    }};
    const program: Ir.Program = .{ .functions = &.{
        .{
            .name = "previous_boundary",
            .parameter_types = &.{},
            .return_type = .uint,
            .value_types = &.{.uint},
            .blocks = &previous_blocks,
        },
        .{
            .name = "extended_boundary",
            .parameter_types = &.{.address},
            .return_type = .void,
            .value_types = &.{ .address, .uint },
            .blocks = &extended_blocks,
        },
        .{
            .name = "main",
            .parameter_types = &.{.address},
            .return_type = .uint,
            .value_types = &.{ .address, .uint },
            .blocks = &main_blocks,
        },
    } };

    const optimized = try optimize(allocator, program);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @main") orelse return error.TestUnexpectedResult;
    const body = text[start..];
    try std.testing.expect(!std.mem.containsAtLeast(u8, body, 1, "call @previous_boundary"));
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "call @extended_boundary"));
}

test "inline scalar class leaves while preserving aliases and call effects" {
    const Frontend = @import("../Frontend.zig");
    const Interpreter = @import("../Interpreter.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Counter {
        \\    var value:int
        \\    func add(amount:int) { self.value += amount }
        \\    func observed(amount:int) { print(amount); self.value += amount }
        \\}
        \\func calculate(rounds:int) int {
        \\    var counter = Counter()
        \\    var observer = counter
        \\    var index = 0
        \\    while index < rounds { counter.add(3); index++ }
        \\    counter.observed(2)
        \\    return observer.value
        \\}
        \\func main() { print(calculate(4)); print(calculate(0)) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    var checked = false;
    for (optimized.functions) |function| {
        if (!std.mem.eql(u8, function.name, "calculate")) continue;
        var stores: usize = 0;
        var observed_calls: usize = 0;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction == .field_store) stores += 1;
            if (instruction == .call) {
                const name = optimized.functions[instruction.call.function].name;
                try std.testing.expect(std.mem.indexOf(u8, name, "Counter.add") == null);
                if (std.mem.indexOf(u8, name, "Counter.observed") != null) observed_calls += 1;
            }
        };
        try std.testing.expectEqual(@as(usize, 1), stores);
        try std.testing.expectEqual(@as(usize, 1), observed_calls);
        checked = true;
    }
    try std.testing.expect(checked);
    const before = try Interpreter.runCapture(allocator, compilation.ir);
    const after = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("2\n14\n2\n2\n", before.stdout);
    try std.testing.expectEqualStrings(before.stdout, after.stdout);
    try std.testing.expectEqualStrings(before.stderr, after.stderr);
    try std.testing.expectEqual(before.exit_code, after.exit_code);

    for (compilation.ir.functions) |function| {
        if (std.mem.indexOf(u8, function.name, "Counter.add") == null) continue;
        try std.testing.expect(scalarClassLeaf(compilation.ir, function));
        const barriers = [_]Ir.Instruction{
            .{ .class_retain = .{ .operand = 0 } },
            .{ .class_drop = .{ .operand = 0, .static_type = function.return_type.structureIndex().?, .plans = &.{} } },
            .{ .call = .{ .result = 0, .function = 0, .arguments = &.{0} } },
        };
        for (barriers) |barrier| {
            var forbidden = function;
            const instructions = try allocator.alloc(Ir.Instruction, function.blocks[0].instructions.len + 1);
            @memcpy(instructions[0..function.blocks[0].instructions.len], function.blocks[0].instructions);
            instructions[instructions.len - 1] = barrier;
            forbidden.blocks = &.{.{ .instructions = instructions, .terminator = function.blocks[0].terminator }};
            try std.testing.expect(!scalarClassLeaf(compilation.ir, forbidden));
        }
    }
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
