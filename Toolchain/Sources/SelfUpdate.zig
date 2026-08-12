const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const Io = std.Io;

const repository = "Matanek/Silex";

pub const Result = enum {
    completed,
    scheduled,
};

pub const Updater = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    diagnostic: ?[]const u8 = null,

    pub fn init(allocator: Allocator, download_allocator: Allocator, io: Io) Updater {
        return .{
            .allocator = allocator,
            .download_allocator = download_allocator,
            .io = io,
        };
    }

    pub fn update(self: *Updater, environment: *const std.process.Environ.Map) !Result {
        self.diagnostic = null;
        const platform = Platform.host() orelse return self.fail("updates are unavailable on this host");
        const executable = std.process.executablePathAlloc(self.io, self.allocator) catch |err|
            return self.failFmt("cannot locate the running Silex executable: {t}", .{err});
        const install_directory = std.fs.path.dirname(executable) orelse
            return self.fail("cannot locate the Silex installation directory");
        const temporary_directory = temporaryDirectory(environment, install_directory, platform);
        Io.Dir.cwd().createDirPath(self.io, temporary_directory) catch |err|
            return self.failFmt("cannot create the update directory: {t}", .{err});
        var random_bytes: [8]u8 = undefined;
        self.io.random(&random_bytes);
        const nonce = std.mem.readInt(u64, &random_bytes, .native);
        const script_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}{c}silex-update-{x}{s}",
            .{ temporary_directory, std.fs.path.sep, nonce, platform.scriptExtension() },
        );
        self.writeInstaller(environment, platform, script_path) catch |err| switch (err) {
            error.InvalidUpdate => return error.InvalidUpdate,
            else => return err,
        };
        var keep_script = true;
        defer if (keep_script) Io.Dir.cwd().deleteFile(self.io, script_path) catch {};

        var child_environment = try environment.clone(self.allocator);
        defer child_environment.deinit();
        _ = child_environment.swapRemove("SILEX_VERSION");
        try child_environment.put("SILEX_INSTALL_DIR", install_directory);
        try child_environment.put("SILEX_UPDATE_SCRIPT", script_path);

        if (platform == .windows) {
            const process_id = std.os.windows.GetCurrentProcessId();
            const process_text = try std.fmt.allocPrint(self.allocator, "{d}", .{process_id});
            try child_environment.put("SILEX_UPDATE_PID", process_text);
            const child = std.process.spawn(self.io, .{
                .argv = &.{ "powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", script_path },
                .environ_map = &child_environment,
                .stdin = .inherit,
                .stdout = .inherit,
                .stderr = .inherit,
                .create_no_window = false,
            }) catch |err| return self.failFmt("cannot start the Windows updater: {t}", .{err});
            _ = child;
            keep_script = false;
            return .scheduled;
        }

        var child = std.process.spawn(self.io, .{
            .argv = &.{ "sh", script_path },
            .environ_map = &child_environment,
            .stdin = .inherit,
            .stdout = .inherit,
            .stderr = .inherit,
        }) catch |err| return self.failFmt("cannot start the Silex installer: {t}", .{err});
        defer child.kill(self.io);
        const term = try child.wait(self.io);
        return switch (term) {
            .exited => |code| if (code == 0) .completed else self.failFmt("the Silex installer exited with code {d}", .{code}),
            else => self.fail("the Silex installer terminated unexpectedly"),
        };
    }

    fn writeInstaller(
        self: *Updater,
        environment: *const std.process.Environ.Map,
        platform: Platform,
        destination: []const u8,
    ) !void {
        const override = environment.get("SILEX_UPDATE_INSTALLER");
        const source = if (override) |path|
            Io.Dir.cwd().readFileAlloc(self.io, path, self.allocator, .limited(256 * 1024)) catch |err|
                return self.failFmt("cannot read update installer '{s}': {t}", .{ path, err })
        else
            try self.fetchInstaller(platform.installerUrl());
        const file = Io.Dir.cwd().createFile(self.io, destination, .{ .exclusive = true }) catch |err|
            return self.failFmt("cannot stage the update installer: {t}", .{err});
        defer file.close(self.io);
        file.writeStreamingAll(self.io, source) catch |err|
            return self.failFmt("cannot write the update installer: {t}", .{err});
    }

    fn fetchInstaller(self: *Updater, url: []const u8) ![]const u8 {
        var output: Io.Writer.Allocating = .init(self.download_allocator);
        defer output.deinit();
        var client: std.http.Client = .{ .allocator = self.download_allocator, .io = self.io };
        defer client.deinit();
        const response = client.fetch(.{
            .location = .{ .url = url },
            .response_writer = &output.writer,
            .headers = .{ .user_agent = .{ .override = "Silex updater" } },
        }) catch |err| return self.failFmt("cannot download the Silex installer: {t}", .{err});
        if (response.status.class() != .success) {
            return self.failFmt("cannot download the Silex installer: HTTP {d}", .{@intFromEnum(response.status)});
        }
        if (output.written().len > 256 * 1024) return self.fail("the Silex installer exceeds 256 KiB");
        return self.allocator.dupe(u8, output.written());
    }

    fn fail(self: *Updater, message: []const u8) error{InvalidUpdate} {
        self.diagnostic = message;
        return error.InvalidUpdate;
    }

    fn failFmt(self: *Updater, comptime format: []const u8, arguments: anytype) error{ OutOfMemory, InvalidUpdate } {
        self.diagnostic = try std.fmt.allocPrint(self.allocator, format, arguments);
        return error.InvalidUpdate;
    }
};

const Platform = enum {
    unix,
    windows,

    fn host() ?Platform {
        return switch (builtin.os.tag) {
            .macos, .linux => .unix,
            .windows => .windows,
            else => null,
        };
    }

    fn scriptExtension(self: Platform) []const u8 {
        return switch (self) {
            .unix => ".sh",
            .windows => ".ps1",
        };
    }

    fn installerUrl(self: Platform) []const u8 {
        return switch (self) {
            .unix => "https://raw.githubusercontent.com/" ++ repository ++ "/main/install.sh",
            .windows => "https://raw.githubusercontent.com/" ++ repository ++ "/main/install.ps1",
        };
    }
};

fn temporaryDirectory(
    environment: *const std.process.Environ.Map,
    install_directory: []const u8,
    platform: Platform,
) []const u8 {
    return switch (platform) {
        .unix => environment.get("TMPDIR") orelse "/tmp",
        .windows => environment.get("TEMP") orelse environment.get("TMP") orelse install_directory,
    };
}

test "select the official installer for each platform" {
    try std.testing.expectEqualStrings(".sh", Platform.unix.scriptExtension());
    try std.testing.expectEqualStrings(".ps1", Platform.windows.scriptExtension());
    try std.testing.expectEqualStrings(
        "https://raw.githubusercontent.com/Matanek/Silex/main/install.sh",
        Platform.unix.installerUrl(),
    );
    try std.testing.expectEqualStrings(
        "https://raw.githubusercontent.com/Matanek/Silex/main/install.ps1",
        Platform.windows.installerUrl(),
    );
}

test "prefer the platform temporary directory and preserve a writable fallback" {
    var environment = std.process.Environ.Map.init(std.testing.allocator);
    defer environment.deinit();
    try environment.put("TMPDIR", "/private/tmp/custom");
    try environment.put("TEMP", "C:\\Temp");
    try std.testing.expectEqualStrings("/private/tmp/custom", temporaryDirectory(&environment, "/bin", .unix));
    try std.testing.expectEqualStrings("C:\\Temp", temporaryDirectory(&environment, "C:\\Silex", .windows));
}
