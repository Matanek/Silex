const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Parser = @import("Parser.zig").Parser;
const Project = @import("Project.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "parse generic function declarations and explicit calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func identity<T>(value:T) T { return value }
        \\func main() { identity<int>(42) }
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 1), program.functions[0].type_parameters.len);
    try std.testing.expectEqual(@as(usize, 1), program.functions[1].statements[0].expression_statement.value.call.type_arguments.len);
}

test "specialize inferred and explicit generic functions once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func identity<T>(value:T) T { return value }
        \\func choose<Key, Value>(key:Key, value:Value) Value { return value }
        \\func main() {
        \\    print(identity(42))
        \\    print(identity<int>(7))
        \\    print(identity("Silex"))
        \\    print(choose(1, "ready"))
        \\}
    );
    try std.testing.expectEqual(@as(usize, 4), compilation.ir.functions.len);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n7\nSilex\nready\n", result.stdout);
}

test "prefer concrete overloads and specialize defaults and stable recursion" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func select(value:int) int { return 100 }
        \\func select<T>(value:T) T { return value }
        \\func with_default<T>(value:T, amount:int = 2) T { return value }
        \\func descend<T>(value:T, count:int) T {
        \\    if count == 0 { return value }
        \\    return descend(value, count - 1)
        \\}
        \\func main() {
        \\    print(select(1))
        \\    print(select("generic"))
        \\    print(with_default(9))
        \\    print(descend(8, 2))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("100\ngeneric\n9\n8\n", result.stdout);
}

test "diagnose generic function arity inference conflicts and divergent recursion" {
    try expectCompileError(
        "func create<T>() T { panic(\"no value\") } func main() { create() }",
        "generic function 'create' cannot infer all type arguments; use explicit '<...>'",
    );
    try expectCompileError(
        "func same<T>(left:T, right:T) T { return left } func main() { same(1, \"x\") }",
        "generic function 'same' cannot infer all type arguments; use explicit '<...>'",
    );
    try expectCompileError(
        "func choose<T, U>(value:T) T { return value } func main() { choose<int>(1) }",
        "generic function 'choose' has no overload accepting 1 type arguments",
    );
    try expectCompileError(
        "func plain(value:int) int { return value } func main() { plain<int>(1) }",
        "function 'plain' does not accept type arguments",
    );
    try expectCompileError(
        "func expand<T>(value:T) T { return expand<T?>(value) } func main() { expand(1) }",
        "generic function 'expand' recursively expands with different type arguments",
    );
}

test "reuse one generic function specialization through modules aliases and reexports" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Left
        \\use Right
        \\func main() { print(Left.answer()); print(Right.answer()) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public func identity<T>(value:T) T { return value }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.identity as keep",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Left.sx",
        .data = "use Facade.keep as local\npublic func answer() int { return local(20) }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Right.sx",
        .data = "use Api\npublic func answer() int { return Api.identity<int>(22) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 4), compilation.ir.functions.len);
    var found_reexport = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Facade")) continue;
        for (interface.functions) |function| if (std.mem.eql(u8, function.export_name, "keep")) {
            try std.testing.expectEqual(@as(usize, 1), function.type_parameters.len);
            try std.testing.expectEqualStrings("T", function.type_parameters[0]);
            found_reexport = true;
        };
    }
    try std.testing.expect(found_reexport);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("20\n22\n", result.stdout);
}

test "specialize generic structure fields initializers constructors and methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair<T> {
        \\    let first:T
        \\    let second:T
        \\}
        \\struct Box<T> {
        \\    var value:T
        \\    init(value:T) { self.value = value }
        \\    func replace(value:T) { self.value = value }
        \\}
        \\func main() {
        \\    let named = Pair<int>(first:1, second:2)
        \\    var built = Box<str>("left")
        \\    built.replace("right")
        \\    print(named.first + named.second)
        \\    print(built.value)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("3\nright\n", result.stdout);
}

test "keep nested generic structure identities distinct and reusable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box<T> { let value:T }
        \\func main() {
        \\    let first = Box<int>(value:1)
        \\    let same = Box<int>(value:1)
        \\    let text = Box<str>(value:"one")
        \\    let nested = Box<Box<int>>(value:first)
        \\    print(first == same)
        \\    print(text.value)
        \\    print(nested.value.value)
        \\}
    );
    try std.testing.expectEqual(@as(usize, 3), compilation.ir.structures.len);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\none\n1\n", result.stdout);
}

test "infer function type arguments through a generic structure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Box<T> { let value:T }
        \\func unbox<T>(box:Box<T>) T { return box.value }
        \\func main() {
        \\    print(unbox(Box<int>(value:42)))
        \\    print(unbox(Box<str>(value:"ready")))
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\nready\n", result.stdout);
}

test "compose generic structures through aliases and reexports" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Facade
        \\use Api.Pair as LocalPair
        \\use Api.Pair<int> as IntPair
        \\func main() {
        \\    let left:Facade.Pair<int> = Facade.Pair<int>(first:20, second:22)
        \\    let right:IntPair = LocalPair<int>(first:left.first, second:left.second)
        \\    print(right.first + right.second)
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public struct Pair<T> { public let first:T; public let second:T }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Api.Pair as Pair",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.ir.structures.len);
    var found_reexport = false;
    for (compilation.interfaces) |interface| {
        if (!std.mem.eql(u8, interface.name, "Facade")) continue;
        for (interface.structures) |structure| if (std.mem.eql(u8, structure.export_name, "Pair")) {
            try std.testing.expectEqual(@as(usize, 1), structure.type_parameters.len);
            found_reexport = true;
        };
    }
    try std.testing.expect(found_reexport);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "diagnose invalid generic structure uses and recursive expansion" {
    try expectCompileError(
        "struct Box<T> { let value:T } func main() { let value:Box }",
        "generic struct 'Box' requires 1 type argument",
    );
    try expectCompileError(
        "struct Pair<T, U> { let left:T; let right:U } func main() { Pair<int>(left:1, right:2) }",
        "generic struct 'Pair' expects 2 type arguments, found 1",
    );
    try expectCompileError(
        "struct Box { let value:int } func main() { Box<int>(value:1) }",
        "struct 'Box' does not accept type arguments",
    );
    try expectCompileError(
        "struct Box<T> { let value:T } func main() { Box(value:1) }",
        "generic struct 'Box' requires 1 type argument",
    );
    try expectCompileError(
        "struct Box<T> { let value:T } func main() { Box<void>() }",
        "'void' is not a generic type argument",
    );
    try expectCompileError(
        "struct Node<T> { let next:Node<T> } func main() { let value:Node<int> }",
        "structure 'Node<int>' has a recursive value representation",
    );
    try expectCompileError(
        "struct Expand<T> { let value:Expand<Expand<T>> } func main() { let value:Expand<int> }",
        "generic struct 'Expand' recursively expands with different type arguments",
    );
}
