const std = @import("std");
const builtin = @import("builtin");
const Types = @import("../Types.zig");
const Machine = @import("Machine.zig");
const Allocation = @import("RegisterAllocation.zig");
const Runner = @import("Runner.zig");

fn witness(allocator: std.mem.Allocator, precision: Types.Type, length: usize, split: bool) !Machine.Function {
    var instructions: std.ArrayList(Machine.Instruction) = .empty;
    try instructions.append(allocator, .{ .class_load = .{ .base = 0, .result = .{ .start = 1, .width = 1 }, .byte_offset = 0 } });
    try instructions.append(allocator, if (precision == .float32)
        .{ .constant_float32 = .{ .result = 2, .bits = @bitCast(@as(f32, 1)) } }
    else
        .{ .constant_float64 = .{ .result = 2, .bits = @bitCast(@as(f64, 1)) } });
    for (0..length) |index| {
        if (split and index == length / 2) {
            try instructions.append(allocator, .{ .class_load = .{ .base = 0, .result = .{ .start = @intCast(length + 5), .width = 1 }, .byte_offset = 0 } });
        }
        try instructions.append(allocator, .{ .binary = .{
            .result = @intCast(index + 3),
            .operator = .add,
            .left = if (index == 0) 1 else @intCast(index + 2),
            .right = 2,
            .type = precision,
        } });
    }
    const last: Machine.Slot = @intCast(length + 2);
    try instructions.append(allocator, .{ .class_load = .{ .base = 0, .result = .{ .start = last + 1, .width = 1 }, .byte_offset = 0 } });
    try instructions.append(allocator, .{ .binary = .{ .result = last + 2, .operator = .add, .left = last, .right = last + 1, .type = precision } });
    try instructions.append(allocator, .{ .return_value = .{ .start = last + 2, .width = 1 } });
    return .{
        .name = "scalar_region_with_class_barriers",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = precision,
        .return_width = 1,
        .slot_count = @intCast(length + 6),
        .frame_size = try Machine.frameSize(@intCast(length + 6)),
        .instructions = try instructions.toOwnedSlice(allocator),
    };
}

test "scalar regions need no wide input and preserve class barrier homes" {
    inline for (.{ Types.Type.float32, Types.Type.float64 }) |precision| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var function = try witness(allocator, precision, 32, false);
        const allocation = try Allocation.allocate(allocator, function);
        try std.testing.expectEqual(@as(usize, function.slot_count), allocation.float_residences.len);
        try std.testing.expect(allocation.float_residences[3] != null);
        for ([_]usize{ 0, 1, 34, 35 }) |slot| {
            try std.testing.expectEqual(@as(?u5, null), allocation.residences[slot]);
            try std.testing.expectEqual(@as(?u5, null), allocation.float_residences[slot]);
            try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), allocation.float_lane_residences[slot]);
        }
        function.register_slots = allocation.residences;
        function.float_register_slots = allocation.float_residences;
        function.float_lane_slots = allocation.float_lane_residences;
        function.frame_size = allocation.frame_size;
        if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
            const Float = if (precision == .float32) f32 else f64;
            const Bits = if (precision == .float32) u32 else u64;
            for ([_]Float{ 1.25, -4, 0 }) |input| {
                var object = [_]u64{ 0, 0, 0, 0, @as(Bits, @bitCast(input)) };
                const actual = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{@intCast(@intFromPtr(&object))});
                try std.testing.expectEqual(Machine.Status.success, actual.status);
                try std.testing.expectEqual(@as(Bits, @bitCast(input * 2 + 32)), @as(Bits, @truncate(@as(u64, @bitCast(actual.value)))));
            }
        }
    }
}

test "scalar regions retain the profitability threshold and never count through barriers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]bool{ false, true }) |split| {
        const function = try witness(allocator, .float32, if (split) 32 else 31, split);
        const allocation = try Allocation.allocate(allocator, function);
        try std.testing.expectEqual(@as(usize, 0), allocation.float_residences.len);
    }
}
