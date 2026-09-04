const std = @import("std");
const builtin = @import("builtin");
const Machine = @import("Machine.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");
const Runner = @import("Runner.zig");

test "copies across an addressed local do not share snapshot residences" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Machine.Function = .{
        .name = "borrowed_snapshot_residences",
        .parameter_count = 0,
        .parameters = &.{},
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 17,
        .frame_size = try Machine.frameSize(17),
        .instructions = &.{
            .{ .constant_float32 = .{ .result = 0, .bits = @bitCast(@as(f32, 3)) } },
            .{ .constant_float32 = .{ .result = 1, .bits = @bitCast(@as(f32, 4)) } },
            .{ .aggregate_init = .{
                .result = .{ .start = 2, .width = 2, .aggregate = true },
                .fields = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
            } },
            .{ .copy_range = .{
                .result = .{ .start = 14, .width = 2, .aggregate = true },
                .operand = .{ .start = 2, .width = 2, .aggregate = true },
            } },
            .{ .local_address = .{ .result = 4, .local = 14, .width = 2 } },
            .{ .call = .{
                .result = null,
                .function = 1,
                .arguments = &.{.{ .start = 4, .width = 1 }},
            } },
            .{ .copy_range = .{
                .result = .{ .start = 5, .width = 2, .aggregate = true },
                .operand = .{ .start = 14, .width = 2, .aggregate = true },
            } },
            .{ .binary = .{ .result = 16, .operator = .add, .left = 5, .right = 2, .type = .float32 } },
            .{ .return_value = .{ .start = 16, .width = 1 } },
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    try std.testing.expectEqual(@as(?u5, null), allocation.residences[4]);
    try std.testing.expectEqual(@as(?u5, null), allocation.float_residences[14]);
    try std.testing.expectEqual(@as(?u5, null), allocation.float_residences[15]);
    try std.testing.expect(allocation.float_residences[2] != null);
    try std.testing.expect(allocation.float_residences[5] != null);
    try std.testing.expect(allocation.float_residences[2] != allocation.float_residences[5]);
}

test "direct calls preserve resident view loop state and checked diagnostics" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var caller: Machine.Function = .{
        .name = "call_view_element",
        .parameter_count = 3,
        .parameters = &.{
            .{ .start = 0, .width = 1 },
            .{ .start = 1, .width = 1 },
            .{ .start = 2, .width = 1 },
        },
        .return_type = .void,
        .slot_count = 7,
        .frame_size = try Machine.frameSize(7),
        .instructions = &.{
            .{ .copy_range = .{
                .result = .{ .start = 3, .width = 2, .aggregate = true },
                .operand = .{ .start = 0, .width = 2, .aggregate = true },
            } },
            .{ .local_address = .{ .result = 5, .local = 3, .width = 2 } },
            .{ .collection_reference = .{
                .result = 6,
                .collection = .{ .start = 3, .width = 2, .aggregate = true },
                .reference = 5,
                .index = 2,
                .element_width = 1,
                .count = 0,
                .dynamic = true,
                .view = true,
                .checked = true,
                .header = 0,
                .tail = 1,
            } },
            .{ .call = .{ .result = null, .function = 1, .arguments = &.{.{ .start = 6, .width = 1 }} } },
            .return_void,
        },
    };
    const caller_allocation = try RegisterAllocation.allocate(allocator, caller);
    caller.register_slots = caller_allocation.residences;
    caller.float_register_slots = caller_allocation.float_residences;
    caller.float_lane_slots = caller_allocation.float_lane_residences;
    try std.testing.expectEqual(@as(?u5, null), caller.register_slots[5]);
    for ([_]usize{ 0, 1, 2, 3, 4, 6 }) |slot| {
        try std.testing.expect(caller.register_slots[slot] != null);
        try std.testing.expect(caller.register_slots[slot].? >= 19);
    }

    var increment: Machine.Function = .{
        .name = "increment",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .void,
        .slot_count = 4,
        .frame_size = try Machine.frameSize(4),
        .instructions = &.{
            .{ .reference_load = .{ .result = .{ .start = 1, .width = 1 }, .reference = 0 } },
            .{ .constant_int = .{ .result = 2, .bits = 1 } },
            .{ .binary = .{ .result = 3, .left = 1, .right = 2, .operator = .add, .type = .int } },
            .{ .reference_store = .{ .reference = 0, .operand = .{ .start = 3, .width = 1 } } },
            .return_void,
        },
    };
    const increment_allocation = try RegisterAllocation.allocate(allocator, increment);
    increment.register_slots = increment_allocation.residences;
    increment.float_register_slots = increment_allocation.float_residences;
    increment.float_lane_slots = increment_allocation.float_lane_residences;

    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const strings: []const []const u8 = &.{ "invalid view index ", " count " };
    var values = [_]u64{ 41, 99 };
    const valid = try Runner.invoke(allocator, .{
        .functions = &.{ caller, increment },
        .strings = strings,
    }, 0, &.{ @intCast(@intFromPtr(&values)), 2, -1 });
    try std.testing.expectEqual(Machine.Status.success, valid.status);
    try std.testing.expectEqual(@as(u64, 100), values[1]);

    const invalid = try Runner.invoke(allocator, .{
        .functions = &.{ caller, increment },
        .strings = strings,
    }, 0, &.{ @intCast(@intFromPtr(&values)), 2, 2 });
    try std.testing.expectEqual(Machine.Status.runtime_failure, invalid.status);
    try std.testing.expectEqual(@as(u64, 41), values[0]);
    try std.testing.expectEqual(@as(u64, 100), values[1]);
}
