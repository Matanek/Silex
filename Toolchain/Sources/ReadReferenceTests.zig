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

test "read-reference parameters accept readable places and temporaries" {
    const output = try run(
        \\struct Box {
        \\    let value:int
        \\    func get() int { return self.value }
        \\}
        \\func make() int { return 6 }
        \\func read(value:@int) int { return value + 1 }
        \\func describe(box:@Box) int { return box.get() }
        \\func main() {
        \\    let fixed = 1
        \\    var mutable = 2
        \\    let box = Box(value:3)
        \\    let values = [4, 5]
        \\    print(read(fixed), read(mutable), read(box.value), read(values[0]), read(5), read(make()))
        \\    print(describe(box))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("234567\n3\n", output);
}

test "forward and coexist read references without consuming their root" {
    const output = try run(
        \\func sum(first:@int, second:@int) int { return first + second }
        \\func forward(value:@int) int { return sum(value, value) }
        \\func first(values:@int[]) int { return values[0] + 0 }
        \\func with_default(value:@int = 21) int { return value * 2 }
        \\func main() {
        \\    var value = 20
        \\    print(forward(value), with_default())
        \\    print(first([7, 8]))
        \\    let transferred = move value
        \\    print(transferred)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("4042\n7\n20\n", output);
}

test "reject mutation and move conflicts between call arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func combine(first:@int, second:int) int { return first + second }
        \\func main() { var value = 1; print(combine(value, move value)) }
    ));
    try std.testing.expectEqualStrings("cannot move or mutate 'value' while it is passed as '@int'", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func combine(values:@int[], removed:int) int { return values.count() + removed }
        \\func main() { var values = [1, 2]; print(combine(values, values.take_first())) }
    ));
    try std.testing.expect(std.mem.startsWith(u8, frontend.diagnostic.?.message, "cannot move or mutate 'values' while it is passed as '@"));
}

test "reject moving returning or storing a read-reference parameter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile("func leak(value:@int) int { return value } func main() { print(leak(1)) }"));
    try std.testing.expectEqualStrings("read-reference parameter 'value' cannot be returned", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile("func store(value:@int) { let copy = value } func main() { store(1) }"));
    try std.testing.expectEqualStrings("read-reference parameter 'value' cannot be stored", frontend.diagnostic.?.message);

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile("func consume(value:@int) { let copy = move value } func main() { consume(1) }"));
    try std.testing.expectEqualStrings("a read-reference parameter cannot be consumed with 'move'", frontend.diagnostic.?.message);
}

test "reference mode alone cannot distinguish overloads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func inspect(value:int) {}
        \\func inspect(value:@int) {}
        \\func main() {}
    ));
    try std.testing.expectEqualStrings("function 'inspect' with these parameter types is already declared", frontend.diagnostic.?.message);
}
