const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Project = @import("Project.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "construct inspect index and mutate fixed arrays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func changed(values:int[3]) int[3] {
        \\    var copy = values
        \\    copy[0] = 9
        \\    return copy
        \\}
        \\func main() {
        \\    var axes:int[3] = [1, 2, 3]
        \\    let copy = changed(axes)
        \\    axes[-1] += 4
        \\    let empty:int[0] = []
        \\    let nested:int[2][2] = [[10, 11], [20, 21]]
        \\    print(axes.count(), " ", axes.is_empty(), " ", axes[0], " ", axes[-1])
        \\    print(copy[0], " ", copy[2], " ", empty.count(), " ", empty.is_empty())
        \\    print(nested[1][-1])
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("3 false 1 7\n9 3 0 true\n21\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "collection.load") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "collection.replace") != null);
}

test "diagnose fixed array type literal index and mutability errors" {
    try expectCompileError("func main() { let values:int[3] = [1, 2] }", "array literal expects 3 values, found 2");
    try expectCompileError(
        "func main() { let values:int[2] = [1, 2]; let other:int[3] = [1, 2, 3]; let mismatch:int[2] = other }",
        "variable 'mismatch' expects 'int[2]', found 'int[3]'",
    );
    try expectCompileError("func main() { let values:int[2] = [1, 2]; print(values[true]) }", "collection index expects 'int', found 'bool'");
    try expectCompileError("func main() { let values:int[2] = [1, 2]; values[0] = 3 }", "cannot assign to immutable variable 'values'");
    try expectCompileError("func main() { let values = [] }", "array literal requires an expected fixed array type");
}

test "report fixed array bounds without partial execution" {
    const cases = [_]struct { source: []const u8, message: []const u8 }{
        .{ .source = "func main() { let values:int[3] = [1, 2, 3]; print(values[3]) }", .message = "<source>:1:58: runtime error: collection index 3 is out of bounds for count 3\n" },
        .{ .source = "func main() { let values:int[3] = [1, 2, 3]; print(values[-4]) }", .message = "<source>:1:58: runtime error: collection index -4 is out of bounds for count 3\n" },
    };
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var frontend = Frontend.Frontend.init(allocator);
        const result = try Interpreter.runCapture(allocator, (try frontend.compile(case.source)).ir);
        try std.testing.expectEqual(@as(u8, 1), result.exit_code);
        try std.testing.expectEqualStrings("", result.stdout);
        try std.testing.expectEqualStrings(case.message, result.stderr);
    }
}

test "compose fixed arrays through public module functions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Arrays.sx",
        .data = "public func changed(values:int[2]) int[2] { var copy = values; copy[1] = 9; return copy }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Arrays\nfunc main() { let source:int[2] = [1, 2]; let copy = Arrays.changed(source); print(source[1], copy[1]) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const result = try Interpreter.runCapture(allocator, (try compiler.compile(input)).ir);
    try std.testing.expectEqualStrings("29\n", result.stdout);
}
