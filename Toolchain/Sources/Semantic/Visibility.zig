const std = @import("std");
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
    const active_file = self.specialization_file orelse position.file;
    if (declaration.enclosing) |owner_name| {
        const owner = self.structureIndex(owner_name) orelse return false;
        if (!typeVisible(self, owner, position)) return false;
        if (declaration.is_public) return true;
        if (declaration.is_internal) return position.file == declaration.position.file or active_file == declaration.position.file;
        const context = self.member_context orelse return false;
        if (sameFamily(self, context, structure_index)) return true;
        return declaration.is_protected and Inheritance.isDescendant(self, context, owner);
    }
    if (declaration.is_public) return true;
    if (position.file == declaration.position.file or active_file == declaration.position.file) return true;
    if (declaration.is_internal) return false;
    return sameModule(self, structure_index);
}

fn sameModule(self: anytype, structure_index: usize) bool {
    const target_root = root(self, structure_index);
    const target = declarationAt(self, target_root) orelse return false;
    const target_module = moduleName(target.name) orelse return false;
    if (self.module_context) |context| return std.mem.eql(u8, logicalModule(context), target_module);
    const context = self.member_context orelse return false;
    const context_declaration = declarationAt(self, root(self, context)) orelse return false;
    const context_module = moduleName(context_declaration.name) orelse return false;
    return std.mem.eql(u8, context_module, target_module);
}

fn moduleName(name_value: []const u8) ?[]const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, name_value, '.') orelse return null;
    return logicalModule(name_value[0..separator]);
}

fn logicalModule(module: []const u8) []const u8 {
    if (std.mem.endsWith(u8, module, ".$Platform")) return module[0 .. module.len - ".$Platform".len];
    if (std.mem.endsWith(u8, module, ".$Target")) return module[0 .. module.len - ".$Target".len];
    return module;
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
