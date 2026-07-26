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

test "map Result errors once while preserving value and void successes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func convert(error:str) int { print("transform"); return error.count() }
        \\func load(allowed:bool) Result<int, str> {
        \\    if allowed { return Result<int, str>.success(42) }
        \\    return Result<int, str>.failure("bad")
        \\}
        \\func save(allowed:bool) Result<void, str> {
        \\    if allowed { return Result<void, str>.success() }
        \\    return Result<void, str>.failure("denied")
        \\}
        \\func main() {
        \\    match map_error(load(true), convert) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match map_error<int, str, int>(load(false), convert) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match map_error(save(true), convert) { success => { print("saved") }; failure(error) => { print(error) } }
        \\    match map_error<str, int>(save(false), convert) { success => { print("saved") }; failure(error) => { print(error) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\ntransform\n3\nsaved\ntransform\n6\n", result.stdout);
}

test "map_error composes explicitly with try" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func convert(error:str) int { return error.count() }
        \\func source() Result<int, str> { return Result<int, str>.failure("bad") }
        \\func mapped() Result<bool, int> {
        \\    let value = try map_error(source(), convert)
        \\    return Result<bool, int>.success(value == 42)
        \\}
        \\func main() { match mapped() { success(value) => { print(value) }; failure(error) => { print(error) } } }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("3\n", result.stdout);
}

test "map_error selects a compatible named overload" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func convert(error:int) str { return "number" }
        \\func convert(error:str) bool { return error == "bad" }
        \\func source() Result<int, str> { return Result<int, str>.failure("bad") }
        \\func main() {
        \\    match map_error<int, str, bool>(source(), convert) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\n", result.stdout);
}

test "diagnose invalid map_error calls and reserve its name" {
    try expectCompileError(
        "func convert(error:str) int { return 1 } func main() { map_error(1, convert) }",
        "'map_error' expects 'Result<T,E>', found 'int'",
    );
    try expectCompileError(
        "func convert(error:int) str { return \"bad\" } func source() Result<int, str> { return Result<int, str>.failure(\"bad\") } func main() { map_error(source(), convert) }",
        "'map_error' transformation must have signature 'func(str) F'",
    );
    try expectCompileError(
        "func source() Result<int, str> { return Result<int, str>.failure(\"bad\") } func main() { let convert = 1; map_error(source(), convert) }",
        "unknown transformation function 'convert'",
    );
    try expectCompileError(
        "func convert(error:str) int { return 1 } func source() Result<int, str> { return Result<int, str>.failure(\"bad\") } func main() { map_error<int, str>(source(), convert) }",
        "'map_error' expects 3 explicit type arguments matching its Result and transformation",
    );
    try expectCompileError(
        "func map_error(value:int) int { return value } func main() {}",
        "'map_error' is a reserved intrinsic function name",
    );
    try expectCompileError(
        "func main() { let map_error = 1 }",
        "'map_error' is a reserved intrinsic function name",
    );
    try expectCompileError(
        "use Library as map_error\nfunc main() {}",
        "'map_error' is a reserved intrinsic function name",
    );
}
