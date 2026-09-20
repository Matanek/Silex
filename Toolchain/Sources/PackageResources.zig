const std = @import("std");
const builtin = @import("builtin");
const EmbeddedFiles = @import("EmbeddedFiles.zig");

const Allocator = std.mem.Allocator;

/// Select resources whose requesting source belongs to the local package.
/// A package source reaching outside the package is rejected; dependency-owned
/// resources are not copied into the author's publication.
pub fn select(allocator: Allocator, package_root: []const u8, uses: []const EmbeddedFiles.Use) ![]const []const u8 {
    const root = try std.fs.path.resolve(allocator, &.{package_root});
    defer allocator.free(root);

    var seen: std.StringHashMap(void) = .init(allocator);
    defer seen.deinit();
    var result: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (result.items) |path| allocator.free(path);
        result.deinit(allocator);
    }

    for (uses) |use| {
        const owner = try std.fs.path.resolve(allocator, &.{use.owner});
        defer allocator.free(owner);
        if (!inside(root, owner)) continue;

        const resource = try std.fs.path.resolve(allocator, &.{use.path});
        defer allocator.free(resource);
        if (!inside(root, resource)) return error.ResourceOutsidePackage;
        const relative = resource[root.len + 1 ..];
        if (relative.len == 0) return error.ResourceOutsidePackage;
        const portable = try allocator.dupe(u8, relative);
        for (portable) |*byte| if (byte.* == '\\') {
            byte.* = '/';
        };
        if (seen.contains(portable)) {
            allocator.free(portable);
        } else {
            try result.append(allocator, portable);
            try seen.put(portable, {});
        }
    }
    std.mem.sort([]const u8, result.items, {}, lessThan);
    return result.toOwnedSlice(allocator);
}

fn inside(root: []const u8, path: []const u8) bool {
    if (path.len <= root.len or path[root.len] != std.fs.path.sep) return false;
    return if (builtin.os.tag == .windows)
        std.ascii.eqlIgnoreCase(root, path[0..root.len])
    else
        std.mem.eql(u8, root, path[0..root.len]);
}

fn lessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

test "select package-owned embedded resources without copying dependency assets" {
    const allocator = std.testing.allocator;
    const root = try std.fs.path.resolve(allocator, &.{"LocalDemo"});
    defer allocator.free(root);
    const module = try std.fs.path.join(allocator, &.{ root, "Module" });
    defer allocator.free(module);
    const other = try std.fs.path.resolve(allocator, &.{"Other"});
    defer allocator.free(other);
    const first = try std.fs.path.join(allocator, &.{ module, "A.sx" });
    defer allocator.free(first);
    const second = try std.fs.path.join(allocator, &.{ module, "B.sx" });
    defer allocator.free(second);
    const a = try std.fs.path.join(allocator, &.{ module, "a.txt" });
    defer allocator.free(a);
    const b = try std.fs.path.join(allocator, &.{ module, "b.txt" });
    defer allocator.free(b);
    const dependency = try std.fs.path.join(allocator, &.{ other, "Dependency.sx" });
    defer allocator.free(dependency);
    const dependency_asset = try std.fs.path.join(allocator, &.{ other, "asset.txt" });
    defer allocator.free(dependency_asset);
    const uses: []const EmbeddedFiles.Use = &.{
        .{ .owner = second, .path = b },
        .{ .owner = dependency, .path = dependency_asset },
        .{ .owner = first, .path = a },
        .{ .owner = second, .path = b },
    };
    const paths = try select(allocator, root, uses);
    defer {
        for (paths) |path| allocator.free(path);
        allocator.free(paths);
    }
    try std.testing.expectEqual(@as(usize, 2), paths.len);
    try std.testing.expectEqualStrings("Module/a.txt", paths[0]);
    try std.testing.expectEqualStrings("Module/b.txt", paths[1]);
}

test "reject a package source embedding an external file" {
    const allocator = std.testing.allocator;
    const root = try std.fs.path.resolve(allocator, &.{"LocalDemo"});
    defer allocator.free(root);
    const owner = try std.fs.path.join(allocator, &.{ root, "Module", "Content.sx" });
    defer allocator.free(owner);
    const external = try std.fs.path.resolve(allocator, &.{"secrets.txt"});
    defer allocator.free(external);
    try std.testing.expectError(error.ResourceOutsidePackage, select(allocator, root, &.{
        .{ .owner = owner, .path = external },
    }));
}
