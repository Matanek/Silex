const std = @import("std");
const PackagePublish = @import("PackagePublish.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const oauth_client_id = "Ov23lioamW82wsfQn6kE";
const api_root = "https://api.github.com";
const upstream_owner = "Matanek";
const registry_name = "Silex-Registry";

pub const Result = struct {
    pull_request_url: []const u8,
};

const StoredAuthorization = struct {
    access_token: []const u8,
    refresh_token: ?[]const u8 = null,
};

const TokenResponse = struct {
    access_token: ?[]const u8 = null,
    refresh_token: ?[]const u8 = null,
    @"error": ?[]const u8 = null,
    error_description: ?[]const u8 = null,
};

const DeviceCode = struct {
    device_code: []const u8,
    user_code: []const u8,
    verification_uri: []const u8,
    expires_in: u32,
    interval: u32 = 5,
};

const User = struct { login: []const u8 };
const Repository = struct { default_branch: []const u8 = "main" };
const PullRequest = struct { html_url: []const u8 };

const Response = struct {
    status: std.http.Status,
    body: []const u8,
};

pub const Publisher = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    diagnostic: ?[]const u8 = null,

    pub fn init(allocator: Allocator, download_allocator: Allocator, io: Io) Publisher {
        return .{ .allocator = allocator, .download_allocator = download_allocator, .io = io };
    }

    pub fn submit(
        self: *Publisher,
        registry_root: []const u8,
        authorization_path: []const u8,
        prepared: PackagePublish.Result,
        environment: *const std.process.Environ.Map,
    ) !Result {
        self.diagnostic = null;
        const authorization = try self.authorize(authorization_path, environment);
        const user_response = try self.api(.GET, "/user", null, authorization.access_token);
        if (user_response.status != .ok) return self.failApi("GitHub rejected the publication authorization", user_response);
        const user = parse(User, self.allocator, user_response.body) catch
            return self.fail("GitHub returned an invalid user identity");

        const version = try versionText(self.allocator, prepared.version);
        const branch = try publicationBranch(self.allocator, prepared.name, version, prepared.sha256);
        if (try self.findOpenPullRequest(user.login, branch, authorization.access_token)) |url| {
            try self.removePreparedManifest(prepared.manifest_path);
            return .{ .pull_request_url = url };
        }

        const head_owner = if (std.mem.eql(u8, user.login, upstream_owner))
            user.login
        else blk: {
            try self.ensureFork(user.login, authorization.access_token);
            break :blk user.login;
        };
        const base_sha = try self.gitHead(registry_root);
        try self.ensureBranch(head_owner, branch, base_sha, authorization.access_token);

        const manifest = Io.Dir.cwd().readFileAlloc(
            self.io,
            prepared.manifest_path,
            self.allocator,
            .limited(1024 * 1024),
        ) catch |err| return self.failFmt("cannot read the prepared registry manifest: {t}", .{err});
        const relative_manifest = try relativeManifestPath(self.allocator, registry_root, prepared.manifest_path);
        if (!try self.manifestExistsOnBranch(head_owner, branch, relative_manifest, manifest, authorization.access_token)) {
            try self.putManifest(head_owner, branch, relative_manifest, manifest, prepared.name, version, authorization.access_token);
        }
        const url = try self.createPullRequest(user.login, branch, prepared.name, version, authorization.access_token);
        try self.removePreparedManifest(prepared.manifest_path);
        return .{ .pull_request_url = url };
    }

    fn authorize(
        self: *Publisher,
        authorization_path: []const u8,
        environment: *const std.process.Environ.Map,
    ) !StoredAuthorization {
        if (environment.get("SILEX_GITHUB_TOKEN")) |token| {
            return .{ .access_token = token };
        }
        if (self.readAuthorization(authorization_path)) |stored| {
            if (stored.refresh_token) |refresh_token| {
                if (self.refreshAuthorization(refresh_token)) |refreshed| {
                    try self.writeAuthorization(authorization_path, refreshed);
                    return refreshed;
                } else |_| {}
            }
            const validation = try self.api(.GET, "/user", null, stored.access_token);
            if (validation.status == .ok) return stored;
        } else |_| {}
        const authorized = try self.deviceAuthorization();
        try self.writeAuthorization(authorization_path, authorized);
        return authorized;
    }

    fn readAuthorization(self: *Publisher, path: []const u8) !StoredAuthorization {
        const source = try Io.Dir.cwd().readFileAlloc(self.io, path, self.allocator, .limited(64 * 1024));
        return parse(StoredAuthorization, self.allocator, source);
    }

    fn writeAuthorization(self: *Publisher, path: []const u8, authorization: StoredAuthorization) !void {
        if (std.fs.path.dirname(path)) |parent| try Io.Dir.cwd().createDirPath(self.io, parent);
        const source = try json(self.allocator, authorization);
        const file = try Io.Dir.cwd().createFile(self.io, path, .{ .truncate = true, .permissions = @enumFromInt(0o600) });
        defer file.close(self.io);
        try file.writeStreamingAll(self.io, source);
        try file.setPermissions(self.io, @enumFromInt(0o600));
    }

    fn refreshAuthorization(self: *Publisher, refresh_token: []const u8) !StoredAuthorization {
        const payload = try std.fmt.allocPrint(
            self.allocator,
            "client_id={s}&grant_type=refresh_token&refresh_token={s}",
            .{ oauth_client_id, refresh_token },
        );
        const response = try self.oauthRequest("https://github.com/login/oauth/access_token", payload);
        const token = try parse(TokenResponse, self.allocator, response.body);
        if (response.status != .ok or token.access_token == null) return error.AuthorizationRefreshFailed;
        return .{ .access_token = token.access_token.?, .refresh_token = token.refresh_token };
    }

    fn deviceAuthorization(self: *Publisher) !StoredAuthorization {
        const payload = try std.fmt.allocPrint(self.allocator, "client_id={s}&scope=public_repo", .{oauth_client_id});
        const response = try self.oauthRequest("https://github.com/login/device/code", payload);
        if (response.status != .ok) return self.failApi("cannot start GitHub authorization", response);
        const device = parse(DeviceCode, self.allocator, response.body) catch
            return self.fail("GitHub returned an invalid device authorization");
        std.debug.print(
            "silex: authorize publication at {s} with code {s}\n",
            .{ device.verification_uri, device.user_code },
        );

        var waited: u32 = 0;
        var interval = @max(device.interval, 1);
        while (waited < device.expires_in) {
            try Io.sleep(self.io, .fromSeconds(interval), .boot);
            waited += interval;
            const poll_payload = try std.fmt.allocPrint(
                self.allocator,
                "client_id={s}&device_code={s}&grant_type=urn:ietf:params:oauth:grant-type:device_code",
                .{ oauth_client_id, device.device_code },
            );
            const poll = try self.oauthRequest("https://github.com/login/oauth/access_token", poll_payload);
            const token = parse(TokenResponse, self.allocator, poll.body) catch
                return self.fail("GitHub returned an invalid authorization response");
            if (token.access_token) |access_token| {
                return .{ .access_token = access_token, .refresh_token = token.refresh_token };
            }
            const oauth_error = token.@"error" orelse return self.fail("GitHub authorization failed");
            if (std.mem.eql(u8, oauth_error, "authorization_pending")) continue;
            if (std.mem.eql(u8, oauth_error, "slow_down")) {
                interval += 5;
                continue;
            }
            return self.failFmt(
                "GitHub authorization failed: {s}",
                .{token.error_description orelse oauth_error},
            );
        }
        return self.fail("GitHub authorization expired before it was approved");
    }

    fn oauthRequest(self: *Publisher, url: []const u8, payload: []const u8) !Response {
        return self.request(.POST, url, payload, &.{
            .{ .name = "Accept", .value = "application/json" },
            .{ .name = "Content-Type", .value = "application/x-www-form-urlencoded" },
        });
    }

    fn api(self: *Publisher, method: std.http.Method, path: []const u8, payload: ?[]const u8, token: []const u8) !Response {
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ api_root, path });
        const authorization = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{token});
        return self.request(method, url, payload, &.{
            .{ .name = "Accept", .value = "application/vnd.github+json" },
            .{ .name = "Authorization", .value = authorization },
            .{ .name = "X-GitHub-Api-Version", .value = "2022-11-28" },
            .{ .name = "Content-Type", .value = "application/json" },
        });
    }

    fn request(
        self: *Publisher,
        method: std.http.Method,
        url: []const u8,
        payload: ?[]const u8,
        headers: []const std.http.Header,
    ) !Response {
        var client: std.http.Client = .{ .allocator = self.download_allocator, .io = self.io };
        defer client.deinit();
        var output: Io.Writer.Allocating = .init(self.download_allocator);
        defer output.deinit();
        const fetched = client.fetch(.{
            .location = .{ .url = url },
            .method = method,
            .payload = payload,
            .response_writer = &output.writer,
            .redirect_behavior = .unhandled,
            .headers = .{ .user_agent = .{ .override = "Silex package publisher" } },
            .extra_headers = headers,
        }) catch |err| return self.failFmt("cannot contact GitHub: {t}", .{err});
        return .{ .status = fetched.status, .body = try self.allocator.dupe(u8, output.written()) };
    }

    fn ensureFork(self: *Publisher, login: []const u8, token: []const u8) !void {
        const fork_path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}", .{ login, registry_name });
        var response = try self.api(.GET, fork_path, null, token);
        if (response.status == .ok) return;
        if (response.status != .not_found) return self.failApi("cannot inspect the registry fork", response);
        response = try self.api(.POST, "/repos/Matanek/Silex-Registry/forks", "{\"default_branch_only\":true}", token);
        if (response.status != .accepted and response.status != .ok) {
            return self.failApi("cannot create the registry fork", response);
        }
        var attempt: u8 = 0;
        while (attempt < 20) : (attempt += 1) {
            try Io.sleep(self.io, .fromSeconds(2), .boot);
            response = try self.api(.GET, fork_path, null, token);
            if (response.status == .ok) return;
            if (response.status != .not_found) return self.failApi("cannot inspect the registry fork", response);
        }
        return self.fail("GitHub is still preparing the registry fork; run publish again in a moment");
    }

    fn ensureBranch(self: *Publisher, owner: []const u8, branch: []const u8, sha: []const u8, token: []const u8) !void {
        const path = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/git/refs", .{ owner, registry_name });
        const payload = try json(self.allocator, .{
            .ref = try std.fmt.allocPrint(self.allocator, "refs/heads/{s}", .{branch}),
            .sha = sha,
        });
        const response = try self.api(.POST, path, payload, token);
        if (response.status == .created) return;
        if (response.status == .unprocessable_entity) {
            const existing = try std.fmt.allocPrint(
                self.allocator,
                "/repos/{s}/{s}/git/ref/heads/{s}",
                .{ owner, registry_name, branch },
            );
            const found = try self.api(.GET, existing, null, token);
            if (found.status == .ok) return;
        }
        return self.failApi("cannot create the registry publication branch", response);
    }

    fn putManifest(
        self: *Publisher,
        owner: []const u8,
        branch: []const u8,
        path: []const u8,
        manifest: []const u8,
        name: []const u8,
        version: []const u8,
        token: []const u8,
    ) !void {
        const encoded_length = std.base64.standard.Encoder.calcSize(manifest.len);
        const encoded = try self.allocator.alloc(u8, encoded_length);
        _ = std.base64.standard.Encoder.encode(encoded, manifest);
        const payload = try json(self.allocator, .{
            .message = try std.fmt.allocPrint(self.allocator, "Publish {s} {s}", .{ name, version }),
            .content = encoded,
            .branch = branch,
        });
        const endpoint = try std.fmt.allocPrint(self.allocator, "/repos/{s}/{s}/contents/{s}", .{ owner, registry_name, path });
        const response = try self.api(.PUT, endpoint, payload, token);
        if (response.status != .created) return self.failApi("cannot commit the registry manifest", response);
    }

    fn manifestExistsOnBranch(
        self: *Publisher,
        owner: []const u8,
        branch: []const u8,
        path: []const u8,
        expected: []const u8,
        token: []const u8,
    ) !bool {
        const endpoint = try std.fmt.allocPrint(
            self.allocator,
            "/repos/{s}/{s}/contents/{s}?ref={s}",
            .{ owner, registry_name, path, branch },
        );
        const response = try self.api(.GET, endpoint, null, token);
        if (response.status == .not_found) return false;
        if (response.status != .ok) return self.failApi("cannot inspect the registry publication branch", response);
        const Content = struct { content: []const u8 };
        const remote = parse(Content, self.allocator, response.body) catch
            return self.fail("GitHub returned invalid registry manifest data");
        const compact = try removeAsciiWhitespace(self.allocator, remote.content);
        const decoded_length = std.base64.standard.Decoder.calcSizeForSlice(compact) catch
            return self.fail("GitHub returned an invalid encoded registry manifest");
        const decoded = try self.allocator.alloc(u8, decoded_length);
        std.base64.standard.Decoder.decode(decoded, compact) catch
            return self.fail("GitHub returned an invalid encoded registry manifest");
        if (!std.mem.eql(u8, decoded, expected)) {
            return self.fail("the existing GitHub publication branch contains a different registry manifest");
        }
        return true;
    }

    fn findOpenPullRequest(self: *Publisher, login: []const u8, branch: []const u8, token: []const u8) !?[]const u8 {
        const path = try std.fmt.allocPrint(
            self.allocator,
            "/repos/{s}/{s}/pulls?state=open&base=main&head={s}%3A{s}",
            .{ upstream_owner, registry_name, login, branch },
        );
        const response = try self.api(.GET, path, null, token);
        if (response.status != .ok) return self.failApi("cannot inspect existing registry proposals", response);
        const pulls = parse([]const PullRequest, self.allocator, response.body) catch
            return self.fail("GitHub returned invalid pull request data");
        if (pulls.len == 0) return null;
        return pulls[0].html_url;
    }

    fn createPullRequest(
        self: *Publisher,
        login: []const u8,
        branch: []const u8,
        name: []const u8,
        version: []const u8,
        token: []const u8,
    ) ![]const u8 {
        const payload = try json(self.allocator, .{
            .title = try std.fmt.allocPrint(self.allocator, "Publish {s} {s}", .{ name, version }),
            .body = try std.fmt.allocPrint(self.allocator, "Automated package proposal created by `silex publish` for `{s}@{s}`.", .{ name, version }),
            .head = try std.fmt.allocPrint(self.allocator, "{s}:{s}", .{ login, branch }),
            .base = "main",
        });
        const response = try self.api(.POST, "/repos/Matanek/Silex-Registry/pulls", payload, token);
        if (response.status != .created) return self.failApi("cannot open the registry pull request", response);
        const pull = parse(PullRequest, self.allocator, response.body) catch
            return self.fail("GitHub returned invalid pull request data");
        return pull.html_url;
    }

    fn gitHead(self: *Publisher, root: []const u8) ![]const u8 {
        const result = std.process.run(self.download_allocator, self.io, .{
            .argv = &.{ "git", "-C", root, "rev-parse", "HEAD" },
            .stdout_limit = .limited(1024),
            .stderr_limit = .limited(64 * 1024),
        }) catch |err| return self.failFmt("cannot inspect the registry revision: {t}", .{err});
        defer self.download_allocator.free(result.stdout);
        defer self.download_allocator.free(result.stderr);
        if (result.term != .exited or result.term.exited != 0) {
            return self.fail("cannot inspect the registry revision");
        }
        return self.allocator.dupe(u8, std.mem.trim(u8, result.stdout, " \t\r\n"));
    }

    fn removePreparedManifest(self: *Publisher, path: []const u8) !void {
        Io.Dir.cwd().deleteFile(self.io, path) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return self.failFmt("the proposal was submitted but the local manifest could not be removed: {t}", .{err}),
        };
    }

    fn failApi(self: *Publisher, context: []const u8, response: Response) error{InvalidPublication} {
        const ApiError = struct { message: ?[]const u8 = null };
        const parsed = parse(ApiError, self.allocator, response.body) catch null;
        return self.failFmt("{s}: {s}", .{ context, if (parsed) |value| value.message orelse @tagName(response.status) else @tagName(response.status) });
    }

    fn fail(self: *Publisher, message: []const u8) error{InvalidPublication} {
        self.diagnostic = message;
        return error.InvalidPublication;
    }

    fn failFmt(self: *Publisher, comptime format: []const u8, arguments: anytype) error{InvalidPublication} {
        self.diagnostic = std.fmt.allocPrint(self.allocator, format, arguments) catch "publication failed";
        return error.InvalidPublication;
    }
};

fn parse(comptime T: type, allocator: Allocator, source: []const u8) !T {
    return std.json.parseFromSliceLeaky(T, allocator, source, .{ .ignore_unknown_fields = true });
}

fn json(allocator: Allocator, value: anytype) ![]const u8 {
    var output: Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try std.json.Stringify.value(value, .{}, &output.writer);
    return output.toOwnedSlice();
}

fn versionText(allocator: Allocator, version: @import("Packages.zig").Version) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
}

fn publicationBranch(allocator: Allocator, name: []const u8, version: []const u8, checksum: []const u8) ![]const u8 {
    const safe_name = try allocator.dupe(u8, name);
    defer allocator.free(safe_name);
    for (safe_name) |*character| character.* = if (std.ascii.isAlphanumeric(character.*)) std.ascii.toLower(character.*) else '-';
    return std.fmt.allocPrint(allocator, "silex-publish-{s}-{s}-{s}", .{ safe_name, version, checksum[0..@min(checksum.len, 12)] });
}

fn relativeManifestPath(allocator: Allocator, root: []const u8, path: []const u8) ![]const u8 {
    if (!std.mem.startsWith(u8, path, root)) return error.InvalidManifestPath;
    return allocator.dupe(u8, std.mem.trimStart(u8, path[root.len..], "/\\"));
}

fn removeAsciiWhitespace(allocator: Allocator, source: []const u8) ![]const u8 {
    const result = try allocator.alloc(u8, source.len);
    var length: usize = 0;
    for (source) |character| {
        if (std.ascii.isWhitespace(character)) continue;
        result[length] = character;
        length += 1;
    }
    return allocator.realloc(result, length);
}

test "derive one deterministic publication branch" {
    const branch = try publicationBranch(
        std.testing.allocator,
        "My GFX",
        "1.2.3",
        "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
    );
    defer std.testing.allocator.free(branch);
    try std.testing.expectEqualStrings("silex-publish-my-gfx-1.2.3-0123456789ab", branch);
}

test "derive the repository-relative manifest path" {
    const path = try relativeManifestPath(std.testing.allocator, "/tmp/registry", "/tmp/registry/registry/v1/packages/GFX/1.2.3.json");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("registry/v1/packages/GFX/1.2.3.json", path);
}

test "remove transport whitespace from GitHub base64" {
    const compact = try removeAsciiWhitespace(std.testing.allocator, "YWJj\nZGVm\r\n");
    defer std.testing.allocator.free(compact);
    try std.testing.expectEqualStrings("YWJjZGVm", compact);
}
