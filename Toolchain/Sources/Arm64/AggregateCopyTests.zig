const std = @import("std");
const Machine = @import("Machine.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");

test "pure aggregate construction and copies retain arithmetic residences" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]bool{ false, true }) |floating| {
        var function: Machine.Function = .{
            .name = "pure_aggregate",
            .parameter_count = 3,
            .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 } },
            .return_type = if (floating) .float32 else .int,
            .return_width = 1,
            .slot_count = 10,
            .frame_size = 80,
            .instructions = &.{
                .{ .aggregate_init = .{ .result = .{ .start = 3, .width = 3, .aggregate = true }, .fields = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 0, .width = 1 } } } },
                .{ .copy_range = .{ .result = .{ .start = 6, .width = 3, .aggregate = true }, .operand = .{ .start = 3, .width = 3, .aggregate = true } } },
                .{ .binary = .{ .result = 9, .operator = .add, .left = 6, .right = 7, .type = if (floating) .float32 else .int } },
                .{ .branch = .{ .condition = 2, .then_instruction = 4, .else_instruction = 5 } },
                .{ .return_value = .{ .start = 9, .width = 1 } },
                .{ .return_value = .{ .start = 7, .width = 1 } },
            },
        };
        const allocation = try RegisterAllocation.allocate(allocator, function);
        try std.testing.expectEqual(@as(usize, 10), allocation.residences.len);
        try std.testing.expect(allocation.residences[9] != null or allocation.float_residences[9] != null);
        const residences = if (floating) allocation.float_residences else allocation.residences;
        try std.testing.expect(residences[0] != null);
        try std.testing.expectEqual(residences[0], residences[3]);
        try std.testing.expectEqual(residences[0], residences[6]);
        function.register_slots = allocation.residences;
        function.float_register_slots = allocation.float_residences;
        function.float_lane_slots = allocation.float_lane_residences;
        const builtin = @import("builtin");
        if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
            const Runner = @import("Runner.zig");
            const x: i64 = if (floating) @as(u32, @bitCast(@as(f32, 3))) else 3;
            const y: i64 = if (floating) @as(u32, @bitCast(@as(f32, 5))) else 5;
            for ([_]bool{ true, false }) |sum| {
                const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{ x, y, @intFromBool(sum) });
                try std.testing.expectEqual(Machine.Status.success, result.status);
                const expected: i64 = if (floating) @as(u32, @bitCast(@as(f32, if (sum) 8 else 5))) else if (sum) 8 else 5;
                try std.testing.expectEqual(expected, result.value);
            }
        }
    }
}

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

test "pure aggregate affinity does not delay an earlier scalar use" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function: Machine.Function = .{
        .name = "early_scalar_use",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 13,
        .frame_size = 112,
        .float_lane_groups = &.{.{ .slots = .{ 3, 9, 0, 0 }, .width = 2, .priority = 1, .recurrence = false, .in_loop = false }},
        .instructions = &.{
            .{ .constant_float32 = .{ .result = 2, .bits = @bitCast(@as(f32, 8)) } },
            .{ .binary = .{ .result = 3, .operator = .subtract, .left = 0, .right = 2, .type = .float32 } },
            .{ .constant_float32 = .{ .result = 4, .bits = @bitCast(@as(f32, 0.03125)) } },
            .{ .binary = .{ .result = 5, .operator = .multiply, .left = 3, .right = 4, .type = .float32 } },
            .{ .constant_float32 = .{ .result = 6, .bits = @bitCast(@as(f32, 0.001953125)) } },
            .{ .binary = .{ .result = 7, .operator = .multiply, .left = 1, .right = 6, .type = .float32 } },
            .{ .binary = .{ .result = 8, .operator = .add, .left = 5, .right = 7, .type = .float32 } },
            .{ .binary = .{ .result = 9, .operator = .subtract, .left = 0, .right = 2, .type = .float32 } },
            .{ .aggregate_init = .{ .result = .{ .start = 10, .width = 2, .aggregate = true }, .fields = &.{ .{ .start = 8, .width = 1 }, .{ .start = 9, .width = 1 } } } },
            .{ .binary = .{ .result = 12, .operator = .add, .left = 10, .right = 11, .type = .float32 } },
            .{ .return_value = .{ .start = 12, .width = 1 } },
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), allocation.float_lane_residences[3]);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const result = try @import("Runner.zig").invoke(allocator, .{ .functions = &.{function} }, 0, &.{ 0, 0 });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(@as(i64, @as(u32, @bitCast(@as(f32, -8.25)))), result.value);
}
