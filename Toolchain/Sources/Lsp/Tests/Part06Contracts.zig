const std = @import("std");
const Protocol = @import("../Protocol.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");
const Types = @import("../Types.zig");

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

test "part 06 insertion distinguishes calls existing parentheses labels constructors and references" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const uri = "file:///Part06-Insertion.sx";
    const declarations =
        \\class Widget { init(name:str) {} }
        \\func paint() {}
        \\func tint(color:int, intensity:float = 1.0) {}
        \\func accept(callback:func()) {}
    ;

    const plain = try Support.removeMarker(
        allocator,
        declarations ++ "\nfunc main() { pai<|> }",
    );
    try Support.openDocument(&server, allocator, uri, 1, plain.text);
    const plain_items = try Support.serverCompletionInOpenDocument(&server, allocator, uri, plain);
    try Support.expectExactLabels(&.{"paint"}, plain_items);
    try Support.expectItem(.{
        .label = "paint",
        .kind = 3,
        .detail = "paint() void",
        .insert_text = "paint()",
    }, plain_items);

    const existing_call = try Support.removeMarker(
        allocator,
        declarations ++ "\nfunc main() { paint<|>() }",
    );
    try Support.changeDocument(&server, allocator, uri, 2, existing_call.text);
    const existing_items = try Support.serverCompletionInOpenDocument(&server, allocator, uri, existing_call);
    try Support.expectExactLabels(&.{"paint"}, existing_items);
    try Support.expectItem(.{
        .label = "paint",
        .kind = 3,
        .detail = "paint() void",
        .insert_text = "paint",
    }, existing_items);

    const callback = try Support.removeMarker(
        allocator,
        declarations ++ "\nfunc main() { accept(callback:pai<|>) }",
    );
    try Support.changeDocument(&server, allocator, uri, 3, callback.text);
    const callback_items = try Support.serverCompletionInOpenDocument(&server, allocator, uri, callback);
    try Support.expectExactLabels(&.{"paint"}, callback_items);
    try Support.expectItem(.{
        .label = "paint",
        .kind = 3,
        .detail = "paint() void",
        .insert_text = "paint",
    }, callback_items);

    const labeled = try Support.removeMarker(
        allocator,
        declarations ++ "\nfunc main() { tin<|> }",
    );
    try Support.changeDocument(&server, allocator, uri, 4, labeled.text);
    const labeled_items = try Support.serverCompletionInOpenDocument(&server, allocator, uri, labeled);
    try Support.expectExactLabels(&.{ "tint(color:int)", "tint(color:int, intensity:float = 1.0)" }, labeled_items);
    try expectCompletionForm(labeled_items, "tint", "tint(${1:color})$0", 2);
    try expectCompletionForm(labeled_items, "tint", "tint(${1:color}, ${2:intensity})$0", 2);

    const constructor = try Support.removeMarker(
        allocator,
        declarations ++ "\nfunc main() { Wid<|> }",
    );
    try Support.changeDocument(&server, allocator, uri, 5, constructor.text);
    const constructor_items = try Support.serverCompletionInOpenDocument(&server, allocator, uri, constructor);
    try expectCompletionForm(constructor_items, "Widget", "Widget(${1:name})$0", 2);
    try Support.expectNoDuplicates(constructor_items);

    const type_name = try Support.removeMarker(
        allocator,
        declarations ++ "\nfunc inspect(widget:Wid<|>) {}",
    );
    try Support.changeDocument(&server, allocator, uri, 6, type_name.text);
    const type_items = try Support.serverCompletionInOpenDocument(&server, allocator, uri, type_name);
    try Support.expectExactLabels(&.{"Widget"}, type_items);
    try expectCompletionForm(type_items, "Widget", "Widget", null);
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

fn expectCompletionForm(
    items: []const Types.CompletionItem,
    filter: []const u8,
    insertion: []const u8,
    format: ?u8,
) !void {
    for (items) |item| {
        if (item.filterText == null or !std.mem.eql(u8, item.filterText.?, filter)) continue;
        if (item.insertText == null or !std.mem.eql(u8, item.insertText.?, insertion)) continue;
        try std.testing.expectEqual(format, item.insertTextFormat);
        return;
    }
    std.debug.print("missing completion form filter='{s}' insertion='{s}'\n", .{ filter, insertion });
    for (items) |item| std.debug.print("  label='{s}' filter='{s}' insert='{s}' detail='{s}'\n", .{
        item.label,
        item.filterText orelse "<none>",
        item.insertText orelse "<none>",
        item.detail,
    });
    return error.MissingCompletionForm;
}
