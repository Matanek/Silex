const std = @import("std");
const Modules = @import("Modules.zig");

const Io = std.Io;

/// Enumerate the package's portable and every declared Platform/Target source
/// tree using the same module discovery rules as the compiler. Paths are
/// relative to the package root and use archive separators.
pub fn collectSources(allocator: std.mem.Allocator, io: Io, package_root: []const u8, sources: []const u8, package_name: []const u8) ![]const []const u8 {
    const root = try std.fs.path.resolve(allocator, &.{package_root});
    defer allocator.free(root);
    var paths: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (paths.items) |path| allocator.free(path);
        paths.deinit(allocator);
    }
    const portable = if (std.mem.eql(u8, sources, ".")) try allocator.dupe(u8, root) else try std.fs.path.join(allocator, &.{ root, sources });
    defer allocator.free(portable);
    const platform = try std.fs.path.join(allocator, &.{ root, "Platform" });
    defer allocator.free(platform);
    const target = try std.fs.path.join(allocator, &.{ root, "Target" });
    defer allocator.free(target);
    const excluded: []const []const u8 = if (std.mem.eql(u8, sources, ".")) &.{ platform, target } else &.{};
    try appendSourceTree(allocator, io, root, portable, excluded, package_name, &paths);
    try appendVariants(allocator, io, root, platform, sources, package_name, &paths);
    try appendVariants(allocator, io, root, target, sources, package_name, &paths);
    std.mem.sort([]const u8, paths.items, {}, lessThan);
    return paths.toOwnedSlice(allocator);
}

fn appendVariants(allocator: std.mem.Allocator, io: Io, root: []const u8, category: []const u8, sources: []const u8, package_name: []const u8, paths: *std.ArrayList([]const u8)) !void {
    var directory = Io.Dir.cwd().openDir(io, category, .{ .iterate = true, .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return,
        else => return error.UnsafeEntry,
    };
    defer directory.close(io);
    var entries = directory.iterateAssumeFirstIteration();
    while (try entries.next(io)) |entry| {
        if (entry.kind != .directory) {
            if (entry.kind == .sym_link) return error.UnsafeEntry;
            continue;
        }
        const variant = try std.fs.path.join(allocator, &.{ category, entry.name });
        defer allocator.free(variant);
        const source_root = if (std.mem.eql(u8, sources, ".")) try allocator.dupe(u8, variant) else try std.fs.path.join(allocator, &.{ variant, sources });
        defer allocator.free(source_root);
        const probe = Io.Dir.cwd().openDir(io, source_root, .{ .follow_symlinks = false }) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return error.UnsafeEntry,
        };
        probe.close(io);
        try appendSourceTree(allocator, io, root, source_root, &.{}, package_name, paths);
    }
}

fn appendSourceTree(allocator: std.mem.Allocator, io: Io, root: []const u8, source_root: []const u8, excluded: []const []const u8, package_name: []const u8, paths: *std.ArrayList([]const u8)) !void {
    var temporary_arena = std.heap.ArenaAllocator.init(allocator);
    defer temporary_arena.deinit();
    const index = try Modules.discoverOwnedExcluding(temporary_arena.allocator(), io, source_root, package_name, 0, excluded);
    for (index.providers) |provider| {
        if (!std.mem.startsWith(u8, provider.path, root) or provider.path.len <= root.len or provider.path[root.len] != std.fs.path.sep) return error.UnsafeEntry;
        const relative = provider.path[root.len + 1 ..];
        const portable = try allocator.dupe(u8, relative);
        for (portable) |*byte| if (byte.* == '\\') {
            byte.* = '/';
        };
        try paths.append(allocator, portable);
    }
}

fn lessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

test "collect portable and inactive variant sources without cache entries" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Package/Module");
    try temporary.dir.createDirPath(std.testing.io, "Package/Platform/Linux/Module");
    try temporary.dir.createDirPath(std.testing.io, "Package/Target/windows-x64/Module");
    try temporary.dir.createDirPath(std.testing.io, "Package/.silex/cache");
    for ([_][]const u8{
        "Package/Module/Core.sx",                       "Package/Platform/Linux/Module/Linux.sx",
        "Package/Target/windows-x64/Module/Windows.sx", "Package/.silex/cache/Hidden.sx",
    }) |path| try temporary.dir.writeFile(std.testing.io, .{ .sub_path = path, .data = "public func answer() int { return 42 }\n" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Package" });
    defer allocator.free(root);
    const sources = try collectSources(allocator, std.testing.io, root, "Module", "Package");
    defer {
        for (sources) |path| allocator.free(path);
        allocator.free(sources);
    }
    try std.testing.expectEqual(@as(usize, 3), sources.len);
    try std.testing.expectEqualStrings("Module/Core.sx", sources[0]);
    try std.testing.expectEqualStrings("Platform/Linux/Module/Linux.sx", sources[1]);
    try std.testing.expectEqualStrings("Target/windows-x64/Module/Windows.sx", sources[2]);
}

test "sources dot does not count variant files twice" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Package/Platform/Linux");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package/Core.sx", .data = "func main() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package/Platform/Linux/Linux.sx", .data = "func main() {}" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Package" });
    defer allocator.free(root);
    const sources = try collectSources(allocator, std.testing.io, root, ".", "Package");
    defer {
        for (sources) |path| allocator.free(path);
        allocator.free(sources);
    }
    try std.testing.expectEqual(@as(usize, 2), sources.len);
    try std.testing.expectEqualStrings("Core.sx", sources[0]);
    try std.testing.expectEqualStrings("Platform/Linux/Linux.sx", sources[1]);
}

test "package root module atoms are discovered for portable and variant sources" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Package/Module");
    try temporary.dir.createDirPath(std.testing.io, "Package/Platform/Linux/Module");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package/Module/@Module.sx", .data = "public func answer() int { return 42 }\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package/Platform/Linux/Module/@Module.sx", .data = "public func other() int { return 43 }\n" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Package" });
    defer allocator.free(root);
    const sources = try collectSources(allocator, std.testing.io, root, "Module", "Package");
    defer {
        for (sources) |path| allocator.free(path);
        allocator.free(sources);
    }
    try std.testing.expectEqual(@as(usize, 2), sources.len);
    try std.testing.expectEqualStrings("Module/@Module.sx", sources[0]);
    try std.testing.expectEqualStrings("Platform/Linux/Module/@Module.sx", sources[1]);
}
