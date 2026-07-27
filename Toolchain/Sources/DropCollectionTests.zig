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

test "collection insertion extraction replacement and clear preserve exact drops" {
    const output = try run(
        \\struct File { let id:int; drop { print("drop ", self.id) } }
        \\func main() {
        \\    var files:File[] = []
        \\    let first = File(id:1)
        \\    files.append(move first)
        \\    files.prepend(File(id:2))
        \\    let removed = files.take_first()
        \\    let previous = files.replace(0, File(id:3))
        \\    print("held")
        \\    var cleared:File[] = [File(id:4), File(id:5)]
        \\    cleared.clear()
        \\    print("cleared")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(
        "held\ndrop 5\ndrop 4\ncleared\ndrop 1\ndrop 2\ndrop 3\n",
        output,
    );
}

test "collection loops copy drop elements and write mutable copies back" {
    const output = try run(
        \\struct File { var id:int; drop { print("drop ", self.id) } }
        \\func inspect(file:@File) { print("see ", file.id) }
        \\func main() {
        \\    var files:File[] = [File(id:1), File(id:2)]
        \\    for file in files { inspect(file) }
        \\    for let file in files { print("let ", file.id) }
        \\    for var file in files { file.id += 10 }
        \\    print(files[0].id, " ", files[1].id)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(
        "see 1\ndrop 1\nsee 2\ndrop 2\nlet 1\ndrop 1\nlet 2\ndrop 2\ndrop 1\ndrop 11\ndrop 2\ndrop 12\n11 12\ndrop 12\ndrop 11\n",
        output,
    );
}

test "indexed reads fixed replacement and sequence append preserve exact drops" {
    const output = try run(
        \\struct File { let id:int; drop { print("drop ", self.id) } }
        \\func inspect(file:@File) { print("see ", file.id) }
        \\func main() {
        \\    var fixed:File[2] = [File(id:1), File(id:2)]
        \\    inspect(fixed[0])
        \\    let old = fixed.replace(0, File(id:3))
        \\    var left:File[] = [File(id:4)]
        \\    let right:File[] = [File(id:5), File(id:6)]
        \\    left.append(move right)
        \\    print("done")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(
        "see 1\ndone\ndrop 6\ndrop 5\ndrop 4\ndrop 1\ndrop 2\ndrop 3\n",
        output,
    );
}

test "collection indexing slicing appending and whole storage copy drop values" {
    const output = try run(
        \\struct File { let id:int; drop { print("drop ", self.id) } }
        \\func main() {
        \\    let file = File(id:1)
        \\    var values:File[] = []
        \\    values.append(file)
        \\    let indexed = values[0]
        \\    let slice = values[0:1]
        \\    let copied = values
        \\    var left:File[] = []
        \\    let right:File[] = [File(id:2)]
        \\    left.append(right)
        \\    print(indexed.id, " ", copied[0].id, " ", left[0].id)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings(
        "1 1 2\ndrop 2\ndrop 2\ndrop 1\ndrop 1\ndrop 1\ndrop 1\ndrop 1\n",
        output,
    );
}

test "whole drop collections transfer explicitly through calls and returns" {
    const output = try run(
        \\struct File { let id:int; drop { print(self.id) } }
        \\func forward(files:File[]) File[] { return move files }
        \\func main() {
        \\    let source:File[] = [File(id:1), File(id:2)]
        \\    let destination = forward(move source)
        \\    print("moved")
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("moved\n2\n1\n", output);
}
