const std = @import("std");
const Machine = @import("Machine.zig");
const Liveness = @import("ResidenceLiveness.zig");
const Conflicts = @import("ResidenceConflicts.zig");

// Former pair scan, independent of the compact representation.
fn scalar(instructions: []const Machine.Instruction, live: []const bool, slots: usize, left: usize, right: usize) bool {
    for (instructions, 0..) |instruction, index| {
        if (instruction == .class_load) {
            const result = instruction.class_load.result;
            if (Liveness.spanContains(result, left) and Liveness.spanContains(result, right)) return true;
        }
        if (!live[index * slots + left] and !live[index * slots + right]) continue;
        if (Conflicts.instructionCanShareResidence(instructions, live, slots, index, left, right)) continue;
        if (live[index * slots + left] and live[index * slots + right]) return true;
        if (Liveness.instructionDefines(instruction, left) and live[index * slots + right]) return true;
        if (Liveness.instructionDefines(instruction, right) and live[index * slots + left]) return true;
    }
    return false;
}

fn compare(instructions: []const Machine.Instruction, live: []const bool, slots: usize) !void {
    const facts = try Conflicts.Facts.init(std.testing.allocator, instructions, live, slots);
    defer facts.deinit(std.testing.allocator);
    for (0..slots) |left| for (0..slots) |right| {
        try std.testing.expectEqual(scalar(instructions, live, slots, left, right), facts.interferes(left, right, instructions, live));
    };
}

test "compact conflicts preserve simultaneous dead class definitions" {
    const instructions = [_]Machine.Instruction{
        .{ .class_load = .{ .result = .{ .start = 1, .width = 3 }, .base = 0, .byte_offset = 0 } },
        .return_void,
    };
    const live = [_]bool{false} ** 8;
    const facts = try Conflicts.Facts.init(std.testing.allocator, &instructions, &live, 4);
    defer facts.deinit(std.testing.allocator);
    try std.testing.expect(facts.interferes(1, 3, &instructions, &live));
    try std.testing.expect(!facts.interferes(0, 3, &instructions, &live));
    try compare(&instructions, &live, 4);
}

test "compact conflicts retain destructive copy and loop successor rules" {
    const instructions = [_]Machine.Instruction{
        .{ .copy = .{ .result = 1, .operand = 0 } },
        .{ .branch = .{ .condition = 2, .then_instruction = 0, .else_instruction = 2 } },
        .{ .return_value = .{ .start = 1, .width = 1 } },
    };
    const live = try Liveness.compute(std.testing.allocator, &instructions, 3);
    defer std.testing.allocator.free(live);
    try compare(&instructions, live, 3);
    // Incoming captures and delayed operands are adjustments to the solved rows.
    live[0] = true;
    live[1] = true;
    live[2] = true;
    live[7] = true;
    try compare(&instructions, live, 3);
}

test "compact conflicts match scalar rows across instruction word boundaries" {
    var prng = std.Random.DefaultPrng.init(0xc01d_2026);
    const random = prng.random();
    for ([_]usize{ 0, 1, 63, 64, 65, 127, 128, 129 }) |count| {
        for ([_]usize{ 1, 3, 65 }) |slots| {
            const instructions = try std.testing.allocator.alloc(Machine.Instruction, count);
            defer std.testing.allocator.free(instructions);
            const live = try std.testing.allocator.alloc(bool, count * slots);
            defer std.testing.allocator.free(live);
            for (instructions) |*instruction| {
                const result: Machine.Slot = @intCast(random.uintLessThan(usize, slots));
                const operand: Machine.Slot = @intCast(random.uintLessThan(usize, slots));
                instruction.* = switch (random.uintLessThan(u8, 6)) {
                    0 => .{ .constant_int = .{ .result = result, .bits = 17 } },
                    1 => .{ .copy = .{ .result = result, .operand = operand } },
                    2 => .{ .class_load = .{ .result = .{ .start = result, .width = @intCast(@min(3, slots - result)) }, .base = operand, .byte_offset = 0 } },
                    3 => .{ .copy_range = .{ .result = .{ .start = result, .width = 1 }, .operand = .{ .start = operand, .width = 1 } } },
                    4 => .{ .jump = random.uintLessThan(usize, count) },
                    else => .return_void,
                };
            }
            for (0..4) |layout| {
                for (live) |*value| value.* = switch (layout) {
                    0 => false,
                    1 => true,
                    2 => random.uintLessThan(u8, 16) == 0,
                    else => random.boolean(),
                };
                try compare(instructions, live, slots);
            }
        }
    }
    try compare(&.{}, &.{}, 0);
}
