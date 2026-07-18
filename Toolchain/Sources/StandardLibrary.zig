const std = @import("std");
const build_options = @import("build_options");
const Project = @import("Project.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub fn isReservedModule(path: []const u8) bool {
    return isReservedRoot(path, "STD") or isReservedRoot(path, "Silex");
}

pub fn isStandardPath(path: []const u8) bool {
    return isReservedRoot(path, "STD");
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

fn isDirectory(io: Io, path: []const u8) !bool {
    var directory = Io.Dir.cwd().openDir(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => |other| return other,
    };
    directory.close(io);
    return true;
}

fn isReservedRoot(path: []const u8, root_name: []const u8) bool {
    return std.mem.eql(u8, path, root_name) or
        (std.mem.startsWith(u8, path, root_name) and path.len > root_name.len and path[root_name.len] == '.');
}

test "recognize reserved distributed module roots" {
    try std.testing.expect(isReservedModule("STD"));
    try std.testing.expect(isReservedModule("STD.Time"));
    try std.testing.expect(isReservedModule("Silex.Window"));
    try std.testing.expect(!isReservedModule("Random"));
    try std.testing.expect(!isReservedModule("std.Random"));
}
