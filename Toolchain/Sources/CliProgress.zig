const std = @import("std");
const Io = std.Io;

pub const Phase = enum {
    analyze,
    prepare,
    cache,
    optimize,
    lower,
    optimize_backend,
    emit,
    link,
    write,
    ready,
    run,
};

pub const InstallPhase = enum { registry, resolve, download, install };

// std.Progress owns terminal sizing, redraws and coordination with diagnostics.
// Initialize its process-wide root only once, lazily for interactive commands.
var root: std.Progress.Node = .none;
var started = false;
var stopped = false;
var dumb_terminal = false;

pub fn configure(environ: *const std.process.Environ.Map) void {
    dumb_terminal = if (environ.get("TERM")) |term| std.mem.eql(u8, term, "dumb") else false;
}

pub fn shutdown() void {
    if (!started or stopped) return;
    root.end();
    stopped = true;
}

const Activity = struct {
    io: Io,
    enabled: bool,
    animated: bool,
    node: std.Progress.Node = .none,
    worker: ?Io.Future(void) = null,
    mutex: Io.Mutex = .init,
    label: [96]u8 = @splat(0),
    label_len: usize = 0,
    started_at: i96 = 0,

    fn init(io: Io) Activity {
        const enabled = Io.File.stderr().isTty(io) catch false;
        const animated = enabled and !dumb_terminal and !stopped;
        if (animated and !started) {
            root = std.Progress.start(io, .{ .initial_delay_ns = .fromMilliseconds(120) });
            started = true;
        }
        return .{ .io = io, .enabled = enabled, .animated = animated and root.index != .none };
    }

    // The worker starts only after the Activity has reached its final address.
    // Copy the caller's label: package and target names often use stack buffers.
    fn message(self: *Activity, phase: []const u8, detail: []const u8) void {
        if (!self.enabled) return;
        if (!self.animated) {
            std.debug.print("silex: [{s}] {s}\n", .{ phase, detail });
            return;
        }
        self.mutex.lockUncancelable(self.io);
        var writer = Io.Writer.fixed(&self.label);
        writer.print("[{s}] {s}", .{ phase, detail }) catch {};
        self.label_len = writer.end;
        // Terminal control characters in paths must not become terminal commands.
        for (self.label[0..self.label_len]) |*byte| {
            if (byte.* < 0x20 or byte.* == 0x7f) byte.* = ' ';
        }
        self.mutex.unlock(self.io);
        if (self.worker == null) {
            self.started_at = Io.Clock.awake.now(self.io).nanoseconds;
            self.node = root.start("", 0);
            self.redraw(0);
            self.worker = self.io.concurrent(tick, .{self}) catch {
                // A failed activity worker must never prevent the actual work.
                self.node.end();
                self.node = .none;
                self.animated = false;
                std.debug.print("silex: [{s}] {s}\n", .{ phase, detail });
                return;
            };
        } else self.redraw(0);
    }

    fn tick(self: *Activity) void {
        var frame: usize = 0;
        while (true) {
            Io.sleep(self.io, .fromMilliseconds(100), .awake) catch return;
            frame +%= 1;
            self.redraw(frame);
        }
    }

    fn redraw(self: *Activity, frame: usize) void {
        self.mutex.lockUncancelable(self.io);
        defer self.mutex.unlock(self.io);
        const elapsed = @max(0, Io.Clock.awake.now(self.io).nanoseconds - self.started_at);
        var buffer: [std.Progress.Node.max_name_len]u8 = undefined;
        const name = formatActivity(&buffer, self.label[0..self.label_len], frame, @intCast(@divTrunc(elapsed, std.time.ns_per_s)));
        self.node.setName(name);
    }

    fn finish(self: *Activity) void {
        if (self.worker) |*worker| worker.cancel(self.io);
        self.worker = null;
        self.node.end();
        self.node = .none;
    }
};

fn formatActivity(buffer: []u8, label: []const u8, frame: usize, seconds: u64) []const u8 {
    var writer = Io.Writer.fixed(buffer);
    writer.print("silex: {c} {d}s {s}", .{ "|/-\\"[frame % 4], seconds, label }) catch {};
    // Truncation should never leave a partial UTF-8 scalar in the terminal.
    while (!std.unicode.utf8ValidateSlice(writer.buffered()) and writer.end > 0) writer.end -= 1;
    return writer.buffered();
}

pub const Build = struct {
    activity: Activity,

    pub fn init(io: Io) Build {
        return .{ .activity = Activity.init(io) };
    }

    pub fn source(self: *Build, phase: Phase, path: []const u8) void {
        self.activity.message(phaseName(phase), path);
    }

    pub fn target(self: *Build, target_name: []const u8, mode_name: []const u8) void {
        var buffer: [256]u8 = undefined;
        const detail = std.fmt.bufPrint(&buffer, "{s} ({s})", .{ target_name, mode_name }) catch return;
        self.source(.prepare, detail);
    }

    pub fn stage(self: *Build, phase: Phase) void {
        self.source(phase, switch (phase) {
            .cache => "reusing compiled executable",
            .optimize => "Silex program",
            .lower => "preparing code generation",
            .optimize_backend => "LLVM program",
            .emit => "machine code",
            .link => "platform libraries",
            .write => "executable",
            else => "",
        });
    }

    pub fn writeOutput(self: *Build, text: []const u8) !void {
        // stdout may share the terminal with the progress row (notably --emit-ir).
        // Clear that row and suspend redraws until the complete output is written.
        _ = std.debug.lockStderr(&.{});
        defer std.debug.unlockStderr();
        try Io.File.stdout().writeStreamingAll(self.activity.io, text);
    }

    pub fn finish(self: *Build) void {
        self.activity.finish();
    }
};

pub const Install = struct {
    activity: Activity,
    completed: usize = 0,

    pub fn init(io: Io) Install {
        return .{ .activity = Activity.init(io) };
    }

    pub fn isInteractive(self: *const Install) bool {
        return self.activity.enabled;
    }

    pub fn source(self: *Install, phase: InstallPhase, detail: []const u8) void {
        self.activity.message(@tagName(phase), detail);
        self.activity.node.setCompletedItems(self.completed);
    }

    pub fn package(self: *Install, phase: InstallPhase, name: []const u8, version: ?struct { major: u32, minor: u32, patch: u32 }) void {
        if (version) |value| {
            var buffer: [512]u8 = undefined;
            const detail = std.fmt.bufPrint(&buffer, "{s}@{d}.{d}.{d}", .{ name, value.major, value.minor, value.patch }) catch return;
            self.source(phase, detail);
        } else self.source(phase, name);
    }

    pub fn finish(self: *Install) void {
        self.activity.finish();
    }

    pub fn complete(self: *Install, name: []const u8, version: struct { major: u32, minor: u32, patch: u32 }, installed: bool) void {
        self.completed += 1;
        self.activity.node.setCompletedItems(self.completed);
        if (!self.activity.enabled) return;
        std.debug.print("silex: [ready] {s}@{d}.{d}.{d} ({s})\n", .{
            name,                                                version.major, version.minor, version.patch,
            if (installed) "installed" else "already installed",
        });
    }

    pub fn failed(self: *Install, name: []const u8, version: ?struct { major: u32, minor: u32, patch: u32 }, diagnostic: []const u8) void {
        self.finish();
        if (!self.activity.enabled) return;
        if (version) |value| {
            std.debug.print("silex: [failed] {s}@{d}.{d}.{d}: {s}\n", .{ name, value.major, value.minor, value.patch, diagnostic });
        } else std.debug.print("silex: [failed] {s}: {s}\n", .{ name, diagnostic });
    }
};

pub fn phaseName(phase: Phase) []const u8 {
    return switch (phase) {
        .optimize_backend => "optimize",
        .emit => "build",
        else => @tagName(phase),
    };
}

test "activity remains visibly alive during an unchanged phase" {
    var first: [120]u8 = undefined;
    var later: [120]u8 = undefined;
    const a = formatActivity(&first, "[optimize] Silex program", 0, 0);
    const b = formatActivity(&later, "[optimize] Silex program", 1, 3);
    try std.testing.expect(!std.mem.eql(u8, a, b));
    try std.testing.expect(std.mem.indexOf(u8, b, "3s [optimize] Silex program") != null);
}

test "long activity labels retain valid UTF-8 and elapsed time" {
    var buffer: [16]u8 = undefined;
    const label = formatActivity(&buffer, "ééééééééééé", 0, 12);
    try std.testing.expect(std.unicode.utf8ValidateSlice(label));
    try std.testing.expect(std.mem.indexOf(u8, label, "12s") != null);
}

test "disabled activity neither starts a worker nor retains caller storage" {
    var activity: Activity = .{ .io = std.testing.io, .enabled = false, .animated = false };
    activity.message("build", "program");
    try std.testing.expect(activity.worker == null);
    try std.testing.expect(activity.node.index == .none);
    activity.finish();
    activity.finish();
}
