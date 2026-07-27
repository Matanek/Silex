const Source = @import("../Source.zig");
const Inheritance = @import("Inheritance.zig");

pub fn memberVisible(self: anytype, structure_index: usize, member: anytype, position: Source.Position) bool {
    if (comptime @hasField(@TypeOf(member), "extension")) {
        if (member.extension) |extension| {
            const active_file = self.specialization_file orelse position.file;
            var active = false;
            for (extension.visible_files) |file| if (file == active_file) {
                active = true;
                break;
            };
            if (!active) return false;
            return member.is_public or position.file == member.position.file;
        }
    }
    if (member.is_public) return true;
    if (member.is_internal) return position.file == member.position.file;
    if (self.extension_context) return false;
    const context = self.member_context orelse return false;
    if (sameFamily(self, context, structure_index)) return true;
    return member.is_protected and Inheritance.isDescendant(self, context, structure_index);
}

pub fn typeVisible(self: anytype, structure_index: usize, position: Source.Position) bool {
    const declaration = declarationAt(self, structure_index) orelse return false;
    if (declaration.enclosing) |owner_name| {
        const owner = self.structureIndex(owner_name) orelse return false;
        if (!typeVisible(self, owner, position)) return false;
        if (declaration.is_public) return true;
        if (declaration.is_internal) return position.file == declaration.position.file;
        const context = self.member_context orelse return false;
        if (sameFamily(self, context, structure_index)) return true;
        return declaration.is_protected and Inheritance.isDescendant(self, context, owner);
    }
    return declaration.is_public or position.file == declaration.position.file;
}

pub fn sameFamily(self: anytype, left: usize, right: usize) bool {
    return root(self, left) == root(self, right);
}

fn root(self: anytype, start: usize) usize {
    var current = start;
    var depth: usize = 0;
    while (depth <= self.structures.len) : (depth += 1) {
        const declaration = declarationAt(self, current) orelse return current;
        const owner_name = declaration.enclosing orelse return current;
        current = self.structureIndex(owner_name) orelse return current;
    }
    return current;
}

fn declarationAt(self: anytype, structure_index: usize) ?@import("../Ast.zig").Structure {
    if (structure_index >= self.structures.len) return null;
    const name_value = self.structures[structure_index].name;
    for (self.program.structures) |structure| if (std.mem.eql(u8, structure.name, name_value)) return structure;
    return null;
}

pub fn name(member: anytype) []const u8 {
    if (member.is_public) return "public";
    if (member.is_internal) return "internal";
    if (member.is_protected) return "protected";
    return "private";
}

const std = @import("std");
