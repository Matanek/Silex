const std = @import("std");
const Machine = @import("Machine.zig");
const Source = @import("../Source.zig");
const ResidenceLiveness = @import("ResidenceLiveness.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");

const Pair = struct { first: Machine.Slot, second: Machine.Slot, order: usize };

// Make independent arithmetic trees adjacent before allocation. No memory
// access, call, potentially trapping arithmetic or control-flow entry may be
// crossed. This changes instruction order, never the expression tree itself.
pub fn optimize(allocator: std.mem.Allocator, function: Machine.Function) !Machine.Function {
    return optimizeWithExternals(allocator, function, &.{});
}

pub fn optimizeWithExternals(allocator: std.mem.Allocator, function: Machine.Function, externals: []const Machine.ExternalFunction) !Machine.Function {
    if (function.float_lane_groups.len == 0 or !RegisterAllocation.supportsMemoryScheduling(function, externals)) return function;
    const definitions = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(definitions);
    @memset(definitions, 0);
    for (function.parameters) |parameter| for (0..parameter.width) |leaf| {
        definitions[@as(usize, parameter.start) + leaf] += 1;
    };
    for (function.instructions) |instruction| for (0..function.slot_count) |slot| {
        if (ResidenceLiveness.instructionDefines(instruction, slot)) definitions[slot] += 1;
    };
    const reserved = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(reserved);
    @memset(reserved, false);
    var pairs: std.ArrayList(Pair) = .empty;
    defer pairs.deinit(allocator);
    for (function.float_lane_groups) |group| {
        if (group.recurrence or group.priority == 0) continue;
        var lane: usize = 0;
        while (lane + 1 < group.width) : (lane += 2) {
            const first = group.slots[lane];
            const second = group.slots[lane + 1];
            if (definitions[first] != 1 or definitions[second] != 1 or reserved[first] or reserved[second]) continue;
            const first_index = definitionIndex(function.instructions, first) orelse continue;
            const second_index = definitionIndex(function.instructions, second) orelse continue;
            if (first_index >= second_index) continue;
            const a = function.instructions[first_index];
            const b = function.instructions[second_index];
            if (a != .binary or b != .binary or !pure(a) or !pure(b) or a.binary.operator != b.binary.operator) continue;
            try pairs.append(allocator, .{ .first = first, .second = second, .order = first_index });
            reserved[first] = true;
            reserved[second] = true;
        }
    }
    if (pairs.items.len == 0) return function;
    std.mem.sort(Pair, pairs.items, {}, laterFirst);
    const entries = try allocator.alloc(bool, function.instructions.len);
    defer allocator.free(entries);
    @memset(entries, false);
    for (function.instructions) |instruction| switch (instruction) {
        .jump => |target| entries[target] = true,
        .branch => |branch| {
            entries[branch.then_instruction] = true;
            entries[branch.else_instruction] = true;
        },
        else => {},
    };
    const instructions = try allocator.dupe(Machine.Instruction, function.instructions);
    const positions = try allocator.dupe(?Source.Position, function.instruction_positions);
    for (pairs.items) |pair| {
        const first = definitionIndex(instructions, pair.first) orelse continue;
        const second = definitionIndex(instructions, pair.second) orelse continue;
        if (first + 1 >= second) continue;
        try placePair(allocator, instructions, positions, entries, definitions, first, second);
    }
    var result = function;
    result.instructions = instructions;
    result.instruction_positions = positions;
    return result;
}

fn laterFirst(_: void, first: Pair, second: Pair) bool {
    return first.order > second.order;
}

fn definitionIndex(instructions: []const Machine.Instruction, slot: Machine.Slot) ?usize {
    for (instructions, 0..) |instruction, index| if (ResidenceLiveness.instructionDefines(instruction, slot)) return index;
    return null;
}

fn pure(instruction: Machine.Instruction) bool {
    return switch (instruction) {
        .constant_int, .constant_bool, .constant_float32, .constant_float64, .copy, .copy_range, .aggregate_init => true,
        .binary => |binary| binary.type == .float32 and switch (binary.operator) {
            .add, .subtract, .multiply => true,
            else => false,
        },
        else => false,
    };
}

fn resultSpan(instruction: Machine.Instruction) Machine.Span {
    return switch (instruction) {
        .constant_int => |value| .{ .start = value.result, .width = 1 },
        .constant_bool => |value| .{ .start = value.result, .width = 1 },
        .constant_float32 => |value| .{ .start = value.result, .width = 1 },
        .constant_float64 => |value| .{ .start = value.result, .width = 1 },
        .copy => |value| .{ .start = value.result, .width = 1 },
        .copy_range => |value| value.result,
        .aggregate_init => |value| value.result,
        .binary => |value| .{ .start = value.result, .width = 1 },
        else => unreachable,
    };
}

fn markSpan(span: Machine.Span, slots: []bool, value: bool) void {
    @memset(slots[span.start .. @as(usize, span.start) + span.width], value);
}

fn markOperands(instruction: Machine.Instruction, slots: []bool) void {
    switch (instruction) {
        .copy => |value| slots[value.operand] = true,
        .copy_range => |value| markSpan(value.operand, slots, true),
        .aggregate_init => |value| for (value.fields) |field| markSpan(field, slots, true),
        .binary => |value| {
            slots[value.left] = true;
            slots[value.right] = true;
        },
        else => {},
    }
}

fn placePair(
    allocator: std.mem.Allocator,
    instructions: []Machine.Instruction,
    positions: []?Source.Position,
    entries: []const bool,
    definitions: []const usize,
    first: usize,
    second: usize,
) !void {
    for (first + 1..second + 1) |index| if (entries[index] or !pure(instructions[index])) return;
    const needed = try allocator.alloc(bool, definitions.len);
    defer allocator.free(needed);
    @memset(needed, false);
    markOperands(instructions[second], needed);
    const moved = try allocator.alloc(bool, second - first + 1);
    defer allocator.free(moved);
    @memset(moved, false);
    var index = second;
    while (index > first + 1) {
        index -= 1;
        const span = resultSpan(instructions[index]);
        var required = false;
        for (0..span.width) |leaf| required = required or needed[@as(usize, span.start) + leaf];
        if (!required) continue;
        for (0..span.width) |leaf| if (definitions[@as(usize, span.start) + leaf] != 1) return;
        moved[index - first] = true;
        markSpan(span, needed, false);
        markOperands(instructions[index], needed);
    }
    const leader = resultSpan(instructions[first]);
    for (0..leader.width) |leaf| if (needed[@as(usize, leader.start) + leaf]) return;
    var order: std.ArrayList(usize) = .empty;
    defer order.deinit(allocator);
    for (first + 1..second) |at| if (moved[at - first]) try order.append(allocator, at);
    try order.appendSlice(allocator, &.{ first, second });
    for (first + 1..second) |at| if (!moved[at - first]) try order.append(allocator, at);
    const original = try allocator.dupe(Machine.Instruction, instructions[first .. second + 1]);
    defer allocator.free(original);
    const original_positions = if (positions.len == 0) &.{} else try allocator.dupe(?Source.Position, positions[first .. second + 1]);
    defer if (positions.len != 0) allocator.free(original_positions);
    for (order.items, first..) |source, target| {
        instructions[target] = original[source - first];
        if (positions.len != 0) positions[target] = original_positions[source - first];
    }
}

fn fixture(instructions: []const Machine.Instruction) Machine.Function {
    return .{
        .name = "checked_pair_schedule",
        .parameter_count = 4,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 } },
        .return_type = .void,
        .slot_count = 11,
        .frame_size = 96,
        .float_lane_groups = &.{
            .{ .slots = .{ 5, 8, 0, 0 }, .width = 2, .priority = 1, .recurrence = false, .in_loop = false },
            .{ .slots = .{ 6, 9, 0, 0 }, .width = 2, .priority = 1, .recurrence = false, .in_loop = false },
        },
        .instructions = instructions,
    };
}

const fixture_instructions = [_]Machine.Instruction{
    .{ .copy = .{ .result = 4, .operand = 0 } },
    .{ .binary = .{ .result = 5, .left = 4, .right = 2, .operator = .multiply, .type = .float32 } },
    .{ .binary = .{ .result = 6, .left = 5, .right = 2, .operator = .add, .type = .float32 } },
    .{ .copy = .{ .result = 7, .operand = 1 } },
    .{ .binary = .{ .result = 8, .left = 7, .right = 2, .operator = .multiply, .type = .float32 } },
    .{ .binary = .{ .result = 9, .left = 8, .right = 2, .operator = .add, .type = .float32 } },
    .{ .reference_store = .{ .reference = 3, .operand = .{ .start = 6, .width = 1 } } },
    .{ .reference_offset = .{ .reference = 3, .result = 10, .byte_offset = 8 } },
    .{ .reference_store = .{ .reference = 10, .operand = .{ .start = 9, .width = 1 } } },
    .return_void,
};

test "memory arithmetic schedule preserves independent trees before scalar stores" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var original = fixture(&fixture_instructions);
    var positions: [fixture_instructions.len]?Source.Position = undefined;
    for (&positions, 0..) |*position, index| position.* = .{ .line = index + 1, .column = 1, .offset = index };
    original.instruction_positions = &positions;
    const unscheduled = try RegisterAllocation.allocate(allocator, original);
    try std.testing.expect(unscheduled.float_lane_residences[5] == null);
    var scheduled = try optimize(allocator, original);
    try std.testing.expectEqual(@as(Machine.Slot, 7), scheduled.instructions[1].copy.result);
    try std.testing.expectEqual(@as(usize, 4), scheduled.instruction_positions[1].?.line);
    try std.testing.expectEqual(@as(Machine.Slot, 5), scheduled.instructions[2].binary.result);
    try std.testing.expectEqual(@as(Machine.Slot, 8), scheduled.instructions[3].binary.result);
    try std.testing.expectEqual(@as(Machine.Slot, 6), scheduled.instructions[4].binary.result);
    try std.testing.expectEqual(@as(Machine.Slot, 9), scheduled.instructions[5].binary.result);
    try std.testing.expectEqual(@as(Machine.Slot, 6), original.instructions[2].binary.result);
    const allocation = try RegisterAllocation.allocate(allocator, scheduled);
    scheduled.register_slots = allocation.residences;
    scheduled.float_register_slots = allocation.float_residences;
    scheduled.float_lane_slots = allocation.float_lane_residences;
    try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), scheduled.float_lane_slots[5]);
    try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), scheduled.float_lane_slots[8]);
    try std.testing.expect(scheduled.float_register_slots[5] != null);
    try std.testing.expect(scheduled.float_register_slots[8] != null);
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const Runner = @import("Runner.zig");
    var values = [_]u64{ 0, 0 };
    const result = try Runner.invoke(allocator, .{ .functions = &.{scheduled} }, 0, &.{
        @as(u32, @bitCast(@as(f32, 3))), @as(u32, @bitCast(@as(f32, -4))),
        @as(u32, @bitCast(@as(f32, 2))), @intCast(@intFromPtr(&values)),
    });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 8))), @as(u32, @truncate(values[0])));
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, -6))), @as(u32, @truncate(values[1])));
}

test "memory arithmetic schedule never crosses stores entries or reused operands" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    for (0..6) |variant| {
        var instructions = fixture_instructions;
        var function = fixture(&instructions);
        function.float_lane_groups = function.float_lane_groups[0..1];
        switch (variant) {
            0 => {
                instructions[2] = .{ .reference_store = .{ .reference = 3, .operand = .{ .start = 5, .width = 1 } } };
                instructions[6].reference_store.operand.start = 5;
            },
            1 => instructions[9] = .{ .jump = 4 },
            2 => {
                instructions[2] = .{ .copy = .{ .result = 0, .operand = 1 } };
                instructions[3].copy.operand = 0;
                instructions[6].reference_store.operand.start = 5;
            },
            3 => instructions[3].copy.operand = 5,
            4 => instructions[2].binary.operator = .divide,
            5 => function.reuses_slots = true,
            else => unreachable,
        }
        const result = try optimize(arena.allocator(), function);
        try std.testing.expectEqualDeep(instructions[0..], result.instructions);
    }
}

test "memory arithmetic schedule uses proven external metadata without moving calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const externals = [_]Machine.ExternalFunction{.{
        .provider = "Darwin.lib_system",
        .source_name = "copysignf",
        .signature = .{ .arguments = &.{ .float32, .float32 }, .result = .float32 },
    }};
    var instructions = fixture_instructions;
    instructions[9] = .{ .external_call = .{ .function = 0, .arguments = &.{ 0, 1 }, .result = 11 } };
    var function = fixture(&instructions);
    function.slot_count = 12;
    const unproven = try optimize(allocator, function);
    try std.testing.expectEqualDeep(instructions[0..], unproven.instructions);
    const scheduled = try optimizeWithExternals(allocator, function, &externals);
    try std.testing.expectEqual(@as(Machine.Slot, 5), scheduled.instructions[2].binary.result);
    try std.testing.expectEqual(@as(Machine.Slot, 8), scheduled.instructions[3].binary.result);
    try std.testing.expectEqualDeep(instructions[9], scheduled.instructions[9]);
    instructions[2] = instructions[9];
    const blocked = try optimizeWithExternals(allocator, function, &externals);
    try std.testing.expectEqualDeep(instructions[0..], blocked.instructions);
}
