const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Error = Allocator.Error || Io.Dir.OpenError || Io.Dir.Iterator.Error || error{
    DuplicateModule,
    InvalidModulePath,
};

pub const Provider = struct {
    name: []const u8,
    path: []const u8,
    file: usize,
    owner: usize = 0,
};

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
                .eq => return self.providers[middle],
            }
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
        const relative_name = try moduleName(allocator, relative_path);
        const module_name = if (prefix) |name|
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ name, relative_name })
        else
            relative_name;
        const full_path = if (root_path.len == 0 or std.mem.eql(u8, root_path, "."))
            relative_path
        else
            try std.fs.path.join(allocator, &.{ root_path, relative_path });
        try providers.append(allocator, .{
            .name = module_name,
            .path = full_path,
            .file = 0,
            .owner = owner,
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

pub fn combine(allocator: Allocator, indexes: []const Index) (Allocator.Error || error{DuplicateModule})!Index {
    var providers: std.ArrayList(Provider) = .empty;
    for (indexes) |index| try providers.appendSlice(allocator, index.providers);
    std.mem.sort(Provider, providers.items, {}, lessThan);
    for (providers.items, 0..) |*provider, index| {
        provider.file = index;
        if (index != 0 and std.mem.eql(u8, providers.items[index - 1].name, provider.name)) {
            return error.DuplicateModule;
        }
    }
    return .{ .providers = try providers.toOwnedSlice(allocator) };
}

pub fn moduleName(allocator: Allocator, relative_path: []const u8) Error![]const u8 {
    if (!std.mem.endsWith(u8, relative_path, ".sx")) return error.InvalidModulePath;
    const stem = relative_path[0 .. relative_path.len - ".sx".len];
    if (stem.len == 0) return error.InvalidModulePath;

    const result = try allocator.dupe(u8, stem);
    for (result) |*character| {
        if (character.* == '/' or character.* == '\\') character.* = '.';
    }
    if (!validName(result)) return error.InvalidModulePath;
    return result;
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
    return std.mem.lessThan(u8, left.path, right.path);
}

test "derive canonical module names from nested and dotted paths" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expectEqualStrings("Math.Operations", try moduleName(allocator, "Math/Operations.sx"));
    try std.testing.expectEqualStrings("Math.Integer.Checked", try moduleName(allocator, "Math/Integer.Checked.sx"));
    try std.testing.expectError(error.InvalidModulePath, moduleName(allocator, "Math/2D.sx"));
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
