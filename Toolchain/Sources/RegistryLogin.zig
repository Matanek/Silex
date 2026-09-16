//! Experimental registry identity client. GitHub credentials never reach this process.
const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const WindowsCredential = @import("Windows/RegistryCredential.zig");
const is_windows = builtin.os.tag == .windows;
const verification_uri = "https://github.com/login/device";
const production_origin = "https://registry.silex-lang.org";
const credential_name = if (is_windows) "registry.dpapi" else "registry.json";
const file_permissions: Io.File.Permissions = if (is_windows) .default_file else @enumFromInt(0o600);
const directory_permissions: Io.File.Permissions = if (is_windows) .default_dir else @enumFromInt(0o700);

const Credential = struct {
    token: []const u8,
    github_id: []const u8,
    login: []const u8,
    expires_at: i64,
};

const Reply = struct {
    id: []const u8,
    state: []const u8,
    expires_at: i64,
    user_code: ?[]const u8 = null,
    verification_uri: ?[]const u8 = null,
    interval: ?i64 = null,
    retry_after: ?i64 = null,
    token: ?[]const u8 = null,
    github_id: ?[]const u8 = null,
    login: ?[]const u8 = null,
};

const Response = struct {
    bytes: [32768]u8 = undefined,
    len: usize,
    status: std.http.Status,
    fn body(self: *const Response) []const u8 {
        return self.bytes[0..self.len];
    }
};

const Client = struct {
    io: Io,
    allocator: std.mem.Allocator,
    network_allocator: std.mem.Allocator,
    origin: []const u8,

    fn fetch(self: Client, method: std.http.Method, url: []const u8, authorization: []const u8) !Response {
        var client: std.http.Client = .{ .allocator = self.network_allocator, .io = self.io };
        defer client.deinit();
        var result: Response = .{ .len = 0, .status = .ok };
        var writer = Io.Writer.fixed(&result.bytes);
        const response = try client.fetch(.{
            .location = .{ .url = url },
            .method = method,
            .payload = if (method == .POST) "" else null,
            .response_writer = &writer,
            .redirect_behavior = .unhandled,
            .headers = .{ .user_agent = .{ .override = "Silex-Registry-Identity" }, .authorization = .{ .override = authorization } },
        });
        result.status = response.status;
        result.len = writer.end;
        return result;
    }

    fn request(self: Client, method: std.http.Method, path: []const u8, scheme: []const u8, secret: []const u8) !Response {
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.origin, path });
        const authorization = try std.fmt.allocPrint(self.allocator, "{s} {s}", .{ scheme, secret });
        // A worker owns all network allocations; cancellation joins it before the stack returns.
        const Event = union(enum) { response: anyerror!Response, timeout: Io.Cancelable!void };
        var buffer: [2]Event = undefined;
        var select = Io.Select(Event).init(self.io, &buffer);
        defer select.cancelDiscard();
        try select.concurrent(.response, fetch, .{ self, method, url, authorization });
        try select.concurrent(.timeout, Io.sleep, .{ self.io, Io.Duration.fromSeconds(25), .boot });
        return switch (try select.await()) {
            .response => |response| response catch return error.RegistryConnectionFailed,
            .timeout => error.RegistryRequestTimedOut,
        };
    }
};

fn equal(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}
fn hex(value: []const u8, length: usize) bool {
    if (value.len != length) return false;
    for (value) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}
fn validIdentity(id: []const u8, login: []const u8) bool {
    if (id.len == 0 or id.len > 20 or id[0] == '0' or login.len == 0 or login.len > 39) return false;
    for (id) |byte| if (!std.ascii.isDigit(byte)) return false;
    for (login) |byte| if (!std.ascii.isAlphanumeric(byte) and byte != '-') return false;
    return true;
}
fn checkCredential(credential: Credential) !void {
    if (!hex(credential.token, 64) or !validIdentity(credential.github_id, credential.login) or credential.expires_at <= 0)
        return error.InvalidRegistryCredential;
}
fn checkStatus(status: std.http.Status) !void {
    switch (status) {
        .ok => {},
        .unauthorized, .forbidden => return error.RegistryAccessRefused,
        .too_many_requests => return error.RegistryLoginRateLimited,
        .service_unavailable => return error.RegistryLoginUnavailable,
        else => return error.InvalidRegistryResponse,
    }
}
fn parse(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    const parsed = std.json.parseFromSlice(T, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.InvalidRegistryResponse;
    // Owned by the command arena, including strings used after a response buffer is reused.
    return parsed.value;
}
fn private(stat: Io.File.Stat, kind: Io.File.Kind) !void {
    if (stat.kind != kind or (!is_windows and (@intFromEnum(stat.permissions) & 0o077) != 0) or (kind == .file and stat.nlink != 1))
        return error.RegistryCredentialStorageNotPrivate;
}
fn syncDirectory(dir: Io.Dir, io: Io) !void {
    // Windows has no equivalent directory fsync on this read-only directory
    // handle. File contents are flushed before rename; no power-loss claim.
    if (is_windows) return;
    const file: Io.File = .{ .handle = dir.handle, .flags = .{ .nonblocking = false } };
    try file.sync(io);
}
fn storageError(comptime step: []const u8, err: anyerror) anyerror {
    // Identify the failing operation without printing paths or credentials.
    std.debug.print("silex: registry storage {s} failed: {s}\n", .{ step, @errorName(err) });
    return err;
}
fn load(dir: Io.Dir, io: Io, allocator: std.mem.Allocator) !?Credential {
    const file = dir.openFile(io, credential_name, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return null,
        error.Unexpected => {
            // Zig 0.16 can report an absent Windows file as Unexpected when
            // opening it without following reparse points. Enumerate the
            // already-checked directory; never reinterpret an existing file's
            // failure or an unsuccessful enumeration as an absent credential.
            if (is_windows) {
                var entries = dir.iterate();
                var count: usize = 0;
                while (entries.next(io) catch |list_err| return storageError("credential listing", list_err)) |entry| {
                    if (equal(entry.name, credential_name)) return storageError("credential open (entry listed)", err);
                    count += 1;
                    if (count > 128) return error.RegistryCredentialStorageTooManyEntries;
                }
                return null;
            }
            return storageError("credential open", err);
        },
        else => return storageError("credential open", err),
    };
    defer file.close(io);
    const credential_stat = file.stat(io) catch |err| return storageError("credential metadata", err);
    try private(credential_stat, .file);
    var bytes: [16385]u8 = undefined;
    const len = file.readPositionalAll(io, &bytes, 0) catch |err| return storageError("credential read", err);
    if (len > (if (is_windows) @as(usize, 16384) else 4096)) return error.InvalidRegistryCredential;
    const plain = if (is_windows) WindowsCredential.unprotect(allocator, bytes[0..len]) catch |err| return storageError("credential decryption", err) else bytes[0..len];
    const credential = try parse(Credential, allocator, plain);
    try checkCredential(credential);
    return credential;
}
fn save(dir: Io.Dir, io: Io, allocator: std.mem.Allocator, credential: Credential) !void {
    var random: [16]u8 = undefined;
    try io.randomSecure(&random);
    const name = try std.fmt.allocPrint(allocator, ".registry-{s}.tmp", .{std.fmt.bytesToHex(random, .lower)});
    const file = try dir.createFile(io, name, .{ .exclusive = true, .permissions = file_permissions });
    defer file.close(io);
    defer dir.deleteFile(io, name) catch {};
    const plain = try std.json.Stringify.valueAlloc(allocator, credential, .{});
    const bytes = if (is_windows) try WindowsCredential.protect(allocator, plain) else plain;
    try file.writeStreamingAll(io, bytes);
    try file.sync(io);
    try dir.rename(name, dir, credential_name, io);
    try syncDirectory(dir, io);
}

fn testOrigin(value: []const u8) bool {
    const prefix = "http://127.0.0.1:";
    if (!std.mem.startsWith(u8, value, prefix)) return false;
    const port = value[prefix.len..];
    if (port.len == 0 or port.len > 5) return false;
    for (port) |byte| if (!std.ascii.isDigit(byte)) return false;
    return (std.fmt.parseInt(u16, port, 10) catch return false) != 0;
}

pub fn run(init: std.process.Init, args: []const []const u8, logout: bool) !u8 {
    const no_browser = args.len == 1 and equal(args[0], "--no-browser");
    if (args.len != 0 and (logout or !no_browser)) {
        std.debug.print("silex: usage: silex {s}\n", .{if (logout) "logout" else "login [--no-browser]"});
        return 1;
    }
    const allocator = init.arena.allocator();
    const io = init.io;
    const test_url = init.environ_map.get("SILEX_REGISTRY_TEST_URL");
    const test_root = init.environ_map.get("SILEX_REGISTRY_TEST_ROOT");
    if ((test_url == null) != (test_root == null)) return error.RegistryTestConfigurationRequiresURLAndRoot;
    const root = if (test_root) |path| blk: {
        if (!testOrigin(test_url.?) or !std.fs.path.isAbsolute(path)) return error.InvalidRegistryTestConfiguration;
        const real = Io.Dir.cwd().realPathFileAlloc(io, path, allocator) catch |err| return storageError("test root resolution", err);
        const state = Io.Dir.cwd().realPathFileAlloc(io, "TestState", allocator) catch |err| return storageError("test state resolution", err);
        const prefix = try std.fmt.allocPrint(allocator, "{s}{s}", .{ state, std.fs.path.sep_str });
        if (!std.mem.startsWith(u8, real, prefix)) return error.RegistryTestRootMustBeInsideTestState;
        break :blk try std.fs.path.join(allocator, &.{ real, "auth" });
    } else blk: {
        const home = (if (is_windows) init.environ_map.get("USERPROFILE") else init.environ_map.get("HOME")) orelse return error.UserHomeUnavailable;
        if (!std.fs.path.isAbsolute(home)) return error.UserHomeUnavailable;
        break :blk try std.fs.path.join(allocator, &.{ home, ".silex", "auth" });
    };
    _ = Io.Dir.cwd().createDirPathStatus(io, root, directory_permissions) catch |err| return storageError("directory creation", err);
    // Linux opens non-iterable directories with O_PATH, which cannot be fsynced.
    // Windows also needs enumeration to verify an absent credential when its
    // no-follow open returns an unexpected status.
    const dir = Io.Dir.cwd().openDir(io, root, .{ .follow_symlinks = false, .iterate = true }) catch |err| return storageError("directory open", err);
    defer dir.close(io);
    const dir_stat = dir.stat(io) catch |err| return storageError("directory metadata", err);
    try private(dir_stat, .directory);
    // Never truncate an existing lock or follow a pre-existing symbolic link.
    // The metadata check requires a readable Windows handle.
    const lock = dir.createFile(io, "registry.lock", .{ .exclusive = true, .read = true, .permissions = file_permissions }) catch |err| switch (err) {
        error.PathAlreadyExists => dir.openFile(io, "registry.lock", .{ .mode = .read_write, .follow_symlinks = false }) catch |open_err| return storageError("lock reopen", open_err),
        else => return storageError("lock creation", err),
    };
    defer lock.close(io);
    const lock_stat = lock.stat(io) catch |err| return storageError("lock metadata", err);
    try private(lock_stat, .file);
    const acquired = lock.tryLock(io, .exclusive) catch |err| return storageError("lock acquisition", err);
    if (!acquired) return error.RegistryLoginAlreadyRunning;
    defer lock.unlock(io);
    const client: Client = .{ .io = io, .allocator = allocator, .network_allocator = init.gpa, .origin = test_url orelse production_origin };
    const stored = load(dir, io, allocator) catch |err| return storageError("credential load", err);
    if (stored) |credential| {
        const response = try client.request(if (logout) .DELETE else .GET, "/v2/session", "Bearer", credential.token);
        if (logout) {
            try checkStatus(response.status);
            const revoked = try parse(struct { revoked: bool }, allocator, response.body());
            if (!revoked.revoked) return error.InvalidRegistryResponse;
        } else if (response.status != .unauthorized) {
            try checkStatus(response.status);
            const session = try parse(struct { github_id: []const u8, login: []const u8, expires_at: i64 }, allocator, response.body());
            if (!equal(session.github_id, credential.github_id) or !validIdentity(session.github_id, session.login)) return error.InvalidRegistryResponse;
            std.debug.print("silex: already connected as {s}; use 'silex logout' before changing accounts\n", .{session.login});
            return 0;
        }
        try dir.deleteFile(io, credential_name);
        try syncDirectory(dir, io);
    }
    if (logout) {
        std.debug.print("silex: disconnected from the registry\n", .{});
        return 0;
    }
    var random: [32]u8 = undefined;
    try io.randomSecure(&random);
    const ticket = std.fmt.bytesToHex(random, .lower);
    const started = Io.Clock.Timestamp.now(io, .boot).raw.toSeconds();
    var response = try client.request(.POST, "/v2/logins", "Login", &ticket);
    try checkStatus(response.status);
    var reply = try parse(Reply, allocator, response.body());
    if (!hex(reply.id, 32) or !equal(reply.state, "pending") or !equal(reply.verification_uri orelse "", verification_uri)) return error.InvalidRegistryResponse;
    const code = reply.user_code orelse return error.InvalidRegistryResponse;
    if (code.len != 9 or code[4] != '-') return error.InvalidRegistryResponse;
    for (code, 0..) |byte, index| if (index != 4 and !std.ascii.isUpper(byte) and !std.ascii.isDigit(byte)) return error.InvalidRegistryResponse;
    const id = reply.id;
    const poll_path = try std.fmt.allocPrint(allocator, "/v2/logins/{s}", .{id});
    std.debug.print("silex: open {s} and enter {s}\n", .{ verification_uri, code });
    std.debug.print("silex: authorize only the dedicated registry identity application (no repository permissions)\n", .{});
    if (!no_browser) openBrowser(init);
    while (true) {
        const retry = reply.retry_after orelse return error.InvalidRegistryResponse;
        if (retry < 1 or retry > 900) return error.InvalidRegistryResponse;
        const elapsed = Io.Clock.Timestamp.now(io, .boot).raw.toSeconds() - started;
        if (elapsed + retry >= 900) return error.RegistryLoginExpired;
        try io.sleep(.fromSeconds(retry), .boot);
        response = try client.request(.POST, poll_path, "Login", &ticket);
        try checkStatus(response.status);
        reply = try parse(Reply, allocator, response.body());
        if (!equal(id, reply.id)) return error.InvalidRegistryResponse;
        if (equal(reply.state, "pending") or equal(reply.state, "polling")) continue;
        if (equal(reply.state, "denied")) return error.RegistryLoginDenied;
        if (equal(reply.state, "expired")) return error.RegistryLoginExpired;
        if (equal(reply.state, "consumed") or equal(reply.state, "failed")) return error.RegistryLoginInterruptedStartAgain;
        if (!equal(reply.state, "authorized")) return error.InvalidRegistryResponse;
        const credential: Credential = .{ .token = reply.token orelse return error.InvalidRegistryResponse, .github_id = reply.github_id orelse return error.InvalidRegistryResponse, .login = reply.login orelse return error.InvalidRegistryResponse, .expires_at = reply.expires_at };
        try checkCredential(credential);
        const now = Io.Timestamp.now(io, .real).toSeconds();
        if (credential.expires_at <= now or credential.expires_at > now + 86460) return error.InvalidRegistryResponse;
        save(dir, io, allocator, credential) catch |err| {
            // Best effort: an unsaved access must not be printed or made recoverable by replay.
            _ = client.request(.DELETE, "/v2/session", "Bearer", credential.token) catch {};
            return err;
        };
        std.debug.print("silex: connected as {s}; registry access expires within 24 hours\n", .{credential.login});
        return 0;
    }
}

fn openBrowser(init: std.process.Init) void {
    if (is_windows) {
        if (!WindowsCredential.openBrowser()) std.debug.print("silex: open the URL above manually\n", .{});
        return;
    }
    const command = if (builtin.os.tag == .macos) "/usr/bin/open" else "xdg-open";
    const result = std.process.run(init.gpa, init.io, .{ .argv = &.{ command, verification_uri }, .stdout_limit = .limited(4096), .stderr_limit = .limited(4096), .timeout = .{ .duration = .{ .raw = .fromSeconds(5), .clock = .boot } } }) catch {
        std.debug.print("silex: browser unavailable; open the URL above manually\n", .{});
        return;
    };
    defer init.gpa.free(result.stdout);
    defer init.gpa.free(result.stderr);
    if (result.term != .exited or result.term.exited != 0) std.debug.print("silex: open the URL above manually\n", .{});
}

test "registry identity rejects injectable identifiers and non-loopback test origins" {
    _ = WindowsCredential;
    try std.testing.expect(validIdentity("1001", "a-renamed-user"));
    try std.testing.expect(!validIdentity("0", "user"));
    try std.testing.expect(!validIdentity("1001", "user\nsecret"));
    try std.testing.expect(testOrigin("http://127.0.0.1:1234"));
    for ([_][]const u8{ "https://example.com", "http://127.0.0.1:0", "http://127.0.0.1:1234/path", "http://127.0.0.1:1234@evil" }) |url|
        try std.testing.expect(!testOrigin(url));
}
