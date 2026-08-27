const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Error = Allocator.Error || Io.Dir.OpenError || Io.Dir.Iterator.Error || error{
    DuplicateModule,
    InvalidModulePath,
};

pub const Origin = enum {
    portable,
    platform,
    target,
    entry,
};

pub const Provider = struct {
    name: []const u8,
    path: []const u8,
    local_prefix: []const u8 = "",
    file: usize,
    owner: usize = 0,
    merge_owner: ?usize = null,
    origin: Origin = .portable,
};

pub const Merge = struct {
    name: []const u8,
    parent_owner: usize,
    child_owner: usize,
};

pub const Collision = struct {
    name: []const u8,
    left_owner: usize,
    right_owner: usize,
};

pub const principal_file = "@module.sx";
pub const principal_file_capitalized = "@Module.sx";

pub const Index = struct {
    providers: []const Provider,

    pub fn find(self: Index, name: []const u8) ?Provider {
        var low: usize = 0;
        var high = self.providers.len;
        while (low < high) {
            const middle = low + (high - low) / 2;
            switch (std.mem.order(u8, self.providers[middle].name, name)) {
                .lt => low = middle + 1,
                .gt => high = middle,
                .eq => high = middle,
            }
        }
        if (low < self.providers.len and std.mem.eql(u8, self.providers[low].name, name)) {
            return self.providers[low];
        }
        return null;
    }

    pub fn isNamespace(self: Index, name: []const u8) bool {
        if (self.find(name) != null) return true;
        for (self.providers) |provider| {
            if (provider.name.len > name.len and
                std.mem.startsWith(u8, provider.name, name) and
                provider.name[name.len] == '.')
            {
                return true;
            }
        }
        return false;
    }
};

pub fn discover(allocator: Allocator, io: Io, root_path: []const u8) Error!Index {
    return discoverOwned(allocator, io, root_path, null, 0);
}

pub fn discoverOwned(
    allocator: Allocator,
    io: Io,
    root_path: []const u8,
    prefix: ?[]const u8,
    owner: usize,
) Error!Index {
    return discoverOwnedAs(allocator, io, root_path, prefix, owner, .portable);
}

pub fn discoverOwnedAs(
    allocator: Allocator,
    io: Io,
    root_path: []const u8,
    prefix: ?[]const u8,
    owner: usize,
    origin: Origin,
) Error!Index {
    return discoverOwnedExcludingAs(allocator, io, root_path, prefix, owner, excluded_none, origin);
}

const excluded_none: []const []const u8 = &.{};

pub fn discoverOwnedExcluding(
    allocator: Allocator,
    io: Io,
    root_path: []const u8,
    prefix: ?[]const u8,
    owner: usize,
    excluded_roots: []const []const u8,
) Error!Index {
    return discoverOwnedExcludingAs(allocator, io, root_path, prefix, owner, excluded_roots, .portable);
}

pub fn discoverOwnedExcludingAs(
    allocator: Allocator,
    io: Io,
    root_path: []const u8,
    prefix: ?[]const u8,
    owner: usize,
    excluded_roots: []const []const u8,
    origin: Origin,
) Error!Index {
    var root = try Io.Dir.cwd().openDir(io, root_path, .{ .iterate = true });
    defer root.close(io);

    var providers: std.ArrayList(Provider) = .empty;
    var walker = try root.walk(allocator);
    defer walker.deinit();

    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory and isInfrastructureDirectory(entry.basename)) {
            walker.leave(io);
            continue;
        }
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".sx")) continue;

        const relative_path = try allocator.dupe(u8, entry.path);
        const full_path = if (root_path.len == 0 or std.mem.eql(u8, root_path, "."))
            relative_path
        else
            try std.fs.path.join(allocator, &.{ root_path, relative_path });
        if (insideAny(full_path, excluded_roots)) continue;

        const relative_name = try relativeModuleName(allocator, relative_path);
        const relative_directory = try moduleDirectoryName(allocator, relative_path);
        const module_name = if (prefix) |name|
            if (relative_name.len == 0)
                try allocator.dupe(u8, name)
            else
                try std.fmt.allocPrint(allocator, "{s}.{s}", .{ name, relative_name })
        else if (relative_name.len != 0)
            relative_name
        else
            return error.InvalidModulePath;
        const local_prefix = if (prefix) |name|
            if (relative_directory.len == 0)
                try allocator.dupe(u8, name)
            else
                try std.fmt.allocPrint(allocator, "{s}.{s}", .{ name, relative_directory })
        else
            relative_directory;
        try providers.append(allocator, .{
            .name = module_name,
            .path = full_path,
            .local_prefix = local_prefix,
            .file = 0,
            .owner = owner,
            .origin = origin,
        });
    }

    std.mem.sort(Provider, providers.items, {}, lessThan);
    for (providers.items, 0..) |*provider, index| {
        provider.file = index;
        if (index != 0 and std.mem.eql(u8, providers.items[index - 1].name, provider.name)) {
            return error.DuplicateModule;
        }
    }
    return .{ .providers = try providers.toOwnedSlice(allocator) };
}

fn insideAny(path: []const u8, roots: []const []const u8) bool {
    for (roots) |root| {
        if (std.mem.eql(u8, path, root)) return true;
        if (path.len > root.len and std.mem.startsWith(u8, path, root) and path[root.len] == std.fs.path.sep) return true;
    }
    return false;
}

pub fn combine(allocator: Allocator, indexes: []const Index) (Allocator.Error || error{DuplicateModule})!Index {
    return combineWithMerges(allocator, indexes, &.{});
}

pub fn combineWithMerges(
    allocator: Allocator,
    indexes: []const Index,
    merges: []const Merge,
) (Allocator.Error || error{DuplicateModule})!Index {
    var providers: std.ArrayList(Provider) = .empty;
    for (indexes) |index| for (index.providers) |provider| {
        var merged = provider;
        merged.merge_owner = mergeOwner(merges, provider);
        try providers.append(allocator, merged);
    };
    std.mem.sort(Provider, providers.items, {}, lessThan);
    for (providers.items, 0..) |*provider, index| {
        provider.file = index;
        if (index != 0 and
            std.mem.eql(u8, providers.items[index - 1].name, provider.name) and
            compositionOwner(providers.items[index - 1]) != compositionOwner(provider.*))
        {
            return error.DuplicateModule;
        }
    }
    return .{ .providers = try providers.toOwnedSlice(allocator) };
}

pub fn firstCollision(indexes: []const Index, merges: []const Merge) ?Collision {
    for (indexes, 0..) |left_index, index_number| {
        for (left_index.providers) |left| {
            for (indexes[index_number..]) |right_index| {
                for (right_index.providers) |right| {
                    if (left.owner == right.owner or !std.mem.eql(u8, left.name, right.name)) continue;
                    const left_merge_owner = mergeOwner(merges, left);
                    const right_merge_owner = mergeOwner(merges, right);
                    if (left_merge_owner != null and left_merge_owner == right_merge_owner) continue;
                    return .{
                        .name = left.name,
                        .left_owner = left.owner,
                        .right_owner = right.owner,
                    };
                }
            }
        }
    }
    return null;
}

pub fn compositionOwner(provider: Provider) usize {
    return provider.merge_owner orelse provider.owner;
}

fn mergeOwner(merges: []const Merge, provider: Provider) ?usize {
    for (merges) |merge| {
        if (!std.mem.eql(u8, merge.name, provider.name)) continue;
        if (provider.owner == merge.parent_owner or provider.owner == merge.child_owner) {
            return merge.parent_owner;
        }
    }
    return null;
}

pub fn moduleName(allocator: Allocator, relative_path: []const u8) Error![]const u8 {
    const name = try relativeModuleName(allocator, relative_path);
    if (name.len == 0) return error.InvalidModulePath;
    return name;
}

pub fn moduleDirectoryName(allocator: Allocator, relative_path: []const u8) Error![]const u8 {
    const directory = std.fs.path.dirname(relative_path) orelse return allocator.dupe(u8, "");
    if (directory.len == 0 or std.mem.eql(u8, directory, ".")) return allocator.dupe(u8, "");
    const result = try allocator.dupe(u8, directory);
    for (result) |*character| {
        if (character.* == '/' or character.* == '\\') character.* = '.';
    }
    if (!validName(result)) return error.InvalidModulePath;
    return result;
}

fn relativeModuleName(allocator: Allocator, relative_path: []const u8) Error![]const u8 {
    if (!std.mem.endsWith(u8, relative_path, ".sx")) return error.InvalidModulePath;
    const stem = if (isPrincipalFile(std.fs.path.basename(relative_path)))
        std.fs.path.dirname(relative_path) orelse ""
    else
        relative_path[0 .. relative_path.len - ".sx".len];
    if (stem.len == 0) return allocator.dupe(u8, "");

    const result = try allocator.dupe(u8, stem);
    for (result) |*character| {
        if (character.* == '/' or character.* == '\\') character.* = '.';
    }
    if (!validName(result)) return error.InvalidModulePath;
    return result;
}

fn isPrincipalFile(basename: []const u8) bool {
    return std.mem.eql(u8, basename, principal_file) or
        std.mem.eql(u8, basename, principal_file_capitalized);
}

pub fn validName(name: []const u8) bool {
    if (name.len == 0) return false;
    var segment_start = true;
    for (name) |character| {
        if (character == '.') {
            if (segment_start) return false;
            segment_start = true;
        } else if (segment_start) {
            if (!std.ascii.isAlphabetic(character) and character != '_') return false;
            segment_start = false;
        } else if (!std.ascii.isAlphanumeric(character) and character != '_') {
            return false;
        }
    }
    return !segment_start;
}

fn isInfrastructureDirectory(name: []const u8) bool {
    return name.len != 0 and (name[0] == '@' or name[0] == '.');
}

fn lessThan(_: void, left: Provider, right: Provider) bool {
    const names = std.mem.order(u8, left.name, right.name);
    if (names != .eq) return names == .lt;
    const left_composition_owner = compositionOwner(left);
    const right_composition_owner = compositionOwner(right);
    if (left_composition_owner == right_composition_owner and left.owner != right.owner) {
        if (left.owner == left_composition_owner) return true;
        if (right.owner == right_composition_owner) return false;
    }
    return std.mem.lessThan(u8, left.path, right.path);
}

test "derive canonical module names from nested and dotted paths" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expectEqualStrings("Math.Operations", try moduleName(allocator, "Math/Operations.sx"));
    try std.testing.expectEqualStrings("Math.Integer.Checked", try moduleName(allocator, "Math/Integer.Checked.sx"));
    try std.testing.expectEqualStrings("Math.Integer", try moduleName(allocator, "Math/Integer/@module.sx"));
    try std.testing.expectEqualStrings("Math.Integer", try moduleName(allocator, "Math/Integer/@Module.sx"));
    try std.testing.expectError(error.InvalidModulePath, moduleName(allocator, "@module.sx"));
    try std.testing.expectError(error.InvalidModulePath, moduleName(allocator, "@Module.sx"));
    try std.testing.expectError(error.InvalidModulePath, moduleName(allocator, "Math/2D.sx"));
}

test "discover capitalized principal module files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GPU");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GPU/@Module.sx", .data = "public func device() {}" });
    const root_path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const index = try discoverOwned(allocator, std.testing.io, root_path, "GFX", 0);

    try std.testing.expect(index.find("GFX.GPU") != null);
    try std.testing.expect(index.find("GFX.GPU.@Module") == null);
}

test "discover package and nested principal modules" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GPU");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "@module.sx", .data = "public func root() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GPU/@module.sx", .data = "public func device() {}" });
    const root_path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const index = try discoverOwned(allocator, std.testing.io, root_path, "GFX", 0);

    try std.testing.expect(index.find("GFX") != null);
    try std.testing.expect(index.find("GFX.GPU") != null);
    try std.testing.expect(index.find("GFX.@module") == null);
    try std.testing.expect(index.find("GFX.GPU.@module") == null);
}

test "reject flat and principal files for the same module" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "GPU");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GPU.sx", .data = "public func first() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "GPU/@module.sx", .data = "public func second() {}" });
    const root_path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    try std.testing.expectError(error.DuplicateModule, discover(allocator, std.testing.io, root_path));
}

test "discover modules deterministically and skip infrastructure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math/Integer");
    try temporary.dir.createDirPath(std.testing.io, "@Docs");
    try temporary.dir.createDirPath(std.testing.io, ".cache");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Math/Operations.sx", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Math/Integer/Checked.sx", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "@Docs/Hidden.sx", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = ".cache/Hidden.sx", .data = "" });

    const root_path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const index = try discover(allocator, std.testing.io, root_path);
    try std.testing.expectEqual(@as(usize, 3), index.providers.len);
    try std.testing.expectEqualStrings("Main", index.providers[0].name);
    try std.testing.expectEqualStrings("Math.Integer.Checked", index.providers[1].name);
    try std.testing.expectEqualStrings("Math.Operations", index.providers[2].name);
    try std.testing.expect(index.isNamespace("Math"));
    try std.testing.expect(index.find("Math") == null);
}

test "reject nested and dotted duplicate providers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math/Integer");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Math/Integer/Checked.sx", .data = "" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Math/Integer.Checked.sx", .data = "" });
    const root_path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    try std.testing.expectError(error.DuplicateModule, discover(allocator, std.testing.io, root_path));
}
