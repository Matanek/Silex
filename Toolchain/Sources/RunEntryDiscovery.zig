const std = @import("std");
const Lexer = @import("Lexer.zig").Lexer;

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Result = union(enum) {
    source: []const u8,
    no_entry,
    ambiguous: []const []const u8,
    invalid_path,
};

pub fn resolve(allocator: Allocator, io: Io, path: []const u8) !Result {
    const status = Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => if (std.mem.endsWith(u8, path, ".sx"))
            return .{ .source = try allocator.dupe(u8, path) }
        else
            return .invalid_path,
        else => return err,
    };
    if (status.kind == .file) return .{ .source = try allocator.dupe(u8, path) };
    if (status.kind != .directory) return .invalid_path;

    var directory = try Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer directory.close(io);
    var iterator = directory.iterateAssumeFirstIteration();
    var candidates: std.ArrayList([]const u8) = .empty;
    while (try iterator.next(io)) |entry| {
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".sx")) continue;
        const source_path = if (path.len == 0 or std.mem.eql(u8, path, "."))
            try allocator.dupe(u8, entry.name)
        else
            try std.fs.path.join(allocator, &.{ path, entry.name });
        const source = try Io.Dir.cwd().readFileAlloc(io, source_path, allocator, .limited(16 * 1024 * 1024));
        if (containsRootMain(source)) try candidates.append(allocator, source_path);
    }

    std.mem.sort([]const u8, candidates.items, {}, lessThan);
    return switch (candidates.items.len) {
        0 => .no_entry,
        1 => .{ .source = candidates.items[0] },
        else => .{ .ambiguous = try candidates.toOwnedSlice(allocator) },
    };
}

pub fn containsRootMain(source: []const u8) bool {
    var lexer = Lexer.init(source);
    var depth: usize = 0;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) return false;
        if (depth == 0 and token.tag == .keyword_func) {
            const name = lexer.next() catch return false;
            if (name.tag == .identifier and std.mem.eql(u8, name.lexeme, "main")) return true;
        }
        if (token.tag == .left_brace) {
            depth += 1;
        } else if (token.tag == .right_brace and depth != 0) {
            depth -= 1;
        }
    }
}

fn lessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

test "recognize only root main declarations" {
    try std.testing.expect(containsRootMain("func main() {}"));
    try std.testing.expect(containsRootMain("public func main(value:int) {}"));
    try std.testing.expect(containsRootMain("func main() {"));
    try std.testing.expect(!containsRootMain("func helper() { func main() {} }"));
    try std.testing.expect(!containsRootMain("func helper() { print(\"func main() {}\") }"));
    try std.testing.expect(!containsRootMain("// func main() {}\nfunc helper() {}"));
    try std.testing.expect(!containsRootMain("struct Application { func main() {} }"));
}

test "keep an explicit file authoritative" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "First.sx", .data = "func main() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Second.sx", .data = "func main() {}" });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "First.sx" });
    const result = try resolve(allocator, std.testing.io, input);
    try std.testing.expectEqualStrings(input, result.source);
}

test "discover one direct entry without activating unrelated sources" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDir(std.testing.io, "Nested", .default_dir);
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Application.sx", .data = "func main() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "this source is deliberately invalid" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Nested/Other.sx", .data = "func main() {}" });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const result = try resolve(allocator, std.testing.io, root);
    try std.testing.expect(std.mem.endsWith(u8, result.source, "Application.sx"));
}

test "report zero and sorted multiple direct entries" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Helper.sx", .data = "func helper() {}" });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    try std.testing.expect((try resolve(allocator, std.testing.io, root)) == .no_entry);

    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Zeta.sx", .data = "func main() {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Alpha.sx", .data = "func main() {}" });
    const ambiguous = (try resolve(allocator, std.testing.io, root)).ambiguous;
    try std.testing.expectEqual(@as(usize, 2), ambiguous.len);
    try std.testing.expect(std.mem.endsWith(u8, ambiguous[0], "Alpha.sx"));
    try std.testing.expect(std.mem.endsWith(u8, ambiguous[1], "Zeta.sx"));
}

test "accept a source atom as the physical entry" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "@Entry.sx", .data = "func main() {}" });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const result = try resolve(allocator, std.testing.io, root);
    try std.testing.expect(std.mem.endsWith(u8, result.source, "@Entry.sx"));
}
