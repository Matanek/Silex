const std = @import("std");
const Frontend = @import("Frontend.zig").Frontend;
const Interpreter = @import("Interpreter.zig");
const Project = @import("Project.zig");

test "parse and execute named and anonymous test blocks independently" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func value() int { return 42 }
        \\test "mutually visible helpers" {
        \\    func first(input:int) bool { return second(input) }
        \\    func second(input:int) bool { return input == value() }
        \\    assert(first(42))
        \\    assert(value() == 42)
        \\}
        \\test {
        \\    print("before failure")
        \\    assert(false, "planned")
        \\    print("after failure")
        \\}
        \\test "continues after failure" {
        \\    assert(true)
        \\}
    ;

    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compileTests(source);
    var entries: std.ArrayList(usize) = .empty;
    for (compilation.ast.functions, 0..) |function, function_id| {
        if (function.is_test_entry) try entries.append(allocator, function_id);
    }
    try std.testing.expectEqual(@as(usize, 3), entries.items.len);
    try std.testing.expectEqualStrings("mutually visible helpers", compilation.ast.functions[entries.items[0]].test_name.?);
    try std.testing.expect(compilation.ast.functions[entries.items[1]].test_name == null);

    const first = try Interpreter.runFunctionCaptureWithBoundaries(allocator, null, compilation.ir, entries.items[0], &.{});
    try std.testing.expectEqual(@as(u8, 0), first.exit_code);
    const failed = try Interpreter.runFunctionCaptureWithBoundaries(allocator, null, compilation.ir, entries.items[1], &.{});
    try std.testing.expectEqual(@as(u8, 1), failed.exit_code);
    try std.testing.expectEqualStrings("before failure\n", failed.stdout);
    try std.testing.expect(std.mem.indexOf(u8, failed.stderr, "assertion failed: planned") != null);
    const last = try Interpreter.runFunctionCaptureWithBoundaries(allocator, null, compilation.ir, entries.items[2], &.{});
    try std.testing.expectEqual(@as(u8, 0), last.exit_code);
}

test "exclude test blocks from normal frontend compilation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.init(arena.allocator());
    const compilation = try frontend.compile(
        \\func main() {}
        \\test "not part of the program" {
        \\    let values = [1, 2]
        \\    let callback = func() { missing_function() }
        \\    missing_function()
        \\}
    );
    try std.testing.expectEqual(@as(usize, 1), compilation.ast.functions.len);
    try std.testing.expectEqual(@as(usize, 0), compilation.ast.structures.len);
    try std.testing.expectEqualStrings("main", compilation.ast.functions[0].name);
    try std.testing.expectEqual(@as(usize, 1), compilation.ir.functions.len);
}

test "activate tests only for the explicit project source" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Library
        \\func main() { print(Library.answer()) }
        \\test "entry test" {
        \\    func expected() int { return Library.answer() }
        \\    assert(expected() == 42)
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library.sx",
        .data =
        \\public func answer() int { return 42 }
        \\test "dependency test" {
        \\    var missing:MissingType
        \\    missing_function()
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    var normal = Project.Compiler.init(allocator, std.testing.io);
    const program = try normal.compile(input);
    try std.testing.expectEqual(@as(usize, 0), program.tests.len);
    for (program.ast.functions) |function| try std.testing.expect(!function.is_test);

    var testing = Project.Compiler.init(allocator, std.testing.io);
    const suite = try testing.compileTests(input);
    try std.testing.expectEqual(@as(usize, 1), suite.tests.len);
    try std.testing.expectEqualStrings("entry test", suite.tests[0].name.?);
    const result = try Interpreter.runFunctionCaptureWithBoundaries(
        allocator,
        null,
        suite.ir,
        suite.tests[0].function,
        suite.boundaries,
    );
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
