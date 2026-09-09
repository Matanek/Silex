const std = @import("std");
const Machine = @import("Machine.zig");
const ResidenceLiveness = @import("ResidenceLiveness.zig");

const Allocator = std.mem.Allocator;

/// Redirects a direct call from a temporary aggregate copy to the unchanged
/// source before register allocation. Keeping the source as an explicit call
/// operand lets liveness and stack forcing preserve its authoritative storage.
pub fn optimize(allocator: Allocator, function: Machine.Function) Allocator.Error!Machine.Function {
    const instructions = try allocator.dupe(Machine.Instruction, function.instructions);
    defer allocator.free(instructions);
    const removed = try allocator.alloc(bool, instructions.len);
    defer allocator.free(removed);
    @memset(removed, false);
    var removed_count: usize = 0;
    for (instructions, 0..) |instruction, copy_index| {
        const copy = switch (instruction) {
            .copy_range => |value| value,
            else => continue,
        };
        if (!copy.result.aggregate or !copy.operand.aggregate or
            copy.result.width == 0 or copy.result.width != copy.operand.width or
            sameSpan(copy.result, copy.operand) or spanAddressed(instructions, copy.operand) or
            !spanDefinedOnlyAt(instructions, copy.result, copy_index)) continue;
        const call_index = soleDirectCallUse(instructions, copy.result, copy_index) orelse continue;
        if (spanDefinedBetween(instructions, copy.operand, copy_index + 1, call_index)) continue;

        var call = instructions[call_index].call;
        const arguments = try allocator.dupe(Machine.Span, call.arguments);
        var replaced = false;
        for (arguments) |*argument| if (sameSpan(argument.*, copy.result)) {
            argument.* = copy.operand;
            replaced = true;
        };
        if (!replaced) {
            allocator.free(arguments);
            continue;
        }
        call.arguments = arguments;
        instructions[call_index] = .{ .call = call };
        removed[copy_index] = true;
        removed_count += 1;
    }
    for (instructions, 0..) |instruction, initialization_index| {
        var initialization = switch (instruction) {
            .aggregate_init => |value| value,
            else => continue,
        };
        if (!aggregateInitializationFeedsImmediateReturn(
            instructions,
            initialization_index,
            initialization,
        )) continue;
        const fields = try allocator.dupe(Machine.Span, initialization.fields);
        var changed = false;
        for (fields) |*field| {
            if (field.width != 1 or field.aggregate) continue;
            const copy_index = scalarCopyDefinition(instructions, field.start, initialization_index) orelse continue;
            const copy = instructions[copy_index].copy;
            if (!slotUsedOnlyByInstruction(instructions, copy.result, initialization_index) or
                spanDefinedBetween(
                    instructions,
                    .{ .start = copy.operand, .width = 1 },
                    copy_index + 1,
                    initialization_index,
                )) continue;
            field.* = .{ .start = copy.operand, .width = 1 };
            if (!removed[copy_index]) {
                removed[copy_index] = true;
                removed_count += 1;
            }
            changed = true;
        }
        if (changed) {
            initialization.fields = fields;
            instructions[initialization_index] = .{ .aggregate_init = initialization };
        } else allocator.free(fields);
    }
    if (removed_count == 0) return function;

    const compact = try allocator.alloc(Machine.Instruction, instructions.len - removed_count);
    var destination: usize = 0;
    for (instructions, 0..) |instruction, index| {
        if (removed[index]) continue;
        compact[destination] = switch (instruction) {
            .jump => |target| .{ .jump = remapTarget(removed, target) },
            .branch => |branch_value| .{ .branch = .{
                .condition = branch_value.condition,
                .then_instruction = remapTarget(removed, branch_value.then_instruction),
                .else_instruction = remapTarget(removed, branch_value.else_instruction),
            } },
            else => instruction,
        };
        destination += 1;
    }
    var result = function;
    result.instructions = compact;
    return result;
}

fn remapTarget(removed: []const bool, target: usize) usize {
    var result = target;
    for (removed[0..target]) |is_removed| result -= @intFromBool(is_removed);
    return result;
}

fn aggregateInitializationFeedsImmediateReturn(
    instructions: []const Machine.Instruction,
    initialization_index: usize,
    initialization: Machine.Instruction.AggregateInit,
) bool {
    if (initialization_index + 1 >= instructions.len or
        controlTargetsInstruction(instructions, initialization_index + 1)) return false;
    const returned = switch (instructions[initialization_index + 1]) {
        .return_value => |value| value,
        else => return false,
    };
    return returned.aggregate and returned.start == initialization.result.start and
        returned.width == initialization.result.width;
}

fn scalarCopyDefinition(
    instructions: []const Machine.Instruction,
    slot: Machine.Slot,
    before: usize,
) ?usize {
    var found: ?usize = null;
    for (instructions, 0..) |instruction, index| {
        if (!ResidenceLiveness.instructionDefines(instruction, slot)) continue;
        if (index >= before or found != null) return null;
        const copy = switch (instruction) {
            .copy => |value| value,
            else => return null,
        };
        if (copy.result != slot or copy.operand == slot) return null;
        found = index;
    }
    return found;
}

fn slotUsedOnlyByInstruction(
    instructions: []const Machine.Instruction,
    slot: Machine.Slot,
    expected: usize,
) bool {
    var found = false;
    for (instructions, 0..) |instruction, index| {
        if (!ResidenceLiveness.instructionUses(instruction, slot)) continue;
        if (index != expected) return false;
        found = true;
    }
    return found;
}

fn controlTargetsInstruction(instructions: []const Machine.Instruction, target: usize) bool {
    for (instructions) |instruction| switch (instruction) {
        .jump => |value| if (value == target) return true,
        .branch => |value| if (value.then_instruction == target or value.else_instruction == target) return true,
        else => {},
    };
    return false;
}

fn soleDirectCallUse(instructions: []const Machine.Instruction, span: Machine.Span, after: usize) ?usize {
    var found: ?usize = null;
    for (instructions[after + 1 ..], after + 1..) |instruction, index| {
        if (!instructionUsesSpan(instruction, span)) continue;
        const call = switch (instruction) {
            .call => |value| value,
            else => return null,
        };
        var exact = false;
        for (call.arguments) |argument| {
            if (spansOverlap(argument, span) and !sameSpan(argument, span)) return null;
            exact = exact or sameSpan(argument, span);
        }
        if (!exact or (found != null and found.? != index)) return null;
        found = index;
    }
    return found;
}

fn instructionUsesSpan(instruction: Machine.Instruction, span: Machine.Span) bool {
    for (0..span.width) |leaf| {
        if (ResidenceLiveness.instructionUses(instruction, @as(usize, span.start) + leaf)) return true;
    }
    return false;
}

fn spanDefinedOnlyAt(instructions: []const Machine.Instruction, span: Machine.Span, expected: usize) bool {
    for (instructions, 0..) |instruction, index| for (0..span.width) |leaf| {
        if (ResidenceLiveness.instructionDefines(instruction, @as(usize, span.start) + leaf) and index != expected) return false;
    };
    return true;
}

fn spanDefinedBetween(instructions: []const Machine.Instruction, span: Machine.Span, first: usize, last: usize) bool {
    for (instructions[first..last]) |instruction| for (0..span.width) |leaf| {
        if (ResidenceLiveness.instructionDefines(instruction, @as(usize, span.start) + leaf)) return true;
    };
    return false;
}

fn spanAddressed(instructions: []const Machine.Instruction, span: Machine.Span) bool {
    for (instructions) |instruction| switch (instruction) {
        .local_address => |address| if (spansOverlap(span, .{ .start = address.local, .width = address.width })) return true,
        else => {},
    };
    return false;
}

fn sameSpan(left: Machine.Span, right: Machine.Span) bool {
    return left.start == right.start and left.width == right.width and left.aggregate == right.aggregate;
}

fn spansOverlap(left: Machine.Span, right: Machine.Span) bool {
    const left_end = @as(usize, left.start) + left.width;
    const right_end = @as(usize, right.start) + right.width;
    return @as(usize, left.start) < right_end and @as(usize, right.start) < left_end;
}

fn fixture(instructions: []const Machine.Instruction) Machine.Function {
    return .{
        .name = "aggregate_call_forwarding",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 2, .aggregate = true }},
        .return_type = .void,
        .slot_count = 7,
        .frame_size = Machine.frameSize(7) catch unreachable,
        .instructions = instructions,
    };
}

test "forward an unchanged aggregate copy before a direct call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const instructions = [_]Machine.Instruction{
        .{ .copy_range = .{
            .result = .{ .start = 2, .width = 2, .aggregate = true },
            .operand = .{ .start = 0, .width = 2, .aggregate = true },
        } },
        .{ .constant_bool = .{ .result = 4, .value = true } },
        .{ .call = .{
            .result = null,
            .function = 1,
            .arguments = &.{.{ .start = 2, .width = 2, .aggregate = true }},
        } },
        .return_void,
    };
    const result = try optimize(arena.allocator(), fixture(&instructions));
    try std.testing.expectEqual(@as(usize, 3), result.instructions.len);
    try std.testing.expectEqual(@as(Machine.Slot, 0), result.instructions[1].call.arguments[0].start);
}

test "retain a captured aggregate copy when its source changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const instructions = [_]Machine.Instruction{
        .{ .copy_range = .{
            .result = .{ .start = 2, .width = 2, .aggregate = true },
            .operand = .{ .start = 0, .width = 2, .aggregate = true },
        } },
        .{ .copy_range = .{
            .result = .{ .start = 0, .width = 2, .aggregate = true },
            .operand = .{ .start = 5, .width = 2, .aggregate = true },
        } },
        .{ .call = .{
            .result = null,
            .function = 1,
            .arguments = &.{.{ .start = 2, .width = 2, .aggregate = true }},
        } },
        .return_void,
    };
    const result = try optimize(arena.allocator(), fixture(&instructions));
    try std.testing.expectEqual(@as(usize, instructions.len), result.instructions.len);
    try std.testing.expectEqual(@as(Machine.Slot, 2), result.instructions[2].call.arguments[0].start);
}

test "remap control flow that targets a removed aggregate copy" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const instructions = [_]Machine.Instruction{
        .{ .branch = .{ .condition = 4, .then_instruction = 1, .else_instruction = 3 } },
        .{ .copy_range = .{
            .result = .{ .start = 2, .width = 2, .aggregate = true },
            .operand = .{ .start = 0, .width = 2, .aggregate = true },
        } },
        .{ .call = .{
            .result = null,
            .function = 1,
            .arguments = &.{.{ .start = 2, .width = 2, .aggregate = true }},
        } },
        .return_void,
    };
    const result = try optimize(arena.allocator(), fixture(&instructions));
    try std.testing.expectEqual(@as(usize, 3), result.instructions.len);
    try std.testing.expectEqual(@as(usize, 1), result.instructions[0].branch.then_instruction);
    try std.testing.expectEqual(@as(usize, 2), result.instructions[0].branch.else_instruction);
}

test "forward scalar copies into an immediately returned aggregate" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 0, .bits = 0x3f800000 } },
        .{ .copy = .{ .result = 1, .operand = 0 } },
        .{ .aggregate_init = .{
            .result = .{ .start = 2, .width = 1, .aggregate = true },
            .fields = &.{.{ .start = 1, .width = 1 }},
        } },
        .{ .return_value = .{ .start = 2, .width = 1, .aggregate = true } },
    };
    const result = try optimize(arena.allocator(), fixture(&instructions));
    try std.testing.expectEqual(@as(usize, 3), result.instructions.len);
    try std.testing.expectEqual(@as(Machine.Slot, 0), result.instructions[1].aggregate_init.fields[0].start);
}

test "retain a return field copy when its source changes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 0, .bits = 0x3f800000 } },
        .{ .copy = .{ .result = 1, .operand = 0 } },
        .{ .constant_float32 = .{ .result = 0, .bits = 0x40000000 } },
        .{ .aggregate_init = .{
            .result = .{ .start = 2, .width = 1, .aggregate = true },
            .fields = &.{.{ .start = 1, .width = 1 }},
        } },
        .{ .return_value = .{ .start = 2, .width = 1, .aggregate = true } },
    };
    const result = try optimize(arena.allocator(), fixture(&instructions));
    try std.testing.expectEqual(@as(usize, instructions.len), result.instructions.len);
    try std.testing.expectEqual(@as(Machine.Slot, 1), result.instructions[3].aggregate_init.fields[0].start);
}
