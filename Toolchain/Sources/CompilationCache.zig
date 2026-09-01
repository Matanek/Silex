const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Blake3 = std.crypto.hash.Blake3;
const Ir = @import("Ir.zig");
const Ast = @import("Ast.zig");
const Packages = @import("Packages.zig");

// This identity describes the on-disk schema only. Compiler implementation
// changes are covered automatically by the digest of the running executable.
pub const format = "silex-cache-v80-compiler-identity";
const State = struct { files: []const []const u8 };

const generated_cache_roots = [_][]const u8{
    ".silex/cache/v4",
    ".silex/cache/shaders",
    ".silex/artifacts/v1",
    ".silex/run",
    ".silex/test",
};

// Part03 measured a 269 MiB peak for the representative GFX working set.
// Keep modest headroom for that set while bounding retained history globally,
// rather than adding independent per-directory quotas.
const rolling_history_reserve: u64 = 320 * 1024 * 1024;

// Cache entry helpers do not carry Io through every backend layer. CLI cache
// entry points initialize this once, before any cache key is computed.
var active_compiler_identity: ?[Blake3.digest_length]u8 = null;
var active_session_started_at: ?i96 = null;
var active_statistics: Statistics = .{};

pub const Statistics = struct {
    entry_hits: usize = 0,
    entry_misses: usize = 0,
    bytes_read: usize = 0,
    bytes_written: usize = 0,
};

pub fn statistics() Statistics {
    return active_statistics;
}

pub const NativeState = struct {
    files: []const []const u8,
    providers: []const Packages.BoundaryProvider,
};

const RetainedFile = struct {
    path: []const u8,
    size: u64,
    modified: i96,
    kind: enum { file, tree },
};

pub fn maintain(allocator: Allocator, io: Io) void {
    active_statistics = .{};
    active_session_started_at = Io.Clock.real.now(io).nanoseconds;
    const identity = ensureCompilerIdentity(io) catch {
        // If the running executable cannot be identified, preserving old
        // generated code would be unsafe. Keep caching usable for this process,
        // but start it from an empty generation on every invocation.
        clearGeneratedCache(io);
        active_compiler_identity = fallbackCompilerIdentity();
        return;
    };
    synchronizeCompilerGeneration(allocator, io, ".silex", identity);

    // These locations used to retain one large object or executable per output
    // path. They are disposable compiler state and are superseded by v4 and
    // the content-addressed artifact store.
    Io.Dir.cwd().deleteTree(io, ".silex/cache/v3") catch {};
    Io.Dir.cwd().deleteTree(io, ".silex/link") catch {};

    const marker = ".silex/maintenance-v5";
    const now = Io.Clock.real.now(io).nanoseconds;
    if (Io.Dir.cwd().statFile(io, marker, .{})) |status| {
        if (now - status.mtime.nanoseconds < 24 * std.time.ns_per_hour) return;
    } else |_| {}

    deleteKind(io, ".silex/cache/v4", ".native-input-json");
    deleteKind(io, ".silex/cache/v4", ".ast-json");
    Io.Dir.cwd().createDirPath(io, ".silex") catch return;
    const file = Io.Dir.cwd().createFile(io, marker, .{}) catch return;
    file.close(io);
}

pub fn maintainAfterMutation(allocator: Allocator, io: Io) void {
    const started_at = active_session_started_at orelse Io.Clock.real.now(io).nanoseconds;
    maintainRootAfterMutation(allocator, io, ".silex", rolling_history_reserve, started_at);
}

fn deleteKind(io: Io, path: []const u8, suffix: []const u8) void {
    var directory = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return;
    defer directory.close(io);
    var iterator = directory.iterateAssumeFirstIteration();
    while (iterator.next(io) catch null) |entry| {
        if (entry.kind == .file and std.mem.endsWith(u8, entry.name, suffix)) {
            directory.deleteFile(io, entry.name) catch {};
        }
    }
}

fn collectFiles(
    allocator: Allocator,
    io: Io,
    path: []const u8,
    retained: *std.ArrayList(RetainedFile),
    total: *u64,
    current: *u64,
    session_started_at: i96,
) void {
    var directory = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return;
    defer directory.close(io);
    var iterator = directory.iterateAssumeFirstIteration();
    while (iterator.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        const status = directory.statFile(io, entry.name, .{}) catch continue;
        const entry_path = std.fs.path.join(allocator, &.{ path, entry.name }) catch return;
        retained.append(allocator, .{
            .path = entry_path,
            .size = status.size,
            .modified = status.mtime.nanoseconds,
            .kind = .file,
        }) catch return;
        total.* += status.size;
        if (status.mtime.nanoseconds >= session_started_at) current.* += status.size;
    }
}

fn collectTrees(
    allocator: Allocator,
    io: Io,
    path: []const u8,
    retained: *std.ArrayList(RetainedFile),
    total: *u64,
    current: *u64,
    session_started_at: i96,
) void {
    var directory = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return;
    defer directory.close(io);
    var iterator = directory.iterateAssumeFirstIteration();
    while (iterator.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        const tree = tree: {
            var child = directory.openDir(io, entry.name, .{ .iterate = true }) catch continue;
            defer child.close(io);
            var walker = child.walk(allocator) catch continue;
            defer walker.deinit();
            var bytes: u64 = 0;
            var modified: i96 = 0;
            while (walker.next(io) catch null) |nested| {
                if (nested.kind != .file) continue;
                const status = child.statFile(io, nested.path, .{}) catch continue;
                bytes += status.size;
                modified = @max(modified, status.mtime.nanoseconds);
            }
            break :tree .{ .size = bytes, .modified = modified };
        };
        const entry_path = std.fs.path.join(allocator, &.{ path, entry.name }) catch return;
        retained.append(allocator, .{
            .path = entry_path,
            .size = tree.size,
            .modified = tree.modified,
            .kind = .tree,
        }) catch return;
        total.* += tree.size;
        if (tree.modified >= session_started_at) current.* += tree.size;
    }
}

fn maintainRootAfterMutation(
    allocator: Allocator,
    io: Io,
    root: []const u8,
    history_reserve: u64,
    session_started_at: i96,
) void {
    var retained: std.ArrayList(RetainedFile) = .empty;
    var total: u64 = 0;
    var current: u64 = 0;
    const flat_roots = [_][]const u8{ "cache/v4", "artifacts/v1", "run", "test" };
    for (flat_roots) |relative| {
        const path = std.fs.path.join(allocator, &.{ root, relative }) catch continue;
        defer allocator.free(path);
        collectFiles(allocator, io, path, &retained, &total, &current, session_started_at);
    }
    const shader_root = std.fs.path.join(allocator, &.{ root, "cache/shaders" }) catch return;
    defer allocator.free(shader_root);
    collectTrees(allocator, io, shader_root, &retained, &total, &current, session_started_at);

    const retained_limit = @max(history_reserve, current);
    if (total <= retained_limit) return;
    std.mem.sort(RetainedFile, retained.items, {}, oldestFirst);
    for (retained.items) |entry| {
        if (total <= retained_limit) break;
        if (entry.modified >= session_started_at) continue;
        switch (entry.kind) {
            .file => Io.Dir.cwd().deleteFile(io, entry.path) catch continue,
            .tree => Io.Dir.cwd().deleteTree(io, entry.path) catch continue,
        }
        total -= entry.size;
    }
}

fn oldestFirst(_: void, left: RetainedFile, right: RetainedFile) bool {
    if (left.modified != right.modified) return left.modified < right.modified;
    return std.mem.lessThan(u8, left.path, right.path);
}

fn ensureCompilerIdentity(io: Io) ![Blake3.digest_length]u8 {
    if (active_compiler_identity) |identity| return identity;
    const executable = try std.process.openExecutable(io, .{});
    defer executable.close(io);
    var hasher = Blake3.init(.{});
    var buffer: [64 * 1024]u8 = undefined;
    var offset: u64 = 0;
    while (true) {
        const amount = try executable.readPositionalAll(io, &buffer, offset);
        if (amount == 0) break;
        hasher.update(buffer[0..amount]);
        offset += amount;
    }
    var identity: [Blake3.digest_length]u8 = undefined;
    hasher.final(&identity);
    active_compiler_identity = identity;
    return identity;
}

fn fallbackCompilerIdentity() [Blake3.digest_length]u8 {
    var identity: [Blake3.digest_length]u8 = undefined;
    Blake3.hash(format, &identity, .{});
    return identity;
}

fn synchronizeCompilerGeneration(
    allocator: Allocator,
    io: Io,
    root: []const u8,
    identity: [Blake3.digest_length]u8,
) void {
    const marker = std.fs.path.join(allocator, &.{ root, "compiler-identity-v1" }) catch return;
    defer allocator.free(marker);
    const hex = std.fmt.bytesToHex(identity, .lower);
    const current = Io.Dir.cwd().readFileAlloc(io, marker, allocator, .limited(hex.len + 1)) catch null;
    if (current) |contents| {
        defer allocator.free(contents);
        if (std.mem.eql(u8, contents, &hex)) return;
    }

    clearGeneratedCacheAt(allocator, io, root);
    Io.Dir.cwd().createDirPath(io, root) catch return;
    var atomic = Io.Dir.cwd().createFileAtomic(io, marker, .{ .make_path = true, .replace = true }) catch return;
    defer atomic.deinit(io);
    atomic.file.writeStreamingAll(io, &hex) catch return;
    atomic.replace(io) catch return;
}

fn clearGeneratedCache(io: Io) void {
    for (generated_cache_roots) |path| Io.Dir.cwd().deleteTree(io, path) catch {};
}

fn clearGeneratedCacheAt(allocator: Allocator, io: Io, root: []const u8) void {
    const relative_roots = [_][]const u8{ "cache/v4", "cache/shaders", "artifacts/v1", "run", "test" };
    for (relative_roots) |relative| {
        const path = std.fs.path.join(allocator, &.{ root, relative }) catch continue;
        defer allocator.free(path);
        Io.Dir.cwd().deleteTree(io, path) catch {};
    }
}

pub fn loadIr(allocator: Allocator, io: Io, source_path: []const u8, target_name: []const u8) ?Ir.Program {
    const state_digest = artifactKey("frontend-state", &.{ source_path, target_name });
    const state_bytes = load(allocator, io, state_digest, "state") orelse return null;
    const state = std.json.parseFromSliceLeaky(State, allocator, state_bytes, .{}) catch return null;
    const digest = entryKey(allocator, io, state.files, "frontend", source_path, target_name) catch return null;
    const payload = load(allocator, io, digest, "ir-json") orelse return null;
    return std.json.parseFromSliceLeaky(Ir.Program, allocator, payload, .{}) catch null;
}

pub fn storeIr(allocator: Allocator, io: Io, source_path: []const u8, target_name: []const u8, files: []const []const u8, program: Ir.Program) void {
    const digest = entryKey(allocator, io, files, "frontend", source_path, target_name) catch return;
    const payload = std.json.Stringify.valueAlloc(allocator, program, .{}) catch return;
    store(allocator, io, digest, "ir-json", payload);
    const state_payload = std.json.Stringify.valueAlloc(allocator, State{ .files = files }, .{}) catch return;
    store(allocator, io, artifactKey("frontend-state", &.{ source_path, target_name }), "state", state_payload);
}

pub fn loadNativeState(allocator: Allocator, io: Io, source_path: []const u8, target_name: []const u8) ?NativeState {
    const state_digest = artifactKey("native-input-state", &.{ source_path, target_name });
    const state_bytes = load(allocator, io, state_digest, "state") orelse return null;
    return std.json.parseFromSliceLeaky(NativeState, allocator, state_bytes, .{}) catch null;
}

pub fn storeNativeState(
    allocator: Allocator,
    io: Io,
    source_path: []const u8,
    target_name: []const u8,
    files: []const []const u8,
    providers: []const Packages.BoundaryProvider,
) void {
    const state_payload = std.json.Stringify.valueAlloc(allocator, NativeState{
        .files = files,
        .providers = providers,
    }, .{}) catch return;
    store(allocator, io, artifactKey("native-input-state", &.{ source_path, target_name }), "state", state_payload);
}

pub fn loadAst(allocator: Allocator, io: Io, path: []const u8, source: []const u8) ?Ast.Program {
    return loadAstAt(allocator, io, ".silex/cache/v4", path, source);
}

pub fn loadAstAt(
    allocator: Allocator,
    io: Io,
    directory: []const u8,
    path: []const u8,
    source: []const u8,
) ?Ast.Program {
    const digest = contentIdentity("module-ast", path, source);
    const payload = loadAt(allocator, io, directory, digest, "ast-json") orelse return null;
    return std.json.parseFromSliceLeaky(Ast.Program, allocator, payload, .{}) catch null;
}

pub fn storeAst(allocator: Allocator, io: Io, path: []const u8, source: []const u8, program: Ast.Program) void {
    storeAstAt(allocator, io, ".silex/cache/v4", path, source, program);
}

pub fn storeAstAt(
    allocator: Allocator,
    io: Io,
    directory: []const u8,
    path: []const u8,
    source: []const u8,
    program: Ast.Program,
) void {
    const payload = std.json.Stringify.valueAlloc(allocator, program, .{}) catch return;
    storeAt(allocator, io, directory, contentIdentity("module-ast", path, source), "ast-json", payload);
}

fn contentIdentity(namespace: []const u8, path: []const u8, source: []const u8) [Blake3.digest_length]u8 {
    var hasher = Blake3.init(.{});
    updateCompilerIdentity(&hasher);
    hasher.update(namespace);
    hasher.update(path);
    hasher.update(source);
    var digest: [Blake3.digest_length]u8 = undefined;
    hasher.final(&digest);
    return digest;
}

pub fn artifactKey(namespace: []const u8, parts: []const []const u8) [Blake3.digest_length]u8 {
    const identity = active_compiler_identity orelse fallbackCompilerIdentity();
    return artifactKeyForCompiler(identity, namespace, parts);
}

fn artifactKeyForCompiler(
    identity: [Blake3.digest_length]u8,
    namespace: []const u8,
    parts: []const []const u8,
) [Blake3.digest_length]u8 {
    var hasher = Blake3.init(.{});
    hasher.update(format);
    hasher.update(&identity);
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
    updateCompilerIdentity(&hasher);
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

pub fn nativeKey(
    allocator: Allocator,
    io: Io,
    files: []const []const u8,
    providers: []const Packages.BoundaryProvider,
    command: []const u8,
    variant: []const u8,
) ![Blake3.digest_length]u8 {
    const paths = try allocator.dupe([]const u8, files);
    defer allocator.free(paths);
    std.mem.sort([]const u8, paths, {}, lessThan);
    var hasher = Blake3.init(.{});
    updateCompilerIdentity(&hasher);
    hasher.update(command);
    hasher.update(variant);
    for (paths) |path| {
        hasher.update(path);
        const source = try Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024));
        defer allocator.free(source);
        hasher.update(source);
        hashAncestorManifests(allocator, io, &hasher, path);
    }
    for (providers) |provider| {
        hasher.update(provider.name);
        if (provider.archive) |archive_path| {
            hasher.update(archive_path);
            if (provider.artifact_sha256.len == 64) {
                hasher.update(provider.artifact_sha256);
                const status = try Io.Dir.cwd().statFile(io, archive_path, .{});
                hasher.update(std.mem.asBytes(&status.size));
                hasher.update(std.mem.asBytes(&status.mtime.nanoseconds));
            } else {
                const archive = try Io.Dir.cwd().readFileAlloc(io, archive_path, allocator, .limited(512 * 1024 * 1024));
                defer allocator.free(archive);
                hasher.update(archive);
            }
        }
        for (provider.frameworks) |framework| hasher.update(framework);
        for (provider.libraries) |library| hasher.update(library);
    }
    var digest: [Blake3.digest_length]u8 = undefined;
    hasher.final(&digest);
    return digest;
}

fn updateCompilerIdentity(hasher: *Blake3) void {
    hasher.update(format);
    const identity = active_compiler_identity orelse fallbackCompilerIdentity();
    hasher.update(&identity);
}

pub fn executablePath(allocator: Allocator, digest: [Blake3.digest_length]u8, kind: []const u8) ![]const u8 {
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, ".silex/artifacts/v1/{s}.{s}", .{ hex, kind });
}

pub fn executableExists(allocator: Allocator, io: Io, digest: [Blake3.digest_length]u8, kind: []const u8) bool {
    const path = executablePath(allocator, digest, kind) catch return false;
    const file = Io.Dir.cwd().openFile(io, path, .{}) catch return false;
    defer file.close(io);
    file.setTimestampsNow(io) catch {};
    return true;
}

pub fn storeExecutableFile(
    allocator: Allocator,
    io: Io,
    digest: [Blake3.digest_length]u8,
    kind: []const u8,
    source_path: []const u8,
) void {
    const destination = executablePath(allocator, digest, kind) catch return;
    if (Io.Dir.cwd().statFile(io, destination, .{})) |_| return else |_| {}
    if (std.fs.path.dirname(destination)) |directory| Io.Dir.cwd().createDirPath(io, directory) catch return;
    Io.Dir.hardLink(Io.Dir.cwd(), source_path, Io.Dir.cwd(), destination, io, .{}) catch {
        Io.Dir.cwd().copyFile(source_path, Io.Dir.cwd(), destination, io, .{}) catch return;
    };
}

pub fn materializeExecutable(
    allocator: Allocator,
    io: Io,
    digest: [Blake3.digest_length]u8,
    kind: []const u8,
    output_path: []const u8,
) !void {
    const source = try executablePath(allocator, digest, kind);
    try ensureOutputParent(io, output_path);
    Io.Dir.cwd().deleteFile(io, output_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    Io.Dir.hardLink(Io.Dir.cwd(), source, Io.Dir.cwd(), output_path, io, .{}) catch {
        try Io.Dir.cwd().copyFile(source, Io.Dir.cwd(), output_path, io, .{});
    };
}

pub fn ensureOutputParent(io: Io, output_path: []const u8) !void {
    const directory = std.fs.path.dirname(output_path) orelse return;
    try ensureDirectory(Io.Dir.cwd(), io, directory);
}

fn ensureDirectory(base: Io.Dir, io: Io, path: []const u8) !void {
    var existing = base.openDir(io, path, .{}) catch {
        try base.createDirPath(io, path);
        return;
    };
    existing.close(io);
}

fn entryKey(
    allocator: Allocator,
    io: Io,
    files: []const []const u8,
    command: []const u8,
    source_path: []const u8,
    target_name: []const u8,
) ![Blake3.digest_length]u8 {
    const variant = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ target_name, source_path });
    defer allocator.free(variant);
    return key(allocator, io, files, command, variant);
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
    return loadAt(allocator, io, ".silex/cache/v4", digest, kind);
}

fn loadAt(
    allocator: Allocator,
    io: Io,
    directory: []const u8,
    digest: [Blake3.digest_length]u8,
    kind: []const u8,
) ?[]const u8 {
    const path = entryPathAt(allocator, directory, digest, kind) catch return null;
    const bytes = Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024)) catch {
        active_statistics.entry_misses += 1;
        return null;
    };
    active_statistics.bytes_read += bytes.len;
    if (bytes.len < digest.len or !std.mem.eql(u8, bytes[0..digest.len], &digest)) {
        active_statistics.entry_misses += 1;
        return null;
    }
    if (Io.Dir.cwd().openFile(io, path, .{})) |file| {
        defer file.close(io);
        file.setTimestampsNow(io) catch {};
    } else |_| {}
    active_statistics.entry_hits += 1;
    return bytes[digest.len..];
}

pub fn store(
    allocator: Allocator,
    io: Io,
    digest: [Blake3.digest_length]u8,
    kind: []const u8,
    payload: []const u8,
) void {
    storeAt(allocator, io, ".silex/cache/v4", digest, kind, payload);
}

fn storeAt(
    allocator: Allocator,
    io: Io,
    directory: []const u8,
    digest: [Blake3.digest_length]u8,
    kind: []const u8,
    payload: []const u8,
) void {
    Io.Dir.cwd().createDirPath(io, directory) catch return;
    const path = entryPathAt(allocator, directory, digest, kind) catch return;
    var atomic = Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true }) catch return;
    defer atomic.deinit(io);
    atomic.file.writeStreamingAll(io, &digest) catch return;
    atomic.file.writeStreamingAll(io, payload) catch return;
    atomic.replace(io) catch return;
    active_statistics.bytes_written += digest.len + payload.len;
}

fn entryPath(allocator: Allocator, digest: [Blake3.digest_length]u8, kind: []const u8) ![]const u8 {
    return entryPathAt(allocator, ".silex/cache/v4", digest, kind);
}

fn entryPathAt(
    allocator: Allocator,
    directory: []const u8,
    digest: [Blake3.digest_length]u8,
    kind: []const u8,
) ![]const u8 {
    const hex = std.fmt.bytesToHex(digest, .lower);
    return std.fmt.allocPrint(allocator, "{s}/{s}.{s}", .{ directory, hex, kind });
}

fn lessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

test "cache key depends on command variant paths and exact contents" {
    const debug = try key(std.testing.allocator, std.testing.io, &.{"build.zig"}, "compile", "debug");
    const release = try key(std.testing.allocator, std.testing.io, &.{"build.zig"}, "compile", "release");
    try std.testing.expect(!std.mem.eql(u8, &debug, &release));
}

test "entry cache key distinguishes programs sharing one source set" {
    const arithmetic = try entryKey(
        std.testing.allocator,
        std.testing.io,
        &.{"build.zig"},
        "native-input",
        "Arithmetic.sx",
        "macos-arm64",
    );
    const objects = try entryKey(
        std.testing.allocator,
        std.testing.io,
        &.{"build.zig"},
        "native-input",
        "Objects.sx",
        "macos-arm64",
    );
    try std.testing.expect(!std.mem.eql(u8, &arithmetic, &objects));
}

test "artifact keys distinguish compiler executables" {
    const first: [Blake3.digest_length]u8 = @splat(0x11);
    const second: [Blake3.digest_length]u8 = @splat(0x22);
    const first_key = artifactKeyForCompiler(first, "machine", &.{"same-input"});
    const second_key = artifactKeyForCompiler(second, "machine", &.{"same-input"});
    try std.testing.expect(!std.mem.eql(u8, &first_key, &second_key));
}

test "compiler generation rotation removes old generated code only once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "cache/v4");
    try temporary.dir.createDirPath(std.testing.io, "cache/shaders/kept");
    try temporary.dir.createDirPath(std.testing.io, "artifacts/v1");
    try temporary.dir.createDirPath(std.testing.io, "run");
    try temporary.dir.createDirPath(std.testing.io, "test");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "cache/v4/old", .data = "old" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "cache/shaders/kept/output", .data = "shader" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "artifacts/v1/old", .data = "old" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "run/old", .data = "old" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "test/old", .data = "old" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const first: [Blake3.digest_length]u8 = @splat(0x11);
    const second: [Blake3.digest_length]u8 = @splat(0x22);

    synchronizeCompilerGeneration(allocator, std.testing.io, root, first);
    try std.testing.expect(!pathExists(temporary.dir, std.testing.io, "cache/v4/old"));
    try std.testing.expect(!pathExists(temporary.dir, std.testing.io, "cache/shaders/kept/output"));

    try temporary.dir.createDirPath(std.testing.io, "cache/v4");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "cache/v4/current", .data = "current" });
    synchronizeCompilerGeneration(allocator, std.testing.io, root, first);
    try std.testing.expect(pathExists(temporary.dir, std.testing.io, "cache/v4/current"));

    synchronizeCompilerGeneration(allocator, std.testing.io, root, second);
    try std.testing.expect(!pathExists(temporary.dir, std.testing.io, "cache/v4/current"));
}

fn pathExists(directory: Io.Dir, io: Io, path: []const u8) bool {
    directory.access(io, path, .{}) catch return false;
    return true;
}

fn setModified(directory: Io.Dir, io: Io, path: []const u8, nanoseconds: i96) !void {
    const file = try directory.openFile(io, path, .{});
    defer file.close(io);
    try file.setTimestamps(io, .{ .modify_timestamp = .{ .new = .{ .nanoseconds = nanoseconds } } });
}

test "rolling retention admits an oversized current working set and evicts history first" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "cache/v4");
    try temporary.dir.createDirPath(std.testing.io, "artifacts/v1");
    try temporary.dir.createDirPath(std.testing.io, "run");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "cache/v4/history", .data = "12345678" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "artifacts/v1/history", .data = "12345678" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "run/current", .data = "123456789012" });
    try setModified(temporary.dir, std.testing.io, "cache/v4/history", 10);
    try setModified(temporary.dir, std.testing.io, "artifacts/v1/history", 20);
    try setModified(temporary.dir, std.testing.io, "run/current", 200);
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });

    maintainRootAfterMutation(allocator, std.testing.io, root, 10, 100);

    try std.testing.expect(!pathExists(temporary.dir, std.testing.io, "cache/v4/history"));
    try std.testing.expect(!pathExists(temporary.dir, std.testing.io, "artifacts/v1/history"));
    try std.testing.expect(pathExists(temporary.dir, std.testing.io, "run/current"));
}

test "a later small working set automatically releases an old oversized set" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "artifacts/v1");
    try temporary.dir.createDirPath(std.testing.io, "cache/v4");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "artifacts/v1/previous-large", .data = "123456789012" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "cache/v4/current-small", .data = "1234" });
    try setModified(temporary.dir, std.testing.io, "artifacts/v1/previous-large", 200);
    try setModified(temporary.dir, std.testing.io, "cache/v4/current-small", 400);
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });

    maintainRootAfterMutation(allocator, std.testing.io, root, 8, 300);

    try std.testing.expect(!pathExists(temporary.dir, std.testing.io, "artifacts/v1/previous-large"));
    try std.testing.expect(pathExists(temporary.dir, std.testing.io, "cache/v4/current-small"));
}

test "rolling retention bounds one global history across cache classes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "cache/v4");
    try temporary.dir.createDirPath(std.testing.io, "artifacts/v1");
    try temporary.dir.createDirPath(std.testing.io, "cache/shaders/group");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "cache/v4/first", .data = "12345678" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "artifacts/v1/second", .data = "12345678" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "cache/shaders/group/output", .data = "12345678" });
    try setModified(temporary.dir, std.testing.io, "cache/v4/first", 10);
    try setModified(temporary.dir, std.testing.io, "artifacts/v1/second", 20);
    try setModified(temporary.dir, std.testing.io, "cache/shaders/group/output", 30);
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });

    maintainRootAfterMutation(allocator, std.testing.io, root, 8, 100);

    try std.testing.expect(!pathExists(temporary.dir, std.testing.io, "cache/v4/first"));
    try std.testing.expect(!pathExists(temporary.dir, std.testing.io, "artifacts/v1/second"));
    try std.testing.expect(pathExists(temporary.dir, std.testing.io, "cache/shaders/group/output"));
}

test "compact native state serialization retains linked boundary providers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const files = &.{"Main.sx"};
    const providers = &.{Packages.BoundaryProvider{
        .name = "SDL3",
        .archive = "Boundary/macos-arm64/libSDL3.a",
        .frameworks = &.{"Metal"},
        .libraries = &.{},
    }};
    const state = NativeState{ .files = files, .providers = providers };
    const payload = try std.json.Stringify.valueAlloc(allocator, state, .{});
    const loaded = try std.json.parseFromSliceLeaky(NativeState, allocator, payload, .{});

    try std.testing.expectEqual(@as(usize, 1), loaded.providers.len);
    try std.testing.expectEqualStrings("SDL3", loaded.providers[0].name);
    try std.testing.expectEqualStrings("Metal", loaded.providers[0].frameworks[0]);
}

test "a corrupt cache entry is a measured safe miss" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const directory = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "cache" });
    const digest: [Blake3.digest_length]u8 = @splat(0x44);
    storeAt(allocator, std.testing.io, directory, digest, "test", "complete");
    const path = try entryPathAt(allocator, directory, digest, "test");
    try Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = path, .data = "truncated" });
    const before = statistics();

    try std.testing.expect(loadAt(allocator, std.testing.io, directory, digest, "test") == null);

    const after = statistics();
    try std.testing.expectEqual(before.entry_misses + 1, after.entry_misses);
}

test "output parent accepts an existing symbolic link to a directory" {
    if (@import("builtin").os.tag == .windows) return error.SkipZigTest;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "target");
    try temporary.dir.symLink(std.testing.io, "target", "alias", .{ .is_directory = true });

    try ensureDirectory(temporary.dir, std.testing.io, "alias");

    var opened = try temporary.dir.openDir(std.testing.io, "alias", .{});
    opened.close(std.testing.io);
}
