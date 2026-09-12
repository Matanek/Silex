const std = @import("std");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");
const Types = @import("../Types.zig");
const ProjectIndex = @import("../ProjectIndex.zig");

test "invalid source paths report diagnostics without disabling package completion" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try temporary.dir.createDirPath(std.testing.io, "Workspace/Sandbox");
    try temporary.dir.createDirPath(std.testing.io, "Global/GFX@1.0.0/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/GFX@1.0.0/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/GFX@1.0.0/Module/@Module.sx",
        .data = "public struct Color {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Global/GFX@1.0.0/Module/Broken-Source.sx",
        .data = "public struct Hidden {}",
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const global = try std.fs.path.join(allocator, &.{ base, "Global" });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}/Workspace", .{base});
    var server = ServerModule.Server.initWithPackages(std.testing.allocator, std.testing.io, global);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);

    // The invalid file remains a neighbor when the valid and dotted names open.
    for ([_][]const u8{ "Test-01.sx", "Test_01.sx", "Test.Nested.sx", "Unsaved-01.sx" }, 0..) |name, index| {
        if (index != 3) try temporary.dir.writeFile(std.testing.io, .{
            .sub_path = try std.fmt.allocPrint(allocator, "Workspace/Sandbox/{s}", .{name}),
            .data = "func main() {}",
        });
        const uri = try std.fmt.allocPrint(allocator, "{s}/Sandbox/{s}", .{ root_uri, name });
        const request = try std.json.Stringify.valueAlloc(allocator, .{
            .jsonrpc = "2.0",
            .method = "textDocument/didOpen",
            .params = .{ .textDocument = .{ .uri = uri, .version = 1, .text = "func main() {}" } },
        }, .{});
        const response = (try server.handleBody(allocator, request)).?;
        const parsed = try std.json.parseFromSliceLeaky(struct {
            params: struct { uri: []const u8, version: i64, diagnostics: []const Types.Diagnostic },
        }, allocator, response, .{ .ignore_unknown_fields = true });
        try std.testing.expectEqualStrings(uri, parsed.params.uri);
        try std.testing.expectEqual(@as(i64, 1), parsed.params.version);
        const invalid = index == 0 or index == 3;
        try std.testing.expectEqual(@as(usize, if (invalid) 1 else 0), parsed.params.diagnostics.len);
        if (invalid) {
            const diagnostic = parsed.params.diagnostics[0];
            try std.testing.expectEqual(@as(u8, 1), diagnostic.severity);
            try std.testing.expect(std.mem.indexOf(u8, diagnostic.message, name) != null);
            try std.testing.expect(std.mem.indexOf(u8, diagnostic.message, "module name") != null);
        }

        for ([_][]const u8{ "use G<|>\n\nfunc main() {}", "use <|>\n\nfunc main() {}" }, 0..) |partial, edit| {
            const marked = try Support.removeMarker(allocator, partial);
            try Support.changeDocument(&server, allocator, uri, @intCast(edit + 2), marked.text);
            const items = if (edit == 0)
                try Support.serverCompletionInOpenDocument(&server, allocator, uri, marked)
            else
                try Support.serverCompletionInOpenDocumentAfterTrigger(&server, allocator, uri, marked, " ");
            if (edit == 0) try Support.expectExactLabels(&.{"GFX"}, items);
            const gfx = for (items) |item| {
                if (std.mem.eql(u8, item.label, "GFX")) break item;
            } else {
                std.debug.print("missing GFX in {s}, edit {d}\n", .{ name, edit });
                try Support.expectPresent("GFX", items);
                return error.MissingGfxCompletion;
            };
            try std.testing.expectEqual(@as(u8, 9), gfx.kind);
            try std.testing.expectEqualStrings("GFX", gfx.insertText.?);
            try std.testing.expectEqualStrings("GFX", gfx.filterText.?);
            try std.testing.expect(gfx.insertTextFormat == null);
            try Support.expectAbsent("Test-01", items);
            try Support.expectAbsent("Unsaved-01", items);
            try Support.expectAbsent("main", items);
            const repeated = try Support.serverCompletionInOpenDocument(&server, allocator, uri, marked);
            try std.testing.expectEqualStrings(
                try std.json.Stringify.valueAlloc(allocator, items, .{}),
                try std.json.Stringify.valueAlloc(allocator, repeated, .{}),
            );
        }
    }
}

test "source path diagnostics respect package roots dotted names and atoms" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try temporary.dir.createDirPath(std.testing.io, "Parent-Directory/Example/Module/Bad-Dir");
    try temporary.dir.createDirPath(std.testing.io, "Parent-Directory/Example/Module/Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Parent-Directory/Example/Package.json",
        .data = "{\"name\":\"Example\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    const root = try std.fmt.allocPrint(allocator, "file://.zig-cache/tmp/{s}/Parent-Directory/Example", .{temporary.sub_path});
    // Source paths are relative to Module, not to ancestor directories of the package.
    // These URIs intentionally have no corresponding source file on disk.
    for ([_][]const u8{ "Test_01.sx", "Math.Geometry.sx", "@Module.sx", "Math/@Value.sx", "Test-01.sx", "Bad-Dir/Value.sx", "Math/@bad-name.sx", "Test%20File.sx" }, 0..) |path, index| {
        const uri = try std.fmt.allocPrint(allocator, "{s}/Module/{s}", .{ root, path });
        const invalid = try ProjectIndex.invalidSourcePath(allocator, std.testing.io, null, .macos_arm64, root, uri);
        try std.testing.expectEqual(index >= 4, invalid != null);
        if (invalid) |relative| try std.testing.expectEqualStrings(if (index == 7) "Test File.sx" else path, relative);
    }
}
