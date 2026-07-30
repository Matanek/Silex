const std = @import("std");
const builtin = @import("builtin");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Lower = @import("Arm64/Lower.zig");
const Runner = @import("Arm64/Runner.zig");
const Parser = @import("Parser.zig").Parser;
const Project = @import("Project.zig");

test "parse method and field cascade operations before terminal access" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\struct Point {
        \\    var x:int
        \\    func shift(value:int) { self.x += value }
        \\    func value() int { return self.x }
        \\}
        \\func main() { let value = Point(x:0)..x = 10..shift(2).value() }
    );
    const program = try parser.parse();
    const terminal = program.functions[0].statements[0].variable_declaration.initializer.?.value.call;
    try std.testing.expectEqualStrings("value", terminal.name);
    const cascade = terminal.receiver.?.value.cascade;
    try std.testing.expectEqual(@as(usize, 2), cascade.operations.len);
    try std.testing.expect(cascade.operations[0] == .field_assignment);
    try std.testing.expect(cascade.operations[1] == .method_call);
}

test "execute cascades through one receiver and ignore intermediate results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Point {
        \\    var x:int
        \\    var y:int
        \\    func shift(amount:int) int { self.x += amount; self.y += amount; return 999 }
        \\    func total() int { return self.x + self.y }
        \\}
        \\func make(calls:&int) Point { calls++; return Point(x:0, y:0) }
        \\func main() {
        \\    var calls = 0
        \\    let total = make(calls)
        \\        ..x = 2
        \\        ..shift(3)
        \\        ..y = 9
        \\        ..shift(0)
        \\        .total()
        \\    var values:int[] = []
        \\        ..append(1)
        \\        ..append(2)
        \\        ..reverse()
        \\    print(calls, " ", total, " ", values[0], values[1], " ", values..append(3).count())
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("1 14 21 3\n", result.stdout);
}

test "infer and accept explicit generic method arguments in a cascade" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\protocol Plugin {}
        \\struct FooPlugin:Plugin {}
        \\class Application {
        \\    public func install<T:Plugin>(plugin:T) {}
        \\    public func run() int { return 42 }
        \\}
        \\func main() {
        \\    print(Application()
        \\        ..install(FooPlugin())
        \\        ..install<FooPlugin>(FooPlugin())
        \\        .run())
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "keep a temporary class cascade alive through its terminal call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Application {
        \\    public func install() Application { return self }
        \\    public func run() { print("run") }
        \\    drop { print("drop") }
        \\}
        \\func main() { Application()..install()..install().run() }
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("run\ndrop\n", result.stdout);
}

test "reject cascade mutation through an immutable receiver" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        "struct Point { var x:int } func main() { let point = Point(x:0); let changed = point..x = 1 }",
    ));
    try std.testing.expectEqualStrings("cannot assign to immutable variable 'point'", frontend.diagnostic.?.message);
}

test "native ARM64 executes a temporary cascade like the interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Point {
        \\    var x:int
        \\    var y:int
        \\    func shift(value:int) { self.x += value; self.y += value }
        \\    func total() int { return self.x + self.y }
        \\}
        \\func answer() int { return Point(x:1, y:2)..y = 10..shift(3).total() }
        \\func main() {}
    );
    var answer: ?usize = null;
    for (compilation.ir.functions, 0..) |function, index| if (std.mem.eql(u8, function.name, "answer")) {
        answer = index;
        break;
    };
    const function = answer orelse return error.TestUnexpectedResult;
    const reference = try Interpreter.invoke(allocator, compilation.ir, function, &.{});
    const machine = try Lower.lower(allocator, compilation.ir);
    const native = try Runner.invoke(allocator, machine, function, &.{});
    try std.testing.expectEqual(Interpreter.Value{ .integer = 17 }, reference);
    try std.testing.expectEqual(@as(i64, 17), native.value);
}

test "compose a cascade whose receiver is a qualified package type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Bootstrap.sx",
        .data =
        \\public struct Application {
        \\    var running:bool = false
        \\    public func run() { self.running = true }
        \\    public func is_running() bool { return self.running }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use GFX.Bootstrap
        \\func main() {
        \\    var app = Bootstrap.Application()
        \\        ..run()
        \\    print(app.is_running())
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("true\n", result.stdout);
}
