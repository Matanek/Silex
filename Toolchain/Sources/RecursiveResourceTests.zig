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

test "fixed arrays and lists destroy elements from last to first" {
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

test "discarded drop temporaries are destroyed immediately" {
    const output = try run(
        \\struct Leaf { drop { print("drop") } }
        \\func make() Leaf { return Leaf() }
        \\func main() { make(); print("after") }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("drop\nafter\n", output);
}

test "drop values copy through structures optionals enums and collections" {
    const output = try run(
        \\struct Leaf { let id:int; drop { print(self.id) } }
        \\struct Box { let leaf:Leaf }
        \\enum Choice { value(Leaf) }
        \\func main() {
        \\    let leaf = Leaf(id:1)
        \\    let box1 = Box(leaf:leaf)
        \\    let box2 = box1
        \\    let optional1:Leaf? = leaf
        \\    let optional2 = optional1
        \\    let choice1 = Choice.value(leaf)
        \\    let choice2 = choice1
        \\    let fixed1:Leaf[1] = [Leaf(id:8)]
        \\    let fixed2 = fixed1
        \\    let list1:Leaf[] = [Leaf(id:9)]
        \\    let list2 = list1
        \\    print("alive")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(
        "alive\n9\n9\n8\n8\n1\n1\n1\n1\n1\n1\n1\n",
        output,
    );
}
