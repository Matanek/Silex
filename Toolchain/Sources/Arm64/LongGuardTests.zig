const std = @import("std");
const builtin = @import("builtin");
const Machine = @import("Machine.zig");
const Encoder = @import("Encoder.zig");
const Runner = @import("Runner.zig");

test "long failure guards preserve calls overflow division and the successful path" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    // Wide copies put the handler beyond imm19 reach with only 200 IR steps.
    // Avoid thousands of unrelated scalar instructions in the regression.
    const tail_length = 200;
    const instructions = try allocator.alloc(Machine.Instruction, tail_length + 3);
    const fields = try allocator.alloc(Machine.Span, 2048);
    @memset(fields, .{ .start = 0, .width = 1 });
    instructions[1] = .{ .aggregate_init = .{
        .result = .{ .start = 4, .width = 2048, .aggregate = true },
        .fields = fields,
    } };
    for (instructions[2 .. tail_length + 2]) |*instruction| {
        instruction.* = .{ .copy_range = .{
            .result = .{ .start = 2052, .width = 2048, .aggregate = true },
            .operand = .{ .start = 4, .width = 2048, .aggregate = true },
        } };
    }
    instructions[tail_length + 2] = .{ .return_value = .{ .start = 2, .width = 1 } };
    const parameters = [_]Machine.Span{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } };
    const callee: Machine.Function = .{
        .name = "checked_callee",
        .parameter_count = 2,
        .parameters = &parameters,
        .return_type = .int,
        .return_width = 1,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .instructions = &.{
            .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
            .{ .return_value = .{ .start = 2, .width = 1 } },
        },
    };
    for (0..3) |scenario| {
        instructions[0] = if (scenario == 2)
            .{ .call = .{ .result = .{ .start = 2, .width = 1 }, .function = 1, .arguments = &parameters } }
        else
            .{ .binary = .{ .result = 2, .operator = if (scenario == 0) .add else .divide, .left = 0, .right = 1 } };
        const caller: Machine.Function = .{
            .name = "long_guard",
            .parameter_count = 2,
            .parameters = &parameters,
            .return_type = .int,
            .return_width = 1,
            .slot_count = 4100,
            .frame_size = try Machine.frameSize(4100),
            .instructions = instructions,
        };
        const program: Machine.Program = .{ .functions = &.{ caller, callee } };
        const encoders = [_]*const fn (std.mem.Allocator, Machine.Program, Encoder.Entry) Encoder.Error!Encoder.Image{
            Encoder.encode, Encoder.encodeLinux, Encoder.encodeWindows,
        };
        for (encoders) |encode| {
            const image = try encode(allocator, program, .none);
            defer image.deinit(allocator);
            try std.testing.expect(image.function_offsets[1] > 1 << 20);
        }
        if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
            const success = try Runner.invoke(allocator, program, 0, &.{ if (scenario == 1) 84 else 40, 2 });
            try std.testing.expectEqual(Machine.Status.success, success.status);
            try std.testing.expectEqual(@as(i64, 42), success.value);
            const failure = try Runner.invoke(allocator, program, 0, &.{ if (scenario == 1) 42 else std.math.maxInt(i64), if (scenario == 1) 0 else 1 });
            try std.testing.expectEqual(if (scenario == 1) Machine.Status.division_by_zero else Machine.Status.integer_overflow, failure.status);
        }
    }
}
