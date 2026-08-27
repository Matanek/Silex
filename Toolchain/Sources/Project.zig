const std = @import("std");
const builtin = @import("builtin");
const Ast = @import("Ast.zig");
const Boundary = @import("Boundary.zig");
const Interface = @import("Interface.zig");
const GenericSpecializer = @import("Generics/Specializer.zig").Specializer;
const Result = @import("Intrinsics/Result.zig");
const Ir = @import("Ir.zig");
const Modules = @import("Modules.zig");
const Names = @import("Project/Names.zig");
const Packages = @import("Packages.zig");
const PackageTestFixtures = @import("Packages/TestFixtures.zig");
const Reexports = @import("Project/Reexports.zig");
const TypeAliases = @import("Project/TypeAliases.zig");
const GenericTypes = @import("Project/GenericTypes.zig");
const FunctionTypes = @import("Project/FunctionTypes.zig");
const Fragments = @import("Project/Fragments.zig");
const Loading = @import("Project/Loading.zig");
const Paths = @import("Project/Paths.zig");
const Lookup = @import("Project/Lookup.zig");
const Activation = @import("Project/Activation.zig");
const Rewriting = @import("Project/Rewriting.zig");
const Resolution = @import("Project/Resolution.zig");
const ProjectExtensions = @import("Project/Extensions.zig");
const Semantic = @import("Semantic/Analyzer.zig");
const Source = @import("Source.zig");
const TargetModule = @import("Target.zig");
const Extensions = @import("Extensions.zig");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const canonicalName = Names.canonical;
const expressionName = Names.expression;
const expressionPosition = Names.expressionPosition;
const findEnum = Names.findEnum;
const findName = Names.find;
const findStructure = Names.findStructure;
const lastSegment = Names.lastSegment;
const parent = Names.parent;
const sameParent = Names.sameParent;
const structureCanonicalName = Names.nominal;

pub const Error = anyerror;
pub const Compilation = struct {
    ast: Ast.Program,
    ir: Ir.Program,
    boundaries: []const Boundary.Function,
    interfaces: []const Interface.Module,
    packages: Packages.Graph,
    files: []const []const u8,
    cache_files: []const []const u8,
    tests: []const TestCase = &.{},
};
pub const TestCase = struct {
    name: ?[]const u8,
    function: Ir.FunctionId,
    position: Source.Position,
};
const Binding = Reexports.Binding;
const CatalogContribution = Reexports.CatalogContribution;
const Unit = Reexports.Unit;

const GeographicScope = enum(u8) { local, module, package, public };

fn geographicScope(declaration: anytype) GeographicScope {
    if (declaration.is_public) return .public;
    if (declaration.is_internal) return .package;
    if (declaration.is_local) return .local;
    if (comptime @hasField(@TypeOf(declaration), "is_private")) {
        if (declaration.is_private or declaration.is_protected) return .local;
    }
    return .module;
}

fn memberGeographicScope(member: anytype, container: Ast.Structure) GeographicScope {
    if (!member.visibility_explicit) return geographicScope(container);
    return geographicScope(member);
}

pub const Compiler = struct {
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8 = null,
    packages: Packages.Graph = undefined,
    index: Modules.Index = undefined,
    module_scope_roots: []const []const u8 = &.{},
    units: []Unit = &.{},
    catalog_contributions: []const CatalogContribution = &.{},
    files: []const []const u8 = &.{},
    entry_module: usize = 0,
    diagnostic: ?Source.Diagnostic = null,
    generic_type_maps: []const []const Ast.Type = &.{},
    function_type_maps: []const []const Ast.Type = &.{},
    cache_modules: bool = false,
    include_tests: bool = false,
    target: TargetModule.Target,
    shadercross_path: ?[]const u8 = null,

    pub fn init(allocator: Allocator, io: Io) Compiler {
        return .{ .allocator = allocator, .io = io, .target = TargetModule.Target.host() orelse .macos_arm64 };
    }

    pub fn initWithPackages(allocator: Allocator, io: Io, global_packages_root: ?[]const u8) Compiler {
        return .{
            .allocator = allocator,
            .io = io,
            .global_packages_root = global_packages_root,
            .target = TargetModule.Target.host() orelse .macos_arm64,
        };
    }

    pub fn initWithPackagesAndCache(
        allocator: Allocator,
        io: Io,
        global_packages_root: ?[]const u8,
        cache_modules: bool,
    ) Compiler {
        // JSON AST entries are currently slower and larger than reparsing the
        // source on GFX-sized graphs. Keep the explicit test hook available,
        // but do not pay that cost on command-line builds. Package-level
        // binary interfaces will replace this transitional cache.
        _ = cache_modules;
        return .{
            .allocator = allocator,
            .io = io,
            .global_packages_root = global_packages_root,
            .cache_modules = false,
            .target = TargetModule.Target.host() orelse .macos_arm64,
        };
    }

    pub fn compile(self: *Compiler, input_path: []const u8) Error!Compilation {
        self.include_tests = false;
        return self.compileConfigured(input_path);
    }

    pub fn compileTests(self: *Compiler, input_path: []const u8) Error!Compilation {
        self.include_tests = true;
        return self.compileConfigured(input_path);
    }

    fn compileConfigured(self: *Compiler, input_path: []const u8) Error!Compilation {
        self.diagnostic = null;
        if (!std.mem.endsWith(u8, input_path, ".sx")) {
            return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, "input must be a .sx source file");
        }

        const root_path = try Paths.findRoot(self.allocator, self.io, input_path);
        if (builtin.is_test) try PackageTestFixtures.prepareWorkspaceLinks(self.allocator, self.io, root_path);
        var package_resolver = Packages.Resolver.initForTarget(self.allocator, self.io, self.global_packages_root, self.target);
        package_resolver.enableDevelopmentDependencies();
        self.packages = package_resolver.resolve(root_path) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.fail(
                .{ .offset = 0, .line = 1, .column = 1 },
                package_resolver.diagnostic orelse "invalid package graph",
            ),
            else => |other| return other,
        };
        self.index = Lookup.discoverProviders(self, input_path) catch |err| switch (err) {
            error.DuplicateModule => return self.fail(
                .{ .offset = 0, .line = 1, .column = 1 },
                "multiple source files provide the same module",
            ),
            error.InvalidModulePath => return self.fail(
                .{ .offset = 0, .line = 1, .column = 1 },
                "a source path does not form a valid module name",
            ),
            else => |other| return other,
        };
        self.module_scope_roots = try self.collectModuleScopeRoots();
        self.units = try self.allocator.alloc(Unit, self.index.providers.len);
        @memset(self.units, .{});
        try Fragments.install(self.allocator, self.index, self.units);
        try Loading.discoverCatalogContributions(self);
        const files = try self.allocator.alloc([]const u8, self.index.providers.len);
        for (self.index.providers, 0..) |provider, file| files[file] = provider.path;
        self.files = files;

        self.entry_module = Lookup.findProviderPathCanonical(self, input_path) orelse return self.fail(
            .{ .offset = 0, .line = 1, .column = 1 },
            "entry source is not a discovered module",
        );
        try self.loadModule(self.entry_module, null);
        try self.validateTypeAliases();
        try self.validateReexports();

        var composition = try self.composeAst();
        var extensions = Extensions.Merger.init(self.allocator);
        composition.program = extensions.merge(composition.program, true, true) catch |err| {
            self.diagnostic = extensions.diagnostic;
            return err;
        };
        var specializer = GenericSpecializer.init(self.allocator);
        specializer.module_scope_roots = self.module_scope_roots;
        specializer.packages = self.packages;
        const ast = specializer.specialize(composition.program) catch |err| {
            self.diagnostic = specializer.diagnostic;
            return err;
        };
        const interfaces = try self.buildInterfaces(composition.type_maps);
        var analyzer = Semantic.Analyzer.init(self.allocator);
        analyzer.target = self.target;
        analyzer.packages = self.packages;
        analyzer.io = self.io;
        analyzer.source_files = self.files;
        analyzer.module_scope_roots = self.module_scope_roots;
        analyzer.shadercross_path = self.shadercross_path;
        var ir = (if (self.include_tests) analyzer.analyzeUnit(ast) else analyzer.analyze(ast)) catch |err| {
            self.diagnostic = analyzer.diagnostic;
            return err;
        };
        if (analyzer.shader_files.items.len != 0 or analyzer.embedded_files.items.len != 0) {
            const all_files = try self.allocator.alloc(
                []const u8,
                self.files.len + analyzer.shader_files.items.len + analyzer.embedded_files.items.len,
            );
            @memcpy(all_files[0..self.files.len], self.files);
            @memcpy(all_files[self.files.len..][0..analyzer.shader_files.items.len], analyzer.shader_files.items);
            @memcpy(all_files[self.files.len + analyzer.shader_files.items.len ..], analyzer.embedded_files.items);
            self.files = all_files;
        }
        ir.files = self.files;

        var dependency_files: std.ArrayList([]const u8) = .empty;
        for (self.units, 0..) |unit, module| {
            if (unit.state == .loaded) try dependency_files.append(self.allocator, self.index.providers[module].path);
        }
        for (self.catalog_contributions) |contribution| {
            const path = self.index.providers[contribution.contributor].path;
            var present = false;
            for (dependency_files.items) |existing| present = present or std.mem.eql(u8, existing, path);
            if (!present) try dependency_files.append(self.allocator, path);
        }
        try dependency_files.appendSlice(self.allocator, analyzer.shader_files.items);
        try dependency_files.appendSlice(self.allocator, analyzer.embedded_files.items);

        var tests: std.ArrayList(TestCase) = .empty;
        for (ast.functions, 0..) |function, function_id| {
            if (!function.is_test_entry) continue;
            try tests.append(self.allocator, .{
                .name = function.test_name,
                .function = function_id,
                .position = function.position,
            });
        }

        return .{
            .ast = ast,
            .ir = ir,
            .boundaries = analyzer.external_functions,
            .interfaces = interfaces,
            .packages = self.packages,
            .files = self.files,
            .cache_files = try dependency_files.toOwnedSlice(self.allocator),
            .tests = try tests.toOwnedSlice(self.allocator),
        };
    }

    fn collectModuleScopeRoots(self: *Compiler) Allocator.Error![]const []const u8 {
        var roots: std.ArrayList([]const u8) = .empty;
        for (self.index.providers) |provider| {
            const basename = std.fs.path.basename(provider.path);
            if (!std.mem.eql(u8, basename, Modules.principal_file) and
                !std.mem.eql(u8, basename, Modules.principal_file_capitalized)) continue;
            var found = false;
            for (roots.items) |root| if (std.mem.eql(u8, root, provider.name)) {
                found = true;
                break;
            };
            if (!found) try roots.append(self.allocator, provider.name);
        }
        return roots.toOwnedSlice(self.allocator);
    }

    pub fn diagnosticPath(self: Compiler, fallback: []const u8) []const u8 {
        const diagnostic = self.diagnostic orelse return fallback;
        if (diagnostic.path) |path| return path;
        if (diagnostic.position.file >= self.files.len) return fallback;
        return self.files[diagnostic.position.file];
    }

    pub fn loadModule(self: *Compiler, module: usize, from: ?usize) Error!void {
        return Loading.load(self, module, from);
    }

    pub fn resolveUse(self: *Compiler, source_module: usize, use: Ast.Use) Error!Binding {
        if (std.mem.eql(u8, use.path, "Interop.C") or
            std.mem.eql(u8, use.path, "Interop.Boundary") or
            std.mem.eql(u8, use.path, "Interop.MacOS") or
            std.mem.eql(u8, use.path, "Interop.Linux") or
            std.mem.eql(u8, use.path, "Interop.Windows"))
        {
            return .{
                .alias = use.alias orelse lastSegment(use.path),
                .path = use.path,
                .module = null,
                .declaration = null,
                .is_public = use.is_public,
                .position = use.position,
            };
        }
        if (use.type_target) |type_target| {
            return .{
                .alias = use.alias.?,
                .path = "",
                .module = self.genericAliasDependency(source_module, type_target),
                .declaration = null,
                .type_alias = type_target,
                .is_public = use.is_public,
                .position = use.position,
            };
        }
        const owner = self.index.providers[source_module].owner;
        if (try self.contextualModulePath(source_module, use.path)) |contextual_path| {
            if (self.bindingForUsePath(owner, use, contextual_path, true)) |binding| return binding;
        } else {
            if (self.bindingForUsePath(owner, use, use.path, false)) |binding| return binding;
        }

        if (use.alias != null) {
            if (findStructure(self.units[source_module].program.?, use.path) != null) return .{
                .alias = use.alias.?,
                .path = use.path,
                .module = source_module,
                .declaration = use.path,
                .is_public = use.is_public,
                .position = use.position,
            };
            return .{
                .alias = use.alias.?,
                .path = use.path,
                .module = null,
                .declaration = null,
                .type_name = use.path,
                .is_public = use.is_public,
                .position = use.position,
            };
        }

        const message = if (self.packages.unavailableForTarget(owner, use.path))
            try std.fmt.allocPrint(
                self.allocator,
                "module '{s}' is not available for {s}",
                .{ use.path, self.target.name() },
            )
        else
            try std.fmt.allocPrint(self.allocator, "unknown module or declaration '{s}'", .{use.path});
        return self.fail(use.position, message);
    }

    fn contextualModulePath(self: *Compiler, source_module: usize, path: []const u8) !?[]const u8 {
        const package_prefix = "Package.";
        const module_prefix = "Module.";
        const provider = self.index.providers[source_module];
        if (std.mem.startsWith(u8, path, package_prefix)) {
            const relative = path[package_prefix.len..];
            const package_name = self.packages.packages[provider.owner].name orelse return relative;
            const canonical: []const u8 = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ package_name, relative });
            return canonical;
        }
        if (std.mem.startsWith(u8, path, module_prefix)) {
            const relative = path[module_prefix.len..];
            if (provider.local_prefix.len == 0) return relative;
            const canonical: []const u8 = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ provider.local_prefix, relative });
            return canonical;
        }
        return null;
    }

    fn bindingForUsePath(
        self: *Compiler,
        owner: usize,
        use: Ast.Use,
        path: []const u8,
        owned_only: bool,
    ) ?Binding {
        const direct = if (owned_only)
            Lookup.findOwnedModule(self, path, owner)
        else
            Lookup.findAccessibleModule(self, path, owner);
        if (direct) |module| return .{
            .alias = use.alias orelse lastSegment(use.path),
            .path = path,
            .module = module,
            .declaration = if (use.is_public) lastSegment(path) else null,
            .is_public = use.is_public,
            .position = use.position,
        };

        const namespace = if (owned_only)
            Lookup.isOwnedNamespace(self, path, owner)
        else
            Lookup.isAccessibleNamespace(self, path, owner);
        if (namespace) return .{
            .alias = use.alias orelse lastSegment(use.path),
            .path = path,
            .module = null,
            .declaration = null,
            .is_public = use.is_public,
            .position = use.position,
        };

        var separator = std.mem.lastIndexOfScalar(u8, path, '.');
        while (separator) |at| {
            const prefix = path[0..at];
            const module = if (owned_only)
                Lookup.findOwnedModule(self, prefix, owner)
            else
                Lookup.findAccessibleModule(self, prefix, owner);
            if (module) |target| return .{
                .alias = use.alias orelse lastSegment(use.path),
                .path = prefix,
                .module = target,
                .declaration = path[at + 1 ..],
                .is_public = use.is_public,
                .position = use.position,
            };
            separator = std.mem.lastIndexOfScalar(u8, prefix, '.');
        }
        return null;
    }

    fn genericAliasDependency(self: *Compiler, source_module: usize, type_value: Ast.Type) ?usize {
        const direct = type_value.optionalChild() orelse type_value;
        const generic_index = direct.genericInstantiationIndex() orelse return null;
        const program = self.units[source_module].program orelse return null;
        if (generic_index >= program.generic_types.len) return null;
        const base_index = program.generic_types[generic_index].base.structureIndex() orelse return null;
        if (base_index >= program.type_names.len) return null;
        const target = self.longestModulePrefix(
            program.type_names[base_index],
            self.index.providers[source_module].owner,
        ) orelse return null;
        return if (target.module == source_module) null else target.module;
    }

    const DeclarationKind = Reexports.DeclarationKind;

    fn validateTypeAliases(self: *Compiler) Error!void {
        for (self.units, 0..) |unit, module| {
            if (unit.state != .loaded) continue;
            for (unit.bindings) |binding| {
                if (binding.type_alias == null and binding.type_name == null) continue;
                if (try self.resolveTypeAlias(module, binding.alias, binding.position, false) == null) {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "unknown type alias target '{s}'",
                        .{binding.path},
                    );
                    return self.fail(binding.position, message);
                }
            }
        }
    }

    fn validateReexports(self: *Compiler) Error!void {
        for (self.units, 0..) |unit, module| {
            if (unit.state != .loaded) continue;
            for (unit.bindings) |binding| {
                if (!binding.is_public) continue;
                if (binding.type_alias != null or binding.type_name != null) {
                    const target = try self.resolveTypeAlias(module, binding.alias, binding.position, false) orelse {
                        return self.fail(binding.position, "public type alias target is unknown");
                    };
                    try self.requirePublicAliasTarget(target, binding.position, binding.alias);
                    continue;
                }
                if (binding.module == null or binding.declaration == null) {
                    return self.fail(binding.position, "public use can only reexport a declaration");
                }
                const functions = try self.resolveReexport(
                    binding.module.?,
                    binding.declaration.?,
                    .function,
                    try self.allocator.alloc(bool, self.units.len),
                );
                const structures = try self.resolveReexport(
                    binding.module.?,
                    binding.declaration.?,
                    .structure,
                    try self.allocator.alloc(bool, self.units.len),
                );
                const enumerations = try self.resolveReexport(
                    binding.module.?,
                    binding.declaration.?,
                    .enumeration,
                    try self.allocator.alloc(bool, self.units.len),
                );
                const declaration_count = @as(u2, @intFromBool(functions != null)) +
                    @as(u2, @intFromBool(structures != null)) + @as(u2, @intFromBool(enumerations != null));
                if (declaration_count > 1) {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "public use destination '{s}' is ambiguous",
                        .{binding.alias},
                    );
                    return self.fail(binding.position, message);
                }
                if (declaration_count == 0) {
                    if (try self.resolveTypeAlias(
                        binding.module.?,
                        binding.declaration.?,
                        binding.position,
                        true,
                    )) |target| {
                        try self.requirePublicAliasTarget(target, binding.position, binding.alias);
                        continue;
                    }
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "public use cannot expose inaccessible declaration '{s}'",
                        .{binding.declaration.?},
                    );
                    return self.fail(binding.position, message);
                }
            }
        }
    }

    pub fn resolveTypeAlias(
        self: *Compiler,
        module: usize,
        name: []const u8,
        position: Source.Position,
        exported_only: bool,
    ) Error!?TypeAliases.Target {
        var capacity = self.units.len;
        for (self.units) |unit| capacity += unit.bindings.len;
        const visits = try self.allocator.alloc(TypeAliases.Visit, capacity + 1);
        const resolved = (if (exported_only)
            TypeAliases.resolveExported(self.units, module, name, visits)
        else
            TypeAliases.resolve(self.units, module, name, visits)) catch {
            const message = try std.fmt.allocPrint(self.allocator, "type alias cycle reaches '{s}'", .{name});
            return self.fail(position, message);
        };
        if (resolved != null or exported_only or std.mem.indexOfScalar(u8, name, '.') == null) return resolved;
        const target = try self.targetForCall(module, name) orelse return null;
        return TypeAliases.resolveExported(
            self.units,
            target.module,
            target.declaration,
            visits,
        ) catch {
            const message = try std.fmt.allocPrint(self.allocator, "type alias cycle reaches '{s}'", .{name});
            return self.fail(position, message);
        };
    }

    fn requirePublicAliasTarget(
        self: *Compiler,
        target: TypeAliases.Target,
        position: Source.Position,
        alias: []const u8,
    ) Error!void {
        const nominal_target = switch (target) {
            .fundamental => return,
            .structure => |structure| structure,
            .enumeration => |enumeration| enumeration,
        };
        const program = self.units[nominal_target.module].program.?;
        if (findStructure(program, nominal_target.declaration)) |structure| {
            if (Reexports.structureExported(program, structure)) return;
            const message = if (structure.is_local)
                try std.fmt.allocPrint(
                    self.allocator,
                    "public type alias '{s}' exposes local structure '{s}'",
                    .{ alias, structure.name },
                )
            else if (structure.is_internal)
                try std.fmt.allocPrint(
                    self.allocator,
                    "public type alias '{s}' exposes package structure '{s}'",
                    .{ alias, structure.name },
                )
            else if (structure.is_private)
                try std.fmt.allocPrint(
                    self.allocator,
                    "public type alias '{s}' exposes private structure '{s}'",
                    .{ alias, structure.name },
                )
            else
                try std.fmt.allocPrint(
                    self.allocator,
                    "public type alias '{s}' exposes module structure '{s}'",
                    .{ alias, structure.name },
                );
            return self.fail(position, message);
        }
        const enumeration = findEnum(program, nominal_target.declaration).?;
        if (enumeration.is_public) return;
        const message = if (enumeration.is_local)
            try std.fmt.allocPrint(
                self.allocator,
                "public type alias '{s}' exposes local enum '{s}'",
                .{ alias, enumeration.name },
            )
        else if (enumeration.is_internal)
            try std.fmt.allocPrint(
                self.allocator,
                "public type alias '{s}' exposes package enum '{s}'",
                .{ alias, enumeration.name },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "public type alias '{s}' exposes module enum '{s}'",
                .{ alias, enumeration.name },
            );
        return self.fail(position, message);
    }

    pub fn resolveReexport(
        self: *Compiler,
        module: usize,
        name: []const u8,
        kind: DeclarationKind,
        visiting: []bool,
    ) Error!?CallTarget {
        return Reexports.resolve(self.units, module, name, kind, visiting) catch {
            const message = try std.fmt.allocPrint(self.allocator, "public use cycle reaches '{s}'", .{name});
            return self.fail(expressionPosition(module), message);
        };
    }

    pub fn activateQualifiedReferences(self: *Compiler, module: usize) Error!void {
        return Activation.activate(self, module);
    }

    pub fn activateType(self: *Compiler, module: usize, type_value: Ast.Type) Error!void {
        return Activation.activateType(self, module, type_value);
    }

    pub fn activateStatement(self: *Compiler, module: usize, statement: Ast.Statement) Error!void {
        return Activation.activateStatement(self, module, statement);
    }

    pub fn activateExpression(self: *Compiler, module: usize, expression: *Ast.Expression) Error!void {
        return Activation.activateExpression(self, module, expression);
    }

    const CallTarget = Reexports.Target;

    pub fn targetForCall(self: *Compiler, module: usize, call_name: []const u8) Error!?CallTarget {
        const canonical_name = try self.contextualModulePath(module, call_name) orelse call_name;
        const separator = std.mem.indexOfScalar(u8, canonical_name, '.');
        if (separator == null) {
            for (self.units[module].bindings) |binding| {
                if (binding.declaration != null and std.mem.eql(u8, binding.alias, canonical_name)) {
                    return .{ .module = binding.module.?, .declaration = binding.declaration.? };
                }
            }
            return null;
        }

        const head = canonical_name[0..separator.?];
        const tail = canonical_name[separator.? + 1 ..];
        for (self.units[module].bindings) |binding| {
            if (!std.mem.eql(u8, binding.alias, head) or binding.declaration != null) continue;
            if (binding.module) |target_module| {
                if (!Fragments.hasPublicDeclaration(self.index, self.units, target_module, tail)) {
                    const canonical = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ binding.path, tail });
                    if (self.longestModulePrefix(canonical, self.index.providers[module].owner)) |target| {
                        if (target.module != target_module) return target;
                    }
                }
                return .{ .module = target_module, .declaration = tail };
            }
            const canonical = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ binding.path, tail });
            if (self.longestModulePrefix(canonical, self.index.providers[module].owner)) |target| return target;
            if (std.mem.startsWith(u8, binding.path, "Interop.")) return null;
            const message = try std.fmt.allocPrint(self.allocator, "unknown qualified path '{s}'", .{canonical});
            return self.fail(expressionPosition(module), message);
        }
        if (self.longestModulePrefix(canonical_name, self.index.providers[module].owner)) |target| return target;
        return null;
    }

    pub fn nominalCandidate(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        return try Resolution.structureCandidate(self, module, name) orelse try Resolution.enumCandidate(self, module, name);
    }

    fn requireContextualTarget(
        self: *Compiler,
        module: usize,
        path: []const u8,
        origin: Modules.Origin,
    ) Error!CallTarget {
        return Resolution.requireContextualTarget(self, module, path, origin);
    }

    fn structureTarget(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        return Resolution.structureTarget(self, module, name);
    }

    fn enumTarget(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        return Resolution.enumTarget(self, module, name);
    }

    fn enumReceiverTarget(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        return Resolution.enumReceiverTarget(self, module, name);
    }

    fn functionTarget(self: *Compiler, target: CallTarget) Error!?CallTarget {
        return Resolution.functionTarget(self, target);
    }

    fn resolveStructure(self: *Compiler, module: usize, name: []const u8, position: Source.Position) Error!CallTarget {
        return Resolution.resolveStructure(self, module, name, position);
    }

    fn requirePublicStructure(self: *Compiler, source_module: usize, target: CallTarget, position: Source.Position) Error!void {
        return Resolution.requirePublicStructure(self, source_module, target, position);
    }

    fn requirePublicEnum(self: *Compiler, source_module: usize, target: CallTarget, position: Source.Position) Error!void {
        return Resolution.requirePublicEnum(self, source_module, target, position);
    }

    fn longestModulePrefix(self: *Compiler, path: []const u8, owner: usize) ?CallTarget {
        return Lookup.longestAccessibleModulePrefix(self, path, owner);
    }

    const AstComposition = struct {
        program: Ast.Program,
        type_maps: []const []const Ast.Type,
    };

    fn collectionCanonicalName(self: *Compiler, module: usize, collection: Ast.Collection) Error![]const u8 {
        const element = try self.canonicalTypeSpelling(module, collection.element);
        return if (collection.view)
            std.fmt.allocPrint(self.allocator, "{s}[..]", .{element})
        else if (collection.length) |length|
            std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ element, length })
        else
            std.fmt.allocPrint(self.allocator, "{s}[]", .{element});
    }

    fn canonicalTypeSpelling(self: *Compiler, module: usize, type_value: Ast.Type) Error![]const u8 {
        if (type_value.optionalChild()) |child| return std.fmt.allocPrint(self.allocator, "{s}?", .{try self.canonicalTypeSpelling(module, child)});
        if (type_value.genericParameterIndex()) |index| return std.fmt.allocPrint(self.allocator, "T{d}", .{index});
        if (type_value.functionIndex()) |index| {
            const function_type = self.units[module].program.?.function_types[index];
            var spelling = try self.allocator.dupe(u8, "func(");
            for (function_type.parameters, 0..) |parameter, parameter_index| spelling = try std.fmt.allocPrint(
                self.allocator,
                "{s}{s}{s}{s}",
                .{ spelling, if (parameter_index == 0) "" else ",", FunctionTypes.modeSpelling(parameter.mode), try self.canonicalTypeSpelling(module, parameter.type) },
            );
            return std.fmt.allocPrint(
                self.allocator,
                "{s}){s}{s}",
                .{ spelling, FunctionTypes.modeSpelling(function_type.return_mode), try self.canonicalTypeSpelling(module, function_type.return_type) },
            );
        }
        if (type_value.genericInstantiationIndex()) |index| {
            const generic = self.units[module].program.?.generic_types[index];
            var name = try self.allocator.dupe(u8, try self.canonicalTypeSpelling(module, generic.base));
            for (generic.arguments, 0..) |argument, argument_index| name = try std.fmt.allocPrint(
                self.allocator,
                "{s}{s}{s}",
                .{ name, if (argument_index == 0) "<" else ",", try self.canonicalTypeSpelling(module, argument) },
            );
            return std.fmt.allocPrint(self.allocator, "{s}>", .{name});
        }
        const index = type_value.structureIndex() orelse return type_value.name();
        const program = self.units[module].program.?;
        if (index >= program.type_names.len) return type_value.name();
        const local_name = program.type_names[index];
        if (findStructure(program, local_name)) |structure| {
            if (structure.collection) |collection| return self.collectionCanonicalName(module, collection);
        }
        const target = try self.structureTarget(module, local_name) orelse try self.enumTarget(module, local_name) orelse return local_name;
        return structureCanonicalName(self.allocator, try self.nominalModule(target), target.declaration);
    }

    pub fn canonicalModule(self: *Compiler, module: usize) Error![]const u8 {
        return Fragments.canonicalModuleName(self.allocator, self.index.providers[module]);
    }

    fn functionModule(self: *Compiler, target: CallTarget) Error![]const u8 {
        return Resolution.functionModule(self, target);
    }

    fn structureModule(self: *Compiler, target: CallTarget) Error![]const u8 {
        return Resolution.structureModule(self, target);
    }

    pub fn enumModule(self: *Compiler, target: CallTarget) Error![]const u8 {
        return Resolution.enumModule(self, target);
    }

    fn nominalModule(self: *Compiler, target: CallTarget) Error![]const u8 {
        return Resolution.nominalModule(self, target);
    }

    fn composeAst(self: *Compiler) Error!AstComposition {
        var type_names: std.ArrayList([]const u8) = .empty;
        for (self.index.providers, 0..) |provider, module| {
            if (self.units[module].state != .loaded) continue;
            const provider_name = try self.canonicalModule(module);
            const program = self.units[module].program.?;
            for (program.structures) |structure| {
                if (structure.is_test and (!self.include_tests or module != self.entry_module)) continue;
                const declaration_module = if (Reexports.structureExported(program, structure)) provider.name else provider_name;
                const name = if (structure.collection) |collection|
                    try self.collectionCanonicalName(module, collection)
                else
                    try structureCanonicalName(self.allocator, declaration_module, structure.name);
                for (type_names.items) |existing| {
                    if (std.mem.eql(u8, existing, name)) {
                        if (structure.collection != null) break;
                        const message = try std.fmt.allocPrint(self.allocator, "structure identity '{s}' is already provided", .{name});
                        return self.fail(structure.name_position, message);
                    }
                } else try type_names.append(self.allocator, name);
            }
            for (program.enums) |enumeration| {
                const name = try structureCanonicalName(
                    self.allocator,
                    if (enumeration.is_public) provider.name else provider_name,
                    enumeration.name,
                );
                if (std.mem.eql(u8, name, Result.name) and findName(type_names.items, name) != null) continue;
                for (type_names.items) |existing| {
                    if (std.mem.eql(u8, existing, name)) {
                        const message = try std.fmt.allocPrint(self.allocator, "type identity '{s}' is already provided", .{name});
                        return self.fail(enumeration.name_position, message);
                    }
                }
                try type_names.append(self.allocator, name);
            }
        }

        const type_maps = try self.allocator.alloc([]const Ast.Type, self.units.len);
        @memset(type_maps, &.{});
        for (self.index.providers, 0..) |_, module| {
            if (self.units[module].state != .loaded) continue;
            const program = self.units[module].program.?;
            const map = try self.allocator.alloc(Ast.Type, program.type_names.len);
            for (program.type_names, 0..) |name, index| {
                if (index < program.test_only_type_names.len and program.test_only_type_names[index] and
                    (!self.include_tests or module != self.entry_module))
                {
                    map[index] = .void;
                    continue;
                }
                if (findStructure(program, name)) |structure| if (structure.collection) |collection| {
                    map[index] = .structure(findName(type_names.items, try self.collectionCanonicalName(module, collection)) orelse return error.InvalidSource);
                    continue;
                };
                if (try self.resolveTypeAlias(module, name, expressionPosition(module), false)) |alias_target| {
                    map[index] = switch (alias_target) {
                        .fundamental => |fundamental| fundamental,
                        .structure => |target| structure_type: {
                            try self.requirePublicStructure(module, target, expressionPosition(module));
                            const canonical = try structureCanonicalName(
                                self.allocator,
                                try self.structureModule(target),
                                target.declaration,
                            );
                            break :structure_type .structure(
                                findName(type_names.items, canonical) orelse return error.InvalidSource,
                            );
                        },
                        .enumeration => |target| enum_type: {
                            try self.requirePublicEnum(module, target, expressionPosition(module));
                            const canonical = try structureCanonicalName(
                                self.allocator,
                                try self.enumModule(target),
                                target.declaration,
                            );
                            break :enum_type .structure(
                                findName(type_names.items, canonical) orelse return error.InvalidSource,
                            );
                        },
                    };
                    continue;
                }
                const target = if (try self.enumTarget(module, name)) |enumeration| enum_target: {
                    try self.requirePublicEnum(module, enumeration, expressionPosition(module));
                    break :enum_target enumeration;
                } else if (self.genericAliasBaseTarget(module, index, name)) |generic_target| generic_target else try self.resolveStructure(module, name, expressionPosition(module));
                const canonical = try structureCanonicalName(
                    self.allocator,
                    try self.nominalModule(target),
                    target.declaration,
                );
                map[index] = .structure(findName(type_names.items, canonical) orelse return error.InvalidSource);
            }
            type_maps[module] = map;
            try self.validatePublicTypeExposure(module);
        }
        const generic_composition = try GenericTypes.compose(self.allocator, self.units, type_maps);
        self.generic_type_maps = generic_composition.maps;
        const function_composition = try FunctionTypes.compose(self.allocator, self.units, type_maps, self.generic_type_maps);
        self.function_type_maps = function_composition.maps;
        for (type_maps, 0..) |type_map, module| {
            for (@constCast(type_map)) |*type_value| {
                type_value.* = GenericTypes.remap(type_value.*, &.{}, self.generic_type_maps[module]);
            }
        }

        var structures: std.ArrayList(Ast.Structure) = .empty;
        var enums: std.ArrayList(Ast.Enum) = .empty;
        var functions: std.ArrayList(Ast.Function) = .empty;
        var external_functions: std.ArrayList(Ast.ExternalFunction) = .empty;
        var extensions: std.ArrayList(Ast.Extension) = .empty;
        for (self.index.providers, 0..) |provider, module| {
            if (self.units[module].state != .loaded) continue;
            const provider_name = try self.canonicalModule(module);
            const program = self.units[module].program.?;
            const type_map = type_maps[module];
            const generic_map = self.generic_type_maps[module];
            const function_map = self.function_type_maps[module];
            for (program.extensions) |extension| {
                try extensions.append(self.allocator, try ProjectExtensions.compose(self, module, provider, extension, type_map, generic_map));
            }
            for (program.structures) |structure| {
                if (structure.is_test and (!self.include_tests or module != self.entry_module)) continue;
                const declaration_module = if (Reexports.structureExported(program, structure)) provider.name else provider_name;
                const composed_name = if (structure.collection) |collection|
                    try self.collectionCanonicalName(module, collection)
                else
                    try structureCanonicalName(self.allocator, declaration_module, structure.name);
                if (structure.collection != null) {
                    var already_composed = false;
                    for (structures.items) |existing| if (std.mem.eql(u8, existing.name, composed_name)) {
                        already_composed = true;
                        break;
                    };
                    if (already_composed) continue;
                }
                var composed_structure = structure;
                composed_structure.owner = provider.owner;
                composed_structure.name = composed_name;
                composed_structure.type_parameters = try GenericTypes.remapParameters(self.allocator, structure.type_parameters, type_map, generic_map);
                if (structure.enclosing) |enclosing| {
                    const enclosing_structure = findStructure(program, enclosing);
                    const enclosing_module = if (enclosing_structure != null and Reexports.structureExported(program, enclosing_structure.?))
                        provider.name
                    else
                        provider_name;
                    composed_structure.enclosing = try structureCanonicalName(self.allocator, enclosing_module, enclosing);
                }
                if (structure.base) |base| composed_structure.base = FunctionTypes.remap(base, type_map, generic_map, function_map);
                const conformances = try self.allocator.alloc(Ast.Type, structure.conformances.len);
                for (structure.conformances, 0..) |conformance, index| {
                    conformances[index] = FunctionTypes.remap(conformance, type_map, generic_map, function_map);
                }
                composed_structure.conformances = conformances;
                if (structure.collection) |collection| composed_structure.collection = .{
                    .element = FunctionTypes.remap(collection.element, type_map, generic_map, function_map),
                    .length = collection.length,
                    .view = collection.view,
                };
                const fields = try self.allocator.alloc(Ast.StructureField, structure.fields.len);
                for (structure.fields, 0..) |field, index| {
                    fields[index] = field;
                    fields[index].type = FunctionTypes.remap(field.type, type_map, generic_map, function_map);
                    if (field.default) |value| try self.rewriteExpression(module, value, type_map);
                }
                composed_structure.fields = fields;
                const static_fields = try self.allocator.alloc(Ast.StructureField, structure.static_fields.len);
                for (structure.static_fields, 0..) |field, index| {
                    static_fields[index] = field;
                    static_fields[index].type = FunctionTypes.remap(field.type, type_map, generic_map, function_map);
                    if (field.default) |value| try self.rewriteExpression(module, value, type_map);
                }
                composed_structure.static_fields = static_fields;
                const constructors = try self.allocator.alloc(Ast.Constructor, structure.constructors.len);
                for (structure.constructors, 0..) |constructor, constructor_index| {
                    constructors[constructor_index] = constructor;
                    const parameters = try self.allocator.alloc(Ast.Parameter, constructor.parameters.len);
                    for (constructor.parameters, 0..) |parameter, parameter_index| {
                        parameters[parameter_index] = parameter;
                        parameters[parameter_index].type = FunctionTypes.remap(parameter.type, type_map, generic_map, function_map);
                        if (parameter.default) |value| try self.rewriteExpression(module, value, type_map);
                    }
                    constructors[constructor_index].parameters = parameters;
                    for (constructor.super_arguments) |argument| try self.rewriteExpression(module, argument, type_map);
                    constructors[constructor_index].statements = try self.rewriteStatements(module, constructor.statements, type_map);
                }
                composed_structure.constructors = constructors;
                const methods = try self.allocator.alloc(Ast.Function, structure.methods.len);
                for (structure.methods, 0..) |method, method_index| {
                    methods[method_index] = method;
                    methods[method_index].owner = provider.owner;
                    methods[method_index].type_parameters = try GenericTypes.remapParameters(self.allocator, method.type_parameters, type_map, generic_map);
                    const parameters = try self.allocator.alloc(Ast.Parameter, method.parameters.len);
                    for (method.parameters, 0..) |parameter, parameter_index| {
                        parameters[parameter_index] = parameter;
                        parameters[parameter_index].type = FunctionTypes.remap(parameter.type, type_map, generic_map, function_map);
                        if (parameter.default) |value| try self.rewriteExpression(module, value, type_map);
                    }
                    methods[method_index].parameters = parameters;
                    methods[method_index].return_type = FunctionTypes.remap(method.return_type, type_map, generic_map, function_map);
                    methods[method_index].statements = try self.rewriteStatements(module, method.statements, type_map);
                }
                composed_structure.methods = methods;
                if (composed_structure.drop) |*drop| drop.statements = try self.rewriteStatements(module, drop.statements, type_map);
                try structures.append(self.allocator, composed_structure);
            }
            for (program.enums) |enumeration| {
                var composed = enumeration;
                composed.owner = provider.owner;
                composed.name = try structureCanonicalName(
                    self.allocator,
                    if (enumeration.is_public) provider.name else provider_name,
                    enumeration.name,
                );
                composed.type_parameters = try GenericTypes.remapParameters(self.allocator, enumeration.type_parameters, type_map, generic_map);
                const variants = try self.allocator.alloc(Ast.EnumVariant, enumeration.variants.len);
                for (enumeration.variants, 0..) |variant, variant_index| {
                    variants[variant_index] = variant;
                    const associated_types = try self.allocator.alloc(Ast.Type, variant.associated_types.len);
                    for (variant.associated_types, 0..) |associated_type, type_index| {
                        associated_types[type_index] = FunctionTypes.remap(associated_type, type_map, generic_map, function_map);
                    }
                    variants[variant_index].associated_types = associated_types;
                }
                composed.variants = variants;
                try enums.append(self.allocator, composed);
            }
            for (program.functions) |function| {
                if (function.is_test and (!self.include_tests or module != self.entry_module)) continue;
                if (module != self.entry_module and std.mem.eql(u8, function.name, "main")) continue;
                var composed = function;
                composed.owner = provider.owner;
                composed.type_parameters = try GenericTypes.remapParameters(self.allocator, function.type_parameters, type_map, generic_map);
                composed.name = if (std.mem.eql(u8, function.name, "main"))
                    "main"
                else
                    try canonicalName(
                        self.allocator,
                        if (function.is_public) provider.name else provider_name,
                        function.name,
                    );
                const parameters = try self.allocator.alloc(Ast.Parameter, function.parameters.len);
                for (function.parameters, 0..) |parameter, index| {
                    parameters[index] = parameter;
                    parameters[index].type = FunctionTypes.remap(parameter.type, type_map, generic_map, function_map);
                    if (parameter.default) |value| try self.rewriteExpression(module, value, type_map);
                }
                composed.parameters = parameters;
                composed.return_type = FunctionTypes.remap(function.return_type, type_map, generic_map, function_map);
                composed.statements = try self.rewriteStatements(module, function.statements, type_map);
                try functions.append(self.allocator, composed);
            }
            for (program.external_functions) |external| {
                var composed = external;
                composed.owner = provider.owner;
                composed.name = try canonicalName(self.allocator, provider_name, external.name);
                try external_functions.append(self.allocator, composed);
            }
        }
        return .{ .program = .{
            .type_names = try type_names.toOwnedSlice(self.allocator),
            .generic_types = generic_composition.types,
            .function_types = function_composition.types,
            .structures = try structures.toOwnedSlice(self.allocator),
            .enums = try enums.toOwnedSlice(self.allocator),
            .extensions = try extensions.toOwnedSlice(self.allocator),
            .external_functions = try external_functions.toOwnedSlice(self.allocator),
            .functions = try functions.toOwnedSlice(self.allocator),
        }, .type_maps = type_maps };
    }

    fn buildInterfaces(self: *Compiler, type_maps: []const []const Ast.Type) Error![]const Interface.Module {
        var interfaces: std.ArrayList(Interface.Module) = .empty;
        const interface_by_module = try self.allocator.alloc(?usize, self.units.len);
        @memset(interface_by_module, null);
        for (self.index.providers, 0..) |provider, module| {
            if (self.units[module].state != .loaded) continue;
            const owner: Interface.Owner = if (self.packages.packages[provider.owner].name) |name|
                .{ .package = name }
            else
                .project;
            const fragment_interface = try Interface.buildMappedGenerics(
                self.allocator,
                owner,
                provider.name,
                self.units[module].program.?,
                type_maps[module],
                self.generic_type_maps[module],
            );
            var destination: ?usize = null;
            for (0..module) |candidate| {
                if (!Fragments.same(self.index, module, candidate)) continue;
                if (interface_by_module[candidate]) |existing| {
                    destination = existing;
                    break;
                }
            }
            if (destination) |existing| {
                interface_by_module[module] = existing;
                interfaces.items[existing].structures = try Fragments.concatenate(
                    self.allocator,
                    Interface.Structure,
                    interfaces.items[existing].structures,
                    fragment_interface.structures,
                );
                interfaces.items[existing].enums = try Fragments.concatenate(
                    self.allocator,
                    Interface.Enum,
                    interfaces.items[existing].enums,
                    fragment_interface.enums,
                );
                interfaces.items[existing].functions = try Fragments.concatenate(
                    self.allocator,
                    Interface.Function,
                    interfaces.items[existing].functions,
                    fragment_interface.functions,
                );
                interfaces.items[existing].type_aliases = try Fragments.concatenate(
                    self.allocator,
                    Interface.TypeAlias,
                    interfaces.items[existing].type_aliases,
                    fragment_interface.type_aliases,
                );
            } else {
                interface_by_module[module] = interfaces.items.len;
                try interfaces.append(self.allocator, fragment_interface);
            }
        }
        for (self.units, 0..) |unit, module| {
            const destination_index = interface_by_module[module] orelse continue;
            for (unit.bindings) |binding| {
                if (!binding.is_public) continue;
                const alias_target = if (binding.type_alias != null or binding.type_name != null)
                    try self.resolveTypeAlias(module, binding.alias, binding.position, false)
                else if (binding.module != null and binding.declaration != null)
                    try self.resolveTypeAlias(binding.module.?, binding.declaration.?, binding.position, true)
                else
                    null;
                if (alias_target) |target| switch (target) {
                    .fundamental => |fundamental| {
                        const previous = interfaces.items[destination_index].type_aliases;
                        const expanded = try self.allocator.alloc(Interface.TypeAlias, previous.len + 1);
                        @memcpy(expanded[0..previous.len], previous);
                        expanded[previous.len] = .{
                            .name = binding.alias,
                            .target = GenericTypes.remap(fundamental, type_maps[module], self.generic_type_maps[module]),
                        };
                        interfaces.items[destination_index].type_aliases = expanded;
                        continue;
                    },
                    .structure => |structure_target| {
                        const source = interfaces.items[interface_by_module[structure_target.module].?];
                        for (source.structures) |structure| {
                            if (!std.mem.eql(u8, structure.id.name, structure_target.declaration)) continue;
                            const previous = interfaces.items[destination_index].structures;
                            const expanded = try self.allocator.alloc(Interface.Structure, previous.len + 1);
                            @memcpy(expanded[0..previous.len], previous);
                            expanded[previous.len] = structure;
                            expanded[previous.len].export_name = binding.alias;
                            interfaces.items[destination_index].structures = expanded;
                        }
                        continue;
                    },
                    .enumeration => |enum_target| {
                        const source = interfaces.items[interface_by_module[enum_target.module].?];
                        for (source.enums) |enumeration| {
                            if (!std.mem.eql(u8, enumeration.id.name, enum_target.declaration)) continue;
                            const previous = interfaces.items[destination_index].enums;
                            const expanded = try self.allocator.alloc(Interface.Enum, previous.len + 1);
                            @memcpy(expanded[0..previous.len], previous);
                            expanded[previous.len] = enumeration;
                            expanded[previous.len].export_name = binding.alias;
                            interfaces.items[destination_index].enums = expanded;
                        }
                        continue;
                    },
                };
                const function_target = try self.resolveReexport(
                    binding.module.?,
                    binding.declaration.?,
                    .function,
                    try self.allocator.alloc(bool, self.units.len),
                );
                if (function_target) |target| {
                    const source = interfaces.items[interface_by_module[target.module].?];
                    for (source.functions) |function| {
                        if (!std.mem.eql(u8, function.id.name, target.declaration)) continue;
                        const previous = interfaces.items[destination_index].functions;
                        const expanded = try self.allocator.alloc(Interface.Function, previous.len + 1);
                        @memcpy(expanded[0..previous.len], previous);
                        expanded[previous.len] = function;
                        expanded[previous.len].export_name = binding.alias;
                        interfaces.items[destination_index].functions = expanded;
                    }
                }
                const structure_target = try self.resolveReexport(
                    binding.module.?,
                    binding.declaration.?,
                    .structure,
                    try self.allocator.alloc(bool, self.units.len),
                );
                if (structure_target) |target| {
                    const source = interfaces.items[interface_by_module[target.module].?];
                    for (source.structures) |structure| {
                        if (!std.mem.eql(u8, structure.id.name, target.declaration)) continue;
                        const previous = interfaces.items[destination_index].structures;
                        const expanded = try self.allocator.alloc(Interface.Structure, previous.len + 1);
                        @memcpy(expanded[0..previous.len], previous);
                        expanded[previous.len] = structure;
                        expanded[previous.len].export_name = binding.alias;
                        interfaces.items[destination_index].structures = expanded;
                    }
                }
                const enum_target = try self.resolveReexport(
                    binding.module.?,
                    binding.declaration.?,
                    .enumeration,
                    try self.allocator.alloc(bool, self.units.len),
                );
                if (enum_target) |target| {
                    const source = interfaces.items[interface_by_module[target.module].?];
                    for (source.enums) |enumeration| {
                        if (!std.mem.eql(u8, enumeration.id.name, target.declaration)) continue;
                        const previous = interfaces.items[destination_index].enums;
                        const expanded = try self.allocator.alloc(Interface.Enum, previous.len + 1);
                        @memcpy(expanded[0..previous.len], previous);
                        expanded[previous.len] = enumeration;
                        expanded[previous.len].export_name = binding.alias;
                        interfaces.items[destination_index].enums = expanded;
                    }
                }
            }
        }
        return interfaces.toOwnedSlice(self.allocator);
    }

    fn genericAliasBaseTarget(self: *Compiler, module: usize, type_index: usize, name: []const u8) ?CallTarget {
        const program = self.units[module].program orelse return null;
        var referenced = false;
        for (program.generic_types) |generic| {
            if (generic.base.structureIndex() == type_index) {
                referenced = true;
                break;
            }
        }
        if (!referenced) return null;
        const target = self.longestModulePrefix(name, self.index.providers[module].owner) orelse return null;
        if (self.units[target.module].state != .loaded) return null;
        const target_program = self.units[target.module].program.?;
        if (findStructure(target_program, target.declaration) != null) {
            self.requirePublicStructure(module, target, expressionPosition(module)) catch return null;
        } else if (findEnum(target_program, target.declaration) != null) {
            self.requirePublicEnum(module, target, expressionPosition(module)) catch return null;
        } else return null;
        return target;
    }

    fn validatePublicTypeExposure(self: *Compiler, module: usize) Error!void {
        const program = self.units[module].program.?;
        for (program.structures) |structure| {
            if (structure.is_test and (!self.include_tests or module != self.entry_module)) continue;
            if (!structure.is_public) continue;
            for (structure.type_parameters) |parameter| if (parameter.constraint) |constraint| {
                try self.requirePublicType(module, constraint, parameter.position, "public structure", structure.name);
            };
            if (structure.base) |base| try self.requirePublicType(module, base, structure.base_position, "public class", structure.name);
            for (structure.fields) |field| {
                if (memberGeographicScope(field, structure) != .public) continue;
                try self.requirePublicType(module, field.type, field.name_position, "public structure", structure.name);
            }
            for (structure.static_fields) |field| {
                if (memberGeographicScope(field, structure) != .public) continue;
                try self.requirePublicType(module, field.type, field.name_position, "public structure", structure.name);
            }
            for (structure.constructors) |constructor| {
                if (memberGeographicScope(constructor, structure) != .public) continue;
                for (constructor.parameters) |parameter| {
                    try self.requirePublicType(module, parameter.type, parameter.position, "constructor of", structure.name);
                }
            }
            for (structure.methods) |method| {
                if (memberGeographicScope(method, structure) != .public) continue;
                for (method.type_parameters) |parameter| if (parameter.constraint) |constraint| {
                    try self.requirePublicType(module, constraint, parameter.position, "method of", structure.name);
                };
                for (method.parameters) |parameter| {
                    try self.requirePublicType(module, parameter.type, parameter.position, "method of", structure.name);
                }
                try self.requirePublicOutputType(module, method.return_type, method.name_position, "method of", structure.name);
            }
        }
        for (program.functions) |function| {
            if (!function.is_public) continue;
            for (function.type_parameters) |parameter| if (parameter.constraint) |constraint| {
                try self.requirePublicType(module, constraint, parameter.position, "public function", function.name);
            };
            for (function.parameters) |parameter| {
                try self.requirePublicType(module, parameter.type, parameter.position, "public function", function.name);
            }
            try self.requirePublicOutputType(module, function.return_type, function.name_position, "public function", function.name);
        }
        for (program.structures) |structure| {
            const structure_scope = geographicScope(structure);
            if (structure_scope == .package or structure_scope == .module) {
                if (structure.base) |base| try self.requireTypeScope(module, base, structure.base_position, structure_scope, "type", structure.name);
                for (structure.conformances) |conformance| try self.requireTypeScope(module, conformance, structure.name_position, structure_scope, "type", structure.name);
            }
            for (structure.fields) |field| try self.validateMemberTypeScope(module, structure, field, field.type, field.name_position, structure.name, field.name);
            for (structure.static_fields) |field| try self.validateMemberTypeScope(module, structure, field, field.type, field.name_position, structure.name, field.name);
            for (structure.constructors) |constructor| {
                const scope = memberGeographicScope(constructor, structure);
                if (scope != .package and scope != .module) continue;
                for (constructor.parameters) |parameter| try self.requireTypeScope(module, parameter.type, parameter.position, scope, "constructor of", structure.name);
            }
            for (structure.methods) |method| {
                const scope = memberGeographicScope(method, structure);
                if (scope != .package and scope != .module) continue;
                for (method.parameters) |parameter| try self.requireTypeScope(module, parameter.type, parameter.position, scope, "method of", structure.name);
                try self.requireTypeScope(module, method.return_type, method.name_position, scope, "method of", structure.name);
            }
        }
        for (program.enums) |enumeration| {
            const scope = geographicScope(enumeration);
            for (enumeration.variants) |variant| for (variant.associated_types) |associated| {
                try self.requireTypeScope(module, associated, variant.position, scope, "enum", enumeration.name);
            };
        }
        for (program.functions) |function| {
            const scope = geographicScope(function);
            if (scope != .package and scope != .module) continue;
            for (function.parameters) |parameter| try self.requireTypeScope(module, parameter.type, parameter.position, scope, "function", function.name);
            try self.requireTypeScope(module, function.return_type, function.name_position, scope, "function", function.name);
        }
    }

    fn validateMemberTypeScope(
        self: *Compiler,
        module: usize,
        container: Ast.Structure,
        member: anytype,
        type_value: Ast.Type,
        position: Source.Position,
        owner: []const u8,
        name: []const u8,
    ) Error!void {
        const scope = memberGeographicScope(member, container);
        if (scope != .package and scope != .module) return;
        const label = try std.fmt.allocPrint(self.allocator, "member {s}.{s}", .{ owner, name });
        try self.requireTypeScope(module, type_value, position, scope, label, name);
    }

    fn requireTypeScope(
        self: *Compiler,
        module: usize,
        type_value: Ast.Type,
        position: Source.Position,
        required: GeographicScope,
        declaration_kind: []const u8,
        declaration_name: []const u8,
    ) Error!void {
        if (required == .public) return self.requirePublicType(module, type_value, position, declaration_kind, declaration_name);
        if (required == .local) return;
        if (type_value.optionalChild()) |child| return self.requireTypeScope(module, child, position, required, declaration_kind, declaration_name);
        if (type_value.functionIndex()) |function_index| {
            const program = self.units[module].program.?;
            if (function_index >= program.function_types.len) return;
            const function_type = program.function_types[function_index];
            for (function_type.parameters) |parameter| try self.requireTypeScope(module, parameter.type, position, required, declaration_kind, declaration_name);
            return self.requireTypeScope(module, function_type.return_type, position, required, declaration_kind, declaration_name);
        }
        if (type_value.genericInstantiationIndex()) |generic_index| {
            const program = self.units[module].program.?;
            if (generic_index >= program.generic_types.len) return;
            const generic = program.generic_types[generic_index];
            try self.requireTypeScope(module, generic.base, position, required, declaration_kind, declaration_name);
            for (generic.arguments) |argument| try self.requireTypeScope(module, argument, position, required, declaration_kind, declaration_name);
            return;
        }
        const index = type_value.structureIndex() orelse return;
        const program = self.units[module].program.?;
        if (index >= program.type_names.len) return;
        const target = try self.structureTarget(module, program.type_names[index]) orelse try self.enumTarget(module, program.type_names[index]) orelse return;
        const target_program = self.units[target.module].program.?;
        const target_scope: GeographicScope = if (findStructure(target_program, target.declaration)) |structure| scope: {
            if (structure.is_tuple) {
                for (structure.fields) |field| try self.requireTypeScope(target.module, field.type, position, required, declaration_kind, declaration_name);
                return;
            }
            if (structure.collection) |collection| return self.requireTypeScope(module, collection.element, position, required, declaration_kind, declaration_name);
            if (Reexports.structureExported(target_program, structure)) break :scope .public;
            break :scope geographicScope(structure);
        } else geographicScope(findEnum(target_program, target.declaration).?);
        if (@intFromEnum(target_scope) >= @intFromEnum(required)) return;
        const message = try std.fmt.allocPrint(
            self.allocator,
            "{s} '{s}' with {s} visibility exposes {s} type '{s}'",
            .{ declaration_kind, declaration_name, @tagName(required), @tagName(target_scope), target.declaration },
        );
        return self.fail(position, message);
    }

    fn requirePublicOutputType(
        self: *Compiler,
        module: usize,
        type_value: Ast.Type,
        position: Source.Position,
        declaration_kind: []const u8,
        declaration_name: []const u8,
    ) Error!void {
        if (type_value.optionalChild()) |child| return self.requirePublicOutputType(module, child, position, declaration_kind, declaration_name);
        if (type_value.genericInstantiationIndex() != null) return self.requirePublicType(module, type_value, position, declaration_kind, declaration_name);
        const index = type_value.structureIndex() orelse return;
        const program = self.units[module].program.?;
        if (index >= program.type_names.len) return;
        const name = program.type_names[index];
        const target = try self.structureTarget(module, name) orelse try self.enumTarget(module, name) orelse return;
        const target_program = self.units[target.module].program.?;
        if (findStructure(target_program, target.declaration)) |structure| {
            if (structure.is_local or structure.is_internal) return;
        } else {
            const enumeration = findEnum(target_program, target.declaration).?;
            if (enumeration.is_local or enumeration.is_internal) return;
        }
        return self.requirePublicType(module, type_value, position, declaration_kind, declaration_name);
    }

    pub fn requirePublicType(
        self: *Compiler,
        module: usize,
        type_value: Ast.Type,
        position: Source.Position,
        declaration_kind: []const u8,
        declaration_name: []const u8,
    ) Error!void {
        if (type_value.optionalChild()) |child| return self.requirePublicType(module, child, position, declaration_kind, declaration_name);
        if (type_value.functionIndex()) |function_index| {
            const program = self.units[module].program.?;
            if (function_index >= program.function_types.len) return;
            const function_type = program.function_types[function_index];
            for (function_type.parameters) |parameter| try self.requirePublicType(module, parameter.type, position, declaration_kind, declaration_name);
            return self.requirePublicType(module, function_type.return_type, position, declaration_kind, declaration_name);
        }
        if (type_value.genericInstantiationIndex()) |generic_index| {
            const program = self.units[module].program.?;
            if (generic_index >= program.generic_types.len) return;
            const generic = program.generic_types[generic_index];
            try self.requirePublicType(module, generic.base, position, declaration_kind, declaration_name);
            for (generic.arguments) |argument| try self.requirePublicType(module, argument, position, declaration_kind, declaration_name);
            return;
        }
        const index = type_value.structureIndex() orelse return;
        const program = self.units[module].program.?;
        if (index >= program.type_names.len) return;
        const name = program.type_names[index];
        const target = try self.structureTarget(module, name) orelse try self.enumTarget(module, name) orelse return;
        const target_program = self.units[target.module].program.?;
        if (findStructure(target_program, target.declaration)) |structure| {
            if (structure.is_tuple) {
                for (structure.fields) |field| {
                    try self.requirePublicType(target.module, field.type, position, declaration_kind, declaration_name);
                }
                return;
            }
            if (structure.collection) |collection| {
                return self.requirePublicType(module, collection.element, position, declaration_kind, declaration_name);
            }
            if (Reexports.structureExported(target_program, structure)) return;
            const message = if (structure.is_local)
                try std.fmt.allocPrint(
                    self.allocator,
                    "{s} '{s}' exposes local structure '{s}'",
                    .{ declaration_kind, declaration_name, structure.name },
                )
            else if (structure.is_internal)
                try std.fmt.allocPrint(
                    self.allocator,
                    "{s} '{s}' exposes package structure '{s}'",
                    .{ declaration_kind, declaration_name, structure.name },
                )
            else if (structure.is_private)
                try std.fmt.allocPrint(
                    self.allocator,
                    "{s} '{s}' exposes private structure '{s}'",
                    .{ declaration_kind, declaration_name, structure.name },
                )
            else
                try std.fmt.allocPrint(
                    self.allocator,
                    "{s} '{s}' exposes module structure '{s}'",
                    .{ declaration_kind, declaration_name, structure.name },
                );
            return self.fail(position, message);
        }
        const enumeration = findEnum(target_program, target.declaration).?;
        if (enumeration.is_public) return;
        const message = if (enumeration.is_local)
            try std.fmt.allocPrint(
                self.allocator,
                "{s} '{s}' exposes local enum '{s}'",
                .{ declaration_kind, declaration_name, enumeration.name },
            )
        else if (enumeration.is_internal)
            try std.fmt.allocPrint(
                self.allocator,
                "{s} '{s}' exposes package enum '{s}'",
                .{ declaration_kind, declaration_name, enumeration.name },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "{s} '{s}' exposes module enum '{s}'",
                .{ declaration_kind, declaration_name, enumeration.name },
            );
        return self.fail(position, message);
    }

    pub fn rewriteStatements(self: *Compiler, module: usize, statements: []const Ast.Statement, type_map: []const Ast.Type) Error![]const Ast.Statement {
        return Rewriting.statements(self, module, statements, type_map);
    }

    pub fn remapType(self: *Compiler, module: usize, type_map: []const Ast.Type, type_value: Ast.Type) Ast.Type {
        return FunctionTypes.remap(type_value, type_map, self.generic_type_maps[module], self.function_type_maps[module]);
    }

    fn qualifyFunctionReference(self: *Compiler, module: usize, name: *[]const u8) Error!void {
        if (Lookup.findLocalFunction(self.units[module].program.?, name.*)) {
            const local_target: CallTarget = .{ .module = module, .declaration = name.* };
            name.* = try canonicalName(self.allocator, try self.functionModule(local_target), name.*);
        } else if (try self.targetForCall(module, name.*)) |candidate| {
            if (try self.functionTarget(candidate)) |target| name.* = try canonicalName(
                self.allocator,
                try self.functionModule(target),
                target.declaration,
            );
        }
    }

    pub fn rewriteExpression(self: *Compiler, module: usize, expression: *Ast.Expression, type_map: []const Ast.Type) Error!void {
        switch (expression.value) {
            .call => |*call| {
                call.owner = self.index.providers[module].owner;
                call.module = self.index.providers[module].name;
                call.entry_module = module == self.entry_module;
                const type_arguments = try self.allocator.alloc(Ast.Type, call.type_arguments.len);
                for (call.type_arguments, 0..) |type_argument, index| {
                    type_arguments[index] = self.remapType(module, type_map, type_argument);
                }
                call.type_arguments = type_arguments;
                if (call.result_type) |result_type| call.result_type = self.remapType(module, type_map, result_type);
                for (call.arguments) |argument| try self.rewriteExpression(module, argument, type_map);
                for (call.named_arguments) |argument| try self.rewriteExpression(module, argument.value, type_map);
                if (call.receiver == null and std.mem.eql(u8, call.name, "C.function_address") and call.arguments.len == 1 and
                    call.arguments[0].value == .identifier)
                {
                    try self.qualifyFunctionReference(module, &call.arguments[0].value.identifier);
                }
                if (call.receiver != null and
                    (std.mem.eql(u8, call.name, "add_system") or std.mem.eql(u8, call.name, "add_after_system")) and
                    call.arguments.len == 2 and call.arguments[1].value == .identifier)
                {
                    try self.qualifyFunctionReference(module, &call.arguments[1].value.identifier);
                }
                if (call.receiver) |receiver| {
                    if (receiver.value == .generic_reference) {
                        const reference = &receiver.value.generic_reference;
                        const enumeration = try self.enumReceiverTarget(module, reference.name);
                        const structure = if (enumeration == null) try self.structureTarget(module, reference.name) else null;
                        const target = enumeration orelse structure orelse {
                            const message = try std.fmt.allocPrint(self.allocator, "unknown generic type '{s}'", .{reference.name});
                            return self.fail(receiver.position, message);
                        };
                        if (enumeration != null)
                            try self.requirePublicEnum(module, target, call.name_position)
                        else
                            try self.requirePublicStructure(module, target, call.name_position);
                        reference.name = try structureCanonicalName(self.allocator, try self.nominalModule(target), target.declaration);
                        for (@constCast(reference.type_arguments)) |*argument| {
                            argument.* = self.remapType(module, type_map, argument.*);
                        }
                    } else if (try expressionName(self.allocator, receiver)) |prefix| {
                        const qualified = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, call.name });
                        const contextual_origin = Fragments.contextualOrigin(qualified);
                        const direct_contextual = if (contextual_origin) |origin|
                            std.mem.eql(u8, prefix, Fragments.label(origin)) and
                                !Fragments.hasBindingAlias(self.units, module, prefix) and
                                findStructure(self.units[module].program.?, prefix) == null and
                                findEnum(self.units[module].program.?, prefix) == null
                        else
                            false;
                        if (direct_contextual) {
                            const origin = contextual_origin.?;
                            const target = try self.requireContextualTarget(module, qualified, origin);
                            const program = self.units[target.module].program.?;
                            var found_function = false;
                            for (program.functions) |function| {
                                if (std.mem.eql(u8, function.name, target.declaration)) {
                                    found_function = true;
                                    break;
                                }
                            }
                            if (found_function) {
                                call.name = try canonicalName(
                                    self.allocator,
                                    try self.functionModule(target),
                                    target.declaration,
                                );
                                call.receiver = null;
                            } else if (findStructure(program, target.declaration) != null or
                                findEnum(program, target.declaration) != null)
                            {
                                call.name = try structureCanonicalName(
                                    self.allocator,
                                    try self.nominalModule(target),
                                    target.declaration,
                                );
                                call.receiver = null;
                            } else {
                                const message = try std.fmt.allocPrint(
                                    self.allocator,
                                    "{s} fragment of '{s}' has no declaration '{s}'",
                                    .{ Fragments.label(origin), self.index.providers[module].name, target.declaration },
                                );
                                return self.fail(call.name_position, message);
                            }
                        } else if (try self.enumReceiverTarget(module, prefix)) |target| {
                            try self.requirePublicEnum(module, target, call.name_position);
                            receiver.value = .{ .identifier = try structureCanonicalName(
                                self.allocator,
                                try self.enumModule(target),
                                target.declaration,
                            ) };
                        } else {
                            const qualified_function = if (try self.targetForCall(module, qualified)) |candidate|
                                try self.functionTarget(candidate)
                            else
                                null;
                            if (qualified_function != null) {
                                call.name = qualified;
                                call.receiver = null;
                            } else if (try self.structureTarget(module, qualified)) |target| {
                                try self.requirePublicStructure(module, target, call.name_position);
                                call.name = try structureCanonicalName(
                                    self.allocator,
                                    try self.structureModule(target),
                                    target.declaration,
                                );
                                call.receiver = null;
                            } else if (try self.structureTarget(module, prefix)) |target| {
                                try self.requirePublicStructure(module, target, call.name_position);
                                receiver.value = .{ .identifier = try structureCanonicalName(
                                    self.allocator,
                                    try self.structureModule(target),
                                    target.declaration,
                                ) };
                            } else if (try self.targetForCall(module, qualified) != null) {
                                call.name = qualified;
                                call.receiver = null;
                            } else if (prefix.len != 0 and std.ascii.isUpper(prefix[0])) {
                                call.name = qualified;
                                call.receiver = null;
                            } else try self.rewriteExpression(module, receiver, type_map);
                        }
                    } else try self.rewriteExpression(module, receiver, type_map);
                }
                if (call.receiver == null and
                    (std.mem.eql(u8, call.name, "embed_text") or std.mem.eql(u8, call.name, "embed_bytes"))) return;
                if (call.receiver == null and std.mem.eql(u8, call.name, "reflect")) return;
                if (call.receiver == null and std.mem.eql(u8, call.name, "map_error")) {
                    if (call.arguments.len == 2 and call.arguments[1].value == .identifier) {
                        try self.qualifyFunctionReference(module, &call.arguments[1].value.identifier);
                    }
                    return;
                }
                if (try self.structureTarget(module, call.name)) |target| {
                    try self.requirePublicStructure(module, target, call.name_position);
                    call.name = try structureCanonicalName(
                        self.allocator,
                        try self.structureModule(target),
                        target.declaration,
                    );
                } else if (try self.targetForCall(module, call.name)) |candidate| {
                    if (try self.functionTarget(candidate)) |target| {
                        call.name = try canonicalName(
                            self.allocator,
                            try self.functionModule(target),
                            target.declaration,
                        );
                    }
                } else if (call.receiver == null and std.mem.indexOfScalar(u8, call.name, '.') == null) {
                    if (!Lookup.findLocalFunction(self.units[module].program.?, call.name)) {
                        if (Fragments.otherFunctionTarget(self.index, self.units, module, call.name)) |target| {
                            const origin = self.index.providers[target.module].origin;
                            const message = try std.fmt.allocPrint(
                                self.allocator,
                                "function '{s}' from the {s} fragment must be accessed as '{s}.{s}'",
                                .{ call.name, Fragments.label(origin), Fragments.label(origin), call.name },
                            );
                            return self.fail(call.name_position, message);
                        }
                    }
                    if (findStructure(self.units[module].program.?, call.name) != null) {
                        const local_target: CallTarget = .{ .module = module, .declaration = call.name };
                        call.name = try structureCanonicalName(
                            self.allocator,
                            try self.structureModule(local_target),
                            call.name,
                        );
                    } else {
                        const function_module = if (Lookup.findLocalFunction(self.units[module].program.?, call.name)) local: {
                            const local_target: CallTarget = .{ .module = module, .declaration = call.name };
                            break :local try self.functionModule(local_target);
                        } else try self.canonicalModule(module);
                        call.name = try canonicalName(self.allocator, function_module, call.name);
                    }
                }
            },
            .cascade => |cascade| {
                try self.rewriteExpression(module, cascade.receiver, type_map);
                for (@constCast(cascade.operations)) |*operation| switch (operation.*) {
                    .method_call => |*method| {
                        const type_arguments = try self.allocator.alloc(Ast.Type, method.type_arguments.len);
                        for (method.type_arguments, 0..) |type_argument, index| {
                            type_arguments[index] = self.remapType(module, type_map, type_argument);
                        }
                        method.type_arguments = type_arguments;
                        for (method.arguments) |argument| try self.rewriteExpression(module, argument, type_map);
                        for (method.named_arguments) |argument| try self.rewriteExpression(module, argument.value, type_map);
                    },
                    .field_assignment => |field| try self.rewriteExpression(module, field.value, type_map),
                };
            },
            .field_access => |access| {
                if (access.base.value == .generic_reference) {
                    const reference = &access.base.value.generic_reference;
                    const enumeration = try self.enumReceiverTarget(module, reference.name);
                    const structure = if (enumeration == null) try self.structureTarget(module, reference.name) else null;
                    if (enumeration orelse structure) |target| {
                        if (enumeration != null)
                            try self.requirePublicEnum(module, target, access.name_position)
                        else
                            try self.requirePublicStructure(module, target, access.name_position);
                        reference.name = try structureCanonicalName(self.allocator, try self.nominalModule(target), target.declaration);
                        for (@constCast(reference.type_arguments)) |*argument| {
                            argument.* = self.remapType(module, type_map, argument.*);
                        }
                        return;
                    }
                } else if (try expressionName(self.allocator, access.base)) |prefix| {
                    if (try self.enumReceiverTarget(module, prefix)) |target| {
                        try self.requirePublicEnum(module, target, access.name_position);
                        access.base.value = .{ .identifier = try structureCanonicalName(
                            self.allocator,
                            try self.enumModule(target),
                            target.declaration,
                        ) };
                        return;
                    } else if (try self.structureTarget(module, prefix)) |target| {
                        try self.requirePublicStructure(module, target, access.name_position);
                        access.base.value = .{ .identifier = try structureCanonicalName(
                            self.allocator,
                            try self.structureModule(target),
                            target.declaration,
                        ) };
                        return;
                    } else {
                        const qualified = try std.fmt.allocPrint(
                            self.allocator,
                            "{s}.{s}",
                            .{ prefix, access.name },
                        );
                        if (try self.targetForCall(module, qualified)) |candidate| {
                            if (try self.functionTarget(candidate)) |target| {
                                expression.value = .{ .identifier = try canonicalName(
                                    self.allocator,
                                    try self.functionModule(target),
                                    target.declaration,
                                ) };
                                return;
                            }
                        }
                    }
                }
                try self.rewriteExpression(module, access.base, type_map);
            },
            .generic_reference => |*reference| {
                const enumeration = try self.enumReceiverTarget(module, reference.name);
                const structure = if (enumeration == null) try self.structureTarget(module, reference.name) else null;
                const target = enumeration orelse structure orelse {
                    const message = try std.fmt.allocPrint(self.allocator, "unknown generic type '{s}'", .{reference.name});
                    return self.fail(expression.position, message);
                };
                if (enumeration != null)
                    try self.requirePublicEnum(module, target, expression.position)
                else
                    try self.requirePublicStructure(module, target, expression.position);
                reference.name = try structureCanonicalName(
                    self.allocator,
                    try self.nominalModule(target),
                    target.declaration,
                );
                for (@constCast(reference.type_arguments)) |*argument| {
                    argument.* = self.remapType(module, type_map, argument.*);
                }
            },
            .unary => |*unary| {
                try self.rewriteExpression(module, unary.operand, type_map);
                if (unary.try_alternative) |*alternative| {
                    if (alternative.statements) |statements| alternative.statements = try self.rewriteStatements(module, statements, type_map);
                    if (alternative.message) |message| try self.rewriteExpression(module, message, type_map);
                }
            },
            .binary => |binary| {
                try self.rewriteExpression(module, binary.left, type_map);
                try self.rewriteExpression(module, binary.right, type_map);
            },
            .conversion => |*conversion| {
                conversion.target = self.remapType(module, type_map, conversion.target);
                try self.rewriteExpression(module, conversion.operand, type_map);
            },
            .string_count => |operand| try self.rewriteExpression(module, operand, type_map),
            .sequence_literal => |*literal| {
                if (literal.inferred_type) |type_value| literal.inferred_type = self.remapType(module, type_map, type_value);
                for (literal.values) |value| try self.rewriteExpression(module, value, type_map);
            },
            .tuple_literal => |*literal| {
                literal.placeholder_type = self.remapType(module, type_map, literal.placeholder_type);
                for (literal.elements) |element| try self.rewriteExpression(module, element.value, type_map);
            },
            .index_access => |access| {
                try self.rewriteExpression(module, access.base, type_map);
                try self.rewriteExpression(module, access.index, type_map);
            },
            .slice_access => |access| {
                try self.rewriteExpression(module, access.base, type_map);
                try self.rewriteExpression(module, access.start, type_map);
                try self.rewriteExpression(module, access.end, type_map);
            },
            .interpolated_string => |interpolated| for (interpolated.parts) |part| switch (part) {
                .text => {},
                .expression => |value| try self.rewriteExpression(module, value, type_map),
            },
            .match_expression => |*match_value| {
                try self.rewriteExpression(module, match_value.subject, type_map);
                const branches = try self.allocator.alloc(Ast.Expression.MatchBranch, match_value.branches.len);
                for (match_value.branches, 0..) |branch, branch_index| {
                    branches[branch_index] = branch;
                    if (branch.guard) |guard| try self.rewriteExpression(module, guard, type_map);
                    if (branch.value) |value| try self.rewriteExpression(module, value, type_map);
                    if (branch.statements) |statements| {
                        branches[branch_index].statements = try self.rewriteStatements(module, statements, type_map);
                    }
                }
                match_value.branches = branches;
            },
            .identifier => |*name| if (Fragments.contextualOrigin(name.*)) |origin| if (!Fragments.hasBindingAlias(
                self.units,
                module,
                Fragments.label(origin),
            ) and findStructure(self.units[module].program.?, Fragments.label(origin)) == null and
                findEnum(self.units[module].program.?, Fragments.label(origin)) == null)
            {
                const target = try self.requireContextualTarget(module, name.*, origin);
                var found = false;
                for (self.units[target.module].program.?.functions) |function| {
                    if (std.mem.eql(u8, function.name, target.declaration)) {
                        found = true;
                        break;
                    }
                }
                if (!found) {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "{s} fragment of '{s}' has no function '{s}'",
                        .{ Fragments.label(origin), self.index.providers[module].name, target.declaration },
                    );
                    return self.fail(expression.position, message);
                }
                name.* = try canonicalName(
                    self.allocator,
                    try self.functionModule(target),
                    target.declaration,
                );
            },
            else => {},
        }
    }

    pub fn fail(self: *Compiler, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};
