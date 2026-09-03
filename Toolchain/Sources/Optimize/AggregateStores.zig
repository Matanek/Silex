const std = @import("std");
const Ir = @import("../Ir.zig");

const Definition = struct { instruction: Ir.Instruction, epoch: usize };
const Target = union(enum) {
    reference: Ir.ValueId,
    view: Ir.Instruction.CollectionReplace,
};

// A reconstructed value may contain unchanged fields from a snapshot of its
// destination. Omit their writes only while that snapshot is still current.
// An unknown effect or a block boundary invalidates the proof. This is not
// store forwarding across aliases, nor an optimization of owning collections.
pub fn optimize(allocator: std.mem.Allocator, program: Ir.Program, function: Ir.Function) !Ir.Function {
    const counts = try allocator.alloc(usize, function.value_types.len);
    defer allocator.free(counts);
    @memset(counts, 0);
    for (0..function.parameter_types.len + function.capture_types.len) |id| counts[id] = 1;
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (resultOf(instruction)) |id| counts[id] += 1;
        if (instruction == .list_edit) if (instruction.list_edit.removed) |id| {
            counts[id] += 1;
        };
    };
    const definitions = try allocator.alloc(?Definition, counts.len);
    defer allocator.free(definitions);
    var types: std.ArrayList(Ir.Type) = .empty;
    try types.appendSlice(allocator, function.value_types);
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    var changed = false;
    for (function.blocks, 0..) |block, block_index| {
        @memset(definitions, null);
        var epoch: usize = 0;
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |instruction| {
            const target: ?Target = switch (instruction) {
                .reference_store => |store| .{ .reference = store.reference },
                .collection_replace => |store| view: {
                    const owner = function.value_types[store.collection].structureIndex() orelse break :view null;
                    const collection = program.structures[owner].collection orelse break :view null;
                    break :view if (collection.view) .{ .view = store } else null;
                },
                else => null,
            };
            var replaced = false;
            if (target) |destination| {
                const operand = switch (instruction) {
                    .reference_store => |store| store.operand,
                    .collection_replace => |store| store.replacement,
                    else => unreachable,
                };
                const context: Context = .{ .definitions = definitions, .counts = counts, .types = function.value_types, .epoch = epoch };
                if (context.definition(operand)) |definition| {
                    if (definition.instruction == .structure_init) {
                        const value = definition.instruction.structure_init;
                        if (plainStructure(program, value.structure)) {
                            var retained: usize = 0;
                            for (value.fields, 0..) |field, index| {
                                if (context.matches(field, value.structure, index, destination)) retained += 1;
                            }
                            if (retained > 0) {
                                const reference = switch (destination) {
                                    .reference => |id| id,
                                    .view => |store| ref: {
                                        const id = try newAddress(allocator, &types);
                                        try instructions.append(allocator, .{ .collection_reference = .{
                                            .result = id,
                                            .collection = store.collection,
                                            .reference = null,
                                            .index = store.index,
                                            .ownership = store.ownership,
                                            .position = store.position,
                                        } });
                                        break :ref id;
                                    },
                                };
                                for (value.fields, 0..) |field, index| {
                                    if (context.matches(field, value.structure, index, destination)) continue;
                                    const address = try newAddress(allocator, &types);
                                    try instructions.append(allocator, .{ .reference_field = .{
                                        .result = address,
                                        .reference = reference,
                                        .structure = value.structure,
                                        .field = index,
                                    } });
                                    try instructions.append(allocator, .{ .reference_store = .{
                                        .reference = address,
                                        .operand = field,
                                    } });
                                }
                                if (destination == .view) {
                                    try instructions.append(allocator, .{ .copy = .{
                                        .result = destination.view.result,
                                        .operand = destination.view.collection,
                                    } });
                                }
                                replaced = true;
                                changed = true;
                            }
                        }
                    }
                }
            }
            if (!replaced) try instructions.append(allocator, instruction);
            if (!readOrPure(instruction, program)) epoch += 1;
            if (resultOf(instruction)) |id| {
                if (counts[id] == 1) definitions[id] = .{ .instruction = instruction, .epoch = epoch };
            }
        }
        blocks[block_index] = .{ .instructions = try instructions.toOwnedSlice(allocator), .terminator = block.terminator };
    }
    if (!changed) return function;
    var result = function;
    result.blocks = blocks;
    result.value_types = try types.toOwnedSlice(allocator);
    return result;
}

const Context = struct {
    definitions: []const ?Definition,
    counts: []const usize,
    types: []const Ir.Type,
    epoch: usize,

    fn origin(self: Context, value: Ir.ValueId) Ir.ValueId {
        var current = value;
        var remaining = self.definitions.len;
        while (remaining > 0) : (remaining -= 1) {
            const node = self.definitionExact(current) orelse return current;
            if (node.instruction != .copy) return current;
            current = node.instruction.copy.operand;
        }
        return value;
    }

    fn definitionExact(self: Context, value: Ir.ValueId) ?Definition {
        if (value >= self.counts.len or self.counts[value] != 1) return null;
        return self.definitions[value];
    }

    fn definition(self: Context, value: Ir.ValueId) ?Definition {
        return self.definitionExact(self.origin(value));
    }

    fn same(self: Context, left: Ir.ValueId, right: Ir.ValueId) bool {
        const a = self.origin(left);
        const b = self.origin(right);
        return a == b and self.counts[a] == 1;
    }

    fn matches(self: Context, value: Ir.ValueId, structure: usize, field: usize, destination: Target) bool {
        const projection = self.definition(value) orelse return false;
        if (projection.instruction != .field_load) return false;
        const load = projection.instruction.field_load;
        if (load.field != field) return false;
        if (self.types[load.base] != Ir.Type.structure(structure)) return false;
        const snapshot = self.definition(load.base) orelse return false;
        if (snapshot.epoch != self.epoch) return false;
        return switch (destination) {
            .reference => |reference| snapshot.instruction == .reference_load and
                self.same(snapshot.instruction.reference_load.reference, reference),
            .view => |store| snapshot.instruction == .collection_load and
                self.same(snapshot.instruction.collection_load.collection, store.collection) and
                self.same(snapshot.instruction.collection_load.index, store.index),
        };
    }
};

fn plainStructure(program: Ir.Program, index: usize) bool {
    if (index >= program.structures.len) return false;
    const structure = program.structures[index];
    if (structure.is_class or structure.is_static or structure.is_protocol or structure.collection != null) return false;
    for (structure.fields) |field| if (!field.type.isNumeric() and field.type != .bool) return false;
    return true;
}

fn readOrPure(instruction: Ir.Instruction, program: Ir.Program) bool {
    return switch (instruction) {
        .constant_int, .constant_bool, .constant_float32, .constant_float64, .copy, .local_load, .local_address, .reference_load, .reference_field, .collection_load, .collection_count, .field_load, .unary, .binary, .convert => true,
        .structure_init => |value| plainStructure(program, value.structure),
        else => false,
    };
}

fn newAddress(allocator: std.mem.Allocator, types: *std.ArrayList(Ir.Type)) !Ir.ValueId {
    const result = types.items.len;
    try types.append(allocator, .address);
    return result;
}

fn resultOf(instruction: Ir.Instruction) ?Ir.ValueId {
    switch (instruction) {
        inline else => |value| {
            if (@typeInfo(@TypeOf(value)) != .@"struct" or !@hasField(@TypeOf(value), "result")) return null;
            return value.result;
        },
    }
}
