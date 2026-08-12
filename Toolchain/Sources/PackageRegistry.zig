const std = @import("std");
const Artifacts = @import("Artifacts.zig");
const Modules = @import("Modules.zig");
const Packages = @import("Packages.zig");
const PackageStore = @import("PackageStore.zig");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const default_location = "https://silex-lang.org/registry/v1/index.json";

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

pub const Registry = struct {
    location: []const u8,
    releases_endpoint: []const u8,
    manifest_endpoint: []const u8,
};

const PackageIndex = struct {
    name: []const u8,
    location: []const u8,
    releases: []const IndexedRelease,

    fn select(
        self: PackageIndex,
        allocator: Allocator,
        request: Request,
        toolchain: Packages.Version,
        diagnostic: *?[]const u8,
    ) error{ OutOfMemory, InvalidRegistry }!IndexedRelease {
        var selected: ?IndexedRelease = null;
        var requested_release: ?IndexedRelease = null;
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
                .{
                    self.name,
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

    fn selectDependency(
        self: PackageIndex,
        allocator: Allocator,
        dependency: Packages.ManifestDependency,
        toolchain: Packages.Version,
        diagnostic: *?[]const u8,
    ) error{ OutOfMemory, InvalidRegistry }!IndexedRelease {
        var selected: ?IndexedRelease = null;
        for (self.releases) |release| {
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

const IndexedRelease = struct {
    version: Packages.Version,
    requirement: Packages.SilexRequirement,
    manifest: []const u8,
};

const RawRegistry = struct {
    schema: u32,
    endpoints: RawEndpoints,
};

const RawEndpoints = struct {
    releases: []const u8,
    manifest: []const u8,
};

const RawPackageIndex = struct {
    schema: u32,
    name: []const u8,
    releases: []const RawIndexedRelease,
};

const RawIndexedRelease = struct {
    version: []const u8,
    requires: RawRequires,
    manifest: []const u8,
};

const RawManifest = struct {
    schema: u32,
    name: []const u8,
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

    pub fn load(self: *Client, location: []const u8) !Registry {
        self.diagnostic = null;
        const source = try self.read(location, "registry index");
        const raw = std.json.parseFromSliceLeaky(RawRegistry, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.fail("invalid package registry index");
        if (raw.schema != 1) return self.fail("unsupported package registry schema");
        if (!validEndpoint(raw.endpoints.releases, "{package}") or
            std.mem.indexOf(u8, raw.endpoints.releases, "{version}") != null or
            !validEndpoint(raw.endpoints.manifest, "{package}") or
            std.mem.indexOf(u8, raw.endpoints.manifest, "{version}") == null)
        {
            return self.fail("package registry contains invalid endpoints");
        }
        return .{
            .location = try self.allocator.dupe(u8, location),
            .releases_endpoint = raw.endpoints.releases,
            .manifest_endpoint = raw.endpoints.manifest,
        };
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
        registry: Registry,
        request: Request,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        store: *PackageStore.Manager,
    ) !PackageStore.InstallResult {
        const package = try self.loadPackageIndex(registry, request.name);
        const indexed = try package.select(self.allocator, request, toolchain, &self.diagnostic);
        const release = try self.loadRelease(registry, package, indexed);
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
            const package = try self.loadPackageIndex(registry, dependency.name);
            const indexed = try package.selectDependency(self.allocator, dependency, toolchain, &self.diagnostic);
            const selected = try self.loadRelease(registry, package, indexed);
            _ = try self.installRelease(registry, selected, toolchain, target, store, stack);
        }
        return store.install(source, target) catch |err| switch (err) {
            error.InvalidPackageStore => return self.failFmt(
                "cannot install package '{s}': {s}",
                .{ release.name, store.diagnostic orelse "invalid package" },
            ),
            else => |other| return other,
        };
    }

    fn loadPackageIndex(self: *Client, registry: Registry, name: []const u8) !PackageIndex {
        const endpoint = try expandEndpoint(self.allocator, registry.releases_endpoint, name, null);
        const location = try resolveLocation(self.allocator, registry.location, endpoint);
        const source = try self.read(location, "package index");
        const raw = std.json.parseFromSliceLeaky(RawPackageIndex, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.failFmt("invalid package index for '{s}'", .{name});
        if (raw.schema != 1) return self.failFmt("package '{s}' uses an unsupported index schema", .{name});
        if (!std.mem.eql(u8, raw.name, name)) return self.failFmt("package index for '{s}' has a mismatched name", .{name});

        var releases: std.ArrayList(IndexedRelease) = .empty;
        for (raw.releases) |raw_release| {
            const version = Packages.Version.parse(raw_release.version) catch
                return self.failFmt("package '{s}' has an invalid release version", .{name});
            for (releases.items) |release| if (release.version.eql(version)) {
                return self.failFmt("package index contains release '{s}@{s}' more than once", .{ name, raw_release.version });
            };
            const requirement = Packages.SilexRequirement.parse(raw_release.requires.silex) catch
                return self.failFmt("release '{s}@{s}' has an invalid requires.silex", .{ name, raw_release.version });
            if (!validRelativePath(raw_release.manifest) or std.mem.indexOfScalar(u8, raw_release.manifest, '/') != null) {
                return self.failFmt("release '{s}@{s}' has an invalid manifest reference", .{ name, raw_release.version });
            }
            const manifest_endpoint = try expandEndpoint(self.allocator, registry.manifest_endpoint, name, raw_release.version);
            if (!std.mem.eql(u8, std.fs.path.basename(manifest_endpoint), raw_release.manifest)) {
                return self.failFmt("release '{s}@{s}' has a mismatched manifest reference", .{ name, raw_release.version });
            }
            try releases.append(self.allocator, .{
                .version = version,
                .requirement = requirement,
                .manifest = raw_release.manifest,
            });
        }
        return .{
            .name = raw.name,
            .location = location,
            .releases = try releases.toOwnedSlice(self.allocator),
        };
    }

    fn loadRelease(self: *Client, registry: Registry, package: PackageIndex, indexed: IndexedRelease) !Release {
        const version_text = try std.fmt.allocPrint(self.allocator, "{d}.{d}.{d}", .{
            indexed.version.major,
            indexed.version.minor,
            indexed.version.patch,
        });
        const endpoint = try expandEndpoint(self.allocator, registry.manifest_endpoint, package.name, version_text);
        const location = try resolveLocation(self.allocator, registry.location, endpoint);
        const adjacent_location = try resolveLocation(self.allocator, package.location, indexed.manifest);
        if (!std.mem.eql(u8, location, adjacent_location)) {
            return self.failFmt("release '{s}@{s}' manifest is outside its package index", .{ package.name, version_text });
        }
        const source = try self.read(location, "release manifest");
        const raw = std.json.parseFromSliceLeaky(RawManifest, self.allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = false,
        }) catch return self.failFmt("invalid release manifest for '{s}@{s}'", .{ package.name, version_text });
        if (raw.schema != 1) return self.failFmt("release '{s}@{s}' uses an unsupported manifest schema", .{ package.name, version_text });
        if (!std.mem.eql(u8, raw.name, package.name) or !std.mem.eql(u8, raw.version, version_text)) {
            return self.failFmt("release manifest for '{s}@{s}' has a mismatched identity", .{ package.name, version_text });
        }
        const requirement = Packages.SilexRequirement.parse(raw.requires.silex) catch
            return self.failFmt("release '{s}@{s}' has an invalid requires.silex", .{ package.name, version_text });
        if (!std.mem.eql(u8, requirement.text, indexed.requirement.text)) {
            return self.failFmt("release manifest for '{s}@{s}' has mismatched Silex compatibility", .{ package.name, version_text });
        }
        if (!std.mem.startsWith(u8, raw.archive.url, "https://")) {
            return self.failFmt("release '{s}@{s}' archive must use HTTPS", .{ package.name, version_text });
        }
        if (!validSha256(raw.archive.sha256)) {
            return self.failFmt("release '{s}@{s}' has an invalid SHA-256 checksum", .{ package.name, version_text });
        }
        return .{
            .name = raw.name,
            .version = indexed.version,
            .requirement = requirement,
            .url = raw.archive.url,
            .sha256 = raw.archive.sha256,
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

fn validEndpoint(template: []const u8, required: []const u8) bool {
    if (std.mem.indexOf(u8, template, required) == null) return false;
    var buffer: [1024]u8 = undefined;
    var writer: std.Io.Writer = .fixed(&buffer);
    expandEndpointToWriter(&writer, template, "Package", "1.2.3") catch return false;
    return validRelativePath(writer.buffered());
}

fn expandEndpoint(
    allocator: Allocator,
    template: []const u8,
    package: []const u8,
    version: ?[]const u8,
) ![]const u8 {
    var output: Io.Writer.Allocating = .init(allocator);
    defer output.deinit();
    try expandEndpointToWriter(&output.writer, template, package, version);
    const expanded = try allocator.dupe(u8, output.written());
    if (!validRelativePath(expanded)) return error.InvalidRegistry;
    return expanded;
}

fn expandEndpointToWriter(
    writer: *Io.Writer,
    template: []const u8,
    package: []const u8,
    version: ?[]const u8,
) !void {
    var cursor: usize = 0;
    while (cursor < template.len) {
        if (std.mem.startsWith(u8, template[cursor..], "{package}")) {
            try writer.writeAll(package);
            cursor += "{package}".len;
        } else if (std.mem.startsWith(u8, template[cursor..], "{version}")) {
            try writer.writeAll(version orelse return error.InvalidRegistry);
            cursor += "{version}".len;
        } else {
            if (template[cursor] == '{' or template[cursor] == '}') return error.InvalidRegistry;
            try writer.writeByte(template[cursor]);
            cursor += 1;
        }
    }
}

fn validRelativePath(path: []const u8) bool {
    if (path.len == 0 or path[0] == '/' or path[0] == '\\') return false;
    if (std.mem.indexOfAny(u8, path, "\\?#") != null or std.mem.indexOf(u8, path, "://") != null) return false;
    var segments = std.mem.splitScalar(u8, path, '/');
    while (segments.next()) |segment| {
        if (segment.len == 0 or std.mem.eql(u8, segment, ".") or std.mem.eql(u8, segment, "..")) return false;
    }
    return true;
}

fn resolveLocation(allocator: Allocator, base_file: []const u8, relative: []const u8) ![]const u8 {
    if (!validRelativePath(relative)) return error.InvalidRegistry;
    if (std.mem.startsWith(u8, base_file, "https://")) {
        const slash = std.mem.lastIndexOfScalar(u8, base_file, '/') orelse return error.InvalidRegistry;
        return std.fmt.allocPrint(allocator, "{s}/{s}", .{ base_file[0..slash], relative });
    }
    const directory = std.fs.path.dirname(base_file) orelse ".";
    return std.fs.path.join(allocator, &.{ directory, relative });
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
    const package: PackageIndex = .{
        .name = "STD",
        .location = "registry/packages/STD/index.json",
        .releases = &.{
            .{
                .version = try Packages.Version.parse("0.15.0"),
                .requirement = try Packages.SilexRequirement.parse(">=0.38.0 <0.39.0"),
                .manifest = "0.15.0.json",
            },
            .{
                .version = try Packages.Version.parse("0.16.0"),
                .requirement = try Packages.SilexRequirement.parse(">=0.39.0 <0.40.0"),
                .manifest = "0.16.0.json",
            },
        },
    };
    var diagnostic: ?[]const u8 = null;
    const selected = try package.select(
        allocator,
        try Request.parse("STD"),
        try Packages.Version.parse("0.38.0"),
        &diagnostic,
    );
    try std.testing.expect(selected.version.eql(try Packages.Version.parse("0.15.0")));
    try std.testing.expectError(error.InvalidRegistry, package.select(
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
    try temporary.dir.createDirPath(std.testing.io, "Registry/packages/STD");
    try temporary.dir.createDirPath(std.testing.io, "Registry/packages/GFX");
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
    const registry_path = try std.fs.path.join(allocator, &.{ base, "Registry", "index.json" });
    var client = Client.init(allocator, std.testing.allocator, std.testing.io, cache);
    const empty_sha = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Registry/index.json",
        .data = "{\"schema\":1,\"endpoints\":{\"releases\":\"packages/{package}/index.json\",\"manifest\":\"packages/{package}/{version}.json\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Registry/packages/STD/index.json",
        .data = "{\"schema\":1,\"name\":\"STD\",\"releases\":[{\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"},\"manifest\":\"1.0.0.json\"}]}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Registry/packages/GFX/index.json",
        .data = "{\"schema\":1,\"name\":\"GFX\",\"releases\":[{\"version\":\"2.0.0\",\"requires\":{\"silex\":\">=0.38.0 <0.39.0\"},\"manifest\":\"2.0.0.json\"}]}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Registry/packages/STD/1.0.0.json",
        .data = try std.fmt.allocPrint(allocator, "{{\"schema\":1,\"name\":\"STD\",\"version\":\"1.0.0\",\"requires\":{{\"silex\":\">=0.38.0 <0.39.0\"}},\"archive\":{{\"url\":\"https://example.test/STD.tar.gz\",\"sha256\":\"{s}\"}}}}", .{empty_sha}),
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Registry/packages/GFX/2.0.0.json",
        .data = try std.fmt.allocPrint(allocator, "{{\"schema\":1,\"name\":\"GFX\",\"version\":\"2.0.0\",\"requires\":{{\"silex\":\">=0.38.0 <0.39.0\"}},\"archive\":{{\"url\":\"https://example.test/GFX.tar.gz\",\"sha256\":\"{s}\"}}}}", .{empty_sha}),
    });
    const registry = try client.load(registry_path);
    var store = PackageStore.Manager.init(allocator, std.testing.allocator, std.testing.io, store_root);
    const result = try client.install(
        registry,
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
