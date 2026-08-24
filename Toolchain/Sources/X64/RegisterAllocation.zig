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
    try allocateGraph(allocator, residences, intervals.items, function.instructions, function.slot_count);
    return residences;
}

fn compatible(function: Machine.Function) bool {
    if (function.hidden_return_slot != null or function.capture_parameters.len != 0 or
        function.float_register_slots.len != 0 or function.float_lane_slots.len != 0)
    {
        return false;
    }
    for (function.parameters) |parameter| if (parameter.aggregate or parameter.width != 1) return false;
    for (function.instructions) |instruction| {
        switch (instruction) {
            .constant_int, .constant_bool, .copy, .return_void, .jump, .branch => {},
            .unary => |value| if (value.type.isFloat() or value.type == .str) return false,
            .binary => |value| if (value.type.isFloat() or value.type == .str) return false,
            .return_value => |value| if (value.aggregate or value.width != 1) return false,
            else => return false,
        }
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
        .branch => |value| touch(value.condition, index, first, last, weights),
        .return_void => {},
        .jump => {},
        else => unreachable,
    }
}

fn touch(slot: Machine.Slot, index: usize, first: []usize, last: []usize, weights: []usize) void {
    first[slot] = @min(first[slot], index);
    last[slot] = @max(last[slot], index);
    weights[slot] += 1;
}

fn heavierInterval(_: void, left: Interval, right: Interval) bool {
    if (left.weight != right.weight) return left.weight > right.weight;
    return left.slot < right.slot;
}

fn allocateGraph(
    allocator: Allocator,
    residences: []?u5,
    intervals: []Interval,
    instructions: []const Machine.Instruction,
    slot_count: usize,
) Allocator.Error!void {
    const live = try allocator.alloc(bool, instructions.len * slot_count);
    defer allocator.free(live);
    @memset(live, false);
    var changed = true;
    while (changed) {
        changed = false;
        var reverse = instructions.len;
        while (reverse != 0) {
            reverse -= 1;
            for (0..slot_count) |slot| {
                const out = successorLive(instructions, live, slot_count, reverse, slot);
                const value = instructionUses(instructions[reverse], slot) or
                    (out and !instructionDefines(instructions[reverse], slot));
                const index = reverse * slot_count + slot;
                if (live[index] != value) {
                    live[index] = value;
                    changed = true;
                }
            }
        }
    }
    std.mem.sort(Interval, intervals, {}, heavierInterval);
    for (intervals) |interval| {
        if (copyResidence(interval.slot, residences, instructions, live, slot_count)) |preferred| {
            if (!colorConflicts(interval.slot, preferred, residences, instructions, live, slot_count)) {
                residences[interval.slot] = preferred;
                continue;
            }
        }
        for (registers) |register| {
            if (!colorConflicts(interval.slot, register, residences, instructions, live, slot_count)) {
                residences[interval.slot] = register;
                break;
            }
        }
    }
}

fn successorLive(
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
    index: usize,
    slot: usize,
) bool {
    return switch (instructions[index]) {
        .jump => |target| live[target * slot_count + slot],
        .branch => |branch| live[branch.then_instruction * slot_count + slot] or
            live[branch.else_instruction * slot_count + slot],
        .return_value, .return_void => false,
        else => if (index + 1 < instructions.len) live[(index + 1) * slot_count + slot] else false,
    };
}

fn instructionUses(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .copy => |value| value.operand == slot,
        .unary => |value| value.operand == slot,
        .binary => |value| value.left == slot or value.right == slot,
        .return_value => |value| value.start == slot,
        .branch => |value| value.condition == slot,
        else => false,
    };
}

fn instructionDefines(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .constant_int => |value| value.result == slot,
        .constant_bool => |value| value.result == slot,
        .copy => |value| value.result == slot,
        .unary => |value| value.result == slot,
        .binary => |value| value.result == slot,
        else => false,
    };
}

fn copyResidence(
    slot: Machine.Slot,
    residences: []const ?u5,
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
) ?u5 {
    for (instructions, 0..) |instruction, index| switch (instruction) {
        .copy => |copy| {
            if (copy.result == slot and
                !successorLive(instructions, live, slot_count, index, copy.operand))
            {
                return residences[copy.operand];
            }
            if (copy.operand == slot and
                !successorLive(instructions, live, slot_count, index, copy.operand))
            {
                return residences[copy.result];
            }
        },
        .binary => |binary| if (binary.result == slot and
            !successorLive(instructions, live, slot_count, index, binary.left))
        {
            return residences[binary.left];
        },
        else => {},
    };
    return null;
}

fn colorConflicts(
    slot: Machine.Slot,
    register: u5,
    residences: []const ?u5,
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
) bool {
    for (residences, 0..) |residence, other| {
        if (other == slot or residence == null or residence.? != register) continue;
        for (instructions, 0..) |instruction, index| {
            if (instruction == .copy) {
                const copy = instruction.copy;
                if (((copy.result == slot and copy.operand == other) or
                    (copy.result == other and copy.operand == slot)) and
                    !successorLive(instructions, live, slot_count, index, copy.operand)) continue;
            }
            if (instruction == .binary) {
                const binary = instruction.binary;
                if (((binary.result == slot and binary.left == other) or
                    (binary.result == other and binary.left == slot)) and
                    !successorLive(instructions, live, slot_count, index, binary.left)) continue;
            }
            if (live[index * slot_count + slot] and live[index * slot_count + other]) return true;
            if (instructionDefines(instruction, slot) and live[index * slot_count + other]) return true;
            if (instructionDefines(instruction, other) and live[index * slot_count + slot]) return true;
        }
    }
    return false;
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

test "allocate X64 scalar values globally across a loop" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 0 } },
        .{ .constant_int = .{ .result = 1, .bits = 1 } },
        .{ .constant_int = .{ .result = 2, .bits = 4 } },
        .{ .binary = .{ .result = 3, .operator = .less, .left = 0, .right = 2 } },
        .{ .branch = .{ .condition = 3, .then_instruction = 5, .else_instruction = 8 } },
        .{ .binary = .{ .result = 4, .operator = .add, .left = 0, .right = 1 } },
        .{ .copy = .{ .result = 0, .operand = 4 } },
        .{ .jump = 3 },
        .{ .return_value = .{ .start = 0, .width = 1 } },
    };
    const residences = try allocate(std.testing.allocator, .{
        .name = "loop",
        .parameter_count = 0,
        .return_type = .int,
        .slot_count = 5,
        .frame_size = 48,
        .instructions = &instructions,
    });
    defer std.testing.allocator.free(residences);
    try std.testing.expectEqual(@as(usize, 5), residences.len);
    try std.testing.expect(residences[0] != null);
    try std.testing.expectEqual(residences[0], residences[4]);
    try std.testing.expect(residences[3] != null);
}
