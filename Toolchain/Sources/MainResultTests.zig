const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

const Case = struct {
    source: []const u8,
    exit_code: u8,
    stdout: []const u8 = "",
    stderr: []const u8,
};

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "interpret recoverable main success and exact failure protocol" {
    const cases = [_]Case{
        .{ .source = "func main() Result<void,str> { return Result<void,str>.success() }", .exit_code = 0, .stderr = "" },
        .{ .source = "func main() Result<void,str> { print(\"before\"); return Result<void,str>.failure(\"configuration missing\") }", .exit_code = 1, .stdout = "before\n", .stderr = "error: configuration missing\n" },
        .{ .source = "func main() Result<void,str> { return Result<void,str>.failure(\"\") }", .exit_code = 1, .stderr = "error: \n" },
        .{ .source = "func main() Result<void,str> { return Result<void,str>.failure(\"échec 🔥\") }", .exit_code = 1, .stderr = "error: échec 🔥\n" },
        .{ .source = "func main() Result<void,str> { return Result<void,str>.failure(\"line\\n\") }", .exit_code = 1, .stderr = "error: line\n\n" },
    };
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var frontend = Frontend.Frontend.init(allocator);
        const result = try Interpreter.runCapture(allocator, (try frontend.compile(case.source)).ir);
        try std.testing.expectEqual(case.exit_code, result.exit_code);
        try std.testing.expectEqualStrings(case.stdout, result.stdout);
        try std.testing.expectEqualStrings(case.stderr, result.stderr);
    }
}

test "try propagates only string failures through recoverable main" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func load() Result<void,str> { return Result<void,str>.failure("missing") }
        \\func main() Result<void,str> {
        \\    try load()
        \\    return Result<void,str>.success()
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expectEqualStrings("error: missing\n", result.stderr);
}

test "diagnose every invalid main return contract" {
    try expectCompileError("func main() int { return 0 }", "'main' must return 'void' or 'Result<void,str>'");
    try expectCompileError(
        "func main() Result<int,str> { return Result<int,str>.success(0) }",
        "'main' must return 'void' or 'Result<void,str>'",
    );
    try expectCompileError(
        "func main() Result<void,int> { return Result<void,int>.failure(1) }",
        "'main' must return 'void' or 'Result<void,str>'",
    );
    try expectCompileError("func main<T>() {}", "'main' cannot be generic");
    try expectCompileError("func main(value:int) {}", "'main' must have no parameters");
    try expectCompileError("func main() {} func main(value:int) {}", "'main' cannot be overloaded");
    try expectCompileError(
        "func main() Result<void,str> { if true { return Result<void,str>.success() } }",
        "function 'main' must return 'Result<void,str>' on every path",
    );
    try expectCompileError(
        "func load() Result<void,int> { return Result<void,int>.failure(1) } func main() Result<void,str> { try load(); return Result<void,str>.success() }",
        "'try' error type 'int' does not match enclosing error type 'str'",
    );
}
