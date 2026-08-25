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

test "shared and mutable views preserve bounds and alias array storage" {
    const output = try run(
        \\func main() {
        \\    var values:int[5] = [0, 1, 2, 3, 4]
        \\    if true {
        \\        let middle = @values[1:4]
        \\        print(middle.count(), " ", middle.is_empty(), " ", middle[0], middle[-1])
        \\    }
        \\    if true {
        \\        var editable = &values[1:4]
        \\        editable[0] = 8
        \\        editable[-1] = 9
        \\        editable.swap(0, -1)
        \\    }
        \\    print(values[0], values[1], values[2], values[3], values[4])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("3 false 13\n09284\n", output);
}

test "views normalize bounds once and support subviews and iteration" {
    const output = try run(
        \\func start() int { print("start"); return -4 }
        \\func end() int { print("end"); return 99 }
        \\func main() {
        \\    var values = [10, 20, 30, 40, 50]
        \\    if true {
        \\        let view = @values[start():end()]
        \\        let sub = @view[1:3]
        \\        for value in sub { print(value) }
        \\    }
        \\    if true {
        \\        var mutable = &values[1:4]
        \\        var nested = &mutable[1:2]
        \\        for var value in nested { value += 7 }
        \\    }
        \\    print(values[2])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("start\nend\n30\n40\n37\n", output);
}

test "view parameters and provenance-qualified returns preserve the root" {
    const output = try run(
        \\func inspect(values:@int[..]) int { return values[0] + values[-1] }
        \\func edit(values:&int[..]) { values[0] += 10 }
        \\func identity(values:@int[..]) @values:int[..] { return values }
        \\func identity_mut(values:&int[..]) &values:int[..] { return values }
        \\func tail(values:@int[..]) @values:int[..] { return @values[1:values.count()] }
        \\func tail_mut(values:&int[..]) &values:int[..] { return &values[1:values.count()] }
        \\func main() {
        \\    var values = [1, 2, 3, 4]
        \\    print(inspect(@values[1:4]))
        \\    edit(&values[1:3])
        \\    print(identity(@values[0:4])[0])
        \\    if true {
        \\        var all = identity_mut(&values[0:4])
        \\        all[0] = 7
        \\    }
        \\    if true {
        \\        let shared = tail(@values[0:4])
        \\        print(shared[0], shared[-1])
        \\    }
        \\    if true {
        \\        var mutable = tail_mut(&values[0:4])
        \\        mutable[1] = 30
        \\    }
        \\    print(values[1], values[2])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("6\n1\n124\n1230\n", output);
}

test "views inspect drop elements and iteration copies them" {
    const output = try run(
        \\struct File { let id:int; drop { print("drop ", self.id) } }
        \\func inspect(file:@File) { print("see ", file.id) }
        \\func main() {
        \\    var files:File[] = [File(id:1), File(id:2)]
        \\    if true {
        \\        let view = @files[0:2]
        \\        inspect(view[0])
        \\        for file in view { inspect(file) }
        \\    }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("see 1\nsee 1\ndrop 1\nsee 2\ndrop 2\ndrop 2\ndrop 1\n", output);
}

test "mutable views replace drop elements" {
    const output = try run(
        \\struct File { let id:int; drop { print("drop ", self.id) } }
        \\func main() {
        \\    var files:File[] = [File(id:1)]
        \\    if true {
        \\        var view = &files[0:1]
        \\        view[0] = File(id:2)
        \\        print(view[0].id)
        \\    }
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("drop 1\n2\ndrop 2\n", output);
}

test "views enforce lexical conflicts and unavailable operations" {
    try expectCompileError(
        "func main() { var values = [1, 2]; let view = @values[0:2]; values[0] = 3 }",
        "cannot mutate or move 'values' while alias 'view' is alive",
    );
    try expectCompileError(
        "func main() { var values = [1, 2]; var view = &values[0:2]; print(values[0]) }",
        "cannot read 'values' while mutable alias 'view' is alive",
    );
    try expectCompileError(
        "func main() { var values = [1, 2]; let view = @values[0:2]; let moved = move values }",
        "cannot mutate or move 'values' while alias 'view' is alive",
    );
    try expectCompileError(
        "func main() { var values = [1, 2]; let view = @values[0:2]; values.append(3) }",
        "cannot mutate or move 'values' while alias 'view' is alive",
    );
    try expectCompileError(
        "func main() { var values = [1, 2]; var view = &values[0:2]; view.append(3) }",
        "views only support in-place 'swap'; resizing, extraction, replacement, and global reordering are unavailable",
    );
    try expectCompileError(
        "func main() { let values = [1, 2]; var view = &values[0:2] }",
        "a mutable view requires a var collection root",
    );
    try expectCompileError(
        "func main() { var values = [1, 2]; let view = @values[0:2]; view[0] = 3 }",
        "cannot assign to immutable variable 'view'",
    );
    try expectCompileError(
        "func main() { var values = [1, 2]; var view = &values[0:2]; view = &values[0:1] }",
        "a view binding cannot be replaced as a whole",
    );
    try expectCompileError(
        "func main(values:int[..]) {}",
        "a view parameter must use '@T[..]' or '&T[..]'",
    );
    try expectCompileError(
        "func invalid(values:@int[..]) int[..] { return values }",
        "a view return must use '@T[..]' or '&T[..]' and name compatible provenance",
    );
    try expectCompileError(
        "struct Invalid { let values:int[..] } func main() {}",
        "a borrowed view cannot be stored in a structure field",
    );
    try expectCompileError(
        "enum Invalid { value(int[..]) } func main() {}",
        "a borrowed view cannot be stored in an enum payload",
    );
    try expectCompileError(
        "func main() { let values:int[..]? = null }",
        "a borrowed view cannot be stored inside another local type",
    );
}

test "mutable views publish class field mutations to their own fields" {
    const output = try run(
        \\class Buffers {
        \\    var first:int[]
        \\    var second:int[]
        \\    init() {
        \\        self.first = [1, 2]
        \\        self.second = [3, 4]
        \\    }
        \\}
        \\func update(first:&int[..], second:&int[..]) {
        \\    first[0] = 10
        \\    second[1] = 40
        \\}
        \\func main() {
        \\    var buffers = Buffers()
        \\    update(
        \\        &buffers.first[0:buffers.first.count()],
        \\        &buffers.second[0:buffers.second.count()]
        \\    )
        \\    print(buffers.first[0])
        \\    print(buffers.first[1])
        \\    print(buffers.second[0])
        \\    print(buffers.second[1])
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("10\n2\n3\n40\n", output);
}
