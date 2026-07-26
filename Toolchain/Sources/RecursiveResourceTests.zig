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

test "drop recursively visits container then fields optionals and enum payloads in reverse order" {
    const output = try run(
        \\struct Leaf { let id:int; drop { print("leaf ", self.id) } }
        \\struct Pair {
        \\    let first:Leaf
        \\    let second:Leaf
        \\    drop { print("pair") }
        \\}
        \\enum Choice { empty; filled(Leaf, Leaf) }
        \\func main() {
        \\    let pair = Pair(first:Leaf(id:1), second:Leaf(id:2))
        \\    let optional:Leaf? = Leaf(id:3)
        \\    let choice = Choice.filled(Leaf(id:4), Leaf(id:5))
        \\    print("alive")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(
        "alive\nleaf 5\nleaf 4\nleaf 3\npair\nleaf 2\nleaf 1\n",
        output,
    );
}

test "ordinary block return break continue and try exits clean completed owners" {
    const output = try run(
        \\struct Leaf { let id:int; drop { print("drop ", self.id) } }
        \\func early() { let value = Leaf(id:1); return }
        \\func propagate() Result<int,str> {
        \\    let value = Leaf(id:2)
        \\    let number = try Result<int,str>.failure("bad")
        \\    return Result<int,str>.success(number)
        \\}
        \\func main() {
        \\    if true { let branch = Leaf(id:3); print("branch") }
        \\    while true { let stopped = Leaf(id:4); break }
        \\    var count = 0
        \\    while count < 1 { let skipped = Leaf(id:5); count += 1; continue }
        \\    early()
        \\    match propagate() { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(
        "branch\ndrop 3\ndrop 4\ndrop 5\ndrop 1\ndrop 2\nbad\n",
        output,
    );
}

test "fixed arrays and lists destroy noncopyable elements from last to first" {
    const output = try run(
        \\struct Leaf { let id:int; drop { print(self.id) } }
        \\func main() {
        \\    let fixed:Leaf[2] = [Leaf(id:1), Leaf(id:2)]
        \\    let values:Leaf[] = [Leaf(id:3), Leaf(id:4), Leaf(id:5)]
        \\    print("done")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("done\n5\n4\n3\n2\n1\n", output);
}

test "discarded owner temporaries are destroyed immediately" {
    const output = try run(
        \\struct Leaf { drop { print("drop") } }
        \\func make() Leaf { return Leaf() }
        \\func main() { make(); print("after") }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("drop\nafter\n", output);
}

test "noncopyability propagates through structures optionals and enums" {
    const cases = [_][]const u8{
        "struct Leaf { drop {} } struct Box { let leaf:Leaf } func main() { let first = Box(leaf:Leaf()); let second = first }",
        "struct Leaf { drop {} } func main() { let first:Leaf? = Leaf(); let second = first }",
        "struct Leaf { drop {} } enum Box { value(Leaf) } func main() { let first = Box.value(Leaf()); let second = first }",
        "struct Leaf { drop {} } func main() { let first:Leaf[1] = [Leaf()]; let second = first }",
        "struct Leaf { drop {} } func main() { let first:Leaf[] = [Leaf()]; let second = first }",
    };
    for (cases) |source| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var frontend = Frontend.Frontend.init(arena.allocator());
        try std.testing.expectError(error.InvalidSource, frontend.compile(source));
        try std.testing.expect(std.mem.containsAtLeast(u8, frontend.diagnostic.?.message, 1, "requires 'move'"));
    }
}
