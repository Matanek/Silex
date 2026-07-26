const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(source);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    return std.testing.allocator.dupe(u8, result.stdout);
}

test "iterate arrays and lists with read and copied bindings" {
    const output = try run(
        \\func main() {
        \\    let fixed:int[3] = [1, 2, 3]
        \\    for value in fixed { print(value) }
        \\    let values = [4, 5]
        \\    for let value in values { print(value) }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("1\n2\n3\n4\n5\n", output);
}

test "mutable collection bindings write through on fallthrough continue and break" {
    const output = try run(
        \\func main() {
        \\    var values = [1, 2, 3, 4]
        \\    for var value in values {
        \\        value += 10
        \\        if value == 12 { continue }
        \\        if value == 13 { break }
        \\    }
        \\    print(values[0], values[1], values[2], values[3])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("1112134\n", output);
}

test "mutable fixed-array bindings write through" {
    const output = try run(
        \\func main() {
        \\    var values:int[3] = [1, 2, 3]
        \\    for var value in values { value *= 2 }
        \\    print(values[0], values[1], values[2])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("246\n", output);
}

test "specialize generic functions containing collection iteration" {
    const output = try run(
        \\func show<T>(values:T[]) {
        \\    for value in values { print(value) }
        \\}
        \\func main() {
        \\    show([1, 2])
        \\    show(["Silex"])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("1\n2\nSilex\n", output);
}

test "iterate ascending descending and empty exclusive ranges" {
    const output = try run(
        \\func main() {
        \\    for i in 0...3 { print(i) }
        \\    for let i in range(3, 0) { print(i) }
        \\    for i in 2...2 { print(99) }
        \\    for (var i in range(0, 3)) {
        \\        i += 100
        \\        print(i)
        \\    }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("0\n1\n2\n3\n2\n1\n100\n101\n102\n", output);
}

test "evaluate collection source and range bounds once from left to right" {
    const output = try run(
        \\func values() int[] { print("V"); return [7, 8] }
        \\func start() int { print("S"); return 0 }
        \\func end() int { print("E"); return 2 }
        \\func main() {
        \\    for value in values() { print(value) }
        \\    for i in start()...end() { print(i) }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("V\n7\n8\nS\nE\n0\n1\n", output);
}

test "for bindings are scoped and read bindings cannot be reassigned" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func main() {
        \\    for value in [1] { value = 2 }
        \\}
    ));
    try std.testing.expectEqualStrings("cannot assign to immutable variable 'value'", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func main() {
        \\    for value in [1] { print(value) }
        \\    print(value)
        \\}
    ));
    try std.testing.expectEqualStrings("unknown variable 'value'", frontend.diagnostic.?.message);
}

test "reject invalid for sources bounds and mutable temporaries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { for value in 42 { print(value) } }"));
    try std.testing.expectEqualStrings("for source expects an array or list", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { for value in range(0, true) { print(value) } }"));
    try std.testing.expectEqualStrings("range bounds expect 'int'", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { for var value in [1, 2] { print(value) } }"));
    try std.testing.expectEqualStrings("for var requires a var collection binding", frontend.diagnostic.?.message);
}
