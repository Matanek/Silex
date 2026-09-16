const std = @import("std");
const Archive = @import("PackageArchive.zig");

const Allocator = std.mem.Allocator;

pub const Artifact = struct {
    target: []const u8,
    name: []const u8,
    path: []const u8,
    bytes: []const u8,
};

pub const Result = struct {
    json: []const u8,
    digest: []const u8,
    source_digest: []const u8,
};

const BlobView = struct {
    sha256: []const u8,
    size: usize,
};

const FileView = struct {
    path: []const u8,
    sha256: []const u8,
    size: usize,
};

const ArtifactView = struct {
    name: []const u8,
    path: []const u8,
    sha256: []const u8,
    size: usize,
    target: []const u8,
};

/// The field order matches the server's recursive alphabetical canonical JSON.
const Canonical = struct {
    artifacts: []const ArtifactView,
    files: []const FileView,
    manifest: []const u8,
    schema: u8 = 1,
    source: BlobView,
};

/// Describes the exact manifest and copied bytes that were used for `source`.
/// A later HTTP retry can send the same JSON without re-reading the author tree.
pub fn render(
    allocator: Allocator,
    files: []const Archive.File,
    source: []const u8,
    artifacts: []const Artifact,
) !Result {
    var manifest: ?[]const u8 = null;
    const file_views = try allocator.alloc(FileView, files.len);
    for (files, file_views) |file, *view| {
        if (std.mem.eql(u8, file.path, "Package.json")) manifest = file.bytes;
        view.* = .{
            .path = file.path,
            .sha256 = try sha256Hex(allocator, file.bytes),
            .size = file.bytes.len,
        };
    }
    if (manifest == null or !std.unicode.utf8ValidateSlice(manifest.?)) return error.InvalidManifest;

    const artifact_views = try allocator.alloc(ArtifactView, artifacts.len);
    for (artifacts, artifact_views) |artifact, *view| {
        view.* = .{
            .name = artifact.name,
            .path = artifact.path,
            .sha256 = try sha256Hex(allocator, artifact.bytes),
            .size = artifact.bytes.len,
            .target = artifact.target,
        };
    }
    const source_digest = try sha256Hex(allocator, source);
    const json = try std.json.Stringify.valueAlloc(allocator, Canonical{
        .artifacts = artifact_views,
        .files = file_views,
        .manifest = manifest.?,
        .source = .{ .sha256 = source_digest, .size = source.len },
    }, .{});
    return .{
        .json = json,
        .digest = try sha256Hex(allocator, json),
        .source_digest = source_digest,
    };
}

fn sha256Hex(allocator: Allocator, bytes: []const u8) ![]const u8 {
    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return allocator.dupe(u8, &std.fmt.bytesToHex(digest, .lower));
}

test "descriptor is canonical for the exact manifest and source archive" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const files: []const Archive.File = &.{
        .{ .path = "Package.json", .bytes = "{\"name\":\"LocalDemo\",\"version\":\"1.0.0\",\"requires\":{\"silex\":\">=0.44.0\"}}\n" },
        .{ .path = "Module/Content.sx", .bytes = "public func answer() int { return 42 }\n" },
    };
    const source = try Archive.encode(allocator, files);
    const result = try render(allocator, files, source, &.{});
    try std.testing.expect(std.mem.startsWith(u8, result.json, "{\"artifacts\":[],\"files\":["));
    try std.testing.expect(std.mem.indexOf(u8, result.json, "\"manifest\":\"{\\\"name\\\":\\\"LocalDemo\\\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, result.json, "\"schema\":1,\"source\":{") != null);
    try std.testing.expectEqual(@as(usize, 64), result.digest.len);
    try std.testing.expectEqualStrings(try sha256Hex(allocator, source), result.source_digest);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, result.json, .{});
    try std.testing.expectEqual(@as(i64, 1), parsed.value.object.get("schema").?.integer);
    const entries = parsed.value.object.get("files").?.array.items;
    try std.testing.expectEqual(@as(usize, 2), entries.len);
    try std.testing.expectEqualStrings("Package.json", entries[0].object.get("path").?.string);
    try std.testing.expectEqualStrings(try sha256Hex(allocator, files[0].bytes), entries[0].object.get("sha256").?.string);
}

test "descriptor requires a copied manifest" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try std.testing.expectError(error.InvalidManifest, render(allocator, &.{.{ .path = "Module/Content.sx", .bytes = "x" }}, "gzip", &.{}));
}
