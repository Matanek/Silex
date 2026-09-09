const std = @import("std");
const Oracle = @import("CompletionOracleSupport.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

const Case = struct {
    id: []const u8,
    provenance: []const u8,
    oracle_type: []const u8,
    canonical: []const u8,
    partial: []const u8,
    forbidden: []const []const u8,
};

const cases = [_]Case{
    .{
        .id = "std-vector-instance",
        .provenance = "STD Math vector public surface",
        .oracle_type = "Vec2",
        .canonical =
        \\public struct Vec2 {
        \\    public var x:float
        \\    public var y:float
        \\    public func length() float { return 0.0 }
        \\    public func normalized() Vec2 { return self }
        \\    private func storage() int { return 0 }
        \\}
        \\func main() { let position = Vec2(x:0.0, y:0.0); print(position.length()) }
        ,
        .partial =
        \\public struct Vec2 {
        \\    public var x:float
        \\    public var y:float
        \\    public func length() float { return 0.0 }
        \\    public func normalized() Vec2 { return self }
        \\    private func storage() int { return 0 }
        \\}
        \\func main() { let position = Vec2(x:0.0, y:0.0); position.<|> }
        ,
        .forbidden = &.{ "storage", "if" },
    },
    .{
        .id = "gfx-application-cascade",
        .provenance = "GFX application builder cascade",
        .oracle_type = "Application",
        .canonical =
        \\public class Application {
        \\    public func add_plugin(plugin:int) Application { return self }
        \\    public func run() {}
        \\    private func bootstrap() {}
        \\}
        \\func main() { Application()..add_plugin(1)..run() }
        ,
        .partial =
        \\public class Application {
        \\    public func add_plugin(plugin:int) Application { return self }
        \\    public func run() {}
        \\    private func bootstrap() {}
        \\}
        \\func main() { Application()..<|> }
        ,
        .forbidden = &.{ "bootstrap", "while" },
    },
    .{
        .id = "data-optional-call-chain",
        .provenance = "data package optional lookup chain",
        .oracle_type = "Value",
        .canonical =
        \\public class Value {
        \\    public func field(name:str) Value? { return null }
        \\    public func as_str() str { return "" }
        \\    private func raw() int { return 0 }
        \\}
        \\func parse() Value { return Value() }
        \\func main() { if text = parse().field("name")?.as_str() { print(text) } }
        ,
        .partial =
        \\public class Value {
        \\    public func field(name:str) Value? { return null }
        \\    public func as_str() str { return "" }
        \\    private func raw() int { return 0 }
        \\}
        \\func parse() Value { return Value() }
        \\func main() { parse().field("name")?.<|> }
        ,
        .forbidden = &.{ "raw", "return" },
    },
    .{
        .id = "interop-specialized-generic-chain",
        .provenance = "interop package generic value wrapper",
        .oracle_type = "Node",
        .canonical =
        \\public struct Node<T> {
        \\    public var value:T
        \\    public func identity() Node<T> { return self }
        \\    private func erased() int { return 0 }
        \\}
        \\func main() { print(Node<int>(value:1).identity().value) }
        ,
        .partial =
        \\public struct Node<T> {
        \\    public var value:T
        \\    public func identity() Node<T> { return self }
        \\    private func erased() int { return 0 }
        \\}
        \\func main() { Node<int>(value:1).identity().<|> }
        ,
        .forbidden = &.{ "erased", "class" },
    },
    .{
        .id = "example-dynamic-protocol",
        .provenance = "application example protocol-erased service",
        .oracle_type = "Sink",
        .canonical =
        \\public protocol Sink {
        \\    public func write(value:str)
        \\    public func close()
        \\}
        \\func consume(sink:Sink) { sink.close() }
        \\func main() {}
        ,
        .partial =
        \\public protocol Sink {
        \\    public func write(value:str)
        \\    public func close()
        \\}
        \\func consume(sink:Sink) { sink.<|> }
        \\func main() {}
        ,
        .forbidden = &.{ "main", "public" },
    },
};

test "sealed corpus stays equal to the independent semantic oracle on first qualification" {
    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const expected = Oracle.publicInstanceMembers(allocator, case.canonical, case.oracle_type) catch |err| {
            std.debug.print("sealed corpus '{s}' oracle failed ({s}): {s}\n", .{ case.id, case.provenance, @errorName(err) });
            return err;
        };
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(allocator, "file:///Sealed-{d}.sx", .{index});
        const actual = Support.serverCompletionAfterTrigger(&server, allocator, uri, case.partial, ".") catch |err| {
            std.debug.print("sealed corpus '{s}' request failed ({s}): {s}\n", .{ case.id, case.provenance, @errorName(err) });
            return err;
        };
        if (expected.len != actual.len) {
            std.debug.print("sealed corpus '{s}' surface differs ({s})\n", .{ case.id, case.provenance });
        }
        try std.testing.expectEqual(expected.len, actual.len);
        for (expected) |label| try Support.expectPresent(label, actual);
        for (case.forbidden) |label| try Support.expectAbsent(label, actual);
        try Support.expectNoDuplicates(actual);

        const repeated = try Support.serverCompletionAfterTrigger(&server, allocator, uri, case.partial, ".");
        try Support.expectEqualItems(actual, repeated);
    }
}

test "Canvas constructor cascade stays semantic beside erroneous neighbours" {
    const canonical =
        \\public class Canvas {
        \\    public func fill() Canvas { return self }
        \\    public func stroke() Canvas { return self }
        \\    private func flush_internal() {}
        \\}
        \\func main() { Canvas()..fill()..stroke() }
    ;
    const partial =
        \\public class Canvas {
        \\    public func fill() Canvas { return self }
        \\    public func stroke() Canvas { return self }
        \\    private func flush_internal() {}
        \\}
        \\func main() { Canvas()..<|> }
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const expected = try Oracle.publicInstanceMembers(allocator, canonical, "Canvas");
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const uri = "file:///Sealed-Canvas-Cascade.sx";
    const clean = try Support.serverCompletionAfterTrigger(&server, allocator, uri, partial, ".");
    try Support.expectExactLabels(expected, clean);
    try Support.expectAbsent("flush_internal", clean);
    try Support.expectNoDuplicates(clean);

    const recovery_mutations = [_][]const u8{
        try std.fmt.allocPrint(allocator, "// Canvas 🙂\n{s}", .{partial}),
        try std.fmt.allocPrint(allocator, "func neighbour() {{ if }}\n{s}", .{partial}),
        try std.fmt.allocPrint(allocator, "{s}\nfunc broken( {{ }}", .{partial}),
    };
    for (recovery_mutations, 0..) |mutation, index| {
        const marked = try Support.removeMarker(allocator, mutation);
        try Support.changeDocument(&server, allocator, uri, @intCast(index + 2), marked.text);
        const recovered = try Support.serverCompletionInOpenDocumentAfterTrigger(&server, allocator, uri, marked, ".");
        try Support.expectEqualItems(clean, recovered);
        try Support.expectNoDuplicates(recovered);
    }
}
