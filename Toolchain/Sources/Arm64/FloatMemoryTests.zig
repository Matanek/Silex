const std = @import("std");
const builtin = @import("builtin");
const Machine = @import("Machine.zig");
const Encoder = @import("Encoder.zig");
const A64 = @import("Instructions.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");
const Runner = @import("Runner.zig");

test "floating copies transfer directly between stack and resident registers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const stack_to_register: Machine.Function = .{
        .name = "stack_to_register",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .float64,
        .return_width = 1,
        .slot_count = 2,
        .frame_size = try Machine.frameSize(2),
        .register_slots = &.{ null, null },
        .float_register_slots = &.{ null, 17 },
        .instructions = &.{
            .{ .copy = .{ .result = 1, .operand = 0 } },
            .{ .return_value = .{ .start = 1, .width = 1 } },
        },
    };
    const register_to_stack: Machine.Function = .{
        .name = "register_to_stack",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .float64,
        .return_width = 1,
        .slot_count = 2,
        .frame_size = try Machine.frameSize(2),
        .register_slots = &.{ null, null },
        .float_register_slots = &.{ 16, null },
        .instructions = &.{
            .{ .copy = .{ .result = 1, .operand = 0 } },
            .{ .return_value = .{ .start = 1, .width = 1 } },
        },
    };
    const image = try Encoder.encode(allocator, .{
        .functions = &.{ stack_to_register, register_to_stack, sentinel },
    }, .{ .test_function = 0 });
    const first = image.code[image.function_offsets[0]..image.function_offsets[1]];
    const second = image.code[image.function_offsets[1]..image.function_offsets[2]];
    try std.testing.expect(containsWord(first, A64.loadFloat64Stack(.x17, 0)));
    try std.testing.expect(!containsWord(first, A64.moveFloat(.x17, .x9, true)));
    try std.testing.expect(containsWord(second, A64.storeFloat64Stack(.x16, 1)));
    try std.testing.expect(!containsWord(second, A64.moveFloat(.x9, .x16, true)));
}

test "floating negation writes its resident destination directly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const function: Machine.Function = .{
        .name = "resident_negation",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .float64,
        .return_width = 1,
        .slot_count = 2,
        .frame_size = try Machine.frameSize(2),
        .register_slots = &.{ null, null },
        .float_register_slots = &.{ 16, 17 },
        .instructions = &.{
            .{ .unary = .{ .result = 1, .operand = 0, .operator = .negate, .type = .float64 } },
            .{ .return_value = .{ .start = 1, .width = 1 } },
        },
    };
    const image = try Encoder.encode(arena.allocator(), .{
        .functions = &.{ function, sentinel },
    }, .{ .test_function = 0 });
    const code = image.code[image.function_offsets[0]..image.function_offsets[1]];
    try std.testing.expect(containsWord(code, A64.floatNegate(.x17, .x16, true)));
    try std.testing.expect(!containsWord(code, A64.floatNegate(.x10, .x9, true)));
}

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

test "allocated scalar references remain resident through unfused field transfers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function: Machine.Function = .{
        .name = "exchange_resident_field_bits",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .float64,
        .return_width = 1,
        .slot_count = 7,
        .frame_size = try Machine.frameSize(7),
        .instructions = &.{
            .{ .reference_offset = .{ .reference = 0, .result = 2, .byte_offset = 8 } },
            .{ .copy = .{ .result = 3, .operand = 2 } },
            .{ .reference_load = .{ .reference = 3, .result = .{ .start = 4, .width = 1 } } },
            .{ .reference_offset = .{ .reference = 0, .result = 5, .byte_offset = 16 } },
            .{ .copy = .{ .result = 6, .operand = 5 } },
            .{ .reference_store = .{ .reference = 6, .operand = .{ .start = 1, .width = 1 } } },
            .{ .return_value = .{ .start = 4, .width = 1 } },
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    for ([_]Machine.Slot{ 0, 2, 3, 5, 6 }) |slot| {
        try std.testing.expect(function.register_slots[slot] != null);
    }
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

test "negated multiplication and FMA do not consume the same producer twice" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]bool{ false, true }) |double| {
        for ([_]bool{ false, true }) |resident| {
            for ([_]bool{ false, true }) |negated_left| {
                for ([_]bool{ false, true }) |product_first| {
                    for ([_]Machine.BinaryOperator{ .add, .subtract }) |operator| {
                        const type_value = if (double) @import("../Ir.zig").Type.float64 else .float32;
                        const function: Machine.Function = .{
                            .name = "negated_product_then_arithmetic",
                            .parameter_count = 3,
                            .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 } },
                            .return_type = type_value,
                            .return_width = 1,
                            .slot_count = 6,
                            .frame_size = try Machine.frameSize(6),
                            .float_register_slots = if (resident) &.{ 16, 17, 18, 19, 20, 21 } else &.{},
                            .instructions = &.{
                                .{ .unary = .{ .result = 3, .operand = 0, .operator = .negate, .type = type_value } },
                                .{ .binary = .{ .result = 4, .left = if (negated_left) 3 else 1, .right = if (negated_left) 1 else 3, .operator = .multiply, .type = type_value } },
                                .{ .binary = .{ .result = 5, .left = if (product_first) 4 else 2, .right = if (product_first) 2 else 4, .operator = operator, .type = type_value } },
                                .{ .return_value = .{ .start = 5, .width = 1 } },
                            },
                        };
                        inline for (.{ Encoder.encode, Encoder.encodeLinux, Encoder.encodeWindows }) |encodeTarget| {
                            const image = try encodeTarget(allocator, .{ .functions = &.{ function, sentinel } }, .{ .test_function = 0 });
                            const code = image.code[image.function_offsets[0]..image.function_offsets[1]];
                            const entry = image.code[image.entry_offset.?..];
                            for (8..16) |register| {
                                try std.testing.expect(containsWord(entry, A64.storeFloat64Stack(@enumFromInt(register), @intCast(register - 8))));
                                try std.testing.expect(containsWord(entry, A64.loadFloat64Stack(@enumFromInt(register), @intCast(register - 8))));
                            }
                            try std.testing.expect(containsWord(code, A64.floatNegatedMultiply(
                                if (resident) .x20 else .x11,
                                if (resident) .x16 else .x9,
                                if (resident) .x17 else .x10,
                                double,
                            )));
                        }
                        if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) continue;
                        const arguments = [_]i64{
                            floatBits(1.5, double), floatBits(2.0, double), floatBits(0.5, double),
                        };
                        const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &arguments);
                        const expected: f64 = if (operator == .add) -2.5 else if (product_first) -3.5 else 3.5;
                        try std.testing.expectEqual(Machine.Status.success, result.status);
                        try std.testing.expectEqual(floatBits(expected, double), result.value);
                    }
                }
            }
        }
    }
}

fn floatBits(value: f64, double: bool) i64 {
    return if (double) @bitCast(value) else @intCast(@as(u32, @bitCast(@as(f32, @floatCast(value)))));
}

test "adjacent float arithmetic preserves product rounding with cached loop literals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]bool{ false, true }) |double| {
        for ([_]bool{ false, true }) |resident| {
            for ([_]bool{ false, true }) |literal_left| {
                for ([_]bool{ false, true }) |product_first| {
                    for ([_]Machine.BinaryOperator{ .add, .subtract }) |operator| {
                        const type_value = if (double) @import("../Ir.zig").Type.float64 else .float32;
                        const literal: Machine.Instruction = if (double)
                            .{ .constant_float64 = .{ .result = 2, .bits = @bitCast(@as(f64, 1.0 - 0x1p-52)) } }
                        else
                            .{ .constant_float32 = .{ .result = 2, .bits = @bitCast(@as(f32, 1.0 - 0x1p-23)) } };
                        const function: Machine.Function = .{
                            .name = "cached_literal_rounded_product",
                            .parameter_count = 3,
                            .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 5, .width = 1 } },
                            .return_type = type_value,
                            .return_width = 1,
                            .slot_count = 6,
                            .frame_size = try Machine.frameSize(6),
                            .float_register_slots = if (resident) &.{ 16, 17, 18, 19, 20, null } else &.{ null, null, null, null, null, null },
                            .instructions = &.{
                                literal,
                                .{ .binary = .{ .result = 3, .left = if (literal_left) 2 else 0, .right = if (literal_left) 0 else 2, .operator = .multiply, .type = type_value } },
                                .{ .binary = .{ .result = 4, .left = if (product_first) 3 else 1, .right = if (product_first) 1 else 3, .operator = operator, .type = type_value } },
                                .{ .branch = .{ .condition = 5, .then_instruction = 0, .else_instruction = 4 } },
                                .{ .return_value = .{ .start = 4, .width = 1 } },
                            },
                        };
                        inline for (.{ Encoder.encode, Encoder.encodeLinux, Encoder.encodeWindows }) |encodeTarget| {
                            const image = try encodeTarget(allocator, .{ .functions = &.{ function, sentinel } }, .{ .test_function = 0 });
                            const code = image.code[image.function_offsets[0]..image.function_offsets[1]];
                            const left: A64.Register = if (literal_left) .x5 else if (resident) .x16 else .x9;
                            const right: A64.Register = if (!literal_left) .x5 else if (resident) .x16 else .x10;
                            const product: A64.Register = if (resident) .x19 else .x11;
                            try std.testing.expect(containsWord(code, A64.floatArithmetic(product, left, right, .multiply, double)));
                            // No scalar fused multiply/add/subtract encoding may remove
                            // the rounding point represented by the first binary operation.
                            var offset: usize = 0;
                            while (offset + 4 <= code.len) : (offset += 4) {
                                const word = std.mem.readInt(u32, code[offset..][0..4], .little);
                                try std.testing.expect(word & 0x5f000000 != 0x1f000000);
                            }
                        }
                        if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) continue;
                        const input: f64 = if (double) 1.0 + 0x1p-52 else 1.0 + 0x1p-23;
                        const accumulator: f64 = if (operator == .add) -1.0 else 1.0;
                        const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{ floatBits(input, double), floatBits(accumulator, double), 0 });
                        const expected: f64 = 0.0;
                        try std.testing.expectEqual(Machine.Status.success, result.status);
                        try std.testing.expectEqual(floatBits(expected, double), result.value);
                    }
                }
            }
        }
    }
}

test "deferred vector subtraction preserves snapshots across later scalar loads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function: Machine.Function = .{
        .name = "horizontal_distance_squared",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 23,
        .frame_size = try Machine.frameSize(23),
        .float_lane_groups = &.{
            .{ .slots = .{ 10, 19, 0, 0 }, .width = 2, .priority = 9, .recurrence = false, .in_loop = false },
            .{ .slots = .{ 20, 21, 0, 0 }, .width = 2, .priority = 17, .recurrence = false, .in_loop = false },
        },
        .instructions = &.{
            .{ .reference_load = .{ .reference = 0, .result = .{ .start = 2, .width = 3, .aggregate = true } } },
            .{ .copy = .{ .result = 5, .operand = 2 } },
            .{ .reference_load = .{ .reference = 1, .result = .{ .start = 6, .width = 3, .aggregate = true } } },
            .{ .copy = .{ .result = 9, .operand = 6 } },
            .{ .binary = .{ .result = 10, .left = 5, .right = 9, .operator = .subtract, .type = .float32 } },
            .{ .reference_load = .{ .reference = 0, .result = .{ .start = 11, .width = 3, .aggregate = true } } },
            .{ .copy = .{ .result = 14, .operand = 13 } },
            .{ .reference_load = .{ .reference = 1, .result = .{ .start = 15, .width = 3, .aggregate = true } } },
            .{ .copy = .{ .result = 18, .operand = 17 } },
            .{ .binary = .{ .result = 19, .left = 14, .right = 18, .operator = .subtract, .type = .float32 } },
            .{ .binary = .{ .result = 20, .left = 10, .right = 10, .operator = .multiply, .type = .float32 } },
            .{ .binary = .{ .result = 21, .left = 19, .right = 19, .operator = .multiply, .type = .float32 } },
            .{ .binary = .{ .result = 22, .left = 20, .right = 21, .operator = .add, .type = .float32 } },
            .{ .return_value = .{ .start = 22, .width = 1 } },
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    try std.testing.expect(function.float_lane_slots[10] != null);
    try std.testing.expect(function.float_lane_slots[19] != null);
    const program: Machine.Program = .{ .functions = &.{function} };
    for ([_]Encoder.Platform{ .darwin, .linux, .windows }) |platform| {
        _ = try switch (platform) {
            .darwin => Encoder.encode(allocator, program, .none),
            .linux => Encoder.encodeLinux(allocator, program, .none),
            .windows => Encoder.encodeWindows(allocator, program, .none),
        };
    }
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    var current = [_]u64{ @bitCast(@as(i64, floatBits(3, false))), 0, @bitCast(@as(i64, floatBits(4, false))) };
    var previous = [_]u64{ @bitCast(@as(i64, floatBits(1, false))), 0, @bitCast(@as(i64, floatBits(1, false))) };
    const result = try Runner.invoke(allocator, program, 0, &.{
        @intCast(@intFromPtr(&current)), @intCast(@intFromPtr(&previous)),
    });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(floatBits(13, false), result.value);
}

test "wide float32 collection loads insert both resident SIMD lanes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Machine.Function = .{
        .name = "wide_resident_vector",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 8,
        .frame_size = try Machine.frameSize(8),
        .float_register_slots = &.{ null, null, null, 16, 16, 17, 18, 19 },
        .float_lane_slots = &.{ null, null, null, .{ .register = 16, .lane = 0, .partner = 4 }, .{ .register = 16, .lane = 1, .partner = 3 }, null, null, null },
        .instructions = &.{
            .{ .constant_int = .{ .result = 2, .bits = 0 } },
            .{ .collection_load = .{
                .result = .{ .start = 3, .width = 3, .aggregate = true },
                .collection = .{ .start = 0, .width = 2, .aggregate = true },
                .index = 2,
                .count = 0,
                .dynamic = true,
                .view = true,
                .checked = false,
                .element_stride = 24,
                .header = 0,
                .tail = 0,
            } },
            .{ .binary = .{ .result = 6, .left = 3, .right = 4, .operator = .add, .type = .float32 } },
            .{ .binary = .{ .result = 7, .left = 6, .right = 5, .operator = .add, .type = .float32 } },
            .{ .return_value = .{ .start = 7, .width = 1 } },
        },
    };
    const program: Machine.Program = .{ .functions = &.{ function, sentinel }, .strings = &.{""} };
    for ([_]Encoder.Platform{ .darwin, .linux, .windows }) |platform| {
        const image = try switch (platform) {
            .darwin => Encoder.encode(allocator, program, .none),
            .linux => Encoder.encodeLinux(allocator, program, .none),
            .windows => Encoder.encodeWindows(allocator, program, .none),
        };
        const code = image.code[image.function_offsets[0]..image.function_offsets[1]];
        try std.testing.expect(containsWord(code, A64.insertFloat32Lane(.x16, .x9, 0)));
        try std.testing.expect(containsWord(code, A64.insertFloat32Lane(.x16, .x9, 1)));
    }
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    var cells = [_]u64{ @intCast(floatBits(2, false)), @intCast(floatBits(3, false)), @intCast(floatBits(5, false)) };
    const result = try Runner.invoke(allocator, program, 0, &.{ @intCast(@intFromPtr(&cells)), 1 });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(floatBits(10, false), result.value);
}

test "Debug copy cleanup scalar cache observes floating writes to reused stack slots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]bool{ false, true }) |double| {
        const numeric: @import("../Types.zig").Type = if (double) .float64 else .float32;
        const one: u64 = @bitCast(floatBits(1, double));
        const two: u64 = @bitCast(floatBits(2, double));
        const negative: u64 = @bitCast(floatBits(-1, double));
        const cases = [_]struct { write: Machine.Instruction, expected: u64 }{
            .{ .write = if (double)
                .{ .constant_float64 = .{ .result = 1, .bits = two } }
            else
                .{ .constant_float32 = .{ .result = 1, .bits = @intCast(two) } }, .expected = two },
            .{ .write = .{ .unary = .{ .result = 1, .operand = 0, .operator = .negate, .type = numeric } }, .expected = negative },
            .{ .write = .{ .binary = .{ .result = 1, .left = 0, .right = 0, .operator = .subtract, .type = numeric } }, .expected = 0 },
        };
        for (cases, 0..) |case, case_index| {
            const instructions = [_]Machine.Instruction{
                .{ .constant_int = .{ .result = 0, .bits = one } },
                .{ .copy = .{ .result = 1, .operand = 0 } },
                case.write,
                .{ .copy = .{ .result = 2, .operand = 1 } },
                .{ .return_value = .{ .start = 2, .width = 1 } },
            };
            const function: Machine.Function = .{
                .name = "floating_stack_cache",
                .parameter_count = 0,
                .return_type = .int,
                .return_width = 1,
                .slot_count = 3,
                .frame_size = try Machine.frameSize(3),
                .instructions = &instructions,
            };
            const program: Machine.Program = .{ .functions = &.{function} };
            for ([_]Encoder.Platform{ .darwin, .linux, .windows }) |platform| {
                const image = try switch (platform) {
                    .darwin => Encoder.encode(allocator, program, .none),
                    .linux => Encoder.encodeLinux(allocator, program, .none),
                    .windows => Encoder.encodeWindows(allocator, program, .none),
                };
                try std.testing.expect(image.code.len != 0);
            }
            if (builtin.os.tag == .macos and builtin.cpu.arch == .aarch64) {
                const result = try Runner.invoke(allocator, program, 0, &.{});
                try std.testing.expectEqual(Machine.Status.success, result.status);
                try std.testing.expectEqual(case.expected, @as(u64, @bitCast(result.value)));
            }
            try writeScalarCacheProbe(allocator, function, case.expected, double, case_index);
        }
    }
}

// Standalone probes let native CI execute the exact stack-only machine form,
// including on Windows ARM64 where the bootstrap is built on Linux.
fn writeScalarCacheProbe(allocator: std.mem.Allocator, original: Machine.Function, expected: u64, double: bool, case_index: usize) !void {
    const instructions = try allocator.alloc(Machine.Instruction, original.instructions.len + 1);
    @memcpy(instructions[0 .. original.instructions.len - 1], original.instructions[0 .. original.instructions.len - 1]);
    instructions[original.instructions.len - 1] = .{ .print = .{ .value = 2, .kind = .unsigned_integer, .newline = true } };
    instructions[original.instructions.len] = .return_void;
    var function = original;
    function.return_type = .void;
    function.return_width = 0;
    function.instructions = instructions;
    const program: Machine.Program = .{ .functions = &.{function} };
    const directory = ".zig-cache/native-scalar-cache";
    try std.Io.Dir.cwd().createDirPath(std.testing.io, directory);
    for ([_]bool{ false, true }) |windows| {
        const image = try if (windows)
            Encoder.encodeWindows(allocator, program, .{ .executable_main = 0 })
        else
            Encoder.encodeLinux(allocator, program, .{ .executable_main = 0 });
        const bytes = if (windows) windows: {
            const Imports = @import("../Windows/Imports.zig");
            const sites = try allocator.alloc(Imports.Arm64Site, image.external_call_sites.len);
            for (image.external_call_sites, sites) |site, *mapped| mapped.* = .{
                .instruction_offset = site.instruction_offset,
                .symbol = site.windows_symbol orelse return error.InvalidMachineProgram,
            };
            break :windows try @import("../Windows/PE.zig").emitArm64(allocator, image.code, image.entry_offset.?, sites);
        } else try @import("../Linux/Elf.zig").emit(allocator, .arm64, image.code, image.entry_offset.?);
        const path = try std.fmt.allocPrint(allocator, "{s}/{s}-float{d}-{d}{s}", .{
            directory,                                    if (windows) @as([]const u8, "windows-arm64") else "linux-arm64",
            if (double) @as(u8, 64) else 32,              case_index,
            if (windows) @as([]const u8, ".exe") else "",
        });
        const executable = try std.Io.Dir.cwd().createFile(std.testing.io, path, .{});
        defer executable.close(std.testing.io);
        try executable.writeStreamingAll(std.testing.io, bytes);
        const expected_path = try std.fmt.allocPrint(allocator, "{s}.expected", .{path});
        const output = try std.Io.Dir.cwd().createFile(std.testing.io, expected_path, .{});
        defer output.close(std.testing.io);
        try output.writeStreamingAll(std.testing.io, try std.fmt.allocPrint(allocator, "{d}\n", .{expected}));
    }
}
