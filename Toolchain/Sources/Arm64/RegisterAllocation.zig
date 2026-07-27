const std = @import("std");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;

const Interval = struct {
    slot: Machine.Slot,
    first: usize,
    last: usize,
};

pub const Result = struct {
    residences: []const ?u5,
    frame_size: u16,
};

/// Allocates the conservative Release subset to x17. Functions that touch a
/// runtime helper or an addressable/aggregate value deliberately remain fully
/// spilled until those helpers accept explicit residences.
pub fn allocate(allocator: Allocator, function: Machine.Function) (Allocator.Error || Machine.Error)!Result {
    const residences = try allocator.alloc(?u5, function.slot_count);
    @memset(residences, null);
    if (!isLocalScalarFunction(function)) return .{ .residences = residences, .frame_size = function.frame_size };

    const first = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(first);
    const last = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(last);
    @memset(first, std.math.maxInt(usize));
    @memset(last, 0);
    for (function.instructions, 0..) |instruction, index| visit(instruction, index, first, last);

    var intervals: std.ArrayList(Interval) = .empty;
    defer intervals.deinit(allocator);
    for (first, 0..) |start, slot| if (start != std.math.maxInt(usize)) {
        try intervals.append(allocator, .{ .slot = @intCast(slot), .first = start, .last = last[slot] });
    };
    std.mem.sort(Interval, intervals.items, {}, lessThan);

    var active_last = [_]?usize{ null, null };
    const registers = [_]u5{ 16, 17 };
    for (intervals.items) |interval| {
        for (&active_last, registers) |*end, register| {
            if (end.* == null or end.*.? <= interval.first) {
                residences[interval.slot] = register;
                end.* = interval.last;
                break;
            }
        }
    }
    var spill_slots: usize = 0;
    for (first, 0..) |start, slot| {
        if (start != std.math.maxInt(usize) and residences[slot] == null) spill_slots = slot + 1;
    }
    return .{ .residences = residences, .frame_size = try Machine.frameSize(spill_slots) };
}

fn isLocalScalarFunction(function: Machine.Function) bool {
    for (function.parameters) |parameter| if (parameter.aggregate) return false;
    for (function.instructions) |instruction| switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .unary,
        .return_value,
        .return_void,
        .jump,
        .branch,
        => {},
        .binary => |binary| if (binary.type == .str) return false,
        else => return false,
    };
    return true;
}

fn visit(instruction: Machine.Instruction, index: usize, first: []usize, last: []usize) void {
    switch (instruction) {
        .constant_int => |value| touch(value.result, index, first, last),
        .constant_bool => |value| touch(value.result, index, first, last),
        .constant_float32 => |value| touch(value.result, index, first, last),
        .constant_float64 => |value| touch(value.result, index, first, last),
        .copy => |value| {
            touch(value.operand, index, first, last);
            touch(value.result, index, first, last);
        },
        .unary => |value| {
            touch(value.operand, index, first, last);
            touch(value.result, index, first, last);
        },
        .binary => |value| {
            touch(value.left, index, first, last);
            touch(value.right, index, first, last);
            touch(value.result, index, first, last);
        },
        .external_call => |value| {
            for (value.arguments) |argument| touch(argument, index, first, last);
            if (value.result) |result| touch(result, index, first, last);
        },
        .return_value => |value| touch(value.start, index, first, last),
        .branch => |value| touch(value.condition, index, first, last),
        else => {},
    }
}

fn touch(slot: Machine.Slot, index: usize, first: []usize, last: []usize) void {
    first[slot] = @min(first[slot], index);
    last[slot] = @max(last[slot], index);
}

fn lessThan(_: void, left: Interval, right: Interval) bool {
    return left.first < right.first or (left.first == right.first and left.slot < right.slot);
}

test "linear scan is deterministic and spills overlapping intervals" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 20 } },
        .{ .constant_int = .{ .result = 1, .bits = 22 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const function: Machine.Function = .{
        .name = "answer",
        .parameter_count = 0,
        .return_type = .int,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    try std.testing.expectEqual(@as(?u5, 16), result.residences[0]);
    try std.testing.expectEqual(@as(?u5, 17), result.residences[1]);
    try std.testing.expectEqual(@as(?u5, 16), result.residences[2]);
    try std.testing.expectEqual(@as(u16, 0), result.frame_size);
}
