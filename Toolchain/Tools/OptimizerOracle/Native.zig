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
        if (!equal(expected_result, debug_run)) {
            reportMismatch("Debug", source_path, expected_result, debug_run);
            return error.NativeDebugMismatch;
        }
        result.debug_size = (try std.Io.Dir.cwd().statFile(io, debug_path, .{})).size;
    }
    const release_path = try std.fmt.allocPrint(allocator, "{s}-release", .{artifact_stem});
    const release_run = try compileAndRun(allocator, io, silex_binary, source_path, release_path, .release);
    if (!equal(expected_result, release_run)) {
        reportMismatch("Release", source_path, expected_result, release_run);
        return error.NativeReleaseMismatch;
    }
    result.release_size = (try std.Io.Dir.cwd().statFile(io, release_path, .{})).size;
    return result;
}

// Runtime errors have an ordered observable prefix and a normal exit status.
// A signal or merely matching Debug/Release failures cannot satisfy this gate.
pub fn verifyFailure(
    allocator: std.mem.Allocator,
    io: std.Io,
    silex_binary: []const u8,
    source_path: []const u8,
    artifact_stem: []const u8,
    prefix: []const u8,
) !void {
    const expected = .{ .exit_code = @as(u8, 1), .stdout = prefix, .stderr = @as([]const u8, "") };
    for ([_]Mode{ .debug, .release }) |mode| {
        const path = try std.fmt.allocPrint(allocator, "{s}-{s}", .{ artifact_stem, @tagName(mode) });
        const actual = try compileAndRun(allocator, io, silex_binary, source_path, path, mode);
        if (!equal(expected, actual)) {
            reportMismatch(@tagName(mode), source_path, expected, actual);
            return error.NativeFailureMismatch;
        }
    }
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

fn reportMismatch(
    mode: []const u8,
    source_path: []const u8,
    expected: anytype,
    actual: std.process.RunResult,
) void {
    std.debug.print(
        "native {s} mismatch for {s}\n" ++
            "  expected exit={d} stdout={any} stderr={any}\n" ++
            "  actual term={any} stdout={any} stderr={any}\n",
        .{
            mode,
            source_path,
            expected.exit_code,
            expected.stdout,
            expected.stderr,
            actual.term,
            actual.stdout,
            actual.stderr,
        },
    );
}

fn successful(term: std.process.Child.Term) bool {
    return switch (term) {
        .exited => |code| code == 0,
        else => false,
    };
}
