const std = @import("std");
const Ir = @import("../Ir.zig");

// Capture projected scalars at the original snapshot instruction. Moving a
// read to its projection would observe intervening writes through aliases.
// Escaping aggregates and owning collections keep their ordinary value copy.
pub fn optimize(allocator: std.mem.Allocator, program: Ir.Program, function: Ir.Function, definitions: []const usize, uses: []const usize) !Ir.Function {
    const count = function.value_types.len;
    const roots = try allocator.alloc(?Ir.ValueId, count);
    defer allocator.free(roots);
    @memset(roots, null);
    for (function.blocks) |block| for (block.instructions) |instruction| {
        const result: Ir.ValueId = switch (instruction) {
            .reference_load => |load| load.result,
            .collection_load => |load| view: {
                // Proven bounded loads already have a cheaper native path,
                // including SIMD seeds. A collection reference would add a
                // check again and lose that representation on X64.
                if (!load.checked) continue;
                const owner = function.value_types[load.collection].structureIndex() orelse continue;
                const collection = program.structures[owner].collection orelse continue;
                if (!collection.view) continue;
                break :view load.result;
            },
            else => continue,
        };
        const structure = function.value_types[result].structureIndex() orelse continue;
        if (definitions[result] == 1 and plainStructure(program, structure)) roots[result] = result;
    };
    var changed = true;
    while (changed) {
        changed = false;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .copy, .deep_copy => |copy| if (definitions[copy.result] == 1 and roots[copy.result] == null and roots[copy.operand] != null and
                function.value_types[copy.result] == function.value_types[copy.operand])
            {
                roots[copy.result] = roots[copy.operand];
                changed = true;
            },
            else => {},
        };
    }
    const allowed = try allocator.alloc(usize, count);
    defer allocator.free(allowed);
    @memset(allowed, 0);
    const escaped = try allocator.alloc(bool, count);
    defer allocator.free(escaped);
    @memset(escaped, false);
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .copy, .deep_copy => |copy| if (roots[copy.operand] != null and roots[copy.result] == roots[copy.operand]) {
            allowed[copy.operand] += 1;
        },
        .field_load => |load| if (roots[load.base] != null) {
            allowed[load.base] += 1;
        },
        else => {},
    };
    for (roots, 0..) |root, value| if (root) |resolved| {
        if (uses[value] != allowed[value]) escaped[resolved] = true;
    };
    const fields = try allocator.alloc(?[]?Ir.ValueId, count);
    defer allocator.free(fields);
    @memset(fields, null);
    var types: std.ArrayList(Ir.Type) = .empty;
    try types.appendSlice(allocator, function.value_types);
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .field_load => |load| if (roots[load.base]) |root| {
            if (escaped[root] or uses[load.result] == 0) continue;
            const structure = program.structures[function.value_types[root].structureIndex().?];
            if (fields[root] == null) {
                fields[root] = try allocator.alloc(?Ir.ValueId, structure.fields.len);
                @memset(fields[root].?, null);
            }
            if (fields[root].?[load.field] == null) {
                fields[root].?[load.field] = try newValue(allocator, &types, structure.fields[load.field].type);
            }
        },
        else => {},
    };
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |instruction| {
            switch (instruction) {
                .reference_load, .collection_load => {
                    const root = if (instruction == .reference_load) instruction.reference_load.result else instruction.collection_load.result;
                    // Keep unused snapshots: a checked view read can fail even
                    // when none of its fields contributes to the result.
                    if (fields[root]) |projections| {
                        const structure = function.value_types[root].structureIndex().?;
                        const reference = if (instruction == .reference_load) instruction.reference_load.reference else ref: {
                            const load = instruction.collection_load;
                            const address = try newValue(allocator, &types, .address);
                            try instructions.append(allocator, .{ .collection_reference = .{
                                .result = address,
                                .collection = load.collection,
                                .reference = null,
                                .index = load.index,
                                .position = load.position,
                            } });
                            break :ref address;
                        };
                        for (projections, 0..) |projection, field| if (projection) |value| {
                            const address = try newValue(allocator, &types, .address);
                            try instructions.append(allocator, .{ .reference_field = .{
                                .result = address,
                                .reference = reference,
                                .structure = structure,
                                .field = field,
                            } });
                            try instructions.append(allocator, .{ .reference_load = .{ .result = value, .reference = address } });
                        };
                        continue;
                    }
                },
                .copy, .deep_copy => |copy| if (roots[copy.result]) |root| {
                    if (fields[root] != null) continue;
                },
                .field_load => |load| if (roots[load.base]) |root| {
                    if (!escaped[root] and uses[load.result] == 0) continue;
                    if (fields[root]) |projections| {
                        try instructions.append(allocator, .{ .copy = .{ .result = load.result, .operand = projections[load.field].? } });
                        continue;
                    }
                },
                else => {},
            }
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{ .instructions = try instructions.toOwnedSlice(allocator), .terminator = block.terminator };
    }
    var result = function;
    result.blocks = blocks;
    result.value_types = try types.toOwnedSlice(allocator);
    return result;
}

fn plainStructure(program: Ir.Program, index: usize) bool {
    const structure = program.structures[index];
    if (structure.is_class or structure.is_static or structure.is_protocol or structure.collection != null) return false;
    for (structure.fields) |field| if (!field.type.isNumeric() and field.type != .bool) return false;
    return true;
}

fn newValue(allocator: std.mem.Allocator, types: *std.ArrayList(Ir.Type), value_type: Ir.Type) !Ir.ValueId {
    const result = types.items.len;
    try types.append(allocator, value_type);
    return result;
}
