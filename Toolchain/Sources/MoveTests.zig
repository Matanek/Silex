const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    return std.testing.allocator.dupe(u8, result.stdout);
}

test "move locals parameters arguments returns and reinitialized vars" {
    const output = try run(
        \\func forward(value:int) int { return move value }
        \\func countdown(value:int) int {
        \\    if value == 0 { return move value }
        \\    return countdown(move value - 1)
        \\}
        \\func main() {
        \\    var original = 40
        \\    let transferred = move original
        \\    original = 2
        \\    print(forward(move original) + transferred)
        \\    print(countdown(3))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n0\n", output);
}

test "availability joins ignore terminal paths" {
    const output = try run(
        \\func show(stop:bool) {
        \\    let value = 7
        \\    if stop { print(move value); return }
        \\    print(value)
        \\}
        \\func main() { show(true); show(false) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("7\n7\n", output);
}

test "loops require the header availability to be restored" {
    const output = try run(
        \\func main() {
        \\    var value = 1
        \\    var index = 0
        \\    while index < 3 {
        \\        let current = move value
        \\        value = current + 1
        \\        index++
        \\    }
        \\    print(value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("4\n", output);
}

test "reject invalid move sources self moves and repeated use" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct Pair { var value:int }
        \\func main() { let pair = Pair(value:1); let value = move pair.value }
    ));
    try std.testing.expectEqualStrings("'move' requires a complete local binding or parameter", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { var value = 1; value = move value }"));
    try std.testing.expectEqualStrings("cannot move value 'value' into itself", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { let value = 1; let next = move value; print(value) }"));
    try std.testing.expectEqualStrings("value 'value' was moved and is unavailable", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { let value = 1; let first = move value; let second = move value }"));
    try std.testing.expectEqualStrings("value 'value' was moved and is unavailable", frontend.diagnostic.?.message);
}

test "reject availability differences at joins and loop back edges" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func main() {
        \\    let value = 1
        \\    if true { let consumed = move value }
        \\    print(value)
        \\}
    ));
    try std.testing.expectEqualStrings("value 'value' was moved and is unavailable", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func main() {
        \\    let value = 1
        \\    while true { let consumed = move value }
        \\}
    ));
    try std.testing.expectEqualStrings("loop must restore availability of 'value' before its next iteration", frontend.diagnostic.?.message);
}
