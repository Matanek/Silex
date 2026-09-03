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
            .source_name = if (double) "sqrt" else "sqrtf",
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
            for (allocation.float_residences) |resident| if (resident) |register| {
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
