const std = @import("std");
const Project = @import("Project.zig");

test "resolve canonical package and module anchored paths once across a namespace collision" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Application/Sources/Demo");
    try temporary.dir.createDirPath(std.testing.io, "DependencySources/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Package.json",
        .data = "{\"dependencies\":{\"Sources\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "DependencySources/Package.json",
        .data = "{\"name\":\"Sources\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "DependencySources/Module/UUID.sx",
        .data = "public func number() int { return 12 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "DependencySources/Module/Consumer.sx",
        .data =
        \\use Sources.UUID.number as canonical_number
        \\use Package.UUID.number as package_number
        \\use Module.UUID.number as module_number
        \\public func total() int { return canonical_number() + package_number() + module_number() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Sources/Demo/Helper.sx",
        .data =
        \\public struct Value { public let number:int }
        \\public func answer() int { return 10 }
        \\public func value() Value { return Value(number:10) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Sources/Demo/Main.sx",
        .data =
        \\use Module.Helper.answer as local_answer
        \\use Package.Sources.Demo.Helper.answer as package_answer
        \\use Sources.Consumer.total
        \\func main() {
        \\    let module_value:Module.Helper.Value = Module.Helper.value()
        \\    let package_value:Package.Sources.Demo.Helper.Value = Package.Sources.Demo.Helper.value()
        \\    print(local_answer() + package_answer() + total() + module_value.number + package_value.number)
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{
        ".zig-cache",
        "tmp",
        &temporary.sub_path,
        "Application",
        "Sources",
        "Demo",
        "Main.sx",
    });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("76\n", result.stdout);
    try std.testing.expect(compilation.packages.explicit);

    var helper_count: usize = 0;
    for (compilation.ir.functions) |function| {
        if (std.mem.eql(u8, function.name, "Sources.Demo.Helper.answer")) helper_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), helper_count);

    var uuid_count: usize = 0;
    for (compilation.ir.functions) |function| {
        if (std.mem.eql(u8, function.name, "Sources.UUID.number")) uuid_count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), uuid_count);
}

test "require an explicit Module anchor for source relative imports" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Application/Sources/Demo");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Package.json",
        .data = "{}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Sources/Demo/Helper.sx",
        .data = "public func answer() int { return 42 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Sources/Demo/Main.sx",
        .data = "use Helper.answer\nfunc main() { print(answer()) }",
    });

    const input = try std.fs.path.join(allocator, &.{
        ".zig-cache",
        "tmp",
        &temporary.sub_path,
        "Application",
        "Sources",
        "Demo",
        "Main.sx",
    });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "unknown module or declaration 'Helper.answer'",
        compiler.diagnostic.?.message,
    );
}

test "anchor Package at the loose project root for a principal entry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Sandbox/Test/Feature");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Test/@Module.sx",
        .data = "use Package.Test.Feature.Worker.run\nfunc main() { print(run()) }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Test/Shared.sx",
        .data = "public func answer() int { return 40 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Test/Feature/Helper.sx",
        .data = "public func extra() int { return 2 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Test/Feature/Worker.sx",
        .data =
        \\use Package.Test.Shared.answer
        \\use Module.Helper.extra
        \\public func run() int { return answer() + extra() }
        ,
    });

    const input = try std.fs.path.join(allocator, &.{
        ".zig-cache",
        "tmp",
        &temporary.sub_path,
        "Sandbox",
        "Test",
        "@Module.sx",
    });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
    try std.testing.expect(!compilation.packages.explicit);
}

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
        \\    let x:int
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

test "resolve a principal structure through its parent namespace" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math
        \\func main() {
        \\    var value:Math.Vec3 = Math.Vec3(x:40, y:2)
        \\    var state:Math.State = Math.State(1)
        \\    print(value.x + value.y + state.value)
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Vec3.sx",
        .data = "public struct Vec3 { var x:int; var y:int }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/State.sx",
        .data =
        \\public class State {
        \\    var value:int
        \\    init(value:int) { self.value = value }
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("43\n", result.stdout);
    var found_vec3 = false;
    var found_state = false;
    for (compilation.ir.structures) |structure| {
        found_vec3 = found_vec3 or std.mem.eql(u8, structure.name, "Math.Vec3");
        found_state = found_state or std.mem.eql(u8, structure.name, "Math.State");
    }
    try std.testing.expect(found_vec3 and found_state);
}

test "public constructor remains available when a class owns a drop" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Resource.sx",
        .data =
        \\public class Resource {
        \\    private let handle:int
        \\    init(handle:int) { self.handle = handle }
        \\    func value() int { return self.handle }
        \\    drop {}
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Resource\nfunc main() { var resource = Resource(42); print(resource.value()) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
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
    try std.testing.expectEqualStrings("structure 'Secret' is module-visible and unavailable outside its module", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "struct Hidden { var value:int } public func reveal(value:Hidden) {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() {}",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("public function 'reveal' exposes module structure 'Hidden'", compiler.diagnostic.?.message);
}

test "compare package and module signature exposure scopes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "local struct FileOnly {} func leak(value:FileOnly) {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() {}",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'leak' with module visibility exposes local type 'FileOnly'",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.createDirPath(std.testing.io, "Library/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Library\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Package.json",
        .data = "{\"name\":\"Library\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Api.sx",
        .data = "struct ModuleOnly {} package func share(value:ModuleOnly) {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Library.Api\nfunc main() {}",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'share' with package visibility exposes module type 'ModuleOnly'",
        compiler.diagnostic.?.message,
    );
}

test "validate signatures against an explicit member scope instead of its public container" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\struct Hidden {}
        \\public class Service {
        \\    module init(value:Hidden) {}
        \\    module func echo(value:Hidden) Hidden { return value }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    _ = try compiler.compile(input);
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

test "compose public named tuple signatures across modules" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data = "public struct State { let modal:bool } public func state() State { return State(modal:true) } public func size() (width:int, height:int) { return (width:1280, height:720) }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api\nfunc main() { let value = Api.size(); if Api.state().modal { print(value.width + value.height + 1) } }",
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("2001\n", result.stdout);
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

test "use a package child namespace without a principal module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/Geometry");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/@Module.sx",
        .data = "public func version() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Geometry/Cube.sx",
        .data = "public struct Cube { static func corners() int { return 8 } }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use GFX.Geometry\nfunc main() { print(Geometry.Cube.corners()) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("8\n", result.stdout);
}

test "implicit module visibility spans files owned by a principal module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Library/Module/Feature");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Library\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Package.json",
        .data = "{\"name\":\"Library\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Feature/@Module.sx",
        .data =
        \\public use Library.Feature.Engine.Service
        \\public struct Feature { module static func value() int { return 42 } }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Feature/Engine.sx",
        .data =
        \\struct Raw { let value:int }
        \\public struct Service { module static func answer() int { return 42 } }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Library/Module/Feature/Api.sx",
        .data =
        \\use Library.Feature.Engine.Raw
        \\use Library.Feature.Service
        \\use Library.Feature
        \\public func answer() int { return Raw(value:Service.answer() + Feature.value() - 42).value }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Library.Feature.Api.answer\nfunc main() { print(answer()) }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Library.Feature.Engine.Raw\nfunc main() { let raw = Raw(value:42) }",
    });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("structure 'Raw' is module-visible and unavailable outside its module", compiler.diagnostic.?.message);
}

test "enforce representative GFX package and module member boundaries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GFX/Module/Canvas");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"GFX\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Canvas/@Module.sx",
        .data =
        \\public class Font {
        \\    init() {}
        \\    package func cached_face_count() int { return 1 }
        \\    module func cached_face() int { return 2 }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Canvas/Rasterizer.sx",
        .data =
        \\use GFX.Canvas.Font
        \\func rasterize(font:Font) int { return font.cached_face() }
        \\func main() { print(rasterize(Font())) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Module/Probe.sx",
        .data =
        \\use GFX.Canvas.Font
        \\func main() { print(Font().cached_face()) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use GFX.Canvas.Font
        \\func main() { print(Font().cached_face_count()) }
        ,
    });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const rasterizer = try std.fs.path.join(allocator, &.{ root, "GFX", "Module", "Canvas", "Rasterizer.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(rasterizer);
    const result = try @import("Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("2\n", result.stdout);

    const probe = try std.fs.path.join(allocator, &.{ root, "GFX", "Module", "Probe.sx" });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(probe));
    try std.testing.expectEqualStrings(
        "method 'cached_face' is module-visible and unavailable outside its module",
        compiler.diagnostic.?.message,
    );

    const consumer = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(consumer));
    try std.testing.expectEqualStrings(
        "method 'cached_face_count' is package-visible and unavailable outside its package",
        compiler.diagnostic.?.message,
    );
}
