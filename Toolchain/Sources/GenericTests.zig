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
