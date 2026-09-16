const std = @import("std");
const Archive = @import("PackageArchive.zig");
const Descriptor = @import("PackageDescriptor.zig");

const Io = std.Io;

/// Capture only a previously selected inventory, in canonical path order.
/// Callers must supply all source modules, embedded resources and selected
/// editorial files; ignored infrastructure is never traversed here.
pub fn captureSelected(allocator: std.mem.Allocator, io: Io, package_root: []const u8, selected: []const []const u8) ![]Archive.File {
    if (selected.len == 0 or selected.len > 10_000) return error.SourceLimit;
    const paths = try allocator.dupe([]const u8, selected);
    defer allocator.free(paths);
    std.mem.sort([]const u8, paths, {}, pathLessThan);
    const files = try allocator.alloc(Archive.File, paths.len);
    errdefer allocator.free(files);
    var copied: usize = 0;
    errdefer for (files[0..copied]) |file| allocator.free(file.bytes);
    var expanded: usize = 0;
    for (paths, files, 0..) |path, *file, index| {
        if (index > 0 and std.mem.eql(u8, path, paths[index - 1])) return error.DuplicatePath;
        const bytes = try copyFile(allocator, io, package_root, path);
        expanded = std.math.add(usize, expanded, bytes.len) catch {
            allocator.free(bytes);
            return error.SourceLimit;
        };
        if (expanded > 64 * 1024 * 1024) {
            allocator.free(bytes);
            return error.SourceLimit;
        }
        file.* = .{ .path = path, .bytes = bytes };
        copied += 1;
    }
    return files;
}

fn pathLessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

/// Copy one selected regular file through directory handles anchored at the
/// package root. Neither an ancestor symlink nor a leaf symlink is followed.
/// The returned bytes are the only bytes later archive/descriptor stages use.
pub fn copyFile(allocator: std.mem.Allocator, io: Io, package_root: []const u8, relative_path: []const u8) ![]u8 {
    if (!Archive.safeArchivePath(relative_path)) return error.InvalidPath;

    const root = Io.Dir.cwd().openDir(io, package_root, .{ .follow_symlinks = false }) catch return error.InvalidPackageRoot;
    defer root.close(io);
    var directory = root;
    var owned_directory: ?Io.Dir = null;
    defer if (owned_directory) |owned| owned.close(io);

    var parts = std.mem.splitScalar(u8, relative_path, '/');
    var name = parts.next().?;
    while (parts.next()) |next| {
        const child = directory.openDir(io, name, .{ .follow_symlinks = false }) catch return error.UnsafeEntry;
        if (owned_directory) |owned| owned.close(io);
        owned_directory = child;
        directory = child;
        name = next;
    }

    const before = directory.statFile(io, name, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return error.MissingFile,
        else => return error.UnsafeEntry,
    };
    if (before.kind != .file or before.nlink != 1) return error.UnsafeEntry;
    if (before.size > 16 * 1024 * 1024) return error.FileLimit;
    const file = directory.openFile(io, name, .{ .allow_directory = false, .follow_symlinks = false }) catch return error.UnsafeEntry;
    defer file.close(io);
    const opened = try file.stat(io);
    if (!sameFile(before, opened)) return error.FileChanged;

    var buffer: [16 * 1024]u8 = undefined;
    var reader = file.reader(io, &buffer);
    const bytes = try reader.interface.allocRemaining(allocator, .limited(16 * 1024 * 1024));
    errdefer allocator.free(bytes);
    const after = try file.stat(io);
    if (!sameFile(opened, after) or bytes.len != after.size) return error.FileChanged;
    return bytes;
}

fn sameFile(first: Io.File.Stat, second: Io.File.Stat) bool {
    return first.kind == .file and second.kind == .file and first.nlink == 1 and second.nlink == 1 and
        first.inode == second.inode and first.size == second.size and
        first.mtime.nanoseconds == second.mtime.nanoseconds and
        first.ctime.nanoseconds == second.ctime.nanoseconds;
}

test "copy package bytes without following file or directory links" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Package/Module");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package/Module/Content.sx", .data = "public func answer() int { return 42 }\n" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Package" });
    defer allocator.free(root);
    const bytes = try copyFile(allocator, std.testing.io, root, "Module/Content.sx");
    defer allocator.free(bytes);
    try std.testing.expectEqualStrings("public func answer() int { return 42 }\n", bytes);
    try std.testing.expectError(error.InvalidPath, copyFile(allocator, std.testing.io, root, "../secret"));
    try std.testing.expectError(error.MissingFile, copyFile(allocator, std.testing.io, root, "Module/Missing.sx"));
    try temporary.dir.symLink(std.testing.io, "Content.sx", "Package/Module/Linked.sx", .{});
    try std.testing.expectError(error.UnsafeEntry, copyFile(allocator, std.testing.io, root, "Module/Linked.sx"));
    try temporary.dir.symLink(std.testing.io, "Module", "Package/LinkedModule", .{ .is_directory = true });
    try std.testing.expectError(error.UnsafeEntry, copyFile(allocator, std.testing.io, root, "LinkedModule/Content.sx"));
    try temporary.dir.hardLink("Package/Module/Content.sx", temporary.dir, "Package/Module/Hard.sx", std.testing.io, .{});
    try std.testing.expectError(error.UnsafeEntry, copyFile(allocator, std.testing.io, root, "Module/Hard.sx"));
}

test "freeze a selected no-Git inventory for source and descriptor" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "LocalDemo/Module");
    try temporary.dir.createDirPath(std.testing.io, "LocalDemo/.silex/cache");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Package.json", .data = "{\"name\":\"LocalDemo\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.44.0\"}}\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Module/Content.sx", .data = "public func answer() int { return 42 }\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Module/Message.txt", .data = "modified local bytes\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/README.md", .data = "Local demo\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/.silex/cache/data", .data = "never publish" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "LocalDemo" });
    defer allocator.free(root);
    const files = try captureSelected(allocator, std.testing.io, root, &.{ "README.md", "Module/Message.txt", "Package.json", "Module/Content.sx" });
    defer {
        for (files) |file| allocator.free(file.bytes);
        allocator.free(files);
    }
    try std.testing.expectEqual(@as(usize, 4), files.len);
    try std.testing.expectEqualStrings("Module/Content.sx", files[0].path);
    try std.testing.expectEqualStrings("modified local bytes\n", files[1].bytes);
    try std.testing.expectEqualStrings("Package.json", files[2].path);
    const source = try Archive.encode(allocator, files);
    defer allocator.free(source);
    const descriptor = try Descriptor.render(allocator, files, source, &.{});
    defer {
        allocator.free(descriptor.json);
        allocator.free(descriptor.digest);
        allocator.free(descriptor.source_digest);
    }
    try std.testing.expect(std.mem.indexOf(u8, descriptor.json, ".silex") == null);
    try std.testing.expect(std.mem.indexOf(u8, descriptor.json, "modified local bytes") == null);
    try std.testing.expectEqual(@as(usize, 64), descriptor.digest.len);
}
