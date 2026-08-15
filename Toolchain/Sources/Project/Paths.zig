const std = @import("std");
const Modules = @import("../Modules.zig");

pub fn findRoot(allocator: std.mem.Allocator, io: std.Io, input_path: []const u8) anyerror![]const u8 {
    return findRootWithin(allocator, io, input_path, null);
}

pub fn findRootWithin(
    allocator: std.mem.Allocator,
    io: std.Io,
    input_path: []const u8,
    boundary: ?[]const u8,
) anyerror![]const u8 {
    var directory = std.fs.path.dirname(input_path) orelse ".";
    const fallback = looseRoot(input_path);
    while (true) {
        const manifest = try std.fs.path.join(allocator, &.{ directory, "Package.json" });
        if (fileExists(io, manifest)) return directory;
        if (boundary) |limit| {
            if (samePath(directory, limit)) return fallback;
            if (!pathInside(directory, limit)) return fallback;
        }
        const next = std.fs.path.dirname(directory) orelse return fallback;
        if (std.mem.eql(u8, next, directory)) return fallback;
        directory = next;
    }
}

fn looseRoot(input_path: []const u8) []const u8 {
    const directory = std.fs.path.dirname(input_path) orelse ".";
    const basename = std.fs.path.basename(input_path);
    if (!std.mem.eql(u8, basename, Modules.principal_file) and
        !std.mem.eql(u8, basename, Modules.principal_file_capitalized)) return directory;
    return std.fs.path.dirname(directory) orelse directory;
}

fn samePath(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, std.mem.trimEnd(u8, left, "/"), std.mem.trimEnd(u8, right, "/"));
}

fn pathInside(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory) or path.len <= directory.len) return false;
    return path[directory.len] == std.fs.path.sep;
}

fn fileExists(io: std.Io, path: []const u8) bool {
    _ = std.Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

test "use a principal module's parent as the loose project root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Sandbox/MonModule");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/MonModule/@Module.sx",
        .data = "func main() {}",
    });
    const workspace = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const sandbox = try std.fs.path.join(allocator, &.{ workspace, "Sandbox" });
    const input = try std.fs.path.join(allocator, &.{ sandbox, "MonModule", "@Module.sx" });

    try std.testing.expectEqualStrings(sandbox, try findRoot(allocator, std.testing.io, input));
    try std.testing.expectEqualStrings(
        sandbox,
        try findRootWithin(allocator, std.testing.io, input, workspace),
    );
}
