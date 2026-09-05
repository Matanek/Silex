const std = @import("std");
const Lexer = @import("Lexer.zig").Lexer;
const Target = @import("Target.zig").Target;

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub fn sources(allocator: Allocator, io: Io, path: []const u8, target: Target) ![]const []const u8 {
    const stat = try Io.Dir.cwd().statFile(io, path, .{});
    if (stat.kind == .file) {
        if (!std.mem.endsWith(u8, path, ".sx")) return error.InvalidTestPath;
        const result = try allocator.alloc([]const u8, 1);
        result[0] = try allocator.dupe(u8, path);
        return result;
    }
    if (stat.kind != .directory) return error.InvalidTestPath;

    var directory = try Io.Dir.cwd().openDir(io, path, .{ .iterate = true });
    defer directory.close(io);
    var walker = try directory.walk(allocator);
    defer walker.deinit();

    var result: std.ArrayList([]const u8) = .empty;
    while (try walker.next(io)) |entry| {
        if (entry.kind == .directory and ignoredDirectory(entry.basename)) {
            walker.leave(io);
            continue;
        }

        const full_path = if (path.len == 0 or std.mem.eql(u8, path, "."))
            try allocator.dupe(u8, entry.path)
        else
            try std.fs.path.join(allocator, &.{ path, entry.path });
        if (!appliesToTarget(full_path, target)) {
            if (entry.kind == .directory) walker.leave(io);
            continue;
        }
        if (entry.kind != .file or !std.mem.endsWith(u8, entry.basename, ".sx")) continue;

        const source = try Io.Dir.cwd().readFileAlloc(io, full_path, allocator, .limited(16 * 1024 * 1024));
        if (containsRootTest(source)) try result.append(allocator, full_path);
    }

    std.mem.sort([]const u8, result.items, {}, lessThan);
    return result.toOwnedSlice(allocator);
}

pub fn containsRootTest(source: []const u8) bool {
    var lexer = Lexer.init(source);
    var depth: usize = 0;
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .end) return false;
        if (depth == 0 and token.tag == .identifier and std.mem.eql(u8, token.lexeme, "test")) {
            var lookahead = lexer;
            const next = lookahead.next() catch return true;
            if (next.tag == .left_brace) return true;
            if (next.tag == .string) {
                const brace = lookahead.next() catch return true;
                if (brace.tag == .left_brace) return true;
            }
        }
        if (token.tag == .left_brace) {
            depth += 1;
        } else if (token.tag == .right_brace and depth != 0) {
            depth -= 1;
        }
    }
}

fn ignoredDirectory(name: []const u8) bool {
    return name.len != 0 and (name[0] == '.' or name[0] == '@' or
        std.mem.eql(u8, name, "zig-cache") or std.mem.eql(u8, name, "zig-out"));
}

fn appliesToTarget(path: []const u8, target: Target) bool {
    var components = std.mem.splitAny(u8, path, "/\\");
    while (components.next()) |component| {
        if (std.mem.eql(u8, component, "Platform")) {
            const selected = components.next() orelse return true;
            if (!std.mem.eql(u8, selected, target.platform.directoryName())) return false;
        } else if (std.mem.eql(u8, component, "Target")) {
            const selected = components.next() orelse return true;
            if (!std.mem.eql(u8, selected, target.name())) return false;
        }
    }
    return true;
}

fn lessThan(_: void, left: []const u8, right: []const u8) bool {
    return std.mem.lessThan(u8, left, right);
}

test "recognize only root test block syntax" {
    try std.testing.expect(containsRootTest("test { assert(true) }"));
    try std.testing.expect(containsRootTest("func helper() {}\ntest \"named\" { assert(true) }"));
    try std.testing.expect(!containsRootTest("func test() {}"));
    try std.testing.expect(!containsRootTest("func main() { test { assert(true) } }"));
    try std.testing.expect(!containsRootTest("// test {}\nfunc main() { print(\"test {}\") }"));
}

test "discover recursive tests deterministically for the active target" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    for ([_][]const u8{ "Nested", ".hidden" }) |directory| {
        try temporary.dir.createDirPath(std.testing.io, directory);
    }
    for ([_][]const u8{ "MacOS", "Linux", "Windows" }) |platform| {
        const directory = try std.fmt.allocPrint(allocator, "Platform/{s}/Module", .{platform});
        try temporary.dir.createDirPath(std.testing.io, directory);
        const source = try std.fmt.allocPrint(allocator, "{s}/Platform.sx", .{directory});
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = source, .data = "test { assert(true) }" });
    }
    for (Target.recognized) |target| {
        const directory = try std.fmt.allocPrint(allocator, "Target/{s}/Module", .{target.name()});
        try temporary.dir.createDirPath(std.testing.io, directory);
        const source = try std.fmt.allocPrint(allocator, "{s}/Selected.sx", .{directory});
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = source, .data = "test { assert(true) }" });
    }

    const files = [_]struct { path: []const u8, source: []const u8 }{
        .{ .path = "Zeta.sx", .source = "test { assert(true) }" },
        .{ .path = "Nested/Alpha.sx", .source = "test \"alpha\" { assert(true) }" },
        .{ .path = "Nested/NoTest.sx", .source = "func test() {}" },
        .{ .path = ".hidden/Hidden.sx", .source = "test { assert(false) }" },
    };
    for (files) |file| try temporary.dir.writeFile(std.testing.io, .{ .sub_path = file.path, .data = file.source });

    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    for (Target.recognized) |target| {
        const found = try sources(allocator, std.testing.io, root, target);
        const platform_source = try std.fmt.allocPrint(
            allocator,
            "Platform/{s}/Module/Platform.sx",
            .{target.platform.directoryName()},
        );
        const target_source = try std.fmt.allocPrint(
            allocator,
            "Target/{s}/Module/Selected.sx",
            .{target.name()},
        );
        try std.testing.expectEqual(@as(usize, 4), found.len);
        try std.testing.expect(std.mem.endsWith(u8, found[0], "Nested/Alpha.sx"));
        try std.testing.expect(std.mem.endsWith(u8, found[1], platform_source));
        try std.testing.expect(std.mem.endsWith(u8, found[2], target_source));
        try std.testing.expect(std.mem.endsWith(u8, found[3], "Zeta.sx"));
    }
}

test "keep an explicit source even when it has no test block" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Empty.sx", .data = "func main() {}" });
    const path = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Empty.sx" });
    const found = try sources(allocator, std.testing.io, path, .macos_arm64);
    try std.testing.expectEqual(@as(usize, 1), found.len);
    try std.testing.expectEqualStrings(path, found[0]);
}
