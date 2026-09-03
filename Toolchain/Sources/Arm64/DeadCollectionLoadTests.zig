const std = @import("std");
const builtin = @import("builtin");
const Machine = @import("Machine.zig");
const Encoder = @import("Encoder.zig");
const A64 = @import("Instructions.zig");

test "unused checked aggregate reads preserve bounds without copying elements" {
    try checkUnusedRead(true);
    try checkUnusedRead(false);
}

fn checkUnusedRead(view: bool) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Machine.Function = .{
        .name = "unused_checked_snapshot",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = if (view) 2 else 1, .aggregate = view }, .{ .start = 2, .width = 1 } },
        .return_type = .int,
        .return_width = 1,
        .slot_count = 10,
        .frame_size = 80,
        .register_slots = &([_]?u5{null} ** 10),
        .instructions = &.{
            .{ .collection_load = .{
                .result = .{ .start = 3, .width = 7, .aggregate = true },
                .collection = .{ .start = 0, .width = if (view) 2 else 1, .aggregate = view },
                .index = 2,
                .count = 0,
                .dynamic = true,
                .view = view,
                .element_stride = 56,
                .header = 0,
                .tail = 1,
            } },
            .{ .return_value = .{ .start = 2, .width = 1 } },
        },
    };
    const sentinel: Machine.Function = .{
        .name = "end_of_test_function",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 0,
        .frame_size = 0,
        .instructions = &.{.return_void},
    };
    const strings: []const []const u8 = &.{ "invalid view index ", " count " };
    const image = try Encoder.encode(allocator, .{ .functions = &.{ function, sentinel }, .strings = strings }, .{ .test_function = 0 });
    const code = image.code[image.function_offsets[0]..image.function_offsets[1]];
    // Slot 3 still transports the original count on the failure path. Slots
    // 4..9 are unobserved payload and must receive no eager element stores.
    var offset: usize = 0;
    while (offset + 4 <= code.len) : (offset += 4) {
        const word = std.mem.readInt(u32, code[offset..][0..4], .little);
        try std.testing.expect(word != A64.load64(.x12, .x10, 0));
        for (4..10) |slot| try std.testing.expect(word != A64.storeStack(.x12, @intCast(slot)));
    }
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const Runner = @import("Runner.zig");
    var values = [_]u64{42} ** 19;
    values[0..5].* = .{ 2, 1, 0, 152, 0 }; // Dynamic-list header, then two seven-slot values.
    for ([_]i64{ 0, -1, 2, -3 }) |index| {
        // Runner's argument convention accepts scalar parameters, so expose
        // the same view slots as two scalar inputs for this invocation only.
        var invoked = function;
        if (view) {
            invoked.parameter_count = 3;
            invoked.parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 } };
        }
        const pointer = if (view) &values[5] else &values[0];
        const arguments = [_]i64{ @intCast(@intFromPtr(pointer)), if (view) 2 else index, index };
        const result = try Runner.invoke(allocator, .{ .functions = &.{invoked}, .strings = strings }, 0, arguments[0..invoked.parameter_count]);
        try std.testing.expectEqual(if (index == 0 or index == -1) Machine.Status.success else Machine.Status.runtime_failure, result.status);
        if (result.status == .success) try std.testing.expectEqual(index, result.value);
    }
}
