const std = @import("std");
const Machine = @import("Machine.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");

test "aggregate copy dead integer leaves do not overwrite a live sibling" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function: Machine.Function = .{
        .name = "snapshot_projection",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .int,
        .return_width = 1,
        .slot_count = 10,
        .frame_size = 80,
        .instructions = &.{
            .{ .reference_load = .{ .reference = 0, .result = .{ .start = 2, .width = 4, .aggregate = true } } },
            .{ .copy_range = .{ .result = .{ .start = 6, .width = 4, .aggregate = true }, .operand = .{ .start = 2, .width = 4, .aggregate = true } } },
            .{ .branch = .{ .condition = 1, .then_instruction = 3, .else_instruction = 4 } },
            .{ .return_value = .{ .start = 6, .width = 1 } },
            .{ .return_value = .{ .start = 7, .width = 1 } },
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    try std.testing.expect(function.register_slots[6] != null);
    const Runner = @import("Runner.zig");
    var values = [_]u64{ 3, 5, 7, 11 };
    for ([_]bool{ true, false }) |first| {
        const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{ @intCast(@intFromPtr(&values)), @intFromBool(first) });
        try std.testing.expectEqual(Machine.Status.success, result.status);
        try std.testing.expectEqual(@as(i64, if (first) 3 else 5), result.value);
    }
}
