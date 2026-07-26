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
        \\    let waiting = Connection.waiting()
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
        "enum Choice { value } func main() { Choice.unknown() }",
        "enum 'Choice' has no variant named 'unknown'",
    );
    try expectCompileError(
        "enum Choice { value } func main() { let equal = Choice.value() == Choice.value() }",
        "operator '==' does not accept 'Choice' and 'Choice'",
    );
    try expectCompileError(
        "enum Choice { value; value } func main() {}",
        "enum variant is already declared",
    );
}

test "use enum values in overloaded constructors" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(
        \\enum Choice { empty; value(int) }
        \\struct Box {
        \\    init(selected:Choice) {}
        \\    init(number:int) {}
        \\}
        \\func main() {
        \\    Box(Choice.empty())
        \\    Box(42)
        \\}
    );
}
