const std = @import("std");
const Ir = @import("../Ir.zig");
const Operands = @import("ValueOperands.zig");

// A snapshot immediately before a pure branch is also a snapshot at the entry
// of either exclusive arm. Separate definitions prevent a cold arm's calls
// from forcing the other arm's scalar values to retain stack homes. Keep the
// checked address in the predecessor and execute every read, in order, before
// the first original arm instruction. In particular, never defer a read past
// a possible alias write merely because its projection occurs later.
pub fn optimize(allocator: std.mem.Allocator, program: Ir.Program) !Ir.Program {
    var result = program;
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| functions[index] = try optimizeFunction(allocator, function);
    result.functions = functions;
    return result;
}

fn optimizeFunction(allocator: std.mem.Allocator, function: Ir.Function) !Ir.Function {
    const predecessors = try allocator.alloc(usize, function.blocks.len);
    defer allocator.free(predecessors);
    @memset(predecessors, 0);
    if (predecessors.len != 0) predecessors[0] = 1; // Entry is also an incoming path.
    for (function.blocks) |block| switch (block.terminator) {
        .jump => |target| predecessors[target] += 1,
        .branch => |branch| {
            predecessors[branch.then_block] += 1;
            predecessors[branch.else_block] += 1;
        },
        else => {},
    };
    var result = function;
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    var types: std.ArrayList(Ir.Type) = .empty;
    try types.appendSlice(allocator, function.value_types);
    for (blocks, 0..) |block, source| {
        if (block.terminator != .branch) continue;
        const branch = block.terminator.branch;
        if (branch.then_block == source or branch.else_block == source or branch.then_block == branch.else_block or
            predecessors[branch.then_block] != 1 or predecessors[branch.else_block] != 1) continue;
        var start = block.instructions.len;
        while (start > 0 and snapshotInstruction(types.items, block.instructions[start - 1])) start -= 1;
        const suffix = block.instructions[start..];
        // Bound static expansion independently of a benchmark's field count.
        if (suffix.len == 0 or suffix.len > 128) continue;
        const definitions = try allocator.alloc(usize, types.items.len);
        defer allocator.free(definitions);
        @memset(definitions, 0);
        for (0..function.parameter_types.len + function.capture_types.len) |value| definitions[value] += 1;
        const outside = try allocator.alloc(usize, types.items.len);
        defer allocator.free(outside);
        @memset(outside, 0);
        for (blocks, 0..) |other, index| {
            for (other.instructions, 0..) |instruction, offset| {
                if (Operands.instructionResult(instruction)) |value| definitions[value] += 1;
                if (instruction == .list_edit) if (instruction.list_edit.removed) |value| {
                    definitions[value] += 1;
                };
                if (index == branch.then_block or index == branch.else_block or (index == source and offset >= start)) continue;
                Operands.countUses(instruction, outside);
            }
            if (index != branch.then_block and index != branch.else_block) Operands.countTerminatorUses(other.terminator, outside);
        }
        var eligible = true;
        var loads: usize = 0;
        for (suffix) |instruction| {
            const value = Operands.instructionResult(instruction).?;
            if (definitions[value] != 1 or outside[value] != 0) eligible = false;
            loads += @intFromBool(instruction == .reference_load);
        }
        if (!eligible or loads == 0) continue;
        for ([_]Ir.BlockId{ branch.then_block, branch.else_block }) |target| {
            // Allocate both arms independently; mappings use the current value
            // count so canonical() can follow the fresh identity entries.
            const remap = try allocator.alloc(Ir.ValueId, types.items.len + suffix.len);
            defer allocator.free(remap);
            for (remap, 0..) |*alias, value| alias.* = value;
            for (suffix) |instruction| {
                const old = Operands.instructionResult(instruction).?;
                remap[old] = types.items.len;
                try types.append(allocator, types.items[old]);
            }
            var instructions: std.ArrayList(Ir.Instruction) = .empty;
            for (suffix) |instruction| {
                var copy = try Operands.rewriteInstruction(allocator, instruction, remap);
                switch (copy) {
                    .reference_field => |*value| value.result = remap[value.result],
                    .reference_load => |*value| value.result = remap[value.result],
                    else => unreachable,
                }
                try instructions.append(allocator, copy);
            }
            for (blocks[target].instructions) |instruction| try instructions.append(allocator, try Operands.rewriteInstruction(allocator, instruction, remap));
            blocks[target] = .{
                .instructions = try instructions.toOwnedSlice(allocator),
                .terminator = remapTerminator(blocks[target].terminator, remap),
            };
        }
        blocks[source].instructions = block.instructions[0..start];
    }
    result.blocks = blocks;
    result.value_types = try types.toOwnedSlice(allocator);
    return result;
}

fn snapshotInstruction(types: []const Ir.Type, instruction: Ir.Instruction) bool {
    return switch (instruction) {
        .reference_field => true,
        .reference_load => |value| types[value.result].isNumeric() or types[value.result] == .bool,
        else => false,
    };
}

fn remapTerminator(terminator: Ir.Terminator, aliases: []const Ir.ValueId) Ir.Terminator {
    var result = terminator;
    switch (result) {
        .return_value => |*value| value.* = aliases[value.*],
        .branch => |*value| value.condition = aliases[value.condition],
        .panic => |*value| value.message = aliases[value.message],
        else => {},
    }
    return result;
}
