const std = @import("std");
const Machine = @import("Machine.zig");
const Liveness = @import("ResidenceLiveness.zig");

// This late pass never extends a register lifetime. Only unaddressed stack
// homes can alias, within one basic block, until either home is overwritten.
pub fn optimize(allocator: std.mem.Allocator, function: Machine.Function) !Machine.Function {
    return optimizeConfigured(allocator, function, true, null);
}

const Counters = struct { definition_queries: usize = 0 };

fn defines(counters: ?*Counters, instruction: Machine.Instruction, slot: usize) bool {
    if (counters) |c| c.definition_queries += 1;
    return Liveness.instructionDefines(instruction, slot);
}

fn optimizeConfigured(allocator: std.mem.Allocator, function: Machine.Function, skip_identities: bool, counters: ?*Counters) !Machine.Function {
    if (function.reuses_slots) return function;
    const aliases = try allocator.alloc(Machine.Slot, function.slot_count);
    defer allocator.free(aliases);
    reset(aliases);
    const eligible = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(eligible);
    for (eligible, 0..) |*value, slot| value.* =
        (function.register_slots.len == 0 or function.register_slots[slot] == null) and
        (function.float_register_slots.len == 0 or function.float_register_slots[slot] == null) and
        (function.float_lane_slots.len == 0 or function.float_lane_slots[slot] == null);
    const heads = try allocator.alloc(bool, function.instructions.len + 1);
    defer allocator.free(heads);
    @memset(heads, false);
    for (function.instructions, 0..) |instruction, index| switch (instruction) {
        .jump => |target| {
            heads[target] = true;
            heads[index + 1] = true;
        },
        .branch => |branch| {
            heads[branch.then_instruction] = true;
            heads[branch.else_instruction] = true;
            heads[index + 1] = true;
        },
        .local_address => |address| @memset(eligible[address.local .. @as(usize, address.local) + address.width], false),
        else => {},
    };
    const instructions = try allocator.dupe(Machine.Instruction, function.instructions);
    for (instructions, 0..) |*instruction, index| {
        if (heads[index]) reset(aliases);
        // Rewrite only scalar consumers. Aggregate ABI operands retain their
        // contiguous stack layout and all memory/ownership effects stay put.
        switch (instruction.*) {
            .copy => |*v| v.operand = aliases[v.operand],
            .binary => |*v| {
                v.left = aliases[v.left];
                v.right = aliases[v.right];
            },
            .unary => |*v| v.operand = aliases[v.operand],
            .convert => |*v| v.operand = aliases[v.operand],
            .class_load => |*v| v.base = aliases[v.base],
            .class_store => |*v| v.base = aliases[v.base],
            .branch => |*v| v.condition = aliases[v.condition],
            else => {},
        }
        // Entries point directly at their storage source. A source write
        // invalidates every snapshot, while a destination write kills itself.
        for (aliases, 0..) |*source, slot| {
            // Resetting an identity cannot change it. Dependent snapshots
            // still test both their destination and their storage source.
            if (skip_identities and source.* == slot) continue;
            if (defines(counters, instruction.*, slot) or
                defines(counters, instruction.*, source.*)) source.* = @intCast(slot);
        }
        switch (instruction.*) {
            .copy => |v| if (eligible[v.result] and eligible[v.operand]) {
                aliases[v.result] = v.operand;
            },
            .copy_range => |v| if (!overlaps(v.result, v.operand)) {
                for (0..v.result.width) |leaf| {
                    const target = @as(usize, v.result.start) + leaf;
                    const source = aliases[@as(usize, v.operand.start) + leaf];
                    if (eligible[target] and eligible[source]) aliases[target] = source;
                }
            },
            .aggregate_init => |v| {
                var offset: usize = 0;
                const disjoint = for (v.fields) |field| {
                    if (overlaps(v.result, field)) break false;
                } else true;
                if (disjoint) for (v.fields) |field| {
                    for (0..field.width) |leaf| {
                        const target = @as(usize, v.result.start) + offset + leaf;
                        const source = aliases[@as(usize, field.start) + leaf];
                        if (eligible[target] and eligible[source]) aliases[target] = source;
                    }
                    offset += field.width;
                };
            },
            else => {},
        }
    }
    var result = function;
    result.instructions = instructions;
    return result;
}
fn reset(aliases: []Machine.Slot) void {
    for (aliases, 0..) |*alias, slot| alias.* = @intCast(slot);
}
fn overlaps(a: Machine.Span, b: Machine.Span) bool {
    return @as(usize, a.start) < @as(usize, b.start) + b.width and
        @as(usize, b.start) < @as(usize, a.start) + a.width;
}

test "stack copies forward numeric snapshots but stop at writes and joins" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const original: Machine.Function = .{
        .name = "snapshots",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .int,
        .return_width = 1,
        .slot_count = 8,
        .frame_size = try Machine.frameSize(8),
        .instructions = &.{
            .{ .copy = .{ .result = 1, .operand = 0 } },
            .{ .copy = .{ .result = 2, .operand = 1 } },
            .{ .binary = .{ .result = 3, .left = 2, .right = 1, .operator = .add } },
            .{ .constant_int = .{ .result = 0, .bits = 100 } },
            .{ .binary = .{ .result = 4, .left = 2, .right = 1, .operator = .add } },
            .{ .copy = .{ .result = 5, .operand = 0 } },
            .{ .jump = 7 },
            .{ .binary = .{ .result = 6, .left = 5, .right = 4, .operator = .add } },
            .{ .binary = .{ .result = 7, .left = 6, .right = 3, .operator = .add } },
            .{ .return_value = .{ .start = 7, .width = 1 } },
        },
    };
    const forwarded = try optimize(allocator, original);
    try std.testing.expectEqual(@as(Machine.Slot, 0), forwarded.instructions[2].binary.left);
    try std.testing.expectEqual(@as(Machine.Slot, 2), forwarded.instructions[4].binary.left);
    try std.testing.expectEqual(@as(Machine.Slot, 5), forwarded.instructions[7].binary.left);
    const optimized = try @import("DeadCopyLeaves.zig").optimize(allocator, forwarded);
    if (@import("builtin").os.tag != .macos or @import("builtin").cpu.arch != .aarch64) return;
    for ([_]Machine.Function{ original, optimized }) |function| {
        const actual = try @import("Runner.zig").invoke(allocator, .{ .functions = &.{function} }, 0, &.{7});
        try std.testing.expectEqual(Machine.Status.success, actual.status);
        try std.testing.expectEqual(@as(i64, 128), actual.value);
    }
}

test "stack forwarding excludes addressed and register homes and handles aggregate leaves" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const function: Machine.Function = .{
        .name = "homes",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 10,
        .frame_size = try Machine.frameSize(10),
        .register_slots = &.{ null, null, 19, null, null, null, null, null, null, null },
        .instructions = &.{
            .{ .copy_range = .{ .result = .{ .start = 3, .width = 3 }, .operand = .{ .start = 0, .width = 3 } } },
            .{ .binary = .{ .result = 6, .left = 3, .right = 4, .operator = .add } },
            .{ .binary = .{ .result = 7, .left = 5, .right = 3, .operator = .add } },
            .{ .local_address = .{ .result = 8, .local = 1, .width = 1 } },
            .return_void,
        },
    };
    const after = try optimize(arena.allocator(), function);
    try std.testing.expectEqual(@as(Machine.Slot, 0), after.instructions[1].binary.left);
    try std.testing.expectEqual(@as(Machine.Slot, 4), after.instructions[1].binary.right);
    try std.testing.expectEqual(@as(Machine.Slot, 5), after.instructions[2].binary.left);
}

test "stack forwarding identity pruning preserves source writes ranges and block joins" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const original: Machine.Function = .{
        .name = "sparse aliases",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .int,
        .return_width = 1,
        .slot_count = 2048,
        .frame_size = try Machine.frameSize(2048),
        .instructions = &.{
            .{ .copy = .{ .result = 2, .operand = 0 } },
            .{ .copy = .{ .result = 3, .operand = 2 } },
            .{ .binary = .{ .result = 4, .left = 3, .right = 1, .operator = .add } },
            .{ .constant_int = .{ .result = 0, .bits = 9 } },
            .{ .binary = .{ .result = 5, .left = 3, .right = 0, .operator = .add } },
            .{ .copy_range = .{ .result = .{ .start = 6, .width = 3 }, .operand = .{ .start = 3, .width = 3 } } },
            .{ .copy_range = .{ .result = .{ .start = 4, .width = 3 }, .operand = .{ .start = 3, .width = 3 } } },
            .{ .binary = .{ .result = 9, .left = 7, .right = 8, .operator = .add } },
            .{ .local_address = .{ .result = 10, .local = 1, .width = 1 } },
            .{ .copy = .{ .result = 11, .operand = 9 } },
            .{ .jump = 11 },
            .{ .binary = .{ .result = 12, .left = 11, .right = 2, .operator = .add } },
            .{ .return_value = .{ .start = 12, .width = 1 } },
        },
    };
    var before: Counters = .{};
    var after: Counters = .{};
    const expected = try optimizeConfigured(a, original, false, &before);
    const actual = try optimizeConfigured(a, original, true, &after);
    const expected_json = try std.json.Stringify.valueAlloc(a, expected, .{});
    const actual_json = try std.json.Stringify.valueAlloc(a, actual, .{});
    try std.testing.expectEqualStrings(expected_json, actual_json);
    try std.testing.expect(after.definition_queries * 100 < before.definition_queries);
    try std.testing.expectEqual(@as(Machine.Slot, 3), actual.instructions[4].binary.left);
    try std.testing.expectEqual(@as(Machine.Slot, 11), actual.instructions[11].binary.left);
}
