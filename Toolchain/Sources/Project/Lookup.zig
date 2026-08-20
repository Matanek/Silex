const std = @import("std");
const builtin = @import("builtin");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");
const Reexports = @import("Reexports.zig");

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
        if (samePath(provider.path, path, builtin.os.tag == .windows)) return index;
    }
    return null;
}

fn samePath(left: []const u8, right: []const u8, windows: bool) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_character, right_character| {
        if (windows and isWindowsSeparator(left_character) and isWindowsSeparator(right_character)) continue;
        if (windows) {
            if (std.ascii.toLower(left_character) != std.ascii.toLower(right_character)) return false;
        } else if (left_character != right_character) return false;
    }
    return true;
}

fn isWindowsSeparator(character: u8) bool {
    return character == '/' or character == '\\';
}

pub fn findLocalFunction(program: Ast.Program, name: []const u8) bool {
    for (program.functions) |function| if (std.mem.eql(u8, function.name, name)) return true;
    return false;
}

pub fn longestAccessibleModulePrefix(self: anytype, path: []const u8, owner: usize) ?Reexports.Target {
    var end = path.len;
    while (true) {
        const prefix = path[0..end];
        if (findAccessibleModule(self, prefix, owner)) |module| {
            if (end == path.len) return .{
                .module = module,
                .declaration = @import("Names.zig").lastSegment(prefix),
            };
            return .{ .module = module, .declaration = path[end + 1 ..] };
        }
        end = std.mem.lastIndexOfScalar(u8, prefix, '.') orelse return null;
    }
}

test "compare Windows provider paths across separator and case spelling" {
    try std.testing.expect(samePath(
        "Examples\\Distribution\\Hello.sx",
        "examples/Distribution/Hello.sx",
        true,
    ));
    try std.testing.expect(!samePath("Examples\\Distribution\\Hello.sx", "Examples/Distribution/Hello.sx", false));
}

test "keep a relative entry path below the current package root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    try std.testing.expectEqualStrings(
        "Tests/Catalogs.sx",
        try relativeInputPath(arena.allocator(), ".", "Tests/Catalogs.sx"),
    );
}

pub fn discoverProviders(self: anytype, input_path: []const u8) !Modules.Index {
    var indexes: std.ArrayList(Modules.Index) = .empty;
    const excluded_roots = try self.allocator.alloc([]const u8, self.packages.packages.len - 1);
    for (self.packages.packages[1..], excluded_roots) |package, *root| root.* = package.root;
    for (self.packages.packages, 0..) |package, owner| {
        for (package.module_roots) |module_root| {
            const discovered = if (owner == 0)
                try Modules.discoverOwnedExcludingAs(self.allocator, self.io, module_root.path, package.name, owner, excluded_roots, module_root.origin)
            else
                try Modules.discoverOwnedAs(self.allocator, self.io, module_root.path, package.name, owner, module_root.origin);
            try indexes.append(self.allocator, discovered);
        }
    }
    const merges = try self.packages.moduleMerges(self.allocator);
    const discovered = Modules.combineWithMerges(self.allocator, indexes.items, merges) catch |err| switch (err) {
        error.DuplicateModule => {
            if (Modules.firstCollision(indexes.items, merges)) |collision| {
                if (namespaceParent(self.packages, collision)) |relationship| {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "parent package '{s}' owns module '{s}'; extension package '{s}' cannot provide the same module unless its exact extension permission enables merge",
                        .{ relationship.parent, collision.name, relationship.child },
                    );
                    return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, message);
                }
            }
            return error.DuplicateModule;
        },
        else => |other| return other,
    };
    if (findProviderPath(.{ .index = discovered }, input_path) != null) return discovered;

    const package = self.packages.packages[0];
    const relative_path = try relativeInputPath(self.allocator, package.root, input_path);
    const relative_name = try Modules.moduleName(self.allocator, relative_path);
    const module_name = if (package.name) |name|
        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ name, relative_name })
    else
        relative_name;
    if (discovered.find(module_name) != null) return error.DuplicateModule;
    const entry_provider = [_]Modules.Provider{.{
        .name = module_name,
        .path = try self.allocator.dupe(u8, input_path),
        .file = 0,
        .owner = 0,
        .origin = .entry,
    }};
    const entry_index: Modules.Index = .{ .providers = &entry_provider };
    return Modules.combine(self.allocator, &.{ discovered, entry_index });
}

fn relativeInputPath(allocator: std.mem.Allocator, root: []const u8, input: []const u8) ![]const u8 {
    if (std.mem.eql(u8, root, ".") and !std.fs.path.isAbsolute(input)) {
        return allocator.dupe(u8, input);
    }
    return std.fs.path.relative(allocator, ".", null, root, input);
}

const NamespaceRelationship = struct {
    parent: []const u8,
    child: []const u8,
};

fn namespaceParent(packages: anytype, collision: Modules.Collision) ?NamespaceRelationship {
    return namespaceParentOrdered(packages, collision.left_owner, collision.right_owner, collision.name) orelse
        namespaceParentOrdered(packages, collision.right_owner, collision.left_owner, collision.name);
}

fn namespaceParentOrdered(packages: anytype, parent_owner: usize, child_owner: usize, module_name: []const u8) ?NamespaceRelationship {
    if (parent_owner >= packages.packages.len or child_owner >= packages.packages.len) return null;
    const parent_name = packages.packages[parent_owner].name orelse return null;
    const child_name = packages.packages[child_owner].name orelse return null;
    if (!std.mem.eql(u8, child_name, module_name)) return null;
    const separator = std.mem.lastIndexOfScalar(u8, child_name, '.') orelse return null;
    if (!std.mem.eql(u8, parent_name, child_name[0..separator])) return null;
    return .{ .parent = parent_name, .child = child_name };
}
