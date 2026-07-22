const std = @import("std");
const NativeDependency = @import("NativeDependency.zig");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

const max_concurrent_compilations = 8;

pub const CompileRequest = struct {
    runtime: NativeDependency.ModuleRuntime,
    source: NativeDependency.SourceFile,
    output_path: []const u8,
};

pub fn compileArguments(
    allocator: Allocator,
    zig_path: []const u8,
    target: TargetModule.Target,
    compiler_flags: []const []const u8,
    runtime: NativeDependency.ModuleRuntime,
    source: NativeDependency.SourceFile,
    output_path: ?[]const u8,
) ![]const []const u8 {
    var arguments: std.ArrayList([]const u8) = .empty;
    const driver = switch (source.kind) {
        .c, .objective_c => "cc",
        .cpp, .objective_cpp => "c++",
    };
    try arguments.appendSlice(allocator, &.{ zig_path, driver });
    if (target.zig_triple) |triple| try arguments.appendSlice(allocator, &.{ "-target", triple });
    try arguments.appendSlice(allocator, compiler_flags);
    if (source.kind == .cpp or source.kind == .objective_cpp) {
        try arguments.appendSlice(allocator, &.{ "-std=c++23", "-Wno-nullability-completeness" });
    }
    for (runtime.include_dirs) |include_dir| {
        try arguments.append(allocator, try std.fmt.allocPrint(allocator, "-I{s}", .{include_dir}));
    }
    for (runtime.defines) |define| {
        try arguments.append(allocator, try std.fmt.allocPrint(allocator, "-D{s}={s}", .{ define.name, define.value }));
    }
    try arguments.appendSlice(allocator, &.{ "-c", source.path });
    if (output_path) |output| try arguments.appendSlice(allocator, &.{ "-o", output });
    return arguments.toOwnedSlice(allocator);
}

pub fn compileObjects(
    allocator: Allocator,
    io: Io,
    zig_path: []const u8,
    target: TargetModule.Target,
    compiler_flags: []const []const u8,
    requests: []const CompileRequest,
    backend_log_path: []const u8,
    progress: std.Progress.Node,
) !void {
    const Job = struct {
        future: Io.Future(std.process.RunError!std.process.RunResult),
        progress: std.Progress.Node,
    };

    var request_index: usize = 0;
    while (request_index < requests.len) {
        var jobs: [max_concurrent_compilations]Job = undefined;
        var job_count: usize = 0;
        while (job_count < jobs.len and request_index < requests.len) : ({
            job_count += 1;
            request_index += 1;
        }) {
            const request = requests[request_index];
            const arguments = try compileArguments(
                allocator,
                zig_path,
                target,
                compiler_flags,
                request.runtime,
                request.source,
                request.output_path,
            );
            const step = progress.start(std.fs.path.basename(request.source.path), 0);
            jobs[job_count] = .{
                .future = io.async(runCompile, .{ io, arguments, step }),
                .progress = step,
            };
        }

        var first_run_error: ?std.process.RunError = null;
        var first_backend_failure: ?[]const u8 = null;
        var completed_jobs: usize = 0;
        defer for (jobs[completed_jobs..job_count]) |*job| {
            if (job.future.cancel(io)) |result| {
                std.heap.c_allocator.free(result.stdout);
                std.heap.c_allocator.free(result.stderr);
            } else |_| {}
            job.progress.end();
        };
        for (jobs[0..job_count]) |*job| {
            const outcome = job.future.await(io);
            completed_jobs += 1;
            job.progress.end();
            progress.completeOne();
            const result = outcome catch |err| {
                if (first_run_error == null) first_run_error = err;
                continue;
            };
            defer std.heap.c_allocator.free(result.stdout);
            defer std.heap.c_allocator.free(result.stderr);
            if (!termSucceeded(result.term)) {
                if (first_backend_failure == null) {
                    first_backend_failure = try allocator.dupe(u8, result.stderr);
                }
                continue;
            }
            if (result.stdout.len > 0) try Io.File.stdout().writeStreamingAll(io, result.stdout);
            if (result.stderr.len > 0) try Io.File.stderr().writeStreamingAll(io, result.stderr);
        }
        if (first_run_error) |err| return err;
        if (first_backend_failure) |backend_output| {
            try Io.Dir.cwd().writeFile(io, .{ .sub_path = backend_log_path, .data = backend_output });
            return error.NativeObjectCompilationFailed;
        }
    }
}

fn runCompile(
    io: Io,
    arguments: []const []const u8,
    progress: std.Progress.Node,
) std.process.RunError!std.process.RunResult {
    return std.process.run(std.heap.c_allocator, io, .{
        .argv = arguments,
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(16 * 1024 * 1024),
        .progress_node = progress,
    });
}

fn termSucceeded(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}

test "native command preserves the C++ compilation contract" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const runtime: NativeDependency.ModuleRuntime = .{
        .module_name = "Probe",
        .module_directory = ".",
        .manifest_path = "@Module.json",
        .origin = .project,
        .sources = &.{},
        .include_dirs = &.{"Includes"},
        .defines = &.{.{ .name = "MODE", .value = "editor" }},
        .system_libraries = &.{},
        .frameworks = &.{},
    };
    const arguments = try compileArguments(
        arena.allocator(),
        "/distribution/toolchain/zig/zig",
        TargetModule.Target.native(),
        &.{"-O2"},
        runtime,
        .{ .kind = .cpp, .path = "Source.cpp" },
        "Source.o",
    );
    const expected: []const []const u8 = &.{
        "/distribution/toolchain/zig/zig",
        "c++",
        "-O2",
        "-std=c++23",
        "-Wno-nullability-completeness",
        "-IIncludes",
        "-DMODE=editor",
        "-c",
        "Source.cpp",
        "-o",
        "Source.o",
    };
    try std.testing.expectEqual(expected.len, arguments.len);
    for (expected, arguments) |expected_argument, argument| {
        try std.testing.expectEqualStrings(expected_argument, argument);
    }
}
