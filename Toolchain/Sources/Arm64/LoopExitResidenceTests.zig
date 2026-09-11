const std = @import("std");
const builtin = @import("builtin");
const Machine = @import("Machine.zig");
const Allocation = @import("RegisterAllocation.zig");
const Runner = @import("Runner.zig");

fn witness() Machine.Function {
    return .{
        .name = "loop_with_interleaved_exit",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .int,
        .return_width = 1,
        .slot_count = 10,
        .frame_size = 80,
        .instructions = &.{
            .{ .constant_int = .{ .result = 1, .bits = 1 } },
            .{ .constant_int = .{ .result = 2, .bits = 0 } },
            .{ .constant_int = .{ .result = 3, .bits = 0 } },
            .{ .binary = .{ .result = 4, .operator = .less, .left = 2, .right = 0, .type = .int } },
            .{ .branch = .{ .condition = 4, .then_instruction = 7, .else_instruction = 5 } },
            // An unsupported stack emitter on an exit path lies numerically
            // inside the back edge. The sum crosses it; the index does not.
            .{ .storage_init = .{ .start = 8, .width = 2 } },
            .{ .return_value = .{ .start = 3, .width = 1 } },
            .{ .binary = .{ .result = 5, .operator = .add, .left = 3, .right = 2, .type = .int } },
            .{ .binary = .{ .result = 3, .operator = .add, .left = 5, .right = 1, .type = .int } },
            .{ .binary = .{ .result = 6, .operator = .add, .left = 2, .right = 1, .type = .int } },
            .{ .copy = .{ .result = 2, .operand = 6 } },
            .{ .jump = 3 },
        },
    };
}

test "loop exit layout keeps dead-on-exit indices resident and crossing sums pinned" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function = witness();
    const allocation = try Allocation.allocate(allocator, function);
    try std.testing.expectEqual(@as(usize, function.slot_count), allocation.residences.len);
    try std.testing.expect(allocation.residences[2] != null);
    try std.testing.expectEqual(@as(?u5, null), allocation.residences[3]);
    try std.testing.expectEqual(@as(?u5, null), allocation.residences[8]);
    try std.testing.expectEqual(@as(?u5, null), allocation.residences[9]);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    function.frame_size = allocation.frame_size;
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    for ([_]i64{ 0, 1, 20, 10000 }) |count| {
        const actual = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{count});
        try std.testing.expectEqual(Machine.Status.success, actual.status);
        try std.testing.expectEqual(@divExact(count * (count + 1), 2), actual.value);
    }
}

test "loop exit residence refuses a repeated barrier and preserves addressed homes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function = witness();
    const instructions = try allocator.dupe(Machine.Instruction, function.instructions);
    function.instructions = instructions;
    // Route the exit block back into the body: its stack emitter now belongs
    // to the repeated path and must fail the region admission test.
    instructions[6] = .{ .jump = 7 };
    const repeated = try Allocation.allocate(allocator, function);
    try std.testing.expect(repeated.residences.len == 0 or repeated.residences[2] == null);
    @memcpy(instructions, witness().instructions);
    instructions[5] = .{ .local_address = .{ .result = 8, .local = 2, .width = 1 } };
    const addressed = try Allocation.allocate(allocator, function);
    try std.testing.expectEqual(@as(?u5, null), addressed.residences[2]);
    try std.testing.expectEqual(@as(?u5, null), addressed.residences[8]);
}
