const std = @import("std");
const Artifacts = @import("Artifacts.zig");
const Modules = @import("Modules.zig");
const Packages = @import("Packages.zig");
const PackageStore = @import("PackageStore.zig");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const default_location = "https://registry.silex-lang.org/v1/index.json";

pub const Request = struct {
    name: []const u8,
    version: ?Packages.Version,

    pub fn parse(text: []const u8) error{InvalidRequest}!Request {
        const separator = std.mem.indexOfScalar(u8, text, '@');
        const name = if (separator) |index| text[0..index] else text;
        if (!Modules.validName(name)) return error.InvalidRequest;
        if (separator) |index| {
            if (index + 1 == text.len or std.mem.indexOfScalar(u8, text[index + 1 ..], '@') != null) return error.InvalidRequest;
            return .{
                .name = name,
                .version = Packages.Version.parse(text[index + 1 ..]) catch return error.InvalidRequest,
            };
        }
        return .{ .name = name, .version = null };
    }
};

pub const Registration = struct {
    name: []const u8,
    repository: []const u8,
};

pub const Registry = struct {
    location: []const u8,
    packages: []const Registration,

    fn find(self: Registry, name: []const u8) ?Registration {
        for (self.packages) |package| if (std.mem.eql(u8, package.name, name)) return package;
        return null;
    }
};

pub const Release = struct {
    name: []const u8,
    version: Packages.Version,
    requirement: Packages.SilexRequirement,
    repository: []const u8,
    commit: []const u8,
};

const PackageIndex = struct {
    name: []const u8,
    repository: []const u8,
    git_root: []const u8,
    releases: []const Release,

    fn select(
        self: PackageIndex,
        allocator: Allocator,
        request: Request,
        toolchain: Packages.Version,
        diagnostic: *?[]const u8,
    ) error{ OutOfMemory, InvalidRegistry }!Release {
        var selected: ?Release = null;
        var requested_release: ?Release = null;
        for (self.releases) |release| {
            if (request.version) |version| {
                if (!release.version.eql(version)) continue;
                requested_release = release;
            }
            if (!release.requirement.accepts(toolchain)) continue;
            if (selected == null or release.version.order(selected.?.version) == .gt) selected = release;
        }
        if (selected) |release| return release;
        if (requested_release) |release| {
            diagnostic.* = try std.fmt.allocPrint(
                allocator,
                "package '{s}@{d}.{d}.{d}' requires Silex {s}",
                .{ self.name, release.version.major, release.version.minor, release.version.patch, release.requirement.text },
            );
        } else if (request.version) |version| {
            diagnostic.* = try std.fmt.allocPrint(
                allocator,
                "package '{s}@{d}.{d}.{d}' has no release tag",
                .{ request.name, version.major, version.minor, version.patch },
            );
        } else {
            diagnostic.* = try std.fmt.allocPrint(
                allocator,
                "package '{s}' has no tagged release compatible with this Silex toolchain",
                .{request.name},
            );
        }
        return error.InvalidRegistry;
    }

    fn selectDependency(
        self: PackageIndex,
        allocator: Allocator,
        dependency: Packages.ManifestDependency,
        toolchain: Packages.Version,
        diagnostic: *?[]const u8,
    ) error{ OutOfMemory, InvalidRegistry }!Release {
        var selected: ?Release = null;
        for (self.releases) |release| {
            if (!dependency.constraint.accepts(release.version) or !release.requirement.accepts(toolchain)) continue;
            if (selected == null or release.version.order(selected.?.version) == .gt) selected = release;
        }
        if (selected) |release| return release;
        diagnostic.* = try std.fmt.allocPrint(
            allocator,
            "dependency '{s}' has no tagged version satisfying {c}{d}.{d}.{d} for this Silex toolchain",
            .{
                dependency.name,
                if (dependency.constraint.kind == .exact) @as(u8, '=') else @as(u8, '^'),
                dependency.constraint.version.major,
                dependency.constraint.version.minor,
                dependency.constraint.version.patch,
            },
        );
        return error.InvalidRegistry;
    }
};

const RawRegistry = struct {
    schema: u32,
    packages: []const RawRegistration,
};

const RawRegistration = struct {
    name: []const u8,
    repository: []const u8,
};

const RawPackageManifest = struct {
    name: []const u8,
    version: []const u8,
    requires: struct { silex: []const u8 },
};

const Acquired = struct {
    source: []const u8,
    sha256: []const u8,
};

pub const Client = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    cache_root: []const u8,
    diagnostic: ?[]const u8 = null,

    pub fn init(allocator: Allocator, download_allocator: Allocator, io: Io, cache_root: []const u8) Client {
        return .{
            .allocator = allocator,
            .download_allocator = download_allocator,
            .io = io,
            .cache_root = cache_root,
        };
    }

    pub fn load(self: *Client, location: []const u8) !Registry {
        self.diagnostic = null;
        const source = try self.read(location, "registry index");
        const raw = std.json.parseFromSliceLeaky(RawRegistry, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.fail("invalid package registry index");
        if (raw.schema != 2) return self.fail("unsupported package registry schema");

        var packages: std.ArrayList(Registration) = .empty;
        for (raw.packages) |package| {
            if (!Modules.validName(package.name)) return self.failFmt("registry contains invalid package name '{s}'", .{package.name});
            if (!validRepository(package.repository, location)) return self.failFmt("package '{s}' has an invalid repository", .{package.name});
            for (packages.items) |existing| if (std.mem.eql(u8, existing.name, package.name)) {
                return self.failFmt("registry contains package '{s}' more than once", .{package.name});
            };
            try packages.append(self.allocator, .{ .name = package.name, .repository = package.repository });
        }
        if (packages.items.len == 0) return self.fail("package registry contains no packages");
        std.mem.sort(Registration, packages.items, {}, registrationLessThan);
        return .{
            .location = try self.allocator.dupe(u8, location),
            .packages = try packages.toOwnedSlice(self.allocator),
        };
    }

    pub fn install(
        self: *Client,
        registry: Registry,
        request: Request,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        store: *PackageStore.Manager,
    ) !PackageStore.InstallResult {
        const package = try self.loadPackageIndex(registry, request.name);
        const release = try package.select(self.allocator, request, toolchain, &self.diagnostic);
        var stack: std.ArrayList([]const u8) = .empty;
        return self.installRelease(registry, release, toolchain, target, store, &stack);
    }

    fn installRelease(
        self: *Client,
        registry: Registry,
        release: Release,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        store: *PackageStore.Manager,
        stack: *std.ArrayList([]const u8),
    ) anyerror!PackageStore.InstallResult {
        for (stack.items) |name| if (std.mem.eql(u8, name, release.name)) {
            return self.failFmt("package dependency cycle includes '{s}'", .{release.name});
        };
        const acquired = try self.acquire(release);
        const manifest = store.inspect(acquired.source) catch |err| switch (err) {
            error.InvalidPackageStore => return self.failFmt(
                "downloaded package '{s}' is invalid: {s}",
                .{ release.name, store.diagnostic orelse "invalid package manifest" },
            ),
            else => |other| return other,
        };
        if (!std.mem.eql(u8, manifest.name, release.name) or
            !manifest.version.eql(release.version) or
            !std.mem.eql(u8, manifest.silex_requirement.text, release.requirement.text))
        {
            return self.failFmt("tagged package '{s}' does not match its Package.json", .{release.name});
        }

        try stack.append(self.allocator, release.name);
        defer _ = stack.pop();
        for (manifest.dependencies) |dependency| {
            const package = try self.loadPackageIndex(registry, dependency.name);
            const selected = try package.selectDependency(self.allocator, dependency, toolchain, &self.diagnostic);
            _ = try self.installRelease(registry, selected, toolchain, target, store, stack);
        }
        return store.installPublished(acquired.source, target, .{
            .repository = release.repository,
            .commit = release.commit,
            .archive_sha256 = acquired.sha256,
            .extensions = manifest.extensions,
            .friends = manifest.friends,
            .catalogs = manifest.catalogs,
        }) catch |err| switch (err) {
            error.InvalidPackageStore => return self.failFmt(
                "cannot install package '{s}': {s}",
                .{ release.name, store.diagnostic orelse "invalid package" },
            ),
            else => |other| return other,
        };
    }

    fn loadPackageIndex(self: *Client, registry: Registry, name: []const u8) !PackageIndex {
        const registration = registry.find(name) orelse return self.failFmt("package '{s}' is not registered", .{name});
        const git_root = try self.synchronizeRepository(registration);
        const tags = try self.runGit(
            git_root,
            &.{ "for-each-ref", "--format=%(refname:strip=2)", "refs/tags" },
            "cannot list package release tags",
        );
        var releases: std.ArrayList(Release) = .empty;
        var lines = std.mem.tokenizeAny(u8, tags, "\r\n");
        while (lines.next()) |tag| {
            if (!std.mem.startsWith(u8, tag, "v")) continue;
            const version = Packages.Version.parse(tag[1..]) catch continue;
            for (releases.items) |existing| if (existing.version.eql(version)) {
                return self.failFmt("repository for '{s}' contains version tag '{s}' more than once", .{ name, tag });
            };
            const reference = try std.fmt.allocPrint(self.allocator, "refs/tags/{s}^{{commit}}", .{tag});
            const commit_source = try self.runGit(git_root, &.{ "rev-parse", reference }, "cannot resolve package release tag");
            const commit = std.mem.trim(u8, commit_source, " \t\r\n");
            if (!validObjectId(commit)) return self.failFmt("package tag '{s}' does not identify a Git commit", .{tag});
            const manifest_ref = try std.fmt.allocPrint(self.allocator, "{s}:Package.json", .{commit});
            const manifest_source = try self.runGit(git_root, &.{ "show", manifest_ref }, "cannot read tagged package manifest");
            const raw = std.json.parseFromSliceLeaky(RawPackageManifest, self.allocator, manifest_source, .{
                .allocate = .alloc_always,
                .ignore_unknown_fields = true,
            }) catch return self.failFmt("tag '{s}' has an invalid Package.json", .{tag});
            if (!std.mem.eql(u8, raw.name, name) or !std.mem.eql(u8, raw.version, tag[1..])) {
                return self.failFmt("tag '{s}' does not match package '{s}' identity and version", .{ tag, name });
            }
            const requirement = Packages.SilexRequirement.parse(raw.requires.silex) catch
                return self.failFmt("tag '{s}' has an invalid requires.silex", .{tag});
            try releases.append(self.allocator, .{
                .name = name,
                .version = version,
                .requirement = requirement,
                .repository = registration.repository,
                .commit = try self.allocator.dupe(u8, commit),
            });
        }
        return .{
            .name = registration.name,
            .repository = registration.repository,
            .git_root = git_root,
            .releases = try releases.toOwnedSlice(self.allocator),
        };
    }

    fn synchronizeRepository(self: *Client, registration: Registration) ![]const u8 {
        const repositories_root = try std.fs.path.join(self.allocator, &.{ self.cache_root, "repositories" });
        const folder = try std.fmt.allocPrint(self.allocator, "{s}.git", .{registration.name});
        const git_root = try std.fs.path.join(self.allocator, &.{ repositories_root, folder });
        if (!try pathExists(self.io, git_root)) {
            try Io.Dir.cwd().createDirPath(self.io, repositories_root);
            _ = try self.run(&.{ "git", "init", "--bare", "--quiet", git_root }, "cannot initialize package repository cache");
            _ = try self.runGit(git_root, &.{ "remote", "add", "origin", registration.repository }, "cannot configure package repository cache");
        } else {
            const remote_source = try self.runGit(git_root, &.{ "remote", "get-url", "origin" }, "cannot inspect package repository cache");
            const remote = std.mem.trim(u8, remote_source, " \t\r\n");
            if (!std.mem.eql(u8, remote, registration.repository)) {
                return self.failFmt("cached repository for '{s}' does not match the registry", .{registration.name});
            }
        }
        _ = try self.runGit(
            git_root,
            &.{ "fetch", "--quiet", "--filter=blob:none", "origin", "refs/tags/v*:refs/tags/v*" },
            "cannot fetch package release tags",
        );
        return git_root;
    }

    fn acquire(self: *Client, release: Release) !Acquired {
        const version = try versionText(self.allocator, release.version);
        const label = try std.fmt.allocPrint(self.allocator, "{s}@{s}-{s}", .{ release.name, version, release.commit[0..12] });
        const archive_relative = try std.fmt.allocPrint(self.allocator, "downloads/{s}.tar.gz", .{label});
        const archive_path = try std.fs.path.join(self.allocator, &.{ self.cache_root, archive_relative });
        const source_relative = try std.fmt.allocPrint(self.allocator, "sources/{s}", .{label});
        if (!try pathExists(self.io, archive_path)) {
            if (std.fs.path.dirname(archive_path)) |parent| try Io.Dir.cwd().createDirPath(self.io, parent);
            const prefix = try std.fmt.allocPrint(self.allocator, "{s}-{s}/", .{ release.name, version });
            const output = try std.fmt.allocPrint(self.allocator, "--output={s}", .{archive_path});
            const prefix_option = try std.fmt.allocPrint(self.allocator, "--prefix={s}", .{prefix});
            const repository_folder = try std.fmt.allocPrint(self.allocator, "{s}.git", .{release.name});
            const git_root = try std.fs.path.join(self.allocator, &.{ self.cache_root, "repositories", repository_folder });
            _ = try self.runGit(
                git_root,
                &.{ "archive", "--format=tar.gz", prefix_option, output, release.commit },
                "cannot create package archive from its release tag",
            );
        }
        const sha256 = try sha256File(self.allocator, self.io, archive_path);
        const source_url = if (std.mem.startsWith(u8, release.repository, "https://"))
            try std.fmt.allocPrint(self.allocator, "{s}/archive/{s}.tar.gz", .{ release.repository[0 .. release.repository.len - ".git".len], release.commit })
        else
            try std.fmt.allocPrint(self.allocator, "https://registry.silex-lang.org/source/{s}.tar.gz", .{release.commit});
        var installer = Artifacts.Installer.init(self.allocator, self.download_allocator, self.io);
        _ = installer.installTool(self.cache_root, .{
            .name = label,
            .path = archive_relative,
            .url = source_url,
            .sha256 = sha256,
            .archive = .{
                .format = .tar_gz,
                .into = source_relative,
                .provides = "Package.json",
                .strip_components = 1,
            },
        }) catch |err| switch (err) {
            error.InvalidManifest => return self.failFmt(
                "cannot acquire package '{s}': {s}",
                .{ label, installer.diagnostic orelse "invalid package archive" },
            ),
            else => |other| return other,
        };
        return .{
            .source = try std.fs.path.join(self.allocator, &.{ self.cache_root, source_relative }),
            .sha256 = sha256,
        };
    }

    fn read(self: *Client, location: []const u8, label: []const u8) ![]const u8 {
        if (std.mem.startsWith(u8, location, "https://")) return self.fetch(location);
        if (std.mem.indexOf(u8, location, "://") != null) return self.fail("package registry must use HTTPS");
        return Io.Dir.cwd().readFileAlloc(self.io, location, self.allocator, .limited(4 * 1024 * 1024)) catch |err| {
            return self.failFmt("cannot read {s} '{s}': {t}", .{ label, location, err });
        };
    }

    fn fetch(self: *Client, url: []const u8) ![]const u8 {
        var output: Io.Writer.Allocating = .init(self.download_allocator);
        defer output.deinit();
        var http: std.http.Client = .{ .allocator = self.download_allocator, .io = self.io };
        defer http.deinit();
        const response = http.fetch(.{
            .location = .{ .url = url },
            .response_writer = &output.writer,
            .headers = .{ .user_agent = .{ .override = "Silex package registry" } },
        }) catch |err| return self.failFmt("cannot download package registry: {t}", .{err});
        if (response.status.class() != .success) return self.failFmt("cannot download package registry: HTTP {d}", .{@intFromEnum(response.status)});
        if (output.written().len > 4 * 1024 * 1024) return self.fail("package registry exceeds 4 MiB");
        return self.allocator.dupe(u8, output.written());
    }

    fn runGit(self: *Client, root: []const u8, arguments: []const []const u8, context: []const u8) ![]const u8 {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(self.allocator, &.{ "git", "-C", root });
        try argv.appendSlice(self.allocator, arguments);
        return self.run(argv.items, context);
    }

    fn run(self: *Client, arguments: []const []const u8, context: []const u8) ![]const u8 {
        const result = std.process.run(self.download_allocator, self.io, .{
            .argv = arguments,
            .stdout_limit = .limited(16 * 1024 * 1024),
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

    fn fail(self: *Client, message: []const u8) error{InvalidRegistry} {
        self.diagnostic = message;
        return error.InvalidRegistry;
    }

    fn failFmt(self: *Client, comptime format: []const u8, arguments: anytype) error{ OutOfMemory, InvalidRegistry } {
        self.diagnostic = try std.fmt.allocPrint(self.allocator, format, arguments);
        return error.InvalidRegistry;
    }
};

fn registrationLessThan(_: void, left: Registration, right: Registration) bool {
    return std.mem.order(u8, left.name, right.name) == .lt;
}

fn validRepository(repository: []const u8, registry_location: []const u8) bool {
    if (std.mem.startsWith(u8, repository, "https://") and std.mem.endsWith(u8, repository, ".git")) return true;
    if (std.mem.startsWith(u8, registry_location, "https://")) return false;
    return std.fs.path.isAbsolute(repository) or std.mem.indexOfAny(u8, repository, "/\\") != null;
}

fn validObjectId(value: []const u8) bool {
    if (value.len != 40 and value.len != 64) return false;
    for (value) |character| if (!std.ascii.isHex(character)) return false;
    return true;
}

fn versionText(allocator: Allocator, version: Packages.Version) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
}

fn sha256File(allocator: Allocator, io: Io, path: []const u8) ![]const u8 {
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
    const hex = std.fmt.bytesToHex(digest, .lower);
    return allocator.dupe(u8, &hex);
}

fn pathExists(io: Io, path: []const u8) !bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => |other| return other,
    };
    return true;
}

test "parse package requests" {
    const latest = try Request.parse("STD");
    try std.testing.expectEqualStrings("STD", latest.name);
    try std.testing.expect(latest.version == null);
    const exact = try Request.parse("GFX@0.22.0");
    try std.testing.expect(exact.version.?.eql(try Packages.Version.parse("0.22.0")));
    try std.testing.expectError(error.InvalidRequest, Request.parse("../STD"));
    try std.testing.expectError(error.InvalidRequest, Request.parse("STD@latest"));
}

test "load repository-only registry and select newest compatible release" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Registry");
    const relative_base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const base = try Io.Dir.cwd().realPathFileAlloc(std.testing.io, relative_base, allocator);
    const repository = try std.fs.path.join(allocator, &.{ base, "STD.git" });
    const registry_path = try std.fs.path.join(allocator, &.{ base, "Registry", "index.json" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Registry/index.json",
        .data = try std.fmt.allocPrint(allocator, "{{\"schema\":2,\"packages\":[{{\"name\":\"STD\",\"repository\":\"{s}\"}}]}}", .{repository}),
    });
    var client = Client.init(allocator, std.testing.allocator, std.testing.io, try std.fs.path.join(allocator, &.{ base, "Cache" }));
    const registry = try client.load(registry_path);
    try std.testing.expectEqualStrings(repository, registry.find("STD").?.repository);

    const package: PackageIndex = .{
        .name = "STD",
        .repository = repository,
        .git_root = repository,
        .releases = &.{
            .{
                .name = "STD",
                .version = try Packages.Version.parse("0.15.0"),
                .requirement = try Packages.SilexRequirement.parse(">=0.38.0 <0.39.0"),
                .repository = repository,
                .commit = "0123456789abcdef0123456789abcdef01234567",
            },
            .{
                .name = "STD",
                .version = try Packages.Version.parse("0.16.0"),
                .requirement = try Packages.SilexRequirement.parse(">=0.39.0 <0.40.0"),
                .repository = repository,
                .commit = "1123456789abcdef0123456789abcdef01234567",
            },
        },
    };
    var diagnostic: ?[]const u8 = null;
    const selected = try package.select(allocator, try Request.parse("STD"), try Packages.Version.parse("0.38.0"), &diagnostic);
    try std.testing.expect(selected.version.eql(try Packages.Version.parse("0.15.0")));
}

test "install tagged package dependencies from registered Git repositories" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "STD/Module");
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "Registry");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "STD/Package.json",
        .data = "{\"name\":\"STD\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "STD/Module/Text.sx", .data = "public func value() int { return 1 }" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"2.0.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"},\"extensions\":[\"GFX.UI\"],\"friends\":[\"GFX.UI\"],\"catalogs\":[\"GFX.Plugins\"],\"dependencies\":{\"STD\":\"^1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Module/Drawing.sx", .data = "public func value() int { return 2 }" });
    const relative_base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const base = try Io.Dir.cwd().realPathFileAlloc(std.testing.io, relative_base, allocator);
    const std_root = try std.fs.path.join(allocator, &.{ base, "STD" });
    const gfx_root = try std.fs.path.join(allocator, &.{ base, "GFX" });
    const std_repository = try std.fs.path.join(allocator, &.{ base, "STD.git" });
    const gfx_repository = try std.fs.path.join(allocator, &.{ base, "GFX.git" });
    try testGit(allocator, std_root, &.{ "init", "--quiet", "--initial-branch=main" });
    try testGit(allocator, std_root, &.{ "add", "." });
    try testGit(allocator, std_root, &.{ "-c", "user.name=Silex Test", "-c", "user.email=test@silex.local", "commit", "--quiet", "-m", "STD" });
    try testGit(allocator, std_root, &.{ "tag", "v1.0.0" });
    try testGit(allocator, base, &.{ "clone", "--quiet", "--bare", "STD", "STD.git" });
    try testGit(allocator, gfx_root, &.{ "init", "--quiet", "--initial-branch=main" });
    try testGit(allocator, gfx_root, &.{ "add", "." });
    try testGit(allocator, gfx_root, &.{ "-c", "user.name=Silex Test", "-c", "user.email=test@silex.local", "commit", "--quiet", "-m", "GFX" });
    try testGit(allocator, gfx_root, &.{ "tag", "v2.0.0" });
    try testGit(allocator, base, &.{ "clone", "--quiet", "--bare", "GFX", "GFX.git" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Registry/index.json",
        .data = try std.fmt.allocPrint(
            allocator,
            "{{\"schema\":2,\"packages\":[{{\"name\":\"GFX\",\"repository\":\"{s}\"}},{{\"name\":\"STD\",\"repository\":\"{s}\"}}]}}",
            .{ gfx_repository, std_repository },
        ),
    });

    const cache = try std.fs.path.join(allocator, &.{ base, "Cache" });
    const store_root = try std.fs.path.join(allocator, &.{ base, "Store", "packages" });
    const registry_path = try std.fs.path.join(allocator, &.{ base, "Registry", "index.json" });
    var client = Client.init(allocator, std.testing.allocator, std.testing.io, cache);
    const registry = try client.load(registry_path);
    var store = PackageStore.Manager.init(allocator, std.testing.allocator, std.testing.io, store_root);
    const result = client.install(
        registry,
        try Request.parse("GFX"),
        try Packages.Version.parse("0.38.0"),
        .macos_arm64,
        &store,
    ) catch |err| {
        std.debug.print("package registry integration failed: {s}\n", .{client.diagnostic orelse store.diagnostic orelse @errorName(err)});
        return err;
    };
    try std.testing.expectEqualStrings("GFX", result.package.name);
    try std.testing.expectEqualStrings("GFX.UI", result.package.friends[0]);
    try std.testing.expectEqualStrings("GFX.Plugins", result.package.catalogs[0]);
    try std.testing.expect(try pathExists(std.testing.io, try std.fs.path.join(allocator, &.{ store_root, "STD@1.0.0" })));
    try std.testing.expect(try pathExists(std.testing.io, try std.fs.path.join(allocator, &.{ store_root, "GFX@2.0.0", ".silex", "source.json" })));
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
