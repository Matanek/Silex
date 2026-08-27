const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Project = @import("Project.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "reflect values through category-specific metadata" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\enum Easing { constant; linear; custom(float) }
        \\struct Transform {
        \\    var x:float
        \\    let visible:bool
        \\    func translate(value:float) {}
        \\    func reset() {}
        \\}
        \\class Actor {
        \\    let label:str
        \\    private var hidden:int = 0
        \\    func act() {}
        \\    private func secret() {}
        \\}
        \\func callback(value:int) bool { return value > 0 }
        \\func main() {
        \\    var easing = Easing.constant
        \\    let first = reflect(easing)
        \\    print(first.type)
        \\    print(first.name)
        \\    for variant in first.variants { print(variant) }
        \\    easing = Easing.linear
        \\    print(reflect(easing).name)
        \\    let transform = Transform(x:1.0, visible:true)
        \\    let structure = reflect(transform)
        \\    print(structure.type)
        \\    print(reflect(Transform(x:2.0, visible:false).visible).name)
        \\    print(reflect(Transform(x:2.0, visible:false).visible).type)
        \\    for field in structure.fields { print(field) }
        \\    for method in structure.methods { print(method) }
        \\    var actor = Actor(label:"hero")
        \\    let class_info = reflect(actor)
        \\    for field in class_info.fields { print(field) }
        \\    for method in class_info.methods { print(method) }
        \\    let function = reflect(callback)
        \\    print(function.type)
        \\    print(function.name)
        \\    for parameter in function.parameters { print(parameter) }
        \\    print(function.return_type)
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        \\Easing
        \\Easing.constant
        \\constant
        \\linear
        \\custom
        \\Easing.linear
        \\Transform
        \\Transform.visible
        \\bool
        \\x
        \\visible
        \\translate
        \\reset
        \\label
        \\act
        \\func(int)bool
        \\callback
        \\int
        \\bool
        \\
    , result.stdout);
}

test "reflect public values through a package alias without changing their canonical identity" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Library/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"Library\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Package.json",
        .data = "{\"name\":\"Library\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Animation.sx",
        .data =
        \\public enum Easing { constant; linear }
        \\public struct Point {
        \\    let x:int
        \\    package let cached:int = 0
        \\    func translated() {}
        \\    package func prepare() {}
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Library.Animation as Motion
        \\enum LocalState { ready }
        \\func main() {
        \\    print(reflect(LocalState.ready).name)
        \\    let easing = reflect(Motion.Easing.constant)
        \\    print(easing.type)
        \\    print(easing.name)
        \\    let point = reflect(Motion.Point(x:1))
        \\    for field in point.fields { print(field) }
        \\    for method in point.methods { print(method) }
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(
        \\LocalState.ready
        \\Library.Animation.Easing
        \\Library.Animation.Easing.constant
        \\x
        \\translated
        \\
    , result.stdout);
}

test "diagnose invalid reflect calls and reserve its name" {
    try expectCompileError("func main() { reflect() }", "reflect expects exactly one value");
    try expectCompileError("func main() { reflect(1, 2) }", "reflect expects exactly one value");
    try expectCompileError(
        "func reflect(value:int) int { return value } func main() {}",
        "'reflect' is a reserved intrinsic function name",
    );
    try expectCompileError(
        "func main() { let reflect = 1 }",
        "'reflect' is a reserved intrinsic function name",
    );
    try expectCompileError(
        "func main() { print(reflect(1 + 2).name) }",
        "type '(type:str)' has no member named 'name'",
    );
}
