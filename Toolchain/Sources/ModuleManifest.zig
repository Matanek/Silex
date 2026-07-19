const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const filename = "@Module.json";
pub const legacy_filename = "Module.json";

pub const Manifest = struct {
    author: ?[]const u8 = null,
    description: ?[]const u8 = null,
    name: ?[]const u8 = null,
    version: ?[]const u8 = null,
    dependencies: ?std.json.Value = null,
    native: ?std.json.Value = null,
};

pub fn load(allocator: Allocator, io: Io, path: []const u8) !Manifest {
    const contents = try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
    return parse(allocator, contents);
}

pub fn manifestPath(allocator: Allocator, directory: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ directory, filename });
}

pub fn rejectLegacyInDirectory(allocator: Allocator, io: Io, directory: []const u8) !void {
    const legacy_path = try std.fs.path.join(allocator, &.{ directory, legacy_filename });
    _ = Io.Dir.cwd().statFile(io, legacy_path, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return,
        else => |other| return other,
    };
    std.debug.print(
        "silex: legacy module manifest '{s}'; rename it to '{s}'\n",
        .{ legacy_path, filename },
    );
    return error.Reported;
}

pub fn parse(allocator: Allocator, contents: []const u8) !Manifest {
    return std.json.parseFromSliceLeaky(Manifest, allocator, contents, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    });
}

test "module metadata and native configuration are optional" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const metadata = try parse(allocator, "{\"author\":\"Ada Lovelace\",\"description\":\"Mathematics\"}");
    try std.testing.expect(metadata.native == null);

    const configured = try parse(allocator, "{\"native\":{}}");
    try std.testing.expect(configured.native != null);

    if (parse(allocator, "{\"unknown\":true}")) |_| {
        return error.TestExpectedError;
    } else |_| {}

    const package = try parse(
        allocator,
        "{\"name\":\"Foundation\",\"version\":\"1.2.3\",\"dependencies\":{\"Utility\":{\"path\":\"../Utility\"}}}",
    );
    try std.testing.expectEqualStrings("Foundation", package.name.?);
    try std.testing.expectEqualStrings("1.2.3", package.version.?);
    try std.testing.expect(package.dependencies != null);
}
