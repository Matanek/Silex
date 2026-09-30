const std = @import("std");
const Machine = @import("Machine.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");

test "scalar residences survive class allocation and a clobbering destructor" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var caller: Machine.Function = .{
        .name = "runtime_boundaries",
        .parameter_count = 3,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 } },
        .return_type = .int,
        .return_width = 1,
        .slot_count = 11,
        .frame_size = try Machine.frameSize(11),
        .instructions = &.{
            .{ .constant_int = .{ .result = 3, .bits = 7 } },
            .{ .binary = .{ .result = 4, .left = 0, .right = 3, .operator = .add } },
            .{ .binary = .{ .result = 5, .left = 1, .right = 1, .operator = .multiply, .type = .float32 } },
            .{ .class_init = .{ .result = 6, .structure = 0, .fields = &.{.{ .start = 2, .width = 1 }} } },
            .{ .class_retain = .{ .operand = 6 } },
            .{ .class_drop = .{ .operand = 6, .static_type = 0, .skip_cycle = true, .plans = &.{.{ .structure = 0, .byte_count = 40, .functions = &.{1} }} } },
            .{ .binary = .{ .result = 7, .left = 5, .right = 1, .operator = .add, .type = .float32 } },
            .{ .convert = .{ .result = 8, .operand = 7, .source = .float32, .target = .int, .checked = false, .header = 0 } },
            .{ .binary = .{ .result = 9, .left = 4, .right = 8, .operator = .add } },
            .{ .return_value = .{ .start = 9, .width = 1 } },
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, caller);
    try std.testing.expect(allocation.residences[4] != null);
    try std.testing.expect(allocation.residences[4].? >= 19);
    try std.testing.expect(allocation.float_residences[5] != null);
    try std.testing.expect(allocation.float_residences[5].? >= 8 and allocation.float_residences[5].? < 16);
    try std.testing.expect(allocation.residences[6] != null);
    caller.register_slots = allocation.residences;
    caller.float_register_slots = allocation.float_residences;
    caller.float_lane_slots = allocation.float_lane_residences;
    caller.frame_size = allocation.frame_size;
    const destructor: Machine.Function = .{
        .name = "destructor",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .void,
        .slot_count = 4,
        .frame_size = try Machine.frameSize(4),
        .float_register_slots = &.{ null, null, null, 16 },
        .instructions = &.{
            .{ .class_load = .{ .result = .{ .start = 1, .width = 1 }, .base = 0, .byte_offset = 0 } },
            .{ .constant_int = .{ .result = 2, .bits = 99 } },
            .{ .constant_float32 = .{ .result = 3, .bits = @bitCast(@as(f32, 100)) } },
            .{ .reference_store = .{ .reference = 1, .operand = .{ .start = 2, .width = 1 } } },
            .return_void,
        },
    };
    if (@import("builtin").os.tag != .macos or @import("builtin").cpu.arch != .aarch64) return;
    var counter: u64 = 0;
    const actual = try @import("Runner.zig").invoke(allocator, .{ .functions = &.{ caller, destructor }, .strings = &.{""}, .copy_model = &.{0} }, 0, &.{ 5, @as(u32, @bitCast(@as(f32, 3))), @intCast(@intFromPtr(&counter)) });
    try std.testing.expectEqual(Machine.Status.success, actual.status);
    try std.testing.expectEqual(@as(i64, 24), actual.value);
    try std.testing.expectEqual(@as(u64, 99), counter);
}
