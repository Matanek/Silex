const std = @import("std");
const Ast = @import("../Ast.zig");
const Boundary = @import("../Boundary.zig");
const CacheBinary = @import("../CacheBinary.zig");
const CompilationCache = @import("../CompilationCache.zig");
const Ir = @import("../Ir.zig");
const Packages = @import("../Packages.zig");
const Source = @import("../Source.zig");
const Types = @import("../Types.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;
const Digest = [std.crypto.hash.Blake3.digest_length]u8;

const FileSymbol = struct { owner: []const u8, path: []const u8 };
const FunctionTypeSymbol = struct { parameters: []const []const u8, result: []const u8 };
const FunctionSymbol = struct { name: []const u8, parameters: []const []const u8 };
const BoundarySymbol = struct {
    provider: []const u8,
    source_name: []const u8,
    parameters: []const []const u8,
    result: []const u8,
};
const Relocation = struct {
    files: []const ?usize,
    structures: []const ?usize,
    enums: []const ?usize,
    function_types: []const ?usize,
    functions: []const ?usize,
    globals: []const ?usize,
    boundaries: []const ?usize,
};
const Context = struct {
    files: []const FileSymbol,
    structures: []const []const u8,
    enums: []const []const u8,
    function_types: []const FunctionTypeSymbol,
    functions: []const FunctionSymbol,
    globals: []const []const u8,
    boundaries: []const BoundarySymbol,
};
const CachedFunction = struct {
    name: []const u8,
    function: Ir.Function,
};
const Artifact = struct { context: Context, functions: []const CachedFunction };

pub const Session = struct {
    allocator: Allocator,
    io: Io,
    graph_digest: Digest,
    target: []const u8,
    packages: Packages.Graph,
    files: []const []const u8,
    program: Ast.Program,
    structures: []const Ir.Structure,
    enums: []const Ir.Enum,
    function_types: []const Ir.FunctionType,
    globals: []const Ir.Global,
    boundaries: []const Boundary.Function,
    generated_keys: []const ?[]const u8,
    loaded: ?Artifact,
    relocation: ?Relocation = null,
    function_hits: usize = 0,
    function_misses: usize = 0,
    relocation_failures: usize = 0,
    functions_stored: usize = 0,

    pub fn init(
        allocator: Allocator,
        io: Io,
        graph_digest: Digest,
        target: []const u8,
        packages: Packages.Graph,
        files: []const []const u8,
        program: Ast.Program,
        structures: []const Ir.Structure,
        enums: []const Ir.Enum,
        function_types: []const Ir.FunctionType,
        globals: []const Ir.Global,
        boundaries: []const Boundary.Function,
        generated_keys: []const ?[]const u8,
    ) !Session {
        const cache_key = CompilationCache.artifactKey("semantic-package-graph-binary-v2", &.{ &graph_digest, target });
        const payload = CompilationCache.load(allocator, io, cache_key, "semantic-package-graph-binary-v2");
        var session: Session = .{
            .allocator = allocator,
            .io = io,
            .graph_digest = graph_digest,
            .target = target,
            .packages = packages,
            .files = files,
            .program = program,
            .structures = structures,
            .enums = enums,
            .function_types = function_types,
            .globals = globals,
            .boundaries = boundaries,
            .generated_keys = generated_keys,
            .loaded = if (payload) |contents| CacheBinary.decode(Artifact, allocator, contents) catch null else null,
        };
        if (session.loaded) |artifact| {
            const current = session.buildContext() catch {
                session.loaded = null;
                return session;
            };
            session.relocation = buildRelocation(allocator, artifact.context, current) catch {
                session.loaded = null;
                return session;
            };
        }
        return session;
    }

    pub fn loadGenerated(self: *Session, key: []const u8, current_name: []const u8) ?Ir.Function {
        const artifact = self.loaded orelse {
            self.function_misses += 1;
            return null;
        };
        if (self.relocation == null) {
            self.function_misses += 1;
            return null;
        }
        for (artifact.functions) |cached| {
            if (!std.mem.eql(u8, cached.name, key)) continue;
            var value = cached.function;
            if (!(relocateFunction(self, artifact.context, &value) catch false)) {
                self.relocation_failures += 1;
                return null;
            }
            value.name = current_name;
            self.function_hits += 1;
            return value;
        }
        self.function_misses += 1;
        return null;
    }

    pub fn storeGenerated(
        self: *Session,
        generated_functions: []const Ir.Function,
        generated_keys: []const ?[]const u8,
    ) void {
        if (generated_functions.len != generated_keys.len) return;
        const context = self.buildContext() catch return;
        var functions: std.ArrayList(CachedFunction) = .empty;
        for (generated_functions, generated_keys) |function, optional_key| {
            const key = optional_key orelse continue;
            if (!knownFunctionReferences(function, self.program, self.generated_keys)) continue;
            functions.append(self.allocator, .{
                .name = key,
                .function = function,
            }) catch return;
        }
        if (functions.items.len == 0) return;
        self.functions_stored = functions.items.len;
        const artifact = Artifact{ .context = context, .functions = functions.items };
        const payload = CacheBinary.encode(self.allocator, artifact) catch return;
        const digest = CompilationCache.artifactKey("semantic-package-graph-binary-v2", &.{ &self.graph_digest, self.target });
        CompilationCache.store(self.allocator, self.io, digest, "semantic-package-graph-binary-v2", payload);
    }

    fn buildContext(self: Session) !Context {
        const files = try self.allocator.alloc(FileSymbol, self.files.len);
        for (self.files, 0..) |file, index| files[index] = try self.fileSymbol(file);
        const structures = try self.allocator.alloc([]const u8, self.structures.len);
        for (self.structures, 0..) |structure, index| structures[index] = structure.name;
        const enums = try self.allocator.alloc([]const u8, self.enums.len);
        for (self.enums, 0..) |enumeration, index| enums[index] = enumeration.name;
        const function_types = try self.allocator.alloc(FunctionTypeSymbol, self.function_types.len);
        for (self.function_types, 0..) |function_type, index| {
            const parameters = try self.allocator.alloc([]const u8, function_type.parameter_types.len);
            for (function_type.parameter_types, 0..) |parameter, parameter_index| {
                parameters[parameter_index] = try stableType(self.allocator, self.structures, self.function_types, parameter, 0);
            }
            function_types[index] = .{
                .parameters = parameters,
                .result = try stableType(self.allocator, self.structures, self.function_types, function_type.return_type, 0),
            };
        }
        const functions = try self.allocator.alloc(FunctionSymbol, self.program.functions.len + self.generated_keys.len);
        for (self.program.functions, 0..) |function, index| {
            const parameters = try self.allocator.alloc([]const u8, function.parameters.len);
            for (function.parameters, 0..) |parameter, parameter_index| {
                parameters[parameter_index] = try stableType(self.allocator, self.structures, self.function_types, parameter.type, 0);
            }
            functions[index] = .{ .name = function.name, .parameters = parameters };
        }
        for (self.generated_keys, self.program.functions.len..) |optional_key, index| {
            functions[index] = .{ .name = optional_key orelse "", .parameters = &.{} };
        }
        const globals = try self.allocator.alloc([]const u8, self.globals.len);
        for (self.globals, 0..) |global, index| globals[index] = global.name;
        const boundaries = try self.allocator.alloc(BoundarySymbol, self.boundaries.len);
        for (self.boundaries, 0..) |boundary, index| {
            const parameters = try self.allocator.alloc([]const u8, boundary.parameters.len);
            for (boundary.parameters, 0..) |parameter, parameter_index| {
                parameters[parameter_index] = try stableType(self.allocator, self.structures, self.function_types, parameter, 0);
            }
            boundaries[index] = .{
                .provider = boundary.provider,
                .source_name = boundary.source_name,
                .parameters = parameters,
                .result = try stableType(self.allocator, self.structures, self.function_types, boundary.return_type, 0),
            };
        }
        return .{
            .files = files,
            .structures = structures,
            .enums = enums,
            .function_types = function_types,
            .functions = functions,
            .globals = globals,
            .boundaries = boundaries,
        };
    }

    fn fileSymbol(self: Session, file: []const u8) !FileSymbol {
        for (self.packages.packages) |package| {
            const relative = std.fs.path.relative(self.allocator, ".", null, package.root, file) catch continue;
            if (std.mem.startsWith(u8, relative, "..")) continue;
            return .{ .owner = package.name orelse "<project>", .path = relative };
        }
        return .{ .owner = "<project>", .path = try self.allocator.dupe(u8, std.fs.path.basename(file)) };
    }
};

fn stableType(
    allocator: Allocator,
    structures: []const Ir.Structure,
    function_types: []const Ir.FunctionType,
    type_value: Types.Type,
    depth: usize,
) ![]const u8 {
    if (depth == 16) return std.fmt.allocPrint(allocator, "raw:{d}", .{@intFromEnum(type_value)});
    if (type_value.optionalChild()) |child| {
        return std.fmt.allocPrint(allocator, "?{s}", .{try stableType(allocator, structures, function_types, child, depth + 1)});
    }
    if (type_value.structureIndex()) |index| {
        if (index >= structures.len) return std.fmt.allocPrint(allocator, "structure:{d}", .{index});
        return std.fmt.allocPrint(allocator, "structure:{s}", .{structures[index].name});
    }
    if (type_value.functionIndex()) |index| {
        if (index >= function_types.len) return std.fmt.allocPrint(allocator, "function:{d}", .{index});
        var output: std.ArrayList(u8) = .empty;
        try output.appendSlice(allocator, "function(");
        for (function_types[index].parameter_types, 0..) |parameter, parameter_index| {
            if (parameter_index != 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, try stableType(allocator, structures, function_types, parameter, depth + 1));
        }
        try output.appendSlice(allocator, ")->");
        try output.appendSlice(allocator, try stableType(allocator, structures, function_types, function_types[index].return_type, depth + 1));
        return output.toOwnedSlice(allocator);
    }
    return std.fmt.allocPrint(allocator, "fundamental:{d}", .{@intFromEnum(type_value)});
}

fn buildRelocation(allocator: Allocator, old: Context, current: Context) !Relocation {
    const files = try allocator.alloc(?usize, old.files.len);
    for (old.files, 0..) |symbol, index| files[index] = uniqueFile(symbol, current.files);
    const structures = try allocator.alloc(?usize, old.structures.len);
    for (old.structures, 0..) |symbol, index| structures[index] = uniqueString(symbol, current.structures);
    const enums = try allocator.alloc(?usize, old.enums.len);
    for (old.enums, 0..) |symbol, index| enums[index] = uniqueString(symbol, current.enums);
    const function_types = try allocator.alloc(?usize, old.function_types.len);
    for (old.function_types, 0..) |symbol, index| function_types[index] = uniqueFunctionType(symbol, current.function_types);
    const functions = try allocator.alloc(?usize, old.functions.len);
    for (old.functions, 0..) |symbol, index| functions[index] = uniqueFunction(symbol, current.functions);
    const globals = try allocator.alloc(?usize, old.globals.len);
    for (old.globals, 0..) |symbol, index| globals[index] = uniqueString(symbol, current.globals);
    const boundaries = try allocator.alloc(?usize, old.boundaries.len);
    for (old.boundaries, 0..) |symbol, index| boundaries[index] = uniqueBoundary(symbol, current.boundaries);
    return .{
        .files = files,
        .structures = structures,
        .enums = enums,
        .function_types = function_types,
        .functions = functions,
        .globals = globals,
        .boundaries = boundaries,
    };
}

fn uniqueFile(symbol: FileSymbol, candidates: []const FileSymbol) ?usize {
    var result: ?usize = null;
    for (candidates, 0..) |candidate, index| {
        if (!std.mem.eql(u8, symbol.owner, candidate.owner) or !std.mem.eql(u8, symbol.path, candidate.path)) continue;
        if (result != null) return null;
        result = index;
    }
    return result;
}

fn uniqueString(symbol: []const u8, candidates: []const []const u8) ?usize {
    var result: ?usize = null;
    for (candidates, 0..) |candidate, index| {
        if (!std.mem.eql(u8, symbol, candidate)) continue;
        if (result != null) return null;
        result = index;
    }
    return result;
}

fn sameStrings(left: []const []const u8, right: []const []const u8) bool {
    if (left.len != right.len) return false;
    for (left, right) |a, b| if (!std.mem.eql(u8, a, b)) return false;
    return true;
}

fn uniqueFunctionType(symbol: FunctionTypeSymbol, candidates: []const FunctionTypeSymbol) ?usize {
    var result: ?usize = null;
    for (candidates, 0..) |candidate, index| {
        if (!sameStrings(symbol.parameters, candidate.parameters) or !std.mem.eql(u8, symbol.result, candidate.result)) continue;
        if (result != null) return null;
        result = index;
    }
    return result;
}

fn uniqueFunction(symbol: FunctionSymbol, candidates: []const FunctionSymbol) ?usize {
    if (symbol.name.len == 0) return null;
    var result: ?usize = null;
    for (candidates, 0..) |candidate, index| {
        if (!std.mem.eql(u8, symbol.name, candidate.name) or !sameStrings(symbol.parameters, candidate.parameters)) continue;
        if (result != null) return null;
        result = index;
    }
    return result;
}

fn uniqueBoundary(symbol: BoundarySymbol, candidates: []const BoundarySymbol) ?usize {
    var result: ?usize = null;
    for (candidates, 0..) |candidate, index| {
        if (!std.mem.eql(u8, symbol.provider, candidate.provider) or
            !std.mem.eql(u8, symbol.source_name, candidate.source_name) or
            !sameStrings(symbol.parameters, candidate.parameters) or
            !std.mem.eql(u8, symbol.result, candidate.result)) continue;
        if (result != null) return null;
        result = index;
    }
    return result;
}

fn relocateFunction(session: *Session, old: Context, function: *Ir.Function) !bool {
    if (!(try relocateOptionalPosition(session, old, &function.source_position))) return false;
    for (@constCast(function.capture_types)) |*type_value| if (!(try relocateType(session, old, type_value))) return false;
    for (@constCast(function.parameter_types)) |*type_value| if (!(try relocateType(session, old, type_value))) return false;
    if (!(try relocateType(session, old, &function.return_type))) return false;
    for (@constCast(function.value_types)) |*type_value| if (!(try relocateType(session, old, type_value))) return false;
    for (@constCast(function.local_types)) |*type_value| if (!(try relocateType(session, old, type_value))) return false;
    for (@constCast(function.blocks)) |*block| {
        for (@constCast(block.instruction_positions)) |*position| if (!(try relocateOptionalPosition(session, old, position))) return false;
        if (!(try relocateOptionalPosition(session, old, &block.terminator_position))) return false;
        switch (block.terminator) {
            .panic => |*value| if (!(try relocatePosition(session, old, &value.position))) return false,
            else => {},
        }
        for (@constCast(block.instructions)) |*instruction| switch (instruction.*) {
            .class_drop => |*value| {
                value.static_type = mapStructure(session, old, value.static_type) orelse return false;
                for (@constCast(value.plans)) |*plan| {
                    plan.structure = mapStructure(session, old, plan.structure) orelse return false;
                    for (@constCast(plan.functions)) |*finalizer| {
                        finalizer.structure = mapStructure(session, old, finalizer.structure) orelse return false;
                        finalizer.function = mapFunction(session, old, finalizer.function) orelse return false;
                    }
                }
            },
            .global_load => |*value| value.global = mapGlobal(session, old, value.global) orelse return false,
            .global_store => |*value| value.global = mapGlobal(session, old, value.global) orelse return false,
            .structure_init => |*value| value.structure = mapStructure(session, old, value.structure) orelse return false,
            .protocol_init => |*value| value.structure = mapStructure(session, old, value.structure) orelse return false,
            .protocol_test => |*value| value.structure = mapStructure(session, old, value.structure) orelse return false,
            .protocol_extract => |*value| value.structure = mapStructure(session, old, value.structure) orelse return false,
            .enum_init => |*value| value.enumeration = mapEnum(session, old, value.enumeration) orelse return false,
            .enum_test => |*value| value.enumeration = mapEnum(session, old, value.enumeration) orelse return false,
            .enum_payload => |*value| value.enumeration = mapEnum(session, old, value.enumeration) orelse return false,
            .enum_raw => |*value| value.enumeration = mapEnum(session, old, value.enumeration) orelse return false,
            .function_reference => |*value| value.function = mapFunction(session, old, value.function) orelse return false,
            .address_load => |*value| if (!(try relocateType(session, old, &value.type))) return false,
            .address_store => |*value| if (!(try relocateType(session, old, &value.type))) return false,
            .reference_field => |*value| value.structure = mapStructure(session, old, value.structure) orelse return false,
            .convert => |*value| {
                if (!(try relocateType(session, old, &value.source)) or !(try relocateType(session, old, &value.target)) or
                    !(try relocatePosition(session, old, &value.position))) return false;
            },
            .call => |*value| value.function = mapFunction(session, old, value.function) orelse return false,
            .boundary_call => |*value| value.function = try mapBoundary(session, old, value.function) orelse return false,
            .boundary_indirect_call => |*value| value.signature = try mapFunctionType(session, old, value.signature) orelse return false,
            .dynamic_call => |*value| {
                value.function = mapFunction(session, old, value.function) orelse return false;
                for (@constCast(value.implementations)) |*implementation| {
                    implementation.structure = mapStructure(session, old, implementation.structure) orelse return false;
                    implementation.function = mapFunction(session, old, implementation.function) orelse return false;
                }
            },
            .assert => |*value| if (!(try relocatePosition(session, old, &value.position))) return false,
            else => {},
        };
    }
    return true;
}

fn relocateType(session: *Session, old: Context, value: *Types.Type) !bool {
    _ = old;
    var base = value.*;
    var optional_depth: usize = 0;
    while (base.optionalChild()) |child| {
        base = child;
        optional_depth += 1;
    }
    const mapped = if (base.structureIndex()) |index|
        Types.Type.structure(mapIndex(session.relocation.?.structures, index) orelse return false)
    else if (base.functionIndex()) |index|
        Types.Type.function(mapIndex(session.relocation.?.function_types, index) orelse return false)
    else if (base.genericInstantiationIndex() != null or base.genericParameterIndex() != null)
        return false
    else
        base;
    value.* = applyOptionalDepth(mapped, optional_depth);
    return true;
}

fn applyOptionalDepth(base: Types.Type, depth: usize) Types.Type {
    var result = base;
    for (0..depth) |_| result = Types.Type.optional(result);
    return result;
}

fn stableTypeFromContext(allocator: Allocator, context: Context, value: Types.Type, depth: usize) ![]const u8 {
    if (depth == 16) return std.fmt.allocPrint(allocator, "raw:{d}", .{@intFromEnum(value)});
    if (value.optionalChild()) |child| return std.fmt.allocPrint(allocator, "?{s}", .{try stableTypeFromContext(allocator, context, child, depth + 1)});
    if (value.structureIndex()) |index| {
        if (index >= context.structures.len) return error.InvalidCache;
        return std.fmt.allocPrint(allocator, "structure:{s}", .{context.structures[index]});
    }
    if (value.functionIndex()) |index| {
        if (index >= context.function_types.len) return error.InvalidCache;
        var output: std.ArrayList(u8) = .empty;
        try output.appendSlice(allocator, "function(");
        for (context.function_types[index].parameters, 0..) |parameter, parameter_index| {
            if (parameter_index != 0) try output.append(allocator, ',');
            try output.appendSlice(allocator, parameter);
        }
        try output.appendSlice(allocator, ")->");
        try output.appendSlice(allocator, context.function_types[index].result);
        return output.toOwnedSlice(allocator);
    }
    return std.fmt.allocPrint(allocator, "fundamental:{d}", .{@intFromEnum(value)});
}

fn fundamentalTypes() []const Types.Type {
    return &.{ .void, .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint, .bool, .float32, .float64, .str, .address };
}

fn mapIndex(mapping: []const ?usize, index: usize) ?usize {
    if (index >= mapping.len) return null;
    return mapping[index];
}

fn mapStructure(session: *Session, old: Context, index: usize) ?usize {
    _ = old;
    return mapIndex(session.relocation.?.structures, index);
}

fn mapEnum(session: *Session, old: Context, index: usize) ?usize {
    _ = old;
    return mapIndex(session.relocation.?.enums, index);
}

fn mapFunction(session: *Session, old: Context, index: usize) ?usize {
    _ = old;
    return mapIndex(session.relocation.?.functions, index);
}

fn mapFunctionType(session: *Session, old: Context, index: usize) !?usize {
    _ = old;
    return mapIndex(session.relocation.?.function_types, index);
}

fn mapGlobal(session: *Session, old: Context, index: usize) ?usize {
    _ = old;
    return mapIndex(session.relocation.?.globals, index);
}

fn mapBoundary(session: *Session, old: Context, index: usize) !?usize {
    _ = old;
    return mapIndex(session.relocation.?.boundaries, index);
}

fn relocateOptionalPosition(session: *Session, old: Context, position: *?Source.Position) !bool {
    if (position.*) |*value| return relocatePosition(session, old, value);
    return true;
}

fn relocatePosition(session: *Session, old: Context, position: *Source.Position) !bool {
    _ = old;
    position.file = mapIndex(session.relocation.?.files, position.file) orelse return false;
    return true;
}

fn knownFunctionReferences(function: Ir.Function, program: Ast.Program, generated_keys: []const ?[]const u8) bool {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .function_reference => |value| if (!stableFunctionReference(program, generated_keys, value.function)) return false,
        .call => |value| if (!stableFunctionReference(program, generated_keys, value.function)) return false,
        .dynamic_call => |value| {
            if (!stableFunctionReference(program, generated_keys, value.function)) return false;
            for (value.implementations) |implementation| if (!stableFunctionReference(program, generated_keys, implementation.function)) return false;
        },
        .class_drop => |value| for (value.plans) |plan| for (plan.functions) |finalizer| {
            if (!stableFunctionReference(program, generated_keys, finalizer.function)) return false;
        },
        else => {},
    };
    return true;
}

fn stableFunctionReference(program: Ast.Program, generated_keys: []const ?[]const u8, index: usize) bool {
    if (index < program.functions.len) {
        const function = program.functions[index];
        return function.owner != 0 and !function.is_anonymous and function.specialization_file == null;
    }
    const generated_index = index - program.functions.len;
    return generated_index < generated_keys.len and generated_keys[generated_index] != null;
}

pub fn generatedKey(
    allocator: Allocator,
    packages: Packages.Graph,
    files: []const []const u8,
    owner: usize,
    position: Source.Position,
    kind: []const u8,
    identity: []const u8,
) ?[]const u8 {
    if (owner == 0 or owner >= packages.packages.len or position.file >= files.len) return null;
    const package = packages.packages[owner];
    const package_name = package.name orelse return null;
    const relative = std.fs.path.relative(allocator, ".", null, package.root, files[position.file]) catch return null;
    defer allocator.free(relative);
    if (std.mem.startsWith(u8, relative, "..")) return null;
    return std.fmt.allocPrint(allocator, "{s}:{s}:{s}:{d}:{s}", .{ package_name, kind, relative, position.offset, identity }) catch null;
}

test "generated package keys are stable and reject project files" {
    const packages = [_]Packages.Package{
        .{
            .name = null,
            .version = null,
            .origin = .project,
            .root = "/workspace/App",
            .module_roots = &.{},
            .inactive_modules = &.{},
            .dependencies = &.{},
        },
        .{
            .name = "Math",
            .version = null,
            .origin = .workspace_link,
            .root = "/workspace/Packages/Math",
            .module_roots = &.{},
            .inactive_modules = &.{},
            .dependencies = &.{},
        },
    };
    const graph: Packages.Graph = .{ .packages = &packages, .explicit = true };
    const files = [_][]const u8{
        "/workspace/App/Main.sx",
        "/workspace/Packages/Math/Module/Vector.sx",
    };
    const position: Source.Position = .{ .file = 1, .offset = 42, .line = 3, .column = 5 };
    const key = generatedKey(std.testing.allocator, graph, &files, 1, position, "method", "Math.Vector") orelse return error.TestUnexpectedResult;
    defer std.testing.allocator.free(key);
    try std.testing.expectEqualStrings("Math:method:Module/Vector.sx:42:Math.Vector", key);
    try std.testing.expect(generatedKey(std.testing.allocator, graph, &files, 0, position, "method", "App") == null);
    try std.testing.expect(generatedKey(std.testing.allocator, graph, &files, 1, .{ .file = 0, .offset = 1, .line = 1, .column = 1 }, "method", "App") == null);
}

test "only stable package and planned generated function references are cacheable" {
    const position: Source.Position = .{ .offset = 0, .line = 1, .column = 1 };
    const functions = [_]Ast.Function{
        .{ .owner = 1, .position = position, .name_position = position, .name = "Math.work", .parameters = &.{}, .return_type = .void, .statements = &.{} },
        .{ .owner = 0, .position = position, .name_position = position, .name = "main", .parameters = &.{}, .return_type = .void, .statements = &.{} },
    };
    const program: Ast.Program = .{ .functions = &functions };
    const generated = [_]?[]const u8{ "Math:method", null };
    try std.testing.expect(stableFunctionReference(program, &generated, 0));
    try std.testing.expect(!stableFunctionReference(program, &generated, 1));
    try std.testing.expect(stableFunctionReference(program, &generated, 2));
    try std.testing.expect(!stableFunctionReference(program, &generated, 3));
    try std.testing.expect(!stableFunctionReference(program, &generated, 4));
}
