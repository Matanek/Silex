const std = @import("std");

const Io = std.Io;

pub const Phase = enum {
    analyze,
    prepare,
    cache,
    emit,
    link,
    write,
    ready,
    run,
};

pub const Build = struct {
    io: Io,
    enabled: bool,
    clearable: bool,
    line_count: usize = 0,

    pub fn init(io: Io) Build {
        const stderr = Io.File.stderr();
        const enabled = stderr.isTty(io) catch false;
        const clearable = if (enabled) enabled: {
            stderr.enableAnsiEscapeCodes(io) catch break :enabled false;
            break :enabled true;
        } else false;
        return .{
            .io = io,
            .enabled = enabled,
            .clearable = clearable,
        };
    }

    pub fn source(self: *Build, phase: Phase, path: []const u8) void {
        self.message(phase, path);
    }

    pub fn target(self: *Build, target_name: []const u8, mode_name: []const u8) void {
        var buffer: [256]u8 = undefined;
        const detail = std.fmt.bufPrint(&buffer, "{s} ({s})", .{ target_name, mode_name }) catch return;
        self.message(.prepare, detail);
    }

    pub fn stage(self: *Build, phase: Phase) void {
        self.message(phase, phaseDetail(phase));
    }

    pub fn finish(self: *Build) void {
        if (!self.clearable) return;
        while (self.line_count != 0) : (self.line_count -= 1) {
            Io.File.stderr().writeStreamingAll(self.io, clear_previous_line) catch return;
        }
    }

    fn message(self: *Build, phase: Phase, detail: []const u8) void {
        if (!self.enabled) return;
        var buffer: [2048]u8 = undefined;
        const line = std.fmt.bufPrint(&buffer, "silex: [{s}] {s}\n", .{ phaseName(phase), detail }) catch return;
        Io.File.stderr().writeStreamingAll(self.io, line) catch return;
        self.line_count += 1;
    }
};

const clear_previous_line = "\x1b[1A\r\x1b[2K";

pub fn phaseName(phase: Phase) []const u8 {
    return switch (phase) {
        .analyze => "analyze",
        .prepare => "prepare",
        .cache => "cache",
        .emit => "build",
        .link => "link",
        .write => "write",
        .ready => "ready",
        .run => "run",
    };
}

fn phaseDetail(phase: Phase) []const u8 {
    return switch (phase) {
        .cache => "reusing compiled executable",
        .emit => "native executable",
        .link => "platform libraries",
        .write => "executable",
        else => "",
    };
}

test "progress phases use developer-facing build language" {
    try std.testing.expectEqualStrings("analyze", phaseName(.analyze));
    try std.testing.expectEqualStrings("prepare", phaseName(.prepare));
    try std.testing.expectEqualStrings("build", phaseName(.emit));
    try std.testing.expectEqualStrings("link", phaseName(.link));
    try std.testing.expectEqualStrings("ready", phaseName(.ready));
    try std.testing.expectEqualStrings("run", phaseName(.run));
}

test "successful progress clears one complete terminal line at a time" {
    try std.testing.expectEqualStrings("\x1b[1A\r\x1b[2K", clear_previous_line);
}
