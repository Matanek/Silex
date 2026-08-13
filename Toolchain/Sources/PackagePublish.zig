const std = @import("std");
const Packages = @import("Packages.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const default_registry_repository = "https://github.com/Matanek/Silex-Registry.git";

pub const Result = struct {
    name: []const u8,
    version: Packages.Version,
    manifest_path: []const u8,
    archive_url: []const u8,
    sha256: []const u8,
};

pub const ReleaseResult = struct {
    name: []const u8,
    version: Packages.Version,
    url: []const u8,
    created: bool,
};

pub const Publisher = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    diagnostic: ?[]const u8 = null,
    registry_repository: []const u8 = default_registry_repository,

    pub fn init(allocator: Allocator, download_allocator: Allocator, io: Io) Publisher {
        return .{
            .allocator = allocator,
            .download_allocator = download_allocator,
            .io = io,
        };
    }

    pub fn release(self: *Publisher, package_root: []const u8) !ReleaseResult {
        self.diagnostic = null;
        const absolute_package_root = Io.Dir.cwd().realPathFileAlloc(self.io, package_root, self.allocator) catch |err|
            return self.failFmt("cannot locate package directory '{s}': {t}", .{ package_root, err });
        const package = try self.inspectPackage(absolute_package_root);
        const version_text = try versionText(self.allocator, package.version);
        try self.validateRepositoryState(absolute_package_root, version_text);
        const remote = try self.git(absolute_package_root, &.{ "remote", "get-url", "origin" });
        const repository = repositoryFromRemote(self.allocator, std.mem.trim(u8, remote, " \t\r\n")) catch
            return self.fail("package origin must identify a GitHub repository");
        const archive_name = try std.fmt.allocPrint(self.allocator, "{s}-{s}.tar.gz", .{ package.name, version_text });
        const tag = try std.fmt.allocPrint(self.allocator, "v{s}", .{version_text});
        const legacy_release_url = try std.fmt.allocPrint(self.allocator, "https://github.com/{s}/releases/tag/{s}", .{ repository, tag });
        const legacy_archive_url = try std.fmt.allocPrint(
            self.allocator,
            "https://github.com/{s}/releases/download/{s}/{s}",
            .{ repository, tag, archive_name },
        );

        const release_ref = try releaseRef(self.allocator, tag);
        if (try self.remoteRefCommit(absolute_package_root, release_ref)) |commit| {
            const archive_url = try gitReleaseArchiveUrl(self.allocator, repository, commit, archive_name);
            _ = try self.publishedChecksum(archive_url, archive_name);
            return .{
                .name = package.name,
                .version = package.version,
                .url = try gitReleaseViewUrl(self.allocator, repository, commit),
                .created = false,
            };
        }
        if (try self.publishedChecksumOptional(legacy_archive_url, archive_name)) |_| {
            return .{ .name = package.name, .version = package.version, .url = legacy_release_url, .created = false };
        }

        const temporary_name = try std.fmt.allocPrint(self.allocator, ".silex-release-{s}-{s}", .{ package.name, version_text });
        const temporary_root = try std.fs.path.join(self.allocator, &.{ absolute_package_root, temporary_name });
        if (try pathExists(self.io, temporary_root)) {
            return self.failFmt("temporary release directory already exists: '{s}'", .{temporary_root});
        }
        Io.Dir.cwd().createDirPath(self.io, temporary_root) catch |err|
            return self.failFmt("cannot create temporary release directory: {t}", .{err});
        defer Io.Dir.cwd().deleteTree(self.io, temporary_root) catch {};

        const commit = try self.publishGitRelease(
            absolute_package_root,
            std.mem.trim(u8, remote, " \t\r\n"),
            temporary_root,
            package.name,
            version_text,
            archive_name,
            release_ref,
        );
        const archive_url = try gitReleaseArchiveUrl(self.allocator, repository, commit, archive_name);
        _ = try self.publishedChecksum(archive_url, archive_name);
        return .{
            .name = package.name,
            .version = package.version,
            .url = try gitReleaseViewUrl(self.allocator, repository, commit),
            .created = true,
        };
    }

    pub fn prepareManaged(self: *Publisher, package_root: []const u8, registry_root: []const u8) !Result {
        const package = try self.inspectPackage(package_root);
        const version_text = try versionText(self.allocator, package.version);
        const resumable_manifest = try std.fs.path.join(self.allocator, &.{
            "registry",                                                          "v1", "packages", package.name,
            try std.fmt.allocPrint(self.allocator, "{s}.json", .{version_text}),
        });
        try self.ensureRegistryCheckout(registry_root, resumable_manifest);
        return self.prepare(package_root, registry_root);
    }

    pub fn prepare(self: *Publisher, package_root: []const u8, registry_root: []const u8) !Result {
        self.diagnostic = null;
        const package = try self.inspectPackage(package_root);

        const version_text = try versionText(self.allocator, package.version);
        try self.validateRegistryRoot(registry_root);
        const package_directory = try std.fs.path.join(self.allocator, &.{ registry_root, "registry", "v1", "packages", package.name });
        const manifest_path = try std.fs.path.join(self.allocator, &.{ package_directory, try std.fmt.allocPrint(self.allocator, "{s}.json", .{version_text}) });
        try self.validateRepositoryState(package_root, version_text);
        const remote = try self.git(package_root, &.{ "remote", "get-url", "origin" });
        const repository = repositoryFromRemote(self.allocator, std.mem.trim(u8, remote, " \t\r\n")) catch
            return self.fail("package origin must identify a GitHub repository");
        const archive_name = try std.fmt.allocPrint(self.allocator, "{s}-{s}.tar.gz", .{ package.name, version_text });
        const published = try self.resolvePublishedArchive(package_root, repository, version_text, archive_name);
        const archive_url = published.url;
        const checksum = published.checksum;

        const manifest = try renderManifest(
            self.allocator,
            package.name,
            version_text,
            package.silex_requirement.text,
            repository,
            package.extensions,
            archive_url,
            checksum,
        );
        if (try pathExists(self.io, manifest_path)) {
            const existing = Io.Dir.cwd().readFileAlloc(self.io, manifest_path, self.allocator, .limited(1024 * 1024)) catch |err|
                return self.failFmt("cannot inspect the existing registry manifest: {t}", .{err});
            if (!std.mem.eql(u8, existing, manifest)) {
                return self.failFmt("package '{s}@{s}' is already proposed with different contents", .{ package.name, version_text });
            }
            return .{
                .name = package.name,
                .version = package.version,
                .manifest_path = manifest_path,
                .archive_url = archive_url,
                .sha256 = checksum,
            };
        }
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

    fn inspectPackage(self: *Publisher, package_root: []const u8) !Packages.ManifestInfo {
        const status = Io.Dir.cwd().statFile(self.io, package_root, .{}) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => return self.failFmt("cannot locate package directory '{s}'", .{package_root}),
            else => return err,
        };
        if (status.kind != .directory) return self.failFmt("package source '{s}' is not a directory", .{package_root});
        var resolver = Packages.Resolver.init(self.allocator, self.io, null);
        const package = resolver.inspectPackage(package_root) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.fail(resolver.diagnostic orelse "invalid package"),
            else => return err,
        };
        if (!std.mem.eql(u8, std.fs.path.basename(package_root), package.name)) {
            return self.fail("local package folder and manifest name differ");
        }
        return package;
    }

    fn validateRepositoryState(self: *Publisher, package_root: []const u8, version: []const u8) !void {
        const changes = try self.git(package_root, &.{ "status", "--porcelain" });
        if (std.mem.trim(u8, changes, " \t\r\n").len != 0) {
            return self.fail("package repository has uncommitted changes");
        }
        const tags = try self.git(package_root, &.{ "tag", "--points-at", "HEAD" });
        const expected = try std.fmt.allocPrint(self.allocator, "v{s}", .{version});
        var lines = std.mem.tokenizeAny(u8, tags, "\r\n");
        var tagged = false;
        while (lines.next()) |tag| if (std.mem.eql(u8, tag, expected)) {
            tagged = true;
            break;
        };
        if (!tagged) return self.failFmt("package HEAD is not tagged '{s}'", .{expected});

        const head = std.mem.trim(u8, try self.git(package_root, &.{ "rev-parse", "HEAD" }), " \t\r\n");
        const tag_ref = try std.fmt.allocPrint(self.allocator, "refs/tags/{s}", .{expected});
        const peeled_ref = try std.fmt.allocPrint(self.allocator, "{s}^{{}}", .{tag_ref});
        const remote = try self.git(package_root, &.{ "ls-remote", "--tags", "origin", tag_ref, peeled_ref });
        var remote_lines = std.mem.tokenizeAny(u8, remote, "\r\n");
        var remote_commit: ?[]const u8 = null;
        while (remote_lines.next()) |line| {
            const separator = std.mem.indexOfAny(u8, line, " \t") orelse continue;
            const commit = line[0..separator];
            const reference = std.mem.trim(u8, line[separator..], " \t");
            if (std.mem.eql(u8, reference, peeled_ref) or remote_commit == null) remote_commit = commit;
        }
        if (remote_commit == null) return self.failFmt("package tag '{s}' has not been pushed to origin", .{expected});
        if (!std.mem.eql(u8, remote_commit.?, head)) {
            return self.failFmt("package tag '{s}' on origin does not identify HEAD", .{expected});
        }
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

    fn ensureRegistryCheckout(self: *Publisher, registry_root: []const u8, resumable_manifest: ?[]const u8) !void {
        if (!try pathExists(self.io, registry_root)) {
            if (std.fs.path.dirname(registry_root)) |parent| {
                Io.Dir.cwd().createDirPath(self.io, parent) catch |err|
                    return self.failFmt("cannot create the global Silex directory: {t}", .{err});
            }
            _ = try self.run(&.{
                "git",                    "clone",       "--quiet", "--origin", "origin", "--branch", "main", "--single-branch",
                self.registry_repository, registry_root,
            }, "cannot clone the Silex registry");
        }
        try self.validateRegistryRoot(registry_root);
        const changes = try self.runGit(registry_root, &.{ "status", "--porcelain", "--untracked-files=all" }, "cannot inspect the global registry checkout");
        if (!changesAreResumable(changes, resumable_manifest)) {
            return self.failFmt(
                "the global registry checkout has unpublished changes in '{s}'; review or commit them before publishing another package",
                .{registry_root},
            );
        }
        _ = try self.runGit(registry_root, &.{ "switch", "--quiet", "main" }, "cannot select the registry main branch");
        _ = try self.runGit(
            registry_root,
            &.{ "pull", "--quiet", "--ff-only", "origin", "main" },
            "cannot fast-forward the global registry checkout before preparing the publication",
        );
    }

    fn publishGitRelease(
        self: *Publisher,
        package_root: []const u8,
        remote: []const u8,
        temporary_root: []const u8,
        package_name: []const u8,
        version: []const u8,
        archive_name: []const u8,
        release_ref: []const u8,
    ) ![]const u8 {
        const release_root = try std.fs.path.join(self.allocator, &.{ temporary_root, "release" });
        try Io.Dir.cwd().createDirPath(self.io, release_root);
        const archive_path = try std.fs.path.join(self.allocator, &.{ release_root, archive_name });
        const prefix = try std.fmt.allocPrint(self.allocator, "{s}-{s}/", .{ package_name, version });
        _ = try self.git(package_root, &.{
            "archive",                                                         "--format=tar.gz",
            try std.fmt.allocPrint(self.allocator, "--prefix={s}", .{prefix}), try std.fmt.allocPrint(self.allocator, "--output={s}", .{archive_path}),
            "HEAD",
        });

        const digest = sha256File(self.io, archive_path) catch |err|
            return self.failFmt("cannot hash package archive: {t}", .{err});
        const checksum = std.fmt.bytesToHex(digest, .lower);
        const checksum_path = try std.fmt.allocPrint(self.allocator, "{s}.sha256", .{archive_path});
        const checksum_source = try std.fmt.allocPrint(self.allocator, "{s}  {s}\n", .{ checksum, archive_name });
        const checksum_file = Io.Dir.cwd().createFile(self.io, checksum_path, .{ .exclusive = true }) catch |err|
            return self.failFmt("cannot create release checksum: {t}", .{err});
        checksum_file.writeStreamingAll(self.io, checksum_source) catch |err| {
            checksum_file.close(self.io);
            return self.failFmt("cannot write release checksum: {t}", .{err});
        };
        checksum_file.close(self.io);

        _ = try self.runGit(release_root, &.{ "init", "--quiet" }, "cannot initialize the package release");
        _ = try self.runGit(release_root, &.{ "add", archive_name, std.fs.path.basename(checksum_path) }, "cannot stage the package release");
        _ = try self.runGit(release_root, &.{
            "-c",     "user.name=Silex",
            "-c",     "user.email=releases@silex-lang.org",
            "commit", "--quiet",
            "-m",     try std.fmt.allocPrint(self.allocator, "Release {s}@{s}", .{ package_name, version }),
        }, "cannot commit the package release");
        _ = try self.runGit(release_root, &.{ "remote", "add", "origin", remote }, "cannot configure the package release remote");
        _ = try self.runGit(release_root, &.{ "push", "origin", try std.fmt.allocPrint(self.allocator, "HEAD:{s}", .{release_ref}) }, "cannot push the package release");
        const commit = std.mem.trim(u8, try self.runGit(release_root, &.{ "rev-parse", "HEAD" }, "cannot identify the package release"), " \t\r\n");
        return self.allocator.dupe(u8, commit);
    }

    fn resolvePublishedArchive(
        self: *Publisher,
        package_root: []const u8,
        repository: []const u8,
        version: []const u8,
        archive_name: []const u8,
    ) !struct { url: []const u8, checksum: []const u8 } {
        const tag = try std.fmt.allocPrint(self.allocator, "v{s}", .{version});
        if (try self.remoteRefCommit(package_root, try releaseRef(self.allocator, tag))) |commit| {
            const url = try gitReleaseArchiveUrl(self.allocator, repository, commit, archive_name);
            return .{ .url = url, .checksum = try self.publishedChecksum(url, archive_name) };
        }
        const legacy = try std.fmt.allocPrint(
            self.allocator,
            "https://github.com/{s}/releases/download/{s}/{s}",
            .{ repository, tag, archive_name },
        );
        if (try self.publishedChecksumOptional(legacy, archive_name)) |checksum| {
            return .{ .url = legacy, .checksum = checksum };
        }
        return self.failFmt("package release '{s}' is unavailable; run 'silex release {s}' first", .{ tag, package_root });
    }

    fn remoteRefCommit(self: *Publisher, repository_root: []const u8, ref: []const u8) !?[]const u8 {
        const output = try self.runGit(repository_root, &.{ "ls-remote", "--refs", "origin", ref }, "cannot inspect the package remote");
        const trimmed = std.mem.trim(u8, output, " \t\r\n");
        if (trimmed.len == 0) return null;
        const separator = std.mem.indexOfAny(u8, trimmed, " \t") orelse
            return self.fail("package remote returned an invalid release reference");
        const commit = trimmed[0..separator];
        if (!isObjectId(commit)) return self.fail("package remote returned an invalid release commit");
        const copy = try self.allocator.dupe(u8, commit);
        return copy;
    }

    fn git(self: *Publisher, package_root: []const u8, arguments: []const []const u8) ![]const u8 {
        return self.runGit(package_root, arguments, "cannot inspect package repository");
    }

    fn runGit(self: *Publisher, root: []const u8, arguments: []const []const u8, context: []const u8) ![]const u8 {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(self.allocator, &.{ "git", "-C", root });
        try argv.appendSlice(self.allocator, arguments);
        return self.run(argv.items, context);
    }

    fn run(self: *Publisher, arguments: []const []const u8, context: []const u8) ![]const u8 {
        const result = std.process.run(self.download_allocator, self.io, .{
            .argv = arguments,
            .stdout_limit = .limited(1024 * 1024),
            .stderr_limit = .limited(1024 * 1024),
        }) catch |err| return self.failFmt("{s}: {t}", .{ context, err });
        defer self.download_allocator.free(result.stdout);
        defer self.download_allocator.free(result.stderr);
        const success = switch (result.term) {
            .exited => |code| code == 0,
            else => false,
        };
        if (!success) {
            const detail = std.mem.trim(u8, result.stderr, " \t\r\n");
            return self.failFmt("{s}: {s}", .{ context, if (detail.len == 0) "git failed" else detail });
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

    fn publishedChecksum(self: *Publisher, archive_url: []const u8, archive_name: []const u8) ![]const u8 {
        return (try self.publishedChecksumOptional(archive_url, archive_name)) orelse
            return self.fail("published release checksum is unavailable");
    }

    fn publishedChecksumOptional(self: *Publisher, archive_url: []const u8, archive_name: []const u8) !?[]const u8 {
        const checksum_url = try std.fmt.allocPrint(self.allocator, "{s}.sha256", .{archive_url});
        const checksum_source = (try self.fetchOptional(checksum_url, "release checksum", 4096)) orelse return null;
        const checksum = parseChecksum(self.allocator, checksum_source, archive_name) catch
            return self.fail("published release checksum is invalid or names another archive");
        try self.verifyPublishedArchive(archive_url, checksum);
        return checksum;
    }

    fn fetch(self: *Publisher, url: []const u8, label: []const u8, limit: usize) ![]const u8 {
        return (try self.fetchOptional(url, label, limit)) orelse
            return self.failFmt("cannot download {s}: HTTP 404", .{label});
    }

    fn fetchOptional(self: *Publisher, url: []const u8, label: []const u8, limit: usize) !?[]const u8 {
        var output: Io.Writer.Allocating = .init(self.download_allocator);
        defer output.deinit();
        var http: std.http.Client = .{ .allocator = self.download_allocator, .io = self.io };
        defer http.deinit();
        const response = http.fetch(.{
            .location = .{ .url = url },
            .response_writer = &output.writer,
            .headers = .{ .user_agent = .{ .override = "Silex package publisher" } },
        }) catch |err| return self.failFmt("cannot download {s}: {t}", .{ label, err });
        if (response.status == .not_found) return null;
        if (response.status.class() != .success) {
            return self.failFmt("cannot download {s}: HTTP {d}", .{ label, @intFromEnum(response.status) });
        }
        if (output.written().len > limit) return self.failFmt("{s} exceeds {d} bytes", .{ label, limit });
        const copy = try self.allocator.dupe(u8, output.written());
        return copy;
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
    repository: []const u8,
    extensions: []const []const u8,
    archive_url: []const u8,
    checksum: []const u8,
) ![]const u8 {
    const Manifest = struct {
        schema: u8 = 1,
        name: []const u8,
        version: []const u8,
        requires: struct { silex: []const u8 },
        repository: []const u8,
        extensions: []const []const u8,
        archive: struct { url: []const u8, sha256: []const u8 },
    };
    var output: Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    try std.json.Stringify.value(Manifest{
        .name = name,
        .version = version,
        .requires = .{ .silex = requirement },
        .repository = repository,
        .extensions = extensions,
        .archive = .{ .url = archive_url, .sha256 = checksum },
    }, .{ .whitespace = .indent_2 }, &output.writer);
    try output.writer.writeByte('\n');
    return output.toOwnedSlice();
}

fn versionText(allocator: Allocator, version: Packages.Version) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
}

fn releaseRef(allocator: Allocator, tag: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "refs/heads/silex/releases/{s}", .{tag});
}

fn gitReleaseArchiveUrl(allocator: Allocator, repository: []const u8, commit: []const u8, archive_name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "https://raw.githubusercontent.com/{s}/{s}/{s}",
        .{ repository, commit, archive_name },
    );
}

fn gitReleaseViewUrl(allocator: Allocator, repository: []const u8, commit: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "https://github.com/{s}/tree/{s}", .{ repository, commit });
}

fn isObjectId(value: []const u8) bool {
    if (value.len != 40 and value.len != 64) return false;
    for (value) |character| if (!std.ascii.isHex(character)) return false;
    return true;
}

fn changesAreResumable(changes: []const u8, resumable_manifest: ?[]const u8) bool {
    const expected = resumable_manifest orelse return std.mem.trim(u8, changes, " \t\r\n").len == 0;
    var lines = std.mem.tokenizeAny(u8, changes, "\r\n");
    var found = false;
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "?? ") or !std.mem.eql(u8, line[3..], expected)) return false;
        if (found) return false;
        found = true;
    }
    return true;
}

fn sha256File(io: Io, path: []const u8) ![32]u8 {
    const file = try Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    var offset: u64 = 0;
    var buffer: [64 * 1024]u8 = undefined;
    while (true) {
        const amount = try file.readPositionalAll(io, &buffer, offset);
        if (amount == 0) break;
        hasher.update(buffer[0..amount]);
        offset += amount;
    }
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    return digest;
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

test "derive the Git-native immutable release location" {
    const allocator = std.testing.allocator;
    const ref = try releaseRef(allocator, "v1.2.3");
    defer allocator.free(ref);
    try std.testing.expectEqualStrings("refs/heads/silex/releases/v1.2.3", ref);
    const commit = "0123456789abcdef0123456789abcdef01234567";
    const url = try gitReleaseArchiveUrl(allocator, "Matanek/GFX", commit, "GFX-1.2.3.tar.gz");
    defer allocator.free(url);
    try std.testing.expectEqualStrings(
        "https://raw.githubusercontent.com/Matanek/GFX/0123456789abcdef0123456789abcdef01234567/GFX-1.2.3.tar.gz",
        url,
    );
    try std.testing.expect(isObjectId(commit));
    try std.testing.expect(!isObjectId("main"));
}

test "resume only the exact manifest prepared by the current publication" {
    const manifest = "registry/v1/packages/GFX/0.25.0.json";
    try std.testing.expect(changesAreResumable("", manifest));
    try std.testing.expect(changesAreResumable("?? registry/v1/packages/GFX/0.25.0.json\n", manifest));
    try std.testing.expect(!changesAreResumable(" M README.md\n", manifest));
    try std.testing.expect(!changesAreResumable("?? registry/v1/packages/GFX/0.24.2.json\n", manifest));
    try std.testing.expect(!changesAreResumable(
        "?? registry/v1/packages/GFX/0.25.0.json\n?? another-file\n",
        manifest,
    ));
}

test "hash a release archive with lowercase SHA-256 output" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Example-1.0.0.tar.gz", .data = "Silex" });
    const root = try std.fs.path.join(std.testing.allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    defer std.testing.allocator.free(root);
    const path = try std.fs.path.join(std.testing.allocator, &.{ root, "Example-1.0.0.tar.gz" });
    defer std.testing.allocator.free(path);
    const digest = try sha256File(std.testing.io, path);
    try std.testing.expectEqualStrings(
        "0c1085f0720dcca0a8a5f9ceb20955324c13959c449315b6b083775aacf16b27",
        &std.fmt.bytesToHex(digest, .lower),
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
        "Matanek/Silex-Lib-GFX",
        &.{ "GFX.UI", "GFX.Tools" },
        "https://github.com/Matanek/Silex-Lib-GFX/releases/download/v0.24.0/GFX-0.24.0.tar.gz",
        digest,
    );
    defer allocator.free(rendered);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, rendered, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("GFX", parsed.value.object.get("name").?.string);
    try std.testing.expectEqualStrings("Matanek/Silex-Lib-GFX", parsed.value.object.get("repository").?.string);
    try std.testing.expectEqualStrings("GFX.Tools", parsed.value.object.get("extensions").?.array.items[1].string);
    try std.testing.expectEqualStrings(digest, parsed.value.object.get("archive").?.object.get("sha256").?.string);
    try std.testing.expect(std.mem.endsWith(u8, rendered, "\n"));
}

test "clone the registry into a managed global checkout with Git only" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Source/registry/v1");
    try temporary.dir.createDirPath(std.testing.io, "Source/scripts");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Source/registry/v1/index.json", .data = "{}\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Source/scripts/build-registry.mjs", .data = "// validator\n" });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    defer allocator.free(root);
    const source = try std.fs.path.join(allocator, &.{ root, "Source" });
    defer allocator.free(source);
    const remote = try std.fs.path.join(allocator, &.{ root, "Registry.git" });
    defer allocator.free(remote);
    const checkout = try std.fs.path.join(allocator, &.{ root, "Home", ".silex", "registry" });
    defer allocator.free(checkout);

    try testGit(allocator, source, &.{ "init", "--quiet", "--initial-branch=main" });
    try testGit(allocator, source, &.{ "add", "." });
    try testGit(allocator, source, &.{
        "-c",     "user.name=Silex Test", "-c", "user.email=test@silex.local",
        "commit", "--quiet",              "-m", "Registry fixture",
    });
    try testGit(allocator, root, &.{ "clone", "--quiet", "--bare", "Source", "Registry.git" });

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var publisher = Publisher.init(arena.allocator(), allocator, std.testing.io);
    publisher.registry_repository = remote;
    try publisher.ensureRegistryCheckout(checkout, null);
    const index = try std.fs.path.join(allocator, &.{ checkout, "registry", "v1", "index.json" });
    defer allocator.free(index);
    try std.testing.expect(try pathExists(std.testing.io, index));
    const origin_output = try publisher.runGit(checkout, &.{ "remote", "get-url", "origin" }, "cannot inspect test registry");
    const origin = std.mem.trim(u8, origin_output, " \t\r\n");
    try std.testing.expect(std.mem.endsWith(u8, origin, remote));

    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Source/registry/v1/upstream.json", .data = "{}\n" });
    try testGit(allocator, source, &.{ "add", "registry/v1/upstream.json" });
    try testGit(allocator, source, &.{
        "-c",     "user.name=Silex Test", "-c", "user.email=test@silex.local",
        "commit", "--quiet",              "-m", "Advance registry fixture",
    });
    const absolute_remote = try Io.Dir.cwd().realPathFileAlloc(std.testing.io, remote, allocator);
    defer allocator.free(absolute_remote);
    try testGit(allocator, source, &.{ "push", "--quiet", absolute_remote, "HEAD:main" });
    try publisher.ensureRegistryCheckout(checkout, null);
    const updated = try std.fs.path.join(allocator, &.{ checkout, "registry", "v1", "upstream.json" });
    defer allocator.free(updated);
    try std.testing.expect(try pathExists(std.testing.io, updated));
}

test "publish a deterministic package archive through the configured Git remote" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Package/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package/Package.json",
        .data = "{\"name\":\"Example\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0\"}}\n",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package/Module/Example.sx", .data = "func value() int { return 1 }\n" });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    defer allocator.free(root);
    const absolute_root = try Io.Dir.cwd().realPathFileAlloc(std.testing.io, root, allocator);
    defer allocator.free(absolute_root);
    const package = try std.fs.path.join(allocator, &.{ absolute_root, "Package" });
    defer allocator.free(package);
    const remote = try std.fs.path.join(allocator, &.{ absolute_root, "Package.git" });
    defer allocator.free(remote);
    const staging = try std.fs.path.join(allocator, &.{ absolute_root, "Staging" });
    defer allocator.free(staging);

    try testGit(allocator, package, &.{ "init", "--quiet", "--initial-branch=main" });
    try testGit(allocator, package, &.{ "add", "." });
    try testGit(allocator, package, &.{
        "-c",     "user.name=Silex Test", "-c", "user.email=test@silex.local",
        "commit", "--quiet",              "-m", "Package fixture",
    });
    try testGit(allocator, absolute_root, &.{ "clone", "--quiet", "--bare", "Package", "Package.git" });
    const absolute_remote = try Io.Dir.cwd().realPathFileAlloc(std.testing.io, remote, allocator);
    defer allocator.free(absolute_remote);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var publisher = Publisher.init(arena.allocator(), allocator, std.testing.io);
    const commit = try publisher.publishGitRelease(
        package,
        absolute_remote,
        staging,
        "Example",
        "1.0.0",
        "Example-1.0.0.tar.gz",
        "refs/heads/silex/releases/v1.0.0",
    );
    try std.testing.expect(isObjectId(commit));

    const released = try std.fs.path.join(allocator, &.{ absolute_root, "Released" });
    defer allocator.free(released);
    try testGit(allocator, absolute_root, &.{
        "clone",       "--quiet",  "--branch", "silex/releases/v1.0.0", "--single-branch",
        "Package.git", "Released",
    });
    const archive = try std.fs.path.join(allocator, &.{ released, "Example-1.0.0.tar.gz" });
    defer allocator.free(archive);
    const checksum = try std.fs.path.join(allocator, &.{ released, "Example-1.0.0.tar.gz.sha256" });
    defer allocator.free(checksum);
    try std.testing.expect(try pathExists(std.testing.io, archive));
    try std.testing.expect(try pathExists(std.testing.io, checksum));
}

fn testGit(allocator: Allocator, root: []const u8, arguments: []const []const u8) !void {
    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(allocator);
    try argv.appendSlice(allocator, &.{ "git", "-C", root });
    try argv.appendSlice(allocator, arguments);
    const result = try std.process.run(allocator, std.testing.io, .{
        .argv = argv.items,
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);
    switch (result.term) {
        .exited => |code| if (code != 0) {
            std.debug.print("test git command failed: {s}\n", .{result.stderr});
            return error.TestUnexpectedResult;
        },
        else => return error.TestUnexpectedResult,
    }
}
