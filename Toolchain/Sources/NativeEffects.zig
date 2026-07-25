const std = @import("std");
const builtin = @import("builtin");

const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Lower = @import("Arm64/Lower.zig");
const MachO = @import("MacOS/MachO.zig");
const Project = @import("Project.zig");

fn compileAndRun(allocator: std.mem.Allocator, source: []const u8) !std.process.RunResult {
    var frontend = Frontend.Frontend.init(allocator);
    var compilation = try frontend.compile(source);
    compilation.ir.files = &.{"Main.sx"};
    const machine = try Lower.lower(allocator, compilation.ir);
    return runMachine(allocator, machine);
}

fn runMachine(allocator: std.mem.Allocator, machine: @import("Arm64/Machine.zig").Program) !std.process.RunResult {
    const bytes = try MachO.emit(allocator, machine);

    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const executable = try std.fs.path.join(allocator, &.{ base, "effects-app" });
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, executable, .{
        .permissions = .executable_file,
    });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, bytes);
    try file.setPermissions(std.testing.io, .executable_file);
    return std.process.run(allocator, std.testing.io, .{ .argv = &.{executable} });
}

fn exitCode(result: std.process.RunResult) u8 {
    return switch (result.term) {
        .exited => |code| code,
        else => 255,
    };
}

test "native effects match the reference output" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func square(value:int) int { return value * value }
        \\func identity(value:str) str { return value }
        \\func main() {
        \\    print("Silex 🔥")
        \\    print(identity("A\0B"))
        \\    print("")
        \\    print(square(5))
        \\    print(-42)
        \\    print(-9223372036854775808)
        \\    print(9223372036854775807)
        \\    print(true)
        \\    print(false)
        \\    print(1 + 2 * 3 < 8 == true)
        \\    print(4 <= 4)
        \\    print(8 > 9)
        \\    print(8 >= 8)
        \\    print(1 != 2)
        \\    print(false == false)
        \\    assert(true, "must pass")
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native assert and panic preserve diagnostics and exit status" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const assertion =
        \\func main() {
        \\    print("before")
        \\    assert(false, "planned failure")
        \\    print("after")
        \\}
    ;
    const failed = try compileAndRun(allocator, assertion);
    try std.testing.expectEqual(@as(u8, 1), exitCode(failed));
    try std.testing.expectEqualStrings("before\n", failed.stdout);
    try std.testing.expectEqualStrings(
        "Main.sx:3:5: runtime error: assertion failed: planned failure\n",
        failed.stderr,
    );

    const panicked = try compileAndRun(allocator,
        \\func message() str { return "literal panic" }
        \\func value() int { panic(message()) }
        \\func main() { value() }
    );
    try std.testing.expectEqual(@as(u8, 1), exitCode(panicked));
    try std.testing.expectEqualStrings("", panicked.stdout);
    try std.testing.expectEqualStrings(
        "Main.sx:2:20: runtime error: literal panic\n",
        panicked.stderr,
    );
}

test "package effects keep their real source path in both execution paths" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Fault/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Fault.Failure
        \\func main() {
        \\    print("before package")
        \\    Failure.fail()
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Fault/Package.json",
        .data = "{\"name\":\"Fault\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Fault/Module/Failure.sx",
        .data = "public func fail() { panic(\"package failure\") }",
    });

    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const native = try runMachine(allocator, try Lower.lower(allocator, compilation.ir));

    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
    try std.testing.expect(std.mem.indexOf(u8, native.stderr, "Fault/Module/Failure.sx:1:22") != null);
}
