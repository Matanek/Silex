const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

test "mutate fixed arrays and dynamic lists with value semantics" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func main() {
        \\    var fixed:int[3] = [1, 2, 3]
        \\    let old_fixed = fixed.replace(1, 8)
        \\    fixed.swap(0, -1)
        \\    fixed.reverse()
        \\    var values = [1, 2, 3]
        \\    let duplicate = values
        \\    let previous = values.replace(1, 8)
        \\    values.swap(0, -1)
        \\    values.reverse()
        \\    values.append(4)
        \\    values.append([5, 6])
        \\    values.prepend(0)
        \\    values.insert(2, 7)
        \\    let removed = values.take(3)
        \\    let first = values.take_first()
        \\    let last = values.take_last()
        \\    values.reverse()
        \\    print(old_fixed, fixed[0], fixed[1], fixed[2])
        \\    print(previous, removed, first, last, " ", values.count(), " ", values[0], values[-1], " ", duplicate[1])
        \\    values.clear()
        \\    print(values.count(), values.is_empty())
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("2183\n2806 5 51 2\n0true\n", result.stdout);
}

test "reject collection mutation through let" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { let values = [1, 2]; values.append(3) }"));
    try std.testing.expectEqualStrings("collection mutation requires a var receiver", frontend.diagnostic.?.message);
}
