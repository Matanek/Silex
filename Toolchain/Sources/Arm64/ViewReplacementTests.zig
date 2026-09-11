const std = @import("std");
const Machine = @import("Machine.zig");

test "view replacement preserves live volatile values across paired and odd leaf copies" {
    const builtin = @import("builtin");
    const Runner = @import("Runner.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]u12{ 1, 2, 3 }) |width| {
        const function: Machine.Function = .{
            .name = "view_copy_preserves_volatile",
            .parameter_count = 7,
            .parameters = &.{
                .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 },
                .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 },
                .{ .start = 4, .width = 1 }, .{ .start = 5, .width = 1 },
                .{ .start = 6, .width = 1 },
            },
            .return_type = .int,
            .return_width = 1,
            .slot_count = 11,
            .frame_size = try Machine.frameSize(11),
            .register_slots = &.{ null, null, null, null, null, 5, 6, null, null, null, null },
            .instructions = &.{
                .{ .constant_int = .{ .result = 7, .bits = 0 } },
                .{ .collection_replace = .{
                    .result = .{ .start = 8, .width = 2, .aggregate = true },
                    .collection = .{ .start = 0, .width = 2, .aggregate = true },
                    .index = 7,
                    .replacement = .{ .start = 2, .width = width, .aggregate = true },
                    .count = 0,
                    .dynamic = true,
                    .view = true,
                    .checked = false,
                    .header = 0,
                    .tail = 0,
                } },
                .{ .binary = .{ .result = 10, .left = 5, .right = 6, .operator = .add, .type = .int } },
                .{ .return_value = .{ .start = 10, .width = 1 } },
            },
        };
        const program: Machine.Program = .{ .functions = &.{function}, .strings = &.{""} };
        const Encoder = @import("Encoder.zig");
        inline for (.{ Encoder.encode, Encoder.encodeLinux, Encoder.encodeWindows }) |encode| {
            const image = try encode(allocator, program, .{ .test_function = 0 });
            image.deinit(allocator);
        }
        if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) continue;
        var values = [_]i64{ 0, 0, 0 };
        const result = try Runner.invoke(allocator, program, 0, &.{
            @intCast(@intFromPtr(&values)), 1, 13, 19, 23, 7, 11,
        });
        try std.testing.expectEqual(Machine.Status.success, result.status);
        try std.testing.expectEqual(@as(i64, 18), result.value);
        const expected = [_]i64{ 13, 19, 23 };
        try std.testing.expectEqualSlices(i64, expected[0..width], values[0..width]);
        for (values[width..]) |value| try std.testing.expectEqual(@as(i64, 0), value);
    }
}
