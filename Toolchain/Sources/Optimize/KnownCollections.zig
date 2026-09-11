const std = @import("std");
const Ir = @import("../Ir.zig");
const ValueOperands = @import("ValueOperands.zig");

// Element snapshots stay block-local; private literal lengths have a separate
// whole-function proof. No alias independence is inferred from readonly types:
// any unknown effect discards the element snapshots.
// Value identities stored in a snapshot must have exactly one definition.
pub fn optimize(allocator: std.mem.Allocator, program: Ir.Program, function: Ir.Function) !Ir.Function {
    var relevant = false;
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .collection_load or instruction == .collection_count or instruction == .collection_replace)
            relevant = true;
    };
    if (!relevant) return function;
    const definitions = try definitionCounts(allocator, function, function.blocks);
    const private_lengths = try privateLengths(allocator, program, function, definitions);
    defer allocator.free(private_lengths);
    const integers = try allocator.alloc(?i64, function.value_types.len);
    const collections = try allocator.alloc(?[]const Ir.ValueId, function.value_types.len);
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    for (blocks) |*block| {
        @memset(integers, null);
        @memset(collections, null);
        const instructions = try allocator.dupe(Ir.Instruction, block.instructions);
        for (instructions) |*instruction| {
            if (resultOf(instruction.*)) |result| {
                if (definitions[result] != 1) {
                    // Edge-transfer destinations may be overwritten. Do not
                    // retain snapshots or indices derived from their old value.
                    @memset(integers, null);
                    @memset(collections, null);
                    continue;
                }
            }
            switch (instruction.*) {
                .constant_int => |value| {
                    if (function.value_types[value.result] == .int)
                        integers[value.result] = @bitCast(value.bits);
                },
                .copy, .deep_copy => |copy| {
                    if (function.value_types[copy.result] == function.value_types[copy.operand]) {
                        integers[copy.result] = integers[copy.operand];
                        collections[copy.result] = collections[copy.operand];
                    }
                },
                .binary => |binary| {
                    if (function.value_types[binary.result] != .int) continue;
                    const left = integers[binary.left] orelse continue;
                    const right = integers[binary.right] orelse continue;
                    integers[binary.result] = switch (binary.operator) {
                        .add => std.math.add(i64, left, right) catch null,
                        .subtract => std.math.sub(i64, left, right) catch null,
                        else => null,
                    };
                },
                .list_init => |list| {
                    if (!scalarCollection(program, function.value_types[list.result])) continue;
                    var stable = true;
                    for (list.values) |value| {
                        if (definitions[value] != 1) stable = false;
                    }
                    if (stable) collections[list.result] = list.values;
                },
                .collection_count => |count| {
                    const size = private_lengths[count.collection] orelse
                        knownLength(program, function.value_types[count.collection], collections[count.collection]) orelse continue;
                    const length = std.math.cast(i64, size) orelse continue;
                    integers[count.result] = length;
                    instruction.* = .{ .constant_int = .{ .result = count.result, .bits = @intCast(length) } };
                },
                .collection_view, .collection_slice => |slice| {
                    // A reference can identify newer storage than the descriptor.
                    if (slice.reference != null) continue;
                    const values = collections[slice.collection] orelse continue;
                    const start = sliceBound(integers[slice.start] orelse continue, values.len);
                    const end = sliceBound(integers[slice.end] orelse continue, values.len);
                    collections[slice.result] = values[start..@max(start, end)];
                },
                .collection_load => |load| {
                    const values = collections[load.collection] orelse continue;
                    const index = normalizedIndex(integers[load.index] orelse continue, values.len) orelse continue;
                    const element = values[index];
                    if (function.value_types[load.result] != function.value_types[element]) continue;
                    integers[load.result] = integers[element];
                    instruction.* = .{ .copy = .{ .result = load.result, .operand = element } };
                },
                .collection_replace => |replacement| {
                    const previous = collections[replacement.collection];
                    const structure = function.value_types[replacement.collection].structureIndex() orelse continue;
                    const collection = program.structures[structure].collection orelse continue;
                    // Owning replacement is a value operation (copy-on-write).
                    // A view update instead invalidates every possible alias.
                    if (collection.view or !scalarCollection(program, function.value_types[replacement.collection])) {
                        @memset(collections, null);
                        continue;
                    }
                    const length = knownLength(program, function.value_types[replacement.collection], previous) orelse continue;
                    const index = normalizedIndex(integers[replacement.index] orelse continue, length) orelse continue;
                    instruction.collection_replace.checked = false;
                    const values = previous orelse continue;
                    if (definitions[replacement.replacement] != 1) continue;
                    const updated = try allocator.dupe(Ir.ValueId, values);
                    updated[index] = replacement.replacement;
                    collections[replacement.result] = updated;
                },
                .constant_bool,
                .constant_float32,
                .constant_float64,
                .unary,
                .convert,
                .print,
                .list_retain,
                // These only observe or derive addresses, never mutate storage.
                .collection_reference,
                .reference_field,
                .reference_load,
                .field_load,
                => {},
                else => @memset(collections, null),
            }
        }
        block.instructions = instructions;
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

// A literal's length is valid across blocks only when every use is a direct
// observation or reference-count operation. Copies, views, addresses, stores,
// edits, calls and returns of the collection reject this proof. A drop is
// admitted only as the final use in a returning block, so folding cannot hide
// a later access to dead storage. No readonly-type alias assumption is used.
fn privateLengths(allocator: std.mem.Allocator, program: Ir.Program, function: Ir.Function, definitions: []const usize) ![]?usize {
    const lengths = try allocator.alloc(?usize, function.value_types.len);
    errdefer allocator.free(lengths);
    @memset(lengths, null);
    const uses = try allocator.alloc(usize, function.value_types.len);
    defer allocator.free(uses);
    const observations = try allocator.alloc(usize, function.value_types.len);
    defer allocator.free(observations);
    const suffix = try allocator.alloc(usize, function.value_types.len);
    defer allocator.free(suffix);
    @memset(uses, 0);
    @memset(observations, 0);
    for (function.blocks) |block| {
        @memset(suffix, 0);
        ValueOperands.countTerminatorUses(block.terminator, uses);
        ValueOperands.countTerminatorUses(block.terminator, suffix);
        var reverse = block.instructions.len;
        while (reverse != 0) {
            reverse -= 1;
            const instruction = block.instructions[reverse];
            switch (instruction) {
                .collection_count => |value| observations[value.collection] += 1,
                .collection_load => |value| observations[value.collection] += 1,
                .list_retain => |value| observations[value.operand] += 1,
                .list_drop => |value| {
                    const returning = block.terminator == .return_value or block.terminator == .return_void;
                    if (returning and suffix[value.operand] == 0) observations[value.operand] += 1;
                },
                else => {},
            }
            ValueOperands.countUses(instruction, uses);
            ValueOperands.countUses(instruction, suffix);
        }
    }
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction != .list_init) continue;
        const list = instruction.list_init;
        if (definitions[list.result] != 1 or uses[list.result] != observations[list.result] or
            !scalarCollection(program, function.value_types[list.result])) continue;
        lengths[list.result] = list.values.len;
    };
    return lengths;
}

// Once every data use has disappeared, scalar list storage has no observable
// identity or destructor. Initializer computations remain separate IR effects.
// Do not generalize this to aggregates, references, escapes or mutable homes.
pub fn deadStorage(
    allocator: std.mem.Allocator,
    function: Ir.Function,
    blocks: []const Ir.Block,
    uses: []const usize,
) !?[]bool {
    var present = false;
    for (blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .list_init) present = true;
    };
    if (!present) return null;
    const observed = try allocator.dupe(usize, uses);
    for (blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .list_retain, .list_drop => |resource| observed[resource.operand] -= 1,
        else => {},
    };
    const definitions = try definitionCounts(allocator, function, blocks);
    const dead = try allocator.alloc(bool, uses.len);
    @memset(dead, false);
    for (blocks) |block| for (block.instructions) |instruction| {
        if (instruction != .list_init) continue;
        const list = instruction.list_init;
        if (definitions[list.result] != 1 or observed[list.result] != 0 or list.values.len == 0) continue;
        var scalar = true;
        for (list.values) |value| {
            const type_value = function.value_types[value];
            if (!type_value.isInteger() and !type_value.isFloat() and type_value != .bool) scalar = false;
        }
        dead[list.result] = scalar;
    };
    return dead;
}

fn definitionCounts(allocator: std.mem.Allocator, function: Ir.Function, blocks: []const Ir.Block) ![]usize {
    const definitions = try allocator.alloc(usize, function.value_types.len);
    @memset(definitions, 0);
    for (0..function.parameter_types.len + function.capture_types.len) |value| definitions[value] += 1;
    for (blocks) |block| for (block.instructions) |instruction| {
        if (resultOf(instruction)) |value| definitions[value] += 1;
        if (instruction == .list_edit) {
            if (instruction.list_edit.removed) |value| definitions[value] += 1;
        }
    };
    return definitions;
}

fn scalarCollection(program: Ir.Program, type_value: Ir.Type) bool {
    const index = type_value.structureIndex() orelse return false;
    const collection = program.structures[index].collection orelse return false;
    return collection.element.isInteger() or collection.element.isFloat() or collection.element == .bool;
}

fn knownLength(program: Ir.Program, type_value: Ir.Type, elements: ?[]const Ir.ValueId) ?usize {
    if (elements) |values| return values.len;
    const index = type_value.structureIndex() orelse return null;
    const collection = program.structures[index].collection orelse return null;
    return collection.length;
}

fn sliceBound(value: i64, length: usize) usize {
    const count: i128 = @intCast(length);
    const adjusted = if (value < 0) @as(i128, value) + count else value;
    return @intCast(std.math.clamp(adjusted, 0, count));
}

fn normalizedIndex(value: i64, length: usize) ?usize {
    const count: i128 = @intCast(length);
    const adjusted = if (value < 0) @as(i128, value) + count else value;
    if (adjusted < 0 or adjusted >= count) return null;
    return @intCast(adjusted);
}

fn resultOf(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        .class_retain,
        .class_drop,
        .list_retain,
        .list_drop,
        .string_retain,
        .string_drop,
        .global_store,
        .local_store,
        .address_store,
        .reference_store,
        .print,
        .assert,
        .mutex_lock,
        .mutex_unlock,
        => null,
        inline .call, .indirect_call, .boundary_call, .boundary_indirect_call, .dynamic_call => |call| call.result,
        inline else => |value| value.result,
    };
}
