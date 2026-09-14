const std = @import("std");
const Boundary = @import("Boundary.zig");
const Cli = @import("Cli.zig");
const CompilationCache = @import("CompilationCache.zig");
const CompilationTrace = @import("CompilationTrace.zig");
const Emitter = @import("../Tools/LlvmEvaluation/Emitter.zig");
const Ir = @import("Ir.zig");
const MacOSLink = @import("MacOS/Link.zig");
const Packages = @import("Packages.zig");
const TargetModule = @import("Target.zig");
const format_runtime = @import("llvm_format_runtime_object");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const version = "21.1.8";

pub const Tools = struct {
    opt: []const u8,
    llc: []const u8,
    cpu: []const u8,
};

pub const BuildOptions = struct {
    tools: Tools,
    target: TargetModule.Target,
    linker_path: []const u8,
    program: Ir.Program,
    boundaries: []const Boundary.Function,
    providers: []const Packages.BoundaryProvider,
    mode: Cli.Mode,
    output_path: []const u8,
    entry_function: ?Ir.FunctionId = null,
    trace: ?*CompilationTrace.Reporter = null,
};

pub fn resolveTools(
    init: std.process.Init,
    allocator: Allocator,
) !?Tools {
    const root = init.environ_map.get("SILEX_LLVM_DIR") orelse {
        std.debug.print(
            "silex: LLVM backend {s} is not configured; set SILEX_LLVM_DIR to its installation directory\n",
            .{version},
        );
        return null;
    };
    const opt = try std.fs.path.join(allocator, &.{ root, "bin", "opt" });
    const llc = try std.fs.path.join(allocator, &.{ root, "bin", "llc" });
    for ([_]struct { name: []const u8, path: []const u8 }{
        .{ .name = "opt", .path = opt },
        .{ .name = "llc", .path = llc },
    }) |tool| {
        const status = Io.Dir.cwd().statFile(init.io, tool.path, .{}) catch {
            std.debug.print("silex: LLVM backend cannot locate {s} at '{s}'\n", .{ tool.name, tool.path });
            return null;
        };
        if (status.kind != .file) {
            std.debug.print("silex: LLVM backend expected a file at '{s}'\n", .{tool.path});
            return null;
        }
    }
    const reported = try versionReport(init, allocator, "opt", opt) orelse return null;
    _ = try versionReport(init, allocator, "llc", llc) orelse return null;
    const cpu_marker = "Host CPU:";
    const marker = std.mem.indexOf(u8, reported.stdout, cpu_marker) orelse {
        std.debug.print("silex: LLVM {s} did not report its host CPU\n", .{version});
        return null;
    };
    const remainder = reported.stdout[marker + cpu_marker.len ..];
    const end = std.mem.indexOfScalar(u8, remainder, '\n') orelse remainder.len;
    const cpu = std.mem.trim(u8, remainder[0..end], " \t\r");
    if (cpu.len == 0) {
        std.debug.print("silex: LLVM {s} reported an empty host CPU\n", .{version});
        return null;
    }
    return .{ .opt = opt, .llc = llc, .cpu = cpu };
}

fn versionReport(
    init: std.process.Init,
    allocator: Allocator,
    name: []const u8,
    path: []const u8,
) !?std.process.RunResult {
    const reported = std.process.run(allocator, init.io, .{ .argv = &.{ path, "--version" } }) catch |err| {
        std.debug.print("silex: unable to execute LLVM {s} at '{s}': {t}\n", .{ name, path, err });
        return null;
    };
    if (exitCode(reported.term) == 0 and
        std.mem.indexOf(u8, reported.stdout, "LLVM version " ++ version) != null)
    {
        return reported;
    }
    std.debug.print("silex: LLVM backend requires LLVM {s}; '{s}' reported:\n{s}", .{
        version,
        path,
        if (reported.stdout.len != 0) reported.stdout else reported.stderr,
    });
    return null;
}

pub fn buildExecutable(
    init: std.process.Init,
    allocator: Allocator,
    options: BuildOptions,
) !bool {
    const llvm_text = llvm_text: {
        var span = if (options.trace) |trace| trace.span(.lowering) else CompilationTrace.Span{};
        defer span.finish();
        break :llvm_text (if (options.entry_function) |entry|
            Emitter.emitEntryWithBoundaries(allocator, options.program, options.boundaries, entry)
        else
            Emitter.emitWithBoundaries(allocator, options.program, options.boundaries)) catch |err| {
            std.debug.print("silex: LLVM backend cannot lower this program: {t}\n", .{err});
            return false;
        };
    };
    const timestamp = Io.Clock.awake.now(init.io).nanoseconds;
    const staging = try std.fmt.allocPrint(allocator, ".silex/llvm/staging-{d}", .{timestamp});
    try Io.Dir.cwd().createDirPath(init.io, staging);
    defer Io.Dir.cwd().deleteTree(init.io, staging) catch {};
    const raw_path = try std.fs.path.join(allocator, &.{ staging, "program.ll" });
    const optimized_path = try std.fs.path.join(allocator, &.{ staging, "program.opt.ll" });
    const object_path = try std.fs.path.join(allocator, &.{ staging, "program.o" });
    const format_path = try std.fs.path.join(allocator, &.{ staging, "silex-llvm-format.o" });
    try writeFile(init.io, raw_path, llvm_text);
    try writeFile(init.io, format_path, format_runtime.object_bytes);

    const optimization = if (options.mode == .debug) "0" else "3";
    const passes = try std.fmt.allocPrint(allocator, "-passes=verify,default<O{s}>", .{optimization});
    {
        var span = if (options.trace) |trace| trace.span(.emission) else CompilationTrace.Span{};
        defer span.finish();
        if (!try runStage(init, "opt", &.{ options.tools.opt, "-S", passes, raw_path, "-o", optimized_path })) return false;
        const level = try std.fmt.allocPrint(allocator, "-O={s}", .{optimization});
        const cpu = try std.fmt.allocPrint(allocator, "-mcpu={s}", .{options.tools.cpu});
        if (!try runStage(init, "llc", &.{
            options.tools.llc,
            "-filetype=obj",
            level,
            "-mtriple=arm64-apple-macosx26.0.0",
            cpu,
            "-fp-contract=off",
            optimized_path,
            "-o",
            object_path,
        })) return false;
    }

    try CompilationCache.ensureOutputParent(init.io, options.output_path);
    Io.Dir.cwd().deleteFile(init.io, options.output_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    {
        var span = if (options.trace) |trace| trace.span(.linking) else CompilationTrace.Span{};
        defer span.finish();
        MacOSLink.executableObjects(
            allocator,
            init.io,
            options.linker_path,
            options.target,
            &.{ object_path, format_path },
            options.output_path,
            options.providers,
            &.{},
        ) catch |err| {
            std.debug.print("silex: cannot link LLVM executable: {t}\n", .{err});
            return false;
        };
    }
    return true;
}

fn runStage(init: std.process.Init, stage: []const u8, arguments: []const []const u8) !bool {
    const result = std.process.run(init.arena.allocator(), init.io, .{ .argv = arguments }) catch |err| {
        std.debug.print("silex: LLVM {s} stage could not start: {t}\n", .{ stage, err });
        return false;
    };
    if (exitCode(result.term) == 0) return true;
    if (result.stdout.len != 0) std.debug.print("{s}", .{result.stdout});
    if (result.stderr.len != 0) std.debug.print("{s}", .{result.stderr});
    std.debug.print("silex: LLVM {s} stage failed\n", .{stage});
    return false;
}

fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .exited => |code| code,
        else => 255,
    };
}

fn writeFile(io: Io, path: []const u8, bytes: []const u8) !void {
    const file = try Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}
