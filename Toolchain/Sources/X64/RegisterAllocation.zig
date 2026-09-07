const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const FloatLaneAllocation = @import("../Arm64/RegisterAllocation.zig");

const Allocator = std.mem.Allocator;
// These registers are volatile in both the System V and Windows X64 ABIs.
// Regional allocation pins every value used by or live across a call, so a
// call can invalidate their contents only after the allocated interval ends.
const registers = [_]u5{ 8, 9, 10, 11 };
// XMM0...XMM5 are volatile in both System V and Win64. Keep XMM3...XMM5
// reserved for pair packing and packed arithmetic scratch values.
const float_lane_registers = [_]u5{ 0, 1, 2 };

const Interval = struct {
    slot: Machine.Slot,
    first: usize,
    last: usize,
    weight: u64,
};

pub fn allocateProgram(allocator: Allocator, program: Machine.Program) (Allocator.Error || Machine.Error)!Machine.Program {
    var result = program;
    const functions = try allocator.alloc(Machine.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        functions[index] = function;
        functions[index].register_slots = try allocate(allocator, function);
        functions[index].float_lane_slots = try FloatLaneAllocation.allocateFloatLanePairsFor(
            allocator,
            function,
            .x64,
            &float_lane_registers,
        );
        functions[index].stack_slot_base = residentStackPrefix(function, functions[index].register_slots);
        functions[index].frame_size = try Machine.frameSize(function.slot_count - functions[index].stack_slot_base);
    }
    result.functions = functions;
    try Machine.validate(result);
    return result;
}

fn residentStackPrefix(function: Machine.Function, residences: []const ?u5) Machine.Slot {
    // Keeping the virtual offsets unchanged is safe only while every skipped
    // slot is backed by a register. The first stack home anchors the physical
    // suffix of the frame.
    if (residences.len != function.slot_count) return 0;
    for (residences, 0..) |residence, slot| {
        if (residence == null) return @intCast(slot);
    }
    return function.slot_count;
}

pub fn allocate(allocator: Allocator, function: Machine.Function) Allocator.Error![]const ?u5 {
    const fully_compatible = compatible(function);
    if (!fully_compatible and !regionallyCompatible(function)) return &.{};
    const residences = try allocator.alloc(?u5, function.slot_count);
    @memset(residences, null);
    const forced = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(forced);
    @memset(forced, false);
    const first = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(first);
    const last = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(last);
    const weights = try allocator.alloc(u64, function.slot_count);
    defer allocator.free(weights);
    const instruction_weights = try allocator.alloc(u64, function.instructions.len);
    defer allocator.free(instruction_weights);
    @memset(first, std.math.maxInt(usize));
    @memset(last, 0);
    @memset(weights, 0);
    @memset(instruction_weights, 1);
    if (!fully_compatible) weightLoops(function.instructions, instruction_weights);

    for (function.parameters) |parameter| touch(parameter.start, 0, first, last, weights, 1);
    for (function.instructions, 0..) |instruction, index| {
        visit(instruction, index, first, last, weights, instruction_weights[index]);
    }
    if (!fully_compatible) {
        extendLoopCarriedIntervals(function.instructions, first, last);
        for (function.instructions, 0..) |instruction, index| {
            // X64 output owns every volatile scratch register. Keep complete
            // intervals crossing that barrier in their deterministic homes;
            // registers are then used only by regions that end before it.
            if (!compatibleInstruction(instruction)) pinIntervalsAt(index, first, last, forced);
        }
    }

    var intervals: std.ArrayList(Interval) = .empty;
    defer intervals.deinit(allocator);
    for (first, 0..) |start, slot| if (start != std.math.maxInt(usize) and !forced[slot]) try intervals.append(allocator, .{
        .slot = @intCast(slot),
        .first = start,
        .last = last[slot],
        .weight = weights[slot],
    });
    try allocateGraph(allocator, residences, intervals.items, function.instructions, function.slot_count);
    return residences;
}

fn compatible(function: Machine.Function) bool {
    if (!compatibleShape(function)) return false;
    for (function.instructions) |instruction| if (!compatibleInstruction(instruction)) return false;
    return true;
}

fn regionallyCompatible(function: Machine.Function) bool {
    // Four arithmetic operations amortize the extra allocation machinery and
    // match the target-independent scalar-loop threshold used by ARM64.
    if (!compatibleShape(function) or !hasProfitableLoopRegion(function.instructions)) return false;
    for (function.instructions) |instruction| {
        if (compatibleInstruction(instruction)) continue;
        switch (instruction) {
            .print => |value| switch (value.kind) {
                .signed_integer, .unsigned_integer, .boolean => {},
                .string, .float32, .float64 => return false,
            },
            .copy_range, .aggregate_init, .call => {},
            else => return false,
        }
    }
    return true;
}

fn compatibleShape(function: Machine.Function) bool {
    if (function.reuses_slots or function.hidden_return_slot != null or function.capture_parameters.len != 0 or
        function.float_register_slots.len != 0 or function.float_lane_slots.len != 0)
    {
        return false;
    }
    for (function.parameters) |parameter| if (parameter.aggregate or parameter.width != 1) return false;
    return true;
}

fn compatibleInstruction(instruction: Machine.Instruction) bool {
    return switch (instruction) {
        .constant_int, .constant_bool, .copy, .return_void, .jump, .branch => true,
        .unary => |value| !value.type.isFloat() and value.type != .str,
        .binary => |value| !value.type.isFloat() and value.type != .str,
        .return_value => |value| !value.aggregate and value.width == 1,
        else => false,
    };
}

fn visit(instruction: Machine.Instruction, index: usize, first: []usize, last: []usize, weights: []u64, weight: u64) void {
    switch (instruction) {
        .constant_int => |value| touch(value.result, index, first, last, weights, weight),
        .constant_bool => |value| touch(value.result, index, first, last, weights, weight),
        .copy => |value| {
            touch(value.operand, index, first, last, weights, weight);
            touch(value.result, index, first, last, weights, weight);
        },
        .unary => |value| {
            touch(value.operand, index, first, last, weights, weight);
            touch(value.result, index, first, last, weights, weight);
        },
        .binary => |value| {
            touch(value.left, index, first, last, weights, weight);
            touch(value.right, index, first, last, weights, weight);
            touch(value.result, index, first, last, weights, weight);
        },
        .return_value => |value| touch(value.start, index, first, last, weights, weight),
        .branch => |value| touch(value.condition, index, first, last, weights, weight),
        .print => |value| touch(value.value, index, first, last, weights, weight),
        .copy_range => |value| {
            touchSpan(value.operand, index, first, last, weights, weight);
            touchSpan(value.result, index, first, last, weights, weight);
        },
        .aggregate_init => |value| {
            for (value.fields) |field| touchSpan(field, index, first, last, weights, weight);
            touchSpan(value.result, index, first, last, weights, weight);
        },
        .call => |value| {
            for (value.arguments) |argument| touchSpan(argument, index, first, last, weights, weight);
            if (value.result) |result| touchSpan(result, index, first, last, weights, weight);
        },
        else => {},
    }
}

fn touchSpan(span: Machine.Span, index: usize, first: []usize, last: []usize, weights: []u64, weight: u64) void {
    for (0..span.width) |leaf| {
        touch(@intCast(@as(usize, span.start) + leaf), index, first, last, weights, weight);
    }
}

fn touch(slot: Machine.Slot, index: usize, first: []usize, last: []usize, weights: []u64, weight: u64) void {
    first[slot] = @min(first[slot], index);
    last[slot] = @max(last[slot], index);
    weights[slot] = std.math.add(u64, weights[slot], weight) catch std.math.maxInt(u64);
}

fn heavierInterval(_: void, left: Interval, right: Interval) bool {
    if (left.weight != right.weight) return left.weight > right.weight;
    return left.slot < right.slot;
}

fn hasProfitableLoopRegion(instructions: []const Machine.Instruction) bool {
    for (instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= source and profitableLoopRange(instructions[target .. source + 1])) return true,
        .branch => |branch| {
            if (branch.then_instruction <= source and
                profitableLoopRange(instructions[branch.then_instruction .. source + 1])) return true;
            if (branch.else_instruction <= source and
                profitableLoopRange(instructions[branch.else_instruction .. source + 1])) return true;
        },
        else => {},
    };
    return false;
}

fn profitableLoopRange(instructions: []const Machine.Instruction) bool {
    var arithmetic: usize = 0;
    for (instructions) |instruction| {
        if (!compatibleInstruction(instruction)) return false;
        arithmetic += switch (instruction) {
            .binary, .unary => 1,
            else => 0,
        };
    }
    return arithmetic >= 4;
}

fn weightLoops(instructions: []const Machine.Instruction, weights: []u64) void {
    for (instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= source) weightRange(target, source, weights),
        .branch => |branch| {
            if (branch.then_instruction <= source) weightRange(branch.then_instruction, source, weights);
            if (branch.else_instruction <= source) weightRange(branch.else_instruction, source, weights);
        },
        else => {},
    };
}

fn weightRange(first: usize, last: usize, weights: []u64) void {
    for (weights[first .. last + 1]) |*weight| weight.* = std.math.mul(u64, weight.*, 32) catch std.math.maxInt(u64);
}

fn extendLoopCarriedIntervals(instructions: []const Machine.Instruction, first: []const usize, last: []usize) void {
    for (instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= source) extendBackEdge(target, source, first, last),
        .branch => |branch| {
            if (branch.then_instruction <= source) extendBackEdge(branch.then_instruction, source, first, last);
            if (branch.else_instruction <= source) extendBackEdge(branch.else_instruction, source, first, last);
        },
        else => {},
    };
}

fn extendBackEdge(target: usize, source: usize, first: []const usize, last: []usize) void {
    for (first, last) |start, *end| {
        if (start < target and end.* >= target and end.* < source) end.* = source;
    }
}

fn pinIntervalsAt(index: usize, first: []const usize, last: []const usize, forced: []bool) void {
    for (first, last, forced) |start, end, *pinned| {
        if (start != std.math.maxInt(usize) and start <= index and end >= index) pinned.* = true;
    }
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
        .print => |value| value.value == slot,
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

test "allocate portable float32 pairs in baseline X64 SIMD registers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 0, .bits = @bitCast(@as(f32, 2.0)) } },
        .{ .constant_float32 = .{ .result = 1, .bits = @bitCast(@as(f32, 2.0)) } },
        .{ .constant_float32 = .{ .result = 2, .bits = @bitCast(@as(f32, 3.0)) } },
        .{ .constant_float32 = .{ .result = 3, .bits = @bitCast(@as(f32, 3.0)) } },
        .{ .binary = .{ .result = 4, .operator = .multiply, .left = 0, .right = 2, .type = .float32 } },
        .{ .binary = .{ .result = 5, .operator = .multiply, .left = 1, .right = 3, .type = .float32 } },
        .return_void,
    };
    const groups = [_]Machine.FloatLaneGroup{.{
        .slots = .{ 4, 5, 0, 0 },
        .width = 2,
        .priority = 8,
        .recurrence = false,
        .in_loop = true,
    }};
    const functions = [_]Machine.Function{.{
        .name = "main",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 6,
        .frame_size = 48,
        .float_lane_groups = &groups,
        .instructions = &instructions,
    }};
    const allocated = try allocateProgram(allocator, .{ .functions = &functions });
    const lanes = allocated.functions[0].float_lane_slots;
    try std.testing.expectEqual(@as(usize, 6), lanes.len);
    const first = lanes[4] orelse return error.TestUnexpectedResult;
    const second = lanes[5] orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(first.register, second.register);
    try std.testing.expectEqual(@as(u1, 0), first.lane);
    try std.testing.expectEqual(@as(u1, 1), second.lane);
}

test "hot X64 scalar loops retain registers before a terminal print barrier" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 12345 } },
        .{ .constant_int = .{ .result = 1, .bits = 5_000_000 } },
        .{ .constant_int = .{ .result = 2, .bits = 0 } },
        .{ .copy = .{ .result = 11, .operand = 0 } },
        .{ .copy = .{ .result = 12, .operand = 2 } },
        .{ .jump = 6 },
        .{ .binary = .{ .result = 3, .operator = .less, .left = 12, .right = 1 } },
        .{ .branch = .{ .condition = 3, .then_instruction = 8, .else_instruction = 18 } },
        .{ .constant_int = .{ .result = 4, .bits = 17 } },
        .{ .binary = .{ .result = 5, .operator = .multiply, .left = 11, .right = 4, .checked = false } },
        .{ .binary = .{ .result = 6, .operator = .add, .left = 5, .right = 12 } },
        .{ .constant_int = .{ .result = 7, .bits = 1_000_003 } },
        .{ .binary = .{ .result = 8, .operator = .remainder, .left = 6, .right = 7, .checked = false } },
        .{ .constant_int = .{ .result = 9, .bits = 1 } },
        .{ .binary = .{ .result = 10, .operator = .add, .left = 12, .right = 9, .checked = false } },
        .{ .copy = .{ .result = 11, .operand = 8 } },
        .{ .copy = .{ .result = 12, .operand = 10 } },
        .{ .jump = 6 },
        .{ .print = .{ .value = 11, .kind = .signed_integer, .newline = true } },
        .return_void,
    };
    const residences = try allocate(std.testing.allocator, .{
        .name = "integer_loop_with_print",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 13,
        .frame_size = try Machine.frameSize(13),
        .instructions = &instructions,
    });
    defer std.testing.allocator.free(residences);

    try std.testing.expectEqual(@as(usize, 13), residences.len);
    try std.testing.expect(residences[12] != null);
    try std.testing.expect(residences[5] != null);
    try std.testing.expect(residences[6] != null);
    try std.testing.expect(residences[8] != null);
    try std.testing.expect(residences[10] != null);
    try std.testing.expectEqual(@as(?u5, null), residences[11]);

    const short_instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 0 } },
        .{ .constant_int = .{ .result = 1, .bits = 1 } },
        .{ .jump = 3 },
        .{ .binary = .{ .result = 2, .operator = .less, .left = 0, .right = 1 } },
        .{ .branch = .{ .condition = 2, .then_instruction = 5, .else_instruction = 9 } },
        .{ .binary = .{ .result = 3, .operator = .add, .left = 0, .right = 1 } },
        .{ .binary = .{ .result = 4, .operator = .add, .left = 3, .right = 1 } },
        .{ .copy = .{ .result = 0, .operand = 4 } },
        .{ .jump = 3 },
        .{ .print = .{ .value = 0, .kind = .signed_integer, .newline = true } },
        .return_void,
    };
    const short = try allocate(std.testing.allocator, .{
        .name = "short_loop_with_print",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 5,
        .frame_size = try Machine.frameSize(5),
        .instructions = &short_instructions,
    });
    try std.testing.expectEqual(@as(usize, 0), short.len);
}

test "hot X64 scalar loops retain registers before aggregate and call barriers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const fields = [_]Machine.Span{
        .{ .start = 11, .width = 1 },
        .{ .start = 12, .width = 1 },
    };
    const arguments = [_]Machine.Span{.{ .start = 13, .width = 2, .aggregate = true }};
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 12345 } },
        .{ .constant_int = .{ .result = 1, .bits = 64 } },
        .{ .constant_int = .{ .result = 2, .bits = 0 } },
        .{ .copy = .{ .result = 11, .operand = 0 } },
        .{ .copy = .{ .result = 12, .operand = 2 } },
        .{ .jump = 6 },
        .{ .binary = .{ .result = 3, .operator = .less, .left = 12, .right = 1 } },
        .{ .branch = .{ .condition = 3, .then_instruction = 8, .else_instruction = 18 } },
        .{ .constant_int = .{ .result = 4, .bits = 17 } },
        .{ .binary = .{ .result = 5, .operator = .multiply, .left = 11, .right = 4, .checked = false } },
        .{ .binary = .{ .result = 6, .operator = .add, .left = 5, .right = 12 } },
        .{ .constant_int = .{ .result = 7, .bits = 1_000_003 } },
        .{ .binary = .{ .result = 8, .operator = .remainder, .left = 6, .right = 7, .checked = false } },
        .{ .constant_int = .{ .result = 9, .bits = 1 } },
        .{ .binary = .{ .result = 10, .operator = .add, .left = 12, .right = 9, .checked = false } },
        .{ .copy = .{ .result = 11, .operand = 8 } },
        .{ .copy = .{ .result = 12, .operand = 10 } },
        .{ .jump = 6 },
        .{ .aggregate_init = .{
            .result = .{ .start = 13, .width = 2, .aggregate = true },
            .fields = &fields,
        } },
        .{ .call = .{ .result = null, .function = 1, .arguments = &arguments } },
        .return_void,
    };
    const callee_parameters = [_]Machine.Span{.{ .start = 0, .width = 2, .aggregate = true }};
    const callee_instructions = [_]Machine.Instruction{.return_void};
    const functions = [_]Machine.Function{
        .{
            .name = "integer_loop_with_aggregate_call",
            .parameter_count = 0,
            .return_type = .void,
            .slot_count = 15,
            .frame_size = try Machine.frameSize(15),
            .instructions = &instructions,
        },
        .{
            .name = "consume_pair",
            .parameter_count = 1,
            .parameters = &callee_parameters,
            .return_type = .void,
            .slot_count = 2,
            .frame_size = try Machine.frameSize(2),
            .instructions = &callee_instructions,
        },
    };
    const allocated = try allocateProgram(allocator, .{ .functions = &functions });
    const function = allocated.functions[0];
    const residences = function.register_slots;

    try std.testing.expectEqual(@as(usize, 15), residences.len);
    for ([_]usize{ 3, 4, 5, 6, 7, 8, 9, 10 }) |slot| {
        try std.testing.expect(residences[slot] != null);
    }
    for ([_]usize{ 11, 12, 13, 14 }) |slot| {
        try std.testing.expectEqual(@as(?u5, null), residences[slot]);
    }
    try std.testing.expectEqual(@as(Machine.Slot, 11), function.stack_slot_base);
    try std.testing.expectEqual(@as(u32, 32), function.frame_size);
}
