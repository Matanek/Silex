const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Blake3 = std.crypto.hash.Blake3;
const Ir = @import("Ir.zig");
const Ast = @import("Ast.zig");
const Packages = @import("Packages.zig");

// This identity covers every serialized frontend, Release and machine artifact.
// Bump it whenever an optimizer, lowering or register-allocation contract
// changes: source-only cache keys cannot distinguish machine plans emitted by
// two versions of the compiler.
pub const format = "silex-cache-v78-reachable-modules";
const State = struct { files: []const []const u8 };

pub const NativeState = struct {
    files: []const []const u8,
    providers: []const Packages.BoundaryProvider,
};

const RetainedFile = struct {
    path: []const u8,
    size: u64,
    modified: i96,
};

pub fn maintain(allocator: Allocator, io: Io) void {
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
    maintainAfterMutation(allocator, io);
    Io.Dir.cwd().createDirPath(io, ".silex") catch return;
    const file = Io.Dir.cwd().createFile(io, marker, .{}) catch return;
    file.close(io);
}

pub fn maintainAfterMutation(allocator: Allocator, io: Io) void {
    trimDirectory(allocator, io, ".silex/cache/v4", 64 * 1024 * 1024);
    trimDirectory(allocator, io, ".silex/artifacts/v1", 256 * 1024 * 1024);
    trimDirectory(allocator, io, ".silex/run", 64 * 1024 * 1024);
    trimDirectory(allocator, io, ".silex/test", 64 * 1024 * 1024);
    trimDirectoryTrees(allocator, io, ".silex/cache/shaders", 16 * 1024 * 1024);
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

fn trimDirectory(allocator: Allocator, io: Io, path: []const u8, maximum_size: u64) void {
    var directory = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return;
    defer directory.close(io);
    var iterator = directory.iterateAssumeFirstIteration();
    var retained: std.ArrayList(RetainedFile) = .empty;
    var total: u64 = 0;
    while (iterator.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        const status = directory.statFile(io, entry.name, .{}) catch continue;
        const name = allocator.dupe(u8, entry.name) catch return;
        retained.append(allocator, .{
            .path = name,
            .size = status.size,
            .modified = status.mtime.nanoseconds,
        }) catch return;
        total += status.size;
    }
    if (total <= maximum_size) return;
    std.mem.sort(RetainedFile, retained.items, {}, oldestFirst);
    for (retained.items) |entry| {
        if (total <= maximum_size) break;
        directory.deleteFile(io, entry.path) catch continue;
        total -= entry.size;
    }
}

fn trimDirectoryTrees(allocator: Allocator, io: Io, path: []const u8, maximum_size: u64) void {
    var directory = Io.Dir.cwd().openDir(io, path, .{ .iterate = true }) catch return;
    defer directory.close(io);
    var iterator = directory.iterateAssumeFirstIteration();
    var retained: std.ArrayList(RetainedFile) = .empty;
    var total: u64 = 0;
    while (iterator.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        const status = directory.statFile(io, entry.name, .{}) catch continue;
        const size = size: {
            var child = directory.openDir(io, entry.name, .{ .iterate = true }) catch continue;
            defer child.close(io);
            var walker = child.walk(allocator) catch continue;
            defer walker.deinit();
            var bytes: u64 = 0;
            while (walker.next(io) catch null) |nested| {
                if (nested.kind != .file) continue;
                bytes += (child.statFile(io, nested.path, .{}) catch continue).size;
            }
            break :size bytes;
        };
        const name = allocator.dupe(u8, entry.name) catch return;
        retained.append(allocator, .{
            .path = name,
            .size = size,
            .modified = status.mtime.nanoseconds,
        }) catch return;
        total += size;
    }
    if (total <= maximum_size) return;
    std.mem.sort(RetainedFile, retained.items, {}, oldestFirst);
    for (retained.items) |entry| {
        if (total <= maximum_size) break;
        directory.deleteTree(io, entry.path) catch continue;
        total -= entry.size;
    }
}

fn oldestFirst(_: void, left: RetainedFile, right: RetainedFile) bool {
    return left.modified < right.modified;
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
    hasher.update(format);
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
        hasher.update(provider.archive);
        if (provider.artifact_sha256.len == 64) {
            hasher.update(provider.artifact_sha256);
            const status = try Io.Dir.cwd().statFile(io, provider.archive, .{});
            hasher.update(std.mem.asBytes(&status.size));
            hasher.update(std.mem.asBytes(&status.mtime.nanoseconds));
        } else {
            const archive = try Io.Dir.cwd().readFileAlloc(io, provider.archive, allocator, .limited(512 * 1024 * 1024));
            defer allocator.free(archive);
            hasher.update(archive);
        }
        for (provider.frameworks) |framework| hasher.update(framework);
        for (provider.libraries) |library| hasher.update(library);
    }
    var digest: [Blake3.digest_length]u8 = undefined;
    hasher.final(&digest);
    return digest;
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
    if (std.fs.path.dirname(output_path)) |directory| try Io.Dir.cwd().createDirPath(io, directory);
    Io.Dir.cwd().deleteFile(io, output_path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    Io.Dir.hardLink(Io.Dir.cwd(), source, Io.Dir.cwd(), output_path, io, .{}) catch {
        try Io.Dir.cwd().copyFile(source, Io.Dir.cwd(), output_path, io, .{});
    };
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
    const path = entryPath(allocator, digest, kind) catch return null;
    const bytes = Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024)) catch return null;
    if (bytes.len < digest.len or !std.mem.eql(u8, bytes[0..digest.len], &digest)) return null;
    if (Io.Dir.cwd().openFile(io, path, .{})) |file| {
        defer file.close(io);
        file.setTimestampsNow(io) catch {};
    } else |_| {}
    return bytes[digest.len..];
}

pub fn store(
    allocator: Allocator,
    io: Io,
    digest: [Blake3.digest_length]u8,
    kind: []const u8,
    payload: []const u8,
) void {
    const directory = ".silex/cache/v4";
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
    return std.fmt.allocPrint(allocator, ".silex/cache/v4/{s}.{s}", .{ hex, kind });
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

test "flat cache maintenance enforces its byte budget" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "a", .data = "12345678" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "b", .data = "12345678" });
    const path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });

    trimDirectory(allocator, std.testing.io, path, 8);

    var iterator = temporary.dir.iterateAssumeFirstIteration();
    var files: usize = 0;
    while (try iterator.next(std.testing.io)) |entry| if (entry.kind == .file) {
        files += 1;
    };
    try std.testing.expectEqual(@as(usize, 1), files);
}

test "nested cache maintenance removes complete content groups" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "first");
    try temporary.dir.createDirPath(std.testing.io, "second");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "first/output", .data = "12345678" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "second/output", .data = "12345678" });
    const path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });

    trimDirectoryTrees(allocator, std.testing.io, path, 8);

    var iterator = temporary.dir.iterateAssumeFirstIteration();
    var directories: usize = 0;
    while (try iterator.next(std.testing.io)) |entry| if (entry.kind == .directory) {
        directories += 1;
    };
    try std.testing.expectEqual(@as(usize, 1), directories);
}

test "compact native state retains linked boundary providers" {
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
    storeNativeState(allocator, std.testing.io, source_path, "macos-arm64", files, providers);
    const loaded = loadNativeState(allocator, std.testing.io, source_path, "macos-arm64").?;

    try std.testing.expectEqual(@as(usize, 1), loaded.providers.len);
    try std.testing.expectEqualStrings("SDL3", loaded.providers[0].name);
    try std.testing.expectEqualStrings("Metal", loaded.providers[0].frameworks[0]);
}
