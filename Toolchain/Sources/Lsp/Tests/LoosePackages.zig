const std = @import("std");
const Workspace = @import("../Workspace.zig");

test "complete installed packages from a loose principal module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Workspace/Sandbox/MonModule");
    try temporary.dir.createDirPath(std.testing.io, "Global/STD@0.16.2/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Workspace/Sandbox/MonModule/@Module.sx",
        .data = "use S",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/STD@0.16.2/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.16.2\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/STD@0.16.2/Module/Value.sx",
        .data = "public func answer() int { return 42 }",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const workspace = try std.fs.path.join(allocator, &.{ base, "Workspace" });
    const document = try std.fs.path.join(allocator, &.{ workspace, "Sandbox", "MonModule", "@Module.sx" });
    const global = try std.fs.path.join(allocator, &.{ base, "Global" });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{workspace});
    const document_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{document});
    const source = "use S";
    const items = (try Workspace.itemsAt(
        allocator,
        std.testing.io,
        global,
        root_uri,
        document_uri,
        &.{},
        source,
        source.len,
    )).?;

    try std.testing.expectEqual(@as(usize, 1), items.len);
    try std.testing.expectEqualStrings("STD", items[0].label);
}
