const std = @import("std");
const Ir = @import("../Ir.zig");

const Allocator = std.mem.Allocator;

/// A target-independent scalar lane. Backends may realize a group with SIMD,
/// split it, or leave it scalar without changing the portable IR.
pub const Lane = union(enum) {
    value: Ir.ValueId,
    local: Ir.LocalId,
};

pub const Group = struct {
    lanes: [4]Lane,
    width: u3,
    priority: u16,
    recurrence: bool,
    in_loop: bool,
};

pub const Plan = struct {
    groups: []const Group,
};

const Pair = struct { first: Lane, second: Lane, priority: u16, recurrence: bool, in_loop: bool };

pub fn analyze(allocator: Allocator, function: Ir.Function) Allocator.Error!Plan {
    var pairs: std.ArrayList(Pair) = .empty;
    defer pairs.deinit(allocator);

    // Adjacent float locals are only an affinity candidate. Requiring both to
    // be written avoids grouping unrelated scratch slots and supports 2D, 3D,
    // and 4D recurrences with the same rule.
    const stored = try allocator.alloc(bool, function.local_types.len);
    defer allocator.free(stored);
    @memset(stored, false);
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .local_store => |store| stored[store.local] = true,
        else => {},
    };
    if (function.local_types.len > 1) for (0..function.local_types.len - 1) |local| {
        if (stored[local] and stored[local + 1] and
            function.local_types[local] == .float32 and function.local_types[local + 1] == .float32)
        {
            _ = try addPair(allocator, &pairs, .{ .local = local }, .{ .local = local + 1 }, 0, false, false);
        }
    };

    // Structure construction gives a strong source-level ordering signal.
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .structure_init => |initialization| {
            if (initialization.fields.len > 1) for (0..initialization.fields.len - 1) |field| {
                const first = initialization.fields[field];
                const second = initialization.fields[field + 1];
                if (isFloatValue(function, first) and isFloatValue(function, second))
                    _ = try addPair(allocator, &pairs, .{ .value = first }, .{ .value = second }, 1, false, false);
            };
        },
        else => {},
    };

    // Grow the plan through loads and isomorphic arithmetic until fixed point.
    var changed = true;
    while (changed) {
        changed = false;
        for (function.blocks, 0..) |block, block_index| {
            const in_loop = blockInLoop(function, block_index);
            for (block.instructions, 0..) |first, first_index| {
                const end = @min(block.instructions.len, first_index + 65);
                for (block.instructions[first_index + 1 .. end]) |second| {
                    const candidate = compatiblePair(function, pairs.items, first, second, in_loop) orelse continue;
                    if (try addPair(
                        allocator,
                        &pairs,
                        candidate.first,
                        candidate.second,
                        candidate.priority,
                        candidate.recurrence,
                        candidate.in_loop,
                    )) changed = true;
                }
            }
        }
    }

    var groups: std.ArrayList(Group) = .empty;
    defer groups.deinit(allocator);
    for (pairs.items) |pair| {
        var pair_lanes: [4]Lane = undefined;
        pair_lanes[0] = pair.first;
        pair_lanes[1] = pair.second;
        try groups.append(allocator, .{
            .lanes = pair_lanes,
            .width = 2,
            .priority = pair.priority,
            .recurrence = pair.recurrence,
            .in_loop = pair.in_loop,
        });
        if (hasPredecessor(pairs.items, pair.first)) continue;
        var lanes: [4]Lane = undefined;
        lanes[0] = pair.first;
        lanes[1] = pair.second;
        var width: usize = 2;
        var priority = pair.priority;
        var recurrence = pair.recurrence;
        var in_loop = pair.in_loop;
        while (width < lanes.len) : (width += 1) {
            const next = successor(pairs.items, lanes[width - 1]) orelse break;
            lanes[width] = next.lane;
            priority = @min(priority, next.priority);
            recurrence = recurrence and next.recurrence;
            in_loop = in_loop or next.in_loop;
        }
        if (width > 2) try groups.append(allocator, .{
            .lanes = lanes,
            .width = @intCast(width),
            .priority = priority,
            .recurrence = recurrence,
            .in_loop = in_loop,
        });
    }
    return .{ .groups = try groups.toOwnedSlice(allocator) };
}

fn compatiblePair(
    function: Ir.Function,
    pairs: []const Pair,
    first: Ir.Instruction,
    second: Ir.Instruction,
    in_loop: bool,
) ?Pair {
    return switch (first) {
        .field_load => |left| switch (second) {
            .field_load => |right| if (equivalentValue(function, left.base, right.base) and left.field + 1 == right.field and
                isFloatValue(function, left.result) and isFloatValue(function, right.result))
                .{ .first = .{ .value = left.result }, .second = .{ .value = right.result }, .priority = 1, .recurrence = false, .in_loop = in_loop }
            else
                null,
            else => null,
        },
        .local_load => |left| switch (second) {
            .local_load => |right| if (paired(pairs, .{ .local = left.local }, .{ .local = right.local }))
                .{
                    .first = .{ .value = left.result },
                    .second = .{ .value = right.result },
                    .priority = pairPriority(pairs, .{ .local = left.local }, .{ .local = right.local }),
                    .recurrence = pairRecurrence(pairs, .{ .local = left.local }, .{ .local = right.local }),
                    .in_loop = in_loop,
                }
            else
                null,
            else => null,
        },
        .local_store => |left| switch (second) {
            .local_store => |right| if (paired(pairs, .{ .value = left.operand }, .{ .value = right.operand }))
                .{ .first = .{ .local = left.local }, .second = .{ .local = right.local }, .priority = pairPriority(pairs, .{ .value = left.operand }, .{ .value = right.operand }), .recurrence = true, .in_loop = in_loop }
            else
                null,
            else => null,
        },
        .copy => |left| switch (second) {
            .copy => |right| if (pairedOrEqual(pairs, left.operand, right.operand) and
                isFloatValue(function, left.result) and isFloatValue(function, right.result))
                .{
                    .first = .{ .value = left.result },
                    .second = .{ .value = right.result },
                    .priority = pairPriority(pairs, .{ .value = left.operand }, .{ .value = right.operand }),
                    .recurrence = (hasMultipleCopyDefinitions(function, left.result) and
                        hasMultipleCopyDefinitions(function, right.result)) or
                        pairRecurrence(pairs, .{ .value = left.operand }, .{ .value = right.operand }),
                    .in_loop = in_loop,
                }
            else
                null,
            else => null,
        },
        .constant_float32 => |left| switch (second) {
            .constant_float32 => |right| if (left.bits == right.bits and
                isFloatValue(function, left.result) and isFloatValue(function, right.result))
                .{
                    .first = .{ .value = left.result },
                    .second = .{ .value = right.result },
                    .priority = 1,
                    .recurrence = false,
                    .in_loop = in_loop,
                }
            else
                null,
            else => null,
        },
        .binary => |left| switch (second) {
            .binary => |right| if (left.operator == right.operator and
                isFloatValue(function, left.result) and isFloatValue(function, right.result) and
                pairedOrEqual(pairs, left.left, right.left) and pairedOrEqual(pairs, left.right, right.right))
                .{ .first = .{ .value = left.result }, .second = .{ .value = right.result }, .priority = @min(255, @as(u16, 8) + @max(
                    pairPriorityOrEqual(pairs, left.left, right.left),
                    pairPriorityOrEqual(pairs, left.right, right.right),
                )), .recurrence = pairRecurrenceOrEqual(pairs, left.left, right.left) or
                    pairRecurrenceOrEqual(pairs, left.right, right.right), .in_loop = in_loop }
            else
                null,
            else => null,
        },
        else => null,
    };
}

fn equivalentValue(function: Ir.Function, first: Ir.ValueId, second: Ir.ValueId) bool {
    if (first == second) return true;
    const left = valueOrigin(function, first, 0) orelse return false;
    const right = valueOrigin(function, second, 0) orelse return false;
    return std.meta.eql(left, right);
}

const Origin = union(enum) {
    local: Ir.LocalId,
    value: Ir.ValueId,
};

fn valueOrigin(function: Ir.Function, value: Ir.ValueId, depth: u3) ?Origin {
    if (depth == 7) return .{ .value = value };
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .local_load => |load| if (load.result == value) return .{ .local = load.local },
        .copy => |copy| if (copy.result == value) return if (hasMultipleCopyDefinitions(function, value))
            .{ .value = value }
        else
            valueOrigin(function, copy.operand, depth + 1),
        else => {},
    };
    return .{ .value = value };
}

fn hasMultipleCopyDefinitions(function: Ir.Function, value: Ir.ValueId) bool {
    var definitions: usize = 0;
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .copy => |copy| if (copy.result == value) {
            definitions += 1;
            if (definitions == 2) return true;
        },
        else => {},
    };
    return false;
}

fn pairedOrEqual(pairs: []const Pair, first: Ir.ValueId, second: Ir.ValueId) bool {
    return first == second or paired(pairs, .{ .value = first }, .{ .value = second });
}

fn pairPriorityOrEqual(pairs: []const Pair, first: Ir.ValueId, second: Ir.ValueId) u16 {
    return if (first == second) 0 else pairPriority(pairs, .{ .value = first }, .{ .value = second });
}

fn pairRecurrenceOrEqual(pairs: []const Pair, first: Ir.ValueId, second: Ir.ValueId) bool {
    return first != second and pairRecurrence(pairs, .{ .value = first }, .{ .value = second });
}

fn pairRecurrence(pairs: []const Pair, first: Lane, second: Lane) bool {
    for (pairs) |pair| if (std.meta.eql(pair.first, first) and std.meta.eql(pair.second, second)) return pair.recurrence;
    return false;
}

fn pairPriority(pairs: []const Pair, first: Lane, second: Lane) u16 {
    for (pairs) |pair| if (std.meta.eql(pair.first, first) and std.meta.eql(pair.second, second)) return pair.priority;
    return 0;
}

fn paired(pairs: []const Pair, first: Lane, second: Lane) bool {
    for (pairs) |pair| if (std.meta.eql(pair.first, first) and std.meta.eql(pair.second, second)) return true;
    return false;
}

fn addPair(
    allocator: Allocator,
    pairs: *std.ArrayList(Pair),
    first: Lane,
    second: Lane,
    priority: u16,
    recurrence: bool,
    in_loop: bool,
) Allocator.Error!bool {
    if (std.meta.eql(first, second)) return false;
    for (pairs.items) |*pair| if (std.meta.eql(pair.first, first) and std.meta.eql(pair.second, second)) {
        const next_priority = @max(priority, pair.priority);
        const next_recurrence = recurrence or pair.recurrence;
        const next_in_loop = in_loop or pair.in_loop;
        if (next_priority == pair.priority and next_recurrence == pair.recurrence and next_in_loop == pair.in_loop) return false;
        pair.priority = next_priority;
        pair.recurrence = next_recurrence;
        pair.in_loop = next_in_loop;
        return true;
    };
    try pairs.append(allocator, .{ .first = first, .second = second, .priority = priority, .recurrence = recurrence, .in_loop = in_loop });
    return true;
}

fn hasPredecessor(pairs: []const Pair, lane: Lane) bool {
    for (pairs) |pair| if (std.meta.eql(pair.second, lane)) return true;
    return false;
}

fn successor(pairs: []const Pair, lane: Lane) ?struct { lane: Lane, priority: u16, recurrence: bool, in_loop: bool } {
    for (pairs) |pair| if (std.meta.eql(pair.first, lane)) return .{
        .lane = pair.second,
        .priority = pair.priority,
        .recurrence = pair.recurrence,
        .in_loop = pair.in_loop,
    };
    return null;
}

fn blockInLoop(function: Ir.Function, block: usize) bool {
    for (function.blocks, 0..) |candidate, source| switch (candidate.terminator) {
        .jump => |target| if (target <= block and block <= source) return true,
        .branch => |branch_value| if ((branch_value.then_block <= block and block <= source) or
            (branch_value.else_block <= block and block <= source)) return true,
        else => {},
    };
    return false;
}

fn isFloatValue(function: Ir.Function, value: Ir.ValueId) bool {
    return function.value_types[value] == .float32;
}

test "SLP plan preserves XYZ lanes through loads and arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const vec3 = Ir.Type.structure(0);
    const types = [_]Ir.Type{ vec3, .float32, .float32, .float32, .float32, .float32, .float32 };
    const instructions = [_]Ir.Instruction{
        .{ .field_load = .{ .result = 1, .base = 0, .field = 0 } },
        .{ .field_load = .{ .result = 2, .base = 0, .field = 1 } },
        .{ .field_load = .{ .result = 3, .base = 0, .field = 2 } },
        .{ .binary = .{ .result = 4, .operator = .multiply, .left = 1, .right = 1 } },
        .{ .binary = .{ .result = 5, .operator = .multiply, .left = 2, .right = 2 } },
        .{ .binary = .{ .result = 6, .operator = .multiply, .left = 3, .right = 3 } },
    };
    const blocks = [_]Ir.Block{.{ .instructions = &instructions, .terminator = .{ .return_value = 6 } }};
    const function: Ir.Function = .{
        .name = "xyz",
        .parameter_types = &.{vec3},
        .return_type = .float32,
        .value_types = &types,
        .blocks = &blocks,
    };
    const plan = try analyze(allocator, function);
    var found_xyz = false;
    for (plan.groups) |group| if (group.width == 3 and
        std.meta.eql(group.lanes[0], Lane{ .value = 4 }) and
        std.meta.eql(group.lanes[1], Lane{ .value = 5 }) and
        std.meta.eql(group.lanes[2], Lane{ .value = 6 }))
    {
        found_xyz = true;
    };
    try std.testing.expect(found_xyz);
}
