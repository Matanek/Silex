const std = @import("std");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

const Case = struct {
    id: []const u8,
    source: []const u8,
    expected: []const Support.ExpectedItem,
    forbidden: []const []const u8,
};

test "part 04 local receiver registry gaps are executable contracts" {
    const cases = [_]Case{
        .{ .id = "member-self-receiver", .source = "struct Counter { var value:int; func read() int { return self.<|> } }\nfunc main() {}", .expected = &.{
            .{ .label = "value", .kind = 5, .detail = "value:int", .insert_text = "value" },
            .{ .label = "read", .kind = 2, .detail = "read() int", .insert_text = "read()" },
        }, .forbidden = &.{"static_only"} },
        .{ .id = "member-local-extension", .source = "struct Adapter {}\nextend Adapter { func choose() int { return 1 } }\nfunc main() { Adapter().<|> }", .expected = &.{
            .{ .label = "choose", .kind = 2, .detail = "choose() int", .insert_text = "choose()" },
        }, .forbidden = &.{"public"} },
        .{ .id = "member-dynamic-protocol", .source = "protocol Readable { func read() int }\nstruct Text : Readable { func read() int { return 1 } }\nfunc main() { var value:Readable = Text(); value.<|> }", .expected = &.{
            .{ .label = "read", .kind = 2, .detail = "read() int", .insert_text = "read()" },
        }, .forbidden = &.{"secret"} },
        .{ .id = "member-optional-safe-access", .source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input:Input? = Input(); if input?.<|> }", .expected = &.{
            .{ .label = "pressed", .kind = 2, .detail = "pressed() bool", .insert_text = "pressed()" },
        }, .forbidden = &.{"if"} },
        .{ .id = "member-static-type", .source = "struct Palette {\nstatic func red() int { return 1 }\nfunc instance() {}\n}\nfunc main() { Palette.<|> }", .expected = &.{
            .{ .label = "red", .kind = 2, .detail = "red() int", .insert_text = "red()" },
        }, .forbidden = &.{"instance"} },
        .{ .id = "member-specialized-generic", .source = "struct Box<T> { let value:T; func get() T { return self.value } }\nfunc main() { Box<int>(value:1).<|> }", .expected = &.{
            .{ .label = "value", .kind = 5, .detail = "value:int", .insert_text = "value" },
            .{ .label = "get", .kind = 2, .detail = "get() int", .insert_text = "get()" },
        }, .forbidden = &.{"T"} },
        .{ .id = "member-named-tuple", .source = "func main() { let size:(width:int, height:int) = (width:1, height:2); size.<|> }", .expected = &.{
            .{ .label = "height", .kind = 5, .detail = "height:int", .insert_text = "height" },
            .{ .label = "width", .kind = 5, .detail = "width:int", .insert_text = "width" },
        }, .forbidden = &.{"length"} },
        .{ .id = "symbol-enum-case", .source = "enum Direction { north; south }\nfunc main() { let value = Direction.<|> }", .expected = &.{
            .{ .label = "north", .kind = 20, .detail = "north Direction", .insert_text = "north" },
            .{ .label = "south", .kind = 20, .detail = "south Direction", .insert_text = "south" },
        }, .forbidden = &.{"__silex_"} },
    };

    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part04-{d}.sx", .{index});
        const items = try Support.serverCompletionAfterTrigger(&server, arena.allocator(), uri, case.source, ".");
        const labels = try arena.allocator().alloc([]const u8, case.expected.len);
        for (case.expected, 0..) |expected, expected_index| labels[expected_index] = expected.label;
        Support.expectExactLabels(labels, items) catch |err| {
            std.debug.print("Part 04 contract '{s}' has a non-exclusive catalogue\n", .{case.id});
            return err;
        };
        for (case.expected) |expected| try Support.expectItem(expected, items);
        for (case.forbidden) |label| try Support.expectAbsent(label, items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletionAfterTrigger(&server, arena.allocator(), uri, case.source, ".");
        try Support.expectEqualItems(items, repeated);
    }
}

test "part 04 preserves an imported field type through query and local bindings" {
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
        .data =
        \\public struct Vec2 {
        \\    var x:float = 0.0
        \\    var y:float = 0.0
        \\    func length() float { return self.x + self.y }
        \\    func normalized() Vec2 { return self }
        \\}
        ,
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

    const sources = [_][]const u8{
        "use STD.Math\nstruct Transform2D { var position:Math.Vec2 }\nfunc broken( { }\nfunc update(transform:&Transform2D) { if transform.position.<|> }",
        "use STD.Math\nstruct Transform2D { var position:Math.Vec2 }\nfunc broken( { }\nfunc update(transform:&Transform2D) { var pos:Math.Vec2 = transform.position; if pos.<|> }",
    };
    for (sources) |source| {
        const items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, source, ".");
        try Support.expectExactLabels(&.{ "x", "y", "length", "normalized" }, items);
        try Support.expectItem(.{ .label = "x", .kind = 5, .detail = "x:float", .insert_text = "x" }, items);
        try Support.expectItem(.{ .label = "y", .kind = 5, .detail = "y:float", .insert_text = "y" }, items);
        try Support.expectItem(.{ .label = "length", .kind = 2, .detail = "length() float", .insert_text = "length()" }, items);
        try Support.expectItem(.{ .label = "normalized", .kind = 2, .detail = "normalized() Vec2", .insert_text = "normalized()" }, items);
        try Support.expectAbsent("position", items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletionAfterTrigger(&server, allocator, uri, source, ".");
        try Support.expectEqualItems(items, repeated);
    }
}

test "part 04 preserves an imported principal receiver through cascade layouts" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX.Canvas/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"GFX.Canvas\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\",\"extensions\":{\"GFX.Canvas\":{\"suite\":true}}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Module/@Module.sx", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Canvas/Package.json",
        .data = "{\"name\":\"GFX.Canvas\",\"version\":\"1.0.0\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Canvas/Module/@Module.sx",
        .data = "public use GFX.Canvas.Canvas.Canvas",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX.Canvas/Module/Canvas.sx",
        .data =
        \\public class Canvas {
        \\    var opacity:float = 1.0
        \\    func paint(callback:func()) Canvas { callback(); return self }
        \\    func clear() Canvas { return self }
        \\}
        ,
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

    const sources = [_][]const u8{
        "use GFX.Canvas\nfunc broken( { }\nfunc draw() Canvas { return Canvas()..<|> }",
        "use GFX.Canvas\nfunc draw() Canvas {\n    return Canvas()\n        ..<|>\n}",
        "use GFX.Canvas\nfunc consume(canvas:Canvas) {}\nfunc draw() { consume(Canvas()..<|>) }",
    };
    for (sources) |source| {
        const items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, source, ".");
        try Support.expectExactLabels(&.{ "opacity", "clear", "paint" }, items);
        try Support.expectItem(.{ .label = "opacity", .kind = 5, .detail = "opacity:float", .insert_text = "opacity" }, items);
        try Support.expectItem(.{ .label = "clear", .kind = 2, .detail = "clear() Canvas", .insert_text = "clear()" }, items);
        try Support.expectItem(.{
            .label = "paint",
            .kind = 2,
            .detail = "paint(callback:function) Canvas",
            .insert_text = "paint(${1:callback})$0",
            .insert_text_format = 2,
        }, items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletionAfterTrigger(&server, allocator, uri, source, ".");
        try Support.expectEqualItems(items, repeated);
    }
}

test "part 04 resolves parenthesized indexed call and mixed local chains" {
    const sources = [_][]const u8{
        "struct Payload { func paint() int { return 1 } }\nfunc inspect(payload:Payload) { let result = (payload).<|> }",
        "struct Payload { func paint() int { return 1 } }\nfunc inspect(payloads:Payload[]) { payloads[0].<|> }",
        "struct Payload { func paint() int { return 1 } }\nfunc make_payload() Payload { return Payload() }\nfunc inspect() { make_payload().<|> }",
        "struct Payload { func paint() int { return 1 } }\nstruct Holder { func current() Payload { return Payload() } }\nfunc inspect(holder:Holder) { holder.current().<|> }",
        "struct Payload { func paint() int { return 1 } }\nstruct Holder { var payload:Payload }\nfunc make_holder() Holder { return Holder(payload:Payload()) }\nfunc inspect() { make_holder().payload.<|> }",
        "struct Payload { func paint() int { return 1 } }\nstruct Holder { func current() Payload { return Payload() } }\nfunc make_holder() Holder { return Holder() }\nfunc inspect() { make_holder().current().<|> }",
    };
    for (sources, 0..) |source, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part04-Chain-{d}.sx", .{index});
        const items = try Support.serverCompletionAfterTrigger(&server, arena.allocator(), uri, source, ".");
        try Support.expectExactLabels(&.{"paint"}, items);
        try Support.expectItem(.{ .label = "paint", .kind = 2, .detail = "paint() int", .insert_text = "paint()" }, items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletionAfterTrigger(&server, arena.allocator(), uri, source, ".");
        try Support.expectEqualItems(items, repeated);
    }
}

test "part 04 preserves specialization and one safe optional layer through chains" {
    const cases = [_]struct {
        source: []const u8,
        expected: []const []const u8,
    }{
        .{
            .source = "struct Payload { func paint() int { return 1 } }\nstruct Box<T> { let value:T; func get() T { return self.value } }\nfunc inspect(box:Box<Payload>) { box.value.<|> }",
            .expected = &.{"paint"},
        },
        .{
            .source = "struct Payload { func paint() int { return 1 } }\nstruct Box<T> { let value:T; func get() T { return self.value } }\nfunc inspect(box:Box<Payload>) { box.get().<|> }",
            .expected = &.{"paint"},
        },
        .{
            .source = "struct Payload { func paint() int { return 1 } }\nstruct Box<T> { let value:T; func get() T { return self.value } }\nfunc inspect(box:Box<Payload?>) { box.get()?.<|> }",
            .expected = &.{"paint"},
        },
        .{
            .source = "struct Payload { func paint() int { return 1 } }\nstruct Box<T> { let value:T; func get() T { return self.value } }\nfunc inspect(box:Box<Payload??>) { box.get()?.<|> }",
            .expected = &.{},
        },
    };

    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part04-Specialized-{d}.sx", .{index});
        const items = try Support.serverCompletionAfterTrigger(&server, arena.allocator(), uri, case.source, ".");
        Support.expectExactLabels(case.expected, items) catch |err| {
            std.debug.print("Part 04 specialized chain case {d} failed\n", .{index});
            return err;
        };
        if (case.expected.len != 0) {
            try Support.expectItem(.{ .label = "paint", .kind = 2, .detail = "paint() int", .insert_text = "paint()" }, items);
        }
        try Support.expectNoDuplicates(items);
    }
}

test "part 04 rejects members from the wrong receiver category" {
    const cases = [_]struct {
        source: []const u8,
        expected: []const []const u8,
    }{
        .{
            .source = "struct Device { static func build() Device { return Device() }\nfunc paint() int { return 1 } }\nfunc inspect(device:Device) { device.<|> }",
            .expected = &.{"paint"},
        },
        .{
            .source = "struct Device { static func build() Device { return Device() }\nfunc paint() int { return 1 } }\nfunc inspect() { Device.<|> }",
            .expected = &.{"build"},
        },
        .{
            .source = "func pair() (int, int) { return (1, 2) }\nfunc inspect() { pair().<|> }",
            .expected = &.{},
        },
        .{
            .source = "func inspect() { unknown.<|> }",
            .expected = &.{},
        },
    };

    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part04-Negative-{d}.sx", .{index});
        const items = try Support.serverCompletionAfterTrigger(&server, arena.allocator(), uri, case.source, ".");
        Support.expectExactLabels(case.expected, items) catch |err| {
            std.debug.print("Part 04 negative receiver case {d} failed\n", .{index});
            return err;
        };
        try Support.expectNoDuplicates(items);
    }
}

test "part 04 preserves read mutable static and conformance receivers" {
    const sources = [_][]const u8{
        "struct Payload { func paint() int { return 1 } }\nfunc inspect(payload:&Payload) { payload.<|> }",
        "struct Payload { func paint() int { return 1 } }\nfunc inspect(payload:@Payload) { payload.<|> }",
        "struct Payload { func paint() int { return 1 } }\nstruct Factory { static func make() Payload { return Payload() } }\nfunc inspect() { Factory.make().<|> }",
        "protocol Drawable { func paint() int }\nstruct Payload {}\nextend Payload : Drawable { func paint() int { return 1 } }\nfunc inspect(payload:Payload) { payload.<|> }",
    };

    for (sources, 0..) |source, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part04-Receiver-Kind-{d}.sx", .{index});
        const items = try Support.serverCompletionAfterTrigger(&server, arena.allocator(), uri, source, ".");
        try Support.expectExactLabels(&.{"paint"}, items);
        try Support.expectItem(.{ .label = "paint", .kind = 2, .detail = "paint() int", .insert_text = "paint()" }, items);
        try Support.expectNoDuplicates(items);
    }
}

test "part 04 keeps the correct root through cascade nesting and continuation" {
    const cases = [_]struct {
        source: []const u8,
        expected: []const Support.ExpectedItem,
    }{
        .{
            .source = "class Canvas { var opacity:float; func paint() Canvas { return self } }\nfunc draw() { Canvas()..<|> }",
            .expected = &.{
                .{ .label = "opacity", .kind = 5, .detail = "opacity:float", .insert_text = "opacity" },
                .{ .label = "paint", .kind = 2, .detail = "paint() Canvas", .insert_text = "paint()" },
            },
        },
        .{
            .source = "class Canvas { var opacity:float; func paint() Canvas { return self } }\nfunc draw() { Canvas()\n    ..paint()\n    ..<|>\n}",
            .expected = &.{
                .{ .label = "opacity", .kind = 5, .detail = "opacity:float", .insert_text = "opacity" },
                .{ .label = "paint", .kind = 2, .detail = "paint() Canvas", .insert_text = "paint()" },
            },
        },
        .{
            .source = "struct Settings { var title:str; var width:int }\nfunc configure() { Settings()..ti<|> = \"Silex\" }",
            .expected = &.{
                .{ .label = "title", .kind = 5, .detail = "title:str", .insert_text = "title" },
            },
        },
        .{
            .source = "class Plugin { func configure() Plugin { return self } }\nclass Application { func install(plugin:Plugin) Application { return self }\nfunc run() int { return 0 } }\nfunc launch() { Application()\n    ..install(Plugin()\n        ..<|>\n    )\n}",
            .expected = &.{
                .{ .label = "configure", .kind = 2, .detail = "configure() Plugin", .insert_text = "configure()" },
            },
        },
        .{
            .source = "class Plugin { func configure() Plugin { return self } }\nclass Application { func install(plugin:Plugin) Application { return self }\nfunc run() int { return 0 } }\nfunc launch() { Application()\n    ..install(Plugin()\n        ..configure()\n    )\n    ..<|>\n}",
            .expected = &.{
                .{ .label = "install", .kind = 2, .detail = "install(plugin:Plugin) Application", .insert_text = "install(${1:plugin})$0", .insert_text_format = 2 },
                .{ .label = "run", .kind = 2, .detail = "run() int", .insert_text = "run()" },
            },
        },
    };

    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(arena.allocator(), "file:///Part04-Cascade-{d}.sx", .{index});
        const items = try Support.serverCompletionAfterTrigger(&server, arena.allocator(), uri, case.source, ".");
        const labels = try arena.allocator().alloc([]const u8, case.expected.len);
        for (case.expected, 0..) |expected, expected_index| labels[expected_index] = expected.label;
        Support.expectExactLabels(labels, items) catch |err| {
            std.debug.print("Part 04 cascade case {d} failed\n", .{index});
            return err;
        };
        for (case.expected) |expected| try Support.expectItem(expected, items);
        try Support.expectNoDuplicates(items);
    }
}

test "part 04 resolves homogeneous member chains at every generated depth" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var expression = try allocator.dupe(u8, "node");
    for (0..16) |depth| {
        const source = try std.fmt.allocPrint(
            allocator,
            "class Node {{ var value:int; func next() Node {{ return self }} }}\nfunc inspect(node:Node) {{ {s}.<|> }}",
            .{expression},
        );
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(allocator, "file:///Part04-Depth-{d}.sx", .{depth});
        const items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, source, ".");
        try Support.expectExactLabels(&.{ "value", "next" }, items);
        try Support.expectItem(.{ .label = "value", .kind = 5, .detail = "value:int", .insert_text = "value" }, items);
        try Support.expectItem(.{ .label = "next", .kind = 2, .detail = "next() Node", .insert_text = "next()" }, items);
        try Support.expectNoDuplicates(items);
        expression = try std.fmt.allocPrint(allocator, "{s}.next()", .{expression});
    }
}
