const std = @import("std");
const Ast = @import("Ast.zig");
const Interface = @import("Interface.zig");
const Ir = @import("Ir.zig");
const Modules = @import("Modules.zig");
const Packages = @import("Packages.zig");
const ParserModule = @import("Parser.zig");
const Semantic = @import("Semantic.zig");
const Source = @import("Source.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Error = anyerror;

pub const Compilation = struct {
    ast: Ast.Program,
    ir: Ir.Program,
    interfaces: []const Interface.Module,
    packages: Packages.Graph,
    files: []const []const u8,
};

const State = enum { fresh, loading, loaded };

const Binding = struct {
    alias: []const u8,
    path: []const u8,
    module: ?usize,
    declaration: ?[]const u8,
};

const Unit = struct {
    state: State = .fresh,
    program: ?Ast.Program = null,
    bindings: []const Binding = &.{},
};

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

        const root_path = try findProjectRoot(self.allocator, self.io, input_path);
        var package_resolver = Packages.Resolver.init(self.allocator, self.io, self.global_packages_root);
        self.packages = package_resolver.resolve(root_path) catch |err| switch (err) {
            error.InvalidPackageGraph => return self.fail(
                .{ .offset = 0, .line = 1, .column = 1 },
                package_resolver.diagnostic orelse "invalid package graph",
            ),
            else => |other| return other,
        };
        self.index = self.discoverProviders() catch |err| switch (err) {
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

        self.entry_module = self.findProviderPath(input_path) orelse return self.fail(
            .{ .offset = 0, .line = 1, .column = 1 },
            "entry source is not a discovered module",
        );
        try self.loadModule(self.entry_module, null);

        const interfaces = try self.buildInterfaces();
        const ast = try self.composeAst();
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
        const program = parser.parse() catch |err| {
            self.diagnostic = parser.diagnostic;
            return err;
        };
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
        const owner = self.index.providers[source_module].owner;
        if (self.findAccessibleModule(use.path, owner)) |module| {
            return .{
                .alias = use.alias orelse lastSegment(use.path),
                .path = use.path,
                .module = module,
                .declaration = null,
            };
        }

        var separator = std.mem.lastIndexOfScalar(u8, use.path, '.');
        while (separator) |at| {
            const prefix = use.path[0..at];
            if (self.findAccessibleModule(prefix, owner)) |module| {
                return .{
                    .alias = use.alias orelse lastSegment(use.path),
                    .path = prefix,
                    .module = module,
                    .declaration = use.path[at + 1 ..],
                };
            }
            separator = std.mem.lastIndexOfScalar(u8, prefix, '.');
        }

        if (self.isAccessibleNamespace(use.path, owner)) {
            return .{
                .alias = use.alias orelse lastSegment(use.path),
                .path = use.path,
                .module = null,
                .declaration = null,
            };
        }

        const message = try std.fmt.allocPrint(self.allocator, "unknown module or declaration '{s}'", .{use.path});
        return self.fail(use.position, message);
    }

    fn activateQualifiedReferences(self: *Compiler, module: usize) Error!void {
        const program = self.units[module].program.?;
        for (program.functions) |function| {
            for (function.statements) |statement| try self.activateStatement(module, statement);
        }
    }

    fn activateStatement(self: *Compiler, module: usize, statement: Ast.Statement) Error!void {
        switch (statement) {
            .variable_declaration => |declaration| if (declaration.initializer) |value|
                try self.activateExpression(module, value),
            .return_statement => |value| if (value.value) |expression|
                try self.activateExpression(module, expression),
            .expression_statement => |expression| try self.activateExpression(module, expression),
            .print_statement, .panic_statement => |effect| try self.activateExpression(module, effect.value),
            .assert_statement => |assertion| {
                try self.activateExpression(module, assertion.condition);
                try self.activateExpression(module, assertion.message);
            },
        }
    }

    fn activateExpression(self: *Compiler, module: usize, expression: *Ast.Expression) Error!void {
        switch (expression.value) {
            .call => |call| {
                if (try self.targetForCall(module, call.name)) |target| {
                    try self.loadModule(target.module, module);
                }
                for (call.arguments) |argument| try self.activateExpression(module, argument);
            },
            .unary => |unary| try self.activateExpression(module, unary.operand),
            .binary => |binary| {
                try self.activateExpression(module, binary.left);
                try self.activateExpression(module, binary.right);
            },
            else => {},
        }
    }

    const CallTarget = struct {
        module: usize,
        declaration: []const u8,
    };

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

    fn longestModulePrefix(self: *Compiler, path: []const u8, owner: usize) ?CallTarget {
        var end = path.len;
        while (true) {
            const prefix = path[0..end];
            if (self.findAccessibleModule(prefix, owner)) |module| {
                if (end == path.len) return null;
                return .{ .module = module, .declaration = path[end + 1 ..] };
            }
            end = std.mem.lastIndexOfScalar(u8, prefix, '.') orelse return null;
        }
    }

    fn composeAst(self: *Compiler) Error!Ast.Program {
        var functions: std.ArrayList(Ast.Function) = .empty;
        for (self.index.providers, 0..) |provider, module| {
            if (self.units[module].state != .loaded) continue;
            const program = self.units[module].program.?;
            for (program.functions) |function| {
                var composed = function;
                composed.owner = provider.owner;
                composed.name = if (module == self.entry_module and std.mem.eql(u8, function.name, "main"))
                    "main"
                else
                    try canonicalName(self.allocator, provider.name, function.name);
                for (function.statements) |statement| try self.rewriteStatement(module, statement);
                try functions.append(self.allocator, composed);
            }
        }
        return .{ .functions = try functions.toOwnedSlice(self.allocator) };
    }

    fn buildInterfaces(self: *Compiler) Error![]const Interface.Module {
        var interfaces: std.ArrayList(Interface.Module) = .empty;
        for (self.index.providers, 0..) |provider, module| {
            if (self.units[module].state != .loaded) continue;
            const owner: Interface.Owner = if (self.packages.packages[provider.owner].name) |name|
                .{ .package = name }
            else
                .project;
            try interfaces.append(
                self.allocator,
                try Interface.build(self.allocator, owner, provider.name, self.units[module].program.?),
            );
        }
        return interfaces.toOwnedSlice(self.allocator);
    }

    fn rewriteStatement(self: *Compiler, module: usize, statement: Ast.Statement) Error!void {
        switch (statement) {
            .variable_declaration => |declaration| if (declaration.initializer) |value|
                try self.rewriteExpression(module, value),
            .return_statement => |value| if (value.value) |expression|
                try self.rewriteExpression(module, expression),
            .expression_statement => |expression| try self.rewriteExpression(module, expression),
            .print_statement, .panic_statement => |effect| try self.rewriteExpression(module, effect.value),
            .assert_statement => |assertion| {
                try self.rewriteExpression(module, assertion.condition);
                try self.rewriteExpression(module, assertion.message);
            },
        }
    }

    fn rewriteExpression(self: *Compiler, module: usize, expression: *Ast.Expression) Error!void {
        switch (expression.value) {
            .call => |*call| {
                call.owner = self.index.providers[module].owner;
                for (call.arguments) |argument| try self.rewriteExpression(module, argument);
                if (try self.targetForCall(module, call.name)) |target| {
                    call.name = try canonicalName(
                        self.allocator,
                        self.index.providers[target.module].name,
                        target.declaration,
                    );
                } else if (std.mem.indexOfScalar(u8, call.name, '.') == null) {
                    call.name = try canonicalName(self.allocator, self.index.providers[module].name, call.name);
                }
            },
            .unary => |unary| try self.rewriteExpression(module, unary.operand),
            .binary => |binary| {
                try self.rewriteExpression(module, binary.left);
                try self.rewriteExpression(module, binary.right);
            },
            else => {},
        }
    }

    fn findModule(self: Compiler, name: []const u8) ?usize {
        for (self.index.providers, 0..) |provider, module| {
            if (std.mem.eql(u8, provider.name, name)) return module;
        }
        return null;
    }

    fn findAccessibleModule(self: Compiler, name: []const u8, owner: usize) ?usize {
        const module = self.findModule(name) orelse return null;
        const provider = self.index.providers[module];
        if (!self.packages.canAccess(owner, provider.owner, provider.name)) return null;
        return module;
    }

    fn isAccessibleNamespace(self: Compiler, name: []const u8, owner: usize) bool {
        for (self.index.providers) |provider| {
            if (!self.packages.canAccess(owner, provider.owner, provider.name)) continue;
            if (std.mem.eql(u8, provider.name, name)) return true;
            if (provider.name.len > name.len and std.mem.startsWith(u8, provider.name, name) and
                provider.name[name.len] == '.') return true;
        }
        return false;
    }

    fn findProviderPath(self: Compiler, path: []const u8) ?usize {
        for (self.index.providers, 0..) |provider, index| {
            if (std.mem.eql(u8, provider.path, path)) return index;
        }
        return null;
    }

    fn discoverProviders(self: *Compiler) Error!Modules.Index {
        const indexes = try self.allocator.alloc(Modules.Index, self.packages.packages.len);
        for (self.packages.packages, 0..) |package, owner| {
            const prefix = package.name;
            var discovered = try Modules.discoverOwned(
                self.allocator,
                self.io,
                package.module_root,
                prefix,
                owner,
            );
            if (owner == 0) discovered = try self.excludePackageSources(discovered);
            indexes[owner] = discovered;
        }
        return Modules.combine(self.allocator, indexes);
    }

    fn excludePackageSources(self: *Compiler, index: Modules.Index) Allocator.Error!Modules.Index {
        var providers: std.ArrayList(Modules.Provider) = .empty;
        for (index.providers) |provider| {
            var excluded = false;
            for (self.packages.packages[1..]) |package| {
                if (pathInside(provider.path, package.root)) {
                    excluded = true;
                    break;
                }
            }
            if (!excluded) try providers.append(self.allocator, provider);
        }
        return .{ .providers = try providers.toOwnedSlice(self.allocator) };
    }

    fn fail(self: *Compiler, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn canonicalName(allocator: Allocator, module: []const u8, declaration: []const u8) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ module, declaration });
}

fn lastSegment(path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return path;
    return path[separator + 1 ..];
}

fn sameParent(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, parent(left), parent(right));
}

fn parent(path: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, path, '.') orelse return "";
    return path[0..separator];
}

fn expressionPosition(module: usize) Source.Position {
    return .{ .offset = 0, .line = 1, .column = 1, .file = module };
}

fn pathInside(path: []const u8, directory: []const u8) bool {
    if (!std.mem.startsWith(u8, path, directory) or path.len <= directory.len) return false;
    return path[directory.len] == std.fs.path.sep;
}

fn findProjectRoot(allocator: Allocator, io: Io, input_path: []const u8) Error![]const u8 {
    var directory = std.fs.path.dirname(input_path) orelse ".";
    while (true) {
        const manifest = try std.fs.path.join(allocator, &.{ directory, "Package.json" });
        if (fileExists(io, manifest)) return directory;
        const next = std.fs.path.dirname(directory) orelse return std.fs.path.dirname(input_path) orelse ".";
        if (std.mem.eql(u8, next, directory)) return std.fs.path.dirname(input_path) orelse ".";
        directory = next;
    }
}

fn fileExists(io: Io, path: []const u8) bool {
    _ = Io.Dir.cwd().statFile(io, path, .{}) catch return false;
    return true;
}

test "compile only the explicit local module closure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func answer() int { return Operations.add(20, 22) }
        \\func main() { answer() }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data = "func add(left:int, right:int) int { return left + right }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Unused.sx",
        .data = "this source is deliberately invalid",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const Interpreter = @import("Interpreter.zig");
    const answer = try Interpreter.invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqualStrings("Main.answer", compilation.ir.functions[0].name);
    try std.testing.expectEqualStrings("Math.Operations.add", compilation.ir.functions[2].name);
}

test "report missing modules and duplicate aliases" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Missing
        \\func main() {}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown module or declaration 'Missing'", compiler.diagnostic.?.message);

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "One.sx",
        .data = "func value() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Two.sx",
        .data = "func value() int { return 2 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use One as Same\nuse Two as Same\nfunc main() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("use alias 'Same' is already declared", compiler.diagnostic.?.message);
}

test "resolve explicit module aliases direct declarations and grouping namespaces" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations as Ops
        \\use Math.Operations.add as plus
        \\use Math as Group
        \\func byModule() int { return Ops.add(20, 22) }
        \\func byDeclaration() int { return plus(21, 21) }
        \\func byNamespace() int { return Group.Operations.add(40, 2) }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data = "func add(left:int, right:int) int { return left + right }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const Interpreter = @import("Interpreter.zig");
    for (0..3) |function| {
        const answer = try Interpreter.invoke(allocator, compilation.ir, function, &.{});
        try std.testing.expectEqual(@as(i64, 42), answer.integer);
    }
}

test "reject alias collisions and dependency cycles across logical parents" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.createDirPath(std.testing.io, "Other");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Group.A\nfunc main() { A.run() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/A.sx",
        .data = "use Other.B\nfunc run() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Other/B.sx",
        .data = "use Group.A\nfunc run() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "module dependency cycle crosses logical parents",
        compiler.diagnostic.?.message,
    );
}

test "allow dependency cycles under one logical parent" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Group");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Group.A\nfunc main() { A.run() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/A.sx",
        .data = "use Group.B\nfunc run() { B.touch() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Group/B.sx",
        .data = "use Group.A\nfunc touch() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    _ = try @import("Interpreter.zig").run(allocator, compilation.ir);
}

test "collect public overloads before analyzing calls across files" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Math.Operations
        \\func answer() int { return Operations.value(20) + Operations.value(true) }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Math/Operations.sx",
        .data =
        \\public func value(input:int) int { return input }
        \\public func value(input:bool) int { return 22 }
        \\func hidden() int { return 0 }
        ,
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 2), compilation.interfaces.len);
    try std.testing.expectEqual(@as(usize, 2), compilation.interfaces[1].functions.len);
    try std.testing.expect(compilation.interfaces[1].functions[0].id.eql(.{
        .owner = .project,
        .module = "Math.Operations",
        .name = "value",
        .parameter_types = &.{.int},
    }));
}

test "do not propagate private module access through a dependency" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Layer");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Layer.A\nfunc main() { B.hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Layer/A.sx",
        .data = "use Layer.B\nfunc touch() { B.hidden() }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Layer/B.sx",
        .data = "func hidden() {}",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown function 'B.hidden'", compiler.diagnostic.?.message);
}

test "compose simple modules with an adjacent local package" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Foo");
    try temporary.dir.createDirPath(std.testing.io, "MonPackage/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Foo.Bar
        \\use MonPackage.Class1
        \\func answer() int { return Bar.value() + Class1.value() }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Foo/Bar.sx",
        .data = "func value() int { return 20 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "MonPackage/Package.json",
        .data = "{\"name\":\"MonPackage\",\"version\":\"1.4.1\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "MonPackage/Module/Class1.sx",
        .data = "public func value() int { return 22 }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("Interpreter.zig").invoke(allocator, compilation.ir, 1, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 2), compilation.packages.packages.len);
    try std.testing.expectEqualStrings("MonPackage.Class1", compilation.interfaces[2].name);
}

test "qualified packages share namespaces without sharing ownership" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    const package_names = [_][]const u8{ "Silex", "Silex.Audio", "Silex.Bootstrap", "Silex.Rendering" };
    for (package_names) |name| {
        const module_path = try std.fs.path.join(allocator, &.{ name, "Module" });
        try temporary.dir.createDirPath(std.testing.io, module_path);
        const manifest_path = try std.fs.path.join(allocator, &.{ name, "Package.json" });
        const manifest = try std.fmt.allocPrint(
            allocator,
            "{{\"name\":\"{s}\",\"version\":\"1.0.0\"}}",
            .{name},
        );
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = manifest_path, .data = manifest });
    }
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Silex.Core
        \\use Silex.Audio.Mixer
        \\use Silex.Bootstrap.Start
        \\use Silex.Rendering.Texture
        \\func answer() int { return Core.value() + Mixer.value() + Start.value() + Texture.value() }
        \\func main() {}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex/Module/Core.sx", .data = "public func value() int { return 9 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Audio/Module/Mixer.sx", .data = "public func value() int { return 10 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Bootstrap/Module/Start.sx", .data = "public func value() int { return 11 }" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Silex.Rendering/Module/Texture.sx", .data = "public func value() int { return 12 }" });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const answer = try @import("Interpreter.zig").invoke(allocator, compilation.ir, 0, &.{});
    try std.testing.expectEqual(@as(i64, 42), answer.integer);
    try std.testing.expectEqual(@as(usize, 5), compilation.packages.packages.len);

    try temporary.dir.createDirPath(std.testing.io, "Silex/Module/Rendering");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Silex/Module/Rendering/Texture.sx",
        .data = "public func duplicate() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("multiple source files provide the same module", compiler.diagnostic.?.message);
}

test "enforce public package interfaces and direct dependency visibility" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "A/Module");
    try temporary.dir.createDirPath(std.testing.io, "B/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"dependencies\":{\"A\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Package.json",
        .data = "{\"name\":\"A\",\"version\":\"1.0.0\",\"dependencies\":{\"B\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "A/Module/Api.sx",
        .data = "func hidden() {}\npublic func exposed() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Package.json",
        .data = "{\"name\":\"B\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "B/Module/Private.sx",
        .data = "public func value() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use A.Api\nfunc main() { Api.hidden() }",
    });

    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(
        "function 'A.Api.hidden' is private outside its package",
        compiler.diagnostic.?.message,
    );

    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use B.Private\nfunc main() {}",
    });
    compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("unknown module or declaration 'B.Private'", compiler.diagnostic.?.message);
}
