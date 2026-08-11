const std = @import("std");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");
const Packages = @import("../Packages.zig");
const ParserModule = @import("../Parser.zig");
const TargetModule = @import("../Target.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const IndexedProject = struct {
    graph: Packages.Graph,
    index: Modules.Index,
    current_owner: usize,
    current_path: []const u8,
};

pub const LoadedProgram = struct {
    source: []const u8,
    program: Ast.Program,
};

pub fn index(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    target: TargetModule.Target,
    root: []const u8,
    document_path: []const u8,
) !IndexedProject {
    var resolver = Packages.Resolver.initForTarget(allocator, io, global_packages_root, target);
    const graph = try resolver.resolve(root);
    var indexes: std.ArrayList(Modules.Index) = .empty;
    const excluded_roots = try allocator.alloc([]const u8, graph.packages.len - 1);
    for (graph.packages[1..], excluded_roots) |package, *package_root| package_root.* = package.root;
    for (graph.packages, 0..) |package, owner| {
        for (package.module_roots) |module_root| {
            const discovered = if (owner == 0)
                try Modules.discoverOwnedExcludingAs(
                    allocator,
                    io,
                    module_root.path,
                    package.name,
                    owner,
                    excluded_roots,
                    module_root.origin,
                )
            else
                try Modules.discoverOwnedAs(
                    allocator,
                    io,
                    module_root.path,
                    package.name,
                    owner,
                    module_root.origin,
                );
            try indexes.append(allocator, discovered);
        }
    }
    const module_index = try Modules.combine(allocator, indexes.items);
    var current_owner: usize = 0;
    for (module_index.providers) |provider| if (samePath(provider.path, document_path)) {
        current_owner = provider.owner;
        break;
    };
    return .{
        .graph = graph,
        .index = module_index,
        .current_owner = current_owner,
        .current_path = document_path,
    };
}

pub fn loadProgram(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    provider: Modules.Provider,
) !?LoadedProgram {
    var source: ?[]const u8 = null;
    for (documents) |document| {
        const path = pathFromUri(allocator, document.uri) catch continue;
        if (samePath(path, provider.path)) {
            source = document.text;
            break;
        }
    }
    if (source) |overlay| {
        var parser = ParserModule.Parser.init(allocator, overlay);
        if (parser.parse()) |program| return .{ .source = overlay, .program = program } else |_| {}
    }
    const disk = Io.Dir.cwd().readFileAlloc(io, provider.path, allocator, .limited(1024 * 1024)) catch return null;
    var parser = ParserModule.Parser.init(allocator, disk);
    const program = parser.parse() catch return null;
    return .{ .source = disk, .program = program };
}

pub fn projectRoot(allocator: Allocator, io: Io, document_path: []const u8, root_hint: ?[]const u8) ![]const u8 {
    var directory = std.fs.path.dirname(document_path) orelse ".";
    const document_directory = directory;
    const boundary = root_hint orelse directory;
    while (true) {
        const manifest = try std.fs.path.join(allocator, &.{ directory, "Package.json" });
        if (fileExists(io, manifest)) return directory;
        if (samePath(directory, boundary)) return document_directory;
        const next = std.fs.path.dirname(directory) orelse return document_directory;
        if (!pathInside(directory, boundary) or std.mem.eql(u8, next, directory)) return document_directory;
        directory = next;
    }
}

pub fn pathFromUri(allocator: Allocator, uri: []const u8) ![]const u8 {
    const prefix = "file://";
    if (!std.mem.startsWith(u8, uri, prefix)) return allocator.dupe(u8, uri);
    const encoded = uri[prefix.len..];
    var decoded: std.ArrayList(u8) = .empty;
    var index_value: usize = 0;
    while (index_value < encoded.len) {
        if (encoded[index_value] == '%' and index_value + 2 < encoded.len) {
            const high = hex(encoded[index_value + 1]);
            const low = hex(encoded[index_value + 2]);
            if (high != null and low != null) {
                try decoded.append(allocator, high.? * 16 + low.?);
                index_value += 3;
                continue;
            }
        }
        try decoded.append(allocator, encoded[index_value]);
        index_value += 1;
    }
    return decoded.toOwnedSlice(allocator);
}

fn samePath(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, std.mem.trimEnd(u8, left, "/"), std.mem.trimEnd(u8, right, "/"));
}

fn pathInside(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory) or path.len <= directory.len) return false;
    return path[directory.len] == std.fs.path.sep;
}

fn fileExists(io: Io, path: []const u8) bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

fn hex(character: u8) ?u8 {
    return switch (character) {
        '0'...'9' => character - '0',
        'a'...'f' => character - 'a' + 10,
        'A'...'F' => character - 'A' + 10,
        else => null,
    };
}

test "reject a package that requires a newer Silex before LSP indexing" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Modern/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Modern/Package.json",
        .data =
        \\{"name":"Modern","version":"1.0.0","requires":{"silex":">=99.0.0 <100.0.0"}}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Modern/Module/Main.sx",
        .data = "func main() {}",
    });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Modern" });
    const document = try std.fs.path.join(allocator, &.{ root, "Module", "Main.sx" });
    try std.testing.expectError(
        error.InvalidPackageGraph,
        index(allocator, std.testing.io, null, .macos_arm64, root, document),
    );
}
