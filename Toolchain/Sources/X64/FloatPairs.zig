const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");

const Allocator = std.mem.Allocator;

/// Emits one selected portable `float32` pair with baseline SSE. Returning
/// true means the scalar instruction is represented by the pair: leaders wait
/// for their follower, and followers materialize both results together.
pub fn emit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    function: Machine.Function,
    binary: Machine.Instruction.Binary,
) (Allocator.Error || Machine.Error)!bool {
    const residence = laneResidence(function, binary.result) orelse return false;
    if (residence.lane == 0) return true;
    const first = definingBinary(function.instructions, residence.partner) orelse return error.InvalidMachineProgram;
    try emitPair(allocator, bytes, function, first, binary);
    return true;
}

pub fn validate(function: Machine.Function) Machine.Error!void {
    for (function.float_lane_slots) |residence| if (residence) |lane| {
        if (lane.register > 2 or lane.partner >= function.slot_count) return error.InvalidMachineProgram;
    };
}

fn emitPair(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    function: Machine.Function,
    first: Machine.Instruction.Binary,
    second: Machine.Instruction.Binary,
) (Allocator.Error || Machine.Error)!void {
    if (first.type != .float32 or second.type != .float32 or first.operator != second.operator or
        switch (first.operator) {
            .add, .subtract, .multiply, .divide => false,
            else => true,
        }) return error.InvalidMachineProgram;
    const first_residence = laneResidence(function, first.result) orelse return error.InvalidMachineProgram;
    const second_residence = laneResidence(function, second.result) orelse return error.InvalidMachineProgram;
    if (first_residence.register != second_residence.register or first_residence.lane != 0 or
        second_residence.lane != 1 or first_residence.partner != second.result or
        second_residence.partner != first.result) return error.InvalidMachineProgram;

    const destination: u3 = @intCast(first_residence.register);
    try preparePair(allocator, bytes, function, 3, 5, first.left, second.left);
    try preparePair(allocator, bytes, function, 4, 5, first.right, second.right);
    try movePacked(allocator, bytes, destination, 3);
    try bytes.appendSlice(allocator, &.{ 0x0f, switch (first.operator) {
        .add => 0x58,
        .subtract => 0x5c,
        .multiply => 0x59,
        .divide => 0x5e,
        else => unreachable,
    }, 0xc0 | (@as(u8, destination) << 3) | 4 });
    try storePair(allocator, bytes, destination, first.result, second.result);
}

fn preparePair(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    function: Machine.Function,
    destination: u3,
    temporary: u3,
    first: Machine.Slot,
    second: Machine.Slot,
) Allocator.Error!void {
    if (residentRegister(function, first, second)) |source| {
        try movePacked(allocator, bytes, destination, source);
        return;
    }
    try loadStack(allocator, bytes, destination, first);
    if (first == second) {
        try unpackLow(allocator, bytes, destination, destination);
        return;
    }
    try loadStack(allocator, bytes, temporary, second);
    try unpackLow(allocator, bytes, destination, temporary);
}

fn storePair(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    source: u3,
    first: Machine.Slot,
    second: Machine.Slot,
) Allocator.Error!void {
    try storeStack(allocator, bytes, source, first);
    try movePacked(allocator, bytes, 5, source);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0xc6, 0xc0 | (5 << 3) | 5, 0x55 });
    try storeStack(allocator, bytes, 5, second);
}

fn residentRegister(function: Machine.Function, first: Machine.Slot, second: Machine.Slot) ?u3 {
    if (first == second) return null;
    const left = laneResidence(function, first) orelse return null;
    const right = laneResidence(function, second) orelse return null;
    if (left.register != right.register or left.lane != 0 or right.lane != 1 or
        left.partner != second or right.partner != first or left.register > 2) return null;
    _ = definingBinary(function.instructions, first) orelse return null;
    _ = definingBinary(function.instructions, second) orelse return null;
    return @intCast(left.register);
}

fn definingBinary(instructions: []const Machine.Instruction, slot: Machine.Slot) ?Machine.Instruction.Binary {
    var result: ?Machine.Instruction.Binary = null;
    for (instructions) |instruction| switch (instruction) {
        .binary => |binary| if (binary.result == slot and binary.type == .float32 and switch (binary.operator) {
            .add, .subtract, .multiply, .divide => true,
            else => false,
        }) {
            if (result != null) return null;
            result = binary;
        },
        else => {},
    };
    return result;
}

fn laneResidence(function: Machine.Function, slot: Machine.Slot) ?Machine.FloatLaneResidence {
    if (function.float_lane_slots.len == 0) return null;
    return function.float_lane_slots[slot];
}

fn loadStack(allocator: Allocator, bytes: *std.ArrayList(u8), xmm: u3, slot: Machine.Slot) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0xf3, 0x0f, 0x10, 0x85 | (@as(u8, xmm) << 3) });
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn storeStack(allocator: Allocator, bytes: *std.ArrayList(u8), xmm: u3, slot: Machine.Slot) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0xf3, 0x0f, 0x11, 0x85 | (@as(u8, xmm) << 3) });
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn movePacked(allocator: Allocator, bytes: *std.ArrayList(u8), destination: u3, source: u3) Allocator.Error!void {
    if (destination == source) return;
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x28, 0xc0 | (@as(u8, destination) << 3) | source });
}

fn unpackLow(allocator: Allocator, bytes: *std.ArrayList(u8), destination: u3, source: u3) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x14, 0xc0 | (@as(u8, destination) << 3) | source });
}

fn slotDisplacement(slot: Machine.Slot) i32 {
    return @as(i32, slot) * Machine.slot_size;
}

fn appendInt(allocator: Allocator, bytes: *std.ArrayList(u8), comptime T: type, value: T) Allocator.Error!void {
    try bytes.appendSlice(allocator, std.mem.asBytes(&value));
}

test "emit a selected portable float32 pair with packed SSE" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const instructions = [_]Machine.Instruction{
        .{ .binary = .{ .result = 4, .operator = .multiply, .left = 0, .right = 2, .type = .float32 } },
        .{ .binary = .{ .result = 5, .operator = .multiply, .left = 1, .right = 3, .type = .float32 } },
    };
    const lanes = [_]?Machine.FloatLaneResidence{
        null,
        null,
        null,
        null,
        .{ .register = 0, .lane = 0, .partner = 5 },
        .{ .register = 0, .lane = 1, .partner = 4 },
    };
    const function: Machine.Function = .{
        .name = "pair",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 6,
        .frame_size = 48,
        .float_lane_slots = &lanes,
        .instructions = &instructions,
    };
    var bytes: std.ArrayList(u8) = .empty;
    try std.testing.expect(try emit(allocator, &bytes, function, instructions[0].binary));
    try std.testing.expectEqual(@as(usize, 0), bytes.items.len);
    try std.testing.expect(try emit(allocator, &bytes, function, instructions[1].binary));
    try std.testing.expect(std.mem.containsAtLeast(u8, bytes.items, 1, &[_]u8{ 0x0f, 0x59 }));
}
