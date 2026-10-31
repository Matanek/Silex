const std = @import("std");
const Machine = @import("Machine.zig");
const Encoder = @import("Encoder.zig");
const builtin = @import("builtin");
const Runner = @import("Runner.zig");
test "deferred collection tail reaches both branches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const f: Machine.Function = .{ .name = "branched_snapshot", .parameter_count = 2, .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } }, .return_type = .float32, .return_width = 1, .slot_count = 11, .frame_size = try Machine.frameSize(11), .register_slots = &([_]?u5{null} ** 11), .float_register_slots = &.{ null, null, null, 16, 17, 18, 19, null, 20, 21, 22 }, .instructions = &.{
        .{ .constant_float32 = .{ .result = 4, .bits = @bitCast(@as(f32, -100)) } },
        .{ .constant_float32 = .{ .result = 5, .bits = @bitCast(@as(f32, -200)) } },
        .{ .constant_int = .{ .result = 2, .bits = 0 } },
        .{ .collection_load = .{ .result = .{ .start = 3, .width = 3, .aggregate = true }, .collection = .{ .start = 0, .width = 2, .aggregate = true }, .index = 2, .count = 0, .dynamic = true, .view = true, .checked = false, .element_stride = 12, .header = 0, .tail = 1 } },
        .{ .constant_float32 = .{ .result = 6, .bits = 0 } },
        .{ .binary = .{ .result = 7, .left = 3, .right = 6, .operator = .greater, .type = .float32 } },
        .{ .branch = .{ .condition = 7, .then_instruction = 7, .else_instruction = 10 } },
        .{ .binary = .{ .result = 8, .left = 4, .right = 4, .operator = .add, .type = .float32 } },
        .{ .binary = .{ .result = 9, .left = 8, .right = 5, .operator = .add, .type = .float32 } },
        .{ .return_value = .{ .start = 9, .width = 1 } },
        .{ .binary = .{ .result = 10, .left = 4, .right = 5, .operator = .subtract, .type = .float32 } },
        .{ .return_value = .{ .start = 10, .width = 1 } },
    } };
    const program: Machine.Program = .{ .functions = &.{f}, .strings = &.{ "invalid index", " count " } };
    for ([_]Encoder.Platform{ .darwin, .linux, .windows }) |platform| {
        _ = try switch (platform) {
            .darwin => Encoder.encode(a, program, .none),
            .linux => Encoder.encodeLinux(a, program, .none),
            .windows => Encoder.encodeWindows(a, program, .none),
        };
    }
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    for ([_]f32{ -3.88, 3.88 }) |x| {
        var values = [_]f32{ x, 2.4, -0.88 };
        const result = try Runner.invoke(a, program, 0, &.{ @intCast(@intFromPtr(&values)), 1 });
        try std.testing.expectEqual(Machine.Status.success, result.status);
        const expected: f32 = if (x > 0) values[1] + values[1] + values[2] else values[1] - values[2];
        try std.testing.expectEqual(@as(i64, @as(u32, @bitCast(expected))), result.value);
    }
}
