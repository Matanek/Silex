const std = @import("std");
const Ast = @import("../Ast.zig");
const LexerModule = @import("../Lexer.zig");
const ParserModule = @import("../Parser.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const CompletionItem = Types.CompletionItem;

const language_items = [_]CompletionItem{
    .{ .label = "func", .kind = 14, .detail = "Silex declaration" },
    .{ .label = "public", .kind = 14, .detail = "Silex visibility" },
    .{ .label = "use", .kind = 14, .detail = "Silex module import" },
    .{ .label = "as", .kind = 14, .detail = "Silex conversion or alias" },
    .{ .label = "let", .kind = 14, .detail = "Silex immutable binding" },
    .{ .label = "if", .kind = 14, .detail = "Silex conditional" },
    .{ .label = "elif", .kind = 14, .detail = "Silex conditional branch" },
    .{ .label = "else", .kind = 14, .detail = "Silex conditional branch" },
    .{ .label = "return", .kind = 14, .detail = "Silex return statement" },
    .{ .label = "true", .kind = 12, .detail = "Silex bool value" },
    .{ .label = "false", .kind = 12, .detail = "Silex bool value" },
    .{ .label = "print", .kind = 3, .detail = "Silex observable effect" },
    .{ .label = "assert", .kind = 3, .detail = "Silex observable effect" },
    .{ .label = "panic", .kind = 3, .detail = "Silex observable effect" },
    .{ .label = "void", .kind = 14, .detail = "Silex type" },
    .{ .label = "bool", .kind = 14, .detail = "Silex type" },
    .{ .label = "str", .kind = 14, .detail = "Silex type" },
    .{ .label = "int", .kind = 14, .detail = "Silex type" },
    .{ .label = "int8", .kind = 14, .detail = "Silex type" },
    .{ .label = "int16", .kind = 14, .detail = "Silex type" },
    .{ .label = "int32", .kind = 14, .detail = "Silex type" },
    .{ .label = "int64", .kind = 14, .detail = "Silex type alias" },
    .{ .label = "uint", .kind = 14, .detail = "Silex type" },
    .{ .label = "uint8", .kind = 14, .detail = "Silex type" },
    .{ .label = "uint16", .kind = 14, .detail = "Silex type" },
    .{ .label = "uint32", .kind = 14, .detail = "Silex type" },
    .{ .label = "uint64", .kind = 14, .detail = "Silex type alias" },
    .{ .label = "float", .kind = 14, .detail = "Silex type alias" },
    .{ .label = "float32", .kind = 14, .detail = "Silex type" },
    .{ .label = "float64", .kind = 14, .detail = "Silex type" },
};

pub fn itemsAt(allocator: Allocator, source: []const u8, cursor: usize) ![]const CompletionItem {
    if (cursor > source.len or !cursorAllowsCode(source, cursor)) return allocator.alloc(CompletionItem, 0);

    var items: std.ArrayList(CompletionItem) = .empty;
    try items.appendSlice(allocator, &language_items);

    var parser = ParserModule.Parser.init(allocator, source);
    if (parser.parse()) |program| {
        try appendParsedItems(allocator, &items, source, program, cursor);
    } else |_| {
        try appendLexicalItems(allocator, &items, source, cursor);
    }
    return items.toOwnedSlice(allocator);
}

fn appendParsedItems(
    allocator: Allocator,
    items: *std.ArrayList(CompletionItem),
    source: []const u8,
    program: Ast.Program,
    cursor: usize,
) !void {
    for (program.functions) |function| {
        try appendUnique(allocator, items, .{
            .label = function.name,
            .kind = 3,
            .detail = "Silex function",
        });
    }
    for (program.functions) |function| {
        if (!functionContainsCursor(source, function, cursor)) continue;
        for (function.parameters) |parameter| try appendUnique(allocator, items, .{
            .label = parameter.name,
            .kind = 6,
            .detail = "Silex parameter",
        });
        try appendVisibleLocals(allocator, items, source, function, cursor);
        break;
    }
}

fn appendVisibleLocals(
    allocator: Allocator,
    items: *std.ArrayList(CompletionItem),
    source: []const u8,
    function: Ast.Function,
    cursor: usize,
) !void {
    const Local = struct { name: []const u8, depth: usize };
    var locals: std.ArrayList(Local) = .empty;
    var lexer = LexerModule.Lexer.init(source);
    var body_started = false;
    var depth: usize = 0;
    var expects_local = false;
    while (true) {
        const token = lexer.next() catch break;
        if (token.tag == .end or token.start >= cursor) break;
        if (token.start < function.position.offset) continue;
        if (!body_started) {
            if (token.tag == .left_brace) {
                body_started = true;
                depth = 1;
            }
            continue;
        }
        if (expects_local) {
            if (token.tag == .identifier) try locals.append(allocator, .{
                .name = token.lexeme,
                .depth = depth,
            });
            expects_local = false;
        }
        switch (token.tag) {
            .keyword_let => expects_local = true,
            .left_brace => depth += 1,
            .right_brace => {
                var index = locals.items.len;
                while (index != 0) {
                    index -= 1;
                    if (locals.items[index].depth >= depth) _ = locals.orderedRemove(index);
                }
                depth -|= 1;
            },
            else => {},
        }
    }
    for (locals.items) |local| try appendUnique(allocator, items, .{
        .label = local.name,
        .kind = 6,
        .detail = "Silex local binding",
    });
}

fn functionContainsCursor(source: []const u8, function: Ast.Function, cursor: usize) bool {
    if (cursor < function.position.offset) return false;
    var lexer = LexerModule.Lexer.init(source);
    var body_started = false;
    var depth: usize = 0;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) return body_started;
        if (token.start < function.position.offset) continue;
        if (!body_started) {
            if (token.tag == .left_brace) {
                body_started = true;
                depth = 1;
                if (cursor < token.end) return false;
            }
            continue;
        }
        switch (token.tag) {
            .left_brace => depth += 1,
            .right_brace => {
                depth -= 1;
                if (depth == 0) return cursor <= token.end;
            },
            else => {},
        }
    }
}

fn appendLexicalItems(
    allocator: Allocator,
    items: *std.ArrayList(CompletionItem),
    source: []const u8,
    cursor: usize,
) !void {
    var lexer = LexerModule.Lexer.init(source);
    var previous: ?LexerModule.TokenTag = null;
    while (true) {
        const token = lexer.next() catch break;
        if (token.tag == .end) break;
        if (token.tag == .identifier and previous == .keyword_func) try appendUnique(allocator, items, .{
            .label = token.lexeme,
            .kind = 3,
            .detail = "Silex function",
        });
        previous = token.tag;
    }

    lexer = LexerModule.Lexer.init(source[0..cursor]);
    previous = null;
    while (true) {
        const token = lexer.next() catch break;
        if (token.tag == .end) break;
        if (token.tag == .identifier and previous == .keyword_let) try appendUnique(allocator, items, .{
            .label = token.lexeme,
            .kind = 6,
            .detail = "Silex local binding",
        });
        previous = token.tag;
    }
}

fn cursorAllowsCode(source: []const u8, cursor: usize) bool {
    var lexer = LexerModule.Lexer.init(source[0..cursor]);
    var string_depth: usize = 0;
    var interpolation_depth: usize = 0;
    var last_token_end: usize = 0;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) break;
        last_token_end = token.end;
        switch (token.tag) {
            .string_start => string_depth += 1,
            .interpolation_start => interpolation_depth += 1,
            .interpolation_end => interpolation_depth -|= 1,
            .string_end => string_depth -|= 1,
            else => {},
        }
    }
    const trailing = source[last_token_end..cursor];
    const line_start = if (std.mem.lastIndexOfScalar(u8, trailing, '\n')) |newline| newline + 1 else 0;
    if (std.mem.indexOf(u8, trailing[line_start..], "//") != null) return false;
    return string_depth == 0 or interpolation_depth != 0;
}

fn appendUnique(
    allocator: Allocator,
    items: *std.ArrayList(CompletionItem),
    candidate: CompletionItem,
) !void {
    for (items.items) |item| if (std.mem.eql(u8, item.label, candidate.label)) return;
    try items.append(allocator, candidate);
}

fn contains(items: []const CompletionItem, label: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return true;
    return false;
}

test "complete only the current language and visible declarations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "func double(value:int) int { return value * 2 } func main() { let answer:int = 42 print(\"$(ans)\") }";
    const cursor = std.mem.indexOf(u8, source, "ans)").? + 3;
    const items = try itemsAt(arena.allocator(), source, cursor);
    try std.testing.expect(contains(items, "double"));
    try std.testing.expect(contains(items, "main"));
    try std.testing.expect(contains(items, "answer"));
    try std.testing.expect(contains(items, "print"));
    try std.testing.expect(contains(items, "int"));
    try std.testing.expect(!contains(items, "class"));
    try std.testing.expect(!contains(items, "struct"));
    try std.testing.expect(!contains(items, "var"));
}

test "do not complete ordinary string text or comments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const string_source = "func main() { print(\"value";
    try std.testing.expectEqual(@as(usize, 0), (try itemsAt(arena.allocator(), string_source, string_source.len)).len);
    const comment_source = "func main() { // val";
    try std.testing.expectEqual(@as(usize, 0), (try itemsAt(arena.allocator(), comment_source, comment_source.len)).len);
}

test "remove locals whose lexical branch ended before the cursor" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source =
        \\func main() {
        \\    if true {
        \\        let branch:int = 1
        \\    }
        \\    let outer:int = 2
        \\    print(outer)
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "outer)").? + 5;
    const items = try itemsAt(arena.allocator(), source, cursor);
    try std.testing.expect(contains(items, "outer"));
    try std.testing.expect(!contains(items, "branch"));
}
