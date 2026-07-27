const std = @import("std");
const builtin = @import("builtin");
const macho = std.macho;

const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Lower = @import("Arm64/Lower.zig");
const Machine = @import("Arm64/Machine.zig");
const MachO = @import("MacOS/MachO.zig");
const Project = @import("Project.zig");
const Runner = @import("Arm64/Runner.zig");

test "emit and execute a composed local-package Mach-O" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math/Module");
    try temporary.dir.createDirPath(std.testing.io, "Math/Platform/macos-arm64/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func calculate() int { return Operations.add(20, 22) }
        \\func main() { calculate() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Package.json",
        .data = "{\"name\":\"Math\",\"version\":\"1.4.1\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Platform/macos-arm64/Module/Operations.sx",
        .data = "public func add(left:int, right:int) int { return left + right }",
    });

    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Main.sx" });
    const output = try std.fs.path.join(allocator, &.{ base, "composed-app" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const calculate = findFunction(compilation.ir, "Main.calculate") orelse return error.TestUnexpectedResult;

    const interpreted = try Interpreter.invoke(allocator, compilation.ir, calculate, &.{});
    try std.testing.expectEqual(@as(i64, 42), interpreted.integer);

    const machine = try Lower.lower(allocator, compilation.ir);
    const native = try Runner.invoke(allocator, machine, calculate, &.{});
    try std.testing.expectEqual(Machine.Status.success, native.status);
    try std.testing.expectEqual(@as(i64, 42), native.value);

    const bytes = try MachO.emit(allocator, machine);
    try std.testing.expectEqual(
        @as(u32, macho.MH_MAGIC_64),
        std.mem.readInt(u32, bytes[0..4], .little),
    );
    try std.testing.expectEqual(
        @as(u32, @bitCast(macho.CPU_TYPE_ARM64)),
        std.mem.readInt(u32, bytes[4..8], .little),
    );
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, output, .{
        .permissions = .executable_file,
    });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, bytes);
    try file.setPermissions(std.testing.io, .executable_file);

    var child = try std.process.spawn(std.testing.io, .{
        .argv = &.{output},
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .inherit,
    });
    defer child.kill(std.testing.io);
    const termination = try child.wait(std.testing.io);
    try std.testing.expectEqual(@as(u8, 0), switch (termination) {
        .exited => |code| code,
        else => 255,
    });
}

test "compose a module facade with its child namespace" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "STD/Module/Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"STD\":\"=0.1.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"0.1.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use STD.Math
        \\func calculate() int {
        \\    let point = Math.Point.seed()
        \\    return Math.answer() + point.x + point.y + Math.Vec3()
        \\}
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math.sx",
        .data =
        \\public func answer() int { return 1 }
        \\public func Vec3() int { return 0 }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math/Point.sx",
        .data =
        \\public struct Point { var x:int; var y:int }
        \\extend Point { static func seed() Point { return Point(x:20, y:21) } }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Module/Math/Vec3.sx",
        .data = "public struct Vec3 { var value:int }",
    });

    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const calculate = findFunction(compilation.ir, "Main.calculate") orelse return error.TestUnexpectedResult;

    const interpreted = try Interpreter.invoke(allocator, compilation.ir, calculate, &.{});
    try std.testing.expectEqual(@as(i64, 42), interpreted.integer);

    const machine = try Lower.lower(allocator, compilation.ir);
    const native = try Runner.invoke(allocator, machine, calculate, &.{});
    try std.testing.expectEqual(Machine.Status.success, native.status);
    try std.testing.expectEqual(@as(i64, 42), native.value);
}

fn findFunction(program: Ir.Program, name: []const u8) ?Ir.FunctionId {
    for (program.functions, 0..) |function, id| {
        if (std.mem.eql(u8, function.name, name)) return id;
    }
    return null;
}
