const std = @import("std");
const Ast = @import("Ast.zig");
const Modules = @import("Modules.zig");
const ParserModule = @import("Parser.zig");
const ProjectModule = @import("Project.zig");
const Source = @import("Source.zig");
const StandardLibrary = @import("StandardLibrary.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

const ModuleBuilder = struct {
    name: []const u8,
    sources: std.ArrayList([]const u8) = .empty,
    provider: Provider,
    native_manifest_path: ?[]const u8 = null,
    native_module_directory: ?[]const u8 = null,
};

const Provider = enum { application, local, distributed };

pub const Loaded = struct {
    project: ProjectModule.Project,
    source_paths: []const []const u8,
    source_contents: []const []const u8,
    files: []const Modules.File,
};

pub const Loader = struct {
    allocator: Allocator,
    io: Io,
    source_paths: std.ArrayList([]const u8) = .empty,
    source_contents: std.ArrayList([]const u8) = .empty,
    files: std.ArrayList(Modules.File) = .empty,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: Allocator, io: Io) Loader {
        return .{ .allocator = allocator, .io = io };
    }

    pub fn load(self: *Loader, input_path: []const u8) !Loaded {
        var project = try ProjectModule.load(self.allocator, self.io, input_path);
        var modules: std.ArrayList(ModuleBuilder) = .empty;
        for (project.modules) |module| {
            var sources: std.ArrayList([]const u8) = .empty;
            try sources.appendSlice(self.allocator, module.sources);
            try modules.append(self.allocator, .{
                .name = module.name,
                .sources = sources,
                .provider = .application,
            });
        }
        for (project.modules, 0..) |module, module_index| for (module.sources) |source_path| {
            try self.appendFile(source_path, module_index);
        };

        const loads_local_modules = project.single_file;
        const project_root = std.fs.path.dirname(input_path) orelse ".";
        var file_index: usize = 0;
        while (file_index < self.files.items.len) : (file_index += 1) {
            const file = self.files.items[file_index];
            for (file.program.imports) |import_value| {
                if (StandardLibrary.isReservedModule(import_value.path)) {
                    try self.loadDistributedModule(&modules, import_value.path, import_value.position);
                } else if (loads_local_modules) {
                    try self.loadLocalOrDistributedModule(&modules, project_root, import_value.path, import_value.position);
                } else {
                    try self.loadDistributedModule(&modules, import_value.path, import_value.position);
                }
            }
            for (file.program.uses) |use_value| {
                if (useUsesImportAlias(file.program.imports, use_value.path)) continue;
                const module_name = moduleNameFromUse(use_value.path) orelse continue;
                if (StandardLibrary.isReservedModule(module_name)) {
                    try self.loadDistributedModule(&modules, module_name, use_value.position);
                } else if (loads_local_modules) {
                    try self.loadLocalOrDistributedModule(&modules, project_root, module_name, use_value.position);
                } else {
                    try self.loadDistributedModule(&modules, module_name, use_value.position);
                }
            }
        }

        var project_modules: std.ArrayList(ProjectModule.Module) = .empty;
        for (modules.items) |*module| try project_modules.append(self.allocator, .{
            .name = module.name,
            .sources = try module.sources.toOwnedSlice(self.allocator),
            .native_manifest_path = module.native_manifest_path,
            .native_module_directory = module.native_module_directory,
        });
        project.modules = try project_modules.toOwnedSlice(self.allocator);
        project.single_file = loads_local_modules and self.files.items.len == 1;
        return self.finish(project);
    }

    fn loadLocalOrDistributedModule(
        self: *Loader,
        modules: *std.ArrayList(ModuleBuilder),
        project_root: []const u8,
        module_name: []const u8,
        position: Source.Position,
    ) !void {
        const local_path = try localModulePath(self.allocator, project_root, module_name);
        const has_local = try isDirectory(self.io, local_path);
        const library_root = StandardLibrary.root(self.allocator, self.io) catch |err| {
            if (has_local) return self.loadModule(modules, project_root, module_name, position, .local);
            return err;
        };
        const distributed_path = try localModulePath(self.allocator, library_root, module_name);
        const has_distributed = try isDirectory(self.io, distributed_path);
        if (has_local and has_distributed) return self.multipleProviders(position, module_name);
        if (findModule(modules.items, module_name) != null and !has_distributed) return;
        if (has_local) return self.loadModule(modules, project_root, module_name, position, .local);
        if (has_distributed) return self.loadModule(modules, library_root, module_name, position, .distributed);
        const message = try std.fmt.allocPrint(
            self.allocator,
            "local module '{s}' was not found at '{s}'",
            .{ module_name, local_path },
        );
        return self.fail(position, message);
    }

    fn loadDistributedModule(
        self: *Loader,
        modules: *std.ArrayList(ModuleBuilder),
        module_name: []const u8,
        position: Source.Position,
    ) !void {
        const library_root = StandardLibrary.root(self.allocator, self.io) catch {
            if (findModule(modules.items, module_name) != null) return;
            const message = try std.fmt.allocPrint(
                self.allocator,
                "distributed library required by module '{s}' was not found; reinstall Silex",
                .{module_name},
            );
            return self.fail(position, message);
        };
        const directory_path = try localModulePath(self.allocator, library_root, module_name);
        if (!try isDirectory(self.io, directory_path)) {
            if (findModule(modules.items, module_name) != null) return;
            const message = try std.fmt.allocPrint(self.allocator, "module '{s}' was not found", .{module_name});
            return self.fail(position, message);
        }
        try self.loadModule(modules, library_root, module_name, position, .distributed);
    }

    fn loadModule(
        self: *Loader,
        modules: *std.ArrayList(ModuleBuilder),
        module_root: []const u8,
        module_name: []const u8,
        position: Source.Position,
        provider: Provider,
    ) !void {
        if (findModule(modules.items, module_name)) |existing_index| {
            if (modules.items[existing_index].provider != provider) return self.multipleProviders(position, module_name);
            return;
        }

        const directory_path = try localModulePath(self.allocator, module_root, module_name);
        var directory = Io.Dir.cwd().openDir(self.io, directory_path, .{ .iterate = true }) catch |err| switch (err) {
            error.FileNotFound, error.NotDir => {
                return self.moduleNotFound(position, module_name, directory_path, null);
            },
            else => |other| return other,
        };
        defer directory.close(self.io);

        var source_names: std.ArrayList([]const u8) = .empty;
        var iterator = directory.iterateAssumeFirstIteration();
        while (try iterator.next(self.io)) |entry| {
            if (entry.kind != .file or !std.mem.endsWith(u8, entry.name, ".sx")) continue;
            try source_names.append(self.allocator, try self.allocator.dupe(u8, entry.name));
        }
        std.mem.sort([]const u8, source_names.items, {}, struct {
            fn lessThan(_: void, left: []const u8, right: []const u8) bool {
                return std.mem.lessThan(u8, left, right);
            }
        }.lessThan);

        if (source_names.items.len == 0) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "module '{s}' has no direct .sx source in '{s}'",
                .{ module_name, directory_path },
            );
            return self.fail(position, message);
        }

        const module_index = modules.items.len;
        const native_manifest_path = if (provider == .distributed)
            try nativeManifestPath(self.allocator, self.io, directory_path)
        else
            null;
        try modules.append(self.allocator, .{
            .name = module_name,
            .provider = provider,
            .native_manifest_path = native_manifest_path,
            .native_module_directory = if (native_manifest_path != null) directory_path else null,
        });
        for (source_names.items) |source_name| {
            const source_path = try std.fs.path.join(self.allocator, &.{ directory_path, source_name });
            try modules.items[module_index].sources.append(self.allocator, source_path);
            try self.appendFile(source_path, module_index);
        }
    }

    fn appendFile(self: *Loader, source_path: []const u8, module_index: usize) !void {
        const source = Io.Dir.cwd().readFileAlloc(self.io, source_path, self.allocator, .limited(16 * 1024 * 1024)) catch |err| {
            std.debug.print("silex: unable to read '{s}': {t}\n", .{ source_path, err });
            return error.Reported;
        };
        const file_index = self.source_paths.items.len;
        try self.source_paths.append(self.allocator, source_path);
        try self.source_contents.append(self.allocator, source);
        var parser = ParserModule.Parser.initFile(self.allocator, source, file_index);
        const program = parser.parse() catch |err| switch (err) {
            error.InvalidSource => {
                self.diagnostic = parser.diagnostic.?;
                return error.InvalidSource;
            },
            else => |other| return other,
        };
        try self.files.append(self.allocator, .{ .module_index = module_index, .program = program });
    }

    fn finish(self: *Loader, project: ProjectModule.Project) !Loaded {
        return .{
            .project = project,
            .source_paths = try self.source_paths.toOwnedSlice(self.allocator),
            .source_contents = try self.source_contents.toOwnedSlice(self.allocator),
            .files = try self.files.toOwnedSlice(self.allocator),
        };
    }

    fn fail(self: *Loader, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }

    fn multipleProviders(self: *Loader, position: Source.Position, module_name: []const u8) !void {
        return self.fail(position, try std.fmt.allocPrint(
            self.allocator,
            "module '{s}' has multiple providers",
            .{module_name},
        ));
    }

    fn moduleNotFound(
        self: *Loader,
        position: Source.Position,
        module_name: []const u8,
        local_path: []const u8,
        distributed_path: ?[]const u8,
    ) !void {
        const message = if (distributed_path) |path|
            try std.fmt.allocPrint(
                self.allocator,
                "module '{s}' was not found locally at '{s}' or in the distributed library at '{s}'",
                .{ module_name, local_path, path },
            )
        else
            try std.fmt.allocPrint(self.allocator, "module '{s}' was not found at '{s}'", .{ module_name, local_path });
        return self.fail(position, message);
    }
};

fn findModule(modules: []const ModuleBuilder, name: []const u8) ?usize {
    for (modules, 0..) |module, index| {
        if (std.mem.eql(u8, module.name, name)) return index;
    }
    return null;
}

fn moduleNameFromUse(path: []const u8) ?[]const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return null;
    return path[0..separator];
}

fn useUsesImportAlias(imports: []const Ast.Import, path: []const u8) bool {
    for (imports) |import_value| {
        const qualifier = import_value.alias orelse import_value.path;
        const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse continue;
        if (separator == qualifier.len and std.mem.startsWith(u8, path, qualifier)) return true;
    }
    return false;
}

fn localModulePath(allocator: Allocator, root: []const u8, module_name: []const u8) ![]const u8 {
    const relative_path = try allocator.dupe(u8, module_name);
    for (relative_path) |*character| {
        if (character.* == '.') character.* = std.fs.path.sep;
    }
    return std.fs.path.join(allocator, &.{ root, relative_path });
}

fn isDirectory(io: Io, path: []const u8) !bool {
    var directory = Io.Dir.cwd().openDir(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return false,
        else => |other| return other,
    };
    directory.close(io);
    return true;
}

fn nativeManifestPath(allocator: Allocator, io: Io, module_directory: []const u8) !?[]const u8 {
    const path = try std.fs.path.join(allocator, &.{ module_directory, "native.json" });
    const stat = Io.Dir.cwd().statFile(io, path, .{}) catch |err| switch (err) {
        error.FileNotFound => return null,
        else => |other| return other,
    };
    return if (stat.kind == .file) path else null;
}

test "local module paths follow their logical segments" {
    const path = try localModulePath(std.testing.allocator, "Sandbox", "Math.Geometry");
    defer std.testing.allocator.free(path);
    const expected = try std.fs.path.join(std.testing.allocator, &.{ "Sandbox", "Math", "Geometry" });
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualStrings(expected, path);
}

test "use paths select a declaration from their parent module" {
    try std.testing.expectEqualStrings("Math.Geometry", moduleNameFromUse("Math.Geometry.Ray").?);
    try std.testing.expect(moduleNameFromUse("Vec3") == null);
}
