const std = @import("std");
const Machine = @import("Machine.zig");
const Liveness = @import("ResidenceLiveness.zig");
const Source = @import("../Source.zig");

// Copies have no ownership or memory effects. Follow demand per leaf through
// their chains instead of considering every field of a copied value used.
// Demand is deliberately function-wide: multiple definitions and loop-carried
// locals remain conservative. Address-taken storage is always observable.
pub fn optimize(allocator: std.mem.Allocator, function: Machine.Function) !Machine.Function {
    if (function.reuses_slots) return function;
    const demanded = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(demanded);
    @memset(demanded, false);
    for (function.instructions) |instruction| {
        if (prunable(instruction)) continue;
        for (demanded, 0..) |*used, slot| used.* = used.* or Liveness.instructionUses(instruction, slot);
        if (instruction == .local_address) {
            const address = instruction.local_address;
            @memset(demanded[address.local .. @as(usize, address.local) + address.width], true);
        }
    }
    var changed = true;
    while (changed) {
        changed = false;
        var index = function.instructions.len;
        while (index != 0) {
            index -= 1;
            const instruction = function.instructions[index];
            if (!prunable(instruction)) continue;
            const result = resultSpan(instruction);
            for (0..result.width) |leaf| {
                const source = operandLeaf(instruction, leaf);
                if (demanded[@as(usize, result.start) + leaf] and !demanded[source]) {
                    demanded[source] = true;
                    changed = true;
                }
            }
        }
    }
    var instructions: std.ArrayList(Machine.Instruction) = .empty;
    var positions: std.ArrayList(?Source.Position) = .empty;
    const remap = try allocator.alloc(usize, function.instructions.len + 1);
    defer allocator.free(remap);
    var altered = false;
    for (function.instructions, 0..) |instruction, index| {
        remap[index] = instructions.items.len;
        const start = instructions.items.len;
        if (prunable(instruction)) {
            const result = resultSpan(instruction);
            var all = true;
            for (0..result.width) |leaf| all = all and demanded[@as(usize, result.start) + leaf];
            if (all) {
                try instructions.append(allocator, instruction);
            } else {
                altered = true;
                for (0..result.width) |leaf| {
                    if (!demanded[@as(usize, result.start) + leaf]) continue;
                    try instructions.append(allocator, .{ .copy = .{
                        .result = @intCast(@as(usize, result.start) + leaf),
                        .operand = operandLeaf(instruction, leaf),
                    } });
                }
            }
        } else try instructions.append(allocator, instruction);
        if (function.instruction_positions.len != 0) {
            for (start..instructions.items.len) |_| try positions.append(allocator, function.instruction_positions[index]);
        }
    }
    remap[function.instructions.len] = instructions.items.len;
    if (!altered) {
        instructions.deinit(allocator);
        positions.deinit(allocator);
        return function;
    }
    for (instructions.items) |*instruction| switch (instruction.*) {
        .jump => |target| instruction.* = .{ .jump = remap[target] },
        .branch => |*branch| {
            branch.then_instruction = remap[branch.then_instruction];
            branch.else_instruction = remap[branch.else_instruction];
        },
        else => {},
    };
    var result = function;
    result.instructions = try instructions.toOwnedSlice(allocator);
    result.instruction_positions = try positions.toOwnedSlice(allocator);
    return result;
}

fn resultSpan(instruction: Machine.Instruction) Machine.Span {
    return switch (instruction) {
        .copy => |value| .{ .start = value.result, .width = 1 },
        .copy_range => |value| value.result,
        .aggregate_init => |value| value.result,
        else => unreachable,
    };
}

fn operandLeaf(instruction: Machine.Instruction, leaf: usize) Machine.Slot {
    return switch (instruction) {
        .copy => |value| value.operand,
        .copy_range => |value| @intCast(@as(usize, value.operand.start) + leaf),
        .aggregate_init => |value| blk: {
            var remaining = leaf;
            for (value.fields) |field| {
                if (remaining < field.width) break :blk @intCast(@as(usize, field.start) + remaining);
                remaining -= field.width;
            }
            unreachable;
        },
        else => unreachable,
    };
}

fn overlaps(a: Machine.Span, b: Machine.Span) bool {
    return @as(usize, a.start) < @as(usize, b.start) + b.width and
        @as(usize, b.start) < @as(usize, a.start) + a.width;
}

fn prunable(instruction: Machine.Instruction) bool {
    return switch (instruction) {
        .copy => true,
        .copy_range => |value| !overlaps(value.result, value.operand),
        .aggregate_init => |value| for (value.fields) |field| {
            if (overlaps(value.result, field)) break false;
        } else true,
        else => false,
    };
}

test "copy demand follows individual leaves through chains and branch joins" {
    const builtin = @import("builtin");
    const Runner = @import("Runner.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const original: Machine.Function = .{
        .name = "copy_chain",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 3, .aggregate = true }, .{ .start = 3, .width = 1 } },
        .return_type = .int,
        .return_width = 1,
        .slot_count = 10,
        .frame_size = try Machine.frameSize(10),
        .instructions = &.{
            .{ .copy_range = .{ .result = .{ .start = 4, .width = 3, .aggregate = true }, .operand = .{ .start = 0, .width = 3, .aggregate = true } } },
            .{ .branch = .{ .condition = 3, .then_instruction = 2, .else_instruction = 4 } },
            .{ .aggregate_init = .{ .result = .{ .start = 7, .width = 3, .aggregate = true }, .fields = &.{.{ .start = 4, .width = 3, .aggregate = true }} } },
            .{ .jump = 6 },
            .{ .copy = .{ .result = 7, .operand = 6 } },
            .{ .copy = .{ .result = 8, .operand = 4 } },
            .{ .return_value = .{ .start = 7, .width = 1 } },
        },
    };
    const optimized = try optimize(allocator, original);
    // Only first and last input leaves survive; the middle field and an
    // unused assignment on the second branch disappear transitively.
    try std.testing.expectEqual(@as(usize, 7), optimized.instructions.len);
    try std.testing.expectEqual(@as(Machine.Slot, 0), optimized.instructions[0].copy.operand);
    try std.testing.expectEqual(@as(Machine.Slot, 2), optimized.instructions[1].copy.operand);
    try std.testing.expectEqual(@as(usize, 3), optimized.instructions[2].branch.then_instruction);
    try std.testing.expectEqual(@as(usize, 5), optimized.instructions[2].branch.else_instruction);
    try std.testing.expectEqual(@as(usize, 6), optimized.instructions[4].jump);
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const input = [_]i64{ 0x1234567800000001, -88, -0x1234567800000002 };
    for ([_]i64{ 0, 1 }) |condition| {
        const args = [_]i64{ @intCast(@intFromPtr(&input)), condition };
        for ([_]Machine.Function{ original, optimized }) |function| {
            const actual = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &args);
            try std.testing.expectEqual(Machine.Status.success, actual.status);
            try std.testing.expectEqual(if (condition == 0) input[2] else input[0], actual.value);
        }
    }
}

test "copy demand preserves address-taken locals and overlapping transfers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Machine.Function = .{
        .name = "addressed",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 10,
        .frame_size = try Machine.frameSize(10),
        .instructions = &.{
            .{ .copy_range = .{ .result = .{ .start = 3, .width = 3, .aggregate = true }, .operand = .{ .start = 0, .width = 3, .aggregate = true } } },
            .{ .local_address = .{ .result = 6, .local = 3, .width = 3 } },
            .{ .copy_range = .{ .result = .{ .start = 7, .width = 2, .aggregate = true }, .operand = .{ .start = 8, .width = 2, .aggregate = true } } },
            .return_void,
        },
    };
    const optimized = try optimize(allocator, function);
    try std.testing.expectEqualSlices(Machine.Instruction, function.instructions, optimized.instructions);
}

test "copy demand reaches a fixed point through backwards loop copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Machine.Function = .{
        .name = "loop_copies",
        .parameter_count = 0,
        .return_type = .int,
        .slot_count = 5,
        .frame_size = try Machine.frameSize(5),
        .instructions = &.{
            .{ .copy = .{ .result = 1, .operand = 0 } },
            .{ .copy = .{ .result = 2, .operand = 1 } },
            .{ .branch = .{ .condition = 4, .then_instruction = 3, .else_instruction = 5 } },
            .{ .copy = .{ .result = 0, .operand = 2 } },
            .{ .jump = 0 },
            .{ .return_value = .{ .start = 0, .width = 1 } },
        },
    };
    const optimized = try optimize(allocator, function);
    try std.testing.expectEqualSlices(Machine.Instruction, function.instructions, optimized.instructions);
}
