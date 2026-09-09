const std = @import("std");
const Ir = @import("../Ir.zig");
const Machine = @import("Machine.zig");
const ResidenceLiveness = @import("ResidenceLiveness.zig");

const Allocator = std.mem.Allocator;

/// Reuses the checked read emitted by whole-element assignment as the hidden
/// return destination of a direct aggregate call. The proof is deliberately
/// narrow: both accesses must name the same local view and index, the discarded
/// read and returned value must have no other users, and address arguments must
/// originate in a collection whose element type differs from the result.
/// Consequently the callee cannot observe fields while it overwrites them.
pub fn optimize(
    allocator: Allocator,
    program: Ir.Program,
    source: Ir.Function,
    function: Machine.Function,
) Machine.Error!Machine.Function {
    if (function.reuses_slots) return function;
    const instructions = try allocator.dupe(Machine.Instruction, function.instructions);
    var changed = false;
    var block_start: usize = 0;
    for (source.blocks) |block| {
        for (block.instructions, 0..) |source_instruction, load_offset| candidate: {
            const source_load = switch (source_instruction) {
                .collection_load => |value| value,
                else => break :candidate,
            };
            if (!source_load.checked or source_load.result >= source.value_types.len) break :candidate;
            const result_type = source.value_types[source_load.result];
            if (!plainDetachedValue(program, result_type)) break :candidate;
            const load_index = block_start + load_offset;
            const machine_load = switch (instructions[load_index]) {
                .collection_load => |value| value,
                else => break :candidate,
            };
            if (!machine_load.dynamic or !machine_load.view or !machine_load.checked or
                !machine_load.result.aggregate or machine_load.result.width < 2 or
                spanUsed(instructions, machine_load.result, null)) break :candidate;
            const load_origin = localCollectionOrigin(block.instructions, source_load.collection, load_offset) orelse
                break :candidate;
            for (block.instructions[load_offset + 1 ..], load_offset + 1..) |possible_call, call_offset| {
                const source_call = switch (possible_call) {
                    .call => |value| value,
                    else => continue,
                };
                const call_result = source_call.result orelse continue;
                const safe_call = call_result < source.value_types.len and source.value_types[call_result] == result_type and
                    safeCallee(program, source, block, call_offset, source_call, result_type);
                if (!safe_call) continue;
                const call_index = block_start + call_offset;
                const machine_call = switch (instructions[call_index]) {
                    .call => |value| value,
                    else => continue,
                };
                const machine_result = machine_call.result orelse continue;
                if (machine_result.width != machine_load.result.width or !machine_result.aggregate) continue;

                for (block.instructions[call_offset + 1 ..], call_offset + 1..) |possible_replace, replace_offset| {
                    const source_replace = switch (possible_replace) {
                        .collection_replace => |value| value,
                        else => continue,
                    };
                    if (!source_replace.checked or source_replace.replacement != call_result or
                        source_replace.index != source_load.index or
                        valueDefinedBetween(block.instructions, source_load.index, load_offset + 1, replace_offset))
                        continue;
                    const replace_origin = localCollectionOrigin(block.instructions, source_replace.collection, replace_offset) orelse
                        continue;
                    if (replace_origin != load_origin or
                        localStoredBetween(block.instructions, load_origin, load_offset + 1, replace_offset))
                        continue;
                    if (!transparentAfterCall(block.instructions, call_offset + 1, replace_offset)) continue;

                    const replace_index = block_start + replace_offset;
                    const machine_replace = switch (instructions[replace_index]) {
                        .collection_replace => |value| value,
                        else => continue,
                    };
                    if (!machine_replace.dynamic or !machine_replace.view or !machine_replace.checked or
                        !sameSpan(machine_replace.replacement, machine_result) or
                        machine_replace.index != machine_load.index or
                        machine_replace.element_stride != machine_load.element_stride or
                        !spanUsed(instructions, machine_result, replace_index))
                        continue;

                    var updated_load = machine_load;
                    updated_load.forwarded_result = machine_result.start;
                    updated_load.forwarded_function = machine_call.function;
                    instructions[load_index] = .{ .collection_load = updated_load };
                    var updated_call = machine_call;
                    updated_call.result_forwarded = true;
                    instructions[call_index] = .{ .call = updated_call };
                    var updated_replace = machine_replace;
                    updated_replace.forwarded_replacement = machine_call.function;
                    instructions[replace_index] = .{ .collection_replace = updated_replace };
                    changed = true;
                    break :candidate;
                }
            }
        }
        block_start += block.instructions.len + 1;
    }
    if (!changed) {
        allocator.free(instructions);
        return function;
    }
    var result = function;
    result.instructions = instructions;
    return result;
}

fn safeCallee(
    program: Ir.Program,
    caller: Ir.Function,
    block: Ir.Block,
    call_offset: usize,
    call: Ir.Instruction.Call,
    result_type: Ir.Type,
) bool {
    if (call.function >= program.functions.len) return false;
    const callee = program.functions[call.function];
    if (callee.return_type != result_type or call.arguments.len != callee.parameter_types.len or
        !plainValueCallee(program, callee)) return false;
    for (call.arguments) |argument| {
        if (argument >= caller.value_types.len) return false;
        const argument_type = caller.value_types[argument];
        if (argument_type == .address) {
            const reference = collectionReferenceOrigin(block.instructions, argument, call_offset) orelse return false;
            if (reference.collection >= caller.value_types.len) return false;
            const element = collectionElement(program, caller.value_types[reference.collection]) orelse return false;
            if (element == result_type) return false;
        } else if (!plainDetachedValue(program, argument_type)) return false;
    }
    return true;
}

fn plainValueCallee(program: Ir.Program, function: Ir.Function) bool {
    if (function.capture_types.len != 0) return false;
    if (!plainDetachedValue(program, function.return_type)) return false;
    // Borrowed parameters are safe only because the caller separately proves
    // that every address originates in a differently typed collection. Inside
    // the callee, admit projections rooted in those parameters and loads, but
    // no fresh reference root or memory-writing operation.
    for (function.parameter_types) |parameter| {
        if (parameter != .address and !plainDetachedValue(program, parameter)) return false;
    }
    for (function.blocks) |block| {
        for (block.instructions) |instruction| switch (instruction) {
            .constant_int,
            .constant_bool,
            .constant_float32,
            .constant_float64,
            .optional_null,
            .optional_some,
            .optional_unwrap,
            .copy,
            .local_load,
            .local_store,
            .storage_init,
            .structure_init,
            .enum_init,
            .enum_test,
            .enum_payload,
            .enum_raw,
            .field_load,
            .reference_field,
            .reference_load,
            .unary,
            .binary,
            .convert,
            => {},
            else => return false,
        };
        switch (block.terminator) {
            .return_value, .return_void, .jump, .branch => {},
            .panic => return false,
        }
    }
    return true;
}

fn plainDetachedValue(program: Ir.Program, type_value: Ir.Type) bool {
    if (type_value == .void or type_value == .address or type_value.functionIndex() != null) return false;
    if (type_value.isNumeric() or type_value == .bool) return true;
    if (type_value.optionalChild()) |child| return plainDetachedValue(program, child);
    if (type_value.structureIndex()) |index| {
        if (index >= program.structures.len) return false;
        const structure = program.structures[index];
        if (structure.is_class or structure.is_protocol or structure.collection != null) return false;
        for (structure.fields) |field| if (!plainDetachedValue(program, field.type)) return false;
        return true;
    }
    return false;
}

fn collectionElement(program: Ir.Program, type_value: Ir.Type) ?Ir.Type {
    const index = type_value.structureIndex() orelse return null;
    if (index >= program.structures.len) return null;
    return (program.structures[index].collection orelse return null).element;
}

fn localCollectionOrigin(instructions: []const Ir.Instruction, value: Ir.ValueId, before: usize) ?Ir.LocalId {
    var current = value;
    var limit = before;
    var remaining = instructions.len;
    while (remaining > 0) : (remaining -= 1) {
        var index = limit;
        var found = false;
        while (index > 0) {
            index -= 1;
            switch (instructions[index]) {
                .copy => |copy| if (copy.result == current) {
                    current = copy.operand;
                    limit = index;
                    found = true;
                    break;
                },
                .local_load => |load| if (load.result == current) return load.local,
                else => {},
            }
        }
        if (!found) return null;
    }
    return null;
}

fn collectionReferenceOrigin(instructions: []const Ir.Instruction, value: Ir.ValueId, before: usize) ?Ir.Instruction.CollectionReference {
    var current = value;
    var index = before;
    while (index > 0) {
        index -= 1;
        switch (instructions[index]) {
            .copy => |copy| if (copy.result == current) {
                current = copy.operand;
            },
            .collection_reference => |reference| if (reference.result == current) return reference,
            else => {},
        }
    }
    return null;
}

fn localStoredBetween(instructions: []const Ir.Instruction, local: Ir.LocalId, first: usize, last: usize) bool {
    for (instructions[first..last]) |instruction| switch (instruction) {
        .local_store => |store| if (store.local == local) return true,
        else => {},
    };
    return false;
}

fn valueDefinedBetween(instructions: []const Ir.Instruction, value: Ir.ValueId, first: usize, last: usize) bool {
    for (instructions[first..last]) |instruction| if (instructionResult(instruction) == value) return true;
    return false;
}

fn instructionResult(instruction: Ir.Instruction) ?Ir.ValueId {
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

fn transparentAfterCall(instructions: []const Ir.Instruction, first: usize, last: usize) bool {
    for (instructions[first..last]) |instruction| switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .local_load,
        => {},
        else => return false,
    };
    return true;
}

fn spanUsed(instructions: []const Machine.Instruction, span: Machine.Span, allowed: ?usize) bool {
    var found_allowed = allowed == null;
    for (instructions, 0..) |instruction, index| for (0..span.width) |leaf| {
        if (!ResidenceLiveness.instructionUses(instruction, @as(usize, span.start) + leaf)) continue;
        if (allowed == null or index != allowed.?) return true;
        found_allowed = true;
    };
    return !found_allowed;
}

fn sameSpan(left: Machine.Span, right: Machine.Span) bool {
    return left.start == right.start and left.width == right.width and left.aggregate == right.aggregate;
}

const test_position: @import("../Source.zig").Position = .{ .offset = 0, .line = 1, .column = 1 };

fn testPrograms(allocator: Allocator, address_collection: Ir.ValueId) !struct { Ir.Program, Ir.Function, Machine.Function } {
    const input_fields = try allocator.dupe(Ir.StructureField, &.{
        .{ .name = "x", .type = .float32, .mutable = false },
        .{ .name = "y", .type = .float32, .mutable = false },
    });
    const output_fields = input_fields;
    const structures = try allocator.dupe(Ir.Structure, &.{
        .{ .name = "Input", .fields = input_fields },
        .{ .name = "Output", .fields = output_fields },
        .{ .name = "InputView", .fields = &.{}, .collection = .{ .element = .structure(0), .length = null, .view = true } },
        .{ .name = "OutputView", .fields = &.{}, .collection = .{ .element = .structure(1), .length = null, .view = true } },
    });
    const callee_fields = try allocator.dupe(Ir.ValueId, &.{ 2, 4 });
    const callee_instructions = try allocator.dupe(Ir.Instruction, &.{
        .{ .reference_field = .{ .result = 1, .reference = 0, .structure = 0, .field = 0 } },
        .{ .reference_load = .{ .result = 2, .reference = 1 } },
        .{ .reference_field = .{ .result = 3, .reference = 0, .structure = 0, .field = 1 } },
        .{ .reference_load = .{ .result = 4, .reference = 3 } },
        .{ .structure_init = .{ .result = 5, .structure = 1, .fields = callee_fields } },
    });
    const callee_blocks = try allocator.dupe(Ir.Block, &.{.{ .instructions = callee_instructions, .terminator = .{ .return_value = 5 } }});
    const caller_arguments = try allocator.dupe(Ir.ValueId, &.{4});
    const caller_instructions = try allocator.dupe(Ir.Instruction, &.{
        .{ .local_load = .{ .result = 2, .local = 0 } },
        .{ .collection_load = .{ .result = 3, .collection = 2, .index = 1, .position = test_position } },
        .{ .collection_reference = .{ .result = 4, .collection = address_collection, .reference = null, .index = 1, .position = test_position } },
        .{ .call = .{ .result = 5, .function = 0, .arguments = caller_arguments } },
        .{ .local_load = .{ .result = 6, .local = 0 } },
        .{ .collection_replace = .{ .result = 7, .collection = 6, .index = 1, .replacement = 5, .position = test_position } },
    });
    const caller_blocks = try allocator.dupe(Ir.Block, &.{.{ .instructions = caller_instructions, .terminator = .return_void }});
    const functions = try allocator.dupe(Ir.Function, &.{
        .{
            .name = "make",
            .parameter_types = &.{.address},
            .return_type = .structure(1),
            .value_types = &.{ .address, .address, .float32, .address, .float32, .structure(1) },
            .blocks = callee_blocks,
        },
        .{
            .name = "fill",
            .parameter_types = &.{ .structure(2), .int },
            .return_type = .void,
            .value_types = &.{ .structure(2), .int, .structure(3), .structure(1), .address, .structure(1), .structure(3), .structure(3) },
            .local_types = &.{.structure(3)},
            .blocks = caller_blocks,
        },
    });
    const machine_arguments = try allocator.dupe(Machine.Span, &.{.{ .start = 9, .width = 1 }});
    const machine_instructions = try allocator.dupe(Machine.Instruction, &.{
        .{ .copy_range = .{ .result = .{ .start = 5, .width = 2, .aggregate = true }, .operand = .{ .start = 3, .width = 2, .aggregate = true } } },
        .{ .collection_load = .{
            .result = .{ .start = 7, .width = 2, .aggregate = true },
            .collection = .{ .start = 5, .width = 2, .aggregate = true },
            .index = 2,
            .count = 0,
            .dynamic = true,
            .view = true,
            .element_stride = 16,
            .header = 0,
            .tail = 0,
        } },
        .{ .collection_reference = .{
            .result = 9,
            .collection = .{ .start = 0, .width = 2, .aggregate = true },
            .reference = null,
            .index = 2,
            .element_width = 2,
            .element_stride = 16,
            .count = 0,
            .dynamic = true,
            .view = true,
            .header = 0,
            .tail = 0,
        } },
        .{ .call = .{ .result = .{ .start = 10, .width = 2, .aggregate = true }, .function = 0, .arguments = machine_arguments } },
        .{ .copy_range = .{ .result = .{ .start = 12, .width = 2, .aggregate = true }, .operand = .{ .start = 3, .width = 2, .aggregate = true } } },
        .{ .collection_replace = .{
            .result = .{ .start = 14, .width = 2, .aggregate = true },
            .collection = .{ .start = 12, .width = 2, .aggregate = true },
            .index = 2,
            .replacement = .{ .start = 10, .width = 2, .aggregate = true },
            .count = 0,
            .dynamic = true,
            .view = true,
            .element_stride = 16,
            .header = 0,
            .tail = 0,
        } },
        .return_void,
    });
    return .{
        .{ .structures = structures, .functions = functions },
        functions[1],
        .{
            .name = "fill",
            .parameter_count = 2,
            .parameters = &.{ .{ .start = 0, .width = 2, .aggregate = true }, .{ .start = 2, .width = 1 } },
            .return_type = .void,
            .slot_count = 16,
            .frame_size = 128,
            .instructions = machine_instructions,
        },
    };
}

test "forward a disjoint checked view load into an aggregate call result" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const values = try testPrograms(arena.allocator(), 0);
    try std.testing.expectEqual(@as(Machine.Slot, 10), values[2].instructions[3].call.result.?.start);
    const result = try optimize(arena.allocator(), values[0], values[1], values[2]);
    try std.testing.expectEqual(@as(Machine.Slot, 10), result.instructions[1].collection_load.forwarded_result.?);
    try std.testing.expectEqual(@as(Machine.FunctionId, 0), result.instructions[1].collection_load.forwarded_function.?);
    try std.testing.expect(result.instructions[3].call.result_forwarded);
    try std.testing.expectEqual(@as(Machine.FunctionId, 0), result.instructions[5].collection_replace.forwarded_replacement.?);
}

test "retain aggregate temporaries when the input can alias the destination" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const values = try testPrograms(arena.allocator(), 2);
    const result = try optimize(arena.allocator(), values[0], values[1], values[2]);
    try std.testing.expect(result.instructions[1].collection_load.forwarded_result == null);
    try std.testing.expect(result.instructions[1].collection_load.forwarded_function == null);
    try std.testing.expect(!result.instructions[3].call.result_forwarded);
    try std.testing.expect(result.instructions[5].collection_replace.forwarded_replacement == null);
}
