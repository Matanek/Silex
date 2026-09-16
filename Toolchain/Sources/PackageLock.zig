const std = @import("std");
const Packages = @import("Packages.zig");

const Io = std.Io;
const Allocator = std.mem.Allocator;

const Receipt = struct {
    schema: u8,
    name: []const u8,
    version: []const u8,
    publication_sha256: []const u8,
    source_sha256: []const u8,
    manifest_sha256: []const u8,
    dependencies: []const Packages.LockedDependency,
    artifacts: []const Packages.ManifestArtifact,
};

/// Installing from a project directory records the exact resolved closure.
/// The resolver reads this file on later builds; a new version in the global
/// store alone cannot change the project's selected packages.
pub fn writeProject(
    allocator: Allocator,
    io: Io,
    project_root: []const u8,
    global_root: []const u8,
    requested: Packages.LockedDependency,
) !bool {
    const manifest_path = try std.fs.path.join(allocator, &.{ project_root, "Package.json" });
    const manifest = Io.Dir.cwd().readFileAlloc(io, manifest_path, allocator, .limited(1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => return err,
    };
    var resolver = Packages.Resolver.init(allocator, io, global_root);
    resolver.ignore_project_lock = true;
    resolver.explicit_pin = requested;
    const graph = try resolver.resolve(project_root);
    const nodes = try allocator.alloc(Packages.LockedPackage, graph.packages.len - 1);
    for (graph.packages[1..], nodes) |package, *node| {
        if (package.origin != .installed) return error.LinkedProjectCannotBeLocked;
        const name = package.name orelse return error.InvalidPackageLock;
        const version = package.version orelse return error.InvalidPackageLock;
        const receipt_path = try std.fs.path.join(allocator, &.{ package.root, ".silex", "source.json" });
        const source = try Io.Dir.cwd().readFileAlloc(io, receipt_path, allocator, .limited(1024 * 1024));
        const receipt = std.json.parseFromSliceLeaky(Receipt, allocator, source, .{
            .allocate = .alloc_always,
            .ignore_unknown_fields = true,
        }) catch return error.InvalidPackageLock;
        const version_string = try versionText(allocator, version);
        if (receipt.schema != 4 or !std.mem.eql(u8, receipt.name, name) or
            !std.mem.eql(u8, receipt.version, version_string)) return error.InvalidPackageLock;
        const inspected = try resolver.inspectPackage(package.root);
        const edges = try allocator.alloc(Packages.LockedDependency, package.dependencies.len);
        for (package.dependencies, edges) |dependency, *edge| {
            const selected = graph.packages[dependency.package];
            edge.* = .{
                .name = dependency.name,
                .version = try versionText(allocator, selected.version orelse return error.InvalidPackageLock),
            };
        }
        if (receipt.dependencies.len != edges.len) return error.InvalidPackageLock;
        for (edges, receipt.dependencies) |edge, received| {
            if (!std.mem.eql(u8, edge.name, received.name) or
                !std.mem.eql(u8, edge.version, received.version)) return error.InvalidPackageLock;
        }
        for (receipt.artifacts) |acquired| {
            var declared = false;
            for (inspected.artifacts) |artifact| {
                if (std.mem.eql(u8, artifact.target, acquired.target) and
                    std.mem.eql(u8, artifact.name, acquired.name) and
                    std.mem.eql(u8, artifact.path, acquired.path) and
                    std.mem.eql(u8, artifact.sha256, acquired.sha256)) declared = true;
            }
            if (!declared) return error.InvalidPackageLock;
        }
        node.* = .{
            .name = name,
            .version = version_string,
            .publication_sha256 = receipt.publication_sha256,
            .source_sha256 = receipt.source_sha256,
            .manifest_sha256 = receipt.manifest_sha256,
            .dependencies = edges,
            .artifacts = inspected.artifacts,
        };
    }
    const lock: Packages.ProjectLock = .{
        .manifest_sha256 = try digest(allocator, manifest),
        .packages = nodes,
    };
    const payload = try std.json.Stringify.valueAlloc(allocator, lock, .{ .whitespace = .indent_2 });
    const destination = try std.fs.path.join(allocator, &.{ project_root, "Silex.lock.json" });
    const temporary = try std.fs.path.join(allocator, &.{ project_root, ".Silex.lock.json.tmp" });
    const file = try Io.Dir.cwd().createFile(io, temporary, .{ .exclusive = true });
    var open = true;
    defer if (open) file.close(io);
    var published = false;
    defer if (!published) Io.Dir.cwd().deleteFile(io, temporary) catch {};
    try file.writeStreamingAll(io, payload);
    try file.sync(io);
    file.close(io);
    open = false;
    try Io.Dir.cwd().rename(temporary, Io.Dir.cwd(), destination, io);
    published = true;
    return true;
}

fn versionText(allocator: Allocator, version: Packages.Version) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d}.{d}.{d}", .{ version.major, version.minor, version.patch });
}

fn digest(allocator: Allocator, bytes: []const u8) ![]const u8 {
    var actual: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &actual, .{});
    const hex = std.fmt.bytesToHex(actual, .lower);
    return allocator.dupe(u8, &hex);
}
