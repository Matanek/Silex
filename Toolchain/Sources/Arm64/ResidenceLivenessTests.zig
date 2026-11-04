const std = @import("std");
const Machine = @import("Machine.zig");
const Liveness = @import("ResidenceLiveness.zig");

// The former scalar solver is kept as a differential oracle. It uses the same
// instruction contract, but neither word packing nor transfer precomputation.
fn scalar(allocator: std.mem.Allocator, instructions: []const Machine.Instruction, slots: usize) ![]bool {
    const live = try allocator.alloc(bool, instructions.len * slots);
    @memset(live, false);
    var changed = true;
    while (changed) {
        changed = false;
        var reverse = instructions.len;
        while (reverse != 0) {
            reverse -= 1;
            for (0..slots) |slot| {
                const out = Liveness.successorLive(instructions, live, slots, reverse, slot);
                const value = Liveness.instructionUses(instructions[reverse], slot) or
                    (out and !Liveness.instructionDefines(instructions[reverse], slot));
                const at = reverse * slots + slot;
                if (live[at] != value) {
                    live[at] = value;
                    changed = true;
                }
            }
        }
    }
    return live;
}

fn compare(instructions: []const Machine.Instruction, slots: usize) !void {
    const expected = try scalar(std.testing.allocator, instructions, slots);
    defer std.testing.allocator.free(expected);
    const actual = try Liveness.compute(std.testing.allocator, instructions, slots);
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualSlices(bool, expected, actual);
}

test "residence liveness preserves known branch and unreachable rows" {
    const branch = [_]Machine.Instruction{
        .{ .branch = .{ .condition = 0, .then_instruction = 1, .else_instruction = 3 } },
        .{ .copy = .{ .result = 1, .operand = 2 } },
        .{ .jump = 4 },
        .{ .copy = .{ .result = 1, .operand = 3 } },
        .{ .return_value = .{ .start = 1, .width = 1 } },
    };
    const live = try Liveness.compute(std.testing.allocator, &branch, 4);
    defer std.testing.allocator.free(live);
    try std.testing.expectEqualSlices(bool, &.{
        true,  false, true,  true,
        false, false, true,  false,
        false, true,  false, false,
        false, false, false, true,
        false, true,  false, false,
    }, live);
    const disconnected = [_]Machine.Instruction{
        .{ .copy = .{ .result = 1, .operand = 0 } },
        .{ .return_value = .{ .start = 1, .width = 1 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const rows = try Liveness.compute(std.testing.allocator, &disconnected, 3);
    defer std.testing.allocator.free(rows);
    try std.testing.expectEqualSlices(bool, &.{ true, false, false, false, true, false, false, false, true }, rows);
}

test "residence liveness preserves loop uses across redefinitions" {
    const instructions = [_]Machine.Instruction{
        .{ .copy = .{ .result = 0, .operand = 1 } },
        .{ .branch = .{ .condition = 2, .then_instruction = 0, .else_instruction = 2 } },
        .{ .return_value = .{ .start = 0, .width = 1 } },
    };
    const live = try Liveness.compute(std.testing.allocator, &instructions, 3);
    defer std.testing.allocator.free(live);
    try std.testing.expectEqualSlices(bool, &.{ false, true, true, true, true, true, true, false, false }, live);
    try compare(&instructions, 3);
}

test "residence liveness matches scalar CFGs across word boundaries" {
    var prng = std.Random.DefaultPrng.init(0x5a17_2026);
    const random = prng.random();
    for ([_]usize{ 1, 31, 63, 64, 65, 127, 128, 129 }) |slots| {
        for (0..24) |_| {
            var instructions: [67]Machine.Instruction = undefined;
            for (&instructions) |*instruction| {
                const result: Machine.Slot = @intCast(random.uintLessThan(usize, slots));
                const operand: Machine.Slot = @intCast(random.uintLessThan(usize, slots));
                instruction.* = switch (random.uintLessThan(u8, 7)) {
                    0 => .{ .constant_int = .{ .result = result, .bits = 17 } },
                    1 => .{ .copy = .{ .result = result, .operand = operand } },
                    2 => .{ .branch = .{ .condition = operand, .then_instruction = random.uintLessThan(usize, instructions.len), .else_instruction = random.uintLessThan(usize, instructions.len) } },
                    3 => .{ .jump = random.uintLessThan(usize, instructions.len) },
                    4 => .{ .return_value = .{ .start = operand, .width = 1 } },
                    5 => .{ .copy_range = .{
                        .result = .{ .start = result, .width = @intCast(@min(3, @min(slots - result, slots - operand))) },
                        .operand = .{ .start = operand, .width = @intCast(@min(3, @min(slots - result, slots - operand))) },
                    } },
                    else => .return_void,
                };
            }
            try compare(&instructions, slots);
        }
    }
    try compare(&.{}, 0);
    try compare(&.{}, 65);
    try compare(&.{.return_void}, 0);
}

test "residence liveness keeps temporary tables outside the result arena" {
    var storage: [129 * 67]u8 = undefined;
    var output = std.heap.FixedBufferAllocator.init(&storage);
    var instructions: [67]Machine.Instruction = @splat(.return_void);
    instructions[0] = .{ .branch = .{ .condition = 128, .then_instruction = 0, .else_instruction = 66 } };
    const live = try Liveness.compute(output.allocator(), &instructions, 129);
    try std.testing.expectEqual(storage.len, output.end_index);
    try std.testing.expect(live[128]);
    for (live[129..]) |value| try std.testing.expect(!value);
}
