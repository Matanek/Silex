const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "execute anonymous scopes once and end local lifetimes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Resource { let name:str; drop { print("drop ", self.name) } }
        \\func early() int { { let resource = Resource(name:"return"); return 7 } }
        \\func main() {
        \\    let outer = 1
        \\    { let temporary = Resource(name:"normal"); print(outer, " ", temporary.name) }
        \\    print("after")
        \\    { let reused = 2; print(reused) }
        \\    { let reused = 3; print(reused) }
        \\    var index = 0
        \\    while index < 3 {
        \\        index++
        \\        { let resource = Resource(name:"loop $(index)"); if index == 1 { continue } if index == 2 { break } }
        \\    }
        \\    print(early())
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "1 normal\ndrop normal\nafter\n2\n3\ndrop loop 1\ndrop loop 2\ndrop return\n7\n",
        result.stdout,
    );
}

test "enforce anonymous scope visibility and ordinary control targets" {
    try expectCompileError("func main() { { let scoped = 1 } print(scoped) }", "unknown variable 'scoped'");
    try expectCompileError("func main() { let value = 1; { let value = 2 } }", "variable 'value' is already declared in this scope");
    try expectCompileError("func main() { { break } }", "'break' is only valid inside a loop");
    try expectCompileError("func main() { { continue } }", "'continue' is only valid inside a loop");
}

test "anonymous scopes clean try propagation and end bound receiver borrows" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Resource { let name:str; drop { print("drop ", self.name) } }
        \\struct Counter { var value:int; func increment() { self.value++ } }
        \\func failure() Result<void,str> { return Result<void,str>.failure("stop") }
        \\func scoped() Result<void,str> {
        \\    { let resource = Resource(name:"try"); try failure() }
        \\    return Result<void,str>.success()
        \\}
        \\func main() {
        \\    var counter = Counter(value:0)
        \\    { let increment:func() = counter.increment; increment() }
        \\    counter.value += 1
        \\    print(counter.value)
        \\    match scoped() { success => {}; failure(message) => { print(message) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("2\ndrop try\nstop\n", result.stdout);
}

test "anonymous scopes are unavailable in expression position" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        "func main() { let value = { let inner = 1 } }",
    ));
    try std.testing.expect(std.mem.indexOf(u8, frontend.diagnostic.?.message, "expression") != null);
}
