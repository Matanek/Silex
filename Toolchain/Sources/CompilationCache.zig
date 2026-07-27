const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Blake3 = std.crypto.hash.Blake3;
const Ir = @import("Ir.zig");
const Ast = @import("Ast.zig");

pub const format = "silex-cache-v3-control-flow-safety";
const State = struct { files: []const []const u8 };

pub fn loadIr(allocator: Allocator, io: Io, source_path: []const u8) ?Ir.Program {
    const state_digest = identity("frontend-state", source_path);
    const state_bytes = load(allocator, io, state_digest, "state") orelse return null;
    const state = std.json.parseFromSliceLeaky(State, allocator, state_bytes, .{}) catch return null;
    const digest = key(allocator, io, state.files, "frontend", source_path) catch return null;
    const payload = load(allocator, io, digest, "ir-json") orelse return null;
    return std.json.parseFromSliceLeaky(Ir.Program, allocator, payload, .{}) catch null;
}

pub fn storeIr(allocator: Allocator, io: Io, source_path: []const u8, files: []const []const u8, program: Ir.Program) void {
    const digest = key(allocator, io, files, "frontend", source_path) catch return;
    const payload = std.json.Stringify.valueAlloc(allocator, program, .{}) catch return;
    store(allocator, io, digest, "ir-json", payload);
    const state_payload = std.json.Stringify.valueAlloc(allocator, State{ .files = files }, .{}) catch return;
    store(allocator, io, identity("frontend-state", source_path), "state", state_payload);
}

fn identity(namespace: []const u8, value: []const u8) [Blake3.digest_length]u8 {
    var hasher = Blake3.init(.{});
    hasher.update(format);
    hasher.update(namespace);
    hasher.update(value);
    var digest: [Blake3.digest_length]u8 = undefined;
    hasher.final(&digest);
    return digest;
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
        const source = try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(16 * 1024 * 1024));
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
