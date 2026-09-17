const std = @import("std");
const Archive = @import("PackageArchive.zig");
const DescriptorWriter = @import("PackageDescriptor.zig");
const Modules = @import("Modules.zig");
const Packages = @import("Packages.zig");
const PackageStore = @import("PackageStore.zig");
const PackageRegistry = @import("PackageRegistry.zig");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
pub const public_origin = "https://registry.silex-lang.org";

pub const Blob = struct {
    sha256: []const u8,
    size: usize,
};

pub const File = struct {
    path: []const u8,
    sha256: []const u8,
    size: usize,
};

pub const Artifact = struct {
    name: []const u8,
    path: []const u8,
    sha256: []const u8,
    size: usize,
    target: []const u8,
};

/// These fields deliberately follow the server's recursively sorted canonical
/// representation; serializing this struct reproduces its publication digest.
pub const Descriptor = struct {
    artifacts: []const Artifact,
    files: []const File,
    manifest: []const u8,
    provenance: ?DescriptorWriter.Provenance = null,
    schema: u8,
    source: Blob,
};

const LegacyDescriptor = struct {
    artifacts: []const Artifact,
    files: []const File,
    manifest: []const u8,
    schema: u8,
    source: Blob,
};

const VersionReply = struct {
    publication_sha256: []const u8,
    descriptor: Descriptor,
};

const VersionListing = struct {
    name: []const u8,
    versions: []const struct { version: []const u8, digest: []const u8 },
};

pub const Publication = struct {
    digest: []const u8,
    descriptor: Descriptor,
    package: Packages.ManifestInfo,
};

pub const ListedVersion = struct {
    version: Packages.Version,
    digest: []const u8,
};

pub const Client = struct {
    allocator: Allocator,
    network_allocator: Allocator,
    io: Io,
    origin: []const u8,
    diagnostic: ?[]const u8 = null,

    pub fn install(
        self: *Client,
        request: PackageRegistry.Request,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        cache_root: []const u8,
        store: *PackageStore.Manager,
        options: PackageRegistry.InstallOptions,
    ) !PackageStore.InstallResult {
        self.diagnostic = null;
        const root = try self.select(request.name, request.version, null, toolchain);
        var stack: std.ArrayList([]const u8) = .empty;
        var installed: std.StringHashMapUnmanaged(PackageStore.InstallResult) = .empty;
        defer installed.deinit(self.allocator);
        const result = try self.installRelease(root, toolchain, target, cache_root, store, &stack, &installed);
        if (options.suite) {
            for (root.package.extensions) |extension| {
                if (!extension.suite) continue;
                const member = try self.selectSuiteMember(extension.name, root.package, toolchain);
                _ = try self.installRelease(member, toolchain, target, cache_root, store, &stack, &installed);
            }
        }
        if (options.development) try self.installDependencies(root.package.dev_dependencies,
            toolchain, target, cache_root, store, &stack, &installed);
        return result;
    }

    pub fn installDevelopmentDependencies(
        self: *Client,
        dependencies: []const Packages.ManifestDependency,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        cache_root: []const u8,
        store: *PackageStore.Manager,
    ) !void {
        var stack: std.ArrayList([]const u8) = .empty;
        var installed: std.StringHashMapUnmanaged(PackageStore.InstallResult) = .empty;
        defer installed.deinit(self.allocator);
        try self.installDependencies(dependencies, toolchain, target, cache_root, store, &stack, &installed);
    }

    fn installDependencies(
        self: *Client,
        dependencies: []const Packages.ManifestDependency,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        cache_root: []const u8,
        store: *PackageStore.Manager,
        stack: *std.ArrayList([]const u8),
        installed: *std.StringHashMapUnmanaged(PackageStore.InstallResult),
    ) !void {
        for (dependencies) |dependency| {
            if (installed.get(dependency.name)) |previous| {
                if (!dependency.constraint.accepts(previous.package.version)) return self.failFmt(
                    "selected package '{s}' conflicts with its development constraint", .{dependency.name});
                continue;
            }
            const selected = try self.select(dependency.name, null, dependency.constraint, toolchain);
            _ = try self.installRelease(selected, toolchain, target, cache_root, store, stack, installed);
        }
    }

    fn selectSuiteMember(self: *Client, name: []const u8, parent: Packages.ManifestInfo, toolchain: Packages.Version) !Publication {
        const listing = try self.versions(name);
        var chosen: ?Publication = null;
        for (listing) |item| {
            if (chosen != null and item.version.order(chosen.?.package.version) != .gt) continue;
            const candidate = self.publication(name, item, toolchain) catch |err| switch (err) {
                error.IncompatibleToolchain => continue,
                else => return err,
            };
            for (candidate.package.dependencies) |dependency| {
                if (!std.mem.eql(u8, dependency.name, parent.name) or !dependency.constraint.accepts(parent.version)) continue;
                chosen = candidate;
                break;
            }
        }
        return chosen orelse self.failFmt("suite member '{s}' has no version compatible with '{s}'",
            .{ name, parent.name });
    }

    fn select(
        self: *Client,
        name: []const u8,
        exact: ?Packages.Version,
        constraint: ?Packages.Constraint,
        toolchain: Packages.Version,
    ) !Publication {
        const listing = try self.versions(name);
        var best: ?ListedVersion = null;
        for (listing) |item| {
            if (exact) |version| if (!item.version.eql(version)) continue;
            if (constraint) |required| if (!required.accepts(item.version)) continue;
            if (best == null or item.version.order(best.?.version) == .gt) best = item;
        }
        // Try older compatible releases if the newest requires a newer toolchain.
        var upper: ?Packages.Version = null;
        while (best) |candidate| {
            const selected = self.publication(name, candidate, toolchain) catch |err| switch (err) {
                error.IncompatibleToolchain => null,
                else => return err,
            };
            if (selected) |publication_data| return publication_data;
            upper = candidate.version;
            best = null;
            for (listing) |item| {
                if (item.version.order(upper.?) != .lt) continue;
                if (exact) |version| if (!item.version.eql(version)) continue;
                if (constraint) |required| if (!required.accepts(item.version)) continue;
                if (best == null or item.version.order(best.?.version) == .gt) best = item;
            }
        }
        return self.failFmt("package '{s}' has no registered version compatible with this Silex toolchain and its constraint", .{name});
    }

    fn installRelease(
        self: *Client,
        publication_data: Publication,
        toolchain: Packages.Version,
        target: TargetModule.Target,
        cache_root: []const u8,
        store: *PackageStore.Manager,
        stack: *std.ArrayList([]const u8),
        installed: *std.StringHashMapUnmanaged(PackageStore.InstallResult),
    ) !PackageStore.InstallResult {
        const package = publication_data.package;
        if (installed.get(package.name)) |previous| {
            if (!previous.package.version.eql(package.version)) return self.failFmt(
                "package '{s}' resolves to incompatible versions", .{package.name});
            return previous;
        }
        for (stack.items) |name| if (std.mem.eql(u8, name, package.name))
            return self.failFmt("package dependency cycle includes '{s}'", .{package.name});
        try stack.append(self.allocator, package.name);
        defer _ = stack.pop();
        for (package.dependencies) |dependency| {
            if (installed.get(dependency.name)) |previous| {
                if (!dependency.constraint.accepts(previous.package.version)) return self.failFmt(
                    "package '{s}' requires an incompatible selected version of '{s}'",
                    .{ package.name, dependency.name });
                continue;
            }
            const selected = try self.select(dependency.name, null, dependency.constraint, toolchain);
            _ = try self.installRelease(selected, toolchain, target, cache_root, store, stack, installed);
        }
        const dependencies = try self.allocator.alloc(Packages.LockedDependency, package.dependencies.len);
        for (package.dependencies, dependencies) |dependency, *selected| {
            const resolved = installed.get(dependency.name) orelse return self.fail("missing selected package dependency");
            selected.* = .{ .name = dependency.name, .version = try std.fmt.allocPrint(self.allocator,
                "{d}.{d}.{d}", .{ resolved.package.version.major, resolved.package.version.minor, resolved.package.version.patch }) };
        }
        const result = try self.installPublication(publication_data, target, cache_root, store, dependencies);
        try installed.put(self.allocator, package.name, result);
        return result;
    }

    pub fn versions(self: *Client, name: []const u8) ![]const ListedVersion {
        if (!Modules.validName(name)) return self.fail("invalid package name");
        const path = try std.fmt.allocPrint(self.allocator, "/v2/packages/{s}", .{name});
        return parseListing(self.allocator, try self.get(path, 1024 * 1024), name) catch
            return self.fail("registry returned an invalid package version list");
    }

    pub fn publication(self: *Client, name: []const u8, listed: ListedVersion, toolchain: Packages.Version) !Publication {
        if (!Modules.validName(name)) return self.fail("invalid package name");
        const path = try std.fmt.allocPrint(self.allocator, "/v2/packages/{s}/versions/{d}.{d}.{d}",
            .{ name, listed.version.major, listed.version.minor, listed.version.patch });
        return parsePublication(self.allocator, self.io, try self.get(path, 1024 * 1024),
            name, listed.version, listed.digest, toolchain) catch |err| switch (err) {
            error.IncompatibleToolchain => error.IncompatibleToolchain,
            error.OutOfMemory => error.OutOfMemory,
            else => self.fail("registry returned a publication inconsistent with its digest or manifest"),
        };
    }

    pub fn source(self: *Client, name: []const u8, version: Packages.Version, blob: Blob) ![]const u8 {
        const path = try std.fmt.allocPrint(self.allocator, "/v2/packages/{s}/versions/{d}.{d}.{d}/source",
            .{ name, version.major, version.minor, version.patch });
        const bytes = try self.get(path, blob.size);
        if (bytes.len != blob.size or !matches(bytes, blob.sha256)) return self.fail("registry source does not match its descriptor");
        return bytes;
    }

    pub fn installPublication(
        self: *Client,
        publication_data: Publication,
        target: TargetModule.Target,
        cache_root: []const u8,
        store: *PackageStore.Manager,
        dependencies: []const Packages.LockedDependency,
    ) !PackageStore.InstallResult {
        const package = publication_data.package;
        const descriptor = publication_data.descriptor;
        const bytes = try self.source(package.name, package.version, descriptor.source);
        const expected = try self.allocator.alloc(Archive.ExpectedFile, descriptor.files.len);
        for (descriptor.files, expected) |file, *item| item.* = .{
            .path = file.path,
            .size = file.size,
            .sha256 = file.sha256,
        };
        const files = Archive.decode(self.allocator, bytes, expected) catch |err| switch (err) {
            error.OutOfMemory => return err,
            else => return self.fail("registry source archive does not match its file inventory"),
        };
        const parent = try std.fs.path.join(self.allocator, &.{ cache_root, "sources-v2" });
        try Io.Dir.cwd().createDirPath(self.io, parent);
        const folder = try std.fmt.allocPrint(self.allocator, ".{s}@{d}.{d}.{d}.extracting",
            .{ package.name, package.version.major, package.version.minor, package.version.patch });
        const staging = try std.fs.path.join(self.allocator, &.{ parent, folder });
        Io.Dir.cwd().createDir(self.io, staging, .default_dir) catch
            return self.fail("an incomplete registry source extraction exists");
        defer Io.Dir.cwd().deleteTree(self.io, staging) catch {};
        for (files) |file| {
            const path = try std.fs.path.join(self.allocator, &.{ staging, file.path });
            if (std.fs.path.dirname(path)) |directory| try Io.Dir.cwd().createDirPath(self.io, directory);
            try Io.Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = file.bytes });
        }
        for (descriptor.artifacts) |artifact| {
            if (!std.mem.eql(u8, artifact.target, target.name())) continue;
            const path = try std.fs.path.join(self.allocator, &.{ staging, artifact.path });
            if (std.fs.path.dirname(path)) |directory| try Io.Dir.cwd().createDirPath(self.io, directory);
            const route = try std.fmt.allocPrint(self.allocator,
                "/v2/packages/{s}/versions/{d}.{d}.{d}/artifacts/{s}/{s}",
                .{ package.name, package.version.major, package.version.minor, package.version.patch, artifact.target, artifact.name });
            try self.downloadBlob(route, path, .{ .sha256 = artifact.sha256, .size = artifact.size });
        }
        var acquired: std.ArrayList(Packages.ManifestArtifact) = .empty;
        for (descriptor.artifacts) |artifact| {
            if (!std.mem.eql(u8, artifact.target, target.name())) continue;
            try acquired.append(self.allocator, .{ .target = artifact.target, .name = artifact.name,
                .path = artifact.path, .sha256 = artifact.sha256 });
        }
        return store.installPublished(staging, target, .{ .registry = .{
            .origin = self.origin,
            .publication_sha256 = publication_data.digest,
            .source_sha256 = descriptor.source.sha256,
            .dependencies = dependencies,
            .artifacts = acquired.items,
            .extensions = package.extensions,
            .catalogs = package.catalogs,
        } }) catch |err| switch (err) {
            error.InvalidPackageStore => self.fail(store.diagnostic orelse "invalid registry package"),
            else => |other| other,
        };
    }

    fn downloadBlob(self: *Client, path: []const u8, output: []const u8, blob: Blob) !void {
        if (!hexSha(blob.sha256) or blob.size > 1024 * 1024 * 1024) return self.fail("invalid registry artifact limit");
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.origin, path });
        const Event = union(enum) { response: anyerror!void, timeout: Io.Cancelable!void };
        var buffer: [2]Event = undefined;
        var race = Io.Select(Event).init(self.io, &buffer);
        defer race.cancelDiscard();
        try race.concurrent(.response, fetchBlob, .{ self, url, output, blob });
        try race.concurrent(.timeout, Io.sleep, .{ self.io, Io.Duration.fromSeconds(30), .boot });
        switch (try race.await()) {
            .response => |response| response catch return self.fail("cannot download or verify registry artifact"),
            .timeout => return self.fail("registry artifact download timed out"),
        }
    }

    fn fetchBlob(self: *Client, url: []const u8, path: []const u8, blob: Blob) !void {
        const file = try Io.Dir.cwd().createFile(self.io, path, .{ .exclusive = true });
        defer file.close(self.io);
        var client: std.http.Client = .{ .allocator = self.network_allocator, .io = self.io };
        defer client.deinit();
        var request = try client.request(.GET, try std.Uri.parse(url), .{
            .redirect_behavior = .unhandled,
            .headers = .{ .user_agent = .{ .override = "Silex package installer" } },
        });
        defer request.deinit();
        try request.sendBodiless();
        var head_buffer: [8192]u8 = undefined;
        var response = try request.receiveHead(&head_buffer);
        if (response.head.status != .ok or response.head.content_encoding != .identity or
            (response.head.content_length != null and response.head.content_length.? != blob.size))
            return error.InvalidRegistryArtifact;
        var transfer_buffer: [64]u8 = undefined;
        const reader = response.reader(&transfer_buffer);
        var buffer: [64 * 1024]u8 = undefined;
        var hasher = std.crypto.hash.sha2.Sha256.init(.{});
        var count: usize = 0;
        while (true) {
            const length = try reader.readSliceShort(&buffer);
            if (length == 0) break;
            if (length > blob.size - count) return error.InvalidRegistryArtifact;
            count += length;
            hasher.update(buffer[0..length]);
            try file.writeStreamingAll(self.io, buffer[0..length]);
        }
        var digest: [32]u8 = undefined;
        hasher.final(&digest);
        const actual = std.fmt.bytesToHex(digest, .lower);
        if (count != blob.size or !std.mem.eql(u8, &actual, blob.sha256)) return error.InvalidRegistryArtifact;
        try file.sync(self.io);
    }

    fn get(self: *Client, path: []const u8, limit: usize) ![]const u8 {
        if (limit > 16 * 1024 * 1024) return self.fail("registry response exceeds source limit");
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.origin, path });
        const output = try self.allocator.alloc(u8, limit + 1);
        const Event = union(enum) { response: anyerror!usize, timeout: Io.Cancelable!void };
        var buffer: [2]Event = undefined;
        var race = Io.Select(Event).init(self.io, &buffer);
        defer race.cancelDiscard();
        try race.concurrent(.response, fetch, .{ self, url, output });
        try race.concurrent(.timeout, Io.sleep, .{ self.io, Io.Duration.fromSeconds(30), .boot });
        const length = switch (try race.await()) {
            .response => |response| response catch return self.fail("cannot read the public package registry"),
            .timeout => return self.fail("public package registry request timed out"),
        };
        if (length > limit) return self.fail("registry response exceeds its declared size limit");
        return output[0..length];
    }

    fn fetch(self: *Client, url: []const u8, output: []u8) !usize {
        var client: std.http.Client = .{ .allocator = self.network_allocator, .io = self.io };
        defer client.deinit();
        var request = try client.request(.GET, try std.Uri.parse(url), .{
            .redirect_behavior = .unhandled,
            .headers = .{ .user_agent = .{ .override = "Silex package installer" } },
        });
        defer request.deinit();
        try request.sendBodiless();
        var head_buffer: [8192]u8 = undefined;
        var response = try request.receiveHead(&head_buffer);
        if (response.head.status != .ok or response.head.content_encoding != .identity or
            (response.head.content_length != null and response.head.content_length.? > output.len))
            return error.RegistryHttpStatus;
        var transfer_buffer: [64]u8 = undefined;
        const reader = response.reader(&transfer_buffer);
        var length: usize = 0;
        while (true) {
            if (length == output.len) {
                var extra: [1]u8 = undefined;
                if (try reader.readSliceShort(&extra) != 0) return error.RegistryResponseTooLong;
                break;
            }
            const read = try reader.readSliceShort(output[length..]);
            length += read;
            if (read == 0) break;
        }
        return length;
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

pub fn parseListing(allocator: Allocator, bytes: []const u8, name: []const u8) ![]const ListedVersion {
    const listing = std.json.parseFromSliceLeaky(VersionListing, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    }) catch return error.InvalidRegistryResponse;
    if (!Modules.validName(name) or !std.mem.eql(u8, name, listing.name) or listing.versions.len == 0 or listing.versions.len > 4096)
        return error.InvalidRegistryResponse;
    const versions = try allocator.alloc(ListedVersion, listing.versions.len);
    for (listing.versions, versions, 0..) |item, *listed, index| {
        const version = Packages.Version.parse(item.version) catch return error.InvalidRegistryResponse;
        if (!hexSha(item.digest)) return error.InvalidRegistryResponse;
        for (versions[0..index]) |previous| if (previous.version.eql(version)) return error.InvalidRegistryResponse;
        listed.* = .{ .version = version, .digest = item.digest };
    }
    return versions;
}

pub fn parsePublication(
    allocator: Allocator,
    io: Io,
    bytes: []const u8,
    name: []const u8,
    version: Packages.Version,
    expected_digest: []const u8,
    toolchain: Packages.Version,
) !Publication {
    if (!hexSha(expected_digest)) return error.InvalidRegistryResponse;
    const reply = std.json.parseFromSliceLeaky(VersionReply, allocator, bytes, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = false,
    }) catch return error.InvalidRegistryResponse;
    if (reply.descriptor.schema != 1 or !std.mem.eql(u8, reply.publication_sha256, expected_digest) or
        reply.descriptor.manifest.len > 262144 or !hexSha(reply.descriptor.source.sha256) or
        reply.descriptor.source.size > 16 * 1024 * 1024 or
        reply.descriptor.files.len == 0 or reply.descriptor.files.len > 10000 or
        reply.descriptor.artifacts.len > 256)
        return error.InvalidRegistryResponse;

    const canonical = if (reply.descriptor.provenance != null)
        try std.json.Stringify.valueAlloc(allocator, reply.descriptor, .{})
    else
        try std.json.Stringify.valueAlloc(allocator, LegacyDescriptor{
            .artifacts = reply.descriptor.artifacts,
            .files = reply.descriptor.files,
            .manifest = reply.descriptor.manifest,
            .schema = reply.descriptor.schema,
            .source = reply.descriptor.source,
        }, .{});
    if (!matches(canonical, expected_digest)) return error.InvalidRegistryResponse;
    const requirement_data = std.json.parseFromSliceLeaky(struct {
        requires: struct { silex: []const u8 },
    }, allocator, reply.descriptor.manifest, .{
        .allocate = .alloc_always,
        .ignore_unknown_fields = true,
    }) catch return error.InvalidRegistryResponse;
    const requirement = Packages.SilexRequirement.parse(requirement_data.requires.silex) catch return error.InvalidRegistryResponse;
    if (!requirement.accepts(toolchain)) return error.IncompatibleToolchain;
    var resolver = Packages.Resolver.init(allocator, io, null);
    // The manifest parser does not perform filesystem access.
    const package = resolver.inspectManifestSource(reply.descriptor.manifest) catch return error.InvalidRegistryResponse;
    if (!std.mem.eql(u8, package.name, name) or !package.version.eql(version)) return error.InvalidRegistryResponse;

    var expanded: usize = 0;
    var has_manifest = false;
    var previous_path: []const u8 = "";
    for (reply.descriptor.files) |file| {
        if (!Archive.safeArchivePath(file.path) or !hexSha(file.sha256) or
            std.mem.order(u8, previous_path, file.path) != .lt or
            file.size > 64 * 1024 * 1024 - expanded)
            return error.InvalidRegistryResponse;
        expanded += file.size;
        previous_path = file.path;
        if (std.mem.eql(u8, file.path, "Package.json")) {
            if (file.size != reply.descriptor.manifest.len or !matches(reply.descriptor.manifest, file.sha256))
                return error.InvalidRegistryResponse;
            has_manifest = true;
        }
    }
    if (!has_manifest) return error.InvalidRegistryResponse;
    if (reply.descriptor.artifacts.len != package.artifacts.len) return error.InvalidRegistryResponse;
    for (reply.descriptor.artifacts, 0..) |artifact, index| {
        if (!Modules.validName(artifact.name) or !Archive.safeArchivePath(artifact.path) or
            !hexSha(artifact.sha256) or artifact.size > 1024 * 1024 * 1024 or
            !validTarget(artifact.target)) return error.InvalidRegistryResponse;
        var declared = false;
        for (package.artifacts) |item| {
            if (std.mem.eql(u8, item.target, artifact.target) and
                std.mem.eql(u8, item.name, artifact.name) and
                std.mem.eql(u8, item.path, artifact.path) and
                std.mem.eql(u8, item.sha256, artifact.sha256)) declared = true;
        }
        if (!declared) return error.InvalidRegistryResponse;
        for (reply.descriptor.artifacts[0..index]) |previous| {
            if (std.mem.eql(u8, previous.target, artifact.target) and
                (std.mem.eql(u8, previous.name, artifact.name) or std.mem.eql(u8, previous.path, artifact.path)))
                return error.InvalidRegistryResponse;
        }
    }
    return .{ .digest = expected_digest, .descriptor = reply.descriptor, .package = package };
}

fn validTarget(target: []const u8) bool {
    inline for (.{ "macos-arm64", "macos-x64", "linux-arm64", "linux-x64", "windows-arm64", "windows-x64" }) |known| {
        if (std.mem.eql(u8, target, known)) return true;
    }
    return false;
}

fn hexSha(digest: []const u8) bool {
    if (digest.len != 64) return false;
    for (digest) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn matches(bytes: []const u8, expected: []const u8) bool {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.mem.eql(u8, &hex, expected);
}

test "public version metadata binds exact manifest and source inventory to digest" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const manifest =
        \\{"name":"Runtime","version":"1.0.0","requires":{"silex":">=0.44.0 <0.45.0"}}
    ;
    const files: []const Archive.File = &.{
        .{ .path = "Module/Value.sx", .bytes = "public module Value {}" },
        .{ .path = "Package.json", .bytes = manifest },
    };
    const source = try Archive.encode(allocator, files);
    const rendered = try DescriptorWriter.render(allocator, files, source, &.{});
    const response = try std.fmt.allocPrint(allocator,
        "{{\"publication_sha256\":\"{s}\",\"descriptor\":{s}}}",
        .{ rendered.digest, rendered.json });
    const toolchain = try Packages.Version.parse("0.44.1");
    const selected = try parsePublication(allocator, std.testing.io, response, "Runtime", try Packages.Version.parse("1.0.0"), rendered.digest, toolchain);
    try std.testing.expectEqualStrings(rendered.source_digest, selected.descriptor.source.sha256);
    try std.testing.expectEqual(@as(usize, 2), selected.descriptor.files.len);
    const attributed = try DescriptorWriter.renderWithProvenance(allocator, files, source, &.{}, .{
        .commit = "1234567890123456789012345678901234567890",
        .repository = "https://github.com/Matanek/Silex-Registry.git",
    });
    const attributed_response = try std.fmt.allocPrint(allocator,
        "{{\"publication_sha256\":\"{s}\",\"descriptor\":{s}}}",
        .{ attributed.digest, attributed.json });
    const attributed_selected = try parsePublication(allocator, std.testing.io, attributed_response,
        "Runtime", try Packages.Version.parse("1.0.0"), attributed.digest, toolchain);
    try std.testing.expectEqualStrings("https://github.com/Matanek/Silex-Registry.git",
        attributed_selected.descriptor.provenance.?.repository);
    try std.testing.expectError(error.InvalidRegistryResponse, parsePublication(
        allocator, std.testing.io, response, "Other", try Packages.Version.parse("1.0.0"), rendered.digest, toolchain,
    ));
    try std.testing.expectError(error.InvalidRegistryResponse, parsePublication(
        allocator, std.testing.io, response, "Runtime", try Packages.Version.parse("1.0.0"), "0" ** 64, toolchain,
    ));
    const versions = try parseListing(allocator,
        try std.fmt.allocPrint(allocator, "{{\"name\":\"Runtime\",\"versions\":[{{\"version\":\"1.0.0\",\"digest\":\"{s}\"}}]}}", .{rendered.digest}),
        "Runtime");
    try std.testing.expectEqualStrings(rendered.digest, versions[0].digest);
}
