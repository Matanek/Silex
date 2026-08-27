const std = @import("std");
const Ast = @import("../Ast.zig");
const Modules = @import("../Modules.zig");
const Packages = @import("../Packages.zig");
const ParserModule = @import("../Parser.zig");
const Paths = @import("../Project/Paths.zig");
const Reexports = @import("../Project/Reexports.zig");
const TargetModule = @import("../Target.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const IndexedProject = struct {
    graph: Packages.Graph,
    index: Modules.Index,
    current_owner: usize,
    current_path: []const u8,
    package_context_prefix: []const u8,
};

pub const LoadedProgram = struct {
    source: []const u8,
    program: Ast.Program,
};

pub const CatalogUse = struct {
    provider: Modules.Provider,
    use: Ast.Use,
};

pub fn catalogUses(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    catalog_provider: Modules.Provider,
) ![]const CatalogUse {
    var result: std.ArrayList(CatalogUse) = .empty;
    for (project.index.providers) |provider| {
        if (provider.origin != .portable) continue;
        const package_name = project.graph.packages[provider.owner].name orelse continue;
        if (!std.mem.eql(u8, provider.name, package_name)) continue;
        if (!project.graph.canContributeToCatalog(provider.owner, catalog_provider.owner, catalog_provider.name)) continue;
        const loaded = try loadProgram(allocator, io, documents, provider) orelse continue;
        for (loaded.program.catalog_contributions) |contribution| {
            if (!std.mem.eql(u8, contribution.target, catalog_provider.name)) continue;
            for (contribution.uses) |use| {
                if (!try useDirectlyOwned(allocator, io, documents, project, provider.owner, use.path)) continue;
                try result.append(allocator, .{ .provider = provider, .use = use });
            }
        }
    }
    return result.toOwnedSlice(allocator);
}

fn useDirectlyOwned(
    allocator: Allocator,
    io: Io,
    documents: []const Types.Document,
    project: IndexedProject,
    owner: usize,
    path: []const u8,
) !bool {
    var module_name: ?[]const u8 = null;
    for (project.index.providers) |provider| {
        const matches = std.mem.eql(u8, path, provider.name) or
            (path.len > provider.name.len and std.mem.startsWith(u8, path, provider.name) and
                path[provider.name.len] == '.');
        if (!matches or provider.owner != owner or (module_name != null and provider.name.len <= module_name.?.len)) continue;
        module_name = provider.name;
    }
    const module = module_name orelse return false;
    const declaration = if (path.len == module.len)
        lastSegment(module)
    else
        path[module.len + 1 ..];
    for (project.index.providers) |provider| {
        if (provider.owner != owner or !std.mem.eql(u8, provider.name, module)) continue;
        const loaded = try loadProgram(allocator, io, documents, provider) orelse continue;
        for (loaded.program.functions) |function| {
            if (function.is_public and std.mem.eql(u8, function.name, declaration)) return true;
        }
        for (loaded.program.structures) |structure| {
            if (Reexports.structureExported(loaded.program, structure) and std.mem.eql(u8, structure.name, declaration)) return true;
        }
        for (loaded.program.enums) |enumeration| {
            if (enumeration.is_public and std.mem.eql(u8, enumeration.name, declaration)) return true;
        }
    }
    return false;
}

fn lastSegment(path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return path;
    return path[separator + 1 ..];
}

pub fn index(
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8,
    target: TargetModule.Target,
    root: []const u8,
    document_path: []const u8,
) !IndexedProject {
    var resolver = Packages.Resolver.initForTarget(allocator, io, global_packages_root, target);
    resolver.enableDevelopmentDependencies();
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
    const module_index = try Modules.combineWithMerges(
        allocator,
        indexes.items,
        try graph.moduleMerges(allocator),
    );
    var current_owner: usize = 0;
    var current_provider: ?Modules.Provider = null;
    for (module_index.providers) |provider| if (samePath(provider.path, document_path)) {
        current_owner = provider.owner;
        current_provider = provider;
        break;
    };
    const package_context_prefix = if (!graph.explicit and graph.packages[0].name == null)
        if (current_provider) |provider| provider.local_prefix else ""
    else
        "";
    return .{
        .graph = graph,
        .index = module_index,
        .current_owner = current_owner,
        .current_path = document_path,
        .package_context_prefix = package_context_prefix,
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

pub fn currentProvider(project: IndexedProject) ?Modules.Provider {
    for (project.index.providers) |provider| {
        if (samePath(provider.path, project.current_path)) return provider;
    }
    return null;
}

pub fn canonicalUsePath(
    allocator: Allocator,
    project: IndexedProject,
    source_provider: Modules.Provider,
    path: []const u8,
) ![]const u8 {
    const package_prefix = "Package.";
    const module_prefix = "Module.";
    if (std.mem.startsWith(u8, path, package_prefix)) {
        const relative = path[package_prefix.len..];
        const package_name = project.graph.packages[source_provider.owner].name orelse
            if (source_provider.owner == 0) project.package_context_prefix else "";
        if (package_name.len == 0) return relative;
        return std.fmt.allocPrint(allocator, "{s}.{s}", .{ package_name, relative });
    }
    if (std.mem.startsWith(u8, path, module_prefix)) {
        const relative = path[module_prefix.len..];
        if (source_provider.local_prefix.len == 0) return relative;
        return std.fmt.allocPrint(allocator, "{s}.{s}", .{ source_provider.local_prefix, relative });
    }
    return path;
}

pub fn projectRoot(allocator: Allocator, io: Io, document_path: []const u8, root_hint: ?[]const u8) ![]const u8 {
    return Paths.findRootWithin(allocator, io, document_path, root_hint);
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
