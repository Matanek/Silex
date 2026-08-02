const std = @import("std");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Project = @import("Project.zig");

test "compose a package diamond once into deterministic portable IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "A/Module");
    try temporary.dir.createDirPath(std.testing.io, "B/Module");
    try temporary.dir.createDirPath(std.testing.io, "Common/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"A\":\"=1.0.0\",\"B\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use A.Api
        \\use B.Api as BApi
        \\func calculate() int { return Api.value() + BApi.value() }
        \\func main() { calculate() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Package.json",
        .data = "{\"name\":\"A\",\"version\":\"1.0.0\",\"dependencies\":{\"Common\":\"^1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Module/Api.sx",
        .data = "use Common.Shared\npublic func value() int { return Shared.first() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Package.json",
        .data = "{\"name\":\"B\",\"version\":\"1.0.0\",\"dependencies\":{\"Common\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Module/Api.sx",
        .data = "use Common.Shared\npublic func value() int { return Shared.second() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Common/Package.json",
        .data = "{\"name\":\"Common\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Common/Module/Shared.sx",
        .data =
        \\public func first() int { return 20 }
        \\public func second() int { return 22 }
        ,
    });

    const input = try inputPath(allocator, &temporary.sub_path);
    var first_compiler = Project.Compiler.init(allocator, std.testing.io);
    const first = try first_compiler.compile(input);
    const value = try Interpreter.invoke(allocator, first.ir, functionId(first.ir, "Main.calculate").?, &.{});
    try std.testing.expectEqual(@as(i64, 42), value.integer);
    try std.testing.expectEqual(@as(usize, 1), countFunctions(first.ir, "Common.Shared.first"));
    try std.testing.expectEqual(@as(usize, 1), countFunctions(first.ir, "Common.Shared.second"));
    try std.testing.expect(functionId(first.ir, "A.Api.value") != functionId(first.ir, "B.Api.value"));

    var second_compiler = Project.Compiler.init(allocator, std.testing.io);
    const second = try second_compiler.compile(input);
    const first_text = try Ir.writeText(allocator, first.ir);
    const second_text = try Ir.writeText(allocator, second.ir);
    try std.testing.expectEqualStrings(first_text, second_text);
}

test "reject an incompatible package call before producing IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func main() { Operations.add(20, true) }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.4.1\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Operations.sx",
        .data = "public func add(left:int, right:int) int { return left + right }",
    });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(try inputPath(allocator, &temporary.sub_path)));
    try std.testing.expectEqualStrings(
        "argument 2 of 'Math.Operations.add' expects 'int', found 'bool'",
        compiler.diagnostic.?.message,
    );
}

test "compile a named package entry with sibling dependencies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Application/Module");
    try temporary.dir.createDirPath(std.testing.io, "Math/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Package.json",
        .data = "{\"name\":\"Application\",\"version\":\"0.1.0\",\"dependencies\":{\"Math\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Module/Main.sx",
        .data = "use Math.Value\nfunc answer() int { return Value.get() }\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Value.sx",
        .data = "public func get() int { return 42 }",
    });

    const input = try std.fs.path.join(allocator, &.{
        ".zig-cache", "tmp", &temporary.sub_path, "Application", "Module", "Main.sx",
    });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try Interpreter.invoke(
        allocator,
        compilation.ir,
        functionId(compilation.ir, "Application.Main.answer").?,
        &.{},
    );
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
}

test "load qualified package modules without use through principal module files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math/Module/Geometry");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"Math\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\func calculate() int {
        \\    let vector = Math.Vec2(20, 22)
        \\    let mode = Math.Mode.ready
        \\    if mode == Math.Mode.ready {
        \\        return vector.x + vector.y + Math.Geometry.bump() + Math.answer() + 1
        \\    }
        \\    return 0
        \\}
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/@module.sx",
        .data = "public use Math.Values.answer",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Values.sx",
        .data = "public func answer() int { return 100 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Geometry/@Module.sx",
        .data = "public func bump() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Vec2.sx",
        .data = "public struct Vec2 { let x:int; let y:int; public init(x:int, y:int) { self.x = x; self.y = y } }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Module/Mode.sx",
        .data = "public enum Mode { ready }",
    });

    const input = try inputPath(allocator, &temporary.sub_path);
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const value = try Interpreter.invoke(allocator, compilation.ir, functionId(compilation.ir, "Main.calculate").?, &.{});
    try std.testing.expectEqual(@as(i64, 144), value.integer);
    try std.testing.expect(compiler.index.find("Math") != null);
    try std.testing.expect(compiler.index.find("Math.Geometry") != null);
}

fn inputPath(allocator: std.mem.Allocator, sub_path: []const u8) ![]const u8 {
    return std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", sub_path, "Main.sx" });
}

fn functionId(program: Ir.Program, name: []const u8) ?Ir.FunctionId {
    for (program.functions, 0..) |function, index| {
        if (std.mem.eql(u8, function.name, name)) return index;
    }
    return null;
}

fn countFunctions(program: Ir.Program, name: []const u8) usize {
    var count: usize = 0;
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, name)) count += 1;
    }
    return count;
}
