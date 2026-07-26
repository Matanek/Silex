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
