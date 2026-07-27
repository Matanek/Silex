const std = @import("std");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");
const pathInside = @import("Names.zig").pathInside;

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

pub fn discoverProviders(self: anytype) !Modules.Index {
    var indexes: std.ArrayList(Modules.Index) = .empty;
    for (self.packages.packages, 0..) |package, owner| {
        for (package.module_roots) |module_root| {
            var discovered = try Modules.discoverOwned(self.allocator, self.io, module_root, package.name, owner);
            if (owner == 0) discovered = try excludePackageSources(self, discovered);
            try indexes.append(self.allocator, discovered);
        }
    }
    return Modules.combine(self.allocator, indexes.items);
}

fn excludePackageSources(self: anytype, index: Modules.Index) !Modules.Index {
    var providers: std.ArrayList(Modules.Provider) = .empty;
    for (index.providers) |provider| {
        var excluded = false;
        for (self.packages.packages[1..]) |package| if (pathInside(provider.path, package.root)) {
            excluded = true;
            break;
        };
        if (!excluded) try providers.append(self.allocator, provider);
    }
    return .{ .providers = try providers.toOwnedSlice(self.allocator) };
}
