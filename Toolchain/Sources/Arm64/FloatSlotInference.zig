const std = @import("std");
const Machine = @import("Machine.zig");

pub fn infer(allocator: std.mem.Allocator, function: Machine.Function, result: []bool) std.mem.Allocator.Error!void {
    // Enum storage is a union: a leaf can hold a float in one variant and a
    // pointer in another. Copying a typed payload does not make that storage
    // uniformly floating, nor another variant's payload reached through it.
    const variant_storage = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(variant_storage);
    @memset(variant_storage, false);
    for (function.instructions) |instruction| switch (instruction) {
        .enum_init => |value| markOpaque(value.result, variant_storage),
        .enum_test => |value| markOpaque(value.operand, variant_storage),
        else => {},
    };
    if (function.return_type.isFloat()) {
        for (function.instructions) |instruction| switch (instruction) {
            .return_value => |value| if (!value.aggregate and value.width == 1) {
                result[value.start] = true;
            },
            else => {},
        };
    }
    for (function.instructions) |instruction| switch (instruction) {
        .constant_float32 => |value| result[value.result] = true,
        .constant_float64 => |value| result[value.result] = true,
        .unary => |value| if (value.type.isFloat()) {
            result[value.operand] = true;
            result[value.result] = true;
        },
        .binary => |value| if (value.type.isFloat()) {
            result[value.left] = true;
            result[value.right] = true;
            switch (value.operator) {
                .add, .subtract, .multiply, .divide, .minimum, .maximum => result[value.result] = true,
                else => {},
            }
        },
        .convert => |value| {
            if (value.source.isFloat()) result[value.operand] = true;
            if (value.target.isFloat()) result[value.result] = true;
        },
        else => {},
    };
    var changed = true;
    while (changed) {
        changed = false;
        for (function.instructions) |instruction| switch (instruction) {
            .copy => |copy| propagateFloat(copy.result, copy.operand, result, variant_storage, &changed),
            .copy_range => |copy| for (0..copy.result.width) |leaf| {
                propagateFloat(
                    @intCast(@as(usize, copy.result.start) + leaf),
                    @intCast(@as(usize, copy.operand.start) + leaf),
                    result,
                    variant_storage,
                    &changed,
                );
            },
            .aggregate_init => |value| {
                var destination_offset: usize = 0;
                for (value.fields) |field| {
                    for (0..field.width) |leaf| {
                        propagateFloat(
                            @intCast(@as(usize, value.result.start) + destination_offset + leaf),
                            @intCast(@as(usize, field.start) + leaf),
                            result,
                            variant_storage,
                            &changed,
                        );
                    }
                    destination_offset += field.width;
                }
            },
            else => {},
        };
    }
}

fn propagateFloat(left: Machine.Slot, right: Machine.Slot, result: []bool, variant_storage: []const bool, changed: *bool) void {
    if (variant_storage[left] or variant_storage[right]) return;
    if (result[left] == result[right]) return;
    result[left] = true;
    result[right] = true;
    changed.* = true;
}

fn markOpaque(span: Machine.Span, variant_storage: []bool) void {
    @memset(variant_storage[span.start .. @as(usize, span.start) + span.width], true);
}

test "enum variants do not propagate float affinity into another payload's pointer" {
    const instructions = [_]Machine.Instruction{
        .{ .enum_test = .{ .result = 3, .operand = .{ .start = 0, .width = 3, .aggregate = true }, .tag = 0 } },
        .{ .copy_range = .{ .result = .{ .start = 4, .width = 2, .aggregate = true }, .operand = .{ .start = 1, .width = 2, .aggregate = true } } },
        .{ .binary = .{ .result = 6, .left = 4, .right = 5, .operator = .add, .type = .float32 } },
        .{ .copy_range = .{ .result = .{ .start = 7, .width = 2, .aggregate = true }, .operand = .{ .start = 1, .width = 2, .aggregate = true } } },
        .{ .unary = .{ .result = 9, .operand = 8, .operator = .negate, .type = .float32 } },
    };
    const function: Machine.Function = .{
        .name = "enum_float_or_pointer",
        .parameter_count = 1,
        .slot_count = 10,
        .frame_size = 80,
        .return_type = .void,
        .instructions = &instructions,
    };
    var floats = [_]bool{false} ** 10;
    try infer(std.testing.allocator, function, &floats);
    try std.testing.expect(!floats[1] and !floats[2] and !floats[7]);
    for ([_]usize{ 4, 5, 6, 8, 9 }) |slot| try std.testing.expect(floats[slot]);
}
