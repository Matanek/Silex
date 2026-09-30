const std = @import("std");
const Machine = @import("Machine.zig");
const RegisterAllocation = @import("RegisterAllocation.zig");
const Encoder = @import("Encoder.zig");
const Types = @import("../Types.zig");

test "scalar math calls retain live values in ABI-preserved registers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]bool{ false, true }) |double| {
        const kind: Machine.AbiValue = if (double) .float64 else .float32;
        const type_value: Types.Type = if (double) .float64 else .float32;
        const external: Machine.ExternalFunction = .{
            .provider = "Darwin.lib_system",
            .source_name = if (double) "sin" else "sinf",
            .signature = .{ .arguments = &.{kind}, .result = kind },
        };
        var instructions = [_]Machine.Instruction{
            if (double) .{ .constant_float64 = .{ .result = 2, .bits = @bitCast(@as(f64, 4.0)) } } else .{ .constant_float32 = .{ .result = 2, .bits = @bitCast(@as(f32, 4.0)) } },
            if (double) .{ .constant_float64 = .{ .result = 3, .bits = @bitCast(@as(f64, 1.0)) } } else .{ .constant_float32 = .{ .result = 3, .bits = @bitCast(@as(f32, 1.0)) } },
            .{ .binary = .{ .result = 4, .operator = .add, .left = 0, .right = 3, .type = type_value } },
            .{ .external_call = .{ .result = 5, .function = 0, .arguments = &.{2} } },
            .{ .binary = .{ .result = 6, .operator = .add, .left = 4, .right = 5, .type = type_value } },
            .{ .convert = .{ .result = 7, .operand = 6, .source = type_value, .target = .int, .header = 0, .checked = false } },
            .{ .binary = .{ .result = 8, .operator = .add, .left = 7, .right = 1 } },
            .{ .return_value = .{ .start = 8, .width = 1 } },
        };
        for ([_]u13{ 9, 4097 }) |slots| {
            var function: Machine.Function = .{
                .name = "math_call_live_values",
                .parameter_count = 2,
                .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
                .return_type = .int,
                .return_width = 1,
                .slot_count = slots,
                .frame_size = try Machine.frameSize(slots),
                .instructions = &instructions,
            };
            const allocation = try RegisterAllocation.allocateWithExternals(allocator, function, &.{external});
            try std.testing.expectEqual(@as(usize, slots), allocation.residences.len);
            try std.testing.expect(allocation.residences[1] != null);
            try std.testing.expect(allocation.float_residences[4] != null);
            for (allocation.residences) |resident| if (resident) |register| {
                try std.testing.expect(register >= 19 and register <= (if (slots >= 4096) @as(u5, 27) else 28));
            };
            // Only the operand, live-through value and call result meet the
            // ABI boundary. Earlier and later scalar regions may use volatiles.
            for ([_]usize{ 2, 4, 5 }) |slot| if (allocation.float_residences[slot]) |register| {
                try std.testing.expect(register == 8 or (register >= 13 and register <= 15));
            };
            for (allocation.float_lane_residences) |resident| if (resident) |lane| {
                try std.testing.expect(lane.register == 8 or (lane.register >= 13 and lane.register <= 15));
                try std.testing.expect(lane.lane < 2);
            };
            function.register_slots = allocation.residences;
            function.float_register_slots = allocation.float_residences;
            function.float_lane_slots = allocation.float_lane_residences;
            const image = try Encoder.encode(allocator, .{ .functions = &.{function}, .external_functions = &.{external}, .strings = &.{"conversion"} }, .none);
            defer image.deinit(allocator);
            // The math operation remains a real ABI call, including its effects.
            try std.testing.expectEqual(@as(usize, 1), image.external_call_sites.len);
        }
        // A lookalike from another library must retain the conservative path.
        var other = external;
        other.provider = "unrelated_library";
        const unknown: Machine.Function = .{ .name = "unknown_math", .parameter_count = 2, .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } }, .return_type = .int, .return_width = 1, .slot_count = 9, .frame_size = try Machine.frameSize(9), .instructions = &instructions };
        const fallback = try RegisterAllocation.allocateWithExternals(allocator, unknown, &.{other});
        try std.testing.expectEqual(@as(usize, 0), fallback.residences.len);
    }
}

test "full lowering resolves scalar math before allocating profitable regions" {
    const Ir = @import("../Ir.zig");
    const Boundary = @import("../Boundary.zig");
    const Lower = @import("Lower.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var instructions: std.ArrayList(Ir.Instruction) = .empty;
    try instructions.append(allocator, .{ .constant_float32 = .{ .result = 1, .bits = @bitCast(@as(f32, 1)) } });
    for (0..16) |i| try instructions.append(allocator, .{ .binary = .{
        .result = i + 2, .left = if (i == 0) 0 else i + 1, .right = 1, .operator = .add,
    } });
    try instructions.append(allocator, .{ .boundary_call = .{ .result = 18, .function = 0, .arguments = &.{17} } });
    try instructions.append(allocator, .{ .binary = .{ .result = 19, .left = 17, .right = 18, .operator = .add } });
    const value_types = [_]Ir.Type{.float32} ** 20;
    const function: Ir.Function = .{
        .name = "sqrt_region", .parameter_types = &.{.float32}, .return_type = .float32,
        .value_types = &value_types,
        .blocks = &.{.{ .instructions = instructions.items, .terminator = .{ .return_value = 19 } }},
    };
    for ([_]bool{ false, true }) |trusted| {
        const boundary: Boundary.Function = .{
            .name = "square_root", .provider = if (trusted) "MacOS.lib_system" else "unrelated_library",
            .package_private = !trusted,
            .source_name = "sqrtf", .parameters = &.{.float32}, .return_type = .float32,
        };
        const lowered = try Lower.lowerWithModeAndBoundaries(allocator, .{ .functions = &.{function} }, &.{boundary}, .release);
        const machine = lowered.functions[0];
        const input = for (machine.instructions) |instruction| {
            if (instruction == .external_call) break instruction.external_call.arguments[0];
        } else return error.MissingMathCall;
        try std.testing.expectEqual(trusted, machine.float_register_slots[input] != null);
        const image = try Encoder.encode(allocator, lowered, .none);
        defer image.deinit(allocator);
        try std.testing.expectEqual(@as(usize, if (trusted) 0 else 1), image.external_call_sites.len);
        if (trusted and @import("builtin").os.tag == .macos and @import("builtin").cpu.arch == .aarch64) {
            const actual = try @import("Runner.zig").invoke(allocator, lowered, 0, &.{@as(u32, @bitCast(@as(f32, 9)))});
            try std.testing.expectEqual(Machine.Status.success, actual.status);
            try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 30))), @as(u32, @truncate(@as(u64, @bitCast(actual.value)))));
        }
    }
}
