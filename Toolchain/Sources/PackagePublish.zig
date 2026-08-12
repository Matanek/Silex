const std = @import("std");
const Packages = @import("Packages.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Result = struct {
    name: []const u8,
    version: Packages.Version,
    manifest_path: []const u8,
    archive_url: []const u8,
    sha256: []const u8,
};

pub const Publisher = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    diagnostic: ?[]const u8 = null,

    pub fn init(allocator: Allocator, download_allocator: Allocator, io: Io) Publisher {
        return .{
            .allocator = allocator,
            .download_allocator = download_allocator,
            .io = io,
        };
    }

    pub fn prepare(self: *Publisher, package_root: []const u8, registry_root: []const u8) !Result {
        self.diagnostic = null;
        const status = Io.Dir.cwd().statFile(self.io, package_root, .{}) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return self.failFmt("cannot locate package directory '{s}'", .{package_root}),
            else => return err,
        };
        if (status.kind != .directory) return self.failFmt("package source '{s}' is not a directory", .{package_root});

        var resolver = Packages.Resolver.init(self.allocator, self.io, null);
        const package = resolver.inspectPackage(package_root) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.failFmt(
                "cannot publish package: {s}",
                .{resolver.diagnostic orelse "invalid package"},
            ),
            else => return err,
        };
        if (!std.mem.eql(u8, std.fs.path.basename(package_root), package.name)) {
            return self.fail("local package folder and manifest name differ");
        }

        const version_text = try versionText(self.allocator, package.version);
        try self.validateRegistryRoot(registry_root);
        const package_directory = try std.fs.path.join(self.allocator, &.{ registry_root, "registry", "v1", "packages", package.name });
        const manifest_path = try std.fs.path.join(self.allocator, &.{ package_directory, try std.fmt.allocPrint(self.allocator, "{s}.json", .{version_text}) });
        if (try pathExists(self.io, manifest_path)) {
            return self.failFmt("package '{s}@{s}' is already proposed in this registry checkout", .{ package.name, version_text });
        }

        try self.validateRepositoryState(package_root, version_text);
        const remote = try self.git(package_root, &.{ "remote", "get-url", "origin" });
        const repository = repositoryFromRemote(self.allocator, std.mem.trim(u8, remote, " \t\r\n")) catch
            return self.fail("package origin must identify a GitHub repository");
        const archive_name = try std.fmt.allocPrint(self.allocator, "{s}-{s}.tar.gz", .{ package.name, version_text });
        const archive_url = try std.fmt.allocPrint(
            self.allocator,
            "https://github.com/{s}/releases/download/v{s}/{s}",
            .{ repository, version_text, archive_name },
        );
        const checksum_url = try std.fmt.allocPrint(self.allocator, "{s}.sha256", .{archive_url});
        const checksum_source = try self.fetch(checksum_url, "release checksum", 4096);
        const checksum = parseChecksum(self.allocator, checksum_source, archive_name) catch
            return self.fail("published release checksum is invalid or names another archive");
        try self.verifyPublishedArchive(archive_url, checksum);

        const manifest = try renderManifest(
            self.allocator,
            package.name,
            version_text,
            package.silex_requirement.text,
            archive_url,
            checksum,
        );
        Io.Dir.cwd().createDirPath(self.io, package_directory) catch |err| {
            return self.failFmt("cannot create registry package directory: {t}", .{err});
        };
        const temporary = try std.fmt.allocPrint(self.allocator, "{s}.silex-publish", .{manifest_path});
        Io.Dir.cwd().deleteFile(self.io, temporary) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return self.failFmt("cannot prepare registry manifest: {t}", .{err}),
        };
        var keep_temporary = true;
        defer if (keep_temporary) Io.Dir.cwd().deleteFile(self.io, temporary) catch {};
        const file = Io.Dir.cwd().createFile(self.io, temporary, .{ .exclusive = true }) catch |err|
            return self.failFmt("cannot create registry manifest: {t}", .{err});
        file.writeStreamingAll(self.io, manifest) catch |err| {
            file.close(self.io);
            return self.failFmt("cannot write registry manifest: {t}", .{err});
        };
        file.close(self.io);
        Io.Dir.cwd().rename(temporary, Io.Dir.cwd(), manifest_path, self.io) catch |err|
            return self.failFmt("cannot publish registry manifest: {t}", .{err});
        keep_temporary = false;

        return .{
            .name = package.name,
            .version = package.version,
            .manifest_path = manifest_path,
            .archive_url = archive_url,
            .sha256 = checksum,
        };
    }

    fn validateRepositoryState(self: *Publisher, package_root: []const u8, version: []const u8) !void {
        const changes = try self.git(package_root, &.{ "status", "--porcelain" });
        if (std.mem.trim(u8, changes, " \t\r\n").len != 0) {
            return self.fail("package repository has uncommitted changes");
        }
        const tags = try self.git(package_root, &.{ "tag", "--points-at", "HEAD" });
        const expected = try std.fmt.allocPrint(self.allocator, "v{s}", .{version});
        var lines = std.mem.tokenizeAny(u8, tags, "\r\n");
        while (lines.next()) |tag| if (std.mem.eql(u8, tag, expected)) return;
        return self.failFmt("package HEAD is not tagged '{s}'", .{expected});
    }

    fn validateRegistryRoot(self: *Publisher, registry_root: []const u8) !void {
        const index = try std.fs.path.join(self.allocator, &.{ registry_root, "registry", "v1", "index.json" });
        const checker = try std.fs.path.join(self.allocator, &.{ registry_root, "scripts", "build-registry.mjs" });
        if (!try pathExists(self.io, index) or !try pathExists(self.io, checker)) {
            return self.failFmt(
                "'{s}' is not a Silex-Registry source checkout; set SILEX_REGISTRY_SOURCE to its path",
                .{registry_root},
            );
        }
    }

    fn git(self: *Publisher, package_root: []const u8, arguments: []const []const u8) ![]const u8 {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(self.allocator, &.{ "git", "-C", package_root });
        try argv.appendSlice(self.allocator, arguments);
        const result = std.process.run(self.download_allocator, self.io, .{
            .argv = argv.items,
            .stdout_limit = .limited(1024 * 1024),
            .stderr_limit = .limited(1024 * 1024),
        }) catch |err| return self.failFmt("cannot inspect package repository: {t}", .{err});
        defer self.download_allocator.free(result.stdout);
        defer self.download_allocator.free(result.stderr);
        const success = switch (result.term) {
            .exited => |code| code == 0,
            else => false,
        };
        if (!success) {
            const detail = std.mem.trim(u8, result.stderr, " \t\r\n");
            return self.failFmt("cannot inspect package repository: {s}", .{if (detail.len == 0) "git failed" else detail});
        }
        return self.allocator.dupe(u8, result.stdout);
    }

    fn verifyPublishedArchive(self: *Publisher, url: []const u8, checksum: []const u8) !void {
        var buffer: [64 * 1024]u8 = undefined;
        var hashing: Io.Writer.Hashing(std.crypto.hash.sha2.Sha256) = .init(&buffer);
        var http: std.http.Client = .{ .allocator = self.download_allocator, .io = self.io };
        defer http.deinit();
        const response = http.fetch(.{
            .location = .{ .url = url },
            .response_writer = &hashing.writer,
            .headers = .{ .user_agent = .{ .override = "Silex package publisher" } },
        }) catch |err| return self.failFmt("cannot inspect published package archive: {t}", .{err});
        if (response.status.class() != .success) {
            return self.failFmt("published package archive is unavailable: HTTP {d}", .{@intFromEnum(response.status)});
        }
        hashing.hasher.update(hashing.writer.buffered());
        var actual: [32]u8 = undefined;
        hashing.hasher.final(&actual);
        var expected: [32]u8 = undefined;
        _ = std.fmt.hexToBytes(&expected, checksum) catch return self.fail("published release checksum is invalid");
        if (!std.mem.eql(u8, &actual, &expected)) {
            return self.fail("published package archive does not match its SHA-256 checksum");
        }
    }

    fn fetch(self: *Publisher, url: []const u8, label: []const u8, limit: usize) ![]const u8 {
        var output: Io.Writer.Allocating = .init(self.download_allocator);
        defer output.deinit();
        var http: std.http.Client = .{ .allocator = self.download_allocator, .io = self.io };
        defer http.deinit();
        const response = http.fetch(.{
            .location = .{ .url = url },
            .response_writer = &output.writer,
            .headers = .{ .user_agent = .{ .override = "Silex package publisher" } },
        }) catch |err| return self.failFmt("cannot download {s}: {t}", .{ label, err });
        if (response.status.class() != .success) {
            return self.failFmt("cannot download {s}: HTTP {d}", .{ label, @intFromEnum(response.status) });
        }
        if (output.written().len > limit) return self.failFmt("{s} exceeds {d} bytes", .{ label, limit });
        return self.allocator.dupe(u8, output.written());
    }

    fn fail(self: *Publisher, message: []const u8) error{InvalidPublication} {
        self.diagnostic = message;
        return error.InvalidPublication;
    }

    fn failFmt(self: *Publisher, comptime format: []const u8, arguments: anytype) error{ OutOfMemory, InvalidPublication } {
        self.diagnostic = try std.fmt.allocPrint(self.allocator, format, arguments);
        return error.InvalidPublication;
    }
};

fn repositoryFromRemote(allocator: Allocator, remote: []const u8) ![]const u8 {
    const path = if (std.mem.startsWith(u8, remote, "git@github.com:"))
        remote["git@github.com:".len..]
    else if (std.mem.startsWith(u8, remote, "https://github.com/"))
        remote["https://github.com/".len..]
    else if (std.mem.startsWith(u8, remote, "ssh://git@github.com/"))
        remote["ssh://git@github.com/".len..]
    else
        return error.InvalidRemote;
    const repository = if (std.mem.endsWith(u8, path, ".git")) path[0 .. path.len - 4] else path;
    const slash = std.mem.indexOfScalar(u8, repository, '/') orelse return error.InvalidRemote;
    if (slash == 0 or slash + 1 == repository.len or std.mem.indexOfScalarPos(u8, repository, slash + 1, '/') != null) {
        return error.InvalidRemote;
    }
    return allocator.dupe(u8, repository);
}

fn parseChecksum(allocator: Allocator, source: []const u8, expected_archive: []const u8) ![]const u8 {
    var fields = std.mem.tokenizeAny(u8, source, " \t\r\n");
    const checksum = fields.next() orelse return error.InvalidChecksum;
    const archive = fields.next() orelse return error.InvalidChecksum;
    if (fields.next() != null or checksum.len != 64) return error.InvalidChecksum;
    for (checksum) |character| if (!std.ascii.isDigit(character) and !(character >= 'a' and character <= 'f')) {
        return error.InvalidChecksum;
    };
    const normalized_archive = std.mem.trimStart(u8, archive, "*");
    if (!std.mem.eql(u8, normalized_archive, expected_archive)) return error.InvalidChecksum;
    return allocator.dupe(u8, checksum);
}

fn renderManifest(
    allocator: Allocator,
    name: []const u8,
    version: []const u8,
    requirement: []const u8,
    archive_url: []const u8,
    checksum: []const u8,
) ![]const u8 {
    const Manifest = struct {
        schema: u8 = 1,
        name: []const u8,
        version: []const u8,
        requires: struct { silex: []const u8 },
        archive: struct { url: []const u8, sha256: []const u8 },
    };
    var output: Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    try std.json.Stringify.value(Manifest{
        .name = name,
        .version = version,
        .requires = .{ .silex = requirement },
        .archive = .{ .url = archive_url, .sha256 = checksum },
    }, .{ .whitespace = .indent_2 }, &output.writer);
    try output.writer.writeByte('\n');
    return output.toOwnedSlice();
}

fn versionText(allocator: Allocator, version: Packages.Version) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
}

fn pathExists(io: Io, path: []const u8) !bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => return err,
    };
    return true;
}

test "derive one GitHub repository identity from common origin forms" {
    const allocator = std.testing.allocator;
    const ssh = try repositoryFromRemote(allocator, "git@github.com:Matanek/Silex-Lib-GFX.git");
    defer allocator.free(ssh);
    try std.testing.expectEqualStrings("Matanek/Silex-Lib-GFX", ssh);
    const https = try repositoryFromRemote(allocator, "https://github.com/Matanek/Silex-Lib-GFX.git");
    defer allocator.free(https);
    try std.testing.expectEqualStrings("Matanek/Silex-Lib-GFX", https);
    try std.testing.expectError(error.InvalidRemote, repositoryFromRemote(allocator, "https://example.test/Package.git"));
}

test "accept the release workflow checksum format and reject another archive" {
    const allocator = std.testing.allocator;
    const digest = "1b046fea163a89446a434a22026cad37c75e5b525394dd112f787d68b4a343df";
    const parsed = try parseChecksum(allocator, digest ++ "  GFX-0.24.0.tar.gz\n", "GFX-0.24.0.tar.gz");
    defer allocator.free(parsed);
    try std.testing.expectEqualStrings(digest, parsed);
    try std.testing.expectError(
        error.InvalidChecksum,
        parseChecksum(allocator, digest ++ "  STD-0.24.0.tar.gz\n", "GFX-0.24.0.tar.gz"),
    );
}

test "render the immutable registry manifest" {
    const allocator = std.testing.allocator;
    const digest = "1b046fea163a89446a434a22026cad37c75e5b525394dd112f787d68b4a343df";
    const rendered = try renderManifest(
        allocator,
        "GFX",
        "0.24.0",
        ">=0.38.0",
        "https://github.com/Matanek/Silex-Lib-GFX/releases/download/v0.24.0/GFX-0.24.0.tar.gz",
        digest,
    );
    defer allocator.free(rendered);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, rendered, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("GFX", parsed.value.object.get("name").?.string);
    try std.testing.expectEqualStrings(digest, parsed.value.object.get("archive").?.object.get("sha256").?.string);
    try std.testing.expect(std.mem.endsWith(u8, rendered, "\n"));
}
