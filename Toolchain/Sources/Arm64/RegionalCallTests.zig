const std = @import("std");
const builtin = @import("builtin");
const Machine = @import("Machine.zig");
const Allocation = @import("RegisterAllocation.zig");
const Runner = @import("Runner.zig");

test "aggregate calls in a loop pin arguments without spilling independent arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var instructions: std.ArrayList(Machine.Instruction) = .empty;
    try instructions.appendSlice(allocator, &.{
        .{ .constant_int = .{ .result = 2, .bits = 0 } },
        .{ .constant_float32 = .{ .result = 3, .bits = 0 } },
        .{ .constant_float32 = .{ .result = 4, .bits = @bitCast(@as(f32, 2)) } },
        .{ .constant_int = .{ .result = 5, .bits = 1 } },
        .{ .binary = .{ .result = 6, .left = 2, .right = 1, .operator = .less, .type = .int } },
        .{ .branch = .{ .condition = 6, .then_instruction = 6, .else_instruction = 0 } },
        .{ .class_load = .{ .base = 0, .byte_offset = 0, .result = .{ .start = 7, .width = 16, .aggregate = true } } },
    });
    for (0..16) |leaf| try instructions.append(allocator, .{ .binary = .{
        .result = @intCast(23 + leaf),
        .left = @intCast(7 + leaf),
        .right = 4,
        .operator = .multiply,
        .type = .float32,
    } });
    for (0..16) |leaf| try instructions.append(allocator, .{ .binary = .{
        .result = @intCast(39 + leaf),
        .left = @intCast(23 + leaf),
        .right = 4,
        .operator = .add,
        .type = .float32,
    } });
    try instructions.appendSlice(allocator, &.{
        .{ .call = .{ .function = 1, .arguments = &.{.{ .start = 39, .width = 16, .aggregate = true }}, .result = .{ .start = 55, .width = 1 } } },
        .{ .binary = .{ .result = 56, .left = 3, .right = 55, .operator = .add, .type = .float32 } },
        .{ .copy = .{ .result = 3, .operand = 56 } },
        .{ .binary = .{ .result = 57, .left = 2, .right = 5, .operator = .add, .type = .int } },
        .{ .copy = .{ .result = 2, .operand = 57 } },
        .{ .jump = 4 },
    });
    instructions.items[5].branch.else_instruction = instructions.items.len;
    try instructions.appendSlice(allocator, &.{
        // An unsupported effect makes this a regionally allocated function.
        .{ .constant_str = .{ .result = 58, .string = 0 } },
        .{ .print = .{ .value = 58, .kind = .string, .newline = false } },
        .{ .return_value = .{ .start = 3, .width = 1 } },
    });
    var caller: Machine.Function = .{
        .name = "regional_aggregate_loop",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 59,
        .frame_size = try Machine.frameSize(59),
        .instructions = instructions.items,
    };
    const allocated = try Allocation.allocate(allocator, caller);
    try std.testing.expect(allocated.float_residences.len != 0);
    try std.testing.expect(allocated.float_residences[23] != null);
    for (39..55) |slot| {
        try std.testing.expectEqual(null, allocated.float_residences[slot]);
        try std.testing.expectEqual(null, allocated.residences[slot]);
        try std.testing.expectEqual(null, allocated.float_lane_residences[slot]);
    }
    caller.register_slots = allocated.residences;
    caller.float_register_slots = allocated.float_residences;
    caller.float_lane_slots = allocated.float_lane_residences;
    caller.frame_size = allocated.frame_size;
    const callee: Machine.Function = .{
        .name = "sum_argument_endpoints",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 16, .aggregate = true }},
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 17,
        .frame_size = try Machine.frameSize(17),
        .instructions = &.{
            .{ .binary = .{ .result = 16, .left = 0, .right = 15, .operator = .add, .type = .float32 } },
            .{ .return_value = .{ .start = 16, .width = 1 } },
        },
    };
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    var object = [_]u64{0} ** 20;
    for (0..16) |i| object[4 + i] = @as(u32, @bitCast(@as(f32, @floatFromInt(i + 1))));
    for ([_]i64{ 0, 1, 100 }) |count| {
        const result = try Runner.invoke(allocator, .{ .functions = &.{ caller, callee }, .strings = &.{""} }, 0, &.{ @intCast(@intFromPtr(&object)), count });
        try std.testing.expectEqual(Machine.Status.success, result.status);
        const expected: f32 = 38 * @as(f32, @floatFromInt(count));
        try std.testing.expectEqual(@as(u32, @bitCast(expected)), @as(u32, @truncate(@as(u64, @bitCast(result.value)))));
    }
}

test "mixed collection leaves keep memory homes without disabling a sixteen-operation region" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var instructions: std.ArrayList(Machine.Instruction) = .empty;
    try instructions.appendSlice(allocator, &.{
        .{ .collection_load = .{
            .collection = .{ .start = 0, .width = 2, .aggregate = true },
            .index = 2,
            .count = 0,
            .dynamic = true,
            .view = true,
            .element_stride = 16,
            .header = 0,
            .tail = 0,
            .result = .{ .start = 4, .width = 2, .aggregate = true },
        } },
    });
    for (0..16) |i| try instructions.append(allocator, .{ .binary = .{
        .result = @intCast(6 + i),
        .left = if (i == 0) 3 else @intCast(5 + i),
        .right = 4,
        .operator = .add,
        .type = .float32,
    } });
    try instructions.appendSlice(allocator, &.{
        .{ .convert = .{ .result = 22, .operand = 5, .source = .int, .target = .float32, .header = 0, .checked = false } },
        .{ .binary = .{ .result = 23, .left = 21, .right = 22, .operator = .add, .type = .float32 } },
        .{ .constant_str = .{ .result = 24, .string = 0 } },
        .{ .print = .{ .value = 24, .kind = .string, .newline = false } },
        .{ .return_value = .{ .start = 23, .width = 1 } },
    });
    var function: Machine.Function = .{
        .name = "mixed_region",
        .parameter_count = 3,
        .parameters = &.{ .{ .start = 0, .width = 2, .aggregate = true }, .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 } },
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 25,
        .frame_size = try Machine.frameSize(25),
        .instructions = instructions.items,
    };
    const allocation = try Allocation.allocate(allocator, function);
    try std.testing.expectEqual(@as(usize, 25), allocation.float_residences.len);
    try std.testing.expect(allocation.float_residences[6] != null);
    for (4..6) |slot| {
        try std.testing.expectEqual(null, allocation.residences[slot]);
        try std.testing.expectEqual(null, allocation.float_residences[slot]);
        try std.testing.expectEqual(null, allocation.float_lane_residences[slot]);
    }
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    function.frame_size = allocation.frame_size;
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    var input = [_]u64{ @as(u32, @bitCast(@as(f32, 2))), 23 };
    const view = [_]u64{ @intFromPtr(&input), 1 };
    const actual = try Runner.invoke(allocator, .{ .functions = &.{function}, .strings = &.{""} }, 0, &.{ @intCast(@intFromPtr(&view)), 0, @as(u32, @bitCast(@as(f32, 1))) });
    try std.testing.expectEqual(Machine.Status.success, actual.status);
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 56))), @as(u32, @truncate(@as(u64, @bitCast(actual.value)))));
}
