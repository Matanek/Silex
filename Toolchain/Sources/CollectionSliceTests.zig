const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

test "copy normalized slices from arrays and lists" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func main() {
        \\    var fixed:int[5] = [0, 1, 2, 3, 4]
        \\    var middle:int[] = fixed[1:4]
        \\    var values = [10, 20, 30, 40, 50]
        \\    let negative = values[-4:-1]
        \\    let clamped = values[-99:99]
        \\    let inverse = values[4:2]
        \\    fixed[2] = 9
        \\    middle[0] = 8
        \\    print(middle.count(), middle[0], middle[-1], fixed[1], fixed[2])
        \\    print(negative[0], negative[-1], " ", clamped.count(), clamped[0], clamped[-1], " ", inverse.count())
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("38319\n2040 51050 0\n", result.stdout);
}

test "reject omitted slice bounds" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile("func main() { let values = [1, 2]; let part = values[:1] }"));
    try std.testing.expectEqualStrings("slice and index bounds cannot be omitted", frontend.diagnostic.?.message);
}
