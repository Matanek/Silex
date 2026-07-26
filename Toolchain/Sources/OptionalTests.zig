const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Parser = @import("Parser.zig").Parser;

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

fn expectParseError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), source);
    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqualStrings(message, parser.diagnostic.?.message);
}

test "lower null and optional promotion to deterministic typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func lift(value:int) int? { return value }
        \\func none() int? { return null }
        \\func main() {}
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        \\func @lift(%0:int) -> int? {
        \\entry:
        \\    %1:int? = optional.some %0
        \\    return %1
        \\}
        \\
        \\func @none() -> int? {
        \\entry:
        \\    %0:int? = optional.null
        \\    return %0
        \\}
        \\
        \\func @main() -> void {
        \\entry:
        \\    return
        \\}
        \\
    , text);
}

test "transport optional fundamentals and structures through language boundaries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box { let value:int? }
        \\func identity(value:int?) int? { return value }
        \\func absent() int? { return null }
        \\func present() int? { return 42 }
        \\func through_field() int? { return Box(value:9).value }
        \\func main() {
        \\    let absent:int?
        \\    let present:int? = 42
        \\    var current:int?
        \\    current = 9
        \\    identity(absent)
        \\    identity(present)
        \\    identity(Box(value:current).value)
        \\}
    );
    _ = try Interpreter.runCapture(allocator, compilation.ir);
    const absent = (try Interpreter.invoke(allocator, compilation.ir, 1, &.{})).optional;
    try std.testing.expect(absent.value == null);
    const present = (try Interpreter.invoke(allocator, compilation.ir, 2, &.{})).optional;
    try std.testing.expectEqual(@as(i64, 42), present.value.?.integer);
    const field = (try Interpreter.invoke(allocator, compilation.ir, 3, &.{})).optional;
    try std.testing.expectEqual(@as(i64, 9), field.value.?.integer);
}

test "use optional parameter context and preserve overload selection" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func accept(value:int?) int { return 1 }
        \\func choose(value:int?) int { return 2 }
        \\func choose(value:str?) int { return 3 }
        \\func main() {
        \\    let number:int? = 7
        \\    print(accept(null))
        \\    print(choose(number))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("1\n2\n", result.stdout);
}

test "reject invalid optional forms and context-free null" {
    try expectParseError("func invalid(value:void?) {} func main() {}", "'void?' is not a valid type");
    try expectParseError("func invalid(value:int??) {} func main() {}", "nested optional types are not supported");
    try expectCompileError("func main() { let value = null }", "'null' requires an expected optional type");
    try expectCompileError(
        "func main() { let value:int = null }",
        "'null' requires an expected optional type",
    );
    try expectCompileError(
        "func main() { let value:int? = 1; let required:int = value }",
        "variable 'required' expects 'int', found 'int?'",
    );
}

test "compare all optional presence states with null on either side" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func main() {
        \\    let absent:int?
        \\    let same_absence:int? = null
        \\    let first:int? = 7
        \\    let same:int? = 7
        \\    let other:int? = 8
        \\    print(absent == same_absence)
        \\    print(first == same)
        \\    print(first == other)
        \\    print(absent == first)
        \\    print(absent == null)
        \\    print(null != first)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\ntrue\nfalse\nfalse\ntrue\ntrue\n", result.stdout);
}

test "refine direct local presence in positive and negative branches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Position { let x:int }
        \\func inspect(position:Position?) {
        \\    if position != null { print(position.x) }
        \\    if null == position { print("missing") }
        \\    else { print(position.x + 1) }
        \\}
        \\func main() {
        \\    inspect(Position(x:41))
        \\    inspect(null)
        \\}
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "optional.unwrap") != null);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("41\n42\nmissing\n", result.stdout);
}

test "invalidate mutable proofs and keep compound or member proofs local" {
    try expectCompileError(
        "func main() { var value:int? = 1; if value != null { value = null; print(value + 1) } }",
        "operator '+' does not accept 'int?' and 'int'",
    );
    try expectCompileError(
        "func main() { let value:int? = 1; if !(value == null) { print(value + 1) } }",
        "operator '+' does not accept 'int?' and 'int'",
    );
    try expectCompileError(
        "func main() { let value:int? = 1; if value != null && true { print(value + 1) } }",
        "operator '+' does not accept 'int?' and 'int'",
    );
    try expectCompileError(
        "struct Box { let value:int? } func main() { let box = Box(value:1); if box.value != null { print(box.value + 1) } }",
        "operator '+' does not accept 'int?' and 'int'",
    );
}

test "bind optional values across conditional forms with deterministic effects" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func observed(value:int?) int? { print("source"); return value }
        \\func main() {
        \\    if item = observed(1) { print(item) }
        \\    if missing = observed(null) { print(100) }
        \\    if true {} elif skipped = observed(2) { print(skipped) }
        \\    if false {} elif reached = observed(3) { print(reached) }
        \\    if false {} else if (let alternative = observed(4)) { print(alternative) }
        \\    if var mutable = observed(5) { mutable += 1; print(mutable) }
        \\    var next:int? = 6
        \\    while item = observed(next) { print(item); next = null; continue }
        \\    next = 7
        \\    while (var item = observed(next)) { item += 1; print(item); break }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    try std.testing.expectEqualStrings(
        "source\n1\nsource\nsource\n3\nsource\n4\nsource\n6\nsource\n6\nsource\nsource\n8\n",
        result.stdout,
    );
}

test "enforce conditional binding type mutability scope and collisions" {
    try expectCompileError(
        "func main() { if value = 1 { print(value) } }",
        "conditional binding 'value' expects an optional source, found 'int'",
    );
    try expectCompileError(
        "func main() { if let value:int = null {} }",
        "expected '=' after conditional binding name",
    );
    try expectCompileError(
        "func main() { let item = 1; if item = null {} }",
        "variable 'item' is already declared in this scope",
    );
    try expectCompileError(
        "func main() { let source:int? = 1; if item = source { item = 2 } }",
        "cannot assign to immutable variable 'item'",
    );
    try expectCompileError(
        "func main() { let source:int? = 1; if item = source {} print(item) }",
        "unknown variable 'item'",
    );
}
