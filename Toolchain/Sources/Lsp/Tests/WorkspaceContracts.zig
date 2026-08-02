const std = @import("std");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

test "server preserves prefix ranking in the response consumed by Zed" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletion(&server, allocator, uri,
        \\func main() {
        \\    l<|>
        \\}
    );
    try Support.expectExactLabels(&.{ "let", "Result" }, items);
    try Support.expectFirst("let", items);
    try Support.expectNoDuplicates(items);
}

test "server resolves a UTF-16 completion position after non-ASCII text" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletion(&server, allocator, uri,
        \\func test(value:str = "😀") i<|>
    );
    try Support.expectFirst("int", items);
    try Support.expectPresent("int32", items);
    try Support.expectAbsent("if", items);
}

test "type contexts expose modules as paths without leaking module values" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Math/Shapes");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Vector.sx",
        .data =
        \\public struct Vector {}
        \\public enum Axis { x; y }
        \\public func make_vector() Vector { return Vector() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Shapes/Circle.sx",
        .data = "public struct Circle {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);

    const return_context_items = try Support.serverCompletion(&server, allocator, uri,
        \\struct LocalType {}
        \\func make_value() LocalType { return LocalType() }
        \\func test() <|>
    );
    try Support.expectPresent("LocalType", return_context_items);
    try Support.expectPresent("Math", return_context_items);
    try Support.expectPresent("Result", return_context_items);
    try Support.expectPresent("int", return_context_items);
    try Support.expectAbsent("make_value", return_context_items);
    try Support.expectAbsent("true", return_context_items);
    try Support.expectAbsent("if", return_context_items);
    try Support.expectNoDuplicates(return_context_items);

    const root_items = try Support.serverCompletion(&server, allocator, uri, "func test() M<|>");
    try Support.expectExactLabels(&.{"Math"}, root_items);
    try Support.expectAbsent("make_vector", root_items);

    const qualified_items = try Support.serverCompletion(
        &server,
        allocator,
        uri,
        "func test() Result<Math.<|>>",
    );
    try Support.expectExactLabels(&.{ "Shapes", "Vector" }, qualified_items);
    try Support.expectAbsent("make_vector", qualified_items);
    try Support.expectAbsent("x", qualified_items);
    try Support.expectAbsent("if", qualified_items);
    try Support.expectNoDuplicates(qualified_items);

    const provider_items = try Support.serverCompletion(
        &server,
        allocator,
        uri,
        "func test() Result<Math.Vector.<|>>",
    );
    try Support.expectPresent("Axis", provider_items);
    try Support.expectAbsent("make_vector", provider_items);
    try Support.expectNoDuplicates(provider_items);
}

test "field parameter and generic annotations expose module paths to types" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Domain");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Domain/Message.sx",
        .data = "public struct Message {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);

    const sources = [_][]const u8{
        \\struct Error {
        \\    let message:<|>
        \\}
        ,
        \\func report(message:<|>) {}
        ,
        \\func draw<T:<|>>() {}
        ,
    };
    for (sources) |source| {
        const items = try Support.serverCompletion(&server, allocator, uri, source);
        try Support.expectPresent("Domain", items);
        try Support.expectPresent("Result", items);
        try Support.expectPresent("str", items);
        try Support.expectAbsent("Message", items);
        try Support.expectAbsent("if", items);
        try Support.expectNoDuplicates(items);
    }

    const qualified_sources = [_][]const u8{
        \\struct Error {
        \\    let message:Domain.<|>
        \\}
        ,
        \\func report(message:Domain.<|>) {}
        ,
        \\func draw<T:Domain.<|>>() {}
        ,
    };
    for (qualified_sources) |source| {
        const items = try Support.serverCompletion(&server, allocator, uri, source);
        try Support.expectExactLabels(&.{"Message"}, items);
    }
}

test "workspace completion uses the unsaved contents of imported documents" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public struct DiskType {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const api_uri = try std.fmt.allocPrint(allocator, "file://{s}/Api.sx", .{root});
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    try Support.openDocument(&server, allocator, api_uri, 1, "public struct PreviousBufferType {}");
    try Support.changeDocument(&server, allocator, api_uri, 2, "public struct BufferType {}");

    const marked = try Support.removeMarker(allocator,
        \\use Api
        \\func test() Result<Api.<|>, str>
    );
    try Support.openDocument(&server, allocator, main_uri, 1, marked.text);
    const items = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"BufferType"}, items);
    try Support.expectAbsent("DiskType", items);
    try Support.expectAbsent("PreviousBufferType", items);
    try Support.expectNoDuplicates(items);
}
