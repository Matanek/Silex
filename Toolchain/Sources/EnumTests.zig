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

test "construct and transport associated enum variants" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Connection {
        \\    waiting
        \\    connected(str)
        \\    measured(int, bool)
        \\}
        \\enum Other { waiting }
        \\struct Box { let connection:Connection }
        \\func identity(value:Connection) Connection { return value }
        \\func accept(value:Connection) int { return 42 }
        \\func main() {
        \\    let waiting = Connection.waiting
        \\    let connected = identity(Connection.connected("server"))
        \\    let measured = Connection.measured(7, true)
        \\    let box = Box(connection:connected)
        \\    print(accept(waiting))
        \\    print(accept(measured))
        \\    print(accept(box.connection))
        \\    Other.waiting()
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n42\n42\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.init @Connection.connected") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.init @Other.waiting()") != null);
}

test "use the first payload-free enum variant as an intrinsic field value" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Mode { none; configured(int) }
        \\struct State {
        \\    var mode:Mode
        \\    init(value:Mode) { self.mode = value }
        \\}
        \\func main() { let state = State(Mode.configured(7)); print(state.mode == Mode.configured(7)) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\n", result.stdout);
}

test "diagnose invalid associated enum construction" {
    try expectCompileError(
        "enum Choice { empty; value(int) } func main() { Choice.empty(1) }",
        "variant 'Choice.empty' expects 0 arguments, found 1",
    );
    try expectCompileError(
        "enum Choice { value(int) } func main() { Choice.value(false) }",
        "cannot implicitly convert 'bool' to 'int'",
    );
    try expectCompileError(
        "enum Choice { value(int) } func main() { let selected = Choice.value }",
        "variant 'Choice.value' expects 1 arguments and must be called",
    );
    try expectCompileError(
        "enum Choice { value } func main() { Choice.unknown() }",
        "enum 'Choice' has no variant named 'unknown'",
    );
    try expectCompileError(
        "enum Choice { value; value } func main() {}",
        "enum variant is already declared",
    );
}

test "compare enum variants and associated values recursively" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Token {
        \\    let name:str
        \\}
        \\enum Inner { number(int); empty }
        \\enum Choice { empty; pair(int, str); nested(Inner); token(Token) }
        \\enum Direction:int { north = 1; south = -2 }
        \\func main() {
        \\    var token = Token(name:"same")
        \\    var alias = token
        \\    var distinct = Token(name:"same")
        \\    print(Choice.empty == Choice.empty())
        \\    print(Choice.empty != Choice.pair(0, ""))
        \\    print(Choice.pair(7, "value") == Choice.pair(7, "value"))
        \\    print(Choice.pair(7, "value") != Choice.pair(8, "value"))
        \\    print(Choice.nested(Inner.number(3)) == Choice.nested(Inner.number(3)))
        \\    print(Choice.nested(Inner.number(3)) != Choice.nested(Inner.empty))
        \\    print(Choice.token(token) == Choice.token(alias))
        \\    print(Choice.token(token) != Choice.token(distinct))
        \\    print(Direction.north == Direction.north())
        \\    print(Direction.north() != Direction.south)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\ntrue\ntrue\ntrue\ntrue\ntrue\ntrue\ntrue\ntrue\ntrue\n", result.stdout);
}

test "use enum values in overloaded constructors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(
        \\enum Choice { empty; value(int) }
        \\struct Box {
        \\    init(value:Choice) {}
        \\    init(value:int) {}
        \\}
        \\func main() {
        \\    Box(Choice.empty())
        \\    Box(42)
        \\}
    );
}

test "construct and observe integer and string raw enums" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Direction:int { north = 1; south = -2 }
        \\enum Label:str { line = "line\nfeed"; plain = "plain" }
        \\func code(value:Direction) int { return value.raw_value }
        \\func direction_name(value:Direction) str { return match value { north => "north"; south => "south" } }
        \\func relay(value:Label) Label { return value }
        \\func main() {
        \\    print(code(Direction.north))
        \\    print(Direction.south.raw_value)
        \\    print(direction_name(Direction.north))
        \\    print(relay(Label.line).raw_value)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("1\n-2\nnorth\nline\nfeed\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum @Direction:int") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.raw") != null);
}

test "diagnose invalid raw enum declarations and uses" {
    try expectCompileError(
        "enum Invalid:bool { value = true } func main() {}",
        "raw enum type must be 'int' or 'str'",
    );
    try expectCompileError(
        "enum Invalid:int { value } func main() {}",
        "raw enum variant requires a literal value",
    );
    try expectCompileError(
        "enum Invalid:int { value = \"text\" } func main() {}",
        "raw enum value must be an 'int' literal",
    );
    try expectCompileError(
        "enum Invalid:str { value = 1 } func main() {}",
        "raw enum value must be a 'str' literal",
    );
    try expectCompileError(
        "enum Invalid:int { value = 1 + 2 } func main() {}",
        "raw enum value must be one literal",
    );
    try expectCompileError(
        "enum Invalid:int { first = 1; second = 1 } func main() {}",
        "raw enum value is already used by another variant",
    );
    try expectCompileError(
        "enum Invalid:str { first = \"line\\n\"; second = \"line\\u{A}\" } func main() {}",
        "raw enum value is already used by another variant",
    );
    try expectCompileError(
        "enum Invalid:int { value(str) = 1 } func main() {}",
        "raw enum variants cannot carry associated values",
    );
    try expectCompileError(
        "enum Invalid { value = 1 } func main() {}",
        "associated enum variants cannot declare raw values",
    );
    try expectCompileError(
        "enum Associated { value } func main() { print(Associated.value().raw_value) }",
        "associated enum has no 'raw_value' property",
    );
    try expectCompileError(
        "enum Direction:int { north = 1 } func main() { var value = Direction.north(); value.raw_value = 2 }",
        "enum property 'raw_value' is read-only",
    );
    try expectCompileError(
        "enum Direction:int { north = 1 } func main() { Direction(1) }",
        "enum 'Direction' must be constructed through one of its variants",
    );
    try expectCompileError(
        "enum Direction:int { north = 1 } func main() { let raw = Direction.north() as int }",
        "'as' requires numeric source and target types",
    );
    try expectCompileError(
        "enum Direction:int { north = 1 } func main() { let value = 1 as Direction }",
        "'as' requires numeric source and target types",
    );
}
