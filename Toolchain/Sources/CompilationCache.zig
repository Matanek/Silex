const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Blake3 = std.crypto.hash.Blake3;
const Ir = @import("Ir.zig");
const Ast = @import("Ast.zig");
const Boundary = @import("Boundary.zig");
const Packages = @import("Packages.zig");

pub const format = "silex-cache-v13-gfx-ecs-foundation";
const State = struct { files: []const []const u8 };

pub const NativeInput = struct {
    program: Ir.Program,
    boundaries: []const Boundary.Function,
    providers: []const Packages.BoundaryProvider,
};

pub fn loadIr(allocator: Allocator, io: Io, source_path: []const u8, target_name: []const u8) ?Ir.Program {
    const state_digest = artifactKey("frontend-state", &.{ source_path, target_name });
    const state_bytes = load(allocator, io, state_digest, "state") orelse return null;
    const state = std.json.parseFromSliceLeaky(State, allocator, state_bytes, .{}) catch return null;
    const digest = key(allocator, io, state.files, "frontend", target_name) catch return null;
    const payload = load(allocator, io, digest, "ir-json") orelse return null;
    return std.json.parseFromSliceLeaky(Ir.Program, allocator, payload, .{}) catch null;
}

pub fn storeIr(allocator: Allocator, io: Io, source_path: []const u8, target_name: []const u8, files: []const []const u8, program: Ir.Program) void {
    const digest = key(allocator, io, files, "frontend", target_name) catch return;
    const payload = std.json.Stringify.valueAlloc(allocator, program, .{}) catch return;
    store(allocator, io, digest, "ir-json", payload);
    const state_payload = std.json.Stringify.valueAlloc(allocator, State{ .files = files }, .{}) catch return;
    store(allocator, io, artifactKey("frontend-state", &.{ source_path, target_name }), "state", state_payload);
}

pub fn loadNativeInput(allocator: Allocator, io: Io, source_path: []const u8, target_name: []const u8) ?NativeInput {
    const state_digest = artifactKey("native-input-state", &.{ source_path, target_name });
    const state_bytes = load(allocator, io, state_digest, "state") orelse return null;
    const state = std.json.parseFromSliceLeaky(State, allocator, state_bytes, .{}) catch return null;
    const digest = key(allocator, io, state.files, "native-input", target_name) catch return null;
    const payload = load(allocator, io, digest, "native-input-json") orelse return null;
    return std.json.parseFromSliceLeaky(NativeInput, allocator, payload, .{}) catch null;
}

pub fn storeNativeInput(
    allocator: Allocator,
    io: Io,
    source_path: []const u8,
    target_name: []const u8,
    files: []const []const u8,
    input: NativeInput,
) void {
    const digest = key(allocator, io, files, "native-input", target_name) catch return;
    const payload = std.json.Stringify.valueAlloc(allocator, input, .{}) catch return;
    store(allocator, io, digest, "native-input-json", payload);
    const state_payload = std.json.Stringify.valueAlloc(allocator, State{ .files = files }, .{}) catch return;
    store(allocator, io, artifactKey("native-input-state", &.{ source_path, target_name }), "state", state_payload);
}

pub fn loadAst(allocator: Allocator, io: Io, path: []const u8, source: []const u8) ?Ast.Program {
    const digest = contentIdentity("module-ast", path, source);
    const payload = load(allocator, io, digest, "ast-json") orelse return null;
    return std.json.parseFromSliceLeaky(Ast.Program, allocator, payload, .{}) catch null;
}

pub fn storeAst(allocator: Allocator, io: Io, path: []const u8, source: []const u8, program: Ast.Program) void {
    const payload = std.json.Stringify.valueAlloc(allocator, program, .{}) catch return;
    store(allocator, io, contentIdentity("module-ast", path, source), "ast-json", payload);
}

fn contentIdentity(namespace: []const u8, path: []const u8, source: []const u8) [Blake3.digest_length]u8 {
    var hasher = Blake3.init(.{});
    hasher.update(format);
    hasher.update(namespace);
    hasher.update(path);
    hasher.update(source);
    var digest: [Blake3.digest_length]u8 = undefined;
    hasher.final(&digest);
    return digest;
}

pub fn artifactKey(namespace: []const u8, parts: []const []const u8) [Blake3.digest_length]u8 {
    var hasher = Blake3.init(.{});
    hasher.update(format);
    hasher.update(namespace);
    for (parts) |part| hasher.update(part);
    var digest: [Blake3.digest_length]u8 = undefined;
    hasher.final(&digest);
    return digest;
}

pub fn key(
    allocator: Allocator,
    io: Io,
    files: []const []const u8,
    command: []const u8,
    variant: []const u8,
) ![Blake3.digest_length]u8 {
    const paths = try allocator.dupe([]const u8, files);
    defer allocator.free(paths);
    std.mem.sort([]const u8, paths, {}, lessThan);
    var hasher = Blake3.init(.{});
    hasher.update(format);
    hasher.update(command);
    hasher.update(variant);
    for (paths) |path| {
        hasher.update(path);
        // Native cache keys also cover boundary archives. SDL3 alone is larger
        // than a regular source file, so the key must accept package artifacts
        // without silently disabling the linked-executable cache.
        const source = try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(512 * 1024 * 1024));
        defer allocator.free(source);
        hasher.update(source);
        hashAncestorManifests(allocator, io, &hasher, path);
    }
    var digest: [Blake3.digest_length]u8 = undefined;
    hasher.final(&digest);
    return digest;
}

fn hashAncestorManifests(allocator: Allocator, io: Io, hasher: *Blake3, source_path: []const u8) void {
    var directory = std.fs.path.dirname(source_path);
    var depth: usize = 0;
    while (directory) |current| : (depth += 1) {
        if (depth == 64) break;
        const manifest = std.fs.path.join(allocator, &.{ current, "Package.json" }) catch break;
        const contents = Io.Dir.cwd().readFileAlloc(io, manifest, allocator, .limited(1024 * 1024)) catch {
            allocator.free(manifest);
            const parent = std.fs.path.dirname(current);
            if (parent == null or std.mem.eql(u8, parent.?, current)) break;
            directory = parent;
            continue;
        };
        hasher.update(manifest);
        hasher.update(contents);
        allocator.free(manifest);
        allocator.free(contents);
        const parent = std.fs.path.dirname(current);
        if (parent == null or std.mem.eql(u8, parent.?, current)) break;
        directory = parent;
    }
    const root_manifest = Io.Dir.cwd().readFileAlloc(io, "Package.json", allocator, .limited(1024 * 1024)) catch return;
    defer allocator.free(root_manifest);
    hasher.update("Package.json");
    hasher.update(root_manifest);
}

pub fn load(allocator: Allocator, io: Io, digest: [Blake3.digest_length]u8, kind: []const u8) ?[]const u8 {
    const path = entryPath(allocator, digest, kind) catch return null;
    const bytes = Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024)) catch return null;
    if (bytes.len < digest.len or !std.mem.eql(u8, bytes[0..digest.len], &digest)) return null;
    return bytes[digest.len..];
}

pub fn store(
    allocator: Allocator,
    io: Io,
    digest: [Blake3.digest_length]u8,
    kind: []const u8,
    payload: []const u8,
) void {
    const directory = ".silex/cache/v3";
    Io.Dir.cwd().createDirPath(io, directory) catch return;
    const path = entryPath(allocator, digest, kind) catch return;
    var atomic = Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true }) catch return;
    defer atomic.deinit(io);
    atomic.file.writeStreamingAll(io, &digest) catch return;
    atomic.file.writeStreamingAll(io, payload) catch return;
    atomic.replace(io) catch return;
}

fn entryPath(allocator: Allocator, digest: [Blake3.digest_length]u8, kind: []const u8) ![]const u8 {
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, ".silex/cache/v3/{s}.{s}", .{ hex, kind });
}

fn lessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

test "cache key depends on command variant paths and exact contents" {
    const debug = try key(std.testing.allocator, std.testing.io, &.{"build.zig"}, "compile", "debug");
    const release = try key(std.testing.allocator, std.testing.io, &.{"build.zig"}, "compile", "release");
    try std.testing.expect(!std.mem.eql(u8, &debug, &release));
}

test "native input cache retains linked boundary providers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}\n" });
    const source_path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    const files = &.{source_path};
    const providers = &.{Packages.BoundaryProvider{
        .name = "SDL3",
        .archive = "Boundary/macos-arm64/libSDL3.a",
        .frameworks = &.{"Metal"},
        .libraries = &.{},
    }};
    const input = NativeInput{
        .program = .{ .functions = &.{}, .files = files },
        .boundaries = &.{},
        .providers = providers,
    };

    storeNativeInput(allocator, std.testing.io, source_path, "macos-arm64", files, input);
    const loaded = loadNativeInput(allocator, std.testing.io, source_path, "macos-arm64").?;

    try std.testing.expectEqual(@as(usize, 1), loaded.providers.len);
    try std.testing.expectEqualStrings("SDL3", loaded.providers[0].name);
    try std.testing.expectEqualStrings("Metal", loaded.providers[0].frameworks[0]);
}
