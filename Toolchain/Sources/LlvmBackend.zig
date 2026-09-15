const std = @import("std");
const Boundary = @import("Boundary.zig");
const Cli = @import("Cli.zig");
const CliProgress = @import("CliProgress.zig");
const CompilationCache = @import("CompilationCache.zig");
const CompilationTrace = @import("CompilationTrace.zig");
const Emitter = @import("../Tools/LlvmEvaluation/Emitter.zig");
const Ir = @import("Ir.zig");
const MacOSLink = @import("MacOS/Link.zig");
const Packages = @import("Packages.zig");
const ToolchainSetup = @import("ToolchainSetup.zig");
const TargetModule = @import("Target.zig");
const format_runtime = @import("llvm_format_runtime_object");
const Units = @import("Llvm/Units.zig");
const Store = @import("Llvm/Store.zig").Store;
const Compile = @import("Llvm/Compile.zig");
const StoreLimit = @import("Llvm/Store.zig").limit;

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const version = ToolchainSetup.llvm_version;

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
    progress: ?*CliProgress.Build = null,
    cache: bool = true,
    worker_count: u16 = 1,
};

pub fn resolveTools(
    init: std.process.Init,
    allocator: Allocator,
) !?Tools {
    const override_root = init.environ_map.get("SILEX_LLVM_DIR");
    const root = override_root orelse managed_root: {
        const home = init.environ_map.get("HOME") orelse init.environ_map.get("USERPROFILE") orelse break :managed_root null;
        const toolchain_root = try std.fs.path.join(allocator, &.{ home, ".silex", "toolchain" });
        break :managed_root try ToolchainSetup.llvmRootPath(allocator, toolchain_root, .macos_arm64);
    } orelse {
        std.debug.print(
            "silex: LLVM backend {s} is not configured; run 'silex setup' or set SILEX_LLVM_DIR to its installation directory\n",
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
            if (override_root == null) {
                std.debug.print(
                    "silex: managed LLVM {s} is incomplete; run 'silex setup' to install {s}\n",
                    .{ version, tool.name },
                );
            } else {
                std.debug.print("silex: LLVM backend cannot locate {s} at '{s}'\n", .{ tool.name, tool.path });
            }
            return null;
        };
        if (status.kind != .file) {
            if (override_root == null) {
                std.debug.print(
                    "silex: managed LLVM {s} is incomplete; run 'silex setup' to reinstall {s}\n",
                    .{ version, tool.name },
                );
            } else {
                std.debug.print("silex: LLVM backend expected a file at '{s}'\n", .{tool.path});
            }
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
    if (options.progress) |progress| progress.stage(.lower);
    const llvm_text = llvm_text: {
        var span = if (options.trace) |trace| trace.span(.lowering) else CompilationTrace.Span{};
        defer span.finish();
        break :llvm_text Emitter.emitCacheableEntry(allocator, options.program, options.boundaries, options.entry_function) catch |err| {
            std.debug.print("silex: LLVM backend cannot lower this program: {t}\n", .{err});
            return false;
        };
    };
    const timestamp = Io.Clock.awake.now(init.io).nanoseconds;
    const staging = try std.fmt.allocPrint(allocator, ".silex/llvm/staging-{d}", .{timestamp});
    try Io.Dir.cwd().createDirPath(init.io, staging);
    defer Io.Dir.cwd().deleteTree(init.io, staging) catch {};
    const format_path = try std.fs.path.join(allocator, &.{ staging, "silex-llvm-format.o" });
    try writeFile(init.io, format_path, format_runtime.object_bytes);

    const units = try Units.split(allocator, options.program, llvm_text, options.mode == .release);
    const cache = if (options.cache) try Store.init(init, allocator) else null;
    var objects: std.ArrayList([]const u8) = .empty;
    try objects.append(allocator, format_path);

    var jobs: std.ArrayList(Compile.Job) = .empty;
    for (units, 0..) |unit, index| {
        const object_path = try std.fmt.allocPrint(allocator, "{s}/unit-{d}.o", .{ staging, index });
        try objects.append(allocator, object_path);
        const digest = Store.key("llvm-unit-v2", &.{ version, options.tools.cpu, options.target.name(), @tagName(options.mode), unit.text });
        if (cache) |store| if (store.load(digest)) |bytes| {
            try writeFile(init.io, object_path, bytes);
            if (options.trace) |trace| {
                trace.metrics.llvm_units_reused += 1;
                trace.metrics.llvm_functions_reused += unit.functions;
            }
            continue;
        };
        if (options.trace) |trace| trace.metrics.llvm_units_compiled += 1;
        try jobs.append(allocator, .{
            .text = unit.text,
            .object_path = object_path,
            .raw_path = try std.fmt.allocPrint(allocator, "{s}/unit-{d}.ll", .{ staging, index }),
            .optimized_path = try std.fmt.allocPrint(allocator, "{s}/unit-{d}.opt.ll", .{ staging, index }),
            .digest = digest,
        });
    }
    const optimization = if (options.mode == .debug) "0" else "3";
    const succeeded = compiled: {
        var span = if (options.trace) |trace| trace.span(.emission) else CompilationTrace.Span{};
        defer span.finish();
        if (options.progress) |progress| progress.stage(.optimize_backend);
        break :compiled Compile.run(.{
            .allocator = allocator,
            .io = init.io,
            .opt = options.tools.opt,
            .llc = options.tools.llc,
            .passes = try std.fmt.allocPrint(allocator, "-passes=verify,default<O{s}>", .{optimization}),
            .level = try std.fmt.allocPrint(allocator, "-O={s}", .{optimization}),
            .cpu = try std.fmt.allocPrint(allocator, "-mcpu={s}", .{options.tools.cpu}),
            .workers = options.worker_count,
            .progress = options.progress,
        }, jobs.items);
    };
    if (cache) |store| {
        var fragments: std.ArrayList(Store.Fragment) = .empty;
        for (jobs.items) |job| if (job.succeeded) {
            const bytes = Io.Dir.cwd().readFileAlloc(init.io, job.object_path, allocator, .limited(StoreLimit)) catch continue;
            fragments.append(allocator, .{ .digest = job.digest, .bytes = bytes }) catch continue;
        };
        store.publishMany(fragments.items) catch {};
    }
    if (!succeeded) return false;
    const response_path = try std.fs.path.join(allocator, &.{ staging, "objects.rsp" });
    var response: std.ArrayList(u8) = .empty;
    for (objects.items) |path| {
        try response.appendSlice(allocator, path);
        try response.append(allocator, '\n');
    }
    try writeFile(init.io, response_path, response.items);

    try CompilationCache.ensureOutputParent(init.io, options.output_path);
    Io.Dir.cwd().deleteFile(init.io, options.output_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    {
        var span = if (options.trace) |trace| trace.span(.linking) else CompilationTrace.Span{};
        defer span.finish();
        if (options.progress) |progress| progress.stage(.link);
        MacOSLink.executableObjects(
            allocator,
            init.io,
            options.linker_path,
            options.target,
            &.{try std.fmt.allocPrint(allocator, "@{s}", .{response_path})},
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
