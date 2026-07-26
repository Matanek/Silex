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

test "propagate Result successes failures and void with one operand evaluation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func read(allowed:bool) Result<int, str> {
        \\    print("read")
        \\    if allowed { return Result<int, str>.success(40) }
        \\    return Result<int, str>.failure("denied")
        \\}
        \\func propagated(allowed:bool) Result<int, str> {
        \\    print("before")
        \\    let value = try read(allowed) + 2
        \\    print("after")
        \\    return Result<int, str>.success(value)
        \\}
        \\func save(allowed:bool) Result<void, str> {
        \\    print("save")
        \\    if allowed { return Result<void, str>.success() }
        \\    return Result<void, str>.failure("not saved")
        \\}
        \\func save_all(allowed:bool) Result<void, str> {
        \\    try save(allowed)
        \\    print("after save")
        \\    return Result<void, str>.success()
        \\}
        \\func main() {
        \\    match propagated(true) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match propagated(false) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match save_all(true) { success => { print("saved") }; failure(error) => { print(error) } }
        \\    match save_all(false) { success => { print("saved") }; failure(error) => { print(error) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        "before\nread\nafter\n42\nbefore\nread\ndenied\nsave\nafter save\nsaved\nsave\nnot saved\n",
        result.stdout,
    );
}

test "lower try as deterministic ordinary enum control flow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func read() Result<int, str> { return Result<int, str>.success(42) }
        \\func propagate() Result<bool, str> {
        \\    let value = try read()
        \\    return Result<bool, str>.success(value == 42)
        \\}
        \\func main() { match propagate() { success(value) => { print(value) }; failure(error) => { print(error) } } }
    );
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.test") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "enum.payload") != null);
    try std.testing.expect(std.mem.count(u8, text, "return") >= 3);
}

test "diagnose invalid try operands contexts and error types" {
    try expectCompileError(
        "func compute() Result<int, str> { return try 1 } func main() {}",
        "'try' expects 'Result<T,E>', found 'int'",
    );
    try expectCompileError(
        "func read() Result<int, str> { return Result<int, str>.success(1) } func compute() int { return try read() } func main() {}",
        "'try' requires an enclosing function returning 'Result<U,E>'",
    );
    try expectCompileError(
        "struct ReadError {} struct SaveError {} func read() Result<int, ReadError> { return Result<int, ReadError>.success(1) } func save() Result<int, SaveError> { return Result<int, SaveError>.success(try read()) } func main() {}",
        "'try' error type 'ReadError' does not match enclosing error type 'SaveError'",
    );
    try expectCompileError(
        "func read() Result<void, str> { return Result<void, str>.success() } func value() Result<int, str> { let item = try read(); return Result<int, str>.success(item) } func main() {}",
        "'try' of 'Result<void,E>' does not produce a value",
    );
    try expectCompileError(
        "func read() Result<int, str> { return Result<int, str>.success(1) } func value() Result<void, str> { try read(); return Result<void, str>.success() } func main() {}",
        "the success value produced by 'try' must be used",
    );
    try expectCompileError(
        "func read() Result<int, str> { return Result<int, str>.success(1) } struct Box { let value:int; init() { self.value = try read() } } func main() {}",
        "'try' requires an enclosing function returning 'Result<U,E>'",
    );
}
