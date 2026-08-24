const std = @import("std");
const Ast = @import("../Ast.zig");
const Arguments = @import("Arguments.zig");
const NamedCalls = @import("NamedCalls.zig");
const Boundary = @import("../Boundary.zig");
const Ir = @import("../Ir.zig");
const MainBoundary = @import("../MainBoundary.zig");
const InjectedSystems = @import("InjectedSystems.zig");
const Packages = @import("../Packages.zig");
const Numeric = @import("../Numeric.zig");
const Source = @import("../Source.zig");
const Mutation = @import("Mutation.zig");
const Moves = @import("Moves.zig");
const Copies = @import("Copies.zig");
const Cascades = @import("Cascades.zig");
const Tuples = @import("Tuples.zig");
const Borrowing = @import("Borrowing.zig");
const Bindings = @import("Bindings.zig");
const MutableReferences = @import("MutableReferences.zig");
const Resources = @import("Resources.zig");
const Optionals = @import("Optionals.zig");
const Constructors = @import("Constructors.zig");
const Collections = @import("Collections.zig");
const Callbacks = @import("Callbacks.zig");
const Model = @import("Model.zig");
const Methods = @import("Methods.zig");
const BoundMethods = @import("BoundMethods.zig");
const Control = @import("Control.zig");
const Enums = @import("Enums.zig");
const Matches = @import("Matches.zig");
const MapError = @import("MapError.zig");
const Support = @import("Support.zig");
const Try = @import("Try.zig");
const Visibility = @import("Visibility.zig");
const Declarations = @import("Declarations.zig");
const Inheritance = @import("Inheritance.zig");
const Interop = @import("Interop.zig");
const EmbeddedFiles = @import("../EmbeddedFiles.zig");
const Reflection = @import("Reflection.zig");
const StaticMembers = @import("StaticMembers.zig");
const StaticInitialization = @import("StaticInitialization.zig");
const Protocols = @import("Protocols.zig");
const Conversions = @import("Conversions.zig");
const GenericSyntax = @import("../Parser/Generics.zig");
const Types = @import("../Types.zig");
const Target = @import("../Target.zig").Target;
const Allocator = std.mem.Allocator;
const AnalyzeError = Source.Error || Allocator.Error;
pub const Binding = Model.Binding;
pub const TypedValue = Model.TypedValue;
pub const BlockBuilder = Model.BlockBuilder;
pub const FunctionBuilder = Model.FunctionBuilder;
pub const AnonymousCapture = struct {
    name: []const u8,
    type: Types.Type,
    mutable: bool,
    borrowed_root: ?[]const u8,
    borrowed_mode: Ast.Parameter.Mode,
};
pub const Analyzer = struct {
    allocator: Allocator,
    program: Ast.Program = undefined,
    structures: []const Ir.Structure = &.{},
    globals: []const Ir.Global = &.{},
    external_functions: []const Boundary.Function = &.{},
    enums: []const Ir.Enum = &.{},
    method_mutability: []const bool = &.{},
    default_expansions: std.ArrayList(*const Ast.Expression) = .empty,
    diagnostic: ?Source.Diagnostic = null,
    member_context: ?usize = null,
    constructor_context: ?usize = null,
    extension_context: bool = false,
    specialization_file: ?usize = null,
    module_context: ?[]const u8 = null,
    module_scope_roots: []const []const u8 = &.{},
    owner_context: ?usize = null,
    anonymous_captures: []?[]const AnonymousCapture = &.{},
    bound_methods: std.ArrayList(Callbacks.BoundMethod) = .empty,
    function_context: ?Ast.Function = null,
    static_initialization_limit: ?usize = null,
    target: ?Target = null,
    packages: ?Packages.Graph = null,
    io: ?std.Io = null,
    source_files: []const []const u8 = &.{},
    shadercross_path: ?[]const u8 = null,
    shader_files: std.ArrayList([]const u8) = .empty,
    embedded_files: std.ArrayList([]const u8) = .empty,
    pub fn init(allocator: Allocator) Analyzer {
        return .{ .allocator = allocator };
    }
    pub fn analyze(self: *Analyzer, program: Ast.Program) AnalyzeError!Ir.Program {
        return self.analyzeProgram(program, true);
    }
    pub fn analyzeUnit(self: *Analyzer, program: Ast.Program) AnalyzeError!Ir.Program {
        return self.analyzeProgram(program, false);
    }
    fn analyzeProgram(self: *Analyzer, program: Ast.Program, require_entry: bool) AnalyzeError!Ir.Program {
        self.program = program;
        self.diagnostic = null;
        self.bound_methods.clearRetainingCapacity();
        self.anonymous_captures = try self.allocator.alloc(?[]const AnonymousCapture, program.functions.len);
        @memset(self.anonymous_captures, null);
        self.structures = try Declarations.prepareStructures(self);
        const function_types = try Callbacks.prepare(self);
        self.globals = try StaticMembers.prepare(self);
        self.external_functions = try Interop.prepare(self);
        self.enums = try Enums.prepare(self);
        self.method_mutability = try Methods.inferMutability(self.allocator, self.program);
        self.structures = try Methods.extendStructures(self.allocator, self.program, self.structures, self.method_mutability);
        try Inheritance.validateOverrides(self);
        try Protocols.validate(self);
        try self.validateDeclarations(require_entry);
        try self.validateParameterDefaults();
        const source_functions = try self.allocator.alloc(?Ir.Function, program.functions.len);
        @memset(source_functions, null);
        for (program.functions, 0..) |function, function_id| {
            if (!function.is_anonymous) source_functions[function_id] = try self.analyzeFunction(function_id, function);
        }
        var generated_functions: std.ArrayList(Ir.Function) = .empty;
        for (program.structures, 0..) |structure, structure_index| {
            if (structure.is_protocol) continue;
            for (structure.constructors, 0..) |constructor, constructor_index| {
                try generated_functions.append(
                    self.allocator,
                    try Constructors.analyze(self, structure_index, constructor_index, constructor),
                );
            }
        }
        for (program.structures, 0..) |structure, structure_index| {
            if (structure.is_protocol) continue;
            for (structure.methods, 0..) |method, method_index| {
                try generated_functions.append(
                    self.allocator,
                    try Methods.analyze(self, structure_index, method_index, method),
                );
            }
        }
        for (program.structures) |structure| if (structure.drop) |drop| {
            const nominal = self.structureIndex(structure.name) orelse return error.InvalidSource;
            try generated_functions.append(self.allocator, try Resources.analyzeDrop(self, nominal, structure, drop));
        };
        for (program.structures) |structure| if (structure.is_class and !structure.is_static) {
            const nominal = self.structureIndex(structure.name) orelse return error.InvalidSource;
            try generated_functions.append(self.allocator, try Resources.analyzeClassFields(self, nominal, structure));
        };
        for (self.bound_methods.items) |bound| {
            try generated_functions.append(self.allocator, try BoundMethods.analyze(self, bound));
        }
        var remaining = program.functions.len;
        while (remaining != 0) {
            var progressed = false;
            for (program.functions, 0..) |function, function_id| {
                if (!function.is_anonymous or source_functions[function_id] != null or self.anonymous_captures[function_id] == null) continue;
                source_functions[function_id] = try self.analyzeFunction(function_id, function);
                progressed = true;
            }
            if (!progressed) break;
            remaining -= 1;
        }
        var functions: std.ArrayList(Ir.Function) = .empty;
        for (program.functions, 0..) |function, function_id| {
            if (source_functions[function_id] == null) {
                if (!function.is_anonymous) return error.InvalidSource;
                self.anonymous_captures[function_id] = &.{};
                source_functions[function_id] = try self.analyzeFunction(function_id, function);
            }
            try functions.append(self.allocator, source_functions[function_id].?);
        }
        try functions.appendSlice(self.allocator, generated_functions.items);
        if (try StaticInitialization.analyze(self)) |initializer| {
            const initializer_id = functions.items.len;
            try functions.append(self.allocator, initializer);
            try StaticInitialization.attachToEntries(self, &functions, initializer_id);
        }
        return .{
            .globals = self.globals,
            .structures = self.structures,
            .enums = self.enums,
            .function_types = function_types,
            .functions = try functions.toOwnedSlice(self.allocator),
        };
    }

    fn validateDeclarations(self: *Analyzer, require_entry: bool) AnalyzeError!void {
        var main: ?Ast.Function = null;
        for (self.program.functions) |function| {
            if (std.mem.eql(u8, function.name, "main")) {
                if (function.is_public) return self.fail(function.name_position, "'main' cannot be public");
                if (main != null) return self.fail(function.name_position, "'main' cannot be overloaded");
                main = function;
            }
            for (function.parameters, 0..) |parameter, index| {
                if (self.isAccessPattern(parameter.type)) {
                    return self.fail(parameter.position, "borrowed access tuples are non-runtime generic patterns");
                }
                try Resources.validateParameter(self, parameter);
                for (function.parameters[0..index]) |previous| {
                    if (std.mem.eql(u8, parameter.name, previous.name)) {
                        const message = try std.fmt.allocPrint(self.allocator, "parameter '{s}' is already declared", .{parameter.name});
                        return self.fail(parameter.position, message);
                    }
                }
            }
            if (self.isAccessPattern(function.return_type)) {
                return self.fail(function.name_position, "borrowed access tuples cannot be returned as values");
            }
            if (function.return_mode != .value) {
                const provenance = function.return_provenance orelse return self.fail(function.name_position, "borrowed return provenance is ambiguous; qualify it with a parameter name");
                var compatible = false;
                for (function.parameters) |parameter| if (std.mem.eql(u8, parameter.name, provenance)) {
                    compatible = if (function.return_mode == .read) parameter.mode != .value else parameter.mode == .mutable;
                    break;
                };
                if (!compatible) return self.fail(function.name_position, "borrowed return provenance must name a compatible borrowed parameter");
            }
            try Resources.validateReturn(self, function);
        }
        for (self.program.functions, 0..) |function, index| {
            for (self.program.functions[0..index]) |previous| {
                if (!std.mem.eql(u8, function.name, previous.name)) continue;
                if (Support.effectiveSignatureCollision(function.parameters, previous.parameters)) |arity| {
                    if (Support.sameParameterTypes(function.parameters, previous.parameters) and
                        Support.requiredParameterCount(function.parameters) == function.parameters.len and
                        Support.requiredParameterCount(previous.parameters) == previous.parameters.len)
                    {
                        const message = try std.fmt.allocPrint(self.allocator, "function '{s}' with these parameter types is already declared", .{function.name});
                        return self.fail(function.name_position, message);
                    }
                    const signature = try self.effectiveSignature(function.name, function.parameters, arity);
                    const message = try std.fmt.allocPrint(self.allocator, "function '{s}' is already exposed by the declaration at {d}:{d}", .{ signature, previous.name_position.line, previous.name_position.column });
                    return self.fail(function.name_position, message);
                }
                if (Arguments.arityRangesOverlap(function.parameters, previous.parameters) and
                    !Arguments.labelsCompatible(function.parameters, previous.parameters))
                {
                    const message = try std.fmt.allocPrint(self.allocator, "overloads of function '{s}' must use the same parameter labels", .{function.name});
                    return self.fail(function.name_position, message);
                }
            }
        }
        for (self.program.structures) |structure| {
            if (structure.drop) |drop| try Resources.validateDrop(self, drop);
            for (structure.constructors, 0..) |constructor, index| {
                for (constructor.parameters, 0..) |parameter, parameter_index| {
                    if (self.isAccessPattern(parameter.type)) {
                        return self.fail(parameter.position, "borrowed access tuples are non-runtime generic patterns");
                    }
                    try Resources.validateParameter(self, parameter);
                    for (constructor.parameters[0..parameter_index]) |previous| {
                        if (std.mem.eql(u8, parameter.name, previous.name)) {
                            const message = try std.fmt.allocPrint(self.allocator, "parameter '{s}' is already declared", .{parameter.name});
                            return self.fail(parameter.position, message);
                        }
                    }
                }
                for (structure.constructors[0..index]) |previous| {
                    if (Support.effectiveSignatureCollision(constructor.parameters, previous.parameters)) |arity| {
                        if (Support.sameParameterTypes(constructor.parameters, previous.parameters) and
                            Support.requiredParameterCount(constructor.parameters) == constructor.parameters.len and
                            Support.requiredParameterCount(previous.parameters) == previous.parameters.len)
                        {
                            const message = try std.fmt.allocPrint(self.allocator, "constructor for '{s}' with these parameter types is already declared", .{structure.name});
                            return self.fail(constructor.position, message);
                        }
                        const signature = try self.effectiveSignature("init", constructor.parameters, arity);
                        const message = try std.fmt.allocPrint(self.allocator, "constructor '{s}' is already exposed by the declaration at {d}:{d}", .{ signature, previous.position.line, previous.position.column });
                        return self.fail(constructor.position, message);
                    }
                    if (Arguments.arityRangesOverlap(constructor.parameters, previous.parameters) and
                        !Arguments.labelsCompatible(constructor.parameters, previous.parameters))
                    {
                        const message = try std.fmt.allocPrint(self.allocator, "constructors of '{s}' must use the same parameter labels", .{structure.name});
                        return self.fail(constructor.position, message);
                    }
                }
            }
            for (structure.methods, 0..) |method, index| {
                for (method.parameters, 0..) |parameter, parameter_index| {
                    if (self.isAccessPattern(parameter.type)) {
                        return self.fail(parameter.position, "borrowed access tuples are non-runtime generic patterns");
                    }
                    try Resources.validateParameter(self, parameter);
                    for (method.parameters[0..parameter_index]) |previous| {
                        if (std.mem.eql(u8, parameter.name, previous.name)) {
                            const message = try std.fmt.allocPrint(self.allocator, "parameter '{s}' is already declared", .{parameter.name});
                            return self.fail(parameter.position, message);
                        }
                    }
                }
                if (self.isAccessPattern(method.return_type)) {
                    return self.fail(method.name_position, "borrowed access tuples cannot be returned as values");
                }
                for (structure.methods[0..index]) |previous| {
                    if (method.is_static != previous.is_static) continue;
                    if (!std.mem.eql(u8, method.name, previous.name)) continue;
                    if (Support.effectiveSignatureCollision(method.parameters, previous.parameters)) |arity| {
                        if (Support.sameParameterTypes(method.parameters, previous.parameters) and
                            Support.requiredParameterCount(method.parameters) == method.parameters.len and
                            Support.requiredParameterCount(previous.parameters) == previous.parameters.len)
                        {
                            const message = try std.fmt.allocPrint(self.allocator, "method '{s}' with these parameter types is already declared in '{s}'", .{ method.name, structure.name });
                            return self.fail(method.name_position, message);
                        }
                        // Iterator discovery intentionally distinguishes the
                        // observable result contract of overlapping `next`
                        // overloads. Keep those declarations available so a
                        // `for` source can select the unique `T?` form or
                        // diagnose iterator ambiguity at the use site.
                        if (std.mem.eql(u8, method.name, "next")) continue;
                        const signature = try self.effectiveSignature(method.name, method.parameters, arity);
                        const message = try std.fmt.allocPrint(self.allocator, "method '{s}' is already exposed in '{s}' by the declaration at {d}:{d}", .{ signature, structure.name, previous.name_position.line, previous.name_position.column });
                        return self.fail(method.name_position, message);
                    }
                    if (Arguments.arityRangesOverlap(method.parameters, previous.parameters) and
                        !Arguments.labelsCompatible(method.parameters, previous.parameters))
                    {
                        const message = try std.fmt.allocPrint(self.allocator, "overloads of method '{s}' in '{s}' must use the same parameter labels", .{ method.name, structure.name });
                        return self.fail(method.name_position, message);
                    }
                }
            }
        }
        const entry = main orelse {
            if (require_entry) return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, "missing 'main' function");
            return;
        };
        if (entry.parameters.len != 0) return self.fail(entry.name_position, "'main' must have no parameters");
        if (entry.return_type != .void and !MainBoundary.accepts(self.enums, entry.return_type)) return self.fail(entry.name_position, "'main' must return 'void' or 'Result<void,str>'");
    }

    fn isAccessPattern(self: *Analyzer, type_value: Ast.Type) bool {
        const index = type_value.structureIndex() orelse return false;
        if (index >= self.program.structures.len) return false;
        const structure = self.program.structures[index];
        if (!structure.is_tuple) return false;
        for (structure.fields) |field| if (field.access_mode != .value) return true;
        return false;
    }

    fn validateParameterDefaults(self: *Analyzer) AnalyzeError!void {
        for (self.program.functions) |function| try self.validateDefaults(function.parameters);
        for (self.program.structures) |structure| {
            for (structure.constructors) |constructor| try self.validateDefaults(constructor.parameters);
            for (structure.methods) |method| try self.validateDefaults(method.parameters);
        }
    }

    fn validateDefaults(self: *Analyzer, parameters: []const Ast.Parameter) AnalyzeError!void {
        var builder: FunctionBuilder = .{};
        try builder.blocks.append(self.allocator, .{});
        for (parameters) |parameter| {
            if (parameter.mode == .mutable and parameter.default != null) {
                return self.fail(parameter.position, "a mutable-reference parameter cannot have a default value");
            }
            if (parameter.default == null) continue;
            _ = try self.analyzeParameterDefault(&builder, parameter);
        }
    }

    fn effectiveSignature(
        self: *Analyzer,
        name: []const u8,
        parameters: []const Ast.Parameter,
        arity: usize,
    ) Allocator.Error![]const u8 {
        var signature = try std.fmt.allocPrint(self.allocator, "{s}(", .{name});
        for (parameters[0..arity], 0..) |parameter, index| {
            signature = try std.fmt.allocPrint(
                self.allocator,
                "{s}{s}{s}",
                .{ signature, if (index == 0) "" else ", ", self.typeName(parameter.type) },
            );
        }
        return std.fmt.allocPrint(self.allocator, "{s})", .{signature});
    }

    fn analyzeFunction(self: *Analyzer, function_id: Ir.FunctionId, function: Ast.Function) AnalyzeError!Ir.Function {
        if (function.intrinsic) |intrinsic| switch (intrinsic) {
            .system_adapter => |adapter| return InjectedSystems.analyze(self, function, adapter),
            else => {},
        };
        const previous_owner_context = self.owner_context;
        self.owner_context = function.owner;
        defer self.owner_context = previous_owner_context;
        const previous_module_context = self.module_context;
        self.module_context = if (std.mem.lastIndexOfScalar(u8, function.name, '.')) |separator|
            function.name[0..separator]
        else
            null;
        defer self.module_context = previous_module_context;
        const previous_specialization_file = self.specialization_file;
        self.specialization_file = function.specialization_file;
        defer self.specialization_file = previous_specialization_file;
        const previous_function_context = self.function_context;
        self.function_context = function;
        defer self.function_context = previous_function_context;
        var builder: FunctionBuilder = .{ .return_type = function.return_type };
        try builder.blocks.append(self.allocator, .{});
        const captures = if (function.is_anonymous)
            self.anonymous_captures[function_id] orelse &.{}
        else
            &.{};
        const capture_types = try self.allocator.alloc(Types.Type, captures.len);
        for (captures, 0..) |capture, capture_index| {
            capture_types[capture_index] = .address;
            try builder.value_types.append(self.allocator, .address);
            try builder.bindings.append(self.allocator, .{
                .name = capture.name,
                .type = capture.type,
                .reference = capture_index,
                .mutable = capture.mutable,
                .borrowed_root = capture.borrowed_root,
                .borrowed_mode = capture.borrowed_mode,
            });
        }
        var parameter_types: std.ArrayList(Types.Type) = .empty;
        for (function.parameters, captures.len..) |parameter, value| {
            try parameter_types.append(self.allocator, try Collections.bindFunctionParameter(self, &builder, parameter, value));
        }

        const ends_with_return = try self.analyzeStatements(&builder, function, function.statements);
        if (function.return_type == .void) {
            if (!ends_with_return) {
                try Resources.emitActiveDrops(self, &builder, 0);
                self.terminate(&builder, .return_void);
            }
        } else if (!ends_with_return) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "function '{s}' must return '{s}' on every path",
                .{ function.name, self.typeName(function.return_type) },
            );
            return self.fail(function.name_position, message);
        }

        var blocks: std.ArrayList(Ir.Block) = .empty;
        for (builder.blocks.items) |*block| {
            try blocks.append(self.allocator, .{
                .instructions = try block.instructions.toOwnedSlice(self.allocator),
                .terminator = block.terminator orelse return error.InvalidSource,
            });
        }
        const owned_blocks = try blocks.toOwnedSlice(self.allocator);
        return .{
            .name = function.name,
            .capture_types = capture_types,
            .parameter_types = try parameter_types.toOwnedSlice(self.allocator),
            .return_type = Collections.loweredBorrowType(self.structures, function.return_mode, function.return_type),
            .value_types = try builder.value_types.toOwnedSlice(self.allocator),
            .local_types = try builder.local_types.toOwnedSlice(self.allocator),
            .blocks = owned_blocks,
        };
    }

    pub fn prepareAnonymousCaptures(
        self: *Analyzer,
        builder: *FunctionBuilder,
        function_id: Ir.FunctionId,
    ) AnalyzeError![]const Ir.ValueId {
        if (function_id >= self.program.functions.len or !self.program.functions[function_id].is_anonymous) return &.{};
        var infos: std.ArrayList(AnonymousCapture) = .empty;
        var values: std.ArrayList(Ir.ValueId) = .empty;
        for (builder.bindings.items) |binding| {
            if (!binding.available or !functionMentionsName(self.program, self.program.functions[function_id], binding.name)) continue;
            const reference = if (binding.reference) |existing|
                existing
            else if (binding.local) |local| reference: {
                const created = try self.newValue(builder, .address);
                try self.emit(builder, .{ .local_address = .{ .result = created, .local = local } });
                break :reference created;
            } else if (binding.value) |value| reference: {
                const local = builder.local_types.items.len;
                try builder.local_types.append(self.allocator, binding.type);
                try self.emit(builder, .{ .local_store = .{ .local = local, .operand = value } });
                const created = try self.newValue(builder, .address);
                try self.emit(builder, .{ .local_address = .{ .result = created, .local = local } });
                break :reference created;
            } else continue;
            try infos.append(self.allocator, .{
                .name = binding.name,
                .type = binding.type,
                .mutable = binding.mutable,
                .borrowed_root = binding.borrowed_root,
                .borrowed_mode = binding.borrowed_mode,
            });
            try values.append(self.allocator, reference);
        }
        const capture_infos = try infos.toOwnedSlice(self.allocator);
        if (self.anonymous_captures[function_id]) |existing| {
            if (existing.len != capture_infos.len) return self.fail(self.program.functions[function_id].position, "anonymous function has inconsistent lexical captures");
        } else self.anonymous_captures[function_id] = capture_infos;
        return values.toOwnedSlice(self.allocator);
    }

    pub fn analyzeStatements(self: *Analyzer, builder: *FunctionBuilder, function: Ast.Function, statements: []const Ast.Statement) AnalyzeError!bool {
        for (statements) |statement| {
            if (try self.analyzeStatement(builder, function, statement)) return true;
        }
        return false;
    }

    pub fn analyzeParameterDefault(
        self: *Analyzer,
        builder: *FunctionBuilder,
        parameter: Ast.Parameter,
    ) AnalyzeError!TypedValue {
        const expression = parameter.default orelse return error.InvalidSource;
        for (self.default_expansions.items) |active| {
            if (active == expression) {
                return self.fail(expression.position, "default parameter expansion is recursive");
            }
        }
        try self.default_expansions.append(self.allocator, expression);
        defer _ = self.default_expansions.pop();
        const caller_bindings = builder.bindings;
        const caller_return_type = builder.return_type;
        builder.bindings = .empty;
        builder.return_type = null;
        defer {
            builder.bindings = caller_bindings;
            builder.return_type = caller_return_type;
        }
        var value = try self.analyzeExpressionExpected(
            builder,
            expression,
            Optionals.expectedContext(parameter.type, expression),
        );
        if (value.type != parameter.type and self.canImplicitlyConvert(value.type, parameter.type)) {
            value = try self.coerce(builder, value, parameter.type, expression.position);
        }
        if (value.type != parameter.type) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "default for parameter '{s}' expects '{s}', found '{s}'",
                .{ parameter.name, self.typeName(parameter.type), self.typeName(value.type) },
            );
            return self.fail(expression.position, message);
        }
        return value;
    }

    fn analyzeStatement(self: *Analyzer, builder: *FunctionBuilder, function: Ast.Function, statement: Ast.Statement) AnalyzeError!bool {
        return switch (statement) {
            .variable_declaration => |declaration| variable: {
                if (declaration.destructuring.len != 0)
                    try Tuples.analyzeDestructuring(self, builder, declaration)
                else
                    try Bindings.analyzeVariable(self, builder, declaration);
                break :variable false;
            },
            .assignment_statement => |assignment| assignment_statement: {
                try Mutation.analyzeAssignment(self, builder, assignment);
                break :assignment_statement false;
            },
            .return_statement => |return_statement| return_value: {
                try Bindings.analyzeReturn(self, builder, function, return_statement);
                break :return_value true;
            },
            .expression_statement => |expression| switch (expression.value) {
                .call => |call| {
                    if (try self.analyzeCall(builder, call)) |value| if (value.transferred and (Resources.needsDrop(self, value.type) or Resources.containsClass(self, value.type)))
                        try Resources.emitDrop(self, builder, value.type, value.value);
                    return false;
                },
                .match_expression => |match_value| return Matches.analyzeStatement(self, builder, function, match_value),
                .cascade => {
                    const value = try self.analyzeExpression(builder, expression);
                    if (value.transferred and (Resources.needsDrop(self, value.type) or Resources.containsClass(self, value.type))) {
                        try Resources.emitDrop(self, builder, value.type, value.value);
                    }
                    return false;
                },
                .unary => |unary| if (unary.operator == .propagate) {
                    try Try.analyzeStatement(self, builder, unary);
                    return false;
                } else unreachable,
                else => unreachable,
            },
            .print_statement => |print_statement| effect: {
                try self.analyzePrint(builder, print_statement);
                break :effect false;
            },
            .assert_statement => |assert_statement| effect: {
                try self.analyzeAssert(builder, assert_statement);
                break :effect false;
            },
            .panic_statement => |panic_statement| fatal: {
                try self.analyzePanic(builder, panic_statement);
                break :fatal true;
            },
            .if_statement => |conditional| Control.analyzeIf(self, builder, function, conditional),
            .while_statement => |loop| Control.analyzeWhile(self, builder, function, loop),
            .for_statement => |loop| Control.analyzeFor(self, builder, function, loop),
            .mutex_statement => |mutex| Control.analyzeMutex(self, builder, function, mutex),
            .break_statement => |position| Control.analyzeLoopControl(self, builder, position, false),
            .continue_statement => |position| Control.analyzeLoopControl(self, builder, position, true),
        };
    }

    pub fn analyzeExpression(self: *Analyzer, builder: *FunctionBuilder, expression: *const Ast.Expression) AnalyzeError!TypedValue {
        return self.analyzeExpressionExpected(builder, expression, null);
    }

    pub fn analyzeExpressionExpected(
        self: *Analyzer,
        builder: *FunctionBuilder,
        expression: *const Ast.Expression,
        expected: ?Types.Type,
    ) AnalyzeError!TypedValue {
        const value = try switch (expression.value) {
            .integer => |lexeme| integer: {
                const target = if (expected != null and expected.?.isInteger()) expected.? else Types.Type.int;
                break :integer try self.emitIntegerLiteral(builder, lexeme, false, target, expression.position);
            },
            .floating => |lexeme| floating: {
                const target = if (expected != null and expected.?.isFloat()) expected.? else Types.Type.float32;
                break :floating try self.emitFloatingLiteral(builder, lexeme, target, expression.position);
            },
            .boolean => |value| self.emitBool(builder, value),
            .null_value => Optionals.analyzeNull(self, builder, expected, expression.position),
            .string => |value| self.emitString(builder, value),
            .interpolated_string => |value| self.analyzeInterpolatedString(builder, value),
            .identifier => |name| identifier: {
                if (Support.findBinding(builder.bindings.items, name) != null) {
                    break :identifier Borrowing.analyzeIdentifier(self, builder, expression.position, name);
                }
                if (expected) |target| {
                    break :identifier (try Callbacks.reference(self, builder, expression.position, name, target)) orelse
                        Borrowing.analyzeIdentifier(self, builder, expression.position, name);
                }
                break :identifier (try Callbacks.inferredReference(self, builder, expression.position, name)) orelse
                    Borrowing.analyzeIdentifier(self, builder, expression.position, name);
            },
            .generic_reference => self.fail(expression.position, "generic type reference was not specialized"),
            .field_access => |access| function_reference: {
                if (try Callbacks.memberReference(self, builder, access, expected)) |reference| {
                    break :function_reference reference;
                }
                if (access.base.value == .identifier and Support.findBinding(builder.bindings.items, access.base.value.identifier) != null) {
                    break :function_reference try self.analyzeFieldAccess(builder, access);
                }
                if (expected) |target| if (target.functionIndex() != null) {
                    if (try GenericSyntax.qualifiedName(self.allocator, expression)) |name| {
                        if (try Callbacks.reference(self, builder, expression.position, name, target)) |reference| break :function_reference reference;
                    }
                };
                break :function_reference try self.analyzeFieldAccess(builder, access);
            },
            .call => |call| (try self.analyzeCall(builder, call)) orelse {
                const message = try std.fmt.allocPrint(self.allocator, "function '{s}' returns 'void' and cannot be used as a value", .{call.name});
                return self.fail(call.name_position, message);
            },
            .cascade => |cascade| Cascades.analyze(self, builder, cascade, expected),
            .unary => |unary| self.analyzeUnary(builder, unary, expected),
            .binary => |binary| self.analyzeBinary(builder, binary, expected),
            .conversion => |conversion| self.analyzeConversion(builder, conversion),
            .string_count => |operand| self.analyzeStringCount(builder, operand),
            .sequence_literal => |literal| Collections.analyzeLiteral(self, builder, literal, expected, expression.position),
            .tuple_literal => |literal| Tuples.analyzeLiteral(self, builder, literal, expected, expression.position),
            .index_access => |access| Collections.analyzeIndex(self, builder, access),
            .slice_access => |access| Collections.analyzeSlice(self, builder, access, expected),
            .match_expression => |match_value| Matches.analyze(self, builder, match_value),
        };
        if (expected) |target| return self.coerce(builder, value, target, expression.position);
        return value;
    }

    fn analyzeUnary(
        self: *Analyzer,
        builder: *FunctionBuilder,
        unary: Ast.Expression.Unary,
        expected: ?Types.Type,
    ) AnalyzeError!TypedValue {
        if (unary.operator == .propagate) return Try.analyzeValue(self, builder, unary);
        if (unary.operator == .move) return Moves.analyze(self, builder, unary);
        if (unary.operator == .copy) return Copies.analyze(self, builder, unary);
        if (unary.operator == .borrow_read or unary.operator == .borrow_mutable) return Collections.analyzeView(self, builder, unary);
        if (unary.operator == .force_optional) return self.analyzeForcedOptional(builder, unary);
        if (unary.operator == .logical_not) {
            const operand = try self.analyzeExpressionExpected(builder, unary.operand, .bool);
            if (operand.type != .bool) {
                const message = try std.fmt.allocPrint(self.allocator, "operator '!' expects 'bool', found '{s}'", .{operand.type.name()});
                return self.fail(unary.operator_position, message);
            }
            const false_value = try self.emitBool(builder, false);
            const result = try self.newValue(builder, .bool);
            try self.emit(builder, .{ .binary = .{
                .result = result,
                .operator = .equal,
                .left = operand.value,
                .right = false_value.value,
            } });
            return .{ .type = .bool, .value = result };
        }
        switch (unary.operand.value) {
            .integer => |lexeme| {
                const target = if (expected != null and expected.?.isInteger()) expected.? else Types.Type.int;
                if (target.isSignedInteger()) return self.emitIntegerLiteral(builder, lexeme, true, target, unary.operator_position);
            },
            else => {},
        }

        const operand = try self.analyzeExpressionExpected(builder, unary.operand, if (expected != null and expected.?.isNumeric()) expected else null);
        if (!operand.type.isNumeric()) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "operator '-' expects a numeric value, found '{s}'",
                .{operand.type.name()},
            );
            return self.fail(unary.operator_position, message);
        }
        const result = try self.newValue(builder, operand.type);
        try self.emit(builder, .{ .unary = .{
            .result = result,
            .operator = .negate,
            .operand = operand.value,
        } });
        return .{ .type = operand.type, .value = result };
    }

    fn analyzeForcedOptional(self: *Analyzer, builder: *FunctionBuilder, unary: Ast.Expression.Unary) AnalyzeError!TypedValue {
        const operand = try self.analyzeExpression(builder, unary.operand);
        const child = operand.type.optionalChild() orelse {
            const message = try std.fmt.allocPrint(self.allocator, "postfix '!' expects an optional value, found '{s}'", .{self.typeName(operand.type)});
            return self.fail(unary.operator_position, message);
        };
        const presence = try Optionals.emitPresence(self, builder, operand);
        const present = try self.newBlock(builder);
        const absent = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = presence.value, .then_block = present, .else_block = absent } });
        builder.current_block = absent;
        const message = try self.emitString(builder, "forced optional extraction failed");
        self.terminate(builder, .{ .panic = .{ .message = message.value, .position = unary.operator_position } });
        builder.current_block = present;
        const result = try Optionals.unwrap(self, builder, operand);
        return .{
            .type = child,
            .value = result.value,
            .transferred = result.transferred,
            .borrowed_root = result.borrowed_root,
            .borrowed_mode = result.borrowed_mode,
            .lexical_captures = result.lexical_captures,
            .lexical_borrows = result.lexical_borrows,
        };
    }

    fn analyzeBinary(
        self: *Analyzer,
        builder: *FunctionBuilder,
        binary: Ast.Expression.Binary,
        expected: ?Types.Type,
    ) AnalyzeError!TypedValue {
        if (binary.operator == .logical_and or binary.operator == .logical_or) {
            return self.analyzeLogical(builder, binary);
        }
        if (binary.operator == .coalesce) return self.analyzeCoalesce(builder, binary);
        const equality = binary.operator == .equal or binary.operator == .not_equal;
        var left: TypedValue = undefined;
        var right: TypedValue = undefined;
        if (equality and binary.left.value == .null_value) {
            right = try self.analyzeExpression(builder, binary.right);
            left = try self.analyzeExpressionExpected(builder, binary.left, right.type);
        } else {
            const left_hint = if (expected != null and expected.?.isNumeric() and Support.isNumericLiteral(binary.left)) expected else null;
            left = try self.analyzeExpressionExpected(builder, binary.left, left_hint);
            if (equality and binary.right.value == .null_value) {
                right = try self.analyzeExpressionExpected(builder, binary.right, left.type);
            } else {
                const right_hint = if (Support.isNumericLiteral(binary.right))
                    (if (expected != null and expected.?.isNumeric()) expected else if (left.type.isNumeric()) left.type else null)
                else
                    null;
                right = try self.analyzeExpressionExpected(builder, binary.right, right_hint);
            }
        }
        if (binary.operator == .add and left.type == .str and right.type == .str) {
            const result = try self.newValue(builder, .str);
            try self.emit(builder, .{ .string_concat = .{
                .result = result,
                .left = left.value,
                .right = right.value,
            } });
            if (left.transferred) try Resources.emitDrop(self, builder, left.type, left.value);
            if (right.transferred) try Resources.emitDrop(self, builder, right.type, right.value);
            return .{ .type = .str, .value = result, .transferred = true };
        }
        const ordering = binary.operator == .less or binary.operator == .less_equal or
            binary.operator == .greater or binary.operator == .greater_equal;
        const bitwise = binary.operator == .bit_and or binary.operator == .bit_xor;
        const shift = binary.operator == .shift_left or binary.operator == .shift_right;
        if (left.type.isNumeric() and right.type.isNumeric() and !shift) {
            if (Numeric.commonNumeric(left.type, right.type)) |common| {
                left = try self.coerce(builder, left, common, binary.left.position);
                right = try self.coerce(builder, right, common, binary.right.position);
            }
        }
        const same_numeric = left.type == right.type and left.type.isNumeric();
        const valid = if (bitwise)
            same_numeric and left.type.isInteger() and !left.type.isSignedInteger()
        else if (shift)
            left.type.isInteger() and !left.type.isSignedInteger() and right.type.isInteger()
        else if (equality)
            same_numeric or (left.type == right.type and Support.isComparable(self, left.type))
        else
            same_numeric and (!left.type.isFloat() or binary.operator != .remainder);
        if (!valid) {
            const message = if (!equality)
                try std.fmt.allocPrint(
                    self.allocator,
                    "operator '{s}' does not accept '{s}' and '{s}'",
                    .{ Support.binaryOperatorText(binary.operator), self.typeName(left.type), self.typeName(right.type) },
                )
            else
                try std.fmt.allocPrint(
                    self.allocator,
                    "operator '{s}' does not accept '{s}' and '{s}'",
                    .{ Support.binaryOperatorText(binary.operator), self.typeName(left.type), self.typeName(right.type) },
                );
            return self.fail(binary.operator_position, message);
        }
        const result_type: Types.Type = if (equality or ordering) .bool else left.type;
        const result = try self.newValue(builder, result_type);
        try self.emit(builder, .{ .binary = .{
            .result = result,
            .operator = switch (binary.operator) {
                .add => .add,
                .subtract => .subtract,
                .multiply => .multiply,
                .divide => .divide,
                .remainder => .remainder,
                .less => .less,
                .less_equal => .less_equal,
                .greater => .greater,
                .greater_equal => .greater_equal,
                .equal => .equal,
                .not_equal => .not_equal,
                .logical_and, .logical_or, .coalesce => unreachable,
                .bit_and => .bit_and,
                .bit_xor => .bit_xor,
                .shift_left => .shift_left,
                .shift_right => .shift_right,
            },
            .left = left.value,
            .right = right.value,
        } });
        if (left.transferred and Resources.needsDrop(self, left.type)) {
            try Resources.emitDrop(self, builder, left.type, left.value);
        }
        if (right.transferred and Resources.needsDrop(self, right.type)) {
            try Resources.emitDrop(self, builder, right.type, right.value);
        }
        return .{ .type = result_type, .value = result };
    }

    fn analyzeCoalesce(self: *Analyzer, builder: *FunctionBuilder, binary: Ast.Expression.Binary) AnalyzeError!TypedValue {
        const left = try self.analyzeExpression(builder, binary.left);
        const child = left.type.optionalChild() orelse {
            const message = try std.fmt.allocPrint(self.allocator, "left operand of '??' must be optional, found '{s}'", .{self.typeName(left.type)});
            return self.fail(binary.operator_position, message);
        };
        const presence = try Optionals.emitPresence(self, builder, left);
        const present = try self.newBlock(builder);
        const absent = try self.newBlock(builder);
        const merge = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = presence.value, .then_block = present, .else_block = absent } });

        builder.current_block = absent;
        var right = try self.analyzeExpression(builder, binary.right);
        const result_type = if (right.type == left.type)
            left.type
        else if (right.type == child)
            child
        else if (child.isNumeric() and right.type.isNumeric())
            Numeric.commonNumeric(child, right.type) orelse {
                const message = try std.fmt.allocPrint(self.allocator, "right operand of '??' expects '{s}' or '{s}', found '{s}'", .{ self.typeName(child), self.typeName(left.type), self.typeName(right.type) });
                return self.fail(binary.right.position, message);
            }
        else {
            const message = try std.fmt.allocPrint(self.allocator, "right operand of '??' expects '{s}' or '{s}', found '{s}'", .{ self.typeName(child), self.typeName(left.type), self.typeName(right.type) });
            return self.fail(binary.right.position, message);
        };
        if (right.type != result_type) right = try self.coerce(builder, right, result_type, binary.right.position);
        const result = try self.newValue(builder, result_type);
        if (Resources.requiresRetain(self, result_type) and !right.transferred) try Resources.retainValue(self, builder, result_type, right.value);
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = right.value } });
        self.terminate(builder, .{ .jump = merge });

        builder.current_block = present;
        var selected = if (result_type == left.type) left else try Optionals.unwrap(self, builder, left);
        if (selected.type != result_type) selected = try self.coerce(builder, selected, result_type, binary.left.position);
        if (Resources.requiresRetain(self, result_type) and !selected.transferred) try Resources.retainValue(self, builder, result_type, selected.value);
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = selected.value } });
        self.terminate(builder, .{ .jump = merge });
        builder.current_block = merge;
        const lexical_borrows = try self.allocator.alloc(Model.LexicalBorrow, left.lexical_borrows.len + right.lexical_borrows.len);
        @memcpy(lexical_borrows[0..left.lexical_borrows.len], left.lexical_borrows);
        @memcpy(lexical_borrows[left.lexical_borrows.len..], right.lexical_borrows);
        return .{
            .type = result_type,
            .value = result,
            .transferred = Resources.ownsValue(self, result_type),
            .lexical_captures = left.lexical_captures or right.lexical_captures,
            .lexical_borrows = lexical_borrows,
        };
    }

    fn analyzeLogical(self: *Analyzer, builder: *FunctionBuilder, binary: Ast.Expression.Binary) AnalyzeError!TypedValue {
        const left = try self.analyzeExpression(builder, binary.left);
        if (left.type != .bool) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "operator '{s}' expects 'bool' operands, found '{s}'",
                .{ Support.binaryOperatorText(binary.operator), left.type.name() },
            );
            return self.fail(binary.operator_position, message);
        }

        const result = try self.newValue(builder, .bool);
        const right_block = try self.newBlock(builder);
        const short_block = try self.newBlock(builder);
        const merge_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = if (binary.operator == .logical_and) .{
            .condition = left.value,
            .then_block = right_block,
            .else_block = short_block,
        } else .{
            .condition = left.value,
            .then_block = short_block,
            .else_block = right_block,
        } });

        builder.current_block = short_block;
        try self.emit(builder, .{ .constant_bool = .{
            .result = result,
            .value = binary.operator == .logical_or,
        } });
        self.terminate(builder, .{ .jump = merge_block });

        builder.current_block = right_block;
        const right = try self.analyzeExpression(builder, binary.right);
        if (right.type != .bool) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "operator '{s}' expects 'bool' operands, found '{s}'",
                .{ Support.binaryOperatorText(binary.operator), right.type.name() },
            );
            return self.fail(binary.operator_position, message);
        }
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = right.value } });
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = merge_block;
        return .{ .type = .bool, .value = result };
    }

    fn findAstStructure(self: *Analyzer, name: []const u8) ?Ast.Structure {
        for (self.program.structures) |structure| {
            if (std.mem.eql(u8, structure.name, name)) return structure;
        }
        return null;
    }

    pub fn structureIndex(self: *Analyzer, name: []const u8) ?usize {
        for (self.structures, 0..) |structure, index| {
            if (std.mem.eql(u8, structure.name, name)) return index;
        }
        return null;
    }

    pub fn resolveStructureIndex(self: *Analyzer, name: []const u8) ?usize {
        if (std.mem.indexOfScalar(u8, name, '.') == null) if (self.member_context) |context| {
            var prefix = self.structures[context].name;
            while (true) {
                const candidate = std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, name }) catch return null;
                if (self.structureIndex(candidate)) |index| return index;
                prefix = if (std.mem.lastIndexOfScalar(u8, prefix, '.')) |dot| prefix[0..dot] else break;
            }
        };
        return self.structureIndex(name);
    }

    pub fn ownerStorageVisible(self: *Analyzer, structure_index: usize, position: Source.Position) bool {
        const declaration = self.findAstStructure(self.structures[structure_index].name) orelse return false;
        if (position.file == declaration.position.file) return true;
        for (self.program.uses) |use_value| {
            if (use_value.position.file == position.file and use_value.type_target != null and use_value.type_target.? == Ast.Type.structure(structure_index)) return true;
        }
        return false;
    }

    pub fn typeName(self: *Analyzer, type_value: Types.Type) []const u8 {
        if (type_value.optionalChild()) |child| {
            return std.fmt.allocPrint(self.allocator, "{s}?", .{self.typeName(child)}) catch "optional";
        }
        if (type_value.structureIndex()) |index| {
            if (index < self.structures.len) return self.structures[index].name;
        }
        return type_value.name();
    }

    fn analyzeFieldAccess(self: *Analyzer, builder: *FunctionBuilder, access: Ast.Expression.FieldAccess) AnalyzeError!TypedValue {
        if (try GenericSyntax.qualifiedName(self.allocator, access.base)) |owner_name| {
            if (Enums.find(self, owner_name)) |enum_index| {
                return Enums.analyzeValue(self, builder, access.name, access.name_position, enum_index);
            }
            if (StaticMembers.ownerIndex(self, owner_name)) |structure_index| {
                if (!Visibility.typeVisible(self, structure_index, access.name_position)) {
                    return self.fail(access.name_position, "nested type is unavailable in this context");
                }
                if (try StaticMembers.analyzeLoad(self, builder, structure_index, access.name, access.name_position)) |value| return value;
                return self.fail(access.name_position, "type has no static field with this name");
            }
        }
        const base = try self.analyzeExpression(builder, access.base);
        if (access.safe) return self.analyzeSafeFieldAccess(builder, access, base);
        return self.analyzeFieldValue(builder, access, base);
    }

    fn analyzeSafeFieldAccess(
        self: *Analyzer,
        builder: *FunctionBuilder,
        access: Ast.Expression.FieldAccess,
        optional_base: TypedValue,
    ) AnalyzeError!TypedValue {
        if (optional_base.type.optionalChild() == null) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "safe access '?.' requires an optional receiver, found '{s}'",
                .{self.typeName(optional_base.type)},
            );
            return self.fail(access.name_position, message);
        }
        const presence = try Optionals.emitPresence(self, builder, optional_base);
        const present_block = try self.newBlock(builder);
        const absent_block = try self.newBlock(builder);
        const merge_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{
            .condition = presence.value,
            .then_block = present_block,
            .else_block = absent_block,
        } });

        builder.current_block = present_block;
        const base = try Optionals.unwrap(self, builder, optional_base);
        const field = try self.analyzeFieldValue(builder, access, base);
        const result = if (field.type.optionalChild() != null)
            field
        else
            (try Optionals.promote(self, builder, field, .optional(field.type))).?;
        self.terminate(builder, .{ .jump = merge_block });

        builder.current_block = absent_block;
        try self.emit(builder, .{ .optional_null = .{ .result = result.value } });
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = merge_block;
        return result;
    }

    pub fn analyzeFieldValue(
        self: *Analyzer,
        builder: *FunctionBuilder,
        access: Ast.Expression.FieldAccess,
        base: TypedValue,
    ) AnalyzeError!TypedValue {
        const structure_index = base.type.structureIndex() orelse {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no fields", .{self.typeName(base.type)});
            return self.fail(access.name_position, message);
        };
        if (try Enums.analyzeProperty(self, builder, base, access.name, access.name_position)) |value| return value;
        const structure = self.structures[structure_index];
        if (structure.is_tuple) {
            if (!structure.tuple_named) {
                return self.fail(access.name_position, "a positional tuple has no named members; use destructuring");
            }
            for (structure.fields, 0..) |field, field_index| {
                if (!std.mem.eql(u8, field.name, access.name)) continue;
                const result = try self.newValue(builder, field.type);
                try self.emit(builder, .{ .field_load = .{ .result = result, .base = base.value, .field = field_index } });
                return .{ .type = field.type, .value = result, .borrowed_root = base.borrowed_root, .borrowed_mode = base.borrowed_mode };
            }
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no member named '{s}'", .{ self.typeName(base.type), access.name });
            return self.fail(access.name_position, message);
        }
        const declaration = self.findAstStructure(structure.name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no fields", .{self.typeName(base.type)});
            return self.fail(access.name_position, message);
        };
        if (!structure.is_tuple and declaration.drop != null and !self.ownerStorageVisible(structure_index, access.name_position)) {
            return self.fail(access.name_position, "owner structure storage is private to its declaring file and direct module users");
        }
        if (declaration.is_local and access.name_position.file != declaration.position.file) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "members of local structure '{s}' are unavailable outside its source file",
                .{structure.name},
            );
            return self.fail(access.name_position, message);
        }
        if (declaration.is_internal and !Visibility.packageVisible(self, declaration.owner)) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "members of package-visible structure '{s}' are unavailable outside its package",
                .{structure.name},
            );
            return self.fail(access.name_position, message);
        }
        for (structure.fields, 0..) |field, field_index| {
            if (!std.mem.eql(u8, field.name, access.name)) continue;
            const inherited = Inheritance.fieldByIndex(self, structure_index, field_index) orelse return error.InvalidSource;
            const source_field = inherited.declaration;
            if (!Visibility.memberVisible(self, inherited.owner, source_field, access.name_position)) {
                const message = if (source_field.is_local)
                    try std.fmt.allocPrint(self.allocator, "field '{s}' is local to its source file", .{field.name})
                else
                    try std.fmt.allocPrint(self.allocator, "field '{s}' is {s} and unavailable here", .{ field.name, Visibility.name(source_field) });
                return self.fail(access.name_position, message);
            }
            const result = try self.newValue(builder, field.type);
            try self.emit(builder, .{ .field_load = .{ .result = result, .base = base.value, .field = field_index } });
            const reference = if (base.reference != null and base.borrowed_mode == .mutable and field.mutable) reference: {
                const field_reference = try self.newValue(builder, .address);
                try self.emit(builder, .{ .reference_field = .{
                    .result = field_reference,
                    .reference = base.reference.?,
                    .structure = structure_index,
                    .field = field_index,
                } });
                break :reference field_reference;
            } else null;
            return .{ .type = field.type, .value = result, .borrowed_root = base.borrowed_root, .borrowed_mode = base.borrowed_mode, .reference = reference, .lexical_captures = base.lexical_captures, .lexical_borrows = base.lexical_borrows };
        }
        const message = try std.fmt.allocPrint(
            self.allocator,
            "type '{s}' has no member named '{s}'",
            .{ structure.name, access.name },
        );
        return self.fail(access.name_position, message);
    }

    fn analyzeStructureInitializer(
        self: *Analyzer,
        builder: *FunctionBuilder,
        call: Ast.Expression.Call,
        structure_index: usize,
    ) AnalyzeError!TypedValue {
        const structure = self.structures[structure_index];
        const declaration = self.findAstStructure(structure.name).?;
        if (declaration.is_protocol) return self.fail(call.name_position, "protocols cannot be constructed");
        if (!Visibility.typeVisible(self, structure_index, call.name_position)) {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' is unavailable in this context", .{structure.name});
            return self.fail(call.name_position, message);
        }
        if (declaration.is_static) {
            return self.fail(call.name_position, if (declaration.is_class) "static classes cannot be constructed" else "static structures cannot be constructed");
        }
        if (declaration.constructors.len != 0) {
            return Constructors.analyzeCall(self, builder, structure_index, declaration, call);
        }
        if (declaration.drop != null and !self.ownerStorageVisible(structure_index, call.name_position)) {
            return self.fail(call.name_position, "owner structure aggregate initializer is private to its declaring file and direct module users");
        }
        if (call.arguments.len != 0) {
            const message = try std.fmt.allocPrint(self.allocator, "structure '{s}' uses named fields", .{structure.name});
            return self.fail(call.name_position, message);
        }
        for (call.named_arguments, 0..) |argument, index| {
            for (call.named_arguments[0..index]) |previous| {
                if (std.mem.eql(u8, argument.name, previous.name)) {
                    const message = try std.fmt.allocPrint(self.allocator, "field '{s}' is provided more than once", .{argument.name});
                    return self.fail(argument.position, message);
                }
            }
            var known = false;
            for (declaration.fields) |source_field| if (std.mem.eql(u8, source_field.name, argument.name)) {
                if (!Visibility.memberVisible(self, structure_index, source_field, argument.position)) {
                    const message = if (source_field.is_local)
                        try std.fmt.allocPrint(self.allocator, "field '{s}' is local to its source file", .{source_field.name})
                    else
                        try std.fmt.allocPrint(self.allocator, "field '{s}' is {s} and unavailable here", .{ source_field.name, Visibility.name(source_field) });
                    return self.fail(argument.position, message);
                }
                known = true;
                break;
            };
            if (!known) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "structure '{s}' has no field named '{s}'",
                    .{ structure.name, argument.name },
                );
                return self.fail(argument.position, message);
            }
        }

        var field_values: std.ArrayList(Ir.ValueId) = .empty;
        var field_transfers: std.ArrayList(bool) = .empty;
        var lexical_captures = false;
        var lexical_borrows: std.ArrayList(Model.LexicalBorrow) = .empty;
        if (structure.base) |base_index| {
            const base = try self.analyzeStructureInitializer(builder, .{
                .name = self.structures[base_index].name,
                .name_position = call.name_position,
                .arguments = &.{},
            }, base_index);
            for (self.structures[base_index].fields, 0..) |field, field_index| {
                const value = try self.newValue(builder, field.type);
                try self.emit(builder, .{ .field_load = .{ .result = value, .base = base.value, .field = field_index } });
                try field_values.append(self.allocator, value);
                try field_transfers.append(self.allocator, false);
            }
        }
        for (declaration.fields) |field| {
            var provided: ?*Ast.Expression = null;
            for (call.named_arguments) |argument| {
                if (std.mem.eql(u8, field.name, argument.name)) provided = argument.value;
            }
            var value = if (provided orelse field.default) |expression|
                try self.analyzeExpressionExpected(
                    builder,
                    expression,
                    Optionals.expectedContext(field.type, expression),
                )
            else missing: {
                if (declaration.is_class and !Visibility.memberVisible(self, structure_index, field, call.name_position)) {
                    const message = try std.fmt.allocPrint(self.allocator, "private field '{s}' requires a default or a constructor", .{field.name});
                    return self.fail(call.name_position, message);
                }
                break :missing try self.emitIntrinsic(builder, field.type, call.name_position);
            };
            if (value.type != field.type and self.canImplicitlyConvert(value.type, field.type)) {
                value = try self.coerce(builder, value, field.type, if (provided) |expression| expression.position else call.name_position);
            }
            if (value.type != field.type) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "field '{s}' of '{s}' expects '{s}', found '{s}'",
                    .{ field.name, structure.name, self.typeName(field.type), self.typeName(value.type) },
                );
                return self.fail(if (provided) |expression| expression.position else call.name_position, message);
            }
            try Borrowing.requireOwned(self, value, if (provided) |expression| expression.position else call.name_position, "stored");
            try field_values.append(self.allocator, value.value);
            try field_transfers.append(self.allocator, value.transferred);
            lexical_captures = lexical_captures or value.lexical_captures;
            try lexical_borrows.appendSlice(self.allocator, value.lexical_borrows);
        }
        for (self.structures[structure_index].fields, field_values.items, field_transfers.items) |field, field_value, transferred| {
            if (!Resources.requiresRetain(self, field.type)) continue;
            if (declaration.is_class) {
                try Resources.retainValueOwned(self, builder, field.type, field_value, .edge);
                if (transferred) try Resources.releaseTransferredRoot(self, builder, field.type, field_value);
            } else if (!transferred) {
                try Resources.retainValue(self, builder, field.type, field_value);
            }
        }
        const result_type = Types.Type.structure(structure_index);
        const result = try self.newValue(builder, result_type);
        try self.emit(builder, .{ .structure_init = .{
            .result = result,
            .structure = structure_index,
            .fields = try field_values.toOwnedSlice(self.allocator),
        } });
        return .{
            .type = result_type,
            .value = result,
            .transferred = Resources.ownsValue(self, result_type) and !declaration.is_class,
            .lexical_captures = lexical_captures,
            .lexical_borrows = try lexical_borrows.toOwnedSlice(self.allocator),
        };
    }

    pub fn emitIntrinsic(self: *Analyzer, builder: *FunctionBuilder, type_value: Types.Type, position: Source.Position) AnalyzeError!TypedValue {
        if (try Optionals.intrinsic(self, builder, type_value)) |value| return value;
        if (Enums.findByType(self, type_value)) |enum_index| {
            const enumeration = self.program.enums[enum_index];
            for (enumeration.variants) |variant| if (variant.associated_types.len == 0) {
                return Enums.analyzeValue(self, builder, variant.name, position, enum_index);
            };
            return self.fail(position, "an enum without a payload-free variant has no intrinsic value");
        }
        if (type_value.functionIndex() != null) {
            const result = try self.newValue(builder, type_value);
            try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = 0 } });
            return .{ .type = type_value, .value = result };
        }
        if (type_value.structureIndex()) |structure_index| if (structure_index < self.structures.len) {
            if (self.structures[structure_index].collection) |collection| {
                if (collection.length == null and !collection.view) {
                    const result = try self.newValue(builder, type_value);
                    try self.emit(builder, .{ .list_init = .{ .result = result, .values = &.{} } });
                    return .{ .type = type_value, .value = result, .transferred = true };
                }
            }
        };
        return switch (type_value) {
            .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint => self.emitInteger(builder, 0, type_value),
            .bool => self.emitBool(builder, false),
            .float32 => self.emitFloat32(builder, 0.0),
            .float64 => self.emitFloat64(builder, 0.0),
            .str => self.emitString(builder, ""),
            else => if (type_value.structureIndex()) |structure_index|
                self.analyzeStructureInitializer(builder, .{
                    .name = self.structures[structure_index].name,
                    .name_position = position,
                    .arguments = &.{},
                }, structure_index)
            else
                self.fail(position, "this type has no intrinsic value"),
        };
    }

    pub fn analyzeCall(self: *Analyzer, builder: *FunctionBuilder, call: Ast.Expression.Call) AnalyzeError!?TypedValue {
        if (try Callbacks.call(self, builder, call)) |result| return result.value;
        if (call.receiver == null and std.mem.eql(u8, call.name, "reflect")) return try Reflection.analyze(self, builder, call);
        if (call.receiver == null and std.mem.eql(u8, call.name, "map_error")) return try MapError.analyze(self, builder, call);
        if (try EmbeddedFiles.analyze(self, builder, call)) |value| return value;
        if (call.receiver == null and std.mem.eql(u8, call.name, "C.call")) {
            return try Interop.analyzeIntrinsic(self, builder, call);
        }
        if (try Interop.analyzeIntrinsic(self, builder, call)) |value| return value;
        if (call.receiver) |receiver_expression| {
            if (Collections.isMutation(call.name) and Collections.receiverIsCollection(self, builder, receiver_expression)) {
                return try Collections.analyzeMutation(self, builder, call);
            }
            if (try Collections.analyzeCall(self, builder, call)) |value| return value;
            if (try GenericSyntax.qualifiedName(self.allocator, receiver_expression)) |receiver_name| {
                const nested_name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ receiver_name, call.name });
                if (self.resolveStructureIndex(nested_name)) |structure_index| {
                    return try self.analyzeStructureInitializer(builder, call, structure_index);
                }
                if (StaticMembers.ownerIndex(self, receiver_name)) |structure_index| {
                    if (!Visibility.typeVisible(self, structure_index, call.name_position)) {
                        return self.fail(call.name_position, "nested type is unavailable in this context");
                    }
                    return try StaticMembers.analyzeCall(self, builder, structure_index, call);
                }
                if (Enums.find(self, receiver_name)) |enum_index| {
                    return try Enums.analyzeInitializer(self, builder, call, enum_index);
                }
            }
            return Methods.analyzeCall(self, builder, call);
        }
        if (Enums.find(self, call.name) != null) {
            const message = try std.fmt.allocPrint(self.allocator, "enum '{s}' must be constructed through one of its variants", .{call.name});
            return self.fail(call.name_position, message);
        }
        if (self.resolveStructureIndex(call.name)) |structure_index| {
            return try self.analyzeStructureInitializer(builder, call, structure_index);
        }
        if (try Collections.analyzeQualifiedStaticCall(self, builder, call)) |handled| return handled.value;
        if (std.mem.endsWith(u8, call.name, ".count") and call.arguments.len == 0) {
            const receiver_name = call.name[0 .. call.name.len - ".count".len];
            if (Support.findBinding(builder.bindings.items, receiver_name)) |binding| {
                if (binding.type != .str) return self.fail(call.name_position, "count() expects 'str'");
                const value = if (binding.local) |local| load: {
                    const result = try self.newValue(builder, binding.type);
                    try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
                    break :load result;
                } else binding.value.?;
                return try self.emitStringCount(builder, value);
            }
        }
        if (Interop.hasFunction(self, call.name)) return Interop.analyzeCall(self, builder, call);
        if (call.named_arguments.len != 0) return NamedCalls.analyzeFunction(self, builder, call);
        var total_named: usize = 0;
        var named_count: usize = 0;
        var arity_count: usize = 0;
        for (self.program.functions) |function| {
            if (!std.mem.eql(u8, function.name, call.name)) continue;
            total_named += 1;
            if (!Support.functionVisible(self.packages, self.module_scope_roots, call, function)) continue;
            named_count += 1;
            if (Support.acceptsArity(function.parameters, call.arguments.len)) arity_count += 1;
        }
        if (total_named == 0) {
            const message = try std.fmt.allocPrint(self.allocator, "unknown function '{s}'", .{call.name});
            return self.fail(call.name_position, message);
        }
        if (named_count == 0) {
            var has_local = false;
            var has_internal = false;
            for (self.program.functions) |function| {
                if (!std.mem.eql(u8, function.name, call.name)) continue;
                has_local = has_local or function.is_local;
                has_internal = has_internal or function.is_internal;
            }
            const message = if (has_local)
                try std.fmt.allocPrint(self.allocator, "function '{s}' is local to its source file", .{call.name})
            else if (has_internal)
                try std.fmt.allocPrint(self.allocator, "function '{s}' is package-visible and unavailable outside its package", .{call.name})
            else
                try std.fmt.allocPrint(self.allocator, "function '{s}' is module-visible and unavailable outside its module", .{call.name});
            return self.fail(call.name_position, message);
        }
        if (arity_count == 0) {
            const message = if (named_count == 1) single: {
                const function = Support.findVisibleFunctionByName(self.packages, self.module_scope_roots, self.program, call).?;
                const required = Support.requiredParameterCount(function.parameters);
                break :single if (required == function.parameters.len)
                    try std.fmt.allocPrint(
                        self.allocator,
                        "function '{s}' expects {d} arguments, found {d}",
                        .{ call.name, function.parameters.len, call.arguments.len },
                    )
                else
                    try std.fmt.allocPrint(
                        self.allocator,
                        "function '{s}' expects between {d} and {d} arguments, found {d}",
                        .{ call.name, required, function.parameters.len, call.arguments.len },
                    );
            } else try std.fmt.allocPrint(
                self.allocator,
                "no overload of function '{s}' accepts {d} arguments",
                .{ call.name, call.arguments.len },
            );
            return self.fail(call.name_position, message);
        }

        var sole_candidate: ?Ir.FunctionId = null;
        if (arity_count == 1) {
            for (self.program.functions, 0..) |function, function_id| {
                if (std.mem.eql(u8, function.name, call.name) and Support.acceptsArity(function.parameters, call.arguments.len) and
                    Support.functionVisible(self.packages, self.module_scope_roots, call, function))
                {
                    sole_candidate = function_id;
                    break;
                }
            }
        }

        var arguments: std.ArrayList(TypedValue) = .empty;
        for (call.arguments, 0..) |argument, index| {
            const expected = if (sole_candidate) |candidate| expected: {
                const parameter_type = self.program.functions[candidate].parameters[index].type;
                break :expected Optionals.expectedContext(parameter_type, argument);
            } else null;
            try arguments.append(self.allocator, try self.analyzeExpressionExpected(builder, argument, expected));
        }

        var resolved: ?Ir.FunctionId = sole_candidate;
        var ambiguous = false;
        if (sole_candidate == null) {
            var viable: std.ArrayList(Ir.FunctionId) = .empty;
            for (self.program.functions, 0..) |function, function_id| {
                if (!std.mem.eql(u8, function.name, call.name) or !Support.acceptsArity(function.parameters, arguments.items.len)) continue;
                if (!Support.functionVisible(self.packages, self.module_scope_roots, call, function)) continue;
                var matches = true;
                for (function.parameters[0..arguments.items.len], arguments.items) |parameter, argument| {
                    if (conversionCost(self, argument.type, parameter.type) == null) {
                        matches = false;
                        break;
                    }
                }
                if (matches) try viable.append(self.allocator, function_id);
            }

            var nondominated: usize = 0;
            for (viable.items) |candidate_id| {
                var dominated = false;
                for (viable.items) |other_id| {
                    if (candidate_id == other_id) continue;
                    if (dominates(
                        self,
                        self.program.functions[other_id].parameters[0..arguments.items.len],
                        self.program.functions[candidate_id].parameters[0..arguments.items.len],
                        arguments.items,
                    )) {
                        dominated = true;
                        break;
                    }
                }
                if (!dominated) {
                    resolved = candidate_id;
                    nondominated += 1;
                }
            }
            ambiguous = nondominated > 1;
        }

        if (ambiguous) {
            const message = try std.fmt.allocPrint(self.allocator, "call to '{s}' is ambiguous", .{call.name});
            return self.fail(call.name_position, message);
        }

        const function_id = resolved orelse {
            if (arity_count == 1) {
                for (self.program.functions) |function| {
                    if (!std.mem.eql(u8, function.name, call.name) or !Support.acceptsArity(function.parameters, arguments.items.len)) continue;
                    if (!Support.functionVisible(self.packages, self.module_scope_roots, call, function)) continue;
                    for (function.parameters[0..arguments.items.len], arguments.items, 0..) |parameter, argument, index| {
                        if (parameter.type == argument.type) continue;
                        const message = try std.fmt.allocPrint(
                            self.allocator,
                            "argument {d} of '{s}' expects '{s}', found '{s}'",
                            .{ index + 1, call.name, self.typeName(parameter.type), self.typeName(argument.type) },
                        );
                        return self.fail(call.arguments[index].position, message);
                    }
                }
            }
            const message = try std.fmt.allocPrint(
                self.allocator,
                "no overload of function '{s}' matches the argument types",
                .{call.name},
            );
            return self.fail(call.name_position, message);
        };
        const function = self.program.functions[function_id];
        try Borrowing.validateReadArguments(self, function.parameters, call.arguments);
        var argument_ids: std.ArrayList(Ir.ValueId) = .empty;
        const MutableArgument = struct { source: *const Ast.Expression, prepared: MutableReferences.Prepared };
        var mutable_arguments: std.ArrayList(MutableArgument) = .empty;
        for (arguments.items, function.parameters[0..arguments.items.len], 0..) |argument, parameter, index| {
            if (!self.canImplicitlyConvert(argument.type, parameter.type)) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "argument {d} of '{s}' expects '{s}', found '{s}'",
                    .{ index + 1, call.name, self.typeName(parameter.type), self.typeName(argument.type) },
                );
                return self.fail(call.arguments[index].position, message);
            }
            if (parameter.mode == .mutable) {
                if (Collections.isViewType(self.structures, parameter.type)) {
                    if (argument.borrowed_mode != .mutable) return self.fail(call.arguments[index].position, "mutable view parameter requires an '&T[..]' argument");
                    try argument_ids.append(self.allocator, argument.value);
                    continue;
                }
                var reused: ?Ir.ValueId = null;
                for (mutable_arguments.items) |previous| if (MutableReferences.samePlace(previous.source, call.arguments[index])) {
                    reused = previous.prepared.reference;
                    break;
                };
                if (reused) |reference| {
                    try argument_ids.append(self.allocator, reference);
                } else {
                    const prepared = try MutableReferences.prepare(self, builder, call.arguments[index], parameter.type);
                    try mutable_arguments.append(self.allocator, .{ .source = call.arguments[index], .prepared = prepared });
                    try argument_ids.append(self.allocator, prepared.reference);
                }
                continue;
            }
            if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, call.arguments[index].position, "passed by value");
            const converted = try self.coerce(builder, argument, parameter.type, call.name_position);
            if (parameter.mode == .value and Resources.requiresRetain(self, parameter.type) and !converted.transferred) {
                try Resources.retainValue(self, builder, parameter.type, converted.value);
            }
            try argument_ids.append(self.allocator, converted.value);
        }
        for (function.parameters[arguments.items.len..]) |parameter| {
            const value = try self.analyzeParameterDefault(builder, parameter);
            try argument_ids.append(self.allocator, value.value);
        }
        const result_type = Collections.loweredBorrowType(self.structures, function.return_mode, function.return_type);
        const result: ?Ir.ValueId = if (function.return_type == .void)
            null
        else result: {
            if (!function.return_type.hasRuntimeValue()) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "values of type '{s}' are not executable yet",
                    .{self.typeName(function.return_type)},
                );
                return self.fail(call.name_position, message);
            }
            break :result try self.newValue(builder, result_type);
        };
        try self.emit(builder, .{ .call = .{
            .result = result,
            .function = function_id,
            .arguments = try argument_ids.toOwnedSlice(self.allocator),
        } });
        for (mutable_arguments.items) |argument| try MutableReferences.writeBack(self, builder, argument.prepared);
        if (result == null) return null;
        if (function.return_mode == .value) return .{
            .type = function.return_type,
            .value = result.?,
            .transferred = Resources.ownsValue(self, function.return_type),
        };
        const provenance = function.return_provenance.?;
        var parameter_index: ?usize = null;
        for (function.parameters, 0..) |parameter, index| if (std.mem.eql(u8, parameter.name, provenance)) {
            parameter_index = index;
            break;
        };
        const source = arguments.items[parameter_index.?];
        const root = source.borrowed_root orelse Borrowing.rootName(call.arguments[parameter_index.?]) orelse
            return self.fail(call.name_position, "borrowed return cannot originate from a temporary");
        if (function.return_mode == .read) return .{
            .type = function.return_type,
            .value = result.?,
            .borrowed_root = root,
            .borrowed_mode = .read,
        };
        if (Collections.isViewType(self.structures, function.return_type)) return .{
            .type = function.return_type,
            .value = result.?,
            .borrowed_root = root,
            .borrowed_mode = .mutable,
        };
        const loaded = try self.newValue(builder, function.return_type);
        try self.emit(builder, .{ .reference_load = .{ .result = loaded, .reference = result.? } });
        return .{
            .type = function.return_type,
            .value = loaded,
            .borrowed_root = root,
            .borrowed_mode = .mutable,
            .reference = result.?,
        };
    }

    fn emitInteger(self: *Analyzer, builder: *FunctionBuilder, bits: u64, type_value: Types.Type) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, type_value);
        try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = Numeric.normalize(bits, type_value) } });
        return .{ .type = type_value, .value = result };
    }

    fn emitIntegerLiteral(
        self: *Analyzer,
        builder: *FunctionBuilder,
        lexeme: []const u8,
        negative: bool,
        target: Types.Type,
        position: Source.Position,
    ) AnalyzeError!TypedValue {
        const magnitude = try Support.parseIntegerMagnitude(self, lexeme, position);
        if (!Numeric.fitsMagnitude(magnitude, negative, target)) {
            const message = try std.fmt.allocPrint(self.allocator, "integer literal is outside the range of '{s}'", .{target.name()});
            return self.fail(position, message);
        }
        return self.emitInteger(builder, Numeric.fromMagnitude(magnitude, negative, target).bits, target);
    }

    fn emitFloatingLiteral(
        self: *Analyzer,
        builder: *FunctionBuilder,
        lexeme: []const u8,
        target: Types.Type,
        position: Source.Position,
    ) AnalyzeError!TypedValue {
        const normalized = try Support.removeSeparators(self.allocator, lexeme);
        return switch (target) {
            .float32 => self.emitFloat32(builder, std.fmt.parseFloat(f32, normalized) catch
                return self.fail(position, "floating literal is outside the range of 'float'")),
            .float64 => self.emitFloat64(builder, std.fmt.parseFloat(f64, normalized) catch
                return self.fail(position, "floating literal is outside the range of 'float64'")),
            else => unreachable,
        };
    }

    fn emitFloat32(self: *Analyzer, builder: *FunctionBuilder, value: f32) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .float32);
        try self.emit(builder, .{ .constant_float32 = .{ .result = result, .bits = @bitCast(value) } });
        return .{ .type = .float32, .value = result };
    }

    fn emitFloat64(self: *Analyzer, builder: *FunctionBuilder, value: f64) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .float64);
        try self.emit(builder, .{ .constant_float64 = .{ .result = result, .bits = @bitCast(value) } });
        return .{ .type = .float64, .value = result };
    }

    fn emitBool(self: *Analyzer, builder: *FunctionBuilder, value: bool) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .constant_bool = .{ .result = result, .value = value } });
        return .{ .type = .bool, .value = result };
    }

    pub fn emitString(self: *Analyzer, builder: *FunctionBuilder, value: []const u8) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .str);
        try self.emit(builder, .{ .constant_str = .{ .result = result, .value = value } });
        return .{ .type = .str, .value = result };
    }

    fn analyzePrint(self: *Analyzer, builder: *FunctionBuilder, statement: Ast.PrintStatement) AnalyzeError!void {
        const values = try self.allocator.alloc(TypedValue, statement.values.len);
        for (statement.values, 0..) |expression, index| {
            const value = try self.analyzeExpression(builder, expression);
            if (value.type != .str and !value.type.isNumeric() and value.type != .bool) {
                return self.fail(expression.position, "print expects 'str', a numeric value, or 'bool'");
            }
            values[index] = value;
        }
        for (values, 0..) |value, index| {
            try self.emit(builder, .{ .print = .{ .value = value.value, .newline = index + 1 == values.len } });
            if (value.transferred and Resources.needsDrop(self, value.type)) {
                try Resources.emitDrop(self, builder, value.type, value.value);
            }
        }
    }

    fn analyzeInterpolatedString(
        self: *Analyzer,
        builder: *FunctionBuilder,
        interpolated: Ast.Expression.InterpolatedString,
    ) AnalyzeError!TypedValue {
        var result = try self.emitString(builder, "");
        for (interpolated.parts) |part| {
            const text: TypedValue = switch (part) {
                .text => |value| try self.emitString(builder, value),
                .expression => |expression| value: {
                    const value = try self.analyzeExpression(builder, expression);
                    if (value.type != .str and !value.type.isNumeric() and value.type != .bool) {
                        return self.fail(expression.position, "string interpolation expects 'str', a numeric value, or 'bool'");
                    }
                    if (value.type == .str) break :value value;
                    const formatted = try self.newValue(builder, .str);
                    try self.emit(builder, .{ .format_value = .{ .result = formatted, .operand = value.value } });
                    break :value .{ .type = .str, .value = formatted, .transferred = true };
                },
            };
            const combined = try self.newValue(builder, .str);
            try self.emit(builder, .{ .string_concat = .{
                .result = combined,
                .left = result.value,
                .right = text.value,
            } });
            if (result.transferred) try Resources.emitDrop(self, builder, result.type, result.value);
            if (text.transferred) try Resources.emitDrop(self, builder, text.type, text.value);
            result = .{ .type = .str, .value = combined, .transferred = true };
        }
        return result;
    }

    fn analyzeAssert(self: *Analyzer, builder: *FunctionBuilder, statement: Ast.AssertStatement) AnalyzeError!void {
        const condition = try self.analyzeExpression(builder, statement.condition);
        const message = try self.analyzeExpression(builder, statement.message);
        if (condition.type != .bool) return self.fail(statement.condition.position, "assert condition expects 'bool'");
        if (message.type != .str) return self.fail(statement.message.position, "assert message expects 'str'");
        try self.emit(builder, .{ .assert = .{
            .condition = condition.value,
            .message = message.value,
            .position = statement.position,
        } });
        if (message.transferred) try Resources.emitDrop(self, builder, message.type, message.value);
    }

    fn analyzePanic(self: *Analyzer, builder: *FunctionBuilder, statement: Ast.EffectStatement) AnalyzeError!void {
        const message = try self.analyzeExpression(builder, statement.value);
        if (message.type != .str) return self.fail(statement.value.position, "panic message expects 'str'");
        self.terminate(builder, .{ .panic = .{ .message = message.value, .position = statement.position } });
    }

    fn analyzeStringCount(self: *Analyzer, builder: *FunctionBuilder, operand: *const Ast.Expression) AnalyzeError!TypedValue {
        const value = try self.analyzeExpression(builder, operand);
        if (value.type != .str) return self.fail(operand.position, "count() expects 'str'");
        const result = try self.emitStringCount(builder, value.value);
        if (value.transferred) try Resources.emitDrop(self, builder, value.type, value.value);
        return result;
    }

    pub fn emitStringCount(self: *Analyzer, builder: *FunctionBuilder, operand: Ir.ValueId) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .int);
        try self.emit(builder, .{ .string_count = .{ .result = result, .operand = operand } });
        return .{ .type = .int, .value = result };
    }

    pub fn emit(self: *Analyzer, builder: *FunctionBuilder, instruction: Ir.Instruction) Allocator.Error!void {
        try builder.blocks.items[builder.current_block].instructions.append(self.allocator, instruction);
    }

    pub fn terminate(_: *Analyzer, builder: *FunctionBuilder, terminator: Ir.Terminator) void {
        std.debug.assert(builder.blocks.items[builder.current_block].terminator == null);
        builder.blocks.items[builder.current_block].terminator = terminator;
    }

    pub fn newBlock(self: *Analyzer, builder: *FunctionBuilder) Allocator.Error!Ir.BlockId {
        const block = builder.blocks.items.len;
        try builder.blocks.append(self.allocator, .{});
        return block;
    }

    fn analyzeConversion(
        self: *Analyzer,
        builder: *FunctionBuilder,
        conversion: Ast.Expression.Conversion,
    ) AnalyzeError!TypedValue {
        const operand = try self.analyzeExpression(builder, conversion.operand);
        if (!operand.type.isNumeric() or !conversion.target.isNumeric()) {
            return self.fail(conversion.operator_position, "'as' requires numeric source and target types");
        }
        return self.emitConversion(builder, operand, conversion.target, conversion.operator_position, true);
    }

    pub fn coerce(
        self: *Analyzer,
        builder: *FunctionBuilder,
        value: TypedValue,
        target: Types.Type,
        position: Source.Position,
    ) AnalyzeError!TypedValue {
        return Conversions.coerce(self, builder, value, target, position);
    }

    pub fn canImplicitlyConvert(self: *Analyzer, source: Types.Type, target: Types.Type) bool {
        return Conversions.canImplicitlyConvert(self, source, target);
    }

    fn emitConversion(
        self: *Analyzer,
        builder: *FunctionBuilder,
        value: TypedValue,
        target: Types.Type,
        position: Source.Position,
        checked: bool,
    ) AnalyzeError!TypedValue {
        return Conversions.emitNumeric(self, builder, value, target, position, checked);
    }

    pub fn newValue(self: *Analyzer, builder: *FunctionBuilder, type_value: Types.Type) Allocator.Error!Ir.ValueId {
        const result = builder.value_types.items.len;
        try builder.value_types.append(self.allocator, type_value);
        return result;
    }

    pub fn fail(self: *Analyzer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn functionMentionsName(program: Ast.Program, function: Ast.Function, name: []const u8) bool {
    for (function.parameters) |parameter| if (std.mem.eql(u8, parameter.name, name)) return false;
    return statementsMentionFreeName(program, function.statements, name, false);
}

fn statementsMentionName(program: Ast.Program, statements: []const Ast.Statement, name: []const u8) bool {
    return statementsMentionFreeName(program, statements, name, false);
}

fn statementsMentionFreeName(
    program: Ast.Program,
    statements: []const Ast.Statement,
    name: []const u8,
    initially_shadowed: bool,
) bool {
    var shadowed = initially_shadowed;
    for (statements) |statement| switch (statement) {
        .variable_declaration => |declaration| {
            if (!shadowed) if (declaration.initializer) |value| if (expressionMentionsName(program, value, name)) return true;
            if (std.mem.eql(u8, declaration.name, name)) shadowed = true;
            for (declaration.destructuring) |binding| if (std.mem.eql(u8, binding.name, name)) {
                shadowed = true;
                break;
            };
        },
        .assignment_statement => |assignment| {
            if (!shadowed) {
                if (std.mem.eql(u8, assignment.target.name, name)) return true;
                for (assignment.target.indices) |index| if (expressionMentionsName(program, index.value, name)) return true;
                if (assignment.value) |value| if (expressionMentionsName(program, value, name)) return true;
            }
        },
        .return_statement => |return_value| if (return_value.value) |value| {
            if (!shadowed and expressionMentionsName(program, value, name)) return true;
        },
        .expression_statement => |expression| if (!shadowed and expressionMentionsName(program, expression, name)) return true,
        .print_statement => |print_value| for (print_value.values) |value| {
            if (!shadowed and expressionMentionsName(program, value, name)) return true;
        },
        .assert_statement => |assertion| {
            if (!shadowed and (expressionMentionsName(program, assertion.condition, name) or expressionMentionsName(program, assertion.message, name))) return true;
        },
        .panic_statement => |panic_value| if (!shadowed and expressionMentionsName(program, panic_value.value, name)) return true,
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                if (!shadowed and expressionMentionsName(program, branch.condition.source(), name)) return true;
                const branch_shadowed = shadowed or switch (branch.condition) {
                    .binding => |binding| std.mem.eql(u8, binding.name, name),
                    .expression => false,
                };
                if (statementsMentionFreeName(program, branch.statements, name, branch_shadowed)) return true;
            }
            if (conditional.else_statements) |alternative| if (statementsMentionFreeName(program, alternative, name, shadowed)) return true;
        },
        .while_statement => |loop| {
            if (!shadowed and expressionMentionsName(program, loop.condition.source(), name)) return true;
            const body_shadowed = shadowed or switch (loop.condition) {
                .binding => |binding| std.mem.eql(u8, binding.name, name),
                .expression => false,
            };
            if (statementsMentionFreeName(program, loop.statements, name, body_shadowed)) return true;
        },
        .for_statement => |loop| {
            if (!shadowed) switch (loop.source) {
                .collection => |collection| if (expressionMentionsName(program, collection, name)) return true,
                .range => |range| if (expressionMentionsName(program, range.start, name) or expressionMentionsName(program, range.end, name)) return true,
            };
            var body_shadowed = shadowed or std.mem.eql(u8, loop.name, name);
            if (loop.index_name) |index_name| body_shadowed = body_shadowed or std.mem.eql(u8, index_name, name);
            for (loop.bindings) |binding| if (std.mem.eql(u8, binding.name, name)) {
                body_shadowed = true;
                break;
            };
            if (statementsMentionFreeName(program, loop.statements, name, body_shadowed)) return true;
        },
        .mutex_statement => |mutex| if (statementsMentionFreeName(program, mutex.statements, name, shadowed)) return true,
        .break_statement, .continue_statement => {},
    };
    return false;
}

fn expressionMentionsName(program: Ast.Program, expression: *const Ast.Expression, name: []const u8) bool {
    return switch (expression.value) {
        .identifier => |identifier| mention: {
            if (std.mem.eql(u8, identifier, name)) break :mention true;
            for (program.functions) |nested| {
                if (nested.is_anonymous and anonymousNameMatches(nested.name, identifier)) {
                    break :mention functionMentionsName(program, nested, name);
                }
            }
            break :mention false;
        },
        .generic_reference => |reference| std.mem.eql(u8, reference.name, name),
        .call => |call| mentions: {
            if (call.receiver) |receiver| if (expressionMentionsName(program, receiver, name)) break :mentions true;
            if (std.mem.eql(u8, call.name, name)) break :mentions true;
            for (call.arguments) |argument| if (expressionMentionsName(program, argument, name)) break :mentions true;
            for (call.named_arguments) |argument| if (expressionMentionsName(program, argument.value, name)) break :mentions true;
            break :mentions false;
        },
        .cascade => |cascade| mentions: {
            if (expressionMentionsName(program, cascade.receiver, name)) break :mentions true;
            for (cascade.operations) |operation| switch (operation) {
                .method_call => |call| {
                    for (call.arguments) |argument| if (expressionMentionsName(program, argument, name)) break :mentions true;
                    for (call.named_arguments) |argument| if (expressionMentionsName(program, argument.value, name)) break :mentions true;
                },
                .field_assignment => |assignment| if (expressionMentionsName(program, assignment.value, name)) break :mentions true,
            };
            break :mentions false;
        },
        .field_access => |access| expressionMentionsName(program, access.base, name),
        .unary => |unary| expressionMentionsName(program, unary.operand, name) or
            (if (unary.try_alternative) |alternative| if (alternative.message) |message| expressionMentionsName(program, message, name) else if (alternative.statements) |statements| statementsMentionName(program, statements, name) else false else false),
        .binary => |binary| expressionMentionsName(program, binary.left, name) or expressionMentionsName(program, binary.right, name),
        .conversion => |conversion| expressionMentionsName(program, conversion.operand, name),
        .string_count => |value| expressionMentionsName(program, value, name),
        .sequence_literal => |sequence| mentions: {
            for (sequence.values) |value| if (expressionMentionsName(program, value, name)) break :mentions true;
            break :mentions false;
        },
        .tuple_literal => |tuple| mentions: {
            for (tuple.elements) |element| if (expressionMentionsName(program, element.value, name)) break :mentions true;
            break :mentions false;
        },
        .index_access => |access| expressionMentionsName(program, access.base, name) or expressionMentionsName(program, access.index, name),
        .slice_access => |access| expressionMentionsName(program, access.base, name) or expressionMentionsName(program, access.start, name) or expressionMentionsName(program, access.end, name),
        .interpolated_string => |interpolation| mentions: {
            for (interpolation.parts) |part| switch (part) {
                .expression => |value| if (expressionMentionsName(program, value, name)) break :mentions true,
                .text => {},
            };
            break :mentions false;
        },
        .match_expression => |match_value| mentions: {
            if (expressionMentionsName(program, match_value.subject, name)) break :mentions true;
            for (match_value.branches) |branch| {
                if (branch.guard) |guard| if (expressionMentionsName(program, guard, name)) break :mentions true;
                if (branch.value) |value| if (expressionMentionsName(program, value, name)) break :mentions true;
                if (branch.statements) |statements| if (statementsMentionName(program, statements, name)) break :mentions true;
            }
            break :mentions false;
        },
        .integer, .floating, .boolean, .null_value, .string => false,
    };
}

fn anonymousNameMatches(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    if (!std.mem.endsWith(u8, candidate, requested) or candidate.len == requested.len) return false;
    return candidate[candidate.len - requested.len - 1] == '.';
}

fn conversionCost(self: *Analyzer, source: Types.Type, target: Types.Type) ?u8 {
    return Conversions.cost(self, source, target);
}

fn dominates(self: *Analyzer, better: []const Ast.Parameter, worse: []const Ast.Parameter, arguments: []const TypedValue) bool {
    var strictly_better = false;
    for (better, worse, arguments) |better_parameter, worse_parameter, argument| {
        const better_cost = conversionCost(self, argument.type, better_parameter.type) orelse return false;
        const worse_cost = conversionCost(self, argument.type, worse_parameter.type) orelse return false;
        if (better_cost > worse_cost) return false;
        if (better_cost < worse_cost) strictly_better = true;
    }
    return strictly_better;
}
