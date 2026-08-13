const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Project = @import("Project.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(source);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    return std.testing.allocator.dupe(u8, result.stdout);
}

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
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

test "collection for loops carry their proven bounds to the backend" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func main() {
        \\    let values = [3, 5, 8]
        \\    for value in values { print(value) }
        \\    print(values[1])
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(source);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "collection.load %") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, " bounded") != null);
    try std.testing.expect(std.mem.indexOfPos(u8, text, std.mem.indexOf(u8, text, " bounded").? + 8, "collection.load ") != null);
}

test "for bindings retain class roots copied from returned collections" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\class Item {}
        \\func items() Item[] { return [Item(), Item()] }
        \\func main() { for item in items() { print("item") } }
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(source);
    const text = try Ir.writeText(allocator, compilation.ir);
    const loop_load = std.mem.indexOf(u8, text, "collection.load") orelse return error.TestExpectedEqual;
    try std.testing.expect(std.mem.indexOfPos(u8, text, loop_load, "class.retain") != null);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("item\nitem\n", result.stdout);
}

test "iterate fixed arrays and dynamic lists with zero-origin indices" {
    const output = try run(
        \\func values() int[] { print("source"); return [7, 8, 9] }
        \\func main() {
        \\    let fixed:int[3] = [3, 4, 5]
        \\    for index, item in fixed.indexed() {
        \\        if index == 1 { continue }
        \\        print(index, ":", item)
        \\    }
        \\    for position, let item in values().indexed() {
        \\        print(position, ":", item)
        \\        if position == 1 { break }
        \\    }
        \\    let empty:int[0] = []
        \\    for index, item in empty.indexed() { print(index, item) }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("0:3\n2:5\nsource\n0:7\n1:8\n", output);
}

test "mutable indexed element bindings write through on continue and break" {
    const output = try run(
        \\func main() {
        \\    var values = [10, 20, 30, 40]
        \\    for index, var item in values.indexed() {
        \\        item += index
        \\        if index == 1 { continue }
        \\        if index == 2 { break }
        \\    }
        \\    print(values[0], " ", values[1], " ", values[2], " ", values[3])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("10 21 32 40\n", output);
}

test "indexed bindings are scoped immutable and require indexed collections" {
    try expectCompileError(
        "func main() { for index, item in [1].indexed() { index = 2 } }",
        "cannot assign to immutable variable 'index'",
    );
    try expectCompileError(
        "func main() { for index, item in [1].indexed() {} print(index) }",
        "unknown variable 'index'",
    );
    try expectCompileError(
        "func main() { for index, item in 42.indexed() { print(index, item) } }",
        "indexed() expects an array or list",
    );
    try expectCompileError(
        "func main() { for index, item in [1] { print(index, item) } }",
        "double for binding requires an indexed() array or list source",
    );
    try expectCompileError(
        "func main() { for index, item in 0...2 { print(index, item) } }",
        "double for binding requires an indexed() array or list source",
    );
    try expectCompileError(
        "func main() { for var index, item in [1].indexed() {} }",
        "indexed for binding mode belongs before the element",
    );
    try expectCompileError(
        "func main() { for item in [1].indexed() { print(item) } }",
        "indexed() traversal requires two for bindings",
    );
    try expectCompileError(
        "func main() { let values = [1]; for index, var item in values.indexed() {} }",
        "for var requires a var collection binding",
    );
    try expectCompileError(
        "func main() { let values = [1]; let view = @values[0:1]; for index, item in view.indexed() {} }",
        "indexed() expects an array or list",
    );
}

test "indexed iteration emits deterministic typed IR" {
    const source = "func main() { let values = [4, 5]; for index, item in values.indexed() { print(index, item) } }";
    var first_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer first_arena.deinit();
    var first_frontend = Frontend.Frontend.init(first_arena.allocator());
    const first = try Ir.writeText(first_arena.allocator(), (try first_frontend.compile(source)).ir);

    var second_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer second_arena.deinit();
    var second_frontend = Frontend.Frontend.init(second_arena.allocator());
    const second = try Ir.writeText(second_arena.allocator(), (try second_frontend.compile(source)).ir);
    try std.testing.expectEqualStrings(first, second);
    try std.testing.expect(std.mem.indexOf(u8, first, "collection.load") != null);
}

test "compose indexed iteration through a public module function" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Indexed.sx",
        .data =
        \\public func weighted(values:int[]) int {
        \\    var total = 0
        \\    for index, item in values.indexed() { total += index * item }
        \\    return total
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Indexed\nfunc main() { print(Indexed.weighted([3, 4, 5])) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const result = try Interpreter.runCapture(allocator, (try compiler.compile(input)).ir);
    try std.testing.expectEqualStrings("14\n", result.stdout);
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
