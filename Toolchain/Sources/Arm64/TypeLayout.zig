const Ir = @import("../Ir.zig");
const Machine = @import("Machine.zig");

pub fn leafCount(program: Ir.Program, type_value: Ir.Type) Machine.Error!usize {
    if (type_value.functionIndex() != null) return 2;
    if (type_value.optionalChild()) |child| return 1 + try leafCount(program, child);
    if (enumByType(program, type_value)) |enumeration| {
        if (enumeration.raw_type != null) return 2;
        var maximum: usize = 0;
        for (enumeration.variants) |variant| {
            var width: usize = 0;
            for (variant.associated_types) |associated| width += try leafCount(program, associated);
            maximum = @max(maximum, width);
        }
        return 1 + maximum;
    }
    const structure_index = type_value.structureIndex() orelse return 1;
    if (structure_index >= program.structures.len) return error.InvalidMachineProgram;
    if (program.structures[structure_index].is_protocol) {
        var maximum: usize = 0;
        for (program.structures, 0..) |structure, candidate| {
            if (structure.is_protocol or !irConforms(program, candidate, structure_index)) continue;
            maximum = @max(maximum, try leafCount(program, .structure(candidate)));
        }
        return 1 + maximum;
    }
    if (program.structures[structure_index].is_class) return 1;
    if (program.structures[structure_index].collection) |collection| {
        if (collection.length == null) return if (collection.view) 2 else 1;
    }
    var result: usize = 0;
    for (program.structures[structure_index].fields) |field| result += try leafCount(program, field.type);
    return result;
}

pub fn isAggregate(program: Ir.Program, type_value: Ir.Type) bool {
    if (type_value.functionIndex() != null) return true;
    if (type_value.optionalChild() != null) return true;
    const index = type_value.structureIndex() orelse return false;
    if (index >= program.structures.len) return true;
    if (program.structures[index].is_class) return false;
    const collection = program.structures[index].collection orelse return true;
    return collection.length != null or collection.view;
}

pub fn enumByType(program: Ir.Program, type_value: Ir.Type) ?Ir.Enum {
    const index = type_value.structureIndex() orelse return null;
    for (program.enums) |enumeration| if (enumeration.type_index == index) return enumeration;
    return null;
}

pub fn irConforms(program: Ir.Program, structure_index: usize, protocol_index: usize) bool {
    var current: ?usize = structure_index;
    while (current) |candidate| : (current = program.structures[candidate].base) {
        for (program.structures[candidate].conformances) |conformance| {
            if (conformance == protocol_index) return true;
        }
    }
    return false;
}
