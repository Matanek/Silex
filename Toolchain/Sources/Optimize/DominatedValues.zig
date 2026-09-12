const std = @import("std");
const Ir = @import("../Ir.zig");

const Key = struct {
    kind: enum { binary, field, reference_field },
    type: Ir.Type,
    left: Ir.ValueId,
    right: usize,
    structure: usize = 0,
    operator: Ir.BinaryOperator = .add,
    checked: bool = false,
    left_non_negative: bool = false,
};
const Location = struct { block: usize, value: Ir.ValueId };

// This bounded global value numbering accepts only functions without calls,
// writes to addressable values, local address formation or resource operations.
// Ordered scalar output does not mutate those values. Aggregate reads
// must project a stable value parameter, never a class, collection or local
// home. Scalar reference reads may project a stable address parameter in this
// same read-only region. A replacement stays below a dominating evaluation.
pub fn optimize(allocator: std.mem.Allocator, program: Ir.Program, function: Ir.Function) !Ir.Function {
    if (function.blocks.len < 2) return function;
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (!readOnly(program, function, instruction)) return function;
    };
    const definitions = try allocator.alloc(usize, function.value_types.len);
    @memset(definitions, 0);
    const projections = try allocator.alloc(?Ir.Instruction.ReferenceField, function.value_types.len);
    @memset(projections, null);
    const parameter_count = function.parameter_types.len + function.capture_types.len;
    for (0..parameter_count) |value| definitions[value] += 1;
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .reference_field) projections[instruction.reference_field.result] = instruction.reference_field;
        if (instruction == .local_store) {
            definitions[instruction.local_store.local] += 1;
        } else {
            const result: ?Ir.ValueId = switch (instruction) {
                inline else => |value| if (@TypeOf(value) == void) null else if (@hasField(@TypeOf(value), "result")) value.result else null,
            };
            if (result) |value| definitions[value] += 1;
        }
    };
    const domination = try dominators(allocator, function.blocks);
    const count = function.blocks.len;
    const order = try allocator.alloc(usize, count);
    const depth = try allocator.alloc(usize, count);
    for (order, depth, 0..) |*block, *level, index| {
        block.* = index;
        level.* = 0;
        for (domination[index * count ..][0..count]) |dominates| level.* += @intFromBool(dominates);
    }
    std.mem.sort(usize, order, depth, struct {
        fn less(levels: []usize, left: usize, right: usize) bool {
            return levels[left] < levels[right] or (levels[left] == levels[right] and left < right);
        }
    }.less);
    const roots = try allocator.alloc(Ir.ValueId, function.value_types.len);
    for (roots, 0..) |*root, value| root.* = value;
    var available = std.AutoHashMap(Key, std.ArrayList(Location)).init(allocator);
    defer {
        var entries = available.valueIterator();
        while (entries.next()) |locations| locations.deinit(allocator);
        available.deinit();
    }
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    for (order) |block_index| {
        if (depth[block_index] == 0) continue;
        const instructions = try allocator.dupe(Ir.Instruction, blocks[block_index].instructions);
        for (instructions) |*instruction| {
            if (instruction.* == .copy or instruction.* == .deep_copy) {
                const copy = if (instruction.* == .copy) instruction.copy else instruction.deep_copy;
                if (definitions[copy.result] == 1 and definitions[copy.operand] == 1 and
                    scalar(function.value_types[copy.result]) and
                    function.value_types[copy.result] == function.value_types[copy.operand])
                    roots[copy.result] = roots[copy.operand];
                continue;
            }
            const result: Ir.ValueId = switch (instruction.*) {
                .binary => |value| value.result,
                .field_load => |value| value.result,
                .reference_load => |value| value.result,
                else => continue,
            };
            if (definitions[result] != 1 or !scalar(function.value_types[result])) continue;
            const key: Key = switch (instruction.*) {
                .binary => |binary| blk: {
                    if (definitions[binary.left] != 1 or definitions[binary.right] != 1 or
                        !scalar(function.value_types[binary.left]) or !scalar(function.value_types[binary.right])) continue;
                    break :blk .{ .kind = .binary, .type = function.value_types[result], .left = roots[binary.left], .right = roots[binary.right], .operator = binary.operator, .checked = binary.checked, .left_non_negative = binary.left_non_negative };
                },
                .field_load => |load| blk: {
                    if (load.base >= parameter_count or definitions[load.base] != 1) continue;
                    const structure = function.value_types[load.base].structureIndex() orelse continue;
                    if (structure >= program.structures.len or program.structures[structure].is_class or
                        program.structures[structure].is_static or program.structures[structure].collection != null) continue;
                    break :blk .{ .kind = .field, .type = function.value_types[result], .left = load.base, .right = load.field };
                },
                .reference_load => |load| blk: {
                    if (definitions[load.reference] != 1) continue;
                    const field = projections[load.reference] orelse continue;
                    if (field.reference >= parameter_count or definitions[field.reference] != 1 or
                        function.value_types[field.reference] != .address or
                        field.structure >= program.structures.len) continue;
                    const structure = program.structures[field.structure];
                    if (structure.is_class or structure.is_static or structure.collection != null or
                        field.field >= structure.fields.len or structure.fields[field.field].type != function.value_types[result]) continue;
                    break :blk .{ .kind = .reference_field, .type = function.value_types[result], .left = field.reference, .right = field.field, .structure = field.structure };
                },
                else => unreachable,
            };
            const entry = try available.getOrPut(key);
            if (!entry.found_existing) entry.value_ptr.* = .empty;
            var previous: ?Ir.ValueId = null;
            for (entry.value_ptr.items) |location| {
                if (domination[block_index * count + location.block]) {
                    previous = location.value;
                    break;
                }
            }
            if (previous) |value| {
                roots[result] = value;
                instruction.* = .{ .copy = .{ .result = result, .operand = value } };
            } else try entry.value_ptr.append(allocator, .{ .block = block_index, .value = result });
        }
        blocks[block_index].instructions = instructions;
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn scalar(value: Ir.Type) bool {
    return value.isNumeric() or value == .bool;
}

fn readOnly(program: Ir.Program, function: Ir.Function, instruction: Ir.Instruction) bool {
    return switch (instruction) {
        .print => |output| scalar(function.value_types[output.value]),
        .structure_init => |value| value.structure < program.structures.len and
            !program.structures[value.structure].is_class and program.structures[value.structure].collection == null,
        .deep_copy => |copy| scalar(function.value_types[copy.result]) and
            function.value_types[copy.result] == function.value_types[copy.operand],
        .reference_field => true,
        .reference_load => |load| scalar(function.value_types[load.result]),
        .constant_int, .constant_bool, .constant_float32, .constant_float64, .copy, .local_load, .local_store, .field_load, .unary, .binary, .convert => true,
        else => false,
    };
}

// Removing a node disconnects exactly the reachable blocks it dominates.
// This independently computed relation also handles shuffled block order,
// backedges and unreachable predecessors without assuming a linear CFG.
fn dominators(allocator: std.mem.Allocator, blocks: []const Ir.Block) ![]bool {
    const count = blocks.len;
    const result = try allocator.alloc(bool, count * count);
    @memset(result, false);
    const reachable = try allocator.alloc(bool, count);
    const avoiding = try allocator.alloc(bool, count);
    const pending = try allocator.alloc(usize, count);
    walk(blocks, null, reachable, pending);
    for (0..count) |candidate| {
        if (!reachable[candidate]) continue;
        walk(blocks, candidate, avoiding, pending);
        for (0..count) |block| result[block * count + candidate] = reachable[block] and !avoiding[block];
    }
    return result;
}

fn walk(blocks: []const Ir.Block, excluded: ?usize, visited: []bool, pending: []usize) void {
    @memset(visited, false);
    if (excluded == 0) return;
    visited[0] = true;
    pending[0] = 0;
    var length: usize = 1;
    while (length != 0) {
        length -= 1;
        const block = blocks[pending[length]];
        const targets: [2]?usize = switch (block.terminator) {
            .jump => |target| .{ target, null },
            .branch => |branch| .{ branch.then_block, branch.else_block },
            else => .{ null, null },
        };
        for (targets) |optional| if (optional) |target| {
            if (excluded == target or visited[target]) continue;
            visited[target] = true;
            pending[length] = target;
            length += 1;
        };
    }
}
