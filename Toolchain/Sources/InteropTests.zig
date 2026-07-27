const std = @import("std");
const builtin = @import("builtin");

const Ir = @import("Ir.zig");
const Lower = @import("Arm64/Lower.zig");
const MachO = @import("MacOS/MachO.zig");
const Project = @import("Project.zig");

const source =
    \\use Interop.C
    \\use Interop.MacOS
    \\
    \\let write = C.function<
    \\    func(int32, C.Pointer<uint8>, C.Size) C.SignedSize
    \\>(
    \\    library:MacOS.lib_system,
    \\    name:"write"
    \\)
    \\
    \\func main() {
    \\    let text = "Silex écrit par interop.\n"
    \\    let written = write(1, C.pointer(text), C.byte_count(text))
    \\    assert(written == C.byte_count(text) as C.SignedSize, "unexpected write count")
    \\}
;

test "compose a C.function declaration into a deterministic boundary call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.boundaries.len);
    try std.testing.expectEqualStrings("Main.write", compilation.boundaries[0].name);
    try std.testing.expectEqualStrings("MacOS.lib_system", compilation.boundaries[0].provider);
    try std.testing.expectEqualStrings("write", compilation.boundaries[0].source_name);

    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.call #0") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.address") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "str.byte_count") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "_write") == null);
}

test "emit and execute C.function write from Silex source" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = source });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Main.sx" });
    const output = try std.fs.path.join(allocator, &.{ base, "interop-write" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const machine = try Lower.lowerBoundaries(allocator, compilation.ir, compilation.boundaries);
    const bytes = try MachO.emit(allocator, machine);
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, output, .{ .permissions = .executable_file });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, bytes);
    try file.setPermissions(std.testing.io, .executable_file);

    const result = try std.process.run(allocator, std.testing.io, .{ .argv = &.{output} });
    try std.testing.expectEqual(@as(u8, 0), switch (result.term) {
        .exited => |code| code,
        else => 255,
    });
    try std.testing.expectEqualStrings("Silex écrit par interop.\n", result.stdout);
    try std.testing.expectEqual(@as(usize, 0), result.stderr.len);
}

test "reject incomplete and invalid C.function declarations" {
    try expectError(
        \\use Interop.C
        \\let write = C.function<func(int32, C.Pointer<uint8>, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() {}
        ,
        "MacOS library requires 'use Interop.MacOS'",
    );
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let write = C.function<func(int32, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() {}
        ,
        "write expects func(int32, C.Pointer<uint8>, C.Size) C.SignedSize",
    );
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let write = C.function<func(int32, C.Pointer<uint8>, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() { write(1, C.pointer(42), 1 as C.Size) }
        ,
        "C.pointer expects a string",
    );
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let write = C.function<func(int32, C.Pointer<uint8>, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() { let text = "x"; let pointer = C.pointer(text); write(1, pointer, 1 as C.Size) }
        ,
        "a C pointer can only be passed directly to a foreign function",
    );
}

fn expectError(input_source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = input_source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(message, compiler.diagnostic.?.message);
}
