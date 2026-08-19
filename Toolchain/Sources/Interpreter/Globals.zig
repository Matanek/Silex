const std = @import("std");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Value = @import("Value.zig").Value;

pub fn initialize(allocator: std.mem.Allocator, program: Ir.Program) ![]Value {
    const values = try allocator.alloc(Value, program.globals.len);
    for (program.globals, 0..) |global, index| {
        var leaf: usize = 0;
        values[index] = try initializeValue(allocator, program, global, global.type, &leaf);
    }
    return values;
}

fn initializeValue(
    allocator: std.mem.Allocator,
    program: Ir.Program,
    global: Ir.Global,
    type_value: Ir.Type,
    leaf: *usize,
) !Value {
    const bits = globalBits(global, leaf.*);
    switch (type_value) {
        .int => {
            leaf.* += 1;
            return .{ .integer = @bitCast(bits) };
        },
        .int8, .int16, .int32, .uint8, .uint16, .uint32, .uint => {
            leaf.* += 1;
            return .{ .typed_integer = .{ .type = type_value, .bits = Numeric.normalize(bits, type_value) } };
        },
        .bool => {
            leaf.* += 1;
            return .{ .boolean = bits != 0 };
        },
        .float32 => {
            leaf.* += 1;
            return .{ .float32 = @bitCast(@as(u32, @truncate(bits))) };
        },
        .float64 => {
            leaf.* += 1;
            return .{ .float64 = @bitCast(bits) };
        },
        else => {},
    }
    if (type_value.optionalChild()) |child| {
        leaf.* += 1 + try leafCount(program, child);
        return .{ .optional = .{ .type = type_value, .value = null } };
    }
    const structure_index = type_value.structureIndex() orelse return error.InvalidProgram;
    if (structure_index >= program.structures.len) return error.InvalidProgram;
    const structure = program.structures[structure_index];
    if (structure.collection) |collection| {
        if (collection.length == null and !collection.view and global.runtime_initialized) {
            leaf.* += 1;
            return .{ .structure = .{ .type = type_value, .fields = &.{} } };
        }
        return error.InvalidProgram;
    }
    if (structure.is_class or structure.is_protocol) return error.InvalidProgram;
    const fields = try allocator.alloc(Value, structure.fields.len);
    for (structure.fields, 0..) |field, index| {
        fields[index] = try initializeValue(allocator, program, global, field.type, leaf);
    }
    return .{ .structure = .{ .type = type_value, .fields = fields } };
}

fn globalBits(global: Ir.Global, leaf: usize) u64 {
    if (leaf == 0) return global.bits;
    return if (leaf - 1 < global.extra_bits.len) global.extra_bits[leaf - 1] else 0;
}

fn leafCount(program: Ir.Program, type_value: Ir.Type) !usize {
    if (type_value.optionalChild()) |child| return 1 + try leafCount(program, child);
    const structure_index = type_value.structureIndex() orelse return 1;
    if (structure_index >= program.structures.len) return error.InvalidProgram;
    const structure = program.structures[structure_index];
    if (structure.is_class or structure.collection != null) return 1;
    var result: usize = 0;
    for (structure.fields) |field| result += try leafCount(program, field.type);
    return result;
}

pub fn load(allocator: std.mem.Allocator, globals: []Value, instruction: Ir.Instruction.GlobalLoad) !Value {
    if (instruction.global >= globals.len) return error.InvalidProgram;
    return @import("Value.zig").clone(allocator, globals[instruction.global]);
}

pub fn store(allocator: std.mem.Allocator, program: Ir.Program, globals: []Value, instruction: Ir.Instruction.GlobalStore, value: Value) !void {
    if (instruction.global >= globals.len or (!program.globals[instruction.global].mutable and !program.globals[instruction.global].runtime_initialized) or
        value.typeOf() != program.globals[instruction.global].type) return error.InvalidProgram;
    globals[instruction.global] = try @import("Value.zig").clone(allocator, value);
}
