const std = @import("std");
const Machine = @import("Machine.zig");
const ResidenceLiveness = @import("ResidenceLiveness.zig");

const Allocator = std.mem.Allocator;

/// Redirects a direct call from a temporary aggregate copy to the unchanged
/// source before register allocation. Keeping the source as an explicit call
/// operand lets liveness and stack forcing preserve its authoritative storage.
pub fn optimize(allocator: Allocator, function: Machine.Function) Allocator.Error!Machine.Function {
    const instructions = try allocator.dupe(Machine.Instruction, function.instructions);
    var changed = false;
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
        changed = true;
    }
    if (!changed) {
        allocator.free(instructions);
        return function;
    }
    var result = function;
    result.instructions = instructions;
    return result;
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
    try std.testing.expectEqual(@as(Machine.Slot, 0), result.instructions[2].call.arguments[0].start);
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
    try std.testing.expectEqual(@as(Machine.Slot, 2), result.instructions[2].call.arguments[0].start);
}
