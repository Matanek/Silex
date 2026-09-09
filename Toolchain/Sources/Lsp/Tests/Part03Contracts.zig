const std = @import("std");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");
const Types = @import("../Types.zig");

const Case = struct {
    id: []const u8,
    source: []const u8,
    expected: Support.ExpectedItem,
    forbidden: []const []const u8,
};

test "part 03 local registry gaps are executable contracts" {
    const cases = [_]Case{
        .{ .id = "declaration-module-empty", .source = "pub<|>", .expected = .{ .label = "public", .kind = 14, .detail = "Silex visibility", .insert_text = "public" }, .forbidden = &.{"break"} },
        .{ .id = "declaration-structure-member", .source = "struct Player { va<|> }\nfunc main() {}", .expected = .{ .label = "var", .kind = 14, .detail = "Silex mutable field", .insert_text = "var" }, .forbidden = &.{"while"} },
        .{ .id = "nominal-relation-type", .source = "protocol Drawable { func draw() }\nstruct Sprite : Dra<|> { func draw() {} }\nfunc main() {}", .expected = .{ .label = "Drawable", .kind = 8, .detail = "Silex protocol", .insert_text = "Drawable" }, .forbidden = &.{"print"} },
        .{ .id = "statement-loop-control", .source = "func main() { while true { br<|> } }", .expected = .{ .label = "break", .kind = 14, .detail = "Silex loop exit", .insert_text = "break" }, .forbidden = &.{"public"} },
        .{ .id = "call-label-middle", .source = "func spawn(health:int, force:int) {}\nfunc main() { spawn(health:100, <|>) }", .expected = .{ .label = "force", .kind = 6, .detail = "force:int", .insert_text = "force:" }, .forbidden = &.{"health"} },
        .{ .id = "call-argument-expression", .source = "func paint(color:int) {}\nfunc main() { let red = 1; paint(<|>) }", .expected = .{ .label = "red", .kind = 6, .detail = "red:int", .insert_text = "red" }, .forbidden = &.{"public"} },
        .{ .id = "aggregate-remaining-field", .source = "struct Player { var health:int; var force:int }\nfunc main() { Player(health:100, <|>) }", .expected = .{ .label = "force", .kind = 5, .detail = "force:int", .insert_text = "force" }, .forbidden = &.{"health"} },
        .{ .id = "lexical-query-destructuring", .source = "struct Target {}\nstruct Motion {}\nfunc update(query:(Target, Motion)[]) { for pair in query { let (target, motion) = pair; mot<|> } }", .expected = .{ .label = "motion", .kind = 6, .detail = "motion:Motion", .insert_text = "motion" }, .forbidden = &.{"query_internal"} },
        .{ .id = "intrinsic-expression-root", .source = "func main() { pri<|> }", .expected = .{ .label = "print", .kind = 14, .detail = "Silex observable effect", .insert_text = "print" }, .forbidden = &.{"public"} },
        .{ .id = "symbol-parameter-binding", .source = "func paint(color:int) { col<|> }\nfunc main() {}", .expected = .{ .label = "color", .kind = 6, .detail = "color:int", .insert_text = "color" }, .forbidden = &.{"__completion"} },
        .{ .id = "symbol-constructor-root", .source = "struct Widget {}\nfunc main() { let value = Wid<|> }", .expected = .{ .label = "Widget", .kind = 22, .detail = "Widget() Widget", .insert_text = "Widget()" }, .forbidden = &.{"while"} },
    };

    var all_satisfied = true;
    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part03-{d}.sx", .{index});
        const items = try Support.serverCompletion(&server, arena.allocator(), uri, case.source);
        const repeated = try Support.serverCompletion(&server, arena.allocator(), uri, case.source);
        try Support.expectItem(case.expected, items);
        for (case.forbidden) |label| if (hasLabel(items, label)) {
            std.debug.print("Part 03 contract '{s}' exposes forbidden label '{s}'\n", .{ case.id, label });
            all_satisfied = false;
        };
        try Support.expectNoDuplicates(items);
        try Support.expectEqualItems(items, repeated);
    }
    try std.testing.expect(all_satisfied);
}

test "part 03 completes a qualified field type from the workspace" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "STD/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"STD\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math.sx",
        .data = "public struct Vec2 { var x:float; var y:float }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletionAfterTrigger(
        &server,
        allocator,
        uri,
        "use STD.Math\nstruct Player { var position:Math.<|> }\nfunc main() {}",
        ".",
    );
    try Support.expectExactLabels(&.{"Vec2"}, items);
    try Support.expectItem(.{
        .label = "Vec2",
        .kind = 22,
        .detail = "struct Vec2",
        .insert_text = "Vec2",
    }, items);
    try Support.expectAbsent("print", items);
    try Support.expectNoDuplicates(items);
    const repeated = try Support.serverCompletionAfterTrigger(
        &server,
        allocator,
        uri,
        "use STD.Math\nstruct Player { var position:Math.<|> }\nfunc main() {}",
        ".",
    );
    try Support.expectEqualItems(items, repeated);
}

test "part 03 exercises every non-empty keyword prefix" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const KeywordSet = struct {
        before: []const u8,
        after: []const u8,
        keywords: []const []const u8,
    };
    const sets = [_]KeywordSet{
        .{
            .before = "",
            .after = "<|>",
            .keywords = &.{ "use", "public", "package", "module", "local", "struct", "class", "nocopy", "static", "protocol", "enum", "func", "test", "extend" },
        },
        .{
            .before = "struct Container { ",
            .after = "<|> }\nfunc main() {}",
            .keywords = &.{ "public", "package", "module", "local", "private", "protected", "let", "var", "init", "func", "static", "struct", "class", "nocopy", "drop" },
        },
        .{
            .before = "func main() { ",
            .after = "<|> }",
            .keywords = &.{ "let", "var", "if", "while", "mutex", "return", "print", "assert", "panic" },
        },
    };
    for (sets) |set| for (set.keywords) |keyword| {
        var prefix_length: usize = 1;
        while (prefix_length <= keyword.len) : (prefix_length += 1) {
            const source = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
                set.before,
                keyword[0..prefix_length],
                set.after,
            });
            const items = try Support.complete(allocator, source);
            const item = itemNamed(items, keyword) orelse {
                std.debug.print("Part 03 keyword '{s}' is missing at prefix '{s}'\n", .{ keyword, keyword[0..prefix_length] });
                return error.MissingCompletionItem;
            };
            try std.testing.expectEqualStrings(keyword, item.filterText.?);
            try std.testing.expectEqualStrings(keyword, item.insertText.?);
            try Support.expectNoDuplicates(items);
        }
    };

    for ([_][]const u8{ "break", "continue" }) |keyword| {
        var prefix_length: usize = 1;
        while (prefix_length <= keyword.len) : (prefix_length += 1) {
            const source = try std.fmt.allocPrint(
                allocator,
                "func main() {{ while true {{ {s}<|> }} }}",
                .{keyword[0..prefix_length]},
            );
            const items = try Support.complete(allocator, source);
            try Support.expectPresent(keyword, items);
            try Support.expectNoDuplicates(items);
        }
    }
}

test "part 03 keeps lexical values through incomplete delimiters" {
    const sources = [_][]const u8{
        "func consume(input:bool) {}\nfunc update(input:bool) bool { if inp<|> }",
        "func consume(input:bool) {}\nfunc update(input:bool) bool { if (inp<|> }",
        "func consume(input:bool) {}\nfunc update(input:bool) bool { while inp<|> }",
        "func consume(input:bool) {}\nfunc update(input:bool) bool { return inp<|> }",
        "func consume(input:bool) {}\nfunc update(input:bool) bool { consume(inp<|> }",
        "func consume(input:bool) {}\nfunc update(input:bool) bool { consume(input:inp<|> }",
        "func consume(input:bool) {}\nfunc update(input:bool) bool { let values = [inp<|> }",
        "func consume(input:bool) {}\nfunc update(input:bool) bool { let pair = (inp<|> }",
    };
    for (sources, 0..) |source, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part03-Delimiter-{d}.sx", .{index});
        const items = try Support.serverCompletion(&server, arena.allocator(), uri, source);
        if (items.len == 0) std.debug.print("Part 03 delimiter case {d} returned no completion\n", .{index});
        try Support.expectExactLabels(&.{"input"}, items);
        try Support.expectItem(.{
            .label = "input",
            .kind = 6,
            .detail = "input:bool",
            .insert_text = "input",
        }, items);
        try Support.expectNoDuplicates(items);
    }
}

test "part 03 enforces nested lexical scope and nearest shadowing" {
    const ScopeCase = struct {
        source: []const u8,
        expected_detail: ?[]const u8,
    };
    const cases = [_]ScopeCase{
        .{ .source = "func main() { val<|>; let value:int = 1 }", .expected_detail = null },
        .{ .source = "func main() { let value:int = 1; val<|> }", .expected_detail = "value:int" },
        .{ .source = "func main() { let value:int = 1; { let value:str = \"inner\"; val<|> } }", .expected_detail = "value:str" },
        .{ .source = "func main() { let value:int = 1; { let scoped:str = \"inner\" } sco<|> }", .expected_detail = null },
    };
    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part03-Scope-{d}.sx", .{index});
        const items = try Support.serverCompletion(&server, arena.allocator(), uri, case.source);
        if (case.expected_detail) |detail| {
            try Support.expectExactLabels(&.{"value"}, items);
            try Support.expectItem(.{
                .label = "value",
                .kind = 6,
                .detail = detail,
                .insert_text = "value",
            }, items);
        } else try std.testing.expectEqual(@as(usize, 0), items.len);
        try Support.expectNoDuplicates(items);
    }
}

test "part 03 publishes direct tuple and indexed for bindings" {
    const sources = [_][]const u8{
        "struct Target {}\nstruct Motion {}\nfunc update(query:(Target, Motion)[]) { for (target, motion) in query { mot<|> } }",
        "struct Motion {}\nfunc update(values:Motion[]) { for index, motion in values.indexed() { mot<|> } }",
    };
    for (sources, 0..) |source, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part03-ForBindings-{d}.sx", .{index});
        const items = try Support.serverCompletion(&server, arena.allocator(), uri, source);
        if (items.len == 0) std.debug.print("Part 03 for binding case {d} returned no completion\n", .{index});
        try Support.expectExactLabels(&.{"motion"}, items);
        try Support.expectItem(.{
            .label = "motion",
            .kind = 6,
            .detail = "motion:Motion",
            .insert_text = "motion",
        }, items);
        try Support.expectNoDuplicates(items);
    }
}

test "part 03 distinguishes code from comments strings and interpolation" {
    const LexicalCase = struct {
        source: []const u8,
        expected: bool,
    };
    const cases = [_]LexicalCase{
        .{ .source = "func main() { let input = true; let text = \"inp<|>\" }", .expected = false },
        .{ .source = "func main() { let input = true; // inp<|>\n}", .expected = false },
        .{ .source = "func main() { let input = true; /* inp<|> */ }", .expected = false },
        .{ .source = "func main() { let input = true; let text = \"$(inp<|>)\" }", .expected = true },
        .{ .source = "func main() { let input = true; print(\"🙂\"); inp<|> }", .expected = true },
    };
    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part03-Lexical-{d}.sx", .{index});
        const items = try Support.serverCompletion(&server, arena.allocator(), uri, case.source);
        if (case.expected) {
            try Support.expectExactLabels(&.{"input"}, items);
        } else try std.testing.expectEqual(@as(usize, 0), items.len);
        try Support.expectNoDuplicates(items);
    }
}

test "part 03 responses stay deterministic across malformed local states" {
    const sources = [_][]const u8{
        "func main() { let motion = 1; if { mot<|> }",
        "func main() { let motion = 1; call((mot<|> }",
        "func main() { let motion = 1; [((mot<|> }",
        "func broken( { }\nfunc main() { let motion = 1; mot<|> }",
        "func main() { let motion = 1; mot<|> }\nstruct Broken { var : }",
    };
    for (sources, 0..) |source, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part03-Malformed-{d}.sx", .{index});
        const first = try Support.serverCompletion(&server, arena.allocator(), uri, source);
        const second = try Support.serverCompletion(&server, arena.allocator(), uri, source);
        if (!hasLabel(first, "motion")) std.debug.print("Part 03 malformed case {d} lost its local binding\n", .{index});
        try Support.expectPresent("motion", first);
        try Support.expectEqualItems(first, second);
        try Support.expectNoDuplicates(first);
    }
}

fn hasLabel(items: []const Types.CompletionItem, label: []const u8) bool {
    return itemNamed(items, label) != null;
}

fn itemNamed(items: []const Types.CompletionItem, label: []const u8) ?Types.CompletionItem {
    for (items) |item| if (std.mem.eql(u8, item.filterText orelse item.label, label)) return item;
    return null;
}
