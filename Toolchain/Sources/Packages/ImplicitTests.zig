const std = @import("std");
const Packages = @import("../Packages.zig");

test "expose the newest compatible global package to a loose project" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Sandbox");
    try temporary.dir.createDirPath(std.testing.io, "Global/STD@0.16.0/Module");
    try temporary.dir.createDirPath(std.testing.io, "Global/STD@0.16.2/Module");
    try temporary.dir.createDirPath(std.testing.io, "Global/STD@0.17.0/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/STD@0.16.0/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.16.0\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/STD@0.16.2/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.16.2\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/STD@0.17.0/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.17.0\",\"requires\":{\"silex\":\">=99.0.0\"}}",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const sandbox = try std.fs.path.join(allocator, &.{ base, "Sandbox" });
    const global = try std.fs.path.join(allocator, &.{ base, "Global" });
    var resolver = Packages.Resolver.init(allocator, std.testing.io, global);
    const graph = try resolver.resolve(sandbox);

    try std.testing.expectEqual(@as(usize, 2), graph.packages.len);
    try std.testing.expectEqualStrings("STD", graph.packages[1].name.?);
    try std.testing.expect(graph.packages[1].version.?.eql(try Packages.Version.parse("0.16.2")));
    try std.testing.expectEqual(Packages.Origin.installed, graph.packages[1].origin);
    try std.testing.expectEqual(@as(usize, 1), graph.packages[0].dependencies.len);
    try std.testing.expectEqualStrings("STD", graph.packages[0].dependencies[0].name);
}

test "prefer a linked package in a loose project" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Sandbox");
    try temporary.dir.createDirPath(std.testing.io, "Silex/links");
    try temporary.dir.createDirPath(std.testing.io, "Silex/packages/STD@0.16.0/Module");
    try temporary.dir.createDirPath(std.testing.io, "Checkout/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Silex/packages/STD@0.16.0/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.16.0\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Checkout/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.16.2\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const checkout = try std.fs.path.join(allocator, &.{ base, "Checkout" });
    const link_source = try std.json.Stringify.valueAlloc(allocator, .{ .path = checkout }, .{});
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Silex/links/STD.json",
        .data = link_source,
    });
    const sandbox = try std.fs.path.join(allocator, &.{ base, "Sandbox" });
    const global = try std.fs.path.join(allocator, &.{ base, "Silex", "packages" });
    var resolver = Packages.Resolver.init(allocator, std.testing.io, global);
    const graph = try resolver.resolve(sandbox);

    try std.testing.expectEqual(@as(usize, 2), graph.packages.len);
    try std.testing.expectEqualStrings(checkout, graph.packages[1].root);
    try std.testing.expect(graph.packages[1].version.?.eql(try Packages.Version.parse("0.16.2")));
    try std.testing.expectEqual(Packages.Origin.user_link, graph.packages[1].origin);
}

test "workspace links override user links without leaking into another workspace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "WorkspaceA/Sandbox");
    try temporary.dir.createDirPath(std.testing.io, "WorkspaceA/.silex/links");
    try temporary.dir.createDirPath(std.testing.io, "WorkspaceB/Sandbox");
    try temporary.dir.createDirPath(std.testing.io, "Home/.silex/links");
    try temporary.dir.createDirPath(std.testing.io, "Home/.silex/packages/STD@1.0.0/Module");
    try temporary.dir.createDirPath(std.testing.io, "UserCheckout/Module");
    try temporary.dir.createDirPath(std.testing.io, "WorkspaceCheckout/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Home/.silex/packages/STD@1.0.0/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "UserCheckout/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"1.1.0\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "WorkspaceCheckout/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"1.2.0\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });

    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const user_checkout = try std.fs.path.join(allocator, &.{ base, "UserCheckout" });
    const workspace_checkout = try std.fs.path.join(allocator, &.{ base, "WorkspaceCheckout" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Home/.silex/links/STD.json",
        .data = try std.json.Stringify.valueAlloc(allocator, .{ .path = user_checkout }, .{}),
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "WorkspaceA/.silex/links/STD.json",
        .data = try std.json.Stringify.valueAlloc(allocator, .{ .path = workspace_checkout }, .{}),
    });

    const packages_root = try std.fs.path.join(allocator, &.{ base, "Home", ".silex", "packages" });
    const workspace_a = try std.fs.path.join(allocator, &.{ base, "WorkspaceA", "Sandbox" });
    var resolver = Packages.Resolver.init(allocator, std.testing.io, packages_root);
    const graph_a = try resolver.resolve(workspace_a);
    try std.testing.expectEqualStrings(workspace_checkout, graph_a.packages[1].root);
    try std.testing.expectEqual(Packages.Origin.workspace_link, graph_a.packages[1].origin);

    const workspace_b = try std.fs.path.join(allocator, &.{ base, "WorkspaceB", "Sandbox" });
    resolver = Packages.Resolver.init(allocator, std.testing.io, packages_root);
    const graph_b = try resolver.resolve(workspace_b);
    try std.testing.expectEqualStrings(user_checkout, graph_b.packages[1].root);
    try std.testing.expectEqual(Packages.Origin.user_link, graph_b.packages[1].origin);
}
