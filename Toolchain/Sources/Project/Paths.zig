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
    const current_directory = try std.process.currentPathAlloc(io, allocator);
    return findRootFrom(allocator, io, input_path, boundary, current_directory);
}

fn findRootFrom(
    allocator: std.mem.Allocator,
    io: std.Io,
    input_path: []const u8,
    boundary: ?[]const u8,
    current_directory: []const u8,
) anyerror![]const u8 {
    const absolute_input = try std.fs.path.resolve(allocator, &.{ current_directory, input_path });
    const absolute_boundary = if (boundary) |limit|
        try std.fs.path.resolve(allocator, &.{ current_directory, limit })
    else
        null;
    var directory = std.fs.path.dirname(absolute_input) orelse current_directory;
    const fallback = looseRoot(absolute_input);
    while (true) {
        const manifest = try std.fs.path.join(allocator, &.{ directory, "Package.json" });
        if (fileExists(io, manifest)) return displayRoot(allocator, input_path, current_directory, directory);
        if (absolute_boundary) |limit| {
            if (samePath(directory, limit)) return displayRoot(allocator, input_path, current_directory, fallback);
            if (!pathInside(directory, limit)) return displayRoot(allocator, input_path, current_directory, fallback);
        }
        const next = parentDirectory(directory) orelse
            return displayRoot(allocator, input_path, current_directory, fallback);
        if (std.mem.eql(u8, next, directory)) {
            return displayRoot(allocator, input_path, current_directory, fallback);
        }
        directory = next;
    }
}

fn displayRoot(
    allocator: std.mem.Allocator,
    input_path: []const u8,
    current_directory: []const u8,
    root: []const u8,
) ![]const u8 {
    if (std.fs.path.isAbsolute(input_path)) return root;
    const relative = try std.fs.path.relative(
        allocator,
        current_directory,
        null,
        current_directory,
        root,
    );
    return if (relative.len == 0) "." else relative;
}

fn parentDirectory(directory: []const u8) ?[]const u8 {
    if (std.fs.path.dirname(directory)) |parent| return parent;
    if (!std.fs.path.isAbsolute(directory) and !std.mem.eql(u8, directory, ".")) return ".";
    return null;
}

fn looseRoot(input_path: []const u8) []const u8 {
    const directory = std.fs.path.dirname(input_path) orelse ".";
    const basename = std.fs.path.basename(input_path);
    if (!Modules.isFragmentFile(basename)) return directory;
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

test "use the conventional module atom's parent as the loose project root" {
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

test "use an atomized module's parent as the loose project root" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Sandbox/Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Math/@Vec3.sx",
        .data = "func main() {}",
    });
    const workspace = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const sandbox = try std.fs.path.join(allocator, &.{ workspace, "Sandbox" });
    const input = try std.fs.path.join(allocator, &.{ sandbox, "Math", "@Vec3.sx" });

    try std.testing.expectEqualStrings(sandbox, try findRoot(allocator, std.testing.io, input));
    try std.testing.expectEqualStrings(sandbox, try findRootWithin(allocator, std.testing.io, input, workspace));
}

test "continue a relative manifest search through the current directory" {
    try std.testing.expectEqualStrings("/", parentDirectory("/Tests").?);
}

test "find a parent manifest from an entry-directory invocation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Application/Sources/Demo");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Package.json",
        .data = "{}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Sources/Demo/Main.sx",
        .data = "func main() {}",
    });
    const workspace = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const application = try std.fs.path.join(allocator, &.{ workspace, "Application" });
    const entry_directory = try std.fs.path.join(allocator, &.{ application, "Sources", "Demo" });

    try std.testing.expectEqualStrings("../..", try findRootFrom(
        allocator,
        std.testing.io,
        "Main.sx",
        null,
        entry_directory,
    ));
}
