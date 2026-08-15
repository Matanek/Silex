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
        if (!std.mem.eql(u8, parent, project_root)) try linkChildren(allocator, io, parent, links_root, &created);
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
