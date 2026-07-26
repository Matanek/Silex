const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "evaluate exhaustive associated enum matches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Connection { waiting; connected(str); measured(int, bool) }
        \\func observe(value:Connection) Connection { print("subject"); return value }
        \\func describe(value:Connection) str {
        \\    return match observe(value) {
        \\        waiting => "waiting"
        \\        connected(name) => name
        \\        measured(let count, var enabled) => "measured"
        \\    }
        \\}
        \\func emit(text:str) { print(text) }
        \\func main() {
        \\    let first = describe(Connection.waiting())
        \\    emit(first)
        \\    emit(describe(Connection.connected("server")))
        \\    emit(describe(Connection.measured(7, true)))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("subject\nwaiting\nsubject\nserver\nsubject\nmeasured\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.test") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.payload") != null);
}

test "diagnose invalid exhaustive match patterns" {
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1 } }",
        "match is missing variant 'right'",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1; left => 2 } }",
        "variant 'left' is matched more than once",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1; unknown => 2 } }",
        "enum 'Choice' has no variant named 'unknown'",
    );
    try expectCompileError(
        "enum Choice { left(int); right } func main() { let value = match Choice.left(1) { left => 1; right => 2 } }",
        "variant 'left' exposes 1 associated values, pattern binds 0",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1 as int8; right => 2 } }",
        "match branch expects exact type 'int8', found 'int'",
    );
    try expectCompileError(
        "enum Choice { left; right } func optional() int? { return 1 } func main() { let value = match Choice.left() { left => optional(); right => 2 } }",
        "match branch expects exact type 'int?', found 'int'",
    );
    try expectCompileError(
        "func main() { let value = match 1 { left => 1 } }",
        "match requires an enum subject, found 'int'",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => match Choice.right() { left => 1; right => 2 }; right => 2 } }",
        "nested match expressions are not available",
    );
}

test "keep match bindings scoped to their branch" {
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { let result = match Choice.value(1) { value(number) => number; empty => 0 }; print(number) }",
        "unknown variable 'number'",
    );
}

test "route unmatched variants through a terminal else branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Direction { north; south; east; west }
        \\func vertical(value:Direction) bool {
        \\    return match value { north => true; south => true; else => false }
        \\}
        \\func main() {
        \\    print(vertical(Direction.north()))
        \\    print(vertical(Direction.east()))
        \\    print(match Direction.west() { else => "fallback" })
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\nfalse\nfallback\n", result.stdout);
}

test "diagnose invalid else match branches" {
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1; right => 2; else => 3 } }",
        "else match branch is unreachable because every variant is already covered",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { else => 1; left => 2 } }",
        "else match branch must be last",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1; else(name) => 2 } }",
        "else match branch cannot bind associated values",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => 1 as int8; else => 2 } }",
        "match branch expects exact type 'int8', found 'int'",
    );
}
