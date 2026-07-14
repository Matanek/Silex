const std = @import("std");
const build_options = @import("build_options");
const Project = @import("Project.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub fn isModule(path: []const u8) bool {
    return std.mem.eql(u8, path, "std") or std.mem.startsWith(u8, path, "std.");
}

pub fn root(allocator: Allocator, io: Io) ![]const u8 {
    const executable_directory = try std.process.executableDirPathAlloc(io, allocator);
    const installed_root = try std.fs.path.resolve(allocator, &.{
        executable_directory,
        "..",
        "lib",
        "silex",
    });
    if (try isDirectory(io, installed_root)) return installed_root;

    if (build_options.developer_standard_library_root.len > 0 and
        try isDirectory(io, build_options.developer_standard_library_root))
    {
        return try allocator.dupe(u8, build_options.developer_standard_library_root);
    }
    return error.StandardLibraryNotFound;
}

pub fn runtimeSources(
    allocator: Allocator,
    io: Io,
    modules: []const Project.Module,
) ![]const []const u8 {
    var has_standard_module = false;
    for (modules) |module| if (isModule(module.name)) {
        has_standard_module = true;
        break;
    };
    if (!has_standard_module) return &.{};

    const standard_library_root = try root(allocator, io);
    var sources: std.ArrayList([]const u8) = .empty;
    for (modules) |module| {
        if (!isModule(module.name)) continue;
        const module_directory = try moduleDirectory(allocator, standard_library_root, module.name);
        var directory = Io.Dir.cwd().openDir(io, module_directory, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => continue,
            else => |other| return other,
        };
        defer directory.close(io);

        var iterator = directory.iterateAssumeFirstIteration();
        while (try iterator.next(io)) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".cpp")) continue;
            try sources.append(allocator, try std.fs.path.join(allocator, &.{ module_directory, entry.name }));
        }
    }
    std.mem.sort([]const u8, sources.items, {}, struct {
        fn lessThan(_: void, left: []const u8, right: []const u8) bool {
            return std.mem.lessThan(u8, left, right);
        }
    }.lessThan);
    return sources.toOwnedSlice(allocator);
}

fn moduleDirectory(allocator: Allocator, module_root: []const u8, module_name: []const u8) ![]const u8 {
    const relative_path = try allocator.dupe(u8, module_name);
    for (relative_path) |*character| {
        if (character.* == '.') character.* = std.fs.path.sep;
    }
    return std.fs.path.join(allocator, &.{ module_root, relative_path });
}

fn isDirectory(io: Io, path: []const u8) !bool {
    var directory = Io.Dir.cwd().openDir(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => |other| return other,
    };
    directory.close(io);
    return true;
}

test "recognize the standard module namespace" {
    try std.testing.expect(isModule("std"));
    try std.testing.expect(isModule("std.Random"));
    try std.testing.expect(!isModule("Random"));
    try std.testing.expect(!isModule("stdlib.Random"));
}
