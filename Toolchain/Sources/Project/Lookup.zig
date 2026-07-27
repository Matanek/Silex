const std = @import("std");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");

pub fn findModule(self: anytype, name: []const u8) ?usize {
    for (self.index.providers, 0..) |provider, module| {
        if (std.mem.eql(u8, provider.name, name)) return module;
    }
    return null;
}

pub fn findAccessibleModule(self: anytype, name: []const u8, owner: usize) ?usize {
    const module = findModule(self, name) orelse return null;
    const provider = self.index.providers[module];
    if (!self.packages.canAccess(owner, provider.owner, provider.name)) return null;
    return module;
}

pub fn isAccessibleNamespace(self: anytype, name: []const u8, owner: usize) bool {
    for (self.index.providers) |provider| {
        if (!self.packages.canAccess(owner, provider.owner, provider.name)) continue;
        if (std.mem.eql(u8, provider.name, name)) return true;
        if (provider.name.len > name.len and std.mem.startsWith(u8, provider.name, name) and provider.name[name.len] == '.') return true;
    }
    return false;
}

pub fn findProviderPath(self: anytype, path: []const u8) ?usize {
    for (self.index.providers, 0..) |provider, index| {
        if (std.mem.eql(u8, provider.path, path)) return index;
    }
    return null;
}

pub fn findLocalFunction(program: Ast.Program, name: []const u8) bool {
    for (program.functions) |function| if (std.mem.eql(u8, function.name, name)) return true;
    return false;
}

pub fn discoverProviders(self: anytype, input_path: []const u8) !Modules.Index {
    var indexes: std.ArrayList(Modules.Index) = .empty;
    const excluded_roots = try self.allocator.alloc([]const u8, self.packages.packages.len - 1);
    for (self.packages.packages[1..], excluded_roots) |package, *root| root.* = package.root;
    for (self.packages.packages, 0..) |package, owner| {
        for (package.module_roots) |module_root| {
            const discovered = if (owner == 0)
                try Modules.discoverOwnedExcluding(self.allocator, self.io, module_root, package.name, owner, excluded_roots)
            else
                try Modules.discoverOwned(self.allocator, self.io, module_root, package.name, owner);
            try indexes.append(self.allocator, discovered);
        }
    }
    const discovered = try Modules.combine(self.allocator, indexes.items);
    if (findProviderPath(.{ .index = discovered }, input_path) != null) return discovered;

    const package = self.packages.packages[0];
    const relative_path = try std.fs.path.relative(self.allocator, ".", null, package.root, input_path);
    const relative_name = try Modules.moduleName(self.allocator, relative_path);
    const module_name = if (package.name) |name|
        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ name, relative_name })
    else
        relative_name;
    const entry_provider = [_]Modules.Provider{.{
        .name = module_name,
        .path = try self.allocator.dupe(u8, input_path),
        .file = 0,
        .owner = 0,
    }};
    const entry_index: Modules.Index = .{ .providers = &entry_provider };
    return Modules.combine(self.allocator, &.{ discovered, entry_index });
}
