const std = @import("std");
const Ir = @import("../Ir.zig");

const Allocator = std.mem.Allocator;

/// Promotes non-addressed scalar locals to virtual values. Join values are
/// built as SSA phi nodes internally, then lowered to parallel copies on CFG
/// edges so the portable IR and every native backend keep a single contract.
pub fn optimize(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        functions[index] = try promoteFunction(allocator, function);
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn promoteFunction(allocator: Allocator, original: Ir.Function) !Ir.Function {
    if (original.blocks.len == 0 or original.local_types.len == 0) return original;

    const function = try reachableFunction(allocator, original);
    const block_count = function.blocks.len;
    const local_count = function.local_types.len;
    const promoted = try allocator.alloc(bool, local_count);
    for (function.local_types, 0..) |local_type, local| {
        // Float recurrences already receive global scalar/SIMD residences in
        // native backends. Preserve their local identity until lane affinity
        // can be carried explicitly through SSA phi nodes.
        promoted[local] = local_type.isInteger() or local_type == .bool;
    }
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .local_address => |address| promoted[address.local] = false,
        else => {},
    };
    if (!containsValue(bool, promoted, true)) return function;

    const predecessors = try buildPredecessors(allocator, function.blocks);
    const live_in = try localLiveness(allocator, function.blocks, promoted);
    var value_types: std.ArrayList(Ir.Type) = .empty;
    try value_types.appendSlice(allocator, function.value_types);

    const phi_values = try allocator.alloc(?Ir.ValueId, block_count * local_count);
    @memset(phi_values, null);
    for (0..block_count) |block| {
        if (predecessors[block].items.len < 2) continue;
        for (0..local_count) |local| {
            if (!promoted[local] or !live_in[at(local_count, block, local)]) continue;
            phi_values[at(local_count, block, local)] = value_types.items.len;
            try value_types.append(allocator, function.local_types[local]);
        }
    }

    const outgoing = try allocator.alloc(?Ir.ValueId, block_count * local_count);
    @memset(outgoing, null);
    const order = try traversalOrder(allocator, function.blocks);
    for (order) |block_index| {
        var current = try entryValues(allocator, local_count, block_index, predecessors, phi_values, outgoing);
        defer allocator.free(current);
        for (function.blocks[block_index].instructions) |instruction| switch (instruction) {
            .local_load => |load| if (promoted[load.local] and current[load.local] == null) return original,
            .local_store => |store| if (promoted[store.local]) {
                current[store.local] = store.operand;
            },
            else => {},
        };
        @memcpy(outgoing[block_index * local_count ..][0..local_count], current);
    }
    for (0..block_count) |block| for (0..local_count) |local| {
        if (phi_values[at(local_count, block, local)] == null) continue;
        for (predecessors[block].items) |predecessor| {
            if (outgoing[at(local_count, predecessor, local)] == null) return original;
        }
    };
    const phi_active = try allocator.alloc(bool, block_count * local_count);
    @memset(phi_active, false);
    for (phi_values, 0..) |phi, index| phi_active[index] = phi != null;
    const value_aliases = try allocator.alloc(Ir.ValueId, value_types.items.len);
    for (value_aliases, 0..) |*alias, value| alias.* = value;
    var aliases_changed = true;
    while (aliases_changed) {
        aliases_changed = false;
        for (0..block_count) |block| for (0..local_count) |local| {
            const index = at(local_count, block, local);
            if (!phi_active[index]) continue;
            const phi = phi_values[index].?;
            var unique: ?Ir.ValueId = null;
            var conflicting = false;
            for (predecessors[block].items) |predecessor| {
                const source = canonical(value_aliases, outgoing[at(local_count, predecessor, local)].?);
                if (source == phi) continue;
                if (unique == null) unique = source else if (unique.? != source) conflicting = true;
            }
            if (!conflicting and unique != null) {
                value_aliases[phi] = unique.?;
                phi_values[index] = unique.?;
                phi_active[index] = false;
                aliases_changed = true;
            }
        };
    }
    // Lowering a live phi on a branch predecessor requires a critical-edge
    // block. Keep that local in the backend's global allocation domain until
    // the machine IR can represent parallel edge transfers directly; an
    // otherwise empty block would add a branch to every hot iteration.
    const active_phi_count = try allocator.alloc(usize, local_count);
    @memset(active_phi_count, 0);
    for (0..block_count) |block| for (0..local_count) |local| {
        const index = at(local_count, block, local);
        if (!phi_active[index]) continue;
        active_phi_count[local] += 1;
        for (predecessors[block].items) |predecessor| switch (function.blocks[predecessor].terminator) {
            .branch => {
                promoted[local] = false;
                break;
            },
            else => {},
        };
    };
    for (active_phi_count, 0..) |count, local| {
        if (count > 1) promoted[local] = false;
    }
    for (0..block_count) |block| for (0..local_count) |local| {
        if (promoted[local]) continue;
        const index = at(local_count, block, local);
        phi_active[index] = false;
        phi_values[index] = null;
    };
    if (!containsValue(bool, promoted, true)) return function;
    for (phi_values) |*phi| {
        if (phi.*) |value| phi.* = canonical(value_aliases, value);
    }
    for (outgoing) |*value| {
        if (value.*) |present| value.* = canonical(value_aliases, present);
    }
    const value_remap = try allocator.alloc(Ir.ValueId, value_types.items.len);
    @memset(value_remap, std.math.maxInt(Ir.ValueId));
    var compact_value_types: std.ArrayList(Ir.Type) = .empty;
    try compact_value_types.appendSlice(allocator, function.value_types);
    for (function.value_types, 0..) |_, value| value_remap[value] = value;
    for (phi_values, 0..) |phi, index| {
        if (!phi_active[index]) continue;
        const value = phi.?;
        if (value_remap[value] != std.math.maxInt(Ir.ValueId)) continue;
        value_remap[value] = compact_value_types.items.len;
        try compact_value_types.append(allocator, value_types.items[value]);
    }
    for (phi_values) |*phi| if (phi.*) |value| {
        phi.* = value_remap[value];
    };
    for (outgoing) |*value| if (value.*) |present| {
        value.* = if (value_remap[present] == std.math.maxInt(Ir.ValueId))
            null
        else
            value_remap[present];
    };
    value_types = compact_value_types;

    const local_remap = try allocator.alloc(?Ir.LocalId, local_count);
    var local_types: std.ArrayList(Ir.Type) = .empty;
    for (function.local_types, 0..) |local_type, local| {
        if (promoted[local]) {
            local_remap[local] = null;
        } else {
            local_remap[local] = local_types.items.len;
            try local_types.append(allocator, local_type);
        }
    }

    var blocks: std.ArrayList(Ir.Block) = .empty;
    for (function.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        var current = try entryValues(allocator, local_count, block_index, predecessors, phi_values, outgoing);
        defer allocator.free(current);
        for (block.instructions) |instruction| switch (instruction) {
            .local_load => |load| if (promoted[load.local]) {
                try instructions.append(allocator, .{ .copy = .{
                    .result = load.result,
                    .operand = current[load.local] orelse return error.InvalidProgram,
                } });
            } else try instructions.append(allocator, .{ .local_load = .{
                .result = load.result,
                .local = local_remap[load.local].?,
            } }),
            .local_store => |store| if (promoted[store.local]) {
                current[store.local] = store.operand;
            } else try instructions.append(allocator, .{ .local_store = .{
                .local = local_remap[store.local].?,
                .operand = store.operand,
            } }),
            .local_address => |address| try instructions.append(allocator, .{ .local_address = .{
                .result = address.result,
                .local = local_remap[address.local].?,
            } }),
            else => try instructions.append(allocator, instruction),
        };
        try blocks.append(allocator, .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        });
    }

    for (0..block_count) |predecessor| {
        var terminator = blocks.items[predecessor].terminator;
        switch (terminator) {
            .jump => |target| {
                const copies = try edgeCopies(
                    allocator,
                    function,
                    predecessor,
                    target,
                    phi_values,
                    phi_active,
                    outgoing,
                    &value_types,
                );
                if (copies.len != 0) {
                    var instructions: std.ArrayList(Ir.Instruction) = .empty;
                    try instructions.appendSlice(allocator, blocks.items[predecessor].instructions);
                    try instructions.appendSlice(allocator, copies);
                    blocks.items[predecessor].instructions = try instructions.toOwnedSlice(allocator);
                }
            },
            .branch => |branch| {
                terminator.branch.then_block = try splitEdge(
                    allocator,
                    function,
                    predecessor,
                    branch.then_block,
                    phi_values,
                    phi_active,
                    outgoing,
                    &value_types,
                    &blocks,
                );
                terminator.branch.else_block = try splitEdge(
                    allocator,
                    function,
                    predecessor,
                    branch.else_block,
                    phi_values,
                    phi_active,
                    outgoing,
                    &value_types,
                    &blocks,
                );
                blocks.items[predecessor].terminator = terminator;
            },
            else => {},
        }
    }

    var result = function;
    result.value_types = try value_types.toOwnedSlice(allocator);
    result.local_types = try local_types.toOwnedSlice(allocator);
    result.blocks = try blocks.toOwnedSlice(allocator);
    return result;
}

fn reachableFunction(allocator: Allocator, function: Ir.Function) !Ir.Function {
    const reachable = try allocator.alloc(bool, function.blocks.len);
    @memset(reachable, false);
    var pending: std.ArrayList(Ir.BlockId) = .empty;
    try pending.append(allocator, 0);
    while (pending.pop()) |block| {
        if (block >= function.blocks.len or reachable[block]) continue;
        reachable[block] = true;
        switch (function.blocks[block].terminator) {
            .jump => |target| try pending.append(allocator, target),
            .branch => |branch| {
                try pending.append(allocator, branch.then_block);
                try pending.append(allocator, branch.else_block);
            },
            else => {},
        }
    }
    if (!containsValue(bool, reachable, false)) return function;
    const remap = try allocator.alloc(Ir.BlockId, function.blocks.len);
    var count: usize = 0;
    for (reachable, 0..) |present, block| if (present) {
        remap[block] = count;
        count += 1;
    };
    const blocks = try allocator.alloc(Ir.Block, count);
    var next: usize = 0;
    for (function.blocks, 0..) |block, block_index| {
        if (!reachable[block_index]) continue;
        blocks[next] = .{ .instructions = block.instructions, .terminator = remapTerminator(block.terminator, remap) };
        next += 1;
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn remapTerminator(terminator: Ir.Terminator, remap: []const Ir.BlockId) Ir.Terminator {
    return switch (terminator) {
        .jump => |target| .{ .jump = remap[target] },
        .branch => |branch| .{ .branch = .{
            .condition = branch.condition,
            .then_block = remap[branch.then_block],
            .else_block = remap[branch.else_block],
        } },
        else => terminator,
    };
}

fn buildPredecessors(allocator: Allocator, blocks: []const Ir.Block) ![]std.ArrayList(Ir.BlockId) {
    const result = try allocator.alloc(std.ArrayList(Ir.BlockId), blocks.len);
    for (result) |*list| list.* = .empty;
    for (blocks, 0..) |block, predecessor| switch (block.terminator) {
        .jump => |target| try result[target].append(allocator, predecessor),
        .branch => |branch| {
            try result[branch.then_block].append(allocator, predecessor);
            if (branch.else_block != branch.then_block) try result[branch.else_block].append(allocator, predecessor);
        },
        else => {},
    };
    return result;
}

fn localLiveness(allocator: Allocator, blocks: []const Ir.Block, promoted: []const bool) ![]bool {
    const local_count = promoted.len;
    const used = try allocator.alloc(bool, blocks.len * local_count);
    const defined = try allocator.alloc(bool, blocks.len * local_count);
    const live_in = try allocator.alloc(bool, blocks.len * local_count);
    const live_out = try allocator.alloc(bool, blocks.len * local_count);
    @memset(used, false);
    @memset(defined, false);
    @memset(live_in, false);
    @memset(live_out, false);
    for (blocks, 0..) |block, block_index| for (block.instructions) |instruction| switch (instruction) {
        .local_load => |load| if (promoted[load.local] and !defined[at(local_count, block_index, load.local)]) {
            used[at(local_count, block_index, load.local)] = true;
        },
        .local_store => |store| if (promoted[store.local]) {
            defined[at(local_count, block_index, store.local)] = true;
        },
        else => {},
    };
    var changed = true;
    while (changed) {
        changed = false;
        var reverse = blocks.len;
        while (reverse != 0) {
            reverse -= 1;
            for (0..local_count) |local| {
                var out = false;
                switch (blocks[reverse].terminator) {
                    .jump => |target| out = live_in[at(local_count, target, local)],
                    .branch => |branch| out = live_in[at(local_count, branch.then_block, local)] or
                        live_in[at(local_count, branch.else_block, local)],
                    else => {},
                }
                const input = used[at(local_count, reverse, local)] or
                    (out and !defined[at(local_count, reverse, local)]);
                if (live_out[at(local_count, reverse, local)] != out or
                    live_in[at(local_count, reverse, local)] != input)
                {
                    live_out[at(local_count, reverse, local)] = out;
                    live_in[at(local_count, reverse, local)] = input;
                    changed = true;
                }
            }
        }
    }
    return live_in;
}

fn traversalOrder(allocator: Allocator, blocks: []const Ir.Block) ![]const Ir.BlockId {
    var result: std.ArrayList(Ir.BlockId) = .empty;
    const visited = try allocator.alloc(bool, blocks.len);
    @memset(visited, false);
    var pending: std.ArrayList(Ir.BlockId) = .empty;
    try pending.append(allocator, 0);
    while (pending.pop()) |block| {
        if (visited[block]) continue;
        visited[block] = true;
        try result.append(allocator, block);
        switch (blocks[block].terminator) {
            .jump => |target| try pending.append(allocator, target),
            .branch => |branch| {
                try pending.append(allocator, branch.else_block);
                try pending.append(allocator, branch.then_block);
            },
            else => {},
        }
    }
    return result.toOwnedSlice(allocator);
}

fn entryValues(
    allocator: Allocator,
    local_count: usize,
    block: Ir.BlockId,
    predecessors: []const std.ArrayList(Ir.BlockId),
    phi_values: []const ?Ir.ValueId,
    outgoing: []const ?Ir.ValueId,
) ![]?Ir.ValueId {
    const result = try allocator.alloc(?Ir.ValueId, local_count);
    @memset(result, null);
    for (0..local_count) |local| {
        if (phi_values[at(local_count, block, local)]) |phi| {
            result[local] = phi;
        } else if (predecessors[block].items.len == 1) {
            result[local] = outgoing[at(local_count, predecessors[block].items[0], local)];
        }
    }
    return result;
}

fn splitEdge(
    allocator: Allocator,
    function: Ir.Function,
    predecessor: Ir.BlockId,
    target: Ir.BlockId,
    phi_values: []const ?Ir.ValueId,
    phi_active: []const bool,
    outgoing: []const ?Ir.ValueId,
    value_types: *std.ArrayList(Ir.Type),
    blocks: *std.ArrayList(Ir.Block),
) !Ir.BlockId {
    const copies = try edgeCopies(allocator, function, predecessor, target, phi_values, phi_active, outgoing, value_types);
    if (copies.len == 0) return target;
    const edge = blocks.items.len;
    try blocks.append(allocator, .{ .instructions = copies, .terminator = .{ .jump = target } });
    return edge;
}

fn edgeCopies(
    allocator: Allocator,
    function: Ir.Function,
    predecessor: Ir.BlockId,
    target: Ir.BlockId,
    phi_values: []const ?Ir.ValueId,
    phi_active: []const bool,
    outgoing: []const ?Ir.ValueId,
    value_types: *std.ArrayList(Ir.Type),
) ![]const Ir.Instruction {
    const local_count = function.local_types.len;
    var destinations: std.ArrayList(Ir.ValueId) = .empty;
    var sources: std.ArrayList(Ir.ValueId) = .empty;
    var types: std.ArrayList(Ir.Type) = .empty;
    for (0..local_count) |local| if (phi_active[at(local_count, target, local)]) {
        const destination = phi_values[at(local_count, target, local)].?;
        const source = outgoing[at(local_count, predecessor, local)] orelse return error.InvalidProgram;
        if (source == destination) continue;
        try destinations.append(allocator, destination);
        try sources.append(allocator, source);
        try types.append(allocator, function.local_types[local]);
    };
    var output: std.ArrayList(Ir.Instruction) = .empty;
    while (destinations.items.len != 0) {
        var safe: ?usize = null;
        for (destinations.items, 0..) |destination, index| {
            if (!containsValue(Ir.ValueId, sources.items, destination)) {
                safe = index;
                break;
            }
        }
        if (safe) |index| {
            try output.append(allocator, .{ .copy = .{
                .result = destinations.items[index],
                .operand = sources.items[index],
            } });
            _ = destinations.swapRemove(index);
            _ = sources.swapRemove(index);
            _ = types.swapRemove(index);
            continue;
        }
        const saved = destinations.items[0];
        const temporary = value_types.items.len;
        try value_types.append(allocator, types.items[0]);
        try output.append(allocator, .{ .copy = .{ .result = temporary, .operand = saved } });
        for (sources.items) |*source| {
            if (source.* == saved) source.* = temporary;
        }
    }
    return output.toOwnedSlice(allocator);
}

fn at(local_count: usize, block: usize, local: usize) usize {
    return block * local_count + local;
}

fn containsValue(comptime T: type, values: []const T, needle: T) bool {
    for (values) |value| if (value == needle) return true;
    return false;
}

fn canonical(aliases: []const Ir.ValueId, value: Ir.ValueId) Ir.ValueId {
    var current = value;
    while (aliases[current] != current) current = aliases[current];
    return current;
}

test "promote scalar locals through a loop and lower the phi to edge copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 0, .bits = 0 } },
            .{ .local_store = .{ .local = 0, .operand = 0 } },
        }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{
            .{ .local_load = .{ .result = 1, .local = 0 } },
            .{ .constant_int = .{ .result = 2, .bits = 4 } },
            .{ .binary = .{ .result = 3, .operator = .less, .left = 1, .right = 2 } },
        }, .terminator = .{ .branch = .{ .condition = 3, .then_block = 2, .else_block = 3 } } },
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 4, .bits = 1 } },
            .{ .binary = .{ .result = 5, .operator = .add, .left = 1, .right = 4 } },
            .{ .local_store = .{ .local = 0, .operand = 5 } },
        }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{.{ .local_load = .{ .result = 6, .local = 0 } }}, .terminator = .{ .return_value = 6 } },
    };
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "count",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{ .int, .int, .int, .bool, .int, .int, .int },
        .local_types = &.{.int},
        .blocks = &blocks,
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expectEqual(@as(usize, 0), optimized.functions[0].local_types.len);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "local.load"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "local.store"));
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "copy"));
}

test "keep a multi-join loop recurrence in the global allocation domain" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 0, .bits = 0 } },
            .{ .local_store = .{ .local = 0, .operand = 0 } },
        }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{
            .{ .local_load = .{ .result = 1, .local = 0 } },
            .{ .constant_int = .{ .result = 2, .bits = 4 } },
            .{ .binary = .{ .result = 3, .operator = .less, .left = 1, .right = 2 } },
        }, .terminator = .{ .branch = .{ .condition = 3, .then_block = 2, .else_block = 5 } } },
        .{ .instructions = &.{.{ .constant_bool = .{ .result = 4, .value = true } }}, .terminator = .{ .branch = .{ .condition = 4, .then_block = 3, .else_block = 4 } } },
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 5, .bits = 1 } },
            .{ .binary = .{ .result = 6, .operator = .add, .left = 1, .right = 5 } },
            .{ .local_store = .{ .local = 0, .operand = 6 } },
        }, .terminator = .{ .jump = 4 } },
        .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{.{ .local_load = .{ .result = 7, .local = 0 } }}, .terminator = .{ .return_value = 7 } },
    };
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "conditional_count",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{ .int, .int, .int, .bool, .bool, .int, .int, .int },
        .local_types = &.{.int},
        .blocks = &blocks,
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expectEqualSlices(Ir.Type, &.{.int}, optimized.functions[0].local_types);
}
