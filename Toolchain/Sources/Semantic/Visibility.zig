const std = @import("std");
const Source = @import("../Source.zig");
const Inheritance = @import("Inheritance.zig");
const ModuleScopes = @import("../ModuleScopes.zig");

pub fn memberVisible(self: anytype, structure_index: usize, member: anytype, position: Source.Position) bool {
    if (!typeVisible(self, structure_index, position)) return false;
    if (comptime @hasField(@TypeOf(member), "extension")) {
        if (member.extension) |extension| {
            const active_file = self.specialization_file orelse position.file;
            var active = false;
            for (extension.visible_files) |file| if (file == active_file) {
                active = true;
                break;
            };
            if (!active) return false;
            if (member.is_public) return true;
            if (member.is_local) return position.file == member.position.file;
            if (member.is_internal) return packageVisible(self, member.owner);
            return position.file == member.position.file;
        }
    }
    if (member.is_public) return true;
    if (member.is_local) return position.file == member.position.file;
    if (member.is_internal) {
        return packageVisible(self, self.program.structures[structure_index].owner);
    }
    if (!member.is_private and !member.is_protected) {
        return position.file == member.position.file or sameModule(self, structure_index);
    }
    if (self.extension_context) return false;
    const context = self.member_context orelse return false;
    if (sameFamily(self, context, structure_index)) return true;
    return member.is_protected and Inheritance.isDescendant(self, context, protectedAnchor(self, structure_index));
}

pub fn typeVisible(self: anytype, structure_index: usize, position: Source.Position) bool {
    const declaration = declarationAt(self, structure_index) orelse return false;
    const active_file = self.specialization_file orelse position.file;
    if (declaration.enclosing) |owner_name| {
        const owner = self.structureIndex(owner_name) orelse return false;
        if (!typeVisible(self, owner, position)) return false;
        if (declaration.is_public) return true;
        if (declaration.is_local) return position.file == declaration.position.file;
        if (declaration.is_internal) return packageVisible(self, declaration.owner);
        if (!declaration.is_private and !declaration.is_protected) {
            return position.file == declaration.position.file or sameModule(self, structure_index);
        }
        const context = self.member_context orelse return false;
        if (sameFamily(self, context, structure_index)) return true;
        return declaration.is_protected and Inheritance.isDescendant(self, context, owner);
    }
    if (declaration.is_public) return true;
    if (position.file == declaration.position.file) return true;
    if (declaration.is_local) return false;
    if (active_file == declaration.position.file) return true;
    if (declaration.is_internal) return packageVisible(self, declaration.owner);
    return sameModule(self, structure_index);
}

fn protectedAnchor(self: anytype, structure_index: usize) usize {
    const declaration = declarationAt(self, structure_index) orelse return structure_index;
    if (!declaration.is_protected) return structure_index;
    const owner_name = declaration.enclosing orelse return structure_index;
    return self.structureIndex(owner_name) orelse structure_index;
}

fn sameModule(self: anytype, structure_index: usize) bool {
    const target_root = root(self, structure_index);
    const target = declarationAt(self, target_root) orelse return false;
    const accessor = self.owner_context orelse return false;
    const target_module = declarationModule(self.module_scope_roots, target.name) orelse return false;
    if (accessor != target.owner and
        (self.packages == null or !self.packages.?.canAccessMergedModule(accessor, target.owner, target_module))) return false;
    if (self.module_context) |context| return ModuleScopes.same(self.module_scope_roots, context, target_module);
    const context = self.member_context orelse return false;
    const context_declaration = declarationAt(self, root(self, context)) orelse return false;
    const context_module = declarationModule(self.module_scope_roots, context_declaration.name) orelse return false;
    return ModuleScopes.same(self.module_scope_roots, context_module, target_module);
}

fn declarationModule(roots: []const []const u8, name_value: []const u8) ?[]const u8 {
    for (roots) |module_root| if (std.mem.eql(u8, module_root, name_value)) return module_root;
    return moduleName(name_value);
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

pub fn packageVisible(self: anytype, provider: usize) bool {
    const accessor = self.owner_context orelse return false;
    return packageAccessible(self, accessor, provider);
}

pub fn packageAccessible(self: anytype, accessor: usize, provider: usize) bool {
    if (self.packages) |packages| return packages.canAccessPackage(accessor, provider);
    return accessor == provider;
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
    if (member.is_internal) return "package";
    if (member.is_local) return "local";
    if (member.is_protected) return "protected";
    if (member.is_private) return "private";
    return "module";
}
