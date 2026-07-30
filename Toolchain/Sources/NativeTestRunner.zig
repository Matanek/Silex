const std = @import("std");
const Boundary = @import("Boundary.zig");
const CompilationCache = @import("CompilationCache.zig");
const Ir = @import("Ir.zig");
const Lower = @import("Arm64/Lower.zig");
const Machine = @import("Arm64/Machine.zig");
const MachO = @import("MacOS/MachO.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub fn lower(
    allocator: Allocator,
    io: Io,
    program: Ir.Program,
    boundaries: []const Boundary.Function,
    cache: bool,
) !Machine.Program {
    return if (cache)
        Lower.lowerCachedWithBoundaries(allocator, io, program, boundaries, .debug)
    else
        Lower.lowerWithModeAndBoundaries(allocator, program, boundaries, .debug);
}

pub fn execute(
    allocator: Allocator,
    io: Io,
    program: Machine.Program,
    function: Machine.FunctionId,
    source_path: []const u8,
    files: []const []const u8,
    cache: bool,
) !std.process.RunResult {
    const function_text = try std.fmt.allocPrint(allocator, "{d}", .{function});
    const digest = if (cache)
        try CompilationCache.key(
            allocator,
            io,
            files,
            "native-test-macos-arm64",
            function_text,
        )
    else
        CompilationCache.artifactKey("native-test", &.{ source_path, function_text });
    const executable = try artifactPath(allocator, source_path, digest);
    if (cache and exists(io, executable)) return run(allocator, io, executable);
    return executeAt(allocator, io, program, function, executable);
}

fn executeAt(
    allocator: Allocator,
    io: Io,
    program: Machine.Program,
    function: Machine.FunctionId,
    executable: []const u8,
) !std.process.RunResult {
    const bytes = try MachO.emitFunction(allocator, program, function);
    try Io.Dir.cwd().createDirPath(io, std.fs.path.dirname(executable).?);
    {
        const file = try Io.Dir.cwd().createFile(io, executable, .{ .permissions = .executable_file });
        defer file.close(io);
        try file.writeStreamingAll(io, bytes);
        try file.setPermissions(io, .executable_file);
    }
    return run(allocator, io, executable);
}

fn run(allocator: Allocator, io: Io, executable: []const u8) !std.process.RunResult {
    return std.process.run(allocator, io, .{ .argv = &.{executable} });
}

fn exists(io: Io, path: []const u8) bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

fn artifactPath(allocator: Allocator, source_path: []const u8, digest: [32]u8) ![]const u8 {
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(
        allocator,
        ".silex/test/{s}-{s}",
        .{ std.fs.path.stem(source_path), hex[0..] },
    );
}

test "execute native test entries independently and preserve failures" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(allocator);
    const compilation = try frontend.compileTests(
        \\test "fails" { assert(false, "planned") }
        \\test "continues" { print("continued"); assert(true) }
    );
    const machine = try lower(allocator, std.testing.io, compilation.ir, &.{}, false);
    var entries: std.ArrayList(usize) = .empty;
    for (compilation.ast.functions, 0..) |function, function_id| {
        if (function.is_test_entry) try entries.append(allocator, function_id);
    }
    try std.testing.expectEqual(@as(usize, 2), entries.items.len);

    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const failed_executable = try std.fs.path.join(allocator, &.{ base, "native-test-fails" });
    const continued_executable = try std.fs.path.join(allocator, &.{ base, "native-test-continues" });
    const failed = try executeAt(allocator, std.testing.io, machine, entries.items[0], failed_executable);
    try std.testing.expectEqual(@as(u8, 1), exitCode(failed.term));
    try std.testing.expect(std.mem.indexOf(u8, failed.stderr, "assertion failed: planned") != null);
    const continued = try executeAt(allocator, std.testing.io, machine, entries.items[1], continued_executable);
    try std.testing.expectEqual(@as(u8, 0), exitCode(continued.term));
    try std.testing.expectEqualStrings("continued\n", continued.stdout);
}

test "execute a native test through a macOS system boundary" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Boundary.sx", .data =
        \\use Interop.C
        \\use Interop.MacOS
        \\let write = C.function<func(int32, C.Pointer<uint8>, C.Size) C.SignedSize>(
        \\    library:MacOS.lib_system,
        \\    name:"write"
        \\)
        \\test "write" {
        \\    let text = "native boundary\n"
        \\    assert(write(1, C.pointer(text), C.byte_count(text)) == C.byte_count(text) as C.SignedSize)
        \\}
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Boundary.sx" });
    const executable = try std.fs.path.join(allocator, &.{ base, "boundary-test" });
    var compiler = @import("Project.zig").Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compileTests(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.tests.len);
    const machine = try lower(allocator, std.testing.io, compilation.ir, compilation.boundaries, false);
    const result = try executeAt(allocator, std.testing.io, machine, compilation.tests[0].function, executable);
    try std.testing.expectEqual(@as(u8, 0), exitCode(result.term));
    try std.testing.expectEqualStrings("native boundary\n", result.stdout);
}

fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .exited => |code| code,
        else => 255,
    };
}
