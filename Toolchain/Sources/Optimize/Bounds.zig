const std = @import("std");
const Ir = @import("../Ir.zig");

const Allocator = std.mem.Allocator;

const Definition = struct {
    block: Ir.BlockId,
    instruction: usize,
    value: Ir.Instruction,
};

const CollectionAccess = struct {
    checked: bool,
    collection: Ir.ValueId,
    index: Ir.ValueId,
};

pub fn optimize(allocator: Allocator, function: Ir.Function) !Ir.Function {
    if (function.blocks.len < 3 or function.local_types.len == 0) return function;
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    var changed = false;

    for (blocks, 0..) |header, header_id| {
        const branch = switch (header.terminator) {
            .branch => |value| value,
            else => continue,
        };
        const comparison_definition = findDefinition(function, branch.condition) orelse continue;
        if (comparison_definition.block != header_id) continue;
        const comparison = switch (comparison_definition.value) {
            .binary => |value| value,
            else => continue,
        };
        if (comparison.operator != .less) continue;
        const induction_definition = findDefinition(function, comparison.left) orelse continue;
        if (induction_definition.block != header_id) continue;
        const induction = switch (induction_definition.value) {
            .local_load => |value| value,
            else => continue,
        };
        const counted_collection = (try resolveCollectionCount(allocator, function, comparison.right, header_id)) orelse continue;
        const loop_blocks = (try naturalLoopBlocks(allocator, blocks, header_id, branch.then_block)) orelse continue;
        if (!(try provenZeroOriginInduction(allocator, function, loop_blocks, header_id, induction.local))) continue;

        for (blocks, 0..) |block, block_id| {
            if (!loop_blocks[block_id] or block_id == header_id) continue;
            var rewritten = try allocator.dupe(Ir.Instruction, block.instructions);
            var block_changed = false;
            for (rewritten, 0..) |instruction, instruction_index| {
                const access: CollectionAccess = switch (instruction) {
                    .collection_load => |value| .{ .checked = value.checked, .collection = value.collection, .index = value.index },
                    .collection_reference => |value| .{ .checked = value.checked, .collection = value.collection, .index = value.index },
                    else => continue,
                };
                if (!access.checked or !sameStableLocalValue(function, access.collection, counted_collection)) continue;
                if (access.collection != counted_collection) {
                    const collection_local = matchingLocalLoad(function, access.collection, counted_collection) orelse continue;
                    if (try incrementCanReachLoad(
                        allocator,
                        function,
                        loop_blocks,
                        header_id,
                        collection_local,
                        block_id,
                        instruction_index,
                    )) continue;
                }
                const index_definition = findDefinition(function, access.index) orelse continue;
                const index_load = switch (index_definition.value) {
                    .local_load => |value| value,
                    else => continue,
                };
                if (index_load.local != induction.local) continue;
                if (try incrementCanReachLoad(
                    allocator,
                    function,
                    loop_blocks,
                    header_id,
                    induction.local,
                    block_id,
                    instruction_index,
                )) continue;
                switch (instruction) {
                    .collection_load => |load| {
                        var bounded = load;
                        bounded.checked = false;
                        rewritten[instruction_index] = .{ .collection_load = bounded };
                    },
                    .collection_reference => |reference| {
                        var bounded = reference;
                        bounded.checked = false;
                        rewritten[instruction_index] = .{ .collection_reference = bounded };
                    },
                    else => unreachable,
                }
                block_changed = true;
                changed = true;
            }
            if (block_changed) blocks[block_id].instructions = rewritten;
        }
    }

    if (!changed) return function;
    var result = function;
    result.blocks = blocks;
    return result;
}

fn sameStableLocalValue(function: Ir.Function, left: Ir.ValueId, right: Ir.ValueId) bool {
    if (left == right) return true;
    return matchingLocalLoad(function, left, right) != null;
}

fn matchingLocalLoad(function: Ir.Function, left: Ir.ValueId, right: Ir.ValueId) ?Ir.LocalId {
    const left_definition = findDefinition(function, left) orelse return null;
    const right_definition = findDefinition(function, right) orelse return null;
    if (left_definition.value != .local_load or right_definition.value != .local_load or
        left_definition.value.local_load.local != right_definition.value.local_load.local) return null;
    return left_definition.value.local_load.local;
}

fn resolveCollectionCount(
    allocator: Allocator,
    function: Ir.Function,
    value: Ir.ValueId,
    header: Ir.BlockId,
) !?Ir.ValueId {
    const definition = findDefinition(function, value) orelse return null;
    switch (definition.value) {
        .collection_count => |count| return count.collection,
        .local_load => |load| {
            var source: ?Ir.ValueId = null;
            var stores: usize = 0;
            for (function.blocks, 0..) |block, block_id| for (block.instructions) |instruction| {
                const store = switch (instruction) {
                    .local_store => |item| item,
                    else => continue,
                };
                if (store.local != load.local or
                    !(try reachesAvoiding(allocator, function.blocks, block_id, header, null))) continue;
                const stored_definition = findDefinition(function, store.operand) orelse return null;
                const count = switch (stored_definition.value) {
                    .collection_count => |item| item,
                    else => return null,
                };
                source = count.collection;
                stores += 1;
            };
            return if (stores == 1) source else null;
        },
        else => return null,
    }
}

fn naturalLoopBlocks(
    allocator: Allocator,
    blocks: []const Ir.Block,
    header: Ir.BlockId,
    body: Ir.BlockId,
) !?[]bool {
    const members = try allocator.alloc(bool, blocks.len);
    @memset(members, false);
    members[header] = true;
    var pending: std.ArrayList(Ir.BlockId) = .empty;
    for (blocks, 0..) |block, block_id| {
        if (!hasSuccessor(block.terminator, header)) continue;
        if (!(try reachesAvoiding(allocator, blocks, body, block_id, header))) continue;
        try pending.append(allocator, block_id);
    }
    if (pending.items.len == 0) return null;

    while (pending.pop()) |block_id| {
        if (members[block_id]) continue;
        members[block_id] = true;
        for (blocks, 0..) |predecessor, predecessor_id| {
            if (predecessor_id == header or members[predecessor_id] or
                !hasSuccessor(predecessor.terminator, block_id)) continue;
            if (try reachesAvoiding(allocator, blocks, body, predecessor_id, header)) {
                try pending.append(allocator, predecessor_id);
            }
        }
    }
    return members;
}

fn hasSuccessor(terminator: Ir.Terminator, target: Ir.BlockId) bool {
    return switch (terminator) {
        .jump => |next| next == target,
        .branch => |branch| branch.then_block == target or branch.else_block == target,
        else => false,
    };
}

fn provenZeroOriginInduction(
    allocator: Allocator,
    function: Ir.Function,
    loop_blocks: []const bool,
    header: Ir.BlockId,
    local: Ir.LocalId,
) !bool {
    var initialization_count: usize = 0;
    for (function.blocks, 0..) |block, block_id| for (block.instructions) |instruction| {
        const store = switch (instruction) {
            .local_store => |value| value,
            else => continue,
        };
        if (store.local != local) continue;
        if (loop_blocks[block_id]) {
            if (!isUnitIncrement(function, store.operand, local)) return false;
            continue;
        }
        if (!(try reachesAvoiding(allocator, function.blocks, block_id, header, null))) continue;
        const definition = findDefinition(function, store.operand) orelse return false;
        const constant = switch (definition.value) {
            .constant_int => |value| value,
            else => return false,
        };
        if (constant.bits != 0) return false;
        initialization_count += 1;
    };
    return initialization_count == 1;
}

fn isUnitIncrement(function: Ir.Function, value: Ir.ValueId, local: Ir.LocalId) bool {
    const definition = findDefinition(function, value) orelse return false;
    const binary = switch (definition.value) {
        .binary => |item| item,
        else => return false,
    };
    if (binary.operator != .add) return false;
    return (isLocalLoad(function, binary.left, local) and isIntegerConstant(function, binary.right, 1)) or
        (isLocalLoad(function, binary.right, local) and isIntegerConstant(function, binary.left, 1));
}

fn isLocalLoad(function: Ir.Function, value: Ir.ValueId, local: Ir.LocalId) bool {
    const definition = findDefinition(function, value) orelse return false;
    return switch (definition.value) {
        .local_load => |load| load.local == local,
        else => false,
    };
}

fn isIntegerConstant(function: Ir.Function, value: Ir.ValueId, bits: u64) bool {
    const definition = findDefinition(function, value) orelse return false;
    return switch (definition.value) {
        .constant_int => |constant| constant.bits == bits,
        else => false,
    };
}

fn incrementCanReachLoad(
    allocator: Allocator,
    function: Ir.Function,
    loop_blocks: []const bool,
    header: Ir.BlockId,
    local: Ir.LocalId,
    load_block: Ir.BlockId,
    load_instruction: usize,
) !bool {
    for (function.blocks, 0..) |block, block_id| {
        if (!loop_blocks[block_id]) continue;
        for (block.instructions, 0..) |instruction, instruction_index| {
            const store = switch (instruction) {
                .local_store => |value| value,
                else => continue,
            };
            if (store.local != local) continue;
            if (block_id == load_block) {
                if (instruction_index < load_instruction) return true;
                continue;
            }
            if (try reachesAvoiding(allocator, function.blocks, block_id, load_block, header)) return true;
        }
    }
    return false;
}

fn findDefinition(function: Ir.Function, value: Ir.ValueId) ?Definition {
    for (function.blocks, 0..) |block, block_id| for (block.instructions, 0..) |instruction, instruction_index| {
        if (instructionResult(instruction)) |result| if (result == value) return .{
            .block = block_id,
            .instruction = instruction_index,
            .value = instruction,
        };
    };
    return null;
}

fn instructionResult(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        .constant_int => |value| value.result,
        .collection_count => |value| value.result,
        .collection_load => |value| value.result,
        .local_load => |value| value.result,
        .binary => |value| value.result,
        else => null,
    };
}

fn reachesAvoiding(
    allocator: Allocator,
    blocks: []const Ir.Block,
    from: Ir.BlockId,
    target: Ir.BlockId,
    forbidden: ?Ir.BlockId,
) !bool {
    if (from == target) return true;
    const visited = try allocator.alloc(bool, blocks.len);
    @memset(visited, false);
    var pending: std.ArrayList(Ir.BlockId) = .empty;
    try pending.append(allocator, from);
    while (pending.pop()) |block| {
        if (forbidden != null and block == forbidden.?) continue;
        if (block == target) return true;
        if (visited[block]) continue;
        visited[block] = true;
        switch (blocks[block].terminator) {
            .jump => |next| try pending.append(allocator, next),
            .branch => |branch| {
                try pending.append(allocator, branch.then_block);
                try pending.append(allocator, branch.else_block);
            },
            else => {},
        }
    }
    return false;
}
