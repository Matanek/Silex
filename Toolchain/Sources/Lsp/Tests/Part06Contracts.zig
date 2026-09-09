const std = @import("std");
const Protocol = @import("../Protocol.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

test "part 06 every advertised trigger reaches its exact completion context" {
    const cases = [_]struct {
        trigger: []const u8,
        source: []const u8,
        required: []const []const u8,
        forbidden: []const []const u8,
        exact: bool = false,
    }{
        .{
            .trigger = ".",
            .source = "class Brush { func paint() {} }\nfunc main() { Brush().<|> }",
            .required = &.{"paint"},
            .forbidden = &.{ "Brush", "if" },
            .exact = true,
        },
        .{
            .trigger = ":",
            .source = "struct Pixel { let color:<|> }",
            .required = &.{"str"},
            .forbidden = &.{ "if", "while" },
        },
        .{
            .trigger = "<",
            .source = "struct Box<T> { let value:T }\nfunc main() { let box = Box<<|> }",
            .required = &.{"int"},
            .forbidden = &.{ "if", "while" },
        },
        .{
            .trigger = ",",
            .source = "func spawn(health:int, force:int) {}\nfunc main() { spawn(health:100,<|>) }",
            .required = &.{"force"},
            .forbidden = &.{"health"},
        },
        .{
            .trigger = " ",
            .source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() <|> }",
            .required = &.{ "else", "else error" },
            .forbidden = &.{ "public", "read" },
            .exact = true,
        },
        .{
            .trigger = ")",
            .source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read()<|> }",
            .required = &.{ "else", "else error" },
            .forbidden = &.{ "public", "read" },
            .exact = true,
        },
        .{
            .trigger = "e",
            .source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() e<|> }",
            .required = &.{ "else", "else error" },
            .forbidden = &.{ "public", "read" },
            .exact = true,
        },
    };

    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(allocator, "file:///Part06-Trigger-{d}.sx", .{index});
        const items = try Support.serverCompletionAfterTrigger(
            &server,
            allocator,
            uri,
            case.source,
            case.trigger,
        );
        if (case.exact) {
            try Support.expectExactLabels(case.required, items);
        } else {
            for (case.required) |label| try Support.expectPresent(label, items);
        }
        if (std.mem.eql(u8, case.trigger, ",")) try Support.expectFirst("force", items);
        for (case.forbidden) |label| try Support.expectAbsent(label, items);
        try Support.expectNoDuplicates(items);
    }
}

test "part 06 UTF-16 completion metadata and JSON response are byte deterministic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const uri = "file:///Part06-Unicode.sx";
    const marked = try Support.removeMarker(
        allocator,
        "func paint() {}\nfunc main() { print(\"pre\u{0302}t 🙂\"); pai<|> }",
    );
    try Support.openDocument(&server, allocator, uri, 41, marked.text);

    const items = try Support.serverCompletionInOpenDocument(&server, allocator, uri, marked);
    try Support.expectExactLabels(&.{"paint"}, items);
    try Support.expectItem(.{
        .label = "paint",
        .kind = 3,
        .detail = "paint() void",
        .insert_text = "paint()",
    }, items);
    try Support.expectNoDuplicates(items);

    const first = try rawCompletionResponse(&server, allocator, uri, marked);
    const repeated = try rawCompletionResponse(&server, allocator, uri, marked);
    try std.testing.expectEqualStrings(first, repeated);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"isIncomplete\":false") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"label\":\"paint\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"kind\":3") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"detail\":\"paint() void\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"sortText\":\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"filterText\":\"paint\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, first, "\"insertText\":\"paint()\"") != null);
}

test "part 06 contextual alternatives expose exact kinds details snippets and stable order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const uri = "file:///Part06-Try.sx";
    const items = try Support.serverCompletionAfterTrigger(
        &server,
        allocator,
        uri,
        "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() <|> }",
        " ",
    );
    try Support.expectExactLabels(&.{ "else", "else error" }, items);
    try Support.expectItem(.{
        .label = "else",
        .kind = 14,
        .detail = "Silex fallback branch",
        .insert_text = "else {$0}",
        .insert_text_format = 2,
    }, items);
    try Support.expectItem(.{
        .label = "else error",
        .kind = 14,
        .detail = "Silex fallback branch with implicit error binding",
        .insert_text = "else error {$0}",
        .insert_text_format = 2,
    }, items);
    try std.testing.expect(std.mem.lessThan(u8, items[0].sortText.?, items[1].sortText.?));
}

fn rawCompletionResponse(
    server: *ServerModule.Server,
    allocator: std.mem.Allocator,
    uri: []const u8,
    source: Support.MarkedSource,
) ![]const u8 {
    const position = Protocol.positionAtByteOffset(source.text, source.cursor, .utf16) orelse
        return error.InvalidCompletionPosition;
    const request = try std.json.Stringify.valueAlloc(allocator, .{
        .jsonrpc = "2.0",
        .id = 61,
        .method = "textDocument/completion",
        .params = .{
            .textDocument = .{ .uri = uri },
            .position = position,
            .context = .{ .triggerKind = 1 },
        },
    }, .{});
    return (try server.handleBody(allocator, request)) orelse error.MissingLspResponse;
}
