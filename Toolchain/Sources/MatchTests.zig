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

test "compile terminal match nested in a mutating method branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Outcome { success(int); failure(str) }
        \\func outcome() Outcome { return Outcome.success(7) }
        \\class Parser {
        \\    var offset:int
        \\    public init(offset:int) { self.offset = offset }
        \\    public func run() Result<int, str> {
        \\        if self.offset == 0 {
        \\            match outcome() {
        \\                success(value) => { return Result<int, str>.success(value) }
        \\                failure(error) => { return Result<int, str>.failure(error) }
        \\            }
        \\        }
        \\        return Result<int, str>.success(0)
        \\    }
        \\}
        \\func main() {
        \\    var parser = Parser(0)
        \\    match parser.run() { success(value) => { assert(value == 7, "nested match") }; failure(error) => { panic(error) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
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

test "execute imperative match blocks with branch-local mutable copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum State { waiting; connected(str); closed(str) }
        \\func show(value:State) {
        \\    match value {
        \\        waiting => { print("waiting") }
        \\        connected(var name) => { name = "changed"; print(name) }
        \\        closed(reason) => { print(reason) }
        \\    }
        \\    match value { waiting => { print("kept") }; else => { print("kept other") } }
        \\}
        \\func classify(value:State) int {
        \\    match value { waiting => { return 1 }; connected(name) => { return 2 }; else => { return 3 } }
        \\}
        \\func main() {
        \\    show(State.waiting())
        \\    show(State.connected("server"))
        \\    print(classify(State.closed("done")))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("waiting\nkept\nchanged\nkept other\n3\n", result.stdout);
}

test "preserve enclosing break and continue through imperative match" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Action { stop; retry }
        \\func run(action:Action) {
        \\    var active = true
        \\    while active {
        \\        active = false
        \\        match action { stop => { break }; retry => { continue } }
        \\        print("unreachable")
        \\    }
        \\    print("done")
        \\}
        \\func main() { run(Action.stop()); run(Action.retry()) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("done\ndone\n", result.stdout);
}

test "diagnose mixed and misplaced match branch forms" {
    try expectCompileError(
        "enum Choice { left; right } func main() { match Choice.left() { left => { print(1) }; right => 2 } }",
        "match cannot mix expression and block branches",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { let value = match Choice.left() { left => { print(1) }; right => { print(2) } } }",
        "imperative match cannot be used as a value",
    );
    try expectCompileError(
        "enum Choice { left; right } func main() { match Choice.left() { left => 1; right => 2 } }",
        "match statement requires block branches",
    );
    try expectCompileError(
        "enum Choice { value(int); empty } func main() { match Choice.value(1) { value(number) => { print(number) }; empty => {} }; print(number) }",
        "unknown variable 'number'",
    );
}
