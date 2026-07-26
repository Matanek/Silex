const std = @import("std");
const Ast = @import("Ast.zig");
const Interface = @import("Interface.zig");
const GenericSpecializer = @import("Generics/Specializer.zig").Specializer;
const Result = @import("Intrinsics/Result.zig");
const Ir = @import("Ir.zig");
const Modules = @import("Modules.zig");
const Names = @import("Project/Names.zig");
const Packages = @import("Packages.zig");
const ParserModule = @import("Parser.zig");
const Reexports = @import("Project/Reexports.zig");
const TypeAliases = @import("Project/TypeAliases.zig");
const GenericTypes = @import("Project/GenericTypes.zig");
const Paths = @import("Project/Paths.zig");
const Lookup = @import("Project/Lookup.zig");
const Semantic = @import("Semantic/Analyzer.zig");
const Source = @import("Source.zig");

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
    interfaces: []const Interface.Module,
    packages: Packages.Graph,
    files: []const []const u8,
};

const Binding = Reexports.Binding;
const Unit = Reexports.Unit;

pub const Compiler = struct {
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8 = null,
    packages: Packages.Graph = undefined,
    index: Modules.Index = undefined,
    units: []Unit = &.{},
    files: []const []const u8 = &.{},
    entry_module: usize = 0,
    diagnostic: ?Source.Diagnostic = null,
    generic_type_maps: []const []const Ast.Type = &.{},

    pub fn init(allocator: Allocator, io: Io) Compiler {
        return .{ .allocator = allocator, .io = io };
    }

    pub fn initWithPackages(allocator: Allocator, io: Io, global_packages_root: ?[]const u8) Compiler {
        return .{ .allocator = allocator, .io = io, .global_packages_root = global_packages_root };
    }

    pub fn compile(self: *Compiler, input_path: []const u8) Error!Compilation {
        self.diagnostic = null;
        if (!std.mem.endsWith(u8, input_path, ".sx")) {
            return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, "input must be a .sx source file");
        }

        const root_path = try Paths.findRoot(self.allocator, self.io, input_path);
        var package_resolver = Packages.Resolver.init(self.allocator, self.io, self.global_packages_root);
        self.packages = package_resolver.resolve(root_path) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.fail(
                .{ .offset = 0, .line = 1, .column = 1 },
                package_resolver.diagnostic orelse "invalid package graph",
            ),
            else => |other| return other,
        };
        self.index = Lookup.discoverProviders(self) catch |err| switch (err) {
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
        self.units = try self.allocator.alloc(Unit, self.index.providers.len);
        @memset(self.units, .{});
        const files = try self.allocator.alloc([]const u8, self.index.providers.len);
        for (self.index.providers, 0..) |provider, file| files[file] = provider.path;
        self.files = files;

        self.entry_module = Lookup.findProviderPath(self, input_path) orelse return self.fail(
            .{ .offset = 0, .line = 1, .column = 1 },
            "entry source is not a discovered module",
        );
        try self.loadModule(self.entry_module, null);
        try self.validateTypeAliases();
        try self.validateReexports();

        const composition = try self.composeAst();
        var specializer = GenericSpecializer.init(self.allocator);
        const ast = specializer.specialize(composition.program) catch |err| {
            self.diagnostic = specializer.diagnostic;
            return err;
        };
        const interfaces = try self.buildInterfaces(composition.type_maps);
        var analyzer = Semantic.Analyzer.init(self.allocator);
        var ir = analyzer.analyze(ast) catch |err| {
            self.diagnostic = analyzer.diagnostic;
            return err;
        };
        ir.files = self.files;

        return .{
            .ast = ast,
            .ir = ir,
            .interfaces = interfaces,
            .packages = self.packages,
            .files = self.files,
        };
    }

    pub fn diagnosticPath(self: Compiler, fallback: []const u8) []const u8 {
        const diagnostic = self.diagnostic orelse return fallback;
        if (diagnostic.position.file >= self.files.len) return fallback;
        return self.files[diagnostic.position.file];
    }

    fn loadModule(self: *Compiler, module: usize, from: ?usize) Error!void {
        switch (self.units[module].state) {
            .loaded => return,
            .loading => {
                if (from) |source| {
                    if (!sameParent(self.index.providers[source].name, self.index.providers[module].name)) {
                        return self.fail(
                            .{ .offset = 0, .line = 1, .column = 1, .file = self.index.providers[source].file },
                            "module dependency cycle crosses logical parents",
                        );
                    }
                }
                return;
            },
            .fresh => {},
        }
        self.units[module].state = .loading;

        const provider = self.index.providers[module];
        const source = try Io.Dir.cwd().readFileAlloc(
            self.io,
            provider.path,
            self.allocator,
            .limited(1024 * 1024),
        );
        var parser = ParserModule.Parser.initFile(self.allocator, source, provider.file);
        const parsed = parser.parse() catch |err| {
            self.diagnostic = parser.diagnostic;
            return err;
        };
        const program = try Result.install(self.allocator, parsed);
        self.units[module].program = program;

        var bindings: std.ArrayList(Binding) = .empty;
        for (program.uses) |use| {
            const binding = try self.resolveUse(module, use);
            for (program.functions) |function| {
                if (std.mem.eql(u8, function.name, binding.alias)) {
                    const position = use.alias_position orelse use.position;
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "use alias '{s}' collides with a local declaration",
                        .{binding.alias},
                    );
                    return self.fail(position, message);
                }
            }
            for (program.structures) |structure| {
                if (std.mem.eql(u8, structure.name, binding.alias)) {
                    const position = use.alias_position orelse use.position;
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "use alias '{s}' collides with a local declaration",
                        .{binding.alias},
                    );
                    return self.fail(position, message);
                }
            }
            for (program.enums) |enumeration| {
                if (std.mem.eql(u8, enumeration.name, binding.alias)) {
                    const position = use.alias_position orelse use.position;
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "use alias '{s}' collides with a local declaration",
                        .{binding.alias},
                    );
                    return self.fail(position, message);
                }
            }
            for (bindings.items) |existing| {
                if (std.mem.eql(u8, existing.alias, binding.alias)) {
                    const position = use.alias_position orelse use.position;
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "use alias '{s}' is already declared",
                        .{binding.alias},
                    );
                    return self.fail(position, message);
                }
            }
            try bindings.append(self.allocator, binding);
            if (binding.module) |dependency| try self.loadModule(dependency, module);
        }
        self.units[module].bindings = try bindings.toOwnedSlice(self.allocator);
        try self.activateQualifiedReferences(module);
        self.units[module].state = .loaded;
    }

    fn resolveUse(self: *Compiler, source_module: usize, use: Ast.Use) Error!Binding {
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
        if (Lookup.findAccessibleModule(self, use.path, owner)) |module| {
            return .{
                .alias = use.alias orelse lastSegment(use.path),
                .path = use.path,
                .module = module,
                .declaration = null,
                .is_public = use.is_public,
                .position = use.position,
            };
        }

        var separator = std.mem.lastIndexOfScalar(u8, use.path, '.');
        while (separator) |at| {
            const prefix = use.path[0..at];
            if (Lookup.findAccessibleModule(self, prefix, owner)) |module| {
                return .{
                    .alias = use.alias orelse lastSegment(use.path),
                    .path = prefix,
                    .module = module,
                    .declaration = use.path[at + 1 ..],
                    .is_public = use.is_public,
                    .position = use.position,
                };
            }
            separator = std.mem.lastIndexOfScalar(u8, prefix, '.');
        }

        if (Lookup.isAccessibleNamespace(self, use.path, owner)) {
            return .{
                .alias = use.alias orelse lastSegment(use.path),
                .path = use.path,
                .module = null,
                .declaration = null,
                .is_public = use.is_public,
                .position = use.position,
            };
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

        const message = try std.fmt.allocPrint(self.allocator, "unknown module or declaration '{s}'", .{use.path});
        return self.fail(use.position, message);
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

    fn resolveTypeAlias(
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
            if (structure.is_public) return;
            const message = if (structure.is_internal)
                try std.fmt.allocPrint(
                    self.allocator,
                    "public type alias '{s}' exposes internal structure '{s}'",
                    .{ alias, structure.name },
                )
            else
                try std.fmt.allocPrint(
                    self.allocator,
                    "public type alias '{s}' exposes private structure '{s}'",
                    .{ alias, structure.name },
                );
            return self.fail(position, message);
        }
        const enumeration = findEnum(program, nominal_target.declaration).?;
        if (enumeration.is_public) return;
        const message = if (enumeration.is_internal)
            try std.fmt.allocPrint(
                self.allocator,
                "public type alias '{s}' exposes internal enum '{s}'",
                .{ alias, enumeration.name },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "public type alias '{s}' exposes private enum '{s}'",
                .{ alias, enumeration.name },
            );
        return self.fail(position, message);
    }

    fn resolveReexport(
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

    fn activateQualifiedReferences(self: *Compiler, module: usize) Error!void {
        const program = self.units[module].program.?;
        for (program.structures) |structure| {
            for (structure.fields) |field| try self.activateType(module, field.type);
            for (structure.constructors) |constructor| {
                for (constructor.parameters) |parameter| try self.activateType(module, parameter.type);
                for (constructor.statements) |statement| try self.activateStatement(module, statement);
            }
            for (structure.methods) |method| {
                for (method.parameters) |parameter| try self.activateType(module, parameter.type);
                try self.activateType(module, method.return_type);
                for (method.statements) |statement| try self.activateStatement(module, statement);
            }
        }
        for (program.enums) |enumeration| {
            for (enumeration.variants) |variant| {
                for (variant.associated_types) |associated_type| try self.activateType(module, associated_type);
            }
        }
        for (program.enums) |enumeration| {
            if (!enumeration.is_public) continue;
            for (enumeration.variants) |variant| {
                for (variant.associated_types) |associated_type| {
                    try self.requirePublicType(module, associated_type, variant.position, "public enum", enumeration.name);
                }
            }
        }
        for (program.functions) |function| {
            for (function.parameters) |parameter| try self.activateType(module, parameter.type);
            try self.activateType(module, function.return_type);
            for (function.statements) |statement| try self.activateStatement(module, statement);
        }
    }

    fn activateType(self: *Compiler, module: usize, type_value: Ast.Type) Error!void {
        if (type_value.optionalChild()) |child| return self.activateType(module, child);
        const index = type_value.structureIndex() orelse return;
        const program = self.units[module].program.?;
        if (index >= program.type_names.len) return;
        const target = try self.nominalCandidate(module, program.type_names[index]) orelse return;
        if (target.module != module) try self.loadModule(target.module, module);
    }

    fn activateStatement(self: *Compiler, module: usize, statement: Ast.Statement) Error!void {
        switch (statement) {
            .variable_declaration => |declaration| if (declaration.initializer) |value|
                try self.activateExpression(module, value),
            .assignment_statement => |assignment| {
                if (assignment.value) |value| try self.activateExpression(module, value);
                for (assignment.target.indices) |target_index| try self.activateExpression(module, target_index.value);
            },
            .return_statement => |value| if (value.value) |expression|
                try self.activateExpression(module, expression),
            .expression_statement => |expression| try self.activateExpression(module, expression),
            .print_statement => |print_statement| for (print_statement.values) |value| try self.activateExpression(module, value),
            .panic_statement => |effect| try self.activateExpression(module, effect.value),
            .assert_statement => |assertion| {
                try self.activateExpression(module, assertion.condition);
                try self.activateExpression(module, assertion.message);
            },
            .if_statement => |conditional| {
                for (conditional.branches) |branch| {
                    try self.activateExpression(module, branch.condition.source());
                    for (branch.statements) |nested| try self.activateStatement(module, nested);
                }
                if (conditional.else_statements) |statements| {
                    for (statements) |nested| try self.activateStatement(module, nested);
                }
            },
            .while_statement => |loop| {
                try self.activateExpression(module, loop.condition.source());
                for (loop.statements) |nested| try self.activateStatement(module, nested);
            },
            .break_statement, .continue_statement => {},
        }
    }

    fn activateExpression(self: *Compiler, module: usize, expression: *Ast.Expression) Error!void {
        switch (expression.value) {
            .call => |call| {
                const qualified_name = if (call.receiver) |receiver|
                    if (try expressionName(self.allocator, receiver)) |prefix|
                        try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, call.name })
                    else
                        null
                else
                    call.name;
                if (qualified_name) |name| {
                    if (call.receiver) |receiver| if (try expressionName(self.allocator, receiver)) |prefix| {
                        for (self.units[module].bindings) |binding| {
                            if (std.mem.eql(u8, binding.alias, prefix)) {
                                if (binding.module) |target_module| try self.loadModule(target_module, module);
                            }
                        }
                    };
                    if (try self.targetForCall(module, name)) |target| {
                        try self.loadModule(target.module, module);
                    } else if (call.receiver) |receiver| try self.activateExpression(module, receiver);
                } else if (call.receiver) |receiver| try self.activateExpression(module, receiver);
                for (call.arguments) |argument| try self.activateExpression(module, argument);
                for (call.named_arguments) |argument| try self.activateExpression(module, argument.value);
            },
            .field_access => |access| try self.activateExpression(module, access.base),
            .unary => |unary| try self.activateExpression(module, unary.operand),
            .binary => |binary| {
                try self.activateExpression(module, binary.left);
                try self.activateExpression(module, binary.right);
            },
            .conversion => |conversion| try self.activateExpression(module, conversion.operand),
            .string_count => |operand| try self.activateExpression(module, operand),
            .sequence_literal => |literal| for (literal.values) |value| try self.activateExpression(module, value),
            .index_access => |access| {
                try self.activateExpression(module, access.base);
                try self.activateExpression(module, access.index);
            },
            .interpolated_string => |interpolated| for (interpolated.parts) |part| switch (part) {
                .text => {},
                .expression => |value| try self.activateExpression(module, value),
            },
            .match_expression => |match_value| {
                try self.activateExpression(module, match_value.subject);
                for (match_value.branches) |branch| {
                    if (branch.value) |value| try self.activateExpression(module, value);
                    if (branch.statements) |statements| for (statements) |statement| try self.activateStatement(module, statement);
                }
            },
            else => {},
        }
    }

    const CallTarget = Reexports.Target;

    fn targetForCall(self: *Compiler, module: usize, call_name: []const u8) Error!?CallTarget {
        const separator = std.mem.indexOfScalar(u8, call_name, '.');
        if (separator == null) {
            for (self.units[module].bindings) |binding| {
                if (binding.declaration != null and std.mem.eql(u8, binding.alias, call_name)) {
                    return .{ .module = binding.module.?, .declaration = binding.declaration.? };
                }
            }
            return null;
        }

        const head = call_name[0..separator.?];
        const tail = call_name[separator.? + 1 ..];
        for (self.units[module].bindings) |binding| {
            if (!std.mem.eql(u8, binding.alias, head) or binding.declaration != null) continue;
            if (binding.module) |target_module| {
                return .{ .module = target_module, .declaration = tail };
            }
            const canonical = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ binding.path, tail });
            if (self.longestModulePrefix(canonical, self.index.providers[module].owner)) |target| return target;
            const message = try std.fmt.allocPrint(self.allocator, "unknown qualified path '{s}'", .{canonical});
            return self.fail(expressionPosition(module), message);
        }
        return null;
    }

    fn structureCandidate(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        if (findStructure(self.units[module].program.?, name) != null) {
            return .{ .module = module, .declaration = name };
        }
        if (std.mem.indexOfScalar(u8, name, '.') != null) return self.targetForCall(module, name);
        for (self.units[module].bindings) |binding| {
            if (!std.mem.eql(u8, binding.alias, name)) continue;
            const target_module = binding.module orelse continue;
            return .{
                .module = target_module,
                .declaration = binding.declaration orelse lastSegment(self.index.providers[target_module].name),
            };
        }
        if (try self.resolveTypeAlias(module, name, expressionPosition(module), false)) |target| {
            return switch (target) {
                .fundamental => null,
                .structure => |structure| structure,
                .enumeration => null,
            };
        }
        return null;
    }

    fn enumCandidate(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        if (findEnum(self.units[module].program.?, name) != null) {
            return .{ .module = module, .declaration = name };
        }
        if (std.mem.indexOfScalar(u8, name, '.') != null) return self.targetForCall(module, name);
        for (self.units[module].bindings) |binding| {
            if (!std.mem.eql(u8, binding.alias, name)) continue;
            const target_module = binding.module orelse continue;
            return .{
                .module = target_module,
                .declaration = binding.declaration orelse lastSegment(self.index.providers[target_module].name),
            };
        }
        if (try self.resolveTypeAlias(module, name, expressionPosition(module), false)) |target| {
            return switch (target) {
                .fundamental, .structure => null,
                .enumeration => |enumeration| enumeration,
            };
        }
        return null;
    }

    fn nominalCandidate(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        return try self.structureCandidate(module, name) orelse try self.enumCandidate(module, name);
    }

    fn structureTarget(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        const target = try self.structureCandidate(module, name) orelse return null;
        if (self.units[target.module].state != .loaded) return null;
        if (findStructure(self.units[target.module].program.?, target.declaration) != null) return target;
        return self.resolveReexport(
            target.module,
            target.declaration,
            .structure,
            try self.allocator.alloc(bool, self.units.len),
        );
    }

    fn enumTarget(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        const target = try self.enumCandidate(module, name) orelse return null;
        if (self.units[target.module].state != .loaded) return null;
        if (findEnum(self.units[target.module].program.?, target.declaration) != null) return target;
        return self.resolveReexport(
            target.module,
            target.declaration,
            .enumeration,
            try self.allocator.alloc(bool, self.units.len),
        );
    }

    fn enumReceiverTarget(self: *Compiler, module: usize, name: []const u8) Error!?CallTarget {
        const separator = std.mem.indexOfScalar(u8, name, '.');
        if (separator == null) return self.enumTarget(module, name);
        const head = name[0..separator.?];
        const tail = name[separator.? + 1 ..];
        for (self.units[module].bindings) |binding| {
            if (!std.mem.eql(u8, binding.alias, head) or binding.declaration != null) continue;
            if (binding.module) |target_module| return self.enumTarget(target_module, tail);
        }
        for (self.index.providers, 0..) |provider, target_module| {
            if (self.units[target_module].state != .loaded) continue;
            for (self.units[target_module].program.?.enums) |enumeration| {
                const canonical = try structureCanonicalName(self.allocator, provider.name, enumeration.name);
                if (std.mem.eql(u8, canonical, name)) return .{ .module = target_module, .declaration = enumeration.name };
            }
        }
        return null;
    }

    fn functionTarget(self: *Compiler, target: CallTarget) Error!?CallTarget {
        const program = self.units[target.module].program orelse return null;
        for (program.functions) |function| {
            if (std.mem.eql(u8, function.name, target.declaration)) return target;
        }
        return self.resolveReexport(
            target.module,
            target.declaration,
            .function,
            try self.allocator.alloc(bool, self.units.len),
        );
    }

    fn resolveStructure(self: *Compiler, module: usize, name: []const u8, position: Source.Position) Error!CallTarget {
        const target = try self.structureTarget(module, name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "unknown structure type '{s}'", .{name});
            return self.fail(position, message);
        };
        try self.requirePublicStructure(module, target, position);
        return target;
    }

    fn resolveEnum(self: *Compiler, module: usize, name: []const u8, position: Source.Position) Error!CallTarget {
        const target = try self.enumTarget(module, name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "unknown enum type '{s}'", .{name});
            return self.fail(position, message);
        };
        try self.requirePublicEnum(module, target, position);
        return target;
    }

    fn requirePublicStructure(self: *Compiler, source_module: usize, target: CallTarget, position: Source.Position) Error!void {
        if (source_module == target.module) return;
        const structure = findStructure(self.units[target.module].program.?, target.declaration).?;
        if (structure.is_public) return;
        const message = if (structure.is_internal)
            try std.fmt.allocPrint(self.allocator, "structure '{s}' is internal to its source file", .{target.declaration})
        else
            try std.fmt.allocPrint(self.allocator, "structure '{s}' is private outside its module", .{target.declaration});
        return self.fail(position, message);
    }

    fn requirePublicEnum(self: *Compiler, source_module: usize, target: CallTarget, position: Source.Position) Error!void {
        if (source_module == target.module) return;
        const enumeration = findEnum(self.units[target.module].program.?, target.declaration).?;
        if (enumeration.is_public) return;
        const message = if (enumeration.is_internal)
            try std.fmt.allocPrint(self.allocator, "enum '{s}' is internal to its source file", .{target.declaration})
        else
            try std.fmt.allocPrint(self.allocator, "enum '{s}' is private outside its module", .{target.declaration});
        return self.fail(position, message);
    }

    fn longestModulePrefix(self: *Compiler, path: []const u8, owner: usize) ?CallTarget {
        var end = path.len;
        while (true) {
            const prefix = path[0..end];
            if (Lookup.findAccessibleModule(self, prefix, owner)) |module| {
                if (end == path.len) return null;
                return .{ .module = module, .declaration = path[end + 1 ..] };
            }
            end = std.mem.lastIndexOfScalar(u8, prefix, '.') orelse return null;
        }
    }

    const AstComposition = struct {
        program: Ast.Program,
        type_maps: []const []const Ast.Type,
    };

    fn collectionCanonicalName(self: *Compiler, module: usize, collection: Ast.Collection) Error![]const u8 {
        const element = try self.canonicalTypeSpelling(module, collection.element);
        return if (collection.length) |length|
            std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ element, length })
        else
            std.fmt.allocPrint(self.allocator, "{s}[]", .{element});
    }

    fn canonicalTypeSpelling(self: *Compiler, module: usize, type_value: Ast.Type) Error![]const u8 {
        if (type_value.optionalChild()) |child| return std.fmt.allocPrint(self.allocator, "{s}?", .{try self.canonicalTypeSpelling(module, child)});
        if (type_value.genericParameterIndex()) |index| return std.fmt.allocPrint(self.allocator, "T{d}", .{index});
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
        return structureCanonicalName(self.allocator, self.index.providers[target.module].name, target.declaration);
    }

    fn composeAst(self: *Compiler) Error!AstComposition {
        var type_names: std.ArrayList([]const u8) = .empty;
        for (self.index.providers, 0..) |provider, module| {
            if (self.units[module].state != .loaded) continue;
            for (self.units[module].program.?.structures) |structure| {
                const name = if (structure.collection) |collection|
                    try self.collectionCanonicalName(module, collection)
                else
                    try structureCanonicalName(self.allocator, provider.name, structure.name);
                for (type_names.items) |existing| {
                    if (std.mem.eql(u8, existing, name)) {
                        if (structure.collection != null) break;
                        const message = try std.fmt.allocPrint(self.allocator, "structure identity '{s}' is already provided", .{name});
                        return self.fail(structure.name_position, message);
                    }
                } else try type_names.append(self.allocator, name);
            }
            for (self.units[module].program.?.enums) |enumeration| {
                const name = try structureCanonicalName(self.allocator, provider.name, enumeration.name);
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
                                self.index.providers[target.module].name,
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
                                self.index.providers[target.module].name,
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
                    self.index.providers[target.module].name,
                    target.declaration,
                );
                map[index] = .structure(findName(type_names.items, canonical) orelse return error.InvalidSource);
            }
            type_maps[module] = map;
            try self.validatePublicTypeExposure(module);
        }
        const generic_composition = try GenericTypes.compose(self.allocator, self.units, type_maps);
        self.generic_type_maps = generic_composition.maps;
        for (type_maps, 0..) |type_map, module| {
            for (@constCast(type_map)) |*type_value| {
                type_value.* = GenericTypes.remap(type_value.*, &.{}, self.generic_type_maps[module]);
            }
        }

        var structures: std.ArrayList(Ast.Structure) = .empty;
        var enums: std.ArrayList(Ast.Enum) = .empty;
        var functions: std.ArrayList(Ast.Function) = .empty;
        for (self.index.providers, 0..) |provider, module| {
            if (self.units[module].state != .loaded) continue;
            const program = self.units[module].program.?;
            const type_map = type_maps[module];
            const generic_map = self.generic_type_maps[module];
            for (program.structures) |structure| {
                const composed_name = if (structure.collection) |collection|
                    try self.collectionCanonicalName(module, collection)
                else
                    try structureCanonicalName(self.allocator, provider.name, structure.name);
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
                if (structure.collection) |collection| composed_structure.collection = .{
                    .element = GenericTypes.remap(collection.element, type_map, generic_map),
                    .length = collection.length,
                };
                const fields = try self.allocator.alloc(Ast.StructureField, structure.fields.len);
                for (structure.fields, 0..) |field, index| {
                    fields[index] = field;
                    fields[index].type = GenericTypes.remap(field.type, type_map, generic_map);
                    if (field.default) |value| try self.rewriteExpression(module, value, type_map);
                }
                composed_structure.fields = fields;
                const constructors = try self.allocator.alloc(Ast.Constructor, structure.constructors.len);
                for (structure.constructors, 0..) |constructor, constructor_index| {
                    constructors[constructor_index] = constructor;
                    const parameters = try self.allocator.alloc(Ast.Parameter, constructor.parameters.len);
                    for (constructor.parameters, 0..) |parameter, parameter_index| {
                        parameters[parameter_index] = parameter;
                        parameters[parameter_index].type = GenericTypes.remap(parameter.type, type_map, generic_map);
                        if (parameter.default) |value| try self.rewriteExpression(module, value, type_map);
                    }
                    constructors[constructor_index].parameters = parameters;
                    constructors[constructor_index].statements = try self.rewriteStatements(module, constructor.statements, type_map);
                }
                composed_structure.constructors = constructors;
                const methods = try self.allocator.alloc(Ast.Function, structure.methods.len);
                for (structure.methods, 0..) |method, method_index| {
                    methods[method_index] = method;
                    methods[method_index].owner = provider.owner;
                    const parameters = try self.allocator.alloc(Ast.Parameter, method.parameters.len);
                    for (method.parameters, 0..) |parameter, parameter_index| {
                        parameters[parameter_index] = parameter;
                        parameters[parameter_index].type = GenericTypes.remap(parameter.type, type_map, generic_map);
                        if (parameter.default) |value| try self.rewriteExpression(module, value, type_map);
                    }
                    methods[method_index].parameters = parameters;
                    methods[method_index].return_type = GenericTypes.remap(method.return_type, type_map, generic_map);
                    methods[method_index].statements = try self.rewriteStatements(module, method.statements, type_map);
                }
                composed_structure.methods = methods;
                try structures.append(self.allocator, composed_structure);
            }
            for (program.enums) |enumeration| {
                var composed = enumeration;
                composed.owner = provider.owner;
                composed.name = try structureCanonicalName(self.allocator, provider.name, enumeration.name);
                const variants = try self.allocator.alloc(Ast.EnumVariant, enumeration.variants.len);
                for (enumeration.variants, 0..) |variant, variant_index| {
                    variants[variant_index] = variant;
                    const associated_types = try self.allocator.alloc(Ast.Type, variant.associated_types.len);
                    for (variant.associated_types, 0..) |associated_type, type_index| {
                        associated_types[type_index] = GenericTypes.remap(associated_type, type_map, generic_map);
                    }
                    variants[variant_index].associated_types = associated_types;
                }
                composed.variants = variants;
                try enums.append(self.allocator, composed);
            }
            for (program.functions) |function| {
                var composed = function;
                composed.owner = provider.owner;
                composed.name = if (module == self.entry_module and std.mem.eql(u8, function.name, "main"))
                    "main"
                else
                    try canonicalName(self.allocator, provider.name, function.name);
                const parameters = try self.allocator.alloc(Ast.Parameter, function.parameters.len);
                for (function.parameters, 0..) |parameter, index| {
                    parameters[index] = parameter;
                    parameters[index].type = GenericTypes.remap(parameter.type, type_map, generic_map);
                    if (parameter.default) |value| try self.rewriteExpression(module, value, type_map);
                }
                composed.parameters = parameters;
                composed.return_type = GenericTypes.remap(function.return_type, type_map, generic_map);
                composed.statements = try self.rewriteStatements(module, function.statements, type_map);
                try functions.append(self.allocator, composed);
            }
        }
        return .{ .program = .{
            .type_names = try type_names.toOwnedSlice(self.allocator),
            .generic_types = generic_composition.types,
            .structures = try structures.toOwnedSlice(self.allocator),
            .enums = try enums.toOwnedSlice(self.allocator),
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
            interface_by_module[module] = interfaces.items.len;
            try interfaces.append(
                self.allocator,
                try Interface.buildMappedGenerics(
                    self.allocator,
                    owner,
                    provider.name,
                    self.units[module].program.?,
                    type_maps[module],
                    self.generic_type_maps[module],
                ),
            );
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
            if (!structure.is_public) continue;
            for (structure.fields) |field| {
                if (field.is_internal) continue;
                try self.requirePublicType(module, field.type, field.name_position, "public structure", structure.name);
            }
            for (structure.constructors) |constructor| {
                if (constructor.is_internal) continue;
                for (constructor.parameters) |parameter| {
                    try self.requirePublicType(module, parameter.type, parameter.position, "constructor of", structure.name);
                }
            }
            for (structure.methods) |method| {
                if (method.is_internal) continue;
                for (method.parameters) |parameter| {
                    try self.requirePublicType(module, parameter.type, parameter.position, "method of", structure.name);
                }
                try self.requirePublicOutputType(module, method.return_type, method.name_position, "method of", structure.name);
            }
        }
        for (program.functions) |function| {
            if (!function.is_public) continue;
            for (function.parameters) |parameter| {
                try self.requirePublicType(module, parameter.type, parameter.position, "public function", function.name);
            }
            try self.requirePublicOutputType(module, function.return_type, function.name_position, "public function", function.name);
        }
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
            if (structure.is_internal) return;
        } else if (findEnum(target_program, target.declaration).?.is_internal) return;
        return self.requirePublicType(module, type_value, position, declaration_kind, declaration_name);
    }

    fn requirePublicType(
        self: *Compiler,
        module: usize,
        type_value: Ast.Type,
        position: Source.Position,
        declaration_kind: []const u8,
        declaration_name: []const u8,
    ) Error!void {
        if (type_value.optionalChild()) |child| return self.requirePublicType(module, child, position, declaration_kind, declaration_name);
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
            if (structure.collection) |collection| {
                return self.requirePublicType(module, collection.element, position, declaration_kind, declaration_name);
            }
            if (structure.is_public) return;
            const message = if (structure.is_internal)
                try std.fmt.allocPrint(
                    self.allocator,
                    "{s} '{s}' exposes internal structure '{s}'",
                    .{ declaration_kind, declaration_name, structure.name },
                )
            else
                try std.fmt.allocPrint(
                    self.allocator,
                    "{s} '{s}' exposes private structure '{s}'",
                    .{ declaration_kind, declaration_name, structure.name },
                );
            return self.fail(position, message);
        }
        const enumeration = findEnum(target_program, target.declaration).?;
        if (enumeration.is_public) return;
        const message = if (enumeration.is_internal)
            try std.fmt.allocPrint(
                self.allocator,
                "{s} '{s}' exposes internal enum '{s}'",
                .{ declaration_kind, declaration_name, enumeration.name },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "{s} '{s}' exposes private enum '{s}'",
                .{ declaration_kind, declaration_name, enumeration.name },
            );
        return self.fail(position, message);
    }

    fn rewriteStatements(self: *Compiler, module: usize, statements: []const Ast.Statement, type_map: []const Ast.Type) Error![]const Ast.Statement {
        const rewritten = try self.allocator.alloc(Ast.Statement, statements.len);
        for (statements, 0..) |statement, index| rewritten[index] = switch (statement) {
            .variable_declaration => |declaration| variable: {
                var value = declaration;
                if (value.annotation) |annotation| value.annotation = GenericTypes.remap(annotation, type_map, self.generic_type_maps[module]);
                if (value.initializer) |initializer| try self.rewriteExpression(module, initializer, type_map);
                break :variable .{ .variable_declaration = value };
            },
            .assignment_statement => |assignment| assignment_statement: {
                if (assignment.value) |value| try self.rewriteExpression(module, value, type_map);
                for (assignment.target.indices) |target_index| try self.rewriteExpression(module, target_index.value, type_map);
                break :assignment_statement .{ .assignment_statement = assignment };
            },
            .return_statement => |value| return_statement: {
                if (value.value) |expression| try self.rewriteExpression(module, expression, type_map);
                break :return_statement .{ .return_statement = value };
            },
            .expression_statement => |expression| expression_statement: {
                try self.rewriteExpression(module, expression, type_map);
                break :expression_statement .{ .expression_statement = expression };
            },
            .print_statement => |print_statement| print: {
                for (print_statement.values) |value| try self.rewriteExpression(module, value, type_map);
                break :print .{ .print_statement = print_statement };
            },
            .panic_statement => |effect| panic: {
                try self.rewriteExpression(module, effect.value, type_map);
                break :panic .{ .panic_statement = effect };
            },
            .assert_statement => |assertion| assertion_statement: {
                try self.rewriteExpression(module, assertion.condition, type_map);
                try self.rewriteExpression(module, assertion.message, type_map);
                break :assertion_statement .{ .assert_statement = assertion };
            },
            .if_statement => |conditional| conditional_statement: {
                const branches = try self.allocator.alloc(Ast.ConditionalBranch, conditional.branches.len);
                for (conditional.branches, 0..) |branch, branch_index| {
                    try self.rewriteExpression(module, branch.condition.source(), type_map);
                    branches[branch_index] = branch;
                    branches[branch_index].statements = try self.rewriteStatements(module, branch.statements, type_map);
                }
                var value = conditional;
                value.branches = branches;
                if (conditional.else_statements) |nested| value.else_statements = try self.rewriteStatements(module, nested, type_map);
                break :conditional_statement .{ .if_statement = value };
            },
            .while_statement => |loop| loop_statement: {
                try self.rewriteExpression(module, loop.condition.source(), type_map);
                var value = loop;
                value.statements = try self.rewriteStatements(module, loop.statements, type_map);
                break :loop_statement .{ .while_statement = value };
            },
            .break_statement => |position| .{ .break_statement = position },
            .continue_statement => |position| .{ .continue_statement = position },
        };
        return rewritten;
    }

    fn rewriteExpression(self: *Compiler, module: usize, expression: *Ast.Expression, type_map: []const Ast.Type) Error!void {
        switch (expression.value) {
            .call => |*call| {
                call.owner = self.index.providers[module].owner;
                const type_arguments = try self.allocator.alloc(Ast.Type, call.type_arguments.len);
                for (call.type_arguments, 0..) |type_argument, index| {
                    type_arguments[index] = GenericTypes.remap(type_argument, type_map, self.generic_type_maps[module]);
                }
                call.type_arguments = type_arguments;
                for (call.arguments) |argument| try self.rewriteExpression(module, argument, type_map);
                for (call.named_arguments) |argument| try self.rewriteExpression(module, argument.value, type_map);
                if (call.receiver) |receiver| {
                    if (receiver.value == .generic_reference) {
                        const reference = &receiver.value.generic_reference;
                        const target = try self.enumReceiverTarget(module, reference.name) orelse {
                            const message = try std.fmt.allocPrint(self.allocator, "unknown generic enum '{s}'", .{reference.name});
                            return self.fail(receiver.position, message);
                        };
                        try self.requirePublicEnum(module, target, call.name_position);
                        reference.name = try structureCanonicalName(self.allocator, self.index.providers[target.module].name, target.declaration);
                        for (@constCast(reference.type_arguments)) |*argument| {
                            argument.* = GenericTypes.remap(argument.*, type_map, self.generic_type_maps[module]);
                        }
                    } else if (try expressionName(self.allocator, receiver)) |prefix| {
                        if (try self.enumReceiverTarget(module, prefix)) |target| {
                            try self.requirePublicEnum(module, target, call.name_position);
                            receiver.value = .{ .identifier = try structureCanonicalName(
                                self.allocator,
                                self.index.providers[target.module].name,
                                target.declaration,
                            ) };
                        } else {
                            const qualified = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, call.name });
                            if (try self.structureTarget(module, qualified) != null or try self.targetForCall(module, qualified) != null) {
                                call.name = qualified;
                                call.receiver = null;
                            } else if (prefix.len != 0 and std.ascii.isUpper(prefix[0])) {
                                call.name = qualified;
                                call.receiver = null;
                            } else try self.rewriteExpression(module, receiver, type_map);
                        }
                    } else try self.rewriteExpression(module, receiver, type_map);
                }
                if (call.receiver == null and std.mem.eql(u8, call.name, "map_error")) {
                    if (call.arguments.len == 2 and call.arguments[1].value == .identifier) {
                        const transformer = &call.arguments[1].value.identifier;
                        if (try self.targetForCall(module, transformer.*)) |candidate| {
                            if (try self.functionTarget(candidate)) |target| transformer.* = try canonicalName(
                                self.allocator,
                                self.index.providers[target.module].name,
                                target.declaration,
                            );
                        } else if (Lookup.findLocalFunction(self.units[module].program.?, transformer.*)) {
                            transformer.* = try canonicalName(self.allocator, self.index.providers[module].name, transformer.*);
                        }
                    }
                    return;
                }
                if (try self.structureTarget(module, call.name)) |target| {
                    try self.requirePublicStructure(module, target, call.name_position);
                    call.name = try structureCanonicalName(
                        self.allocator,
                        self.index.providers[target.module].name,
                        target.declaration,
                    );
                } else if (try self.targetForCall(module, call.name)) |candidate| {
                    if (try self.functionTarget(candidate)) |target| {
                        call.name = try canonicalName(
                            self.allocator,
                            self.index.providers[target.module].name,
                            target.declaration,
                        );
                    }
                } else if (call.receiver == null and std.mem.indexOfScalar(u8, call.name, '.') == null) {
                    call.name = if (findStructure(self.units[module].program.?, call.name) != null)
                        try structureCanonicalName(self.allocator, self.index.providers[module].name, call.name)
                    else
                        try canonicalName(self.allocator, self.index.providers[module].name, call.name);
                }
            },
            .field_access => |access| try self.rewriteExpression(module, access.base, type_map),
            .generic_reference => |*reference| {
                for (@constCast(reference.type_arguments)) |*argument| {
                    argument.* = GenericTypes.remap(argument.*, type_map, self.generic_type_maps[module]);
                }
            },
            .unary => |unary| try self.rewriteExpression(module, unary.operand, type_map),
            .binary => |binary| {
                try self.rewriteExpression(module, binary.left, type_map);
                try self.rewriteExpression(module, binary.right, type_map);
            },
            .conversion => |*conversion| {
                conversion.target = GenericTypes.remap(conversion.target, type_map, self.generic_type_maps[module]);
                try self.rewriteExpression(module, conversion.operand, type_map);
            },
            .string_count => |operand| try self.rewriteExpression(module, operand, type_map),
            .sequence_literal => |*literal| {
                if (literal.inferred_type) |type_value| literal.inferred_type = GenericTypes.remap(type_value, type_map, self.generic_type_maps[module]);
                for (literal.values) |value| try self.rewriteExpression(module, value, type_map);
            },
            .index_access => |access| {
                try self.rewriteExpression(module, access.base, type_map);
                try self.rewriteExpression(module, access.index, type_map);
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
                    if (branch.value) |value| try self.rewriteExpression(module, value, type_map);
                    if (branch.statements) |statements| {
                        branches[branch_index].statements = try self.rewriteStatements(module, statements, type_map);
                    }
                }
                match_value.branches = branches;
            },
            else => {},
        }
    }

    fn fail(self: *Compiler, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};
