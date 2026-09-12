const std = @import("std");

pub fn prepareWorkspaceLinks(
    allocator: std.mem.Allocator,
    io: std.Io,
    project_root: []const u8,
) !void {
    const links_root = try std.fs.path.join(allocator, &.{ project_root, ".silex", "links" });
    var created = false;
    try linkChildren(allocator, io, project_root, links_root, &created);
    if (std.fs.path.dirname(project_root)) |parent| {
        // std.testing.tmpDir owns one child of this shared directory. Its
        // siblings are unrelated fixtures, not packages in this workspace.
        const temporary_root = try std.fs.path.resolve(allocator, &.{ ".zig-cache", "tmp" });
        const absolute_parent = try std.fs.path.resolve(allocator, &.{parent});
        if (!std.mem.eql(u8, parent, project_root) and !std.mem.eql(u8, absolute_parent, temporary_root)) {
            try linkChildren(allocator, io, parent, links_root, &created);
        }
    }
}

fn linkChildren(
    allocator: std.mem.Allocator,
    io: std.Io,
    root: []const u8,
    links_root: []const u8,
    created: *bool,
) !void {
    var directory = std.Io.Dir.cwd().openDir(io, root, .{ .iterate = true }) catch return;
    defer directory.close(io);
    var iterator = directory.iterateAssumeFirstIteration();
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .directory or std.mem.eql(u8, entry.name, ".silex")) continue;
        const package_root = try std.fs.path.join(allocator, &.{ root, entry.name });
        const manifest_path = try std.fs.path.join(allocator, &.{ package_root, "Package.json" });
        const source = std.Io.Dir.cwd().readFileAlloc(io, manifest_path, allocator, .limited(1024 * 1024)) catch continue;
        const Identity = struct { name: ?[]const u8 = null };
        const identity = std.json.parseFromSliceLeaky(Identity, allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        }) catch continue;
        const name = identity.name orelse continue;
        if (!created.*) {
            try std.Io.Dir.cwd().createDirPath(io, links_root);
            created.* = true;
        }
        const link_name = try std.fmt.allocPrint(allocator, "{s}.json", .{name});
        const link_path = try std.fs.path.join(allocator, &.{ links_root, link_name });
        const payload = try std.json.Stringify.valueAlloc(allocator, .{ .path = package_root }, .{});
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = link_path, .data = payload });
    }
}

test "workspace links stay inside their temporary fixture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    var unrelated = std.testing.tmpDir(.{});
    defer unrelated.cleanup();
    try unrelated.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"name\":\"UnrelatedFixture\"}",
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &fixture.sub_path });
    try prepareWorkspaceLinks(allocator, std.testing.io, root);
    try std.testing.expectError(error.FileNotFound, fixture.dir.readFileAlloc(
        std.testing.io,
        ".silex/links/UnrelatedFixture.json",
        allocator,
        .limited(1024),
    ));
}

test "workspace links include sibling packages and refresh changed fixtures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var fixture = std.testing.tmpDir(.{});
    defer fixture.cleanup();
    try fixture.dir.createDirPath(std.testing.io, "App/Child");
    try fixture.dir.createDirPath(std.testing.io, "Api");
    try fixture.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Package.json", .data = "{\"name\":\"Api\"}" });
    try fixture.dir.writeFile(std.testing.io, .{ .sub_path = "App/Child/Package.json", .data = "{\"name\":\"Child\"}" });
    const root = try std.fs.path.resolve(allocator, &.{ ".zig-cache", "tmp", &fixture.sub_path, "App" });
    try prepareWorkspaceLinks(allocator, std.testing.io, root);
    inline for (.{ "Api", "Child" }) |name| {
        const payload = try fixture.dir.readFileAlloc(std.testing.io, "App/.silex/links/" ++ name ++ ".json", allocator, .limited(4096));
        const link = try std.json.parseFromSliceLeaky(struct { path: []const u8 }, allocator, payload, .{});
        try std.testing.expectEqualStrings(name, std.fs.path.basename(link.path));
    }
    try fixture.dir.createDirPath(std.testing.io, "Later");
    try fixture.dir.writeFile(std.testing.io, .{ .sub_path = "Later/Package.json", .data = "{\"name\":\"Later\"}" });
    try prepareWorkspaceLinks(allocator, std.testing.io, root);
    _ = try fixture.dir.readFileAlloc(std.testing.io, "App/.silex/links/Later.json", allocator, .limited(4096));
}
