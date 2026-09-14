const builtin = @import("builtin");
const std = @import("std");

pub const silex_compiler_api = @import("silex_optimizer_api");

var logged_errors: usize = 0;

pub const std_options: std.Options = .{ .logFn = log };

pub fn main(init: std.process.Init.Minimal) void {
    @disableInstrumentation();
    var passed: usize = 0;
    var skipped: usize = 0;
    var failed: usize = 0;
    var leaked: usize = 0;
    std.testing.environ = init.environ;

    for (builtin.test_functions, 0..) |test_function, index| {
        std.testing.allocator_instance = .{};
        std.testing.io_instance = .init(std.testing.allocator, .{
            .argv0 = .init(init.args),
            .environ = init.environ,
        });
        logged_errors = 0;
        std.debug.print("{d}/{d} {s}...", .{ index + 1, builtin.test_functions.len, test_function.name });
        if (test_function.func()) |_| {
            passed += 1;
            std.debug.print("OK\n", .{});
        } else |err| switch (err) {
            error.SkipZigTest => {
                skipped += 1;
                std.debug.print("SKIP\n", .{});
            },
            else => {
                failed += 1;
                std.debug.print("FAIL ({t})\n", .{err});
                if (@errorReturnTrace()) |trace| std.debug.dumpErrorReturnTrace(trace);
            },
        }
        std.testing.io_instance.deinit();
        leaked += std.testing.allocator_instance.detectLeaks();
        std.testing.allocator_instance.deinitWithoutLeakChecks();
        if (logged_errors != 0) failed += 1;
    }

    std.debug.print("{d} passed; {d} skipped; {d} failed; {d} leaked.\n", .{
        passed,
        skipped,
        failed,
        leaked,
    });
    if (failed != 0 or leaked != 0) std.process.exit(1);
}

fn log(
    comptime message_level: std.log.Level,
    comptime scope: @EnumLiteral(),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@intFromEnum(message_level) <= @intFromEnum(std.log.Level.err)) logged_errors +|= 1;
    if (@intFromEnum(message_level) <= @intFromEnum(std.testing.log_level)) {
        std.debug.print("[" ++ @tagName(scope) ++ "] (" ++ @tagName(message_level) ++ "): " ++ format ++ "\n", args);
    }
}
