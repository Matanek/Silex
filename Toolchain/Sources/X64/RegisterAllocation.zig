const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");

const Allocator = std.mem.Allocator;
// These registers are volatile in both the System V and Windows X64 ABIs.
// Compatible functions are leaves, so no call can invalidate their contents.
const registers = [_]u5{ 8, 9, 10, 11 };

const Interval = struct {
    slot: Machine.Slot,
    first: usize,
    last: usize,
    weight: usize,
};

pub fn allocateProgram(allocator: Allocator, program: Machine.Program) (Allocator.Error || Machine.Error)!Machine.Program {
    var result = program;
    const functions = try allocator.alloc(Machine.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        functions[index] = function;
        functions[index].register_slots = try allocate(allocator, function);
    }
    result.functions = functions;
    try Machine.validate(result);
    return result;
}

pub fn allocate(allocator: Allocator, function: Machine.Function) Allocator.Error![]const ?u5 {
    if (!compatible(function)) return &.{};
    const residences = try allocator.alloc(?u5, function.slot_count);
    @memset(residences, null);
    const first = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(first);
    const last = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(last);
    const weights = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(weights);
    @memset(first, std.math.maxInt(usize));
    @memset(last, 0);
    @memset(weights, 0);

    for (function.parameters) |parameter| touch(parameter.start, 0, first, last, weights);
    for (function.instructions, 0..) |instruction, index| visit(instruction, index, first, last, weights);

    var intervals: std.ArrayList(Interval) = .empty;
    defer intervals.deinit(allocator);
    for (first, 0..) |start, slot| if (start != std.math.maxInt(usize)) try intervals.append(allocator, .{
        .slot = @intCast(slot),
        .first = start,
        .last = last[slot],
        .weight = weights[slot],
    });
    std.mem.sort(Interval, intervals.items, {}, earlierInterval);

    var active: std.ArrayList(Interval) = .empty;
    defer active.deinit(allocator);
    for (intervals.items) |interval| {
        var used = [_]bool{false} ** registers.len;
        var active_index: usize = 0;
        while (active_index < active.items.len) {
            if (active.items[active_index].last < interval.first) {
                _ = active.swapRemove(active_index);
                continue;
            }
            if (residences[active.items[active_index].slot]) |residence| {
                for (registers, 0..) |register, register_index| {
                    if (register == residence) used[register_index] = true;
                }
            }
            active_index += 1;
        }
        for (registers, 0..) |register, register_index| if (!used[register_index]) {
            residences[interval.slot] = register;
            try active.append(allocator, interval);
            break;
        };
    }
    return residences;
}

fn compatible(function: Machine.Function) bool {
    if (function.hidden_return_slot != null or function.capture_parameters.len != 0 or
        function.float_register_slots.len != 0 or function.float_lane_slots.len != 0)
    {
        return false;
    }
    for (function.parameters) |parameter| if (parameter.aggregate or parameter.width != 1) return false;
    for (function.instructions, 0..) |instruction, index| {
        switch (instruction) {
            .constant_int, .constant_bool, .copy, .return_void => {},
            .unary => |value| if (value.type.isFloat() or value.type == .str) return false,
            .binary => |value| if (value.type.isFloat() or value.type == .str) return false,
            .return_value => |value| if (value.aggregate or value.width != 1) return false,
            else => return false,
        }
        if (index + 1 != function.instructions.len and
            (instruction == .return_void or instruction == .return_value)) return false;
    }
    return true;
}

fn visit(instruction: Machine.Instruction, index: usize, first: []usize, last: []usize, weights: []usize) void {
    switch (instruction) {
        .constant_int => |value| touch(value.result, index, first, last, weights),
        .constant_bool => |value| touch(value.result, index, first, last, weights),
        .copy => |value| {
            touch(value.operand, index, first, last, weights);
            touch(value.result, index, first, last, weights);
        },
        .unary => |value| {
            touch(value.operand, index, first, last, weights);
            touch(value.result, index, first, last, weights);
        },
        .binary => |value| {
            touch(value.left, index, first, last, weights);
            touch(value.right, index, first, last, weights);
            touch(value.result, index, first, last, weights);
        },
        .return_value => |value| touch(value.start, index, first, last, weights),
        .return_void => {},
        else => unreachable,
    }
}

fn touch(slot: Machine.Slot, index: usize, first: []usize, last: []usize, weights: []usize) void {
    first[slot] = @min(first[slot], index);
    last[slot] = @max(last[slot], index);
    weights[slot] += 1;
}

fn earlierInterval(_: void, left: Interval, right: Interval) bool {
    if (left.first != right.first) return left.first < right.first;
    if (left.weight != right.weight) return left.weight > right.weight;
    return left.slot < right.slot;
}

test "allocate X64 volatile scalar residences and spill incompatible functions" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 1 } },
        .{ .constant_int = .{ .result = 1, .bits = 2 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const residences = try allocate(std.testing.allocator, .{
        .name = "sum",
        .parameter_count = 0,
        .return_type = .int,
        .slot_count = 3,
        .frame_size = 32,
        .instructions = &instructions,
    });
    defer std.testing.allocator.free(residences);
    try std.testing.expectEqual(@as(usize, 3), residences.len);
    for (residences) |residence| try std.testing.expect(residence != null);

    const incompatible = [_]Machine.Instruction{ .{ .print = .{ .value = 0, .kind = .signed_integer, .newline = false } }, .return_void };
    try std.testing.expectEqual(@as(usize, 0), (try allocate(std.testing.allocator, .{
        .name = "print",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 1,
        .frame_size = 16,
        .instructions = &incompatible,
    })).len);
}

test "keep operands used by the same X64 instruction in distinct residences" {
    const instructions = [_]Machine.Instruction{
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const residences = try allocate(std.testing.allocator, .{
        .name = "sum",
        .parameter_count = 2,
        .parameters = &.{
            .{ .start = 0, .width = 1 },
            .{ .start = 1, .width = 1 },
        },
        .return_type = .int,
        .slot_count = 3,
        .frame_size = 32,
        .instructions = &instructions,
    });
    defer std.testing.allocator.free(residences);
    try std.testing.expect(residences[0] != null);
    try std.testing.expect(residences[1] != null);
    try std.testing.expect(residences[0] != residences[1]);
}
