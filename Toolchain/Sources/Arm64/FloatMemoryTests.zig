const std = @import("std");
const builtin = @import("builtin");
const Machine = @import("Machine.zig");
const Encoder = @import("Encoder.zig");
const Runner = @import("Runner.zig");

test "floating reference transfers use direct memory instructions and preserve payloads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Machine.Function = .{
        .name = "exchange_bits",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .float64,
        .return_width = 1,
        .slot_count = 3,
        .frame_size = 32,
        .register_slots = &.{ null, null, null },
        .float_register_slots = &.{ null, 16, 17 },
        .instructions = &.{
            .{ .reference_load = .{ .reference = 0, .result = .{ .start = 2, .width = 1 } } },
            .{ .reference_store = .{ .reference = 0, .operand = .{ .start = 1, .width = 1 } } },
            .{ .return_value = .{ .start = 2, .width = 1 } },
        },
    };
    const image = try Encoder.encode(allocator, .{ .functions = &.{ function, sentinel } }, .{ .test_function = 0 });
    const code = image.code[image.function_offsets[0]..image.function_offsets[1]];
    try std.testing.expect(containsWord(code, 0xfd400131)); // ldr d17, [x9]
    try std.testing.expect(containsWord(code, 0xfd000130)); // str d16, [x9]
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const payloads = [_]u64{ 0, 0x8000000000000000, 0x7ff8000000001234, 0x7ff0000000005678, 0xfff800000000abcd };
    for (payloads, 0..) |original, index| {
        var value = original;
        const replacement = payloads[(index + 1) % payloads.len];
        const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{
            @intCast(@intFromPtr(&value)), @bitCast(replacement),
        });
        try std.testing.expectEqual(Machine.Status.success, result.status);
        try std.testing.expectEqual(original, @as(u64, @bitCast(result.value)));
        try std.testing.expectEqual(replacement, value);
    }
}

test "single-use reference field offsets fuse into scalar loads and stores" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Machine.Function = .{
        .name = "exchange_field_bits",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .float64,
        .return_width = 1,
        .slot_count = 5,
        .frame_size = 48,
        .register_slots = &.{ null, null, null, null, null },
        .float_register_slots = &.{ null, 16, null, 17, null },
        .instructions = &.{
            .{ .reference_offset = .{ .reference = 0, .result = 2, .byte_offset = 8 } },
            .{ .reference_load = .{ .reference = 2, .result = .{ .start = 3, .width = 1 } } },
            .{ .reference_offset = .{ .reference = 0, .result = 4, .byte_offset = 16 } },
            .{ .reference_store = .{ .reference = 4, .operand = .{ .start = 1, .width = 1 } } },
            .{ .return_value = .{ .start = 3, .width = 1 } },
        },
    };
    const image = try Encoder.encode(allocator, .{ .functions = &.{ function, sentinel } }, .{ .test_function = 0 });
    const code = image.code[image.function_offsets[0]..image.function_offsets[1]];
    try std.testing.expect(containsWord(code, 0xfd400531)); // ldr d17, [x9, #8]
    try std.testing.expect(containsWord(code, 0xfd000930)); // str d16, [x9, #16]
    try std.testing.expect(!containsWord(code, 0xf9000be9)); // no field-address spill to slot 2
    try std.testing.expect(!containsWord(code, 0xf90013e9)); // no field-address spill to slot 4
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const payloads = [_]u64{ 0, 0x8000000000000000, 0x7ff8000000001234, 0x7ff0000000005678 };
    for (payloads, 0..) |original, index| {
        var fields = [_]u64{ 1, original, 3 };
        const replacement = payloads[(index + 1) % payloads.len];
        const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{
            @intCast(@intFromPtr(&fields)), @bitCast(replacement),
        });
        try std.testing.expectEqual(Machine.Status.success, result.status);
        try std.testing.expectEqual(original, @as(u64, @bitCast(result.value)));
        try std.testing.expectEqual(replacement, fields[2]);
    }
}

test "floating stack transfers address both windows without integer round trips" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]Machine.Slot{ 600, 4095, 4096, 8187 }) |slot| {
        const function: Machine.Function = .{
            .name = "negate_stack_bits",
            .parameter_count = 1,
            .parameters = &.{.{ .start = slot, .width = 1 }},
            .return_type = .float64,
            .return_width = 1,
            .slot_count = slot + 2,
            .frame_size = try Machine.frameSize(slot + 2),
            .instructions = &.{
                .{ .unary = .{ .result = slot + 1, .operand = slot, .operator = .negate, .type = .float64 } },
                .{ .return_value = .{ .start = slot + 1, .width = 1 } },
            },
        };
        const image = try Encoder.encode(allocator, .{ .functions = &.{ function, sentinel } }, .{ .test_function = 0 });
        const code = image.code[image.function_offsets[0]..image.function_offsets[1]];
        const load_base: u32 = if (slot >= 4096) 28 else 31;
        const store_base: u32 = if (slot + 1 >= 4096) 28 else 31;
        const load_word = 0xfd400009 | (@as(u32, slot % 4096) << 10) | (load_base << 5);
        const store_word = 0xfd00000a | (@as(u32, (slot + 1) % 4096) << 10) | (store_base << 5);
        try std.testing.expect(containsWord(code, load_word));
        try std.testing.expect(containsWord(code, store_word));
        if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) continue;
        for ([_]u64{ 0, 0x8000000000000000, 0x7ff8000000001234, 0x7ff0000000005678 }) |payload| {
            const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{@bitCast(payload)});
            try std.testing.expectEqual(Machine.Status.success, result.status);
            try std.testing.expectEqual(payload ^ 0x8000000000000000, @as(u64, @bitCast(result.value)));
        }
    }
}

const sentinel: Machine.Function = .{
    .name = "end_of_test_function",
    .parameter_count = 0,
    .return_type = .void,
    .slot_count = 0,
    .frame_size = 0,
    .instructions = &.{.return_void},
};

fn containsWord(code: []const u8, expected: u32) bool {
    var offset: usize = 0;
    while (offset + 4 <= code.len) : (offset += 4) {
        if (std.mem.readInt(u32, code[offset..][0..4], .little) == expected) return true;
    }
    return false;
}
