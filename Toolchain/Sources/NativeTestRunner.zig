const std = @import("std");
const Boundary = @import("Boundary.zig");
const Arm64Object = @import("Arm64/Object.zig");
const CompilationCache = @import("CompilationCache.zig");
const Ir = @import("Ir.zig");
const Lower = @import("Arm64/Lower.zig");
const Machine = @import("Arm64/Machine.zig");
const MachOObject = @import("MacOS/Object.zig");
const MachOX64Object = @import("MacOS/X64Object.zig");
const MacOSLink = @import("MacOS/Link.zig");
const NativeLink = @import("NativeLink.zig");
const Packages = @import("Packages.zig");
const Project = @import("Project.zig");
const TargetModule = @import("Target.zig");
const X64Encoder = @import("X64/Encoder.zig");
const X64Object = @import("X64/Object.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Execution = struct {
    result: std.process.RunResult,
    executable: []const u8,
};

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
    target: TargetModule.Target,
    linker_path: []const u8,
    program: Machine.Program,
    function: Machine.FunctionId,
    source_path: []const u8,
    files: []const []const u8,
    providers: []const Packages.BoundaryProvider,
    cache: bool,
) !Execution {
    const function_text = try std.fmt.allocPrint(allocator, "{d}", .{function});
    const reusable = cache and providers.len == 0 and !MacOSLink.requiresSystemLink(program.external_functions);
    const digest = if (reusable)
        try CompilationCache.key(
            allocator,
            io,
            files,
            try std.fmt.allocPrint(allocator, "native-test-{s}", .{target.name()}),
            function_text,
        )
    else
        CompilationCache.artifactKey("native-test", &.{ source_path, function_text });
    const executable = try artifactPath(allocator, source_path, digest, target);
    if (reusable and exists(io, executable)) return .{
        .result = try run(allocator, io, executable),
        .executable = executable,
    };
    const result = try executeAt(allocator, io, target, linker_path, program, function, executable, providers);
    if (!reusable and !retainArtifact(result.term)) Io.Dir.cwd().deleteFile(io, executable) catch {};
    return .{ .result = result, .executable = executable };
}

fn executeAt(
    allocator: Allocator,
    io: Io,
    target: TargetModule.Target,
    linker_path: []const u8,
    program: Machine.Program,
    function: Machine.FunctionId,
    executable: []const u8,
    providers: []const Packages.BoundaryProvider,
) !std.process.RunResult {
    try Io.Dir.cwd().createDirPath(io, std.fs.path.dirname(executable).?);
    if (target.eql(.macos_arm64)) {
        const object = try MachOObject.emitFunction(allocator, program, function);
        const object_path = try std.fmt.allocPrint(allocator, "{s}.o", .{executable});
        defer Io.Dir.cwd().deleteFile(io, object_path) catch {};
        {
            const file = try Io.Dir.cwd().createFile(io, object_path, .{});
            defer file.close(io);
            try file.writeStreamingAll(io, object);
        }
        try MacOSLink.executable(allocator, io, linker_path, target, object_path, executable, providers, program.external_functions);
        return run(allocator, io, executable);
    }
    if (target.eql(.macos_x64)) {
        var image = try X64Encoder.encodeDarwinFunctionObject(allocator, program, function);
        defer image.deinit(allocator);
        const object = try MachOX64Object.emit(allocator, program, &image);
        const object_path = try std.fmt.allocPrint(allocator, "{s}.o", .{executable});
        defer Io.Dir.cwd().deleteFile(io, object_path) catch {};
        {
            const file = try Io.Dir.cwd().createFile(io, object_path, .{});
            defer file.close(io);
            try file.writeStreamingAll(io, object);
        }
        try MacOSLink.executable(allocator, io, linker_path, target, object_path, executable, providers, program.external_functions);
        return run(allocator, io, executable);
    }
    if (target.eql(.linux_x64) or target.eql(.windows_x64)) {
        var image = if (target.eql(.linux_x64))
            try X64Encoder.encodeLinuxFunctionObject(allocator, program, function)
        else
            try X64Encoder.encodeWindowsFunctionObject(allocator, program, function);
        defer image.deinit(allocator);
        const object = if (target.eql(.linux_x64))
            try X64Object.emitElf(allocator, program, image)
        else
            try X64Object.emitCoff(allocator, program, image);
        const object_path = try std.fmt.allocPrint(allocator, "{s}.o", .{executable});
        defer Io.Dir.cwd().deleteFile(io, object_path) catch {};
        {
            const file = try Io.Dir.cwd().createFile(io, object_path, .{});
            defer file.close(io);
            try file.writeStreamingAll(io, object);
        }
        try NativeLink.executable(allocator, io, linker_path, target, object_path, executable, providers);
        return run(allocator, io, executable);
    }
    if (target.eql(.windows_arm64)) {
        const object = try Arm64Object.emitWindowsFunction(allocator, program, function);
        const object_path = try std.fmt.allocPrint(allocator, "{s}.o", .{executable});
        defer Io.Dir.cwd().deleteFile(io, object_path) catch {};
        {
            const file = try Io.Dir.cwd().createFile(io, object_path, .{});
            defer file.close(io);
            try file.writeStreamingAll(io, object);
        }
        try NativeLink.executable(allocator, io, linker_path, target, object_path, executable, providers);
        return run(allocator, io, executable);
    }
    if (target.eql(.linux_arm64)) {
        const object = try Arm64Object.emitLinuxFunction(allocator, program, function);
        const object_path = try std.fmt.allocPrint(allocator, "{s}.o", .{executable});
        defer Io.Dir.cwd().deleteFile(io, object_path) catch {};
        {
            const file = try Io.Dir.cwd().createFile(io, object_path, .{});
            defer file.close(io);
            try file.writeStreamingAll(io, object);
        }
        try NativeLink.executable(allocator, io, linker_path, target, object_path, executable, providers);
        return run(allocator, io, executable);
    }
    return error.UnsupportedTarget;
}

fn retainArtifact(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code != 0,
        else => true,
    };
}

fn run(allocator: Allocator, io: Io, executable: []const u8) !std.process.RunResult {
    return std.process.run(allocator, io, .{ .argv = &.{executable} });
}

fn exists(io: Io, path: []const u8) bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

test "retain every abnormal native test artifact" {
    try std.testing.expect(!retainArtifact(.{ .exited = 0 }));
    try std.testing.expect(retainArtifact(.{ .exited = 1 }));
    try std.testing.expect(retainArtifact(.{ .signal = @enumFromInt(11) }));
}

fn artifactPath(
    allocator: Allocator,
    source_path: []const u8,
    digest: [32]u8,
    target: TargetModule.Target,
) ![]const u8 {
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(
        allocator,
        ".silex/test/{s}-{s}{s}",
        .{ std.fs.path.stem(source_path), hex[0..], target.executableExtension() },
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
    const failed = try executeAt(allocator, std.testing.io, .macos_arm64, "zig", machine, entries.items[0], failed_executable, &.{});
    try std.testing.expectEqual(@as(u8, 1), exitCode(failed.term));
    try std.testing.expect(std.mem.indexOf(u8, failed.stderr, "assertion failed: planned") != null);
    const continued = try executeAt(allocator, std.testing.io, .macos_arm64, "zig", machine, entries.items[1], continued_executable, &.{});
    try std.testing.expectEqual(@as(u8, 0), exitCode(continued.term));
    try std.testing.expectEqualStrings("continued\n", continued.stdout);
}

test "retain a signaled native test executable for source debugging" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Crash.sx",
        .data = "use Interop.C\ntest \"crash\" { C.call<func() void>(0 as uint) }",
    });
    const source_path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Crash.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compileTests(source_path);
    const machine = try lower(allocator, std.testing.io, compilation.ir, &.{}, false);
    const execution = try execute(
        allocator,
        std.testing.io,
        .macos_arm64,
        "zig",
        machine,
        compilation.tests[0].function,
        source_path,
        compilation.files,
        &.{},
        false,
    );
    defer Io.Dir.cwd().deleteFile(std.testing.io, execution.executable) catch {};
    switch (execution.result.term) {
        .signal => |signal| try std.testing.expectEqual(@as(u32, 11), @intFromEnum(signal)),
        else => return error.TestUnexpectedResult,
    }
    try std.testing.expect(exists(std.testing.io, execution.executable));
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
    const result = try executeAt(allocator, std.testing.io, .macos_arm64, "zig", machine, compilation.tests[0].function, executable, &.{});
    try std.testing.expectEqual(@as(u8, 0), exitCode(result.term));
    try std.testing.expectEqualStrings("native boundary\n", result.stdout);
}

test "link a package boundary provider into a native test" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Tests");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/provider.c",
        .data = "#include <stdint.h>\n" ++
            "int boundary_answer(void) { return 42; }\n" ++
            "int boundary_add(int left, int right) { return left + right; }\n" ++
            "uintptr_t boundary_add_address(void) { return (uintptr_t)&boundary_add; }\n",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"macos-arm64":{"providers":{"Native":{"archive":"libProvider.a"}}}}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Module/Api.sx", .data =
        \\use Interop.C
        \\use Interop.Boundary
        \\let native_answer = C.function<func() int32>(library:Boundary.Native, name:"boundary_answer")
        \\let native_add_address = C.function<func() uint>(library:Boundary.Native, name:"boundary_add_address")
        \\public func answer() int32 { return native_answer() }
        \\public func add(left:int32, right:int32) int32 {
        \\    return C.call<func(int32, int32) int32>(native_add_address(), left, right)
        \\}
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Tests/Boundary.sx", .data =
        \\use Bridge.Api
        \\test "provider" {
        \\    assert(Api.answer() == 42)
        \\    assert(Api.add(19, 23) == 42)
        \\}
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Bridge" });
    const input = try std.fs.path.join(allocator, &.{ base, "Tests/Boundary.sx" });
    const provider_source = try std.fs.path.join(allocator, &.{ base, "provider.c" });
    const provider_object = try std.fs.path.join(allocator, &.{ base, "provider.o" });
    const archive = try std.fs.path.join(allocator, &.{ base, "libProvider.a" });
    const executable = try std.fs.path.join(allocator, &.{ base, "provider-test" });
    for ([_][]const []const u8{
        &.{ "zig", "cc", "-target", "aarch64-macos", "-c", provider_source, "-o", provider_object },
        &.{ "zig", "ar", "rcs", archive, provider_object },
    }) |arguments| {
        const result = try std.process.run(allocator, std.testing.io, .{ .argv = arguments });
        try std.testing.expectEqual(@as(u8, 0), exitCode(result.term));
    }

    var compiler = @import("Project.zig").Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compileTests(input);
    const machine = try lower(allocator, std.testing.io, compilation.ir, compilation.boundaries, false);
    const providers = [_]Packages.BoundaryProvider{.{
        .name = "Provider",
        .archive = archive,
        .frameworks = &.{},
        .libraries = &.{},
    }};
    const result = try executeAt(
        allocator,
        std.testing.io,
        .macos_arm64,
        "zig",
        machine,
        compilation.tests[0].function,
        executable,
        &providers,
    );
    try std.testing.expectEqual(@as(u8, 0), exitCode(result.term));
}

test "link an unlisted system symbol from a package manifest without an archive" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Module");
    try temporary.dir.createDirPath(std.testing.io, "Bridge/Tests");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Bridge/Package.json",
        .data =
        \\{"name":"Bridge","version":"1.0.0","boundary":{"macos-arm64":{"providers":{"System":{"libraries":["System"]}}}}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Bridge/Tests/System.sx", .data =
        \\use Interop.C
        \\use Interop.Boundary
        \\let get_user_id = C.function<func() uint32>(library:Boundary.System, name:"getuid")
        \\test "system provider" { assert(get_user_id() == get_user_id()) }
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Bridge" });
    const input = try std.fs.path.join(allocator, &.{ base, "Tests/System.sx" });
    const executable = try std.fs.path.join(allocator, &.{ base, "system-test" });
    var compiler = @import("Project.zig").Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compileTests(input);
    const machine = try lower(allocator, std.testing.io, compilation.ir, compilation.boundaries, false);
    const providers = [_]Packages.BoundaryProvider{.{
        .name = "System",
        .libraries = &.{"System"},
        .frameworks = &.{},
    }};
    const result = try executeAt(
        allocator,
        std.testing.io,
        .macos_arm64,
        "zig",
        machine,
        compilation.tests[0].function,
        executable,
        &providers,
    );
    try std.testing.expectEqual(@as(u8, 0), exitCode(result.term));
}

fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .exited => |code| code,
        else => 255,
    };
}
