const std = @import("std");
const Ast = @import("../Ast.zig");

pub const Field = struct {
    owner: usize,
    local: usize,
    flattened: usize,
    declaration: Ast.StructureField,
};

pub fn directBase(self: anytype, structure_index: usize) ?usize {
    if (structure_index >= self.structures.len) return null;
    return self.structures[structure_index].base;
}

pub fn canUpcast(self: anytype, source: Ast.Type, target: Ast.Type) bool {
    const source_index = source.structureIndex() orelse return false;
    const target_index = target.structureIndex() orelse return false;
    if (source_index >= self.structures.len or target_index >= self.structures.len) return false;
    if (!self.structures[source_index].is_class or !self.structures[target_index].is_class) return false;
    var current = self.structures[source_index].base;
    while (current) |index| {
        if (index == target_index) return true;
        current = self.structures[index].base;
    }
    return false;
}

pub fn isDescendant(self: anytype, candidate: usize, ancestor: usize) bool {
    if (candidate == ancestor) return true;
    if (candidate >= self.structures.len) return false;
    var current = self.structures[candidate].base;
    while (current) |index| {
        if (index == ancestor) return true;
        current = self.structures[index].base;
    }
    return false;
}

pub fn fieldByIndex(self: anytype, structure_index: usize, flattened: usize) ?Field {
    if (structure_index >= self.structures.len or flattened >= self.structures[structure_index].fields.len) return null;
    const base = self.structures[structure_index].base;
    const base_count = if (base) |index| self.structures[index].fields.len else 0;
    if (base) |index| if (flattened < base_count) return fieldByIndex(self, index, flattened);
    const local = flattened - base_count;
    const declaration = findDeclaration(self, structure_index) orelse return null;
    if (local >= declaration.fields.len) return null;
    return .{ .owner = structure_index, .local = local, .flattened = flattened, .declaration = declaration.fields[local] };
}

pub fn fieldByName(self: anytype, structure_index: usize, name: []const u8) ?Field {
    if (structure_index >= self.structures.len) return null;
    for (self.structures[structure_index].fields, 0..) |field, index| {
        if (std.mem.eql(u8, field.name, name)) return fieldByIndex(self, structure_index, index);
    }
    return null;
}

pub fn methodOwner(self: anytype, structure_index: usize, name: []const u8) ?usize {
    var current: ?usize = structure_index;
    while (current) |index| {
        const declaration = findDeclaration(self, index) orelse return null;
        for (declaration.methods) |method| if (std.mem.eql(u8, method.name, name)) return index;
        current = self.structures[index].base;
    }
    return null;
}

pub fn findDeclaration(self: anytype, structure_index: usize) ?Ast.Structure {
    if (structure_index >= self.structures.len) return null;
    const name = self.structures[structure_index].name;
    for (self.program.structures) |structure| if (std.mem.eql(u8, structure.name, name)) return structure;
    return null;
}
