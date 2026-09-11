const std = @import("std");
const Completion = @import("../Completion.zig");
const Support = @import("Support.zig");
const Frontend = @import("../../Frontend.zig").Frontend;
const Server = @import("../Server.zig").Server;

test "inherited call results complete in conditions and ordinary expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const header =
        \\class State { func is_down(key:int) bool { return false } }
        \\class Node { var state:State = State(); func input() @State { return self.state } func input_mut() &State { return self.state } func inspect(action:func()) @State { action(); return self.state } }
        \\class Root:Node {
        \\    func update() {
        \\        self.state = State()
        \\
    ;
    for ([_][]const u8{ "let input:@State = self.input()", "var input:&State = self.input_mut()", "var input = self.input()", "var input = self.inspect(func() { print(1) })" }) |binding| {
        for ([_][]const u8{ "input.<|>", "if input.<|>", "if self.input().<|>", "while input.<|>", "if input.<|> {}", "if (input.<|>)", "if input.is_<|>" }) |expression| {
            const source = try std.fmt.allocPrint(allocator, "{s}        {s}\n        {s}\n    }}\n}}", .{ header, binding, expression });
            const marked = try Support.removeMarker(allocator, source);
            const decision = try Completion.decisionAt(allocator, marked.text, marked.cursor, .invoked);
            const items = try Support.complete(allocator, source);
            if (items.len == 0) std.debug.print("binding={s} expression={s} kind={s} recovery={s} parsed={} receiver={s}\n", .{ binding, expression, @tagName(decision.kind), @tagName(decision.recovery), decision.program != null, decision.receiver orelse "" });
            try Support.expectExactLabels(&.{"is_down"}, items);
            try Support.expectNoDuplicates(items);
        }
        var frontend = Frontend.init(allocator);
        _ = try frontend.compile(try std.fmt.allocPrint(allocator, "{s}{s}\n if input.is_down(0) {{}}\n }}\n}}\nfunc main() {{}}", .{ header, binding }));
    }
}

test "imported inherited call results complete after if" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Nodes");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Input.sx", .data = "public class State { func is_down(key:int) bool { return false } private func hidden() {} }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Nodes/@Node.sx", .data = "use Input\npublic class Node<T> { protected func input() @T { panic(\"fixture\") } protected func input_mut() &T { panic(\"fixture\") } protected func inspect(action:func()) @T { panic(\"fixture\") } }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Nodes/@Node2D.sx", .data = "use Input\npublic class Node2D:Node<Input.State> {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "{s}/Main.sx", .{root_uri});
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    for ([_][]const u8{ "let input:@Input.State = self.input()", "var input:&Input.State = self.input_mut()", "var input = self.input()", "var input = self.inspect(func() { print(1) })" }) |binding| {
        for ([_][]const u8{ "input.<|>", "if input.<|>", "if self.input().<|>", "while input.<|>", "if input.<|> {}", "if (input.<|>)", "if input.is_<|>" }) |expression| {
            const source = try std.fmt.allocPrint(allocator, "use Nodes\nuse Input\nclass Root:Nodes.Node2D {{\n    func update() {{\n        {s}\n        {s}\n    }}\n}}", .{ binding, expression });
            const items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, source, ".");
            if (items.len == 0) {
                const marked = try Support.removeMarker(allocator, source);
                const decision = try Completion.decisionAt(allocator, marked.text, marked.cursor, .invoked);
                std.debug.print("binding={s} expression={s} kind={s} recovery={s} parsed={} receiver={s}\n", .{ binding, expression, @tagName(decision.kind), @tagName(decision.recovery), decision.program != null, decision.receiver orelse "" });
            }
            try Support.expectExactLabels(&.{"is_down"}, items);
            try Support.expectNoDuplicates(items);
            try Support.expectEqualItems(items, try Support.serverCompletion(&server, allocator, uri, source));
        }
    }
}

test "inherited call results use only the visible binding" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const header = "class State { func is_down() bool { return false } }\nclass Node { func input() @State { panic(\"fixture\") } }\nclass Root:Node {\n";
    for ([_][]const u8{
        "func first() { var input = self.input() }\nfunc next() { if input.<|> }",
        "func update() { { var input = self.input() }\n if input.<|> }",
        "func update() { var input = self.input()\n { let input = 1\n if input.<|> } }",
    }) |body| {
        const source = try std.fmt.allocPrint(allocator, "{s}{s}\n}}", .{ header, body });
        const items = try Support.complete(allocator, source);
        try Support.expectAbsent("is_down", items);
    }
}

test "namespace arguments recover unfinished conditions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Input.sx", .data = "public enum Key { w, a } public class State { func is_down(key:Key) bool { return false } }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "{s}/Main.sx", .{root_uri});
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    for ([_][]const u8{ "if input.is_down({s})", "while input.is_down({s})", "if (input.is_down({s}))", "if input.is_down({s}) {}", "input.is_down({s})", "if input.is_down({s}" }) |form| {
        for ([_][]const u8{ "G<|>", "GF<|>" }) |prefix| {
            const hole = std.mem.indexOf(u8, form, "{s}").?;
            const expression = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ form[0..hole], prefix, form[hole + 3 ..] });
            const source = try std.fmt.allocPrint(allocator, "use GFX.Input\nclass Root {{ func update(input:Input.State) {{\n {s}\n }} }}", .{expression});
            const items = try Support.serverCompletion(&server, allocator, uri, source);
            try Support.expectPresent("GFX", items);
            try Support.expectAbsent("__completion", items);
            try Support.expectNoDuplicates(items);
            try Support.expectEqualItems(items, try Support.serverCompletion(&server, allocator, uri, source));
        }
    }
}
