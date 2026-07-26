const std = @import("std");
const Project = @import("Project.zig");

test "compose principal secondary qualified and aliased public structures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Geometry");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Geometry.Vec2
        \\use Geometry.Shapes as Shapes
        \\use Geometry.Shapes.Point as P
        \\func pass(value:Vec2) Vec2 { return Vec2.identity(value) }
        \\func main() {
        \\    let vector:Vec2 = Vec2(22, 2)
        \\    let passed = pass(vector)
        \\    let point:Shapes.Point = Shapes.Point(x:13, y:5)
        \\    let alias:P = P(x:3, y:2)
        \\    print(passed.sum() + point.x + alias.x + alias.y)
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry/Vec2.sx",
        .data =
        \\public struct Vec2 {
        \\    public let x:int
        \\    let y:int
        \\    init(x:int, y:int) { self.x = x; self.y = y }
        \\    func sum() int { return self.x + self.y }
        \\}
        \\public func identity(value:Vec2) Vec2 { return value }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry/Shapes.sx",
        .data = "public struct Point { var x:int; var y:int }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    var found_vec2 = false;
    var found_point = false;
    for (compilation.ir.structures) |structure| {
        found_vec2 = found_vec2 or std.mem.eql(u8, structure.name, "Geometry.Vec2");
        found_point = found_point or std.mem.eql(u8, structure.name, "Geometry.Shapes.Point");
    }
    try std.testing.expect(found_vec2 and found_point);
    var found_interface = false;
    for (compilation.interfaces) |interface| {
        for (interface.structures) |structure| {
            if (std.mem.eql(u8, structure.id.module, "Geometry.Vec2")) {
                found_interface = true;
                try std.testing.expectEqualStrings("Vec2", structure.id.name);
                try std.testing.expectEqual(@as(usize, 1), structure.constructors.len);
                try std.testing.expectEqual(@as(usize, 1), structure.methods.len);
            }
        }
    }
    try std.testing.expect(found_interface);
}

test "reject private structure access and public signature leaks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Secret.sx",
        .data = "struct Secret { var value:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Secret\nfunc main() { let value = Secret(value:1) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("structure 'Secret' is private outside its module", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "struct Hidden { var value:int } public func reveal() Hidden { return Hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() {}",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("public function 'reveal' exposes private structure 'Hidden'", compiler.diagnostic.?.message);
}

test "reject colliding canonical structure identities" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Geometry");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Geometry as G\nuse Geometry.Vec2 as V\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry.sx",
        .data = "public struct Vec2 { var x:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Geometry/Vec2.sx",
        .data = "public struct Vec2 { var x:int; var y:int }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("structure identity 'Geometry.Vec2' is already provided", compiler.diagnostic.?.message);
}

test "compose a public structure from a direct local package dependency" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Vectors/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Vectors\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Vectors/Package.json",
        .data = "{\"name\":\"Vectors\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Vectors/Module/Vec2.sx",
        .data =
        \\public struct Vec2 { var x:int; var y:int }
        \\public func sum(value:Vec2) int { return value.x + value.y }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Vectors.Vec2\nfunc main() { print(Vec2.sum(Vec2(x:20, y:22))) }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    try std.testing.expect(compilation.interfaces[1].structures[0].id.owner.eql(.{ .package = "Vectors" }));
}
