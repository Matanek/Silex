const std = @import("std");
const Differential = @import("Differential.zig");

pub const Mode = enum {
    debug,
    release,

    fn argument(self: Mode) []const u8 {
        return switch (self) {
            .debug => "-d",
            .release => "-r",
        };
    }
};

pub const Verification = struct {
    debug_size: ?u64 = null,
    release_size: u64,
};

pub fn verify(
    allocator: std.mem.Allocator,
    io: std.Io,
    silex_binary: []const u8,
    source_path: []const u8,
    expected: Differential.Execution,
    artifact_stem: []const u8,
    include_debug: bool,
) !Verification {
    const expected_result = switch (expected) {
        .completed => |result| result,
        .failed => return error.ExpectedSuccessfulExecution,
    };
    var result: Verification = .{ .release_size = 0 };
    if (include_debug) {
        const debug_path = try std.fmt.allocPrint(allocator, "{s}-debug", .{artifact_stem});
        const debug_run = try compileAndRun(allocator, io, silex_binary, source_path, debug_path, .debug);
        if (!equal(expected_result, debug_run)) return error.NativeDebugMismatch;
        result.debug_size = (try std.Io.Dir.cwd().statFile(io, debug_path, .{})).size;
    }
    const release_path = try std.fmt.allocPrint(allocator, "{s}-release", .{artifact_stem});
    const release_run = try compileAndRun(allocator, io, silex_binary, source_path, release_path, .release);
    if (!equal(expected_result, release_run)) return error.NativeReleaseMismatch;
    result.release_size = (try std.Io.Dir.cwd().statFile(io, release_path, .{})).size;
    return result;
}

fn compileAndRun(
    allocator: std.mem.Allocator,
    io: std.Io,
    silex_binary: []const u8,
    source_path: []const u8,
    executable_path: []const u8,
    mode: Mode,
) !std.process.RunResult {
    const compilation = try std.process.run(allocator, io, .{
        .argv = &.{
            silex_binary,
            "compile",
            source_path,
            mode.argument(),
            "-n",
            "-o",
            executable_path,
        },
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(16 * 1024 * 1024),
    });
    if (!successful(compilation.term)) {
        const detail = std.mem.trim(u8, compilation.stderr, " \t\r\n");
        if (detail.len != 0) std.debug.print("{s}\n", .{detail});
        return error.NativeCompilationFailed;
    }
    return std.process.run(allocator, io, .{
        .argv = &.{executable_path},
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(16 * 1024 * 1024),
    });
}

fn equal(expected: anytype, actual: std.process.RunResult) bool {
    const exit_code = switch (actual.term) {
        .exited => |code| code,
        else => return false,
    };
    return expected.exit_code == exit_code and
        std.mem.eql(u8, expected.stdout, actual.stdout) and
        std.mem.eql(u8, expected.stderr, actual.stderr);
}

fn successful(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}
