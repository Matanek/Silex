const std = @import("std");
const Artifacts = @import("Artifacts.zig");
const Modules = @import("Modules.zig");
const Packages = @import("Packages.zig");
const PackageStore = @import("PackageStore.zig");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const default_location = "https://raw.githubusercontent.com/Matanek/Silex/main/Registry.json";

pub const Request = struct {
    name: []const u8,
    version: ?Packages.Version,

    pub fn parse(text: []const u8) error{InvalidRequest}!Request {
        const separator = std.mem.indexOfScalar(u8, text, '@');
        const name = if (separator) |index| text[0..index] else text;
        if (!Modules.validName(name)) return error.InvalidRequest;
        if (separator) |index| {
            if (index + 1 == text.len or std.mem.indexOfScalar(u8, text[index + 1 ..], '@') != null) {
                return error.InvalidRequest;
            }
            return .{
                .name = name,
                .version = Packages.Version.parse(text[index + 1 ..]) catch return error.InvalidRequest,
            };
        }
        return .{ .name = name, .version = null };
    }
};

pub const Release = struct {
    name: []const u8,
    version: Packages.Version,
    requirement: Packages.SilexRequirement,
    url: []const u8,
    sha256: []const u8,
};

pub const Catalog = struct {
    packages: []const Package,

    const Package = struct {
        name: []const u8,
        releases: []const Release,
    };

    pub fn select(
        self: Catalog,
        allocator: Allocator,
        request: Request,
        toolchain: Packages.Version,
        diagnostic: *?[]const u8,
    ) error{ OutOfMemory, InvalidRegistry }!Release {
        const package = for (self.packages) |candidate| {
            if (std.mem.eql(u8, candidate.name, request.name)) break candidate;
        } else {
            diagnostic.* = try std.fmt.allocPrint(allocator, "package '{s}' is not present in the registry", .{request.name});
            return error.InvalidRegistry;
        };

        var selected: ?Release = null;
        var requested_release: ?Release = null;
        for (package.releases) |release| {
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
                .{
                    release.name,
                    release.version.major,
                    release.version.minor,
                    release.version.patch,
                    release.requirement.text,
                },
            );
        } else if (request.version) |version| {
            diagnostic.* = try std.fmt.allocPrint(
                allocator,
                "package '{s}@{d}.{d}.{d}' is not published",
                .{ request.name, version.major, version.minor, version.patch },
            );
        } else {
            diagnostic.* = try std.fmt.allocPrint(
                allocator,
                "package '{s}' has no release compatible with this Silex toolchain",
                .{request.name},
            );
        }
        return error.InvalidRegistry;
    }

    pub fn selectDependency(
        self: Catalog,
        allocator: Allocator,
        dependency: Packages.ManifestDependency,
        toolchain: Packages.Version,
        diagnostic: *?[]const u8,
    ) error{ OutOfMemory, InvalidRegistry }!Release {
        const package = for (self.packages) |candidate| {
            if (std.mem.eql(u8, candidate.name, dependency.name)) break candidate;
        } else {
            diagnostic.* = try std.fmt.allocPrint(
                allocator,
                "dependency '{s}' is not present in the registry",
                .{dependency.name},
            );
            return error.InvalidRegistry;
        };
        var selected: ?Release = null;
        for (package.releases) |release| {
            if (!dependency.constraint.accepts(release.version) or !release.requirement.accepts(toolchain)) continue;
            if (selected == null or release.version.order(selected.?.version) == .gt) selected = release;
        }
        if (selected) |release| return release;
        diagnostic.* = try std.fmt.allocPrint(
            allocator,
            "dependency '{s}' has no published version satisfying {c}{d}.{d}.{d} for this Silex toolchain",
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

const RawCatalog = struct {
    schema: u32,
    packages: []const RawPackage,
};

const RawPackage = struct {
    name: []const u8,
    releases: []const RawRelease,
};

const RawRelease = struct {
    version: []const u8,
    requires: RawRequires,
    archive: RawArchive,
};

const RawRequires = struct {
    silex: []const u8,
};

const RawArchive = struct {
    url: []const u8,
    sha256: []const u8,
};

pub const Client = struct {
    allocator: Allocator,
    download_allocator: Allocator,
    io: Io,
    cache_root: []const u8,
    diagnostic: ?[]const u8 = null,

    pub fn init(
        allocator: Allocator,
        download_allocator: Allocator,
        io: Io,
        cache_root: []const u8,
    ) Client {
        return .{
            .allocator = allocator,
            .download_allocator = download_allocator,
            .io = io,
            .cache_root = cache_root,
        };
    }

    pub fn load(self: *Client, location: []const u8) !Catalog {
        self.diagnostic = null;
        const source = if (std.mem.startsWith(u8, location, "https://"))
            try self.fetch(location)
        else if (std.mem.indexOf(u8, location, "://") != null)
            return self.fail("package registry must use HTTPS")
        else
            Io.Dir.cwd().readFileAlloc(self.io, location, self.allocator, .limited(4 * 1024 * 1024)) catch |err| {
                return self.failFmt("cannot read package registry '{s}': {t}", .{ location, err });
            };
        return self.parse(source);
    }

    pub fn acquire(self: *Client, release: Release) ![]const u8 {
        const label = try releaseLabel(self.allocator, release);
        const archive_path = try std.fmt.allocPrint(self.allocator, "downloads/{s}.tar.gz", .{label});
        const source_path = try std.fmt.allocPrint(self.allocator, "sources/{s}", .{label});
        var installer = Artifacts.Installer.init(self.allocator, self.download_allocator, self.io);
        _ = installer.installTool(self.cache_root, .{
            .name = label,
            .path = archive_path,
            .url = release.url,
            .sha256 = release.sha256,
            .archive = .{
                .format = .tar_gz,
                .into = source_path,
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
        return std.fs.path.join(self.allocator, &.{ self.cache_root, source_path });
    }

    pub fn install(
        self: *Client,
        catalog: Catalog,
        request: Request,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        store: *PackageStore.Manager,
    ) !PackageStore.InstallResult {
        const release = try catalog.select(self.allocator, request, toolchain, &self.diagnostic);
        var stack: std.ArrayList([]const u8) = .empty;
        return self.installRelease(catalog, release, toolchain, target, store, &stack);
    }

    fn installRelease(
        self: *Client,
        catalog: Catalog,
        release: Release,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        store: *PackageStore.Manager,
        stack: *std.ArrayList([]const u8),
    ) anyerror!PackageStore.InstallResult {
        for (stack.items) |name| if (std.mem.eql(u8, name, release.name)) {
            return self.failFmt("package dependency cycle includes '{s}'", .{release.name});
        };
        const source = try self.acquire(release);
        const manifest = store.inspect(source) catch |err| switch (err) {
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
            return self.failFmt("downloaded package '{s}' does not match its registry release", .{release.name});
        }

        try stack.append(self.allocator, release.name);
        defer _ = stack.pop();
        for (manifest.dependencies) |dependency| {
            const selected = try catalog.selectDependency(self.allocator, dependency, toolchain, &self.diagnostic);
            _ = try self.installRelease(catalog, selected, toolchain, target, store, stack);
        }
        return store.install(source, target) catch |err| switch (err) {
            error.InvalidPackageStore => return self.failFmt(
                "cannot install package '{s}': {s}",
                .{ release.name, store.diagnostic orelse "invalid package" },
            ),
            else => |other| return other,
        };
    }

    fn parse(self: *Client, source: []const u8) !Catalog {
        const raw = std.json.parseFromSliceLeaky(RawCatalog, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.fail("invalid package registry");
        if (raw.schema != 1) return self.fail("unsupported package registry schema");
        var packages: std.ArrayList(Catalog.Package) = .empty;
        for (raw.packages) |raw_package| {
            if (!Modules.validName(raw_package.name)) return self.fail("registry contains an invalid package name");
            for (packages.items) |package| if (std.mem.eql(u8, package.name, raw_package.name)) {
                return self.failFmt("registry contains package '{s}' more than once", .{raw_package.name});
            };
            var releases: std.ArrayList(Release) = .empty;
            for (raw_package.releases) |raw_release| {
                const version = Packages.Version.parse(raw_release.version) catch
                    return self.failFmt("package '{s}' has an invalid release version", .{raw_package.name});
                for (releases.items) |release| if (release.version.eql(version)) {
                    return self.failFmt("registry contains release '{s}@{s}' more than once", .{ raw_package.name, raw_release.version });
                };
                const requirement = Packages.SilexRequirement.parse(raw_release.requires.silex) catch
                    return self.failFmt("release '{s}@{s}' has an invalid requires.silex", .{ raw_package.name, raw_release.version });
                if (!std.mem.startsWith(u8, raw_release.archive.url, "https://")) {
                    return self.failFmt("release '{s}@{s}' archive must use HTTPS", .{ raw_package.name, raw_release.version });
                }
                if (!validSha256(raw_release.archive.sha256)) {
                    return self.failFmt("release '{s}@{s}' has an invalid SHA-256 checksum", .{ raw_package.name, raw_release.version });
                }
                try releases.append(self.allocator, .{
                    .name = raw_package.name,
                    .version = version,
                    .requirement = requirement,
                    .url = raw_release.archive.url,
                    .sha256 = raw_release.archive.sha256,
                });
            }
            try packages.append(self.allocator, .{
                .name = raw_package.name,
                .releases = try releases.toOwnedSlice(self.allocator),
            });
        }
        return .{ .packages = try packages.toOwnedSlice(self.allocator) };
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
        if (response.status.class() != .success) {
            return self.failFmt("cannot download package registry: HTTP {d}", .{@intFromEnum(response.status)});
        }
        if (output.written().len > 4 * 1024 * 1024) return self.fail("package registry exceeds 4 MiB");
        return self.allocator.dupe(u8, output.written());
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

fn releaseLabel(allocator: Allocator, release: Release) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}@{d}.{d}.{d}", .{
        release.name,
        release.version.major,
        release.version.minor,
        release.version.patch,
    });
}

fn validSha256(text: []const u8) bool {
    if (text.len != 64) return false;
    for (text) |character| if (!std.ascii.isHex(character)) return false;
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

test "select newest toolchain-compatible registry release" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var client = Client.init(allocator, std.testing.allocator, std.testing.io, "Cache");
    const catalog = try client.parse(
        \\{"schema":1,"packages":[{"name":"STD","releases":[
        \\{"version":"0.15.0","requires":{"silex":">=0.38.0 <0.39.0"},"archive":{"url":"https://example.test/STD-0.15.0.tar.gz","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}},
        \\{"version":"0.16.0","requires":{"silex":">=0.39.0 <0.40.0"},"archive":{"url":"https://example.test/STD-0.16.0.tar.gz","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"}}
        \\]}]}
    );
    var diagnostic: ?[]const u8 = null;
    const selected = try catalog.select(
        allocator,
        try Request.parse("STD"),
        try Packages.Version.parse("0.38.0"),
        &diagnostic,
    );
    try std.testing.expect(selected.version.eql(try Packages.Version.parse("0.15.0")));
    try std.testing.expectError(error.InvalidRegistry, catalog.select(
        allocator,
        try Request.parse("STD@0.16.0"),
        try Packages.Version.parse("0.38.0"),
        &diagnostic,
    ));
    try std.testing.expect(std.mem.indexOf(u8, diagnostic.?, "requires Silex >=0.39.0 <0.40.0") != null);
}

test "install registry package dependencies before the requested package" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Cache/downloads");
    try temporary.dir.createDirPath(std.testing.io, "Cache/sources/STD@1.0.0/Module");
    try temporary.dir.createDirPath(std.testing.io, "Cache/sources/GFX@2.0.0/Module");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Cache/downloads/STD@1.0.0.tar.gz", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Cache/downloads/GFX@2.0.0.tar.gz", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Cache/sources/STD@1.0.0/Package.json",
        .data =
        \\{"name":"STD","version":"1.0.0","requires":{"silex":">=0.38.0 <0.39.0"}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Cache/sources/GFX@2.0.0/Package.json",
        .data =
        \\{"name":"GFX","version":"2.0.0","requires":{"silex":">=0.38.0 <0.39.0"},"dependencies":{"STD":"^1.0.0"}}
        ,
    });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const cache = try std.fs.path.join(allocator, &.{ base, "Cache" });
    const store_root = try std.fs.path.join(allocator, &.{ base, "Store", "packages" });
    var client = Client.init(allocator, std.testing.allocator, std.testing.io, cache);
    const empty_sha = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
    const catalog = try client.parse(try std.fmt.allocPrint(allocator,
        \\{{"schema":1,"packages":[
        \\{{"name":"STD","releases":[{{"version":"1.0.0","requires":{{"silex":">=0.38.0 <0.39.0"}},"archive":{{"url":"https://example.test/STD.tar.gz","sha256":"{s}"}}}}]}},
        \\{{"name":"GFX","releases":[{{"version":"2.0.0","requires":{{"silex":">=0.38.0 <0.39.0"}},"archive":{{"url":"https://example.test/GFX.tar.gz","sha256":"{s}"}}}}]}}
        \\]}}
    , .{ empty_sha, empty_sha }));
    var store = PackageStore.Manager.init(allocator, std.testing.allocator, std.testing.io, store_root);
    const result = try client.install(
        catalog,
        try Request.parse("GFX"),
        try Packages.Version.parse("0.38.0"),
        .macos_arm64,
        &store,
    );
    try std.testing.expectEqualStrings("GFX", result.package.name);
    try std.testing.expect(try pathExists(std.testing.io, try std.fs.path.join(allocator, &.{ store_root, "STD@1.0.0" })));
    try std.testing.expect(try pathExists(std.testing.io, try std.fs.path.join(allocator, &.{ store_root, "GFX@2.0.0" })));
}

fn pathExists(io: Io, path: []const u8) !bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => |other| return other,
    };
    return true;
}
