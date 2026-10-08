const std = @import("std");
const builtin = @import("builtin");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Lower = @import("Arm64/Lower.zig");
const Runner = @import("Arm64/Runner.zig");

test "native and interpreter agree on reordered named arguments" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func combine(first:int = 1, second:int = 2, third:int = 3) int { return first + second + third }
        \\struct Box {
        \\    var value:int
        \\    init(value:int, scale:int = 2) { self.value = value * scale }
        \\    func add(left:int, right:int = 1) int { return self.value + left + right }
        \\    static func sum(left:int, right:int = 1) int { return left + right }
        \\}
        \\func answer() int {
        \\    return combine(third:30, first:10) + Box(scale:3, value:4).add(right:2, left:1) + Box.sum(right:2, left:3)
        \\}
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
    try std.testing.expectEqual(Interpreter.Value{ .integer = 62 }, reference);
    try std.testing.expectEqual(@as(i64, 62), native.value);
}

test "named overloaded functions and static methods share collection argument context" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\public struct Item { let value:int }
        \\func pick(selector:int, values:Item[], extra:int = 0) int { return values.count() + extra }
        \\func pick(selector:str, values:Item[], extra:int = 0) int { return values.count() + extra }
        \\public static struct Factory {
        \\    func pick(selector:int, values:Item[], extra:int = 0) int { return values.count() + extra }
        \\    func pick(selector:str, values:Item[], extra:int = 0) int { return values.count() + extra }
        \\}
        \\func answer() int {
        \\    let item = Item(value:42)
        \\    return pick(values:[item], selector:1, extra:10) + pick(selector:"", values:[]) + Factory.pick(1, values:[item], extra:20) + Factory.pick(1, [item], 9)
        \\}
        \\func main() {}
    );
    var id: ?usize = null;
    for (compilation.ir.functions, 0..) |function, index| {
        if (std.mem.eql(u8, function.name, "answer")) id = index;
    }
    const function_id = id orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(Interpreter.Value{ .integer = 42 }, try Interpreter.invoke(allocator, compilation.ir, function_id, &.{}));
    const native = try Runner.invoke(allocator, try Lower.lower(allocator, compilation.ir), function_id, &.{});
    try std.testing.expectEqual(@as(i64, 42), native.value);
}

test "named overloads do not invent a collection context when candidate types differ" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\public struct Item { let value:int }
        \\func pick(selector:int, values:Item[]) int { return values.count() }
        \\func pick(selector:str, values:int[]) int { return values.count() }
        \\func main() { let count = pick(selector:1, values:[]) }
    ));
}
