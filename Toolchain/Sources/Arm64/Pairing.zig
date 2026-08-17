const std = @import("std");
const Machine = @import("Machine.zig");

pub const FloatDivision = struct {
    leader: usize,
    follower: usize,
    numerator: u5,
};

/// Finds two scalar float32 divisions whose numerators already occupy the two
/// lanes of one NEON register and whose copied denominator remains unchanged.
/// A backend can issue one vector division at the leader and extract the
/// second lane at the follower without moving intervening scalar work.
pub fn floatDivisionLeader(
    function: Machine.Function,
    instruction_index: usize,
    division: Machine.Instruction.Binary,
) ?FloatDivision {
    if (division.type != .float32 or division.operator != .divide or
        floatLaneResidence(function, division.result) != null or
        !slotHasLastUseAt(function.instructions, division.left, instruction_index)) return null;
    const first = floatLaneResidence(function, division.left) orelse return null;
    if (first.lane != 0) return null;
    const denominator = transferRootBefore(function.instructions, instruction_index, division.right);
    const limit = @min(function.instructions.len, instruction_index + 12);
    for (function.instructions[instruction_index + 1 .. limit], instruction_index + 1..) |instruction, index| {
        const candidate = switch (instruction) {
            .binary => |binary| candidate: {
                if (binary.result == denominator) return null;
                break :candidate binary;
            },
            .copy => |copy| {
                if (copy.result == denominator) return null;
                continue;
            },
            .copy_range => |copy| {
                if (spanContainsSlot(copy.result, denominator)) return null;
                continue;
            },
            else => return null,
        };
        if (candidate.type != .float32 or candidate.operator != .divide or
            floatLaneResidence(function, candidate.result) != null or
            !slotHasLastUseAt(function.instructions, candidate.left, index)) continue;
        const second = floatLaneResidence(function, candidate.left) orelse continue;
        if (second.register != first.register or second.lane != 1 or second.partner != division.left or
            transferRootBefore(function.instructions, index, candidate.right) != denominator) continue;
        return .{
            .leader = instruction_index,
            .follower = index,
            .numerator = first.register,
        };
    }
    return null;
}

pub fn floatDivisionFollower(
    function: Machine.Function,
    instruction_index: usize,
    division: Machine.Instruction.Binary,
) ?FloatDivision {
    const start = instruction_index -| 11;
    for (function.instructions[start..instruction_index], start..) |instruction, index| {
        const leader = switch (instruction) {
            .binary => |binary| floatDivisionLeader(function, index, binary),
            else => null,
        } orelse continue;
        if (leader.follower == instruction_index and
            function.instructions[instruction_index].binary.result == division.result) return leader;
    }
    return null;
}

fn transferRootBefore(
    instructions: []const Machine.Instruction,
    before: usize,
    initial: Machine.Slot,
) Machine.Slot {
    var slot = initial;
    for (0..instructions.len) |_| {
        const operand = definingTransferOperandBefore(instructions, before, slot) orelse break;
        if (operand == slot) break;
        slot = operand;
    }
    return slot;
}

fn definingTransferOperandBefore(
    instructions: []const Machine.Instruction,
    before: usize,
    slot: Machine.Slot,
) ?Machine.Slot {
    var index = before;
    while (index != 0) {
        index -= 1;
        switch (instructions[index]) {
            .copy => |copy| if (copy.result == slot) return copy.operand,
            .copy_range => |copy| if (spanContainsSlot(copy.result, slot)) {
                return copy.operand.start + slot - copy.result.start;
            },
            .jump, .branch, .return_value, .return_void => return null,
            else => {},
        }
    }
    return null;
}

fn slotHasLastUseAt(
    instructions: []const Machine.Instruction,
    slot: Machine.Slot,
    allowed: usize,
) bool {
    if (!instructionUsesSlot(instructions[allowed], slot)) return false;
    for (instructions[allowed + 1 ..]) |instruction| {
        if (instructionUsesSlot(instruction, slot)) return false;
    }
    return true;
}

fn instructionUsesSlot(instruction: Machine.Instruction, slot: Machine.Slot) bool {
    return switch (instruction) {
        .copy => |value| value.operand == slot,
        .copy_range => |value| spanContainsSlot(value.operand, slot),
        .aggregate_init => |value| for (value.fields) |field| {
            if (spanContainsSlot(field, slot)) break true;
        } else false,
        .unary => |value| value.operand == slot,
        .binary => |value| value.left == slot or value.right == slot,
        .convert => |value| value.operand == slot,
        .collection_load => |value| value.index == slot or spanContainsSlot(value.collection, slot),
        .collection_count => |value| spanContainsSlot(value.collection, slot),
        .return_value => |value| spanContainsSlot(value, slot),
        .branch => |value| value.condition == slot,
        else => false,
    };
}

fn floatLaneResidence(function: Machine.Function, slot: Machine.Slot) ?Machine.FloatLaneResidence {
    if (function.float_lane_slots.len == 0) return null;
    return function.float_lane_slots[slot];
}

fn spanContainsSlot(span: Machine.Span, slot: Machine.Slot) bool {
    return slot >= span.start and @as(usize, slot) < @as(usize, span.start) + span.width;
}

test "pair separated float32 divisions with a shared denominator" {
    const instructions = [_]Machine.Instruction{
        .{ .copy = .{ .result = 3, .operand = 2 } },
        .{ .binary = .{ .result = 4, .operator = .divide, .left = 0, .right = 3, .type = .float32 } },
        .{ .copy = .{ .result = 5, .operand = 4 } },
        .{ .copy = .{ .result = 6, .operand = 2 } },
        .{ .binary = .{ .result = 7, .operator = .divide, .left = 1, .right = 6, .type = .float32 } },
        .{ .return_value = .{ .start = 7, .width = 1 } },
    };
    const function = pairedFunction(&instructions);

    const leader = floatDivisionLeader(function, 1, instructions[1].binary) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 4), leader.follower);
    try std.testing.expectEqual(@as(u5, 16), leader.numerator);
    const follower = floatDivisionFollower(function, 4, instructions[4].binary) orelse
        return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 1), follower.leader);
}

test "do not pair divisions across a denominator mutation" {
    const instructions = [_]Machine.Instruction{
        .{ .copy = .{ .result = 3, .operand = 2 } },
        .{ .binary = .{ .result = 4, .operator = .divide, .left = 0, .right = 3, .type = .float32 } },
        .{ .copy = .{ .result = 2, .operand = 8 } },
        .{ .copy = .{ .result = 6, .operand = 2 } },
        .{ .binary = .{ .result = 7, .operator = .divide, .left = 1, .right = 6, .type = .float32 } },
        .{ .return_value = .{ .start = 7, .width = 1 } },
    };
    const function = pairedFunction(&instructions);

    try std.testing.expectEqual(
        @as(?FloatDivision, null),
        floatDivisionLeader(function, 1, instructions[1].binary),
    );
}

fn pairedFunction(instructions: []const Machine.Instruction) Machine.Function {
    const lanes = &[_]?Machine.FloatLaneResidence{
        .{ .register = 16, .lane = 0, .partner = 1 },
        .{ .register = 16, .lane = 1, .partner = 0 },
        null,
        null,
        null,
        null,
        null,
        null,
        null,
    };
    return .{
        .name = "paired_divisions",
        .parameter_count = 0,
        .return_type = .float32,
        .slot_count = lanes.len,
        .frame_size = Machine.frameSize(lanes.len) catch unreachable,
        .float_lane_slots = lanes,
        .instructions = instructions,
    };
}
