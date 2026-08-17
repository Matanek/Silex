const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");

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

test "append an element through optional promotion" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func main() {
        \\    var values:int?[] = []
        \\    values.append(42)
        \\    if value = values[0] { print(value) }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "mutate a dynamic list stored in a mutable field" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Values {
        \\    var items:int[]
        \\    func append(value:int) { self.items.append(value) }
        \\}
        \\func main() { var values = Values(items:[]); values.append(42); print(values.items[0]) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "preserve edge ownership while replacing a class-owned list" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Values {
        \\    var items:int[]
        \\    init() { self.items = [1, 2, 3] }
        \\    func reorder() { self.items.swap(0, 2) }
        \\}
        \\func main() { var values = Values(); values.reorder(); print(values.items[0]) }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("3\n", result.stdout);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "collection.replace") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, ", edge") != null);
}

test "mutate fields of collection elements in place" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Position { var x:int; var y:int }
        \\struct Vertex { var position:Position }
        \\func main() {
        \\    var vertices:Vertex[] = [Vertex(position:Position(x:1, y:2))]
        \\    vertices[0].position.x = 7
        \\    vertices[0].position.y += 3
        \\    print(vertices[0].position.x, " ", vertices[0].position.y)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("7 5\n", result.stdout);
}
