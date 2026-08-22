const std = @import("std");
const Packages = @import("Packages.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const default_registry_repository = "https://github.com/Matanek/Silex-Registry.git";

pub const RegistrationResult = struct {
    name: []const u8,
    registration_path: []const u8,
    registration_sha256: []const u8,
    registration_required: bool,
};

pub const CheckResult = struct {
    name: []const u8,
    version: Packages.Version,
    expected_tag: []const u8,
};

pub const Manager = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    diagnostic: ?[]const u8 = null,
    registry_repository: []const u8 = default_registry_repository,

    pub fn init(allocator: Allocator, download_allocator: Allocator, io: Io) Manager {
        return .{
            .allocator = allocator,
            .download_allocator = download_allocator,
            .io = io,
        };
    }

    pub fn check(self: *Manager, package_root: []const u8) !CheckResult {
        self.diagnostic = null;
        const absolute_root = try self.absolutePackageRoot(package_root);
        const package = try self.inspectPackage(absolute_root);
        const version = try versionText(self.allocator, package.version);
        return .{
            .name = package.name,
            .version = package.version,
            .expected_tag = try std.fmt.allocPrint(self.allocator, "v{s}", .{version}),
        };
    }

    pub fn prepareRegistrationManaged(self: *Manager, package_root: []const u8, registry_root: []const u8) !RegistrationResult {
        const absolute_root = try self.absolutePackageRoot(package_root);
        const package = try self.inspectPackage(absolute_root);
        const resumable_registration = try std.fs.path.join(self.allocator, &.{ "registry", "v1", "packages", try std.fmt.allocPrint(self.allocator, "{s}.json", .{package.name}) });
        try self.ensureRegistryCheckout(registry_root, resumable_registration);
        return self.prepareRegistration(absolute_root, registry_root);
    }

    pub fn prepareRegistration(self: *Manager, package_root: []const u8, registry_root: []const u8) !RegistrationResult {
        self.diagnostic = null;
        const absolute_root = try self.absolutePackageRoot(package_root);
        const package = try self.inspectPackage(absolute_root);

        try self.validateRegistryRoot(registry_root);
        const package_directory = try std.fs.path.join(self.allocator, &.{ registry_root, "registry", "v1", "packages" });
        const registration_path = try std.fs.path.join(self.allocator, &.{ package_directory, try std.fmt.allocPrint(self.allocator, "{s}.json", .{package.name}) });
        try self.validateCleanRepository(absolute_root);
        const remote = try self.git(absolute_root, &.{ "remote", "get-url", "origin" });
        const identity = repositoryFromRemote(self.allocator, std.mem.trim(u8, remote, " \t\r\n")) catch
            return self.fail("package origin must identify a GitHub repository");
        const repository = try std.fmt.allocPrint(self.allocator, "https://github.com/{s}.git", .{identity});
        const registration = try renderRegistration(self.allocator, package.name, repository);
        const checksum = try sha256Source(self.allocator, registration);
        if (try pathExists(self.io, registration_path)) {
            const existing = Io.Dir.cwd().readFileAlloc(self.io, registration_path, self.allocator, .limited(1024 * 1024)) catch |err|
                return self.failFmt("cannot inspect the existing registry registration: {t}", .{err});
            if (!std.mem.eql(u8, existing, registration)) {
                return self.failFmt("package '{s}' is already registered to another repository", .{package.name});
            }
            return .{
                .name = package.name,
                .registration_path = registration_path,
                .registration_sha256 = checksum,
                .registration_required = false,
            };
        }
        Io.Dir.cwd().createDirPath(self.io, package_directory) catch |err| {
            return self.failFmt("cannot create registry package directory: {t}", .{err});
        };
        const temporary = try std.fmt.allocPrint(self.allocator, "{s}.silex-register", .{registration_path});
        Io.Dir.cwd().deleteFile(self.io, temporary) catch |err| switch (err) {
            error.FileNotFound => {},
            else => return self.failFmt("cannot prepare registry registration: {t}", .{err}),
        };
        var keep_temporary = true;
        defer if (keep_temporary) Io.Dir.cwd().deleteFile(self.io, temporary) catch {};
        const file = Io.Dir.cwd().createFile(self.io, temporary, .{ .exclusive = true }) catch |err|
            return self.failFmt("cannot create registry registration: {t}", .{err});
        file.writeStreamingAll(self.io, registration) catch |err| {
            file.close(self.io);
            return self.failFmt("cannot write registry registration: {t}", .{err});
        };
        file.close(self.io);
        Io.Dir.cwd().rename(temporary, Io.Dir.cwd(), registration_path, self.io) catch |err|
            return self.failFmt("cannot publish registry registration: {t}", .{err});
        keep_temporary = false;

        return .{
            .name = package.name,
            .registration_path = registration_path,
            .registration_sha256 = checksum,
            .registration_required = true,
        };
    }

    fn inspectPackage(self: *Manager, package_root: []const u8) !Packages.ManifestInfo {
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

    fn absolutePackageRoot(self: *Manager, package_root: []const u8) ![]const u8 {
        return Io.Dir.cwd().realPathFileAlloc(self.io, package_root, self.allocator) catch |err|
            return self.failFmt("cannot locate package directory '{s}': {t}", .{ package_root, err });
    }

    fn validateCleanRepository(self: *Manager, package_root: []const u8) !void {
        const changes = try self.git(package_root, &.{ "status", "--porcelain" });
        if (std.mem.trim(u8, changes, " \t\r\n").len != 0) {
            return self.fail("package repository has uncommitted changes");
        }
    }

    fn validateRegistryRoot(self: *Manager, registry_root: []const u8) !void {
        const index = try std.fs.path.join(self.allocator, &.{ registry_root, "registry", "v1", "packages" });
        const checker = try std.fs.path.join(self.allocator, &.{ registry_root, "scripts", "build-registry.mjs" });
        if (!try pathExists(self.io, index) or !try pathExists(self.io, checker)) {
            return self.failFmt(
                "'{s}' is not a Silex-Registry source checkout; set SILEX_REGISTRY_SOURCE to its path",
                .{registry_root},
            );
        }
    }

    fn ensureRegistryCheckout(self: *Manager, registry_root: []const u8, resumable_registration: ?[]const u8) !void {
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
        if (!changesAreResumable(changes, resumable_registration)) {
            return self.failFmt(
                "the global registry checkout has unpublished changes in '{s}'; review or commit them before registering another package",
                .{registry_root},
            );
        }
        _ = try self.runGit(registry_root, &.{ "switch", "--quiet", "main" }, "cannot select the registry main branch");
        _ = try self.runGit(
            registry_root,
            &.{ "pull", "--quiet", "--ff-only", "origin", "main" },
            "cannot fast-forward the global registry checkout before preparing the registration",
        );
    }

    fn git(self: *Manager, package_root: []const u8, arguments: []const []const u8) ![]const u8 {
        return self.runGit(package_root, arguments, "cannot inspect package repository");
    }

    fn runGit(self: *Manager, root: []const u8, arguments: []const []const u8, context: []const u8) ![]const u8 {
        var argv: std.ArrayList([]const u8) = .empty;
        try argv.appendSlice(self.allocator, &.{ "git", "-C", root });
        try argv.appendSlice(self.allocator, arguments);
        return self.run(argv.items, context);
    }

    fn run(self: *Manager, arguments: []const []const u8, context: []const u8) ![]const u8 {
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

    fn fail(self: *Manager, message: []const u8) error{InvalidPackageOperation} {
        self.diagnostic = message;
        return error.InvalidPackageOperation;
    }

    fn failFmt(self: *Manager, comptime format: []const u8, arguments: anytype) error{ OutOfMemory, InvalidPackageOperation } {
        self.diagnostic = try std.fmt.allocPrint(self.allocator, format, arguments);
        return error.InvalidPackageOperation;
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

fn renderRegistration(allocator: Allocator, name: []const u8, repository: []const u8) ![]const u8 {
    const Registration = struct {
        schema: u8 = 1,
        name: []const u8,
        repository: []const u8,
    };
    var output: Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    try std.json.Stringify.value(Registration{
        .name = name,
        .repository = repository,
    }, .{ .whitespace = .indent_2 }, &output.writer);
    try output.writer.writeByte('\n');
    return output.toOwnedSlice();
}

fn sha256Source(allocator: Allocator, source: []const u8) ![]const u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return allocator.dupe(u8, &hex);
}

fn versionText(allocator: Allocator, version: Packages.Version) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
}

fn changesAreResumable(changes: []const u8, resumable_registration: ?[]const u8) bool {
    const expected = resumable_registration orelse return std.mem.trim(u8, changes, " \t\r\n").len == 0;
    var lines = std.mem.tokenizeAny(u8, changes, "\r\n");
    var found = false;
    while (lines.next()) |line| {
        if (!std.mem.startsWith(u8, line, "?? ") or !std.mem.eql(u8, line[3..], expected)) return false;
        if (found) return false;
        found = true;
    }
    return true;
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

test "resume only the exact registration prepared by the current registration" {
    const registration = "registry/v1/packages/GFX.json";
    try std.testing.expect(changesAreResumable("", registration));
    try std.testing.expect(changesAreResumable("?? registry/v1/packages/GFX.json\n", registration));
    try std.testing.expect(!changesAreResumable(" M README.md\n", registration));
    try std.testing.expect(!changesAreResumable("?? registry/v1/packages/STD.json\n", registration));
    try std.testing.expect(!changesAreResumable(
        "?? registry/v1/packages/GFX.json\n?? another-file\n",
        registration,
    ));
}

test "render the immutable package registration" {
    const allocator = std.testing.allocator;
    const rendered = try renderRegistration(allocator, "GFX", "https://github.com/Matanek/Silex-Lib-GFX.git");
    defer allocator.free(rendered);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, rendered, .{});
    defer parsed.deinit();
    try std.testing.expectEqualStrings("GFX", parsed.value.object.get("name").?.string);
    try std.testing.expectEqualStrings("https://github.com/Matanek/Silex-Lib-GFX.git", parsed.value.object.get("repository").?.string);
    try std.testing.expect(parsed.value.object.get("version") == null);
    try std.testing.expect(std.mem.endsWith(u8, rendered, "\n"));
}

test "check validates a package without requiring or mutating Git" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.2.3\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Module/Drawing.sx", .data = "public func draw() {}\n" });

    const package_root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "GFX" });
    defer allocator.free(package_root);

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var publisher = Manager.init(arena.allocator(), allocator, std.testing.io);
    const checked = try publisher.check(package_root);
    try std.testing.expectEqualStrings("GFX", checked.name);
    try std.testing.expectEqualStrings("v1.2.3", checked.expected_tag);
}

test "register prepares one identity without requiring a version tag" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "GFX/Module");
    try temporary.dir.createDirPath(std.testing.io, "Registry/registry/v1/packages");
    try temporary.dir.createDirPath(std.testing.io, "Registry/scripts");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "GFX/Package.json",
        .data = "{\"name\":\"GFX\",\"version\":\"1.2.3\",\"requires\":{\"silex\":\">=0.38.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GFX/Module/Drawing.sx", .data = "public func draw() {}\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Registry/scripts/build-registry.mjs", .data = "// validator\n" });

    const relative_root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    defer allocator.free(relative_root);
    const root = try Io.Dir.cwd().realPathFileAlloc(std.testing.io, relative_root, allocator);
    defer allocator.free(root);
    const package_root = try std.fs.path.join(allocator, &.{ root, "GFX", "." });
    defer allocator.free(package_root);
    const registry_root = try std.fs.path.join(allocator, &.{ root, "Registry" });
    defer allocator.free(registry_root);

    try testGit(allocator, package_root, &.{ "init", "--quiet", "--initial-branch=main" });
    try testGit(allocator, package_root, &.{ "add", "." });
    try testGit(allocator, package_root, &.{
        "-c",     "user.name=Silex Test", "-c", "user.email=test@silex.local",
        "commit", "--quiet",              "-m", "Package fixture",
    });
    try testGit(allocator, package_root, &.{ "remote", "add", "origin", "git@github.com:Silex-Test/GFX.git" });

    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    var manager = Manager.init(arena.allocator(), allocator, std.testing.io);
    const prepared = try manager.prepareRegistration(package_root, registry_root);
    try std.testing.expect(prepared.registration_required);
    const repeated = try manager.prepareRegistration(package_root, registry_root);
    try std.testing.expect(!repeated.registration_required);
    try std.testing.expectEqualStrings(prepared.registration_path, repeated.registration_path);
}

test "clone the registry into a managed global checkout with Git only" {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Source/registry/v1/packages");
    try temporary.dir.createDirPath(std.testing.io, "Source/scripts");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Source/registry/v1/packages/STD.json", .data = "{}\n" });
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
    var publisher = Manager.init(arena.allocator(), allocator, std.testing.io);
    publisher.registry_repository = remote;
    try publisher.ensureRegistryCheckout(checkout, null);
    const index = try std.fs.path.join(allocator, &.{ checkout, "registry", "v1", "packages", "STD.json" });
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
