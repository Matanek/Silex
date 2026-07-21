const std = @import("std");
const Ast = @import("Ast.zig");
const Generics = @import("Generics.zig");
const Modules = @import("Modules.zig");
const PackageGraph = @import("PackageGraph.zig");
const ProjectModule = @import("Project.zig");
const Semantic = @import("Semantic.zig");
const Source = @import("Source.zig");
const SourceGraph = @import("SourceGraph.zig");
const SymbolIndex = @import("SymbolIndex.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Mode = enum { compiler, editor };
pub const Overlay = SourceGraph.Overlay;

pub const Snapshot = struct {
    project: ProjectModule.Project,
    package_graph: PackageGraph.Graph,
    source_paths: []const []const u8,
    source_contents: []const []const u8,
    files: []const Modules.File,
    ast: Ast.Program,
    specialized_ast: Ast.Program,
    program: Semantic.Program,
    index: SymbolIndex.Index,
};

pub const Failure = struct {
    source_paths: []const []const u8,
    source_contents: []const []const u8,
    diagnostic: Source.Diagnostic,
};

pub const Outcome = union(enum) {
    success: Snapshot,
    failure: Failure,
};

pub fn analyze(
    allocator: Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    input_path: []const u8,
    mode: Mode,
    overlays: []const Overlay,
) !Outcome {
    var loader = SourceGraph.Loader.init(allocator, io, environ_map);
    loader.mode = if (mode == .editor) .editor else .compiler;
    loader.overlays = overlays;
    const loaded = loader.load(input_path) catch |err| switch (err) {
        error.InvalidSource => return .{ .failure = .{
            .source_paths = loader.source_paths.items,
            .source_contents = loader.source_contents.items,
            .diagnostic = loader.diagnostic.?,
        } },
        else => |other| return other,
    };
    return analyzeLoaded(allocator, io, mode, loaded, true);
}

pub fn analyzeProject(
    allocator: Allocator,
    io: Io,
    environ_map: *const std.process.Environ.Map,
    project: ProjectModule.Project,
    project_root: []const u8,
    mode: Mode,
    overlays: []const Overlay,
    require_main: bool,
) !Outcome {
    var loader = SourceGraph.Loader.init(allocator, io, environ_map);
    loader.mode = if (mode == .editor) .editor else .compiler;
    loader.overlays = overlays;
    const loaded = loader.loadProject(project, project_root) catch |err| switch (err) {
        error.InvalidSource => return .{ .failure = .{
            .source_paths = loader.source_paths.items,
            .source_contents = loader.source_contents.items,
            .diagnostic = loader.diagnostic.?,
        } },
        else => |other| return other,
    };
    return analyzeLoaded(allocator, io, mode, loaded, require_main);
}

fn analyzeLoaded(
    allocator: Allocator,
    io: Io,
    mode: Mode,
    loaded: SourceGraph.Loaded,
    require_main: bool,
) !Outcome {
    const source_paths = try canonicalizePaths(allocator, io, loaded.source_paths);

    var resolver = Modules.Resolver.init(allocator, loaded.project, loaded.files);
    const ast = resolver.resolve() catch |err| switch (err) {
        error.InvalidSource => return .{ .failure = .{
            .source_paths = diagnosticPaths(mode, loaded.source_paths, source_paths),
            .source_contents = loaded.source_contents,
            .diagnostic = resolver.diagnostic.?,
        } },
        else => |other| return other,
    };

    var specializer = Generics.Specializer.init(allocator, ast);
    const specialized_ast = specializer.specialize() catch |err| switch (err) {
        error.InvalidSource => return .{ .failure = .{
            .source_paths = diagnosticPaths(mode, loaded.source_paths, source_paths),
            .source_contents = loaded.source_contents,
            .diagnostic = specializer.diagnostic.?,
        } },
        else => |other| return other,
    };

    var analyzer = Semantic.Analyzer.init(allocator);
    analyzer.native_module_names = try nativeModuleNames(allocator, loaded.project);
    analyzer.require_main = require_main;
    const program = analyzer.analyze(specialized_ast) catch |err| switch (err) {
        error.InvalidSource => return .{ .failure = .{
            .source_paths = diagnosticPaths(mode, loaded.source_paths, source_paths),
            .source_contents = loaded.source_contents,
            .diagnostic = analyzer.diagnostic.?,
        } },
        else => |other| return other,
    };

    return .{ .success = .{
        .project = loaded.project,
        .package_graph = loaded.package_graph,
        .source_paths = source_paths,
        .source_contents = loaded.source_contents,
        .files = loaded.files,
        .ast = ast,
        .specialized_ast = specialized_ast,
        .program = program,
        .index = try SymbolIndex.build(
            allocator,
            loaded.project,
            loaded.files,
            loaded.source_contents,
            specialized_ast,
            program,
        ),
    } };
}

fn nativeModuleNames(allocator: Allocator, project: ProjectModule.Project) ![]const []const u8 {
    var names: std.ArrayList([]const u8) = .empty;
    for (project.modules) |module| {
        if (module.module_manifest_path != null) try names.append(allocator, module.name);
    }
    return names.toOwnedSlice(allocator);
}

fn canonicalizePaths(allocator: Allocator, io: Io, paths: []const []const u8) ![]const []const u8 {
    const canonical = try allocator.alloc([]const u8, paths.len);
    for (paths, 0..) |path, index| canonical[index] = try SourceGraph.canonicalPath(allocator, io, path);
    return canonical;
}

fn diagnosticPaths(mode: Mode, original: []const []const u8, canonical: []const []const u8) []const []const u8 {
    return if (mode == .compiler) original else canonical;
}
