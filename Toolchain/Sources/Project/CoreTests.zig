const std = @import("std");
const Compiler = @import("../Project.zig").Compiler;

test "compile only the explicit local module closure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func answer() int { return Operations.add(20, 22) }
        \\func main() { answer() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data = "func add(left:int, right:int) int { return left + right }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Unused.sx",
        .data = "this source is deliberately invalid",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const Interpreter = @import("../Interpreter.zig");
    const answer = try Interpreter.invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqualStrings("Main.answer", compilation.ir.functions[0].name);
    try std.testing.expectEqualStrings("Math.Operations.add", compilation.ir.functions[2].name);
}

test "report missing modules and duplicate aliases" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Missing
        \\func main() {}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown module or declaration 'Missing'", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "One.sx",
        .data = "func value() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Two.sx",
        .data = "func value() int { return 2 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use One as Same\nuse Two as Same\nfunc main() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("use alias 'Same' is already declared", compiler.diagnostic.?.message);
}

test "resolve explicit module aliases direct declarations and grouping namespaces" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations as Ops
        \\use Math.Operations.add as plus
        \\use Math as Group
        \\func byModule() int { return Ops.add(20, 22) }
        \\func byDeclaration() int { return plus(21, 21) }
        \\func byNamespace() int { return Group.Operations.add(40, 2) }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data = "func add(left:int, right:int) int { return left + right }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const Interpreter = @import("../Interpreter.zig");
    for (0..3) |function| {
        const answer = try Interpreter.invoke(allocator, compilation.ir, function, &.{});
        try std.testing.expectEqual(@as(i64, 42), answer.integer);
    }
}

test "reject alias collisions and dependency cycles across logical parents" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.createDirPath(std.testing.io, "Other");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Group.A\nfunc main() { A.run() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/A.sx",
        .data = "use Other.B\nfunc run() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Other/B.sx",
        .data = "use Group.A\nfunc run() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "module dependency cycle crosses logical parents",
        compiler.diagnostic.?.message,
    );
}

test "allow dependency cycles under one logical parent" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Group.A\nfunc main() { A.run() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/A.sx",
        .data = "use Group.B\nfunc run() { B.touch() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/B.sx",
        .data = "use Group.A\nfunc touch() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    _ = try @import("../Interpreter.zig").run(allocator, compilation.ir);
}

test "collect public overloads before analyzing calls across files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func answer() int { return Operations.value(20) + Operations.value(true) }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data =
        \\public func value(input:int) int { return input }
        \\public func value(input:bool) int { return 22 }
        \\func hidden() int { return 0 }
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 2), compilation.interfaces.len);
    try std.testing.expectEqual(@as(usize, 2), compilation.interfaces[1].functions.len);
    try std.testing.expect(compilation.interfaces[1].functions[0].id.eql(.{
        .owner = .project,
        .module = "Math.Operations",
        .name = "value",
        .parameter_types = &.{.int},
    }));
}

test "compose public parameter defaults in their declaring module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func answer() int { return Operations.value() + Operations.Box().plus() }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data =
        \\func seed() int { return 20 }
        \\public func value(input:int = seed()) int { return input }
        \\public struct Box {
        \\    var value:int
        \\    init(value:int = seed()) { self.value = value }
        \\    func plus(amount:int = 2) int { return self.value + amount }
        \\}
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 0), compilation.interfaces[1].functions[0].required_parameters);
    try std.testing.expectEqual(@as(usize, 0), compilation.interfaces[1].structures[0].constructors[0].required_parameters);
    try std.testing.expectEqual(@as(usize, 0), compilation.interfaces[1].structures[0].methods[0].required_parameters);
}

test "do not propagate private module access through a dependency" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Layer");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Layer.A\nfunc main() { B.hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Layer/A.sx",
        .data = "use Layer.B\nfunc touch() { B.hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Layer/B.sx",
        .data = "func hidden() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown function 'B.hidden'", compiler.diagnostic.?.message);
}

test "compose simple modules with an adjacent local package" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Foo");
    try temporary.dir.createDirPath(std.testing.io, "MonPackage/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Foo.Bar
        \\use MonPackage.Class1
        \\func answer() int { return Bar.value() + Class1.value() }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Foo/Bar.sx",
        .data = "func value() int { return 20 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "MonPackage/Package.json",
        .data = "{\"name\":\"MonPackage\",\"version\":\"1.4.1\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "MonPackage/Module/Class1.sx",
        .data = "public func value() int { return 22 }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 1, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 2), compilation.packages.packages.len);
    try std.testing.expectEqualStrings("MonPackage.Class1", compilation.interfaces[2].name);
}

test "qualified packages share namespaces without sharing ownership" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    const package_names = [_][]const u8{ "Silex", "Silex.Audio", "Silex.Bootstrap", "Silex.Rendering" };
    for (package_names) |name| {
        const module_path = try std.fs.path.join(allocator, &.{ name, "Module" });
        try temporary.dir.createDirPath(std.testing.io, module_path);
        const manifest_path = try std.fs.path.join(allocator, &.{ name, "Package.json" });
        const manifest = try std.fmt.allocPrint(
            allocator,
            "{{\"name\":\"{s}\",\"version\":\"1.0.0\"}}",
            .{name},
        );
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = manifest_path, .data = manifest });
    }
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Silex.Core
        \\use Silex.Audio.Mixer
        \\use Silex.Bootstrap.Start
        \\use Silex.Rendering.Texture
        \\func answer() int { return Core.value() + Mixer.value() + Start.value() + Texture.value() }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex/Module/Core.sx", .data = "public func value() int { return 9 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Audio/Module/Mixer.sx", .data = "public func value() int { return 10 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Bootstrap/Module/Start.sx", .data = "public func value() int { return 11 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Rendering/Module/Texture.sx", .data = "public func value() int { return 12 }" });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("../Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 5), compilation.packages.packages.len);

    try temporary.dir.createDirPath(std.testing.io, "Silex/Module/Rendering");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Silex/Module/Rendering/Texture.sx",
        .data = "public func duplicate() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("multiple source files provide the same module", compiler.diagnostic.?.message);
}

test "enforce public package interfaces and direct dependency visibility" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "A/Module");
    try temporary.dir.createDirPath(std.testing.io, "B/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"A\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Package.json",
        .data = "{\"name\":\"A\",\"version\":\"1.0.0\",\"dependencies\":{\"B\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Module/Api.sx",
        .data = "func hidden() {}\npublic func exposed() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Package.json",
        .data = "{\"name\":\"B\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Module/Private.sx",
        .data = "public func value() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use A.Api\nfunc main() { Api.hidden() }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'A.Api.hidden' is private outside its package",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use B.Private\nfunc main() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown module or declaration 'B.Private'", compiler.diagnostic.?.message);
}

test "compose and execute structures inside their declaring module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\struct Point { var x:int; var y:int = 2 }
        \\func main() { let point = Point(x:40); print(point.x + point.y) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}
