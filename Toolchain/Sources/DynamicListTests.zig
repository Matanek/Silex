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

test "infer construct transport copy and index dynamic lists" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func changed(values:int[]) int[] { var duplicate = values; duplicate[0] = 9; return duplicate }
        \\func main() {
        \\    let inferred = [1, 2, 3]
        \\    let empty:int[] = []
        \\    let nested:int[][] = [[10, 11], [20]]
        \\    let duplicate = changed(inferred)
        \\    print(inferred.count(), " ", inferred.is_empty(), " ", inferred[-1])
        \\    print(empty.count(), " ", empty.is_empty(), " ", duplicate[0], " ", nested[0][1])
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("3 false 3\n0 true 9 11\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "list.init") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "collection.count") != null);
}

test "diagnose dynamic list element and empty inference errors" {
    try expectCompileError("func main() { let values:int[] = [1, true] }", "cannot implicitly convert 'bool' to 'int'");
    try expectCompileError("func main() { let values = [] }", "empty or non-fundamental list literal requires an expected collection type");
}

test "report dynamic list bounds" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile("func main() { let values = [1, 2]; print(values[-3]) }")).ir);
    try std.testing.expectEqual(@as(u8, 1), result.exit_code);
    try std.testing.expectEqualStrings("<source>:1:48: runtime error: collection index -3 is out of bounds for count 2\n", result.stderr);
}
