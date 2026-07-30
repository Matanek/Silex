const std = @import("std");
const builtin = @import("builtin");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Lower = @import("Arm64/Lower.zig");
const Runner = @import("Arm64/Runner.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "transport named and positional tuples through parameters returns nesting and destructuring" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func size(seed:int) (width:int, height:int) {
        \\    return (width:seed + 1, height:seed + 2)
        \\}
        \\func sum(pair:(int, int)) int {
        \\    let (left, right) = pair
        \\    return left + right
        \\}
        \\func answer() int {
        \\    let value = size(40)
        \\    let (width, height) = value
        \\    let nested:((x:int, y:int), bool) = ((x:width, y:height), true)
        \\    let (point, visible) = nested
        \\    if visible { return point.x + point.y + sum((1, 2)) }
        \\    return 0
        \\}
        \\func main() { print(answer()) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("86\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "(width:int, height:int)") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "$tuple") == null);
}

test "infer a first class named tuple literal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func main() {
        \\    let point = (x:20, y:22)
        \\    print(point.x + point.y)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "use tuple types in generic functions and collections" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func swap<T>(pair:(T, T)) (T, T) {
        \\    let (left, right) = pair
        \\    return (right, left)
        \\}
        \\func main() {
        \\    let pairs:(int, int)[2] = [(1, 2), (3, 4)]
        \\    let changed = swap(pairs[1])
        \\    let (first, second) = changed
        \\    print(first, second)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("43\n", result.stdout);
}

test "diagnose tuple names arity types destructuring and positional access" {
    try expectCompileError(
        "func size() (width:int, height:int) { return (height:1, width:2) } func main() {}",
        "tuple element 1 expects name 'width', found 'height'",
    );
    try expectCompileError(
        "func size() (width:int, height:int) { return (width:1, height:true) } func main() {}",
        "tuple element 2 expects 'int', found 'bool'",
    );
    try expectCompileError(
        "func size() (int, int) { return (1, 2) } func main() { let (only, extra, third) = size() }",
        "tuple destructuring expects 2 bindings, found 3",
    );
    try expectCompileError(
        "func size() (int, int) { return (1, 2) } func main() { let value = size(); print(value.width) }",
        "a positional tuple has no named members; use destructuring",
    );
    try expectCompileError("func main() { let value = (x:1, x:2) }", "tuple element name 'x' is duplicated");
    try expectCompileError(
        "func size() (width:int, height:int) { return (1, 2) } func main() {}",
        "named tuple expression must repeat the declared element names",
    );
    try expectCompileError(
        "func size() (width:int, height:int) { return (width:1, height:2, depth:3) } func main() {}",
        "tuple expects 2 elements, found 3",
    );
    try expectCompileError(
        "func main() { var value = (x:1, y:2); value.x = 3 }",
        "cannot assign through immutable field 'x'",
    );
}

test "destructuring preserves recursive tuple destruction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Token {
        \\    let id:int
        \\    drop { print(self.id) }
        \\}
        \\func main() {
        \\    let pair:(Token, Token) = (Token(id:1), Token(id:2))
        \\    let (first, second) = move pair
        \\    print(first.id, second.id)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("12\n2\n1\n", result.stdout);
}

test "native ARM64 transports tuple aggregates like the interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func pair(value:int) (first:int, second:int) { return (first:value, second:value + 1) }
        \\func answer() int { let value = pair(20); let (left, right) = value; return left + right + value.second - value.first }
        \\func main() {}
    );
    var function_id: ?usize = null;
    for (compilation.ir.functions, 0..) |function, index| {
        if (std.mem.eql(u8, function.name, "answer")) function_id = index;
    }
    const id = function_id orelse return error.TestUnexpectedResult;
    const reference = try Interpreter.invoke(allocator, compilation.ir, id, &.{});
    const machine = try Lower.lower(allocator, compilation.ir);
    const native = try Runner.invoke(allocator, machine, id, &.{});
    try std.testing.expectEqual(Interpreter.Value{ .integer = 42 }, reference);
    try std.testing.expectEqual(@as(i64, 42), native.value);
}
