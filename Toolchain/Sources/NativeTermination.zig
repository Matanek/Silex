const std = @import("std");
const builtin = @import("builtin");
const Cli = @import("Cli.zig");

const Allocator = std.mem.Allocator;

const SignalInfo = struct {
    name: []const u8,
    detail: []const u8,
    native_fault: bool,
};

pub fn programDiagnostic(
    allocator: Allocator,
    signal: u32,
    source_path: []const u8,
    executable_path: []const u8,
    mode: Cli.Mode,
) ![]const u8 {
    const info = signalInfo(signal);
    const mode_name = if (mode == .debug) "Debug" else "Release";
    const debugger = debuggerCommand();
    const symbols = sourceSymbols(mode);
    const fault = if (info.native_fault)
        "silex: native fault: generated code, the embedded runtime, or a package boundary may be responsible\n"
    else
        "";
    return std.fmt.allocPrint(
        allocator,
        "silex: program terminated by {s} (signal {d}): {s}\n" ++
            "silex: source: {s}\n" ++
            "silex: native mode: {s}\n" ++
            "silex: retained executable: {s}\n" ++
            "{s}" ++
            "{s}" ++
            "silex: reproduce in Debug: silex run \"{s}\" --debug --nocache\n" ++
            "silex: inspect this executable: {s} \"{s}\"\n",
        .{
            info.name,
            signal,
            info.detail,
            source_path,
            mode_name,
            executable_path,
            symbols,
            fault,
            source_path,
            debugger,
            executable_path,
        },
    );
}

pub fn testDiagnostic(
    allocator: Allocator,
    signal: u32,
    label: []const u8,
    source_path: []const u8,
    executable_path: []const u8,
) ![]const u8 {
    const info = signalInfo(signal);
    const fault = if (info.native_fault)
        "silex: native fault: generated code, the embedded runtime, or a package boundary may be responsible\n"
    else
        "";
    return std.fmt.allocPrint(
        allocator,
        "silex: native test '{s}' terminated by {s} (signal {d}): {s}\n" ++
            "silex: source: {s}\n" ++
            "silex: retained executable: {s}\n" ++
            "{s}" ++
            "{s}" ++
            "silex: reproduce without cached native code: silex test \"{s}\" --nocache\n" ++
            "silex: inspect this executable: {s} \"{s}\"\n",
        .{
            label,
            info.name,
            signal,
            info.detail,
            source_path,
            executable_path,
            sourceSymbols(.debug),
            fault,
            source_path,
            debuggerCommand(),
            executable_path,
        },
    );
}

fn sourceSymbols(mode: Cli.Mode) []const u8 {
    if (mode != .debug) return "silex: source symbols: rebuild in Debug to expose Silex function, file, line and column\n";
    return switch (builtin.os.tag) {
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => "silex: source symbols: Silex function, file, line and column are embedded for LLDB\n",
        else => "silex: source symbols: Debug provenance is preserved, but target debugger symbols are not connected yet\n",
    };
}

pub fn stoppedDescription(allocator: Allocator, signal: u32) ![]const u8 {
    const info = signalInfo(signal);
    return std.fmt.allocPrint(allocator, "{s} (signal {d}): {s}", .{ info.name, signal, info.detail });
}

fn debuggerCommand() []const u8 {
    return switch (builtin.os.tag) {
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => "lldb --",
        .linux => "gdb --args",
        .windows => "windbg",
        else => "debugger --",
    };
}

fn signalInfo(signal: u32) SignalInfo {
    return switch (builtin.os.tag) {
        .driverkit, .ios, .maccatalyst, .macos, .tvos, .visionos, .watchos => darwinSignal(signal),
        .linux => linuxSignal(signal),
        .windows => windowsSignal(signal),
        else => commonSignal(signal),
    };
}

fn commonSignal(signal: u32) SignalInfo {
    return switch (signal) {
        4 => .{ .name = "SIGILL", .detail = "illegal machine instruction", .native_fault = true },
        6 => .{ .name = "SIGABRT", .detail = "the process aborted", .native_fault = true },
        8 => .{ .name = "SIGFPE", .detail = "invalid arithmetic operation", .native_fault = true },
        9 => .{ .name = "SIGKILL", .detail = "the process was forcibly killed", .native_fault = false },
        11 => .{ .name = "SIGSEGV", .detail = "invalid memory access", .native_fault = true },
        15 => .{ .name = "SIGTERM", .detail = "termination was requested", .native_fault = false },
        else => .{ .name = "an operating-system signal", .detail = "the process did not exit normally", .native_fault = false },
    };
}

fn darwinSignal(signal: u32) SignalInfo {
    return switch (signal) {
        5 => .{ .name = "SIGTRAP", .detail = "debugger or breakpoint trap", .native_fault = true },
        10 => .{ .name = "SIGBUS", .detail = "invalid or misaligned memory access", .native_fault = true },
        13 => .{ .name = "SIGPIPE", .detail = "write to a closed pipe", .native_fault = false },
        else => commonSignal(signal),
    };
}

fn linuxSignal(signal: u32) SignalInfo {
    return switch (signal) {
        5 => .{ .name = "SIGTRAP", .detail = "debugger or breakpoint trap", .native_fault = true },
        7 => .{ .name = "SIGBUS", .detail = "invalid or misaligned memory access", .native_fault = true },
        13 => .{ .name = "SIGPIPE", .detail = "write to a closed pipe", .native_fault = false },
        else => commonSignal(signal),
    };
}

fn windowsSignal(signal: u32) SignalInfo {
    return switch (signal) {
        21 => .{ .name = "SIGBREAK", .detail = "console break was requested", .native_fault = false },
        22 => .{ .name = "SIGABRT", .detail = "the process aborted", .native_fault = true },
        else => commonSignal(signal),
    };
}

test "describe a segmentation fault with actionable native context" {
    const text = try programDiagnostic(
        std.testing.allocator,
        11,
        "Examples/Crash.sx",
        "/workspace/.silex/run/Crash-macos-arm64-debug",
        .debug,
    );
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "SIGSEGV (signal 11): invalid memory access") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "source: Examples/Crash.sx") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "retained executable: /workspace/.silex/run/Crash-macos-arm64-debug") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "function, file, line and column are embedded for LLDB") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "--debug --nocache") != null);
}

test "keep an unknown signal explicit without calling it a native fault" {
    const text = try testDiagnostic(std.testing.allocator, 127, "unknown", "Unknown.sx", "/tmp/unknown-test");
    defer std.testing.allocator.free(text);
    try std.testing.expect(std.mem.indexOf(u8, text, "operating-system signal (signal 127)") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "native fault") == null);
    try std.testing.expect(std.mem.indexOf(u8, text, "retained executable: /tmp/unknown-test") != null);
}
