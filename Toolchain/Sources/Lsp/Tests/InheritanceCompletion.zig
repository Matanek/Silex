const std = @import("std");
const Frontend = @import("../../Frontend.zig").Frontend;
const Server = @import("../Server.zig").Server;
const Support = @import("Support.zig");

const node =
    \\public class Node<T> {
    \\    var name:str = ""
    \\    func add_child(child:Node<T>) {}
    \\    protected func input() int { return 0 }
    \\    protected func on_ready() {}
    \\    protected func on_process(delta:T) {}
    \\    private func secret() {}
    \\    module func internal_hook() {}
    \\    static func factory() {}
    \\}
;

test "inherited completion server handles aliases atoms overlays and override triggers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Nodes");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Nodes/@Node.sx", .data = node });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Nodes/@Node2D.sx", .data = "public class Node2D:Node<float> {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "{s}/Main.sx", .{root_uri});
    const node_uri = try std.fmt.allocPrint(allocator, "{s}/Nodes/@Node.sx", .{root_uri});
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);

    for ([_][]const u8{ "use Nodes\nclass Player:Nodes.Node2D", "use Nodes.Node2D as Parent\nclass Player:Parent" }) |declaration| {
        const source = try std.fmt.allocPrint(allocator, "{s} {{\n    override func on_ready() {{}}\n    func tick() {{\n        if self.<|>\n    }}\n}}", .{declaration});
        const items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, source, ".");
        try Support.expectExactLabels(&.{ "name", "add_child", "input", "on_process", "on_ready", "tick" }, items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletion(&server, allocator, uri, source);
        try Support.expectEqualItems(items, repeated);
        try Support.expectItem(.{ .label = "on_process", .kind = 2, .detail = "on_process(delta:float) void", .insert_text = "on_process(${1:delta})$0", .insert_text_format = 2 }, items);

        for ([_][]const u8{ "override ", "override func ", "override func on_", "protected override func " }) |editing| {
            const partial = try std.fmt.allocPrint(allocator, "{s} {{\n    override func on_ready() {{}}\n    {s}<|>\n}}", .{ declaration, editing });
            const overrides = try Support.serverCompletionAfterTrigger(&server, allocator, uri, partial, " ");
            try Support.expectPresent("on_process", overrides);
            for ([_][]const u8{ "on_ready", "secret", "internal_hook", "factory", "name", "func", "if", "Node" }) |forbidden|
                try Support.expectAbsent(forbidden, overrides);
            try Support.expectNoDuplicates(overrides);
            try Support.expectItem(.{ .label = "on_process", .kind = 2, .detail = "on_process(delta:float) void", .insert_text = if (std.mem.eql(u8, editing, "override ")) "func on_process(delta:float) {\n    $0\n}" else "on_process(delta:float) {\n    $0\n}", .insert_text_format = 2 }, overrides);
        }
    }
    const external = try Support.serverCompletionAfterTrigger(&server, allocator, uri, "use Nodes\nfunc inspect(player:Nodes.Node2D) { player.<|> }", ".");
    try Support.expectExactLabels(&.{ "name", "add_child" }, external);
    const static_items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, "use Nodes\nfunc inspect() { Nodes.Node2D.<|> }", ".");
    try Support.expectExactLabels(&.{}, static_items);

    const definition = (try Support.serverDefinition(&server, allocator, uri, "use Nodes\nclass Player:Nodes.Node2<|>D {}\nfunc main() {}")).?;
    try std.testing.expect(std.mem.endsWith(u8, try @import("../Workspace.zig").pathFromUri(allocator, definition.uri), "/Nodes/@Node2D.sx"));

    for ([_][]const u8{ "use Nodes\nclass Player:Nodes.Node2D", "use Nodes.Node2D as Parent\nclass Player:Parent" }) |declaration| {
        for ([_][]const u8{ "add_child", "input", "name" }) |member| {
            const source = try std.fmt.allocPrint(allocator, "{s} {{ func tick() {{ print(self.{s}<|>) }} }}", .{ declaration, member });
            const inherited_definition = (try Support.serverDefinition(&server, allocator, uri, source)) orelse return error.MissingInheritedDefinition;
            try std.testing.expectEqualStrings(try @import("../Workspace.zig").pathFromUri(allocator, node_uri), try @import("../Workspace.zig").pathFromUri(allocator, inherited_definition.uri));
            const offset = std.mem.indexOf(u8, node, member).?;
            const expected = @import("../Protocol.zig").positionAtByteOffset(node, offset, .utf16).?;
            try std.testing.expectEqual(expected, inherited_definition.range.start);
            try std.testing.expectEqual(expected.character + member.len, inherited_definition.range.end.character);
        }
    }
    const public_member = (try Support.serverDefinition(&server, allocator, uri, "use Nodes\nfunc visit(player:Nodes.Node2D) { player.add_ch<|>ild(player) }")) orelse return error.MissingInheritedDefinition;
    try std.testing.expectEqualStrings(try @import("../Workspace.zig").pathFromUri(allocator, node_uri), try @import("../Workspace.zig").pathFromUri(allocator, public_member.uri));
    for ([_][]const u8{
        "use Nodes\nclass Player:Nodes.Node2D { func tick() { self.sec<|>ret() } }",
        "use Nodes\nfunc visit(player:Nodes.Node2D) { player.inp<|>ut() }",
        "use Nodes\nfunc visit() { Nodes.Node2D.fac<|>tory() }",
    }) |source| try std.testing.expectEqual(@as(?@import("../Types.zig").Location, null), try Support.serverDefinition(&server, allocator, uri, source));
    const own_override = (try Support.serverDefinition(&server, allocator, uri, "use Nodes\nclass Player:Nodes.Node2D { override func on_ready() {} func tick() { self.on_re<|>ady() } }")) orelse return error.MissingOverrideDefinition;
    try std.testing.expectEqualStrings(uri, own_override.uri);
    const local_base = (try Support.serverDefinition(&server, allocator, uri, "class Base<T> { func update(value:T) {} }\nclass Middle:Base<int> {}\nclass Child:Middle { func tick() { self.up<|>date(1) } }")) orelse return error.MissingLocalInheritedDefinition;
    try std.testing.expectEqualStrings(uri, local_base.uri);
    try std.testing.expectEqual(@as(usize, 0), local_base.range.start.line);

    const changed_node = try std.mem.replaceOwned(u8, allocator, node, "private func secret()", "protected func on_overlay() {}\n    private func secret()");
    try Support.openDocument(&server, allocator, node_uri, 2, changed_node);
    const overlay = try Support.serverCompletionAfterTrigger(&server, allocator, uri, "use Nodes\nclass Player:Nodes.Node2D {\n    override <|>\n}", " ");
    try Support.expectPresent("on_overlay", overlay);
    try Support.expectPresent("on_process", overlay);
    const node2d_uri = try std.fmt.allocPrint(allocator, "{s}/Nodes/@Node2D.sx", .{root_uri});
    const same_module = try Support.serverCompletionAfterTrigger(&server, allocator, node2d_uri, "public class Node2D:Node<float> {\n    override <|>\n}", " ");
    try Support.expectPresent("on_process", same_module);
    const extension_source = "public class Node2D:Node<float> {}\nextend Node2D { func extension_method() {} }";
    try Support.openDocument(&server, allocator, node2d_uri, 3, extension_source);
    const extensions = try Support.serverCompletionAfterTrigger(&server, allocator, uri, "use Nodes\nclass Player:Nodes.Node2D {\n    override <|>\n}", " ");
    try Support.expectPresent("on_process", extensions);
    try Support.expectAbsent("extension_method", extensions);
    const local = try Support.serverCompletionAfterTrigger(&server, allocator, uri, "use Nodes\nclass Base { func update() {} }\nclass Child:Base {\n    override <|>\n}", " ");
    try Support.expectExactLabels(&.{"update"}, local);
}

test "inherited override insertion compiles and preserves borrow modes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const header =
        \\class State { var value:int = 0 }
        \\class Node<T> {
        \\    protected func on_process(delta:T, state:&State) {}
        \\}
        \\class Player:Node<float> {
        \\
    ;
    const items = try Support.complete(allocator, header ++ "    override <|>\n}");
    try Support.expectExactLabels(&.{"on_process"}, items);
    const insertion = items[0].insertText.?;
    try std.testing.expect(std.mem.indexOf(u8, insertion, "state:&State") != null);
    const body = try std.mem.replaceOwned(u8, allocator, insertion, "$0", "state.value = 1");
    const canonical = try std.fmt.allocPrint(allocator, "{s}    override {s}\n}}\nfunc main() {{}}", .{ header, body });
    var frontend = Frontend.init(allocator);
    _ = try frontend.compile(canonical);
    const renamed = try Support.complete(allocator, header ++
        "    override func on_process(dt:float, value:&State) {}\n    override <|>\n}");
    try Support.expectExactLabels(&.{}, renamed);
    for ([_][]const u8{ "func main() { over<|> }", "struct Plain { over<|> }", "class Plain { over<|> }", "static class Plain { over<|> }", "class Base {} class Child:Base { struct Plain { over<|> } }" }) |source|
        try Support.expectAbsent("override", try Support.complete(allocator, source));
}

test "inherited override overloads retain distinct signatures and hide extensions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const items = try Support.complete(arena.allocator(),
        \\class Base {
        \\    func visit(value:int) {}
        \\    func visit(value:str) {}
        \\}
        \\extend Base { func extension_method() {} }
        \\class Child:Base {
        \\    override <|>
        \\}
    );
    try Support.expectExactLabels(&.{ "visit(value:int)", "visit(value:str)" }, items);
    try Support.expectNoDuplicates(items);
}

test "inherited override signatures compile for callbacks generic methods and borrowed returns" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const header =
        \\class State {}
        \\class Base {
        \\    func inspect(value:@State) @State { return value }
        \\    func call(action:func(int) bool) {}
        \\    func identity<T>(value:T) T { return value }
        \\}
        \\class Child:Base {
        \\
    ;
    const items = try Support.complete(allocator, header ++ "    override <|>\n}");
    try Support.expectExactLabels(&.{ "call", "identity", "inspect" }, items);
    var canonical: []const u8 = header;
    for (items) |item| {
        const declaration = try std.mem.replaceOwned(u8, allocator, item.insertText.?, "$0", "panic(\"body\")");
        canonical = try std.fmt.allocPrint(allocator, "{s}\n    override {s}\n", .{ canonical, declaration });
    }
    var frontend = Frontend.init(allocator);
    _ = try frontend.compile(try std.fmt.allocPrint(allocator, "{s}\n}}\nfunc main() {{}}", .{canonical}));
    const generic = try Support.complete(allocator, "class Base<T> { func update(value:T) {} }\nclass Child<T>:Base<T> {\n    override <|>\n}");
    try std.testing.expectEqualStrings("update(value:T) void", generic[0].detail);
    const protocol = "protocol Contract { func update() }\nclass Child:Contract {\n    override <|>\n}";
    try Support.expectExactLabels(&.{}, try Support.complete(allocator, protocol));
}
