//! A bounded user-global store for disposable compilation fragments.
//! Readers hold bytes privately; eviction cannot remove an input to an active link.
const std = @import("std");
const Cache = @import("../CompilationCache.zig");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const Hash = std.crypto.hash.Blake3;

pub const limit: u64 = 512 * 1024 * 1024;
pub const Store = struct {
    allocator: Allocator,
    io: Io,
    root: []const u8,
    capacity: u64 = limit,
    max_entries: usize = 8192,

    pub const Fragment = struct { digest: [32]u8, bytes: []const u8 };

    pub fn init(init_process: std.process.Init, allocator: Allocator) !?Store {
        const home = init_process.environ_map.get("HOME") orelse init_process.environ_map.get("USERPROFILE") orelse return null;
        return .{ .allocator = allocator, .io = init_process.io, .root = try std.fs.path.join(allocator, &.{ home, ".silex", "cache", "compiled-v1" }) };
    }

    pub fn key(namespace: []const u8, parts: []const []const u8) [32]u8 {
        return Cache.artifactKey(namespace, parts);
    }

    fn path(self: Store, digest: [32]u8) ![]const u8 {
        return std.fmt.allocPrint(self.allocator, "{s}/{s}.bin", .{ self.root, std.fmt.bytesToHex(digest, .lower) });
    }

    pub fn load(self: Store, digest: [32]u8) ?[]const u8 {
        const file_path = self.path(digest) catch return null;
        const file = Io.Dir.cwd().openFile(self.io, file_path, .{}) catch return null;
        defer file.close(self.io);
        const status = file.stat(self.io) catch return null;
        if (status.size < 64 or status.size > self.capacity) return null;
        const bytes = self.allocator.alloc(u8, @intCast(status.size)) catch return null;
        if ((file.readPositionalAll(self.io, bytes, 0) catch return null) != bytes.len) return null;
        if (!std.mem.eql(u8, bytes[0..32], &digest)) return null;
        var actual: [32]u8 = undefined;
        Hash.hash(bytes[64..], &actual, .{});
        if (!std.mem.eql(u8, bytes[32..64], &actual)) return null;
        file.setTimestampsNow(self.io) catch {};
        return bytes[64..];
    }

    pub fn store(self: Store, digest: [32]u8, bytes: []const u8) void {
        self.publish(digest, bytes) catch {};
    }

    fn publish(self: Store, digest: [32]u8, bytes: []const u8) !void {
        return self.publishMany(&.{.{ .digest = digest, .bytes = bytes }});
    }

    pub fn publishMany(self: Store, fragments: []const Fragment) !void {
        if (fragments.len == 0) return;
        try Io.Dir.cwd().createDirPath(self.io, self.root);
        const lock_path = try std.fs.path.join(self.allocator, &.{ self.root, "lock" });
        const lock = try Io.Dir.cwd().createFile(self.io, lock_path, .{ .truncate = false });
        defer lock.close(self.io);
        try lock.lock(self.io, .exclusive);
        defer lock.unlock(self.io);
        const temporary = try std.fs.path.join(self.allocator, &.{ self.root, "pending" });
        Io.Dir.cwd().deleteFile(self.io, temporary) catch {};
        defer Io.Dir.cwd().deleteFile(self.io, temporary) catch {};

        const Entry = struct { path: []const u8, size: u64, modified: i96, removed: bool = false };
        var files: std.ArrayList(Entry) = .empty;
        defer files.deinit(self.allocator);
        var directory = try Io.Dir.cwd().openDir(self.io, self.root, .{ .iterate = true });
        defer directory.close(self.io);
        var iterator = directory.iterateAssumeFirstIteration();
        var total: u64 = 0;
        var count: usize = 0;
        while (try iterator.next(self.io)) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".bin")) continue;
            const full = try std.fs.path.join(self.allocator, &.{ self.root, entry.name });
            const status = try directory.statFile(self.io, entry.name, .{});
            const size = charge(status.size);
            total += size;
            count += 1;
            try files.append(self.allocator, .{ .path = full, .size = size, .modified = status.mtime.nanoseconds });
        }
        const Sort = struct {
            fn less(_: void, a: Entry, b: Entry) bool {
                if (a.modified != b.modified) return a.modified < b.modified;
                return std.mem.lessThan(u8, a.path, b.path);
            }
        };
        std.mem.sort(Entry, files.items, {}, Sort.less);
        var oldest: usize = 0;
        for (fragments) |fragment| {
            const size = charge(fragment.bytes.len + 64);
            if (size > self.capacity or self.max_entries == 0) continue;
            const destination = try self.path(fragment.digest);
            for (files.items) |*entry| {
                if (entry.removed or !std.mem.eql(u8, entry.path, destination)) continue;
                try Io.Dir.cwd().deleteFile(self.io, entry.path);
                total -= entry.size;
                count -= 1;
                entry.removed = true;
            }
            while (total + size > self.capacity or count >= self.max_entries) {
                if (oldest == files.items.len) return error.CacheCapacityExceeded;
                const entry = &files.items[oldest];
                oldest += 1;
                if (entry.removed) continue;
                try Io.Dir.cwd().deleteFile(self.io, entry.path);
                total -= entry.size;
                count -= 1;
                entry.removed = true;
            }
            const file = try Io.Dir.cwd().createFile(self.io, temporary, .{});
            {
                defer file.close(self.io);
                var checksum: [32]u8 = undefined;
                Hash.hash(fragment.bytes, &checksum, .{});
                try file.writeStreamingAll(self.io, &fragment.digest);
                try file.writeStreamingAll(self.io, &checksum);
                try file.writeStreamingAll(self.io, fragment.bytes);
            }
            try Io.Dir.cwd().rename(temporary, Io.Dir.cwd(), destination, self.io);
            total += size;
            count += 1;
            try files.append(self.allocator, .{ .path = destination, .size = size, .modified = Io.Clock.real.now(self.io).nanoseconds });
        }
    }

    fn charge(size: u64) u64 {
        // Tiny records still occupy filesystem blocks and metadata. Bound both
        // accounted bytes and entry count, rather than only logical payloads.
        return std.mem.alignForward(u64, size, 4096) + 4096;
    }
};

test "shared fragments are integrity checked and evicted within a hard byte limit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const root = try std.fs.path.join(a, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const store: Store = .{ .allocator = a, .io = std.testing.io, .root = root, .capacity = 2 * 8192 };
    const first = Store.key("test", &.{"first"});
    const second = Store.key("test", &.{"second"});
    const third = Store.key("test", &.{"third"});
    try store.publish(first, "one");
    try store.publish(second, "two");
    // Control age rather than depending on the filesystem clock's resolution.
    const file = try Io.Dir.cwd().openFile(std.testing.io, try store.path(first), .{ .mode = .read_write });
    try file.setTimestamps(std.testing.io, .{ .modify_timestamp = .{ .new = .{ .nanoseconds = std.time.ns_per_s } } });
    file.close(std.testing.io);
    try store.publish(third, "three");
    try std.testing.expect(store.load(first) == null);
    try std.testing.expectEqualStrings("two", store.load(second).?);
    try std.testing.expectEqualStrings("three", store.load(third).?);
    try Io.Dir.cwd().writeFile(std.testing.io, .{ .sub_path = try store.path(third), .data = "truncated" });
    try std.testing.expect(store.load(third) == null);
    try store.publish(third, "repaired");
    try std.testing.expectEqualStrings("repaired", store.load(third).?);
    try store.publish(first, &([_]u8{0} ** (2 * 8192 + 1)));
    try std.testing.expect(store.load(first) == null);
    var directory = try Io.Dir.cwd().openDir(std.testing.io, root, .{ .iterate = true });
    defer directory.close(std.testing.io);
    var iterator = directory.iterateAssumeFirstIteration();
    var bytes: u64 = 0;
    while (try iterator.next(std.testing.io)) |entry| {
        bytes += (try directory.statFile(std.testing.io, entry.name, .{})).size;
    }
    try std.testing.expect(bytes <= store.capacity);
}

test "batch publication bounds entry count and replaces duplicate keys" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const root = try std.fs.path.join(a, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const store: Store = .{ .allocator = a, .io = std.testing.io, .root = root, .max_entries = 2 };
    const first = Store.key("batch", &.{"first"});
    const second = Store.key("batch", &.{"second"});
    const third = Store.key("batch", &.{"third"});
    try store.publishMany(&.{
        .{ .digest = first, .bytes = "one" },
        .{ .digest = second, .bytes = "two" },
        .{ .digest = second, .bytes = "replacement" },
        .{ .digest = third, .bytes = "three" },
    });
    try std.testing.expect(store.load(first) == null);
    try std.testing.expectEqualStrings("replacement", store.load(second).?);
    try std.testing.expectEqualStrings("three", store.load(third).?);
    var directory = try Io.Dir.cwd().openDir(std.testing.io, root, .{ .iterate = true });
    defer directory.close(std.testing.io);
    var iterator = directory.iterateAssumeFirstIteration();
    var count: usize = 0;
    while (try iterator.next(std.testing.io)) |entry| {
        if (std.mem.endsWith(u8, entry.name, ".bin")) count += 1;
        try std.testing.expect(!std.mem.eql(u8, entry.name, "pending"));
    }
    try std.testing.expectEqual(@as(usize, 2), count);
}

test "concurrent writers publish complete records and share one quota" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const root = try std.fs.path.join(a, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const Worker = struct {
        store: Store,
        prefix: u8,
        failure: ?anyerror = null,
        fn run(self: *@This()) void {
            for (0..16) |index| {
                const input = [_]u8{ self.prefix, @intCast(index) };
                const digest = Store.key("concurrent", &.{&input});
                self.store.publish(digest, "complete") catch |err| {
                    self.failure = err;
                    return;
                };
                // Another writer may evict it, but a hit must be complete.
                if (self.store.load(digest)) |bytes| {
                    if (!std.mem.eql(u8, bytes, "complete")) self.failure = error.TestUnexpectedResult;
                }
            }
        }
    };
    const store: Store = .{ .allocator = a, .io = std.testing.io, .root = root, .capacity = 8 * 8192, .max_entries = 8 };
    var one: Worker = .{ .store = store, .prefix = 1 };
    var two: Worker = .{ .store = store, .prefix = 2 };
    const thread = try std.Thread.spawn(.{}, Worker.run, .{&one});
    two.run();
    thread.join();
    try std.testing.expect(one.failure == null and two.failure == null);
    var directory = try Io.Dir.cwd().openDir(std.testing.io, root, .{ .iterate = true });
    defer directory.close(std.testing.io);
    var iterator = directory.iterateAssumeFirstIteration();
    var count: usize = 0;
    var charged: u64 = 0;
    while (try iterator.next(std.testing.io)) |entry| {
        if (!std.mem.endsWith(u8, entry.name, ".bin")) continue;
        count += 1;
        charged += Store.charge((try directory.statFile(std.testing.io, entry.name, .{})).size);
    }
    try std.testing.expectEqual(@as(usize, 8), count);
    try std.testing.expect(charged <= store.capacity);
}
