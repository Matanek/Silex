const std = @import("std");
const Archive = @import("PackageArchive.zig");
const Descriptor = @import("PackageDescriptor.zig");
const Inventory = @import("PackageInventory.zig");
const Packages = @import("Packages.zig");
const Project = @import("Project.zig");
const Resources = @import("PackageResources.zig");
const Snapshot = @import("PackageSnapshot.zig");
const TargetModule = @import("Target.zig");
const Unicode = @import("PackageUnicode.zig");

const Io = std.Io;

pub const Prepared = struct {
    name: []const u8,
    version: Packages.Version,
    files: []const Archive.File,
    source: []const u8,
    descriptor: Descriptor.Result,
    repository: ?[]const u8,
    artifacts: []const Descriptor.Artifact,
    exclusions: []const Exclusion,
};

pub const Exclusion = struct {
    path: []const u8,
    reason: []const u8,
};

pub const Manager = struct {
    allocator: std.mem.Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    diagnostic: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, io: Io, global_packages_root: ?[]const u8) Manager {
        return .{ .allocator = allocator, .io = io, .global_packages_root = global_packages_root };
    }

    /// Prepare exactly one immutable source publication. Network transfer and
    /// credentials are deliberately outside this operation, so `--dry-run`
    /// exercises the same manifest, compiler, snapshot and descriptor path.
    pub fn prepare(self: *Manager, package_root: []const u8) !Prepared {
        self.diagnostic = null;
        const host = TargetModule.Target.host() orelse TargetModule.Target.macos_arm64;
        var resolver = Packages.Resolver.initForTarget(self.allocator, self.io, self.global_packages_root, host);
        const manifest = resolver.inspectPackage(package_root) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.fail(resolver.diagnostic orelse "invalid package manifest"),
            else => |other| return other,
        };
        const sources = Inventory.collectSources(self.allocator, self.io, package_root, manifest.sources, manifest.name) catch |err| {
            return self.fail(try std.fmt.allocPrint(self.allocator, "package source inventory failed: {s}", .{@errorName(err)}));
        };
        var uses: std.ArrayList(@import("EmbeddedFiles.zig").Use) = .empty;
        for (sources) |relative| {
            const source_path = try std.fs.path.join(self.allocator, &.{ package_root, relative });
            var compiler = Project.Compiler.initWithPackages(self.allocator, self.io, self.global_packages_root);
            compiler.target = targetForSource(relative, host) catch return self.fail("package source uses an unsupported Platform or Target variant");
            const compilation = compiler.compileTests(source_path) catch |err| switch (err) {
                error.InvalidSource, error.InvalidPackageGraph => return self.fail(compiler.diagnosticMessage() orelse "package source does not compile"),
                error.ReadFailed => return self.fail("cannot read a package source during publication"),
                else => |other| return other,
            };
            try uses.appendSlice(self.allocator, compilation.embedded_file_uses);
        }
        const resources = Resources.select(self.allocator, package_root, uses.items) catch |err| switch (err) {
            error.ResourceOutsidePackage => return self.fail("a package source embeds a file outside the package"),
            else => |other| return other,
        };

        var selected: std.ArrayList([]const u8) = .empty;
        try appendUnique(self.allocator, &selected, "Package.json");
        for (sources) |path| try appendUnique(self.allocator, &selected, path);
        for (resources) |path| try appendUnique(self.allocator, &selected, path);
        for (manifest.boundary_archives) |path| {
            if (!artifactAt(manifest.artifacts, path)) try appendUnique(self.allocator, &selected, path);
        }
        for ([_][]const u8{ "README.md", "README", "LICENSE", "LICENSE.md", "NOTICE" }) |name| {
            if (try optionalRegularFile(self.allocator, self.io, package_root, name)) try appendUnique(self.allocator, &selected, name);
        }
        validatePortablePaths(self.allocator, selected.items, manifest.artifacts) catch |err| switch (err) {
            error.NonNormalizedPath => return self.fail("package publication paths must use Unicode NFC"),
            error.PathCollision => return self.fail("package publication paths collide after Unicode lowercase comparison"),
            else => |other| return other,
        };
        const artifacts = captureArtifacts(self.allocator, self.io, package_root, manifest.artifacts) catch |err| switch (err) {
            error.MissingFile => return self.fail("a declared artifact is missing; run 'silex install <package-directory>'"),
            error.FileChanged => return self.fail("a declared artifact changed during preparation"),
            error.InvalidPath, error.UnsafeEntry => return self.fail("a declared artifact path is unsafe or is not a regular file"),
            error.FileLimit => return self.fail("a declared artifact exceeds the registry object limit"),
            error.ArtifactDigestMismatch => return self.fail("a declared artifact does not match its sha256"),
            error.ArtifactPathCollision => return self.fail("declared artifact destinations collide for one target"),
            error.ReadFailed => return self.fail("cannot read a declared artifact"),
            else => |other| return other,
        };
        const exclusions = collectExclusions(self.allocator, self.io, package_root, selected.items, manifest.artifacts) catch |err| switch (err) {
            error.UnsafeEntry => return self.fail("package contains a symbolic link, hard link or special entry outside excluded infrastructure"),
            error.ArtifactPathCollision => return self.fail("a declared artifact path collides with a source file"),
            else => |other| return other,
        };
        const files = Snapshot.captureSelected(self.allocator, self.io, package_root, selected.items) catch |err| switch (err) {
            error.MissingFile => return self.fail("a selected package file disappeared during preparation"),
            error.FileChanged => return self.fail("a selected package file changed during preparation"),
            error.UnsafeEntry => return self.fail("a selected package entry is a link or is not a regular file"),
            error.ReadFailed => return self.fail("cannot read a selected package file"),
            else => |other| return other,
        };
        const source = try Archive.encode(self.allocator, files);
        const descriptor = try Descriptor.render(self.allocator, files, source, artifacts);
        return .{ .name = manifest.name, .version = manifest.version, .files = files, .source = source, .descriptor = descriptor, .repository = manifest.repository, .artifacts = artifacts, .exclusions = exclusions };
    }

    fn fail(self: *Manager, message: []const u8) error{InvalidPackagePublication} {
        self.diagnostic = message;
        return error.InvalidPackagePublication;
    }
};

fn targetForSource(relative: []const u8, fallback: TargetModule.Target) !TargetModule.Target {
    if (componentAfter(relative, "Target/")) |name| return TargetModule.Target.parse(name);
    if (componentAfter(relative, "Platform/")) |name| {
        for (TargetModule.Target.recognized) |target| if (std.mem.eql(u8, target.platform.directoryName(), name)) return target;
        return error.UnknownTarget;
    }
    return fallback;
}

fn appendUnique(allocator: std.mem.Allocator, paths: *std.ArrayList([]const u8), path: []const u8) !void {
    for (paths.items) |existing| if (std.mem.eql(u8, existing, path)) return;
    try paths.append(allocator, path);
}

fn collectExclusions(
    allocator: std.mem.Allocator,
    io: Io,
    root_path: []const u8,
    selected: []const []const u8,
    artifacts: []const Packages.ManifestArtifact,
) ![]const Exclusion {
    var root = Io.Dir.cwd().openDir(io, root_path, .{ .iterate = true, .follow_symlinks = false }) catch return error.UnsafeEntry;
    defer root.close(io);
    var walker = try root.walk(allocator);
    defer walker.deinit();
    var result: std.ArrayList(Exclusion) = .empty;
    while (try walker.next(io)) |entry| {
        const path = try portablePath(allocator, entry.path);
        if (entry.kind == .directory and excludedInfrastructure(entry.basename)) {
            walker.leave(io);
            const shown = try std.fmt.allocPrint(allocator, "{s}/", .{path});
            allocator.free(path);
            try result.append(allocator, .{ .path = shown, .reason = "infrastructure directory" });
            continue;
        }
        if (entry.kind == .directory) {
            allocator.free(path);
            continue;
        }
        if (entry.kind != .file) return error.UnsafeEntry;
        const stat = entry.dir.statFile(io, entry.basename, .{ .follow_symlinks = false }) catch return error.UnsafeEntry;
        if (stat.kind != .file or stat.nlink != 1) return error.UnsafeEntry;
        if (contains(selected, path)) {
            if (artifactAt(artifacts, path)) return error.ArtifactPathCollision;
            allocator.free(path);
            continue;
        }
        try result.append(allocator, .{
            .path = path,
            .reason = if (artifactAt(artifacts, path))
                "declared artifact sent as a separate object"
            else
                "not selected by the manifest or source analysis",
        });
    }
    std.mem.sort(Exclusion, result.items, {}, exclusionLessThan);
    return result.toOwnedSlice(allocator);
}

fn captureArtifacts(
    allocator: std.mem.Allocator,
    io: Io,
    package_root: []const u8,
    declarations: []const Packages.ManifestArtifact,
) ![]const Descriptor.Artifact {
    const result = try allocator.alloc(Descriptor.Artifact, declarations.len);
    var copied: usize = 0;
    errdefer {
        for (result[0..copied]) |artifact| allocator.free(artifact.bytes);
        allocator.free(result);
    }
    for (declarations, result, 0..) |declaration, *artifact, index| {
        for (declarations[0..index]) |previous| {
            if (!std.mem.eql(u8, previous.target, declaration.target)) continue;
            if (pathsCollide(previous.path, declaration.path)) return error.ArtifactPathCollision;
        }
        const bytes = try Snapshot.copyFileLimited(allocator, io, package_root, declaration.path, 1024 * 1024 * 1024);
        var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        const actual = std.fmt.bytesToHex(digest, .lower);
        if (!std.mem.eql(u8, &actual, declaration.sha256)) {
            allocator.free(bytes);
            return error.ArtifactDigestMismatch;
        }
        artifact.* = .{
            .target = declaration.target,
            .name = declaration.name,
            .path = declaration.path,
            .bytes = bytes,
        };
        copied += 1;
    }
    return result;
}

fn artifactAt(artifacts: []const Packages.ManifestArtifact, path: []const u8) bool {
    for (artifacts) |artifact| if (std.mem.eql(u8, artifact.path, path)) return true;
    return false;
}

fn pathsCollide(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right) or
        (left.len < right.len and std.mem.startsWith(u8, right, left) and right[left.len] == '/') or
        (right.len < left.len and std.mem.startsWith(u8, left, right) and left[right.len] == '/');
}

const PortablePath = struct {
    key: []const u8,
    target: ?[]const u8,
};

fn validatePortablePaths(
    allocator: std.mem.Allocator,
    sources: []const []const u8,
    artifacts: []const Packages.ManifestArtifact,
) !void {
    var paths: std.ArrayList(PortablePath) = .empty;
    defer {
        for (paths.items) |path| allocator.free(path.key);
        paths.deinit(allocator);
    }
    for (sources) |source| {
        const normalized = Unicode.isNfc(allocator, source) catch |err| switch (err) {
            error.InvalidUtf8 => return error.NonNormalizedPath,
            else => |other| return other,
        };
        if (!normalized) return error.NonNormalizedPath;
        const key = Unicode.lowercase(allocator, source) catch |err| switch (err) {
            error.InvalidUtf8 => return error.NonNormalizedPath,
            else => |other| return other,
        };
        errdefer allocator.free(key);
        for (paths.items) |previous| if (pathsCollide(previous.key, key)) return error.PathCollision;
        try paths.append(allocator, .{ .key = key, .target = null });
    }
    for (artifacts) |artifact| {
        const normalized = Unicode.isNfc(allocator, artifact.path) catch |err| switch (err) {
            error.InvalidUtf8 => return error.NonNormalizedPath,
            else => |other| return other,
        };
        if (!normalized) return error.NonNormalizedPath;
        const key = Unicode.lowercase(allocator, artifact.path) catch |err| switch (err) {
            error.InvalidUtf8 => return error.NonNormalizedPath,
            else => |other| return other,
        };
        errdefer allocator.free(key);
        for (paths.items) |previous| {
            if (previous.target == null or std.mem.eql(u8, previous.target.?, artifact.target)) {
                if (pathsCollide(previous.key, key)) return error.PathCollision;
            }
        }
        try paths.append(allocator, .{ .key = key, .target = artifact.target });
    }
}

fn portablePath(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    const result = try allocator.dupe(u8, path);
    for (result) |*byte| if (byte.* == '\\') {
        byte.* = '/';
    };
    return result;
}

fn contains(paths: []const []const u8, path: []const u8) bool {
    for (paths) |candidate| if (std.mem.eql(u8, candidate, path)) return true;
    return false;
}

fn excludedInfrastructure(name: []const u8) bool {
    return std.ascii.eqlIgnoreCase(name, ".git") or std.ascii.eqlIgnoreCase(name, ".silex") or
        std.ascii.eqlIgnoreCase(name, ".zig-cache") or std.ascii.eqlIgnoreCase(name, "zig-out");
}

fn exclusionLessThan(_: void, left: Exclusion, right: Exclusion) bool {
    return std.mem.lessThan(u8, left.path, right.path);
}

fn componentAfter(path: []const u8, prefix: []const u8) ?[]const u8 {
    if (!std.mem.startsWith(u8, path, prefix)) return null;
    const rest = path[prefix.len..];
    const end = std.mem.indexOfScalar(u8, rest, '/') orelse return null;
    return rest[0..end];
}

fn optionalRegularFile(allocator: std.mem.Allocator, io: Io, root: []const u8, name: []const u8) !bool {
    const path = try std.fs.path.join(allocator, &.{ root, name });
    defer allocator.free(path);
    const stat = Io.Dir.cwd().statFile(io, path, .{ .follow_symlinks = false }) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => return error.UnsafeEntry,
    };
    if (stat.kind != .file or stat.nlink != 1) return error.UnsafeEntry;
    return true;
}

test "prepare a modified local package without Git or cache files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "LocalDemo/Module");
    try temporary.dir.createDirPath(std.testing.io, "LocalDemo/.silex/cache");
    try temporary.dir.createDirPath(std.testing.io, "LocalDemo/Boundary/macos-arm64");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Package.json", .data = "{\"name\":\"LocalDemo\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.44.0\"},\"artifacts\":{\"macos-arm64\":{\"Demo\":{\"path\":\"Boundary/macos-arm64/libDemo.a\",\"sha256\":\"6c227048ddc712dcb6b6519e44011b8c3e13e4307bd6c12ffbf5e8539405e4fd\"}}}}\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Module/Content.sx", .data =
        \\public func answer() int { return 42 }
        \\func main() {
        \\    let file = "Message.txt"
        \\    print(embed_text(file))
        \\}
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Module/Message.txt", .data = "modified before publication\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/README.md", .data = "Local package\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/.silex/cache/secret", .data = "excluded" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Boundary/macos-arm64/libDemo.a", .data = "native artifact\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Notes.tmp", .data = "not selected" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "LocalDemo" });
    var manager = Manager.init(allocator, std.testing.io, null);
    const prepared = try manager.prepare(root);
    try std.testing.expectEqualStrings("LocalDemo", prepared.name);
    try std.testing.expectEqual(@as(usize, 4), prepared.files.len);
    try std.testing.expect(std.mem.indexOf(u8, prepared.descriptor.json, ".silex") == null);
    try std.testing.expectEqual(@as(usize, 3), prepared.exclusions.len);
    try std.testing.expectEqualStrings(".silex/", prepared.exclusions[0].path);
    try std.testing.expectEqualStrings("Boundary/macos-arm64/libDemo.a", prepared.exclusions[1].path);
    try std.testing.expectEqualStrings("declared artifact sent as a separate object", prepared.exclusions[1].reason);
    try std.testing.expectEqualStrings("Notes.tmp", prepared.exclusions[2].path);
    try std.testing.expectEqual(@as(usize, 1), prepared.artifacts.len);
    try std.testing.expectEqualStrings("macos-arm64", prepared.artifacts[0].target);
    try std.testing.expectEqualStrings("Demo", prepared.artifacts[0].name);
    try std.testing.expectEqualStrings("native artifact\n", prepared.artifacts[0].bytes);
    try std.testing.expect(std.mem.indexOf(u8, prepared.descriptor.json, "\"target\":\"macos-arm64\"") != null);
    const resource = for (prepared.files) |file| {
        if (std.mem.eql(u8, file.path, "Module/Message.txt")) break file;
    } else return error.TestExpectedEqual;
    try std.testing.expectEqualStrings("modified before publication\n", resource.bytes);

    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "LocalDemo/Boundary/macos-arm64/libDemo.a", .data = "tampered artifact\n" });
    manager = Manager.init(allocator, std.testing.io, null);
    try std.testing.expectError(error.InvalidPackagePublication, manager.prepare(root));
    try std.testing.expectEqualStrings("a declared artifact does not match its sha256", manager.diagnostic.?);
}

test "publish native boundary archives for every declared target" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Portable/Module");
    try temporary.dir.createDirPath(std.testing.io, "Portable/Boundary/macos-x64");
    try temporary.dir.createDirPath(std.testing.io, "Portable/Boundary/linux-x64");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Portable/Package.json", .data =
        "{\"name\":\"Portable\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.44.0\"}," ++
        "\"boundary\":{\"macos-x64\":{\"providers\":{\"Native\":{\"archive\":\"Boundary/macos-x64/libNative.a\"}}}," ++
        "\"linux-x64\":{\"providers\":{\"Native\":{\"archive\":\"Boundary/linux-x64/libNative.a\"}}}}}\n",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Portable/Module/Value.sx", .data =
        "public func answer() int { return 42 }\n" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Portable/Boundary/macos-x64/libNative.a", .data = "macOS bytes" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Portable/Boundary/linux-x64/libNative.a", .data = "Linux bytes" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Portable" });
    var manager = Manager.init(allocator, std.testing.io, null);
    const prepared = try manager.prepare(root);
    try std.testing.expectEqual(@as(usize, 4), prepared.files.len);
    try std.testing.expect(containsFile(prepared.files, "Boundary/macos-x64/libNative.a"));
    try std.testing.expect(containsFile(prepared.files, "Boundary/linux-x64/libNative.a"));
}

fn containsFile(files: []const Archive.File, path: []const u8) bool {
    for (files) |file| if (std.mem.eql(u8, file.path, path)) return true;
    return false;
}

test "reject non-NFC and Unicode lowercase publication collisions" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.NonNormalizedPath, validatePortablePaths(allocator, &.{"Module/Re\u{301}sume\u{301}.sx"}, &.{}));
    try std.testing.expectError(error.PathCollision, validatePortablePaths(allocator, &.{ "Module/Data.sx", "module/data.sx" }, &.{}));
    try std.testing.expectError(error.PathCollision, validatePortablePaths(allocator, &.{"Module/École.sx"}, &.{.{
        .target = "linux-x64",
        .name = "Runtime",
        .path = "module/école.sx",
        .sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    }}));
    try validatePortablePaths(allocator, &.{"Module/Content.sx"}, &.{
        .{ .target = "linux-x64", .name = "Runtime", .path = "Boundary/Runtime.a", .sha256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" },
        .{ .target = "windows-x64", .name = "Runtime", .path = "boundary/runtime.a", .sha256 = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
    });
}
