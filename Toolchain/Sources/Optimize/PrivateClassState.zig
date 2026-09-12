const std = @import("std");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");
const Operands = @import("ValueOperands.zig");
const Allocator = std.mem.Allocator;

// Cache scalar fields in ordinary locals while writing through to the original
// object. Allocation, stores, reference counts and destruction stay in place.
// The existing SSA pass decides how to transport these locals across the CFG.
pub fn optimize(allocator: Allocator, program: Ir.Program, original: Ir.Function) !Ir.Function {
    if (original.blocks.len < 2) return original;
    // An entry allocation must execute once, before every cached observation.
    for (original.blocks) |block| switch (block.terminator) {
        .jump => |target| if (target == 0) return original,
        .branch => |branch| if (branch.then_block == 0 or branch.else_block == 0) return original,
        else => {},
    };
    var function = original;
    for (original.blocks[0].instructions) |instruction| {
        if (instruction != .structure_init) continue;
        const init = instruction.structure_init;
        const structure = program.structures[init.structure];
        if (!structure.is_class or structure.base != null or structure.fields.len == 0) continue;
        var scalar = true;
        for (structure.fields) |field| if (!field.type.isNumeric() and field.type != .bool) {
            scalar = false;
        };
        if (!scalar) continue;
        function = try cacheObject(allocator, function, init);
    }
    return function;
}

fn resultOf(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        inline else => |value| if (@TypeOf(value) != void and @hasField(@TypeOf(value), "result")) value.result else null,
    };
}

fn mark(values: []bool, index: usize, changed: *bool) void {
    if (!values[index]) {
        values[index] = true;
        changed.* = true;
    }
}

fn cacheObject(allocator: Allocator, function: Ir.Function, init: Ir.Instruction.StructureInit) !Ir.Function {
    const aliases = try allocator.alloc(bool, function.value_types.len);
    defer allocator.free(aliases);
    const locals = try allocator.alloc(bool, function.local_types.len);
    defer allocator.free(locals);
    @memset(aliases, false);
    @memset(locals, false);
    aliases[init.result] = true;
    // This is a may-alias closure. Admission below rejects mixed definitions,
    // other instances stored into a home, address-taking and every escape.
    var changed = true;
    while (changed) {
        changed = false;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .copy => |copy| if (aliases[copy.operand]) mark(aliases, copy.result, &changed),
            .field_store => |store| if (aliases[store.base]) mark(aliases, store.result, &changed),
            .local_store => |store| if (aliases[store.operand]) mark(locals, store.local, &changed),
            .local_load => |load| if (locals[load.local]) mark(aliases, load.result, &changed),
            else => {},
        };
    }
    const definitions = try allocator.alloc(usize, aliases.len);
    defer allocator.free(definitions);
    const uses = try allocator.alloc(usize, aliases.len);
    defer allocator.free(uses);
    const allowed = try allocator.alloc(usize, aliases.len);
    defer allocator.free(allowed);
    const fields = try allocator.alloc(?Ir.LocalId, init.fields.len);
    defer allocator.free(fields);
    @memset(definitions, 0);
    @memset(uses, 0);
    @memset(allowed, 0);
    @memset(fields, null);
    for (0..function.parameter_types.len + function.capture_types.len) |value| definitions[value] = 1;
    var reads: usize = 0;
    for (function.blocks) |block| {
        var dropped = false;
        for (block.instructions) |instruction| {
            if (resultOf(instruction)) |result| definitions[result] += 1;
            Operands.countUses(instruction, uses);
            switch (instruction) {
                .copy => |copy| if (aliases[copy.operand]) {
                    allowed[copy.operand] += 1;
                },
                .local_store => |store| if (locals[store.local]) {
                    if (!aliases[store.operand]) return function;
                    allowed[store.operand] += 1;
                },
                .local_address => |address| if (locals[address.local]) return function,
                .field_load => |load| if (aliases[load.base]) {
                    if (dropped) return function;
                    allowed[load.base] += 1;
                    fields[load.field] = 0;
                    reads += 1;
                },
                .field_store => |store| if (aliases[store.base]) {
                    if (dropped) return function;
                    allowed[store.base] += 1;
                },
                .class_retain => |retain| if (aliases[retain.operand]) {
                    allowed[retain.operand] += 1;
                },
                .class_drop => |drop| if (aliases[drop.operand]) {
                    if (block.terminator != .return_value and block.terminator != .return_void) return function;
                    allowed[drop.operand] += 1;
                    dropped = true;
                },
                else => {},
            }
        }
        Operands.countTerminatorUses(block.terminator, uses);
    }
    if (reads < 2) return function;
    for (aliases, 0..) |alias, value| if (alias) {
        if (definitions[value] != 1 or uses[value] != allowed[value] or
            function.value_types[value] != function.value_types[init.result]) return function;
    };
    // Require each tracked home to be initialized in entry before a load.
    // This deliberately excludes conditionally initialized aliases.
    const initialized = try allocator.alloc(bool, locals.len);
    defer allocator.free(initialized);
    @memset(initialized, false);
    for (function.blocks[0].instructions) |instruction| switch (instruction) {
        .local_store => |store| if (locals[store.local]) {
            initialized[store.local] = true;
        },
        .local_load => |load| if (locals[load.local] and !initialized[load.local]) return function,
        else => {},
    };
    for (locals, 0..) |local, index| if (local and !initialized[index]) return function;

    var local_types: std.ArrayList(Ir.Type) = .empty;
    try local_types.appendSlice(allocator, function.local_types);
    for (fields, 0..) |*field, index| if (field.* != null) {
        field.* = local_types.items.len;
        try local_types.append(allocator, function.value_types[init.fields[index]]);
    };
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    for (blocks) |*block| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        var positions: std.ArrayList(?Source.Position) = .empty;
        for (block.instructions, 0..) |instruction, index| {
            const position = if (block.instruction_positions.len == 0) null else block.instruction_positions[index];
            var replacement = instruction;
            if (instruction == .field_load and aliases[instruction.field_load.base]) {
                const load = instruction.field_load;
                replacement = .{ .local_load = .{ .result = load.result, .local = fields[load.field].? } };
            }
            try instructions.append(allocator, replacement);
            try positions.append(allocator, position);
            if (instruction == .structure_init and instruction.structure_init.result == init.result) {
                for (fields, 0..) |field, field_index| if (field) |local| {
                    try instructions.append(allocator, .{ .local_store = .{ .local = local, .operand = init.fields[field_index] } });
                    try positions.append(allocator, position);
                };
            } else if (instruction == .field_store and aliases[instruction.field_store.base]) {
                const store = instruction.field_store;
                if (fields[store.field]) |local| {
                    try instructions.append(allocator, .{ .local_store = .{ .local = local, .operand = store.replacement } });
                    try positions.append(allocator, position);
                }
            }
        }
        block.instructions = try instructions.toOwnedSlice(allocator);
        block.instruction_positions = try positions.toOwnedSlice(allocator);
    }
    var result = function;
    result.local_types = try local_types.toOwnedSlice(allocator);
    result.blocks = blocks;
    return result;
}
