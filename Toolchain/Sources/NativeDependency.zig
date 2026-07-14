const std = @import("std");
const TargetModule = @import("Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Dependency = struct {
    name: []const u8,
    manifest_path: []const u8,
    sources: []const []const u8,
    targets: []const []const u8,

    pub fn supports(self: Dependency, allocator: Allocator, target: TargetModule.Target) !bool {
        const target_name = try target.cacheName(allocator);
        for (self.targets) |supported_target| {
            if (std.mem.eql(u8, supported_target, target_name)) return true;
        }
        return false;
    }
};

pub const SourceKind = enum { c, cpp, objective_c, objective_cpp };

pub const SourceFile = struct {
    kind: SourceKind,
    path: []const u8,
};

pub const ModuleRuntime = struct {
    module_name: []const u8,
    module_directory: []const u8,
    manifest_path: []const u8,
    sources: []const SourceFile,
    include_dirs: []const []const u8,
    defines: []const []const u8,
    system_libraries: []const []const u8,
    frameworks: []const []const u8,
};

const Manifest = struct {
    name: []const u8,
    sources: []const []const u8,
    targets: []const []const u8,
};

const SourceLists = struct {
    c: []const []const u8 = &.{},
    cpp: []const []const u8 = &.{},
    objective_c: []const []const u8 = &.{},
    objective_cpp: []const []const u8 = &.{},
};

const RuntimeConfiguration = struct {
    sources: SourceLists = .{},
    include_dirs: []const []const u8 = &.{},
    defines: std.json.Value = .{ .object = .empty },
    system_libraries: []const []const u8 = &.{},
    frameworks: []const []const u8 = &.{},
};

pub fn load(allocator: Allocator, io: Io, manifest_path: []const u8) !Dependency {
    const contents = try Io.Dir.cwd().readFileAlloc(io, manifest_path, allocator, .limited(1024 * 1024));
    const manifest = try std.json.parseFromSliceLeaky(Manifest, allocator, contents, .{
        .allocate = .alloc_always,
    });
    if (manifest.name.len == 0 or manifest.sources.len == 0 or manifest.targets.len == 0) {
        return error.IncompleteNativeDependency;
    }

    const manifest_dir = std.fs.path.dirname(manifest_path) orelse ".";
    const sources = try allocator.alloc([]const u8, manifest.sources.len);
    for (manifest.sources, 0..) |source, index| {
        sources[index] = try std.fs.path.join(allocator, &.{ manifest_dir, source });
    }

    return .{
        .name = manifest.name,
        .manifest_path = manifest_path,
        .sources = sources,
        .targets = manifest.targets,
    };
}

pub fn loadModuleRuntime(
    allocator: Allocator,
    io: Io,
    module_name: []const u8,
    module_directory: []const u8,
    manifest_path: []const u8,
    target: TargetModule.Target,
) !ModuleRuntime {
    const contents = try Io.Dir.cwd().readFileAlloc(io, manifest_path, allocator, .limited(1024 * 1024));
    const value = try std.json.parseFromSliceLeaky(std.json.Value, allocator, contents, .{});
    const root = switch (value) {
        .object => |object| object,
        else => return error.InvalidNativeModuleManifest,
    };
    try requireOnlyFields(root, &.{ "common", "targets" });
    const common_value = root.get("common") orelse return error.InvalidNativeModuleManifest;
    const targets_value = root.get("targets") orelse return error.InvalidNativeModuleManifest;
    const common = try parseConfiguration(allocator, common_value);
    const targets = switch (targets_value) {
        .object => |object| object,
        else => return error.InvalidNativeModuleManifest,
    };
    const target_name = try target.cacheName(allocator);
    const target_value = targets.get(target_name) orelse return error.NativeModuleTargetUnsupported;
    const target_configuration = try parseConfiguration(allocator, target_value);

    var sources: std.ArrayList(SourceFile) = .empty;
    var include_dirs: std.ArrayList([]const u8) = .empty;
    var defines: std.ArrayList([]const u8) = .empty;
    var system_libraries: std.ArrayList([]const u8) = .empty;
    var frameworks: std.ArrayList([]const u8) = .empty;
    try appendConfiguration(
        allocator,
        io,
        module_directory,
        common,
        &sources,
        &include_dirs,
        &defines,
        &system_libraries,
        &frameworks,
    );
    try appendConfiguration(
        allocator,
        io,
        module_directory,
        target_configuration,
        &sources,
        &include_dirs,
        &defines,
        &system_libraries,
        &frameworks,
    );
    return .{
        .module_name = module_name,
        .module_directory = module_directory,
        .manifest_path = manifest_path,
        .sources = try sources.toOwnedSlice(allocator),
        .include_dirs = try include_dirs.toOwnedSlice(allocator),
        .defines = try defines.toOwnedSlice(allocator),
        .system_libraries = try system_libraries.toOwnedSlice(allocator),
        .frameworks = try frameworks.toOwnedSlice(allocator),
    };
}

fn parseConfiguration(allocator: Allocator, value: std.json.Value) !RuntimeConfiguration {
    return std.json.parseFromValueLeaky(RuntimeConfiguration, allocator, value, .{
        .ignore_unknown_fields = false,
    });
}

fn requireOnlyFields(object: std.json.ObjectMap, allowed: []const []const u8) !void {
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        var accepted = false;
        for (allowed) |field| {
            if (std.mem.eql(u8, entry.key_ptr.*, field)) {
                accepted = true;
                break;
            }
        }
        if (!accepted) return error.InvalidNativeModuleManifest;
    }
}

fn appendConfiguration(
    allocator: Allocator,
    io: Io,
    module_directory: []const u8,
    configuration: RuntimeConfiguration,
    sources: *std.ArrayList(SourceFile),
    include_dirs: *std.ArrayList([]const u8),
    defines: *std.ArrayList([]const u8),
    system_libraries: *std.ArrayList([]const u8),
    frameworks: *std.ArrayList([]const u8),
) !void {
    try appendSources(allocator, io, module_directory, .c, configuration.sources.c, sources);
    try appendSources(allocator, io, module_directory, .cpp, configuration.sources.cpp, sources);
    try appendSources(allocator, io, module_directory, .objective_c, configuration.sources.objective_c, sources);
    try appendSources(allocator, io, module_directory, .objective_cpp, configuration.sources.objective_cpp, sources);
    for (configuration.include_dirs) |path| {
        const resolved = try resolveModulePath(allocator, io, module_directory, path);
        const stat = try Io.Dir.cwd().statFile(io, resolved, .{});
        if (stat.kind != .directory) return error.InvalidNativeModuleManifest;
        try include_dirs.append(allocator, resolved);
    }
    try appendDefines(allocator, configuration.defines, defines);
    try appendLinkNames(allocator, configuration.system_libraries, system_libraries);
    try appendLinkNames(allocator, configuration.frameworks, frameworks);
}

fn appendSources(
    allocator: Allocator,
    io: Io,
    module_directory: []const u8,
    kind: SourceKind,
    paths: []const []const u8,
    sources: *std.ArrayList(SourceFile),
) !void {
    for (paths) |path| {
        const resolved = try resolveModulePath(allocator, io, module_directory, path);
        const stat = try Io.Dir.cwd().statFile(io, resolved, .{});
        if (stat.kind != .file) return error.InvalidNativeModuleManifest;
        try sources.append(allocator, .{ .kind = kind, .path = resolved });
    }
}

fn appendDefines(allocator: Allocator, value: std.json.Value, defines: *std.ArrayList([]const u8)) !void {
    const object = switch (value) {
        .object => |object| object,
        else => return error.InvalidNativeModuleManifest,
    };
    var iterator = object.iterator();
    while (iterator.next()) |entry| {
        const define_value = switch (entry.value_ptr.*) {
            .string => |string| string,
            else => return error.InvalidNativeModuleManifest,
        };
        if (!isLinkName(entry.key_ptr.*)) return error.InvalidNativeModuleManifest;
        try defines.append(allocator, try std.fmt.allocPrint(allocator, "{s}={s}", .{ entry.key_ptr.*, define_value }));
    }
}

fn appendLinkNames(allocator: Allocator, names: []const []const u8, result: *std.ArrayList([]const u8)) !void {
    for (names) |name| {
        if (!isLinkName(name)) return error.InvalidNativeModuleManifest;
        try result.append(allocator, name);
    }
}

fn resolveModulePath(allocator: Allocator, io: Io, module_directory: []const u8, path: []const u8) ![]const u8 {
    if (path.len == 0 or std.fs.path.isAbsolute(path)) return error.InvalidNativeModuleManifest;
    var components = std.mem.tokenizeAny(u8, path, "/\\");
    while (components.next()) |component| {
        if (std.mem.eql(u8, component, ".") or std.mem.eql(u8, component, "..")) return error.InvalidNativeModuleManifest;
    }
    const joined = try std.fs.path.join(allocator, &.{ module_directory, path });
    const canonical_module_directory = try Io.Dir.cwd().realPathFileAlloc(io, module_directory, allocator);
    const canonical_path = try Io.Dir.cwd().realPathFileAlloc(io, joined, allocator);
    if (!isPathWithin(canonical_module_directory, canonical_path)) return error.InvalidNativeModuleManifest;
    return canonical_path;
}

fn isPathWithin(root: []const u8, path: []const u8) bool {
    return std.mem.startsWith(u8, path, root) and path.len > root.len and path[root.len] == std.fs.path.sep;
}

fn isLinkName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |character| {
        if (!std.ascii.isAlphanumeric(character) and character != '_' and character != '+' and character != '-' and character != '.') return false;
    }
    return true;
}

test "dependency declares supported targets" {
    const dependency: Dependency = .{
        .name = "example",
        .manifest_path = "example.json",
        .sources = &.{"example.cpp"},
        .targets = &.{"x86_64-linux-musl"},
    };
    const target = try TargetModule.Target.parse(std.testing.allocator, std.testing.io, "x86_64-linux-musl");
    defer std.testing.allocator.free(target.zig_triple.?);

    try std.testing.expect(try dependency.supports(std.testing.allocator, target));
    try std.testing.expect(!try dependency.supports(std.testing.allocator, TargetModule.Target.native()));
}
