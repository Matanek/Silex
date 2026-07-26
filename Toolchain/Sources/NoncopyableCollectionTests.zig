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

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "collection insertion extraction replacement and clear transfer unique elements" {
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

test "collection loops inspect and mutate noncopyable elements without copying" {
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
        "see 1\nsee 2\nlet 1\nlet 2\n11 12\ndrop 12\ndrop 11\n",
        output,
    );
}

test "indexed read references fixed replacement and sequence append preserve one owner" {
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

test "noncopyable collection operations reject implicit copies" {
    const prefix = "struct File { drop {} } ";
    try expectCompileError(
        prefix ++ "func main() { var files:File[] = []; let file = File(); files.append(file) }",
        "named noncopyable value requires 'move' when appending it to a collection",
    );
    try expectCompileError(
        prefix ++ "func main() { let file = File(); let files:File[] = [file] }",
        "named noncopyable value requires 'move' when storing it in a collection",
    );
    try expectCompileError(
        prefix ++ "func main() { let files:File[] = [File()]; let file = files[0] }",
        "indexed access cannot copy a noncopyable element; use '@T' inspection or an extracting collection operation",
    );
    try expectCompileError(
        prefix ++ "func main() { let files:File[] = [File()]; let part = files[0:1] }",
        "a copied slice cannot contain noncopyable elements; use a borrowed view",
    );
    try expectCompileError(
        prefix ++ "func main() { let files:File[] = [File()]; let copy = files }",
        "named noncopyable value requires 'move' when storing it",
    );
    try expectCompileError(
        prefix ++ "func main() { var left:File[] = []; let right:File[] = [File()]; left.append(right) }",
        "named noncopyable value requires 'move' when appending its elements to another collection",
    );
}

test "whole noncopyable collections transfer through calls and returns" {
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
