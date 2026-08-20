const std = @import("std");
const Ast = @import("../Ast.zig");
const Numeric = @import("../Numeric.zig");
const Result = @import("../Intrinsics/Result.zig");
const Source = @import("../Source.zig");
const Nested = @import("Nested.zig");
const Remap = @import("Remap.zig");
const Conformances = @import("Conformances.zig");
const TypedResources = @import("TypedResources.zig");
const InjectedSystems = @import("InjectedSystems.zig");
const EcsComponents = @import("EcsComponents.zig");
const WorkerSafety = @import("WorkerSafety.zig");
const ModuleScopes = @import("../ModuleScopes.zig");
const Packages = @import("../Packages.zig");

const Allocator = std.mem.Allocator;
const SpecializeError = Source.Error || Allocator.Error;

const Binding = struct {
    name: []const u8,
    type: Ast.Type,
};

const GenericContract = struct {
    argument: Ast.Type,
    protocol: Ast.Type,
};

fn nestedNameMatches(candidate: []const u8, short_name: []const u8) bool {
    return candidate.len > short_name.len and
        std.mem.endsWith(u8, candidate, short_name) and
        candidate[candidate.len - short_name.len - 1] == '.';
}

const FunctionSpecialization = struct {
    template_position: Source.Position,
    arguments: []const Ast.Type,
    name: []const u8,
    visiting: bool = true,
};

const StructureSpecialization = struct {
    template_position: Source.Position,
    arguments: []const Ast.Type,
    name: []const u8,
    type: Ast.Type,
    visiting: bool = true,
};

const EnumSpecialization = struct {
    template_position: Source.Position,
    arguments: []const Ast.Type,
    name: []const u8,
    type: Ast.Type,
    visiting: bool = true,
};

const SpecializedType = struct {
    template_position: Source.Position,
    arguments: []const Ast.Type,
};

const MethodSpecialization = struct {
    structure: Ast.Type,
    template_position: Source.Position,
    template_parameters: []const Ast.Parameter,
    arguments: []const Ast.Type,
    name: []const u8,
    visiting: bool = true,
};

pub const Specializer = struct {
    allocator: Allocator,
    source: Ast.Program = undefined,
    functions: std.ArrayList(Ast.Function) = .empty,
    structures: std.ArrayList(Ast.Structure) = .empty,
    enums: std.ArrayList(Ast.Enum) = .empty,
    type_names: std.ArrayList([]const u8) = .empty,
    function_types: std.ArrayList(Ast.FunctionType) = .empty,
    specializations: std.ArrayList(FunctionSpecialization) = .empty,
    structure_specializations: std.ArrayList(StructureSpecialization) = .empty,
    enum_specializations: std.ArrayList(EnumSpecialization) = .empty,
    method_specializations: std.ArrayList(MethodSpecialization) = .empty,
    specialization_file: ?usize = null,
    active_contracts: []const GenericContract = &.{},
    module_scope_roots: []const []const u8 = &.{},
    packages: ?Packages.Graph = null,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: Allocator) Specializer {
        return .{ .allocator = allocator };
    }

    pub fn specialize(self: *Specializer, program: Ast.Program) SpecializeError!Ast.Program {
        self.source = program;
        self.diagnostic = null;
        var found_main = false;
        for (program.functions) |function| {
            if (!std.mem.eql(u8, function.name, "main")) continue;
            if (found_main) return self.fail(function.name_position, "'main' cannot be overloaded");
            found_main = true;
            if (function.type_parameters.len != 0) return self.fail(function.name_position, "'main' cannot be generic");
        }
        try self.type_names.appendSlice(self.allocator, program.type_names);
        try self.validateConstraintDeclarations();
        try TypedResources.validateDeclarations(self);
        for (program.enums) |enumeration| {
            if (enumeration.type_parameters.len == 0) try self.enums.append(self.allocator, enumeration);
        }
        const concrete_enum_count = self.enums.items.len;
        for (0..concrete_enum_count) |enum_index| try self.rewriteEnumAt(enum_index, &.{});
        for (program.structures) |structure| {
            if (structure.type_parameters.len == 0 and !self.collectionNeedsSpecialization(structure) and
                !self.tupleNeedsSpecialization(structure))
            {
                try self.structures.append(self.allocator, structure);
            }
        }
        try TypedResources.prepareConcreteStorage(self);
        const concrete_structure_count = self.structures.items.len;
        for (0..concrete_structure_count) |structure_index| {
            try self.rewriteStructureAt(structure_index, &.{}, null);
            try TypedResources.markConcreteMethods(self, structure_index);
        }

        for (program.functions) |function| {
            if (function.type_parameters.len != 0) continue;
            var present = false;
            for (self.functions.items) |existing| {
                if (samePosition(existing.name_position, function.name_position)) {
                    present = true;
                    break;
                }
            }
            if (!present) try self.functions.append(self.allocator, function);
        }

        for (self.functions.items) |*function| {
            var locals: std.ArrayList(Binding) = .empty;
            function.parameters = try self.rewriteParameters(function.parameters, &.{}, &locals);
            function.return_type = try self.rewriteType(function.return_type, &.{}, function.name_position);
            _ = try self.internFunctionType(function.*);
        }

        var function_index: usize = 0;
        while (function_index < self.functions.items.len) : (function_index += 1) {
            var function = self.functions.items[function_index];
            var locals: std.ArrayList(Binding) = .empty;
            for (function.parameters) |parameter| try locals.append(self.allocator, .{ .name = parameter.name, .type = parameter.type });
            function.statements = try self.rewriteStatements(function.statements, &.{}, &locals);
            self.functions.items[function_index] = function;
        }

        try self.compactTypeNames();

        var result = program;
        result.type_names = try self.type_names.toOwnedSlice(self.allocator);
        result.generic_types = &.{};
        result.function_types = try self.function_types.toOwnedSlice(self.allocator);
        result.structures = try self.structures.toOwnedSlice(self.allocator);
        result.enums = try self.enums.toOwnedSlice(self.allocator);
        result.functions = try self.functions.toOwnedSlice(self.allocator);
        return result;
    }

    pub fn internFunctionType(self: *Specializer, function: Ast.Function) Allocator.Error!Ast.Type {
        const parameters = try self.allocator.alloc(Ast.FunctionType.ParameterType, function.parameters.len);
        for (function.parameters, 0..) |parameter, index| parameters[index] = .{
            .type = parameter.type,
            .mode = parameter.mode,
        };
        const candidate: Ast.FunctionType = .{
            .parameters = parameters,
            .return_type = function.return_type,
            .return_mode = function.return_mode,
        };
        for (self.function_types.items, 0..) |existing, index| {
            if (sameFunctionType(existing, candidate)) return .function(index);
        }
        const index = self.function_types.items.len;
        try self.function_types.append(self.allocator, candidate);
        return .function(index);
    }

    pub fn inferConcreteFunctionType(self: *Specializer, name: []const u8) SpecializeError!?Ast.Type {
        var match: ?Ast.Function = null;
        for (self.source.functions) |function| {
            if (function.type_parameters.len != 0 or !functionNameMatches(function.name, name)) continue;
            if (match != null) return null;
            match = function;
        }
        var function = match orelse return null;
        var present = false;
        for (self.functions.items) |existing| {
            if (samePosition(existing.name_position, function.name_position)) {
                present = true;
                break;
            }
        }
        if (!present) try self.functions.append(self.allocator, function);
        var locals: std.ArrayList(Binding) = .empty;
        function.parameters = try self.rewriteParameters(function.parameters, &.{}, &locals);
        function.return_type = try self.rewriteType(function.return_type, &.{}, function.name_position);
        return try self.internFunctionType(function);
    }

    fn compactTypeNames(self: *Specializer) SpecializeError!void {
        const map = try self.allocator.alloc(?Ast.Type, self.type_names.items.len);
        @memset(map, null);
        var names: std.ArrayList([]const u8) = .empty;
        for (self.structures.items) |structure| {
            for (self.type_names.items, 0..) |name, index| if (std.mem.eql(u8, structure.name, name)) {
                map[index] = .structure(names.items.len);
                try names.append(self.allocator, name);
                break;
            };
        }
        for (self.enums.items) |enumeration| {
            for (self.type_names.items, 0..) |name, index| if (std.mem.eql(u8, enumeration.name, name)) {
                map[index] = .structure(names.items.len);
                try names.append(self.allocator, name);
                break;
            };
        }
        for (self.structures.items) |*structure| {
            if (structure.base) |base| structure.base = Remap.concreteType(base, map);
            for (@constCast(structure.conformances)) |*conformance| conformance.* = Remap.concreteType(conformance.*, map);
            for (@constCast(structure.extension_conformances)) |*conformance| conformance.protocol = Remap.concreteType(conformance.protocol, map);
            if (structure.collection) |collection| structure.collection.?.element = Remap.concreteType(collection.element, map);
            if (structure.query_pattern) |pattern| structure.query_pattern = Remap.concreteType(pattern, map);
            for (@constCast(structure.fields)) |*field| {
                field.type = Remap.concreteType(field.type, map);
                if (field.default) |value| Remap.expressionTypes(value, map);
            }
            for (@constCast(structure.static_fields)) |*field| {
                field.type = Remap.concreteType(field.type, map);
                if (field.default) |value| Remap.expressionTypes(value, map);
            }
            for (@constCast(structure.constructors)) |*constructor| {
                for (@constCast(constructor.parameters)) |*parameter| parameter.type = Remap.concreteType(parameter.type, map);
                for (constructor.super_arguments) |argument| Remap.expressionTypes(argument, map);
                Remap.statementTypes(constructor.statements, map);
            }
            for (@constCast(structure.methods)) |*method| {
                for (@constCast(method.parameters)) |*parameter| parameter.type = Remap.concreteType(parameter.type, map);
                method.return_type = Remap.concreteType(method.return_type, map);
                Remap.statementTypes(method.statements, map);
            }
            if (structure.drop) |drop| Remap.statementTypes(drop.statements, map);
        }
        for (self.functions.items) |*function| {
            for (@constCast(function.parameters)) |*parameter| parameter.type = Remap.concreteType(parameter.type, map);
            function.return_type = Remap.concreteType(function.return_type, map);
            if (function.intrinsic) |*intrinsic| switch (intrinsic.*) {
                .system_adapter => |*adapter| {
                    if (adapter.receiver) |*receiver| {
                        receiver.type = Remap.concreteType(receiver.type, map);
                        receiver.source_type = Remap.concreteType(receiver.source_type, map);
                    }
                    if (adapter.receiver_type) |receiver_type| {
                        adapter.receiver_type = Remap.concreteType(receiver_type, map);
                    }
                    for (@constCast(adapter.dependencies)) |*dependency| {
                        dependency.type = Remap.concreteType(dependency.type, map);
                        dependency.source_type = Remap.concreteType(dependency.source_type, map);
                    }
                },
                else => {},
            };
            Remap.statementTypes(function.statements, map);
        }
        for (self.enums.items) |*enumeration| {
            for (@constCast(enumeration.variants)) |*variant| {
                for (@constCast(variant.associated_types)) |*associated_type| {
                    associated_type.* = Remap.concreteType(associated_type.*, map);
                }
            }
        }
        for (self.function_types.items) |*function_type| {
            for (@constCast(function_type.parameters)) |*parameter| {
                parameter.type = Remap.concreteType(parameter.type, map);
            }
            function_type.return_type = Remap.concreteType(function_type.return_type, map);
        }
        self.type_names = names;
    }

    fn rewriteEnumAt(self: *Specializer, enum_index: usize, arguments: []const Ast.Type) SpecializeError!void {
        var enumeration = self.enums.items[enum_index];
        enumeration.type_parameters = &.{};
        const variants = try self.allocator.alloc(Ast.EnumVariant, enumeration.variants.len);
        for (enumeration.variants, 0..) |variant, variant_index| {
            variants[variant_index] = variant;
            const associated_types = try self.allocator.alloc(Ast.Type, variant.associated_types.len);
            for (variant.associated_types, 0..) |associated_type, type_index| {
                associated_types[type_index] = try self.rewriteType(associated_type, arguments, variant.position);
            }
            variants[variant_index].associated_types = if (Result.hasVoidSuccess(enumeration, variant, associated_types)) &.{} else associated_types;
        }
        enumeration.variants = variants;
        self.enums.items[enum_index] = enumeration;
    }

    fn rewriteStructureAt(self: *Specializer, structure_index: usize, arguments: []const Ast.Type, specialization_file: ?usize) SpecializeError!void {
        var structure = self.structures.items[structure_index];
        structure.type_parameters = &.{};
        if (std.mem.startsWith(u8, structure.name, "GFX.ECS.Query<") and arguments.len == 1) {
            structure.query_pattern = arguments[0];
        }
        const self_type = self.typeForName(structure.name) orelse return error.InvalidSource;
        if (structure.base) |base| structure.base = try self.rewriteType(base, arguments, structure.base_position);
        const conformances = try self.allocator.alloc(Ast.Type, structure.conformances.len);
        for (structure.conformances, 0..) |conformance, index| {
            conformances[index] = try self.rewriteType(conformance, arguments, structure.name_position);
        }
        structure.conformances = conformances;
        const fields = try self.allocator.alloc(Ast.StructureField, structure.fields.len);
        for (structure.fields, 0..) |field, field_index| {
            fields[field_index] = field;
            fields[field_index].type = try self.rewriteType(field.type, arguments, field.name_position);
            if (field.default) |value| {
                var locals: std.ArrayList(Binding) = .empty;
                fields[field_index].default = try self.rewriteExpression(value, arguments, &locals);
            }
        }
        structure.fields = fields;
        const static_fields = try self.allocator.alloc(Ast.StructureField, structure.static_fields.len);
        for (structure.static_fields, 0..) |field, field_index| {
            static_fields[field_index] = field;
            static_fields[field_index].type = try self.rewriteType(field.type, arguments, field.name_position);
            if (field.default) |value| {
                var locals: std.ArrayList(Binding) = .empty;
                static_fields[field_index].default = try self.rewriteExpression(value, arguments, &locals);
            }
        }
        structure.static_fields = static_fields;
        if (structure.collection) |collection| structure.collection.?.element = try self.rewriteType(collection.element, arguments, structure.position);
        self.structures.items[structure_index] = structure;

        const constructors = try self.allocator.alloc(Ast.Constructor, structure.constructors.len);
        for (structure.constructors, 0..) |constructor, constructor_index| {
            constructors[constructor_index] = constructor;
            constructors[constructor_index].specialization_file = specialization_file;
            var locals: std.ArrayList(Binding) = .empty;
            try locals.append(self.allocator, .{ .name = "self", .type = self_type });
            constructors[constructor_index].parameters = try self.rewriteParameters(constructor.parameters, arguments, &locals);
            const super_arguments = try self.allocator.alloc(*Ast.Expression, constructor.super_arguments.len);
            for (constructor.super_arguments, 0..) |argument, index| {
                super_arguments[index] = try self.rewriteExpression(argument, arguments, &locals);
            }
            constructors[constructor_index].super_arguments = super_arguments;
            constructors[constructor_index].statements = try self.rewriteStatements(constructor.statements, arguments, &locals);
        }
        structure.constructors = constructors;
        var concrete_methods: std.ArrayList(Ast.Function) = .empty;
        for (structure.methods) |method| if (method.type_parameters.len == 0) {
            try concrete_methods.append(self.allocator, method);
        };
        structure.methods = try concrete_methods.toOwnedSlice(self.allocator);
        if (structure.drop) |*drop| {
            var locals: std.ArrayList(Binding) = .empty;
            try locals.append(self.allocator, .{ .name = "self", .type = self_type });
            drop.statements = try self.rewriteStatements(drop.statements, arguments, &locals);
        }
        self.structures.items[structure_index] = structure;
        const initial_method_count = structure.methods.len;
        for (0..initial_method_count) |method_index| {
            var method = self.structures.items[structure_index].methods[method_index];
            method.specialization_file = specialization_file;
            var locals: std.ArrayList(Binding) = .empty;
            try locals.append(self.allocator, .{ .name = "self", .type = self_type });
            method.parameters = try self.rewriteParameters(method.parameters, arguments, &locals);
            method.return_type = try self.rewriteType(method.return_type, arguments, method.name_position);
            method.statements = try self.rewriteStatements(method.statements, arguments, &locals);
            @constCast(self.structures.items[structure_index].methods)[method_index] = method;
        }
    }

    fn rewriteParameters(
        self: *Specializer,
        parameters: []const Ast.Parameter,
        arguments: []const Ast.Type,
        locals: *std.ArrayList(Binding),
    ) SpecializeError![]const Ast.Parameter {
        const rewritten = try self.allocator.alloc(Ast.Parameter, parameters.len);
        for (parameters, 0..) |parameter, index| {
            rewritten[index] = parameter;
            rewritten[index].type = try self.rewriteType(parameter.type, arguments, parameter.position);
            if (parameter.default) |value| rewritten[index].default = try self.rewriteExpression(value, arguments, locals);
            var found = false;
            for (locals.items) |*local| if (std.mem.eql(u8, local.name, parameter.name)) {
                local.type = rewritten[index].type;
                found = true;
                break;
            };
            if (!found) try locals.append(self.allocator, .{ .name = parameter.name, .type = rewritten[index].type });
        }
        return rewritten;
    }

    fn rewriteStatements(
        self: *Specializer,
        statements: []const Ast.Statement,
        arguments: []const Ast.Type,
        locals: *std.ArrayList(Binding),
    ) SpecializeError![]const Ast.Statement {
        const rewritten = try self.allocator.alloc(Ast.Statement, statements.len);
        for (statements, 0..) |statement, index| rewritten[index] = switch (statement) {
            .variable_declaration => |declaration| value: {
                var copy = declaration;
                if (copy.annotation) |annotation| copy.annotation = try self.rewriteType(annotation, arguments, copy.name_position);
                if (copy.initializer) |initializer| copy.initializer = try self.rewriteExpression(initializer, arguments, locals);
                const type_value = copy.annotation orelse if (copy.initializer) |initializer|
                    self.inferExpressionType(initializer, locals.items)
                else
                    null;
                if (type_value) |known| try locals.append(self.allocator, .{ .name = copy.name, .type = known });
                break :value .{ .variable_declaration = copy };
            },
            .assignment_statement => |assignment| value: {
                var copy = assignment;
                if (copy.value) |expression| copy.value = try self.rewriteExpression(expression, arguments, locals);
                for (@constCast(copy.target.indices)) |*target_index| target_index.value = try self.rewriteExpression(target_index.value, arguments, locals);
                if (copy.target.type_arguments.len != 0) {
                    const type_arguments = try self.allocator.alloc(Ast.Type, copy.target.type_arguments.len);
                    for (copy.target.type_arguments, 0..) |type_argument, type_index| {
                        type_arguments[type_index] = try self.rewriteType(type_argument, arguments, copy.target.name_position);
                    }
                    const base = self.typeForName(copy.target.name) orelse return self.fail(copy.target.name_position, "unknown generic type");
                    copy.target.name = self.typeName(try self.instantiateStructure(base, type_arguments, copy.target.name_position));
                    copy.target.type_arguments = &.{};
                }
                break :value .{ .assignment_statement = copy };
            },
            .return_statement => |statement_value| value: {
                var copy = statement_value;
                if (copy.value) |expression| copy.value = try self.rewriteExpression(expression, arguments, locals);
                break :value .{ .return_statement = copy };
            },
            .expression_statement => |expression| .{ .expression_statement = try self.rewriteExpression(expression, arguments, locals) },
            .print_statement => |print_statement| value: {
                var copy = print_statement;
                const values = try self.allocator.alloc(*Ast.Expression, copy.values.len);
                for (copy.values, 0..) |expression, value_index| values[value_index] = try self.rewriteExpression(expression, arguments, locals);
                copy.values = values;
                break :value .{ .print_statement = copy };
            },
            .assert_statement => |assertion| value: {
                var copy = assertion;
                copy.condition = try self.rewriteExpression(copy.condition, arguments, locals);
                copy.message = try self.rewriteExpression(copy.message, arguments, locals);
                break :value .{ .assert_statement = copy };
            },
            .panic_statement => |effect| value: {
                var copy = effect;
                copy.value = try self.rewriteExpression(copy.value, arguments, locals);
                break :value .{ .panic_statement = copy };
            },
            .if_statement => |conditional| value: {
                var copy = conditional;
                const branches = try self.allocator.alloc(Ast.ConditionalBranch, conditional.branches.len);
                for (conditional.branches, 0..) |branch, branch_index| {
                    branches[branch_index] = branch;
                    const source = try self.rewriteExpression(branch.condition.source(), arguments, locals);
                    branches[branch_index].condition = switch (branch.condition) {
                        .expression => .{ .expression = source },
                        .binding => |binding| binding_value: {
                            var binding_copy = binding;
                            binding_copy.source = source;
                            break :binding_value .{ .binding = binding_copy };
                        },
                    };
                    const local_count = locals.items.len;
                    if (branches[branch_index].condition == .binding) {
                        const binding = branches[branch_index].condition.binding;
                        if (self.inferExpressionType(source, locals.items)) |source_type| {
                            try locals.append(self.allocator, .{ .name = binding.name, .type = source_type.optionalChild() orelse source_type });
                        }
                    }
                    branches[branch_index].statements = try self.rewriteStatements(branch.statements, arguments, locals);
                    locals.shrinkRetainingCapacity(local_count);
                }
                copy.branches = branches;
                if (conditional.else_statements) |nested| {
                    const local_count = locals.items.len;
                    copy.else_statements = try self.rewriteStatements(nested, arguments, locals);
                    locals.shrinkRetainingCapacity(local_count);
                }
                break :value .{ .if_statement = copy };
            },
            .while_statement => |loop| value: {
                var copy = loop;
                const source = try self.rewriteExpression(loop.condition.source(), arguments, locals);
                copy.condition = switch (loop.condition) {
                    .expression => .{ .expression = source },
                    .binding => |binding| binding_value: {
                        var binding_copy = binding;
                        binding_copy.source = source;
                        break :binding_value .{ .binding = binding_copy };
                    },
                };
                const local_count = locals.items.len;
                if (copy.condition == .binding) {
                    const binding = copy.condition.binding;
                    if (self.inferExpressionType(source, locals.items)) |source_type| {
                        try locals.append(self.allocator, .{ .name = binding.name, .type = source_type.optionalChild() orelse source_type });
                    }
                }
                copy.statements = try self.rewriteStatements(loop.statements, arguments, locals);
                locals.shrinkRetainingCapacity(local_count);
                break :value .{ .while_statement = copy };
            },
            .for_statement => |loop| value: {
                var copy = loop;
                const local_count = locals.items.len;
                const element_type: ?Ast.Type = switch (loop.source) {
                    .collection => |source| element: {
                        const rewritten_source = try self.rewriteExpression(source, arguments, locals);
                        copy.source = .{ .collection = rewritten_source };
                        const source_type = self.inferExpressionType(rewritten_source, locals.items) orelse break :element null;
                        const structure = self.structureForType(source_type) orelse break :element null;
                        if (structure.query_pattern) |pattern_type| {
                            const pattern = self.structureForType(pattern_type) orelse break :element null;
                            if (loop.bindings.len == pattern.fields.len) {
                                for (loop.bindings, pattern.fields) |binding, field| {
                                    try locals.append(self.allocator, .{ .name = binding.name, .type = field.type });
                                }
                            }
                            break :element null;
                        }
                        break :element if (structure.collection) |collection| collection.element else null;
                    },
                    .range => |range| range_value: {
                        copy.source = .{ .range = .{
                            .start = try self.rewriteExpression(range.start, arguments, locals),
                            .end = try self.rewriteExpression(range.end, arguments, locals),
                        } };
                        break :range_value .int;
                    },
                };
                if (element_type) |type_value| try locals.append(self.allocator, .{ .name = loop.name, .type = type_value });
                copy.statements = try self.rewriteStatements(loop.statements, arguments, locals);
                locals.shrinkRetainingCapacity(local_count);
                break :value .{ .for_statement = copy };
            },
            .mutex_statement => |mutex| value: {
                var copy = mutex;
                const local_count = locals.items.len;
                copy.statements = try self.rewriteStatements(mutex.statements, arguments, locals);
                locals.shrinkRetainingCapacity(local_count);
                break :value .{ .mutex_statement = copy };
            },
            .break_statement => |position| .{ .break_statement = position },
            .continue_statement => |position| .{ .continue_statement = position },
        };
        return rewritten;
    }

    fn rewriteExpression(
        self: *Specializer,
        expression: *const Ast.Expression,
        arguments: []const Ast.Type,
        locals: *std.ArrayList(Binding),
    ) SpecializeError!*Ast.Expression {
        const result = try self.allocator.create(Ast.Expression);
        result.* = expression.*;
        result.value = switch (expression.value) {
            .call => |call| value: {
                var copy = call;
                try Nested.specializeCall(self, &copy, arguments);
                if (copy.receiver) |receiver| copy.receiver = try self.rewriteExpression(receiver, arguments, locals);
                const positional = try self.allocator.alloc(*Ast.Expression, copy.arguments.len);
                for (copy.arguments, 0..) |argument, index| positional[index] = try self.rewriteExpression(argument, arguments, locals);
                copy.arguments = positional;
                const named = try self.allocator.alloc(Ast.Expression.NamedArgument, copy.named_arguments.len);
                for (copy.named_arguments, 0..) |named_argument, index| {
                    named[index] = named_argument;
                    named[index].value = try self.rewriteExpression(named_argument.value, arguments, locals);
                }
                copy.named_arguments = named;
                const type_arguments = try self.allocator.alloc(Ast.Type, copy.type_arguments.len);
                for (copy.type_arguments, 0..) |type_argument, index| type_arguments[index] = try self.rewriteType(type_argument, arguments, copy.name_position);
                copy.type_arguments = type_arguments;
                if (copy.receiver != null and self.callUsesGenericContract(copy, locals.items)) {
                    copy.compiler_generated = true;
                }
                if (copy.receiver == null and std.mem.eql(u8, copy.name, "C.function_address") and copy.type_arguments.len != 0) {
                    if (copy.arguments.len != 1 or copy.named_arguments.len != 0 or copy.arguments[0].value != .identifier) {
                        return self.fail(copy.name_position, "C.function_address<T...> expects one named generic function");
                    }
                    const function_name = copy.arguments[0].value.identifier;
                    var selected: ?Ast.Function = null;
                    for (self.source.functions) |candidate| {
                        const name_matches = std.mem.eql(u8, candidate.name, function_name) or
                            (candidate.name.len > function_name.len and std.mem.endsWith(u8, candidate.name, function_name) and
                                candidate.name[candidate.name.len - function_name.len - 1] == '.');
                        if (!name_matches or
                            candidate.type_parameters.len != copy.type_arguments.len or !functionVisible(self.packages, self.module_scope_roots, copy, candidate)) continue;
                        if (selected != null) {
                            const message = try std.fmt.allocPrint(
                                self.allocator,
                                "generic function reference '{s}' is ambiguous",
                                .{function_name},
                            );
                            return self.fail(copy.arguments[0].position, message);
                        }
                        selected = candidate;
                    }
                    const template = selected orelse {
                        const message = try std.fmt.allocPrint(
                            self.allocator,
                            "unknown generic function '{s}' accepting {d} type arguments",
                            .{ function_name, copy.type_arguments.len },
                        );
                        return self.fail(copy.arguments[0].position, message);
                    };
                    copy.arguments[0].value.identifier = try self.instantiate(template, copy.type_arguments, copy.name_position);
                    const parameter_types = try self.allocator.alloc(Ast.FunctionType.ParameterType, template.parameters.len);
                    for (template.parameters, 0..) |parameter, parameter_index| parameter_types[parameter_index] = .{
                        .type = try self.rewriteType(parameter.type, copy.type_arguments, parameter.position),
                        .mode = parameter.mode,
                    };
                    const signature: Ast.FunctionType = .{
                        .parameters = parameter_types,
                        .return_type = try self.rewriteType(template.return_type, copy.type_arguments, template.name_position),
                        .return_mode = template.return_mode,
                    };
                    var known_signature = false;
                    for (self.function_types.items) |existing| if (sameFunctionType(existing, signature)) {
                        known_signature = true;
                        break;
                    };
                    if (!known_signature) try self.function_types.append(self.allocator, signature);
                    copy.type_arguments = &.{};
                }
                if (copy.receiver) |receiver| if (receiver.value == .identifier) {
                    if (self.typeForName(receiver.value.identifier)) |receiver_type| {
                        if (self.enumTemplateForType(receiver_type)) |template| {
                            const message = try std.fmt.allocPrint(
                                self.allocator,
                                "generic enum '{s}' requires {d} type argument{s}",
                                .{ template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s" },
                            );
                            return self.fail(receiver.position, message);
                        }
                    }
                };
                if (copy.receiver == null and std.mem.eql(u8, copy.name, "map_error")) {
                    copy.result_type = try self.specializeMapError(copy, locals.items);
                    copy.type_arguments = &.{};
                    break :value .{ .call = copy };
                }
                if (copy.receiver == null and std.mem.eql(u8, copy.name, "reflect")) {
                    break :value .{ .call = copy };
                }
                if (copy.receiver != null) {
                    _ = try InjectedSystems.rewriteRegistration(self, &copy, locals.items);
                    if (try self.specializeMethodCall(copy, locals.items)) |name| {
                        copy.name = name;
                        copy.type_arguments = &.{};
                    }
                }
                if (copy.receiver == null) {
                    if (try self.specializeStructureCall(copy)) |specialized| {
                        copy.name = specialized;
                        copy.type_arguments = &.{};
                        break :value .{ .call = copy };
                    }
                }
                if (copy.receiver == null and copy.named_arguments.len == 0) {
                    if (try self.specializeCall(copy, locals.items)) |name| {
                        copy.name = name;
                        copy.type_arguments = &.{};
                    }
                }
                break :value .{ .call = copy };
            },
            .cascade => |cascade| value: {
                var copy = cascade;
                copy.receiver = try self.rewriteExpression(cascade.receiver, arguments, locals);
                const operations = try self.allocator.alloc(Ast.Expression.Cascade.Operation, cascade.operations.len);
                for (cascade.operations, 0..) |operation, index| operations[index] = switch (operation) {
                    .method_call => |method| operation: {
                        var method_copy = method;
                        const method_type_arguments = try self.allocator.alloc(Ast.Type, method.type_arguments.len);
                        for (method.type_arguments, 0..) |type_argument, type_index| {
                            method_type_arguments[type_index] = try self.rewriteType(type_argument, arguments, method.name_position);
                        }
                        method_copy.type_arguments = method_type_arguments;
                        const method_arguments = try self.allocator.alloc(*Ast.Expression, method.arguments.len);
                        for (method.arguments, 0..) |argument, argument_index| {
                            method_arguments[argument_index] = try self.rewriteExpression(argument, arguments, locals);
                        }
                        method_copy.arguments = method_arguments;
                        const method_named_arguments = try self.allocator.alloc(Ast.Expression.NamedArgument, method.named_arguments.len);
                        for (method.named_arguments, 0..) |argument, argument_index| {
                            method_named_arguments[argument_index] = argument;
                            method_named_arguments[argument_index].value = try self.rewriteExpression(argument.value, arguments, locals);
                        }
                        method_copy.named_arguments = method_named_arguments;
                        var call: Ast.Expression.Call = .{
                            .name = method_copy.name,
                            .name_position = method_copy.name_position,
                            .receiver = copy.receiver,
                            .compiler_generated = method_copy.compiler_generated,
                            .arguments = method_copy.arguments,
                            .named_arguments = method_copy.named_arguments,
                            .type_arguments = method_copy.type_arguments,
                        };
                        _ = try InjectedSystems.rewriteRegistration(self, &call, locals.items);
                        method_copy.name = call.name;
                        method_copy.compiler_generated = call.compiler_generated;
                        method_copy.arguments = call.arguments;
                        method_copy.named_arguments = call.named_arguments;
                        if (try self.specializeMethodCall(call, locals.items)) |name| {
                            method_copy.name = name;
                            method_copy.type_arguments = &.{};
                        }
                        break :operation .{ .method_call = method_copy };
                    },
                    .field_assignment => |field| operation: {
                        var field_copy = field;
                        field_copy.value = try self.rewriteExpression(field.value, arguments, locals);
                        break :operation .{ .field_assignment = field_copy };
                    },
                };
                copy.operations = operations;
                break :value .{ .cascade = copy };
            },
            .field_access => |access| value: {
                var copy = access;
                copy.base = try self.rewriteExpression(access.base, arguments, locals);
                break :value .{ .field_access = copy };
            },
            .unary => |unary| value: {
                var copy = unary;
                copy.operand = try self.rewriteExpression(unary.operand, arguments, locals);
                if (unary.try_alternative) |alternative| {
                    var alternative_copy = alternative;
                    const local_count = locals.items.len;
                    if (alternative.statements) |statements| {
                        alternative_copy.statements = try self.rewriteStatements(statements, arguments, locals);
                    }
                    if (alternative.message) |message| {
                        alternative_copy.message = try self.rewriteExpression(message, arguments, locals);
                    }
                    locals.shrinkRetainingCapacity(local_count);
                    copy.try_alternative = alternative_copy;
                }
                break :value .{ .unary = copy };
            },
            .binary => |binary| value: {
                var copy = binary;
                copy.left = try self.rewriteExpression(binary.left, arguments, locals);
                copy.right = try self.rewriteExpression(binary.right, arguments, locals);
                break :value .{ .binary = copy };
            },
            .conversion => |conversion| value: {
                var copy = conversion;
                copy.target = try self.rewriteType(copy.target, arguments, copy.operator_position);
                copy.operand = try self.rewriteExpression(copy.operand, arguments, locals);
                break :value .{ .conversion = copy };
            },
            .string_count => |operand| .{ .string_count = try self.rewriteExpression(operand, arguments, locals) },
            .sequence_literal => |literal| value: {
                const copy = try self.allocator.alloc(*Ast.Expression, literal.values.len);
                for (literal.values, 0..) |item, index| copy[index] = try self.rewriteExpression(item, arguments, locals);
                break :value .{ .sequence_literal = .{
                    .values = copy,
                    .inferred_type = if (literal.inferred_type) |type_value| try self.rewriteType(type_value, arguments, expression.position) else null,
                } };
            },
            .tuple_literal => |literal| value: {
                var copy = literal;
                const elements = try self.allocator.alloc(Ast.Expression.TupleLiteral.Element, literal.elements.len);
                for (literal.elements, 0..) |element, index| {
                    elements[index] = element;
                    elements[index].value = try self.rewriteExpression(element.value, arguments, locals);
                }
                copy.elements = elements;
                copy.placeholder_type = try self.rewriteType(copy.placeholder_type, arguments, expression.position);
                break :value .{ .tuple_literal = copy };
            },
            .index_access => |access| value: {
                var copy = access;
                copy.base = try self.rewriteExpression(access.base, arguments, locals);
                copy.index = try self.rewriteExpression(access.index, arguments, locals);
                break :value .{ .index_access = copy };
            },
            .slice_access => |access| value: {
                var copy = access;
                copy.base = try self.rewriteExpression(access.base, arguments, locals);
                copy.start = try self.rewriteExpression(access.start, arguments, locals);
                copy.end = try self.rewriteExpression(access.end, arguments, locals);
                break :value .{ .slice_access = copy };
            },
            .interpolated_string => |interpolated| value: {
                const parts = try self.allocator.alloc(Ast.Expression.StringPart, interpolated.parts.len);
                for (interpolated.parts, 0..) |part, index| parts[index] = switch (part) {
                    .text => |text| .{ .text = text },
                    .expression => |nested| .{ .expression = try self.rewriteExpression(nested, arguments, locals) },
                };
                break :value .{ .interpolated_string = .{ .parts = parts } };
            },
            .match_expression => |match_value| value: {
                var copy = match_value;
                copy.subject = try self.rewriteExpression(match_value.subject, arguments, locals);
                const branches = try self.allocator.alloc(Ast.Expression.MatchBranch, match_value.branches.len);
                for (match_value.branches, 0..) |branch, index| {
                    branches[index] = branch;
                    const local_count = locals.items.len;
                    if (branch.guard) |guard| branches[index].guard = try self.rewriteExpression(guard, arguments, locals);
                    if (branch.value) |nested| branches[index].value = try self.rewriteExpression(nested, arguments, locals);
                    if (branch.statements) |statements| branches[index].statements = try self.rewriteStatements(statements, arguments, locals);
                    locals.shrinkRetainingCapacity(local_count);
                }
                copy.branches = branches;
                break :value .{ .match_expression = copy };
            },
            .generic_reference => |reference| value: {
                const base = self.typeForName(reference.name) orelse {
                    const message = try std.fmt.allocPrint(self.allocator, "unknown generic type '{s}'", .{reference.name});
                    return self.fail(expression.position, message);
                };
                const type_arguments = try self.allocator.alloc(Ast.Type, reference.type_arguments.len);
                for (reference.type_arguments, 0..) |type_argument, index| {
                    type_arguments[index] = try self.rewriteType(type_argument, arguments, expression.position);
                }
                const specialized = if (self.enumTemplateForType(base) != null or self.enumForType(base) != null)
                    try self.instantiateEnum(base, type_arguments, expression.position)
                else
                    try self.instantiateStructure(base, type_arguments, expression.position);
                break :value .{ .identifier = self.typeName(specialized) };
            },
            else => expression.value,
        };
        return result;
    }

    fn specializeCall(self: *Specializer, call: Ast.Expression.Call, locals: []const Binding) SpecializeError!?[]const u8 {
        if (std.mem.eql(u8, call.name, "C.load") or std.mem.eql(u8, call.name, "C.store") or
            std.mem.eql(u8, call.name, "C.object_from_address")) return null;
        const actual_types = try self.allocator.alloc(Ast.Type, call.arguments.len);
        for (call.arguments, 0..) |argument, index| {
            actual_types[index] = self.inferExpressionType(argument, locals) orelse contextual_type: {
                if (call.type_arguments.len == 0) return null;
                var contextual: ?Ast.Type = null;
                for (self.source.functions) |function| {
                    if (!std.mem.eql(u8, function.name, call.name) or function.type_parameters.len != call.type_arguments.len or
                        !parametersAcceptArity(function.parameters, call.arguments.len) or !functionVisible(self.packages, self.module_scope_roots, call, function)) continue;
                    const candidate = try self.rewriteType(function.parameters[index].type, call.type_arguments, call.arguments[index].position);
                    if (contextual != null and contextual.? != candidate) {
                        contextual = null;
                        break;
                    }
                    contextual = candidate;
                }
                break :contextual_type contextual orelse return self.fail(call.arguments[index].position, "cannot determine argument type for generic specialization");
            };
        }

        if (call.type_arguments.len == 0 and self.hasCompatibleConcrete(call, actual_types)) return null;

        var selected: ?*const Ast.Function = null;
        var selected_arguments: []const Ast.Type = &.{};
        var selected_cost: usize = std.math.maxInt(usize);
        var is_ambiguous = false;
        var saw_generic = false;
        var saw_arity = false;
        for (self.source.functions) |*function| {
            if (function.type_parameters.len == 0 or !std.mem.eql(u8, function.name, call.name) or !functionVisible(self.packages, self.module_scope_roots, call, function.*)) continue;
            saw_generic = true;
            if (call.type_arguments.len != 0) {
                if (call.type_arguments.len != function.type_parameters.len) continue;
                saw_arity = true;
                if (!parametersAcceptArity(function.parameters, actual_types.len)) continue;
                if (!self.argumentsMatch(function.parameters, actual_types, call.type_arguments)) continue;
                const cost = self.argumentAdaptationCost(function.parameters, actual_types);
                if (cost < selected_cost) {
                    selected = function;
                    selected_arguments = call.type_arguments;
                    selected_cost = cost;
                    is_ambiguous = false;
                } else if (cost == selected_cost) is_ambiguous = true;
                continue;
            }
            if (!parametersAcceptArity(function.parameters, actual_types.len)) continue;
            saw_arity = true;
            const inferred = try self.inferTypeArguments(function.*, actual_types) orelse continue;
            const cost = self.argumentAdaptationCost(function.parameters, actual_types);
            if (cost < selected_cost) {
                selected = function;
                selected_arguments = inferred;
                selected_cost = cost;
                is_ambiguous = false;
            } else if (cost == selected_cost) is_ambiguous = true;
        }

        if (is_ambiguous) return self.ambiguous(call.name_position, call.name);
        if (selected) |template| return try self.instantiate(template.*, selected_arguments, call.name_position);
        if (!saw_generic) {
            if (call.type_arguments.len == 0) return null;
            const message = try std.fmt.allocPrint(self.allocator, "function '{s}' does not accept type arguments", .{call.name});
            return self.fail(call.name_position, message);
        }
        if (call.type_arguments.len != 0 and !saw_arity) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "generic function '{s}' has no overload accepting {d} type arguments",
                .{ call.name, call.type_arguments.len },
            );
            return self.fail(call.name_position, message);
        }
        const message = try std.fmt.allocPrint(
            self.allocator,
            "generic function '{s}' cannot infer all type arguments; use explicit '<...>'",
            .{call.name},
        );
        return self.fail(call.name_position, message);
    }

    fn specializeMapError(self: *Specializer, call: Ast.Expression.Call, locals: []const Binding) SpecializeError!Ast.Type {
        if (call.arguments.len != 2 or call.named_arguments.len != 0) {
            return self.fail(call.name_position, "'map_error' expects a Result and one named transformation function");
        }
        const source_type = self.inferExpressionType(call.arguments[0], locals) orelse {
            return self.fail(call.arguments[0].position, "cannot determine the Result type passed to 'map_error'");
        };
        const source = self.enumForType(source_type) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "'map_error' expects 'Result<T,E>', found '{s}'", .{self.typeName(source_type)});
            return self.fail(call.arguments[0].position, message);
        };
        const success_type = Result.successType(source) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "'map_error' expects 'Result<T,E>', found '{s}'", .{self.typeName(source_type)});
            return self.fail(call.arguments[0].position, message);
        };
        const error_type = Result.errorType(source).?;
        if (call.arguments[1].value != .identifier) {
            return self.fail(call.arguments[1].position, "'map_error' transformation must be a named function");
        }
        const expected_count: usize = if (success_type == .void) 2 else 3;
        if (call.type_arguments.len != 0 and call.type_arguments.len != expected_count) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "'map_error' expects {d} explicit type arguments matching its Result and transformation",
                .{expected_count},
            );
            return self.fail(call.name_position, message);
        }
        const explicit_target: ?Ast.Type = if (call.type_arguments.len == 0) null else call.type_arguments[expected_count - 1];
        if (call.type_arguments.len != 0) {
            const source_arguments: []const Ast.Type = if (success_type == .void)
                &.{error_type}
            else
                &.{ success_type, error_type };
            if (!std.mem.eql(Ast.Type, call.type_arguments[0 .. expected_count - 1], source_arguments)) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "'map_error' expects {d} explicit type arguments matching its Result and transformation",
                    .{expected_count},
                );
                return self.fail(call.name_position, message);
            }
        }
        const transformer_name = call.arguments[1].value.identifier;
        var found_name = false;
        var transformer: ?Ast.Function = null;
        for (self.functions.items) |function| {
            if (!std.mem.eql(u8, function.name, transformer_name)) continue;
            found_name = true;
            if (function.parameters.len != 1 or function.parameters[0].type != error_type or function.return_type == .void) continue;
            if (explicit_target) |target| if (function.return_type != target) continue;
            if (transformer != null) return self.fail(call.arguments[1].position, "'map_error' transformation function is ambiguous");
            transformer = function;
        }
        if (!found_name) {
            const message = try std.fmt.allocPrint(self.allocator, "unknown transformation function '{s}'", .{transformer_name});
            return self.fail(call.arguments[1].position, message);
        }
        const function = transformer orelse {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "'map_error' transformation must have signature 'func({s}) F'",
                .{self.typeName(error_type)},
            );
            return self.fail(call.arguments[1].position, message);
        };
        const result_base = self.typeForName(Result.name) orelse return error.InvalidSource;
        return self.instantiateEnum(result_base, &.{ success_type, function.return_type }, call.name_position);
    }

    fn specializeMethodCall(self: *Specializer, call: Ast.Expression.Call, locals: []const Binding) SpecializeError!?[]const u8 {
        const receiver_type = if (call.receiver.?.value == .identifier)
            self.typeForName(call.receiver.?.value.identifier) orelse self.inferExpressionType(call.receiver.?, locals) orelse return null
        else
            self.inferExpressionType(call.receiver.?, locals) orelse return null;
        const concrete_receiver = receiver_type.optionalChild() orelse receiver_type;
        const structure = self.structureForType(concrete_receiver) orelse return null;
        const source_structure = self.sourceStructureForType(concrete_receiver) orelse return null;
        const actual_types = try self.allocator.alloc(Ast.Type, call.arguments.len + call.named_arguments.len);
        for (call.arguments, 0..) |argument, index| {
            actual_types[index] = self.inferExpressionType(argument, locals) orelse {
                if (call.type_arguments.len == 0) return null;
                return self.fail(call.arguments[index].position, "cannot determine argument type for generic method specialization");
            };
        }
        for (call.named_arguments, 0..) |argument, index| {
            actual_types[call.arguments.len + index] = self.inferExpressionType(argument.value, locals) orelse {
                if (call.type_arguments.len == 0) return null;
                return self.fail(argument.value.position, "cannot determine named argument type for generic method specialization");
            };
        }
        if (call.type_arguments.len == 0) {
            for (structure.methods) |method| {
                if (!std.mem.eql(u8, method.name, call.name) or !methodVisible(self.packages, self.module_scope_roots, call, source_structure, method)) continue;
                const ordered = try self.orderNamedMethodArguments(method.parameters, call, actual_types) orelse continue;
                if (self.argumentsMatch(method.parameters, ordered, &.{})) return null;
            }
        }

        var selected: ?Ast.Function = null;
        var selected_arguments: []const Ast.Type = &.{};
        var saw_generic = false;
        var saw_type_arity = false;
        for (source_structure.methods) |method| {
            if (method.type_parameters.len == 0 or !std.mem.eql(u8, method.name, call.name) or !methodVisible(self.packages, self.module_scope_roots, call, source_structure, method)) continue;
            saw_generic = true;
            const ordered = try self.orderNamedMethodArguments(method.parameters, call, actual_types) orelse continue;
            if (call.type_arguments.len != 0) {
                if (call.type_arguments.len != method.type_parameters.len) continue;
                saw_type_arity = true;
                if (!parametersAcceptArity(method.parameters, ordered.len) or
                    !self.argumentsMatch(method.parameters, ordered, call.type_arguments)) continue;
                if (selected != null) return self.ambiguousMethod(call.name_position, call.name);
                selected = method;
                selected_arguments = call.type_arguments;
            } else {
                if (!parametersAcceptArity(method.parameters, ordered.len)) continue;
                saw_type_arity = true;
                const inferred = try self.inferTypeArguments(method, ordered) orelse continue;
                if (selected != null) return self.ambiguousMethod(call.name_position, call.name);
                selected = method;
                selected_arguments = inferred;
            }
        }
        if (selected) |template| return try self.instantiateMethod(concrete_receiver, template, selected_arguments, call.name_position);
        if (!saw_generic) {
            if (call.type_arguments.len == 0) return null;
            const message = try std.fmt.allocPrint(self.allocator, "method '{s}' does not accept type arguments", .{call.name});
            return self.fail(call.name_position, message);
        }
        if (call.type_arguments.len != 0 and !saw_type_arity) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "generic method '{s}' has no overload accepting {d} type arguments",
                .{ call.name, call.type_arguments.len },
            );
            return self.fail(call.name_position, message);
        }
        const message = try std.fmt.allocPrint(
            self.allocator,
            "generic method '{s}' cannot infer all type arguments; use explicit '<...>'",
            .{call.name},
        );
        return self.fail(call.name_position, message);
    }

    fn orderNamedMethodArguments(
        self: *Specializer,
        parameters: []const Ast.Parameter,
        call: Ast.Expression.Call,
        actual_types: []const Ast.Type,
    ) SpecializeError!?[]const Ast.Type {
        if (call.named_arguments.len == 0) return actual_types;
        if (actual_types.len > parameters.len) return null;
        const ordered = try self.allocator.alloc(Ast.Type, actual_types.len);
        @memset(ordered, .void);
        for (call.arguments, 0..) |_, index| ordered[index] = actual_types[index];
        for (call.named_arguments, 0..) |argument, named_index| {
            const parameter_index = for (parameters, 0..) |parameter, index| {
                if (std.mem.eql(u8, parameter.name, argument.name)) break index;
            } else return null;
            if (parameter_index < call.arguments.len or parameter_index >= actual_types.len) return null;
            ordered[parameter_index] = actual_types[call.arguments.len + named_index];
        }
        for (ordered) |type_value| if (type_value == .void) return null;
        return ordered;
    }

    pub fn instantiateMethod(
        self: *Specializer,
        structure_type: Ast.Type,
        template: Ast.Function,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError![]const u8 {
        const previous_specialization_file = self.specialization_file;
        self.specialization_file = previous_specialization_file orelse position.file;
        defer self.specialization_file = previous_specialization_file;
        for (arguments) |argument| if (argument == .void) return self.fail(position, "'void' is not a generic type argument");
        try self.validateArguments(template.type_parameters, arguments, position);
        WorkerSafety.validateSubmission(self, structure_type, template, arguments, position) catch |err| switch (err) {
            error.WorkerUnsafe => return error.InvalidSource,
            error.InvalidSource => return error.InvalidSource,
            error.OutOfMemory => return error.OutOfMemory,
        };
        for (self.method_specializations.items) |specialization| {
            if (specialization.structure != structure_type or
                !samePosition(specialization.template_position, template.name_position) or
                !sameTemplateParameters(specialization.template_parameters, template.parameters)) continue;
            if (std.mem.eql(Ast.Type, specialization.arguments, arguments)) return specialization.name;
            if (specialization.visiting) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "generic method '{s}' recursively expands with different type arguments",
                    .{template.name},
                );
                return self.fail(position, message);
            }
        }
        var name = try self.specializationName(template.name, arguments);
        var overload_index: usize = 0;
        for (self.method_specializations.items) |specialization| {
            if (specialization.structure != structure_type or !std.mem.eql(Ast.Type, specialization.arguments, arguments)) continue;
            if (std.mem.eql(u8, specialization.name, name) or
                (specialization.name.len > name.len and std.mem.startsWith(u8, specialization.name, name) and
                    specialization.name[name.len] == '#')) overload_index += 1;
        }
        if (overload_index != 0) name = try std.fmt.allocPrint(self.allocator, "{s}#{d}", .{ name, overload_index });
        const specialization_index = self.method_specializations.items.len;
        try self.method_specializations.append(self.allocator, .{
            .structure = structure_type,
            .template_position = template.name_position,
            .template_parameters = template.parameters,
            .arguments = try self.allocator.dupe(Ast.Type, arguments),
            .name = name,
        });
        var concrete = template;
        concrete.name = name;
        concrete.type_parameters = &.{};
        concrete.specialization_file = self.specialization_file;
        var locals: std.ArrayList(Binding) = .empty;
        try locals.append(self.allocator, .{ .name = "self", .type = structure_type });
        concrete.parameters = try self.rewriteParameters(template.parameters, arguments, &locals);
        concrete.return_type = try self.rewriteType(template.return_type, arguments, template.name_position);
        concrete.intrinsic = try TypedResources.intrinsicForSpecialization(
            self,
            structure_type,
            template.name,
            arguments,
            position,
        );
        if (concrete.intrinsic == null) {
            concrete.intrinsic = EcsComponents.intrinsicForSpecialization(self, structure_type, template.name, arguments);
        }
        const structure_index = self.structureIndexForType(structure_type) orelse return error.InvalidSource;
        const method_index = try self.appendMethod(structure_index, concrete);
        const previous_contracts = self.active_contracts;
        self.active_contracts = try self.genericContracts(template.type_parameters, arguments);
        defer self.active_contracts = previous_contracts;
        concrete.statements = try self.rewriteStatements(template.statements, arguments, &locals);
        @constCast(self.structures.items[structure_index].methods)[method_index] = concrete;
        self.method_specializations.items[specialization_index].visiting = false;
        return name;
    }

    fn instantiate(
        self: *Specializer,
        template: Ast.Function,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError![]const u8 {
        const previous_specialization_file = self.specialization_file;
        self.specialization_file = previous_specialization_file orelse position.file;
        defer self.specialization_file = previous_specialization_file;
        for (arguments) |argument| if (argument == .void) return self.fail(position, "'void' is not a generic type argument");
        try self.validateArguments(template.type_parameters, arguments, position);
        for (self.specializations.items) |specialization| {
            if (!samePosition(specialization.template_position, template.name_position)) continue;
            if (std.mem.eql(Ast.Type, specialization.arguments, arguments)) return specialization.name;
            if (specialization.visiting) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "generic function '{s}' recursively expands with different type arguments",
                    .{template.name},
                );
                return self.fail(position, message);
            }
        }

        const name = try self.specializationName(template.name, arguments);
        const specialization_index = self.specializations.items.len;
        try self.specializations.append(self.allocator, .{
            .template_position = template.name_position,
            .arguments = try self.allocator.dupe(Ast.Type, arguments),
            .name = name,
        });

        var concrete = template;
        concrete.name = name;
        concrete.type_parameters = &.{};
        concrete.specialization_file = self.specialization_file;
        var locals: std.ArrayList(Binding) = .empty;
        concrete.parameters = try self.rewriteParameters(template.parameters, arguments, &locals);
        concrete.return_type = try self.rewriteType(template.return_type, arguments, template.name_position);
        const previous_contracts = self.active_contracts;
        self.active_contracts = try self.genericContracts(template.type_parameters, arguments);
        defer self.active_contracts = previous_contracts;
        concrete.statements = try self.rewriteStatements(template.statements, arguments, &locals);
        self.specializations.items[specialization_index].visiting = false;
        try self.functions.append(self.allocator, concrete);
        return name;
    }

    fn genericContracts(
        self: *Specializer,
        parameters: []const Ast.TypeParameter,
        arguments: []const Ast.Type,
    ) Allocator.Error![]const GenericContract {
        var contracts: std.ArrayList(GenericContract) = .empty;
        for (parameters, arguments) |parameter, argument| if (parameter.constraint) |protocol| {
            try contracts.append(self.allocator, .{ .argument = argument, .protocol = protocol });
        };
        return contracts.toOwnedSlice(self.allocator);
    }

    fn callUsesGenericContract(
        self: *Specializer,
        call: Ast.Expression.Call,
        locals: []const Binding,
    ) bool {
        const receiver = call.receiver orelse return false;
        const inferred = self.inferExpressionType(receiver, locals) orelse return false;
        const receiver_type = inferred.optionalChild() orelse inferred;
        for (self.active_contracts) |contract| {
            if (receiver_type != contract.argument) continue;
            const protocol = self.sourceStructureForType(contract.protocol) orelse continue;
            if (!protocol.is_protocol) continue;
            for (protocol.methods) |requirement| {
                if (!std.mem.eql(u8, requirement.name, call.name)) continue;
                if (parametersAcceptArity(requirement.parameters, call.arguments.len + call.named_arguments.len)) return true;
            }
        }
        return false;
    }

    pub fn rewriteType(
        self: *Specializer,
        type_value: Ast.Type,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError!Ast.Type {
        if (type_value.optionalChild()) |child| return .optional(try self.rewriteType(child, arguments, position));
        if (type_value.functionIndex()) |function_index| {
            if (function_index >= self.source.function_types.len) return error.InvalidSource;
            const source = self.source.function_types[function_index];
            const parameters = try self.allocator.alloc(Ast.FunctionType.ParameterType, source.parameters.len);
            for (source.parameters, 0..) |parameter, index| parameters[index] = .{
                .type = try self.rewriteType(parameter.type, arguments, position),
                .mode = parameter.mode,
            };
            const candidate: Ast.FunctionType = .{
                .parameters = parameters,
                .return_type = try self.rewriteType(source.return_type, arguments, position),
                .return_mode = source.return_mode,
            };
            for (self.function_types.items, 0..) |existing, index| if (sameFunctionType(existing, candidate)) return .function(index);
            const index = self.function_types.items.len;
            try self.function_types.append(self.allocator, candidate);
            return .function(index);
        }
        if (type_value.genericParameterIndex()) |parameter| {
            if (parameter >= arguments.len) return self.fail(position, "unknown type parameter");
            return arguments[parameter];
        }
        if (type_value.genericInstantiationIndex()) |generic_index| {
            if (generic_index >= self.source.generic_types.len) return error.InvalidSource;
            const generic = self.source.generic_types[generic_index];
            const base = if (generic.base.genericParameterIndex()) |parameter|
                if (parameter < arguments.len) arguments[parameter] else return self.fail(generic.position, "unknown type parameter")
            else
                generic.base;
            const concrete_arguments = try self.allocator.alloc(Ast.Type, generic.arguments.len);
            for (generic.arguments, 0..) |argument, index| {
                concrete_arguments[index] = try self.rewriteType(argument, arguments, generic.position);
            }
            if (self.enumTemplateForType(base) != null or self.enumForType(base) != null) return self.instantiateEnum(base, concrete_arguments, generic.position);
            return self.instantiateStructure(base, concrete_arguments, generic.position);
        }
        if (self.sourceStructureForType(type_value)) |structure| {
            if (self.collectionNeedsSpecialization(structure)) return self.instantiateCollection(structure, arguments, position);
            if (self.tupleNeedsSpecialization(structure)) return self.instantiateTuple(structure, arguments, position);
        }
        if (self.structureTemplateForType(type_value)) |template| {
            const kind = if (template.is_class) "class" else "struct";
            const message = try std.fmt.allocPrint(
                self.allocator,
                "generic {s} '{s}' requires {d} type argument{s}",
                .{ kind, template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s" },
            );
            return self.fail(position, message);
        }
        if (self.enumTemplateForType(type_value)) |template| {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "generic enum '{s}' requires {d} type argument{s}",
                .{ template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s" },
            );
            return self.fail(position, message);
        }
        if (type_value.structureIndex()) |index| {
            if (index >= self.type_names.items.len) return self.fail(position, "nominal type is unavailable");
            const name = self.type_names.items[index];
            const declared = self.sourceStructureForType(type_value) != null or
                self.structureForType(type_value) != null or
                self.structureTemplateForType(type_value) != null or
                self.enumForType(type_value) != null or
                self.enumTemplateForType(type_value) != null or
                self.hasNestedTypeNamed(name);
            if (!declared) {
                const message = try std.fmt.allocPrint(self.allocator, "unknown nominal type '{s}'", .{name});
                return self.fail(position, message);
            }
        }
        return type_value;
    }

    fn hasNestedTypeNamed(self: *Specializer, name: []const u8) bool {
        for (self.source.structures) |structure| if (nestedNameMatches(structure.name, name)) return true;
        for (self.source.enums) |enumeration| if (nestedNameMatches(enumeration.name, name)) return true;
        return false;
    }

    fn specializeStructureCall(self: *Specializer, call: Ast.Expression.Call) SpecializeError!?[]const u8 {
        const base = self.typeForName(call.name) orelse return null;
        if (self.structureTemplateForType(base)) |template| {
            if (call.type_arguments.len == 0) {
                const kind = if (template.is_class) "class" else "struct";
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "generic {s} '{s}' requires {d} type argument{s}",
                    .{ kind, template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s" },
                );
                return self.fail(call.name_position, message);
            }
            const specialized = try self.instantiateStructure(base, call.type_arguments, call.name_position);
            return self.typeName(specialized);
        }
        if (call.type_arguments.len != 0 and self.structureForType(base) != null) {
            const kind = if (self.structureForType(base).?.is_class) "class" else "struct";
            const message = try std.fmt.allocPrint(self.allocator, "{s} '{s}' does not accept type arguments", .{ kind, call.name });
            return self.fail(call.name_position, message);
        }
        return null;
    }

    fn instantiateCollection(
        self: *Specializer,
        template: Ast.Structure,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError!Ast.Type {
        const source_collection = template.collection.?;
        const element = try self.rewriteType(source_collection.element, arguments, position);
        for (self.structures.items) |structure| if (structure.collection) |collection| {
            if (collection.element == element and collection.length == source_collection.length and collection.view == source_collection.view) {
                return self.typeForName(structure.name) orelse error.InvalidSource;
            }
        };
        const name = if (source_collection.view)
            try std.fmt.allocPrint(self.allocator, "{s}[..]", .{self.typeName(element)})
        else if (source_collection.length) |length|
            try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ self.typeName(element), length })
        else
            try std.fmt.allocPrint(self.allocator, "{s}[]", .{self.typeName(element)});
        const type_value = self.typeForName(name) orelse new_type: {
            const value: Ast.Type = .structure(self.type_names.items.len);
            try self.type_names.append(self.allocator, name);
            break :new_type value;
        };
        var concrete = template;
        concrete.name = name;
        concrete.collection = .{ .element = element, .length = source_collection.length, .view = source_collection.view };
        const structure_index = self.structures.items.len;
        try self.structures.append(self.allocator, concrete);
        try self.rewriteStructureAt(structure_index, arguments, self.specialization_file orelse position.file);
        return type_value;
    }

    fn instantiateTuple(
        self: *Specializer,
        template: Ast.Structure,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError!Ast.Type {
        const fields = try self.allocator.alloc(Ast.StructureField, template.fields.len);
        var name = try self.allocator.dupe(u8, "(");
        for (template.fields, 0..) |field, index| {
            fields[index] = field;
            fields[index].type = try self.rewriteType(field.type, arguments, position);
            name = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}{s}{s}", .{
                name,
                if (index == 0) "" else ", ",
                if (template.tuple_named) try std.fmt.allocPrint(self.allocator, "{s}:", .{field.name}) else "",
                switch (field.access_mode) {
                    .value => "",
                    .read => "@",
                    .mutable => "&",
                },
                self.typeName(fields[index].type),
            });
        }
        name = try std.fmt.allocPrint(self.allocator, "{s})", .{name});
        if (self.typeForName(name)) |existing| return existing;
        const result: Ast.Type = .structure(self.type_names.items.len);
        try self.type_names.append(self.allocator, name);
        var concrete = template;
        concrete.name = name;
        concrete.fields = fields;
        concrete.tuple_placeholder = false;
        try self.structures.append(self.allocator, concrete);
        return result;
    }

    fn tupleNeedsSpecialization(self: *Specializer, structure: Ast.Structure) bool {
        if (!structure.is_tuple or structure.tuple_placeholder) return false;
        for (structure.fields) |field| if (self.typeNeedsSpecialization(field.type)) return true;
        return false;
    }

    pub fn instantiateStructure(
        self: *Specializer,
        base: Ast.Type,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError!Ast.Type {
        const previous_specialization_file = self.specialization_file;
        self.specialization_file = previous_specialization_file orelse position.file;
        defer self.specialization_file = previous_specialization_file;
        const template = self.structureTemplateForType(base) orelse {
            const name = self.typeName(base);
            const declaration = self.structureForType(base);
            const kind = if (declaration != null and declaration.?.is_class) "class" else "struct";
            const message = try std.fmt.allocPrint(self.allocator, "{s} '{s}' does not accept type arguments", .{ kind, name });
            return self.fail(position, message);
        };
        if (arguments.len != template.type_parameters.len) {
            const kind = if (template.is_class) "class" else "struct";
            const message = try std.fmt.allocPrint(
                self.allocator,
                "generic {s} '{s}' expects {d} type argument{s}, found {d}",
                .{ kind, template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s", arguments.len },
            );
            return self.fail(position, message);
        }
        for (arguments) |argument| if (argument == .void) return self.fail(position, "'void' is not a generic type argument");
        try self.validateArguments(template.type_parameters, arguments, position);
        for (self.structure_specializations.items) |specialization| {
            if (!samePosition(specialization.template_position, template.name_position)) continue;
            if (std.mem.eql(Ast.Type, specialization.arguments, arguments)) return specialization.type;
            if (specialization.visiting) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "generic {s} '{s}' recursively expands with different type arguments",
                    .{ if (template.is_class) "class" else "struct", template.name },
                );
                return self.fail(position, message);
            }
        }

        const name = try self.specializationName(template.name, arguments);
        const type_value: Ast.Type = self.typeForName(name) orelse new_type: {
            const value: Ast.Type = .structure(self.type_names.items.len);
            try self.type_names.append(self.allocator, name);
            break :new_type value;
        };
        const specialization_index = self.structure_specializations.items.len;
        try self.structure_specializations.append(self.allocator, .{
            .template_position = template.name_position,
            .arguments = try self.allocator.dupe(Ast.Type, arguments),
            .name = name,
            .type = type_value,
        });
        var concrete = template;
        concrete.name = name;
        concrete.type_parameters = &.{};
        if (try Nested.concreteEnclosing(self, template, arguments, position)) |owner| concrete.enclosing = owner;
        const structure_index = self.structures.items.len;
        try self.structures.append(self.allocator, concrete);
        try self.rewriteStructureAt(structure_index, arguments, self.specialization_file);
        self.structure_specializations.items[specialization_index].visiting = false;
        return type_value;
    }

    fn instantiateEnum(
        self: *Specializer,
        base: Ast.Type,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError!Ast.Type {
        const template = self.enumTemplateForType(base) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "enum '{s}' does not accept type arguments", .{self.typeName(base)});
            return self.fail(position, message);
        };
        if (arguments.len != template.type_parameters.len) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "generic enum '{s}' expects {d} type argument{s}, found {d}",
                .{ template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s", arguments.len },
            );
            return self.fail(position, message);
        }
        if (std.mem.eql(u8, template.name, Result.name)) {
            if (!Result.acceptsArguments(template, arguments)) return self.fail(position, "the error type of 'Result' cannot be 'void'");
        } else for (arguments) |argument| if (argument == .void) return self.fail(position, "'void' is not a generic type argument");
        try self.validateArguments(template.type_parameters, arguments, position);
        for (self.enum_specializations.items) |specialization| {
            if (!samePosition(specialization.template_position, template.name_position)) continue;
            if (std.mem.eql(Ast.Type, specialization.arguments, arguments)) return specialization.type;
            if (specialization.visiting) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "generic enum '{s}' recursively expands with different type arguments",
                    .{template.name},
                );
                return self.fail(position, message);
            }
        }
        const name = try self.specializationName(template.name, arguments);
        const type_value: Ast.Type = self.typeForName(name) orelse new_type: {
            const value: Ast.Type = .structure(self.type_names.items.len);
            try self.type_names.append(self.allocator, name);
            break :new_type value;
        };
        const specialization_index = self.enum_specializations.items.len;
        try self.enum_specializations.append(self.allocator, .{
            .template_position = template.name_position,
            .arguments = try self.allocator.dupe(Ast.Type, arguments),
            .name = name,
            .type = type_value,
        });
        var concrete = template;
        concrete.name = name;
        concrete.type_parameters = &.{};
        const enum_index = self.enums.items.len;
        try self.enums.append(self.allocator, concrete);
        try self.rewriteEnumAt(enum_index, arguments);
        self.enum_specializations.items[specialization_index].visiting = false;
        return type_value;
    }

    fn inferTypeArguments(self: *Specializer, template: Ast.Function, actual: []const Ast.Type) Allocator.Error!?[]const Ast.Type {
        const inferred = try self.allocator.alloc(?Ast.Type, template.type_parameters.len);
        @memset(inferred, null);
        for (template.parameters[0..actual.len], actual) |parameter, actual_type| {
            if (!self.unifyType(parameter.type, actual_type, inferred)) return null;
        }
        const result = try self.allocator.alloc(Ast.Type, inferred.len);
        for (inferred, 0..) |argument, index| result[index] = argument orelse return null;
        if (!self.argumentsMatch(template.parameters, actual, result)) return null;
        return result;
    }

    fn hasCompatibleConcrete(self: *Specializer, call: Ast.Expression.Call, actual: []const Ast.Type) bool {
        for (self.functions.items) |function| {
            if (!std.mem.eql(u8, function.name, call.name) or !functionVisible(self.packages, self.module_scope_roots, call, function)) continue;
            if (!parametersAcceptArity(function.parameters, actual.len)) continue;
            if (self.argumentsMatch(function.parameters, actual, &.{})) return true;
        }
        // A concrete sibling may not have been copied into `functions` yet
        // when modules are specialized in dependency order. It still wins for
        // a call without explicit type arguments; the generic sibling remains
        // available through `name<T>(...)`.
        for (self.source.functions) |function| {
            if (function.type_parameters.len != 0 or !std.mem.eql(u8, function.name, call.name) or
                !functionVisible(self.packages, self.module_scope_roots, call, function)) continue;
            if (!parametersAcceptArity(function.parameters, actual.len)) continue;
            if (self.argumentsMatch(function.parameters, actual, &.{})) return true;
        }
        return false;
    }

    fn unifyType(self: *Specializer, pattern: Ast.Type, actual: Ast.Type, inferred: []?Ast.Type) bool {
        if (pattern.optionalChild()) |child| return self.unifyType(child, actual.optionalChild() orelse actual, inferred);
        if (pattern.genericParameterIndex()) |index| {
            if (index >= inferred.len or actual == .void) return false;
            if (inferred[index]) |existing| return existing == actual;
            inferred[index] = actual;
            return true;
        }
        if (pattern.functionIndex()) |pattern_index| {
            const actual_index = actual.functionIndex() orelse return false;
            if (pattern_index >= self.source.function_types.len) return false;
            const pattern_function = self.source.function_types[pattern_index];
            const actual_function = if (actual_index < self.function_types.items.len)
                self.function_types.items[actual_index]
            else if (actual_index < self.source.function_types.len)
                self.source.function_types[actual_index]
            else
                return false;
            if (pattern_function.return_mode != actual_function.return_mode or pattern_function.parameters.len != actual_function.parameters.len) return false;
            if (!self.unifyType(pattern_function.return_type, actual_function.return_type, inferred)) return false;
            for (pattern_function.parameters, actual_function.parameters) |pattern_parameter, actual_parameter| {
                if (pattern_parameter.mode != actual_parameter.mode or !self.unifyType(pattern_parameter.type, actual_parameter.type, inferred)) return false;
            }
            return true;
        }
        if (pattern.genericInstantiationIndex()) |generic_index| {
            if (generic_index >= self.source.generic_types.len) return false;
            const generic = self.source.generic_types[generic_index];
            const specialization = self.specializedType(actual) orelse return false;
            const template_position = if (self.structureTemplateForType(generic.base)) |template|
                template.name_position
            else if (self.enumTemplateForType(generic.base)) |template|
                template.name_position
            else
                return false;
            if (!samePosition(template_position, specialization.template_position) or
                generic.arguments.len != specialization.arguments.len) return false;
            for (generic.arguments, specialization.arguments) |nested_pattern, nested_actual| {
                if (!self.unifyType(nested_pattern, nested_actual, inferred)) return false;
            }
            return true;
        }
        if (self.sourceStructureForType(pattern)) |pattern_structure| if (pattern_structure.is_tuple) {
            const actual_structure = self.structureForType(actual) orelse return false;
            if (!actual_structure.is_tuple or pattern_structure.tuple_named != actual_structure.tuple_named or
                pattern_structure.fields.len != actual_structure.fields.len) return false;
            for (pattern_structure.fields, actual_structure.fields) |pattern_field, actual_field| {
                if (pattern_structure.tuple_named and !std.mem.eql(u8, pattern_field.name, actual_field.name)) return false;
                if (!self.unifyType(pattern_field.type, actual_field.type, inferred)) return false;
            }
            return true;
        };
        if (self.collectionForSourceType(pattern)) |pattern_collection| {
            const actual_collection = self.collectionForSourceType(actual) orelse return false;
            return (pattern_collection.view or pattern_collection.length == actual_collection.length) and
                self.unifyType(pattern_collection.element, actual_collection.element, inferred);
        }
        return compatible(actual, pattern);
    }

    fn argumentsMatch(self: *Specializer, parameters: []const Ast.Parameter, actual: []const Ast.Type, arguments: []const Ast.Type) bool {
        if (!parametersAcceptArity(parameters, actual.len)) return false;
        for (parameters[0..actual.len], actual) |parameter, actual_type| {
            if (!self.matchesPattern(parameter.type, actual_type, arguments)) return false;
        }
        return true;
    }

    fn argumentAdaptationCost(self: *Specializer, parameters: []const Ast.Parameter, actual: []const Ast.Type) usize {
        var cost: usize = 0;
        for (parameters[0..actual.len], actual) |parameter, actual_type| {
            cost += self.typeAdaptationCost(parameter.type, actual_type);
        }
        return cost;
    }

    fn typeAdaptationCost(self: *Specializer, pattern: Ast.Type, actual: Ast.Type) usize {
        if (pattern.optionalChild()) |child| return self.typeAdaptationCost(child, actual.optionalChild() orelse actual);
        if (self.collectionForSourceType(pattern)) |pattern_collection| {
            const actual_collection = self.collectionForSourceType(actual) orelse return 0;
            return @intFromBool(pattern_collection.view and !actual_collection.view) +
                self.typeAdaptationCost(pattern_collection.element, actual_collection.element);
        }
        return 0;
    }

    fn matchesPattern(self: *Specializer, pattern: Ast.Type, actual: Ast.Type, arguments: []const Ast.Type) bool {
        if (pattern.optionalChild()) |child| {
            const expected_child = self.substitutedPattern(child, arguments) orelse return false;
            return compatible(actual, .optional(expected_child));
        }
        if (pattern.genericParameterIndex()) |index| {
            return index < arguments.len and compatible(actual, arguments[index]);
        }
        if (pattern.functionIndex()) |pattern_index| {
            const actual_index = actual.functionIndex() orelse return false;
            if (pattern_index >= self.source.function_types.len) return false;
            const pattern_function = self.source.function_types[pattern_index];
            const actual_function = if (actual_index < self.function_types.items.len)
                self.function_types.items[actual_index]
            else if (actual_index < self.source.function_types.len)
                self.source.function_types[actual_index]
            else
                return false;
            if (pattern_function.return_mode != actual_function.return_mode or pattern_function.parameters.len != actual_function.parameters.len) return false;
            if (!self.matchesPattern(pattern_function.return_type, actual_function.return_type, arguments)) return false;
            for (pattern_function.parameters, actual_function.parameters) |pattern_parameter, actual_parameter| {
                if (pattern_parameter.mode != actual_parameter.mode or !self.matchesPattern(pattern_parameter.type, actual_parameter.type, arguments)) return false;
            }
            return true;
        }
        if (pattern.genericInstantiationIndex()) |generic_index| {
            if (generic_index >= self.source.generic_types.len) return false;
            const generic = self.source.generic_types[generic_index];
            const specialization = self.specializedType(actual) orelse return false;
            const template_position = if (self.structureTemplateForType(generic.base)) |template|
                template.name_position
            else if (self.enumTemplateForType(generic.base)) |template|
                template.name_position
            else
                return false;
            if (!samePosition(template_position, specialization.template_position) or
                generic.arguments.len != specialization.arguments.len) return false;
            for (generic.arguments, specialization.arguments) |nested_pattern, nested_actual| {
                if (!self.matchesPattern(nested_pattern, nested_actual, arguments)) return false;
            }
            return true;
        }
        if (self.collectionForSourceType(pattern)) |pattern_collection| {
            const actual_collection = self.collectionForSourceType(actual) orelse return false;
            return (pattern_collection.view or pattern_collection.length == actual_collection.length) and
                self.matchesPattern(pattern_collection.element, actual_collection.element, arguments);
        }
        if (self.sourceStructureForType(pattern)) |pattern_structure| if (pattern_structure.is_tuple) {
            const actual_structure = self.structureForType(actual) orelse return false;
            if (!actual_structure.is_tuple or pattern_structure.tuple_named != actual_structure.tuple_named or
                pattern_structure.fields.len != actual_structure.fields.len) return false;
            for (pattern_structure.fields, actual_structure.fields) |pattern_field, actual_field| {
                if (pattern_structure.tuple_named and !std.mem.eql(u8, pattern_field.name, actual_field.name)) return false;
                if (!self.matchesPattern(pattern_field.type, actual_field.type, arguments)) return false;
            }
            return true;
        };
        return compatible(actual, pattern);
    }

    fn substitutedPattern(self: *Specializer, pattern: Ast.Type, arguments: []const Ast.Type) ?Ast.Type {
        _ = self;
        if (pattern.genericParameterIndex()) |index| return if (index < arguments.len) arguments[index] else null;
        return pattern;
    }

    pub fn inferExpressionType(self: *Specializer, expression: *const Ast.Expression, locals: []const Binding) ?Ast.Type {
        return switch (expression.value) {
            .integer => .int,
            .floating => .float32,
            .boolean => .bool,
            .string, .interpolated_string => .str,
            .null_value => null,
            .generic_reference => null,
            .identifier => |name| local: {
                var index = locals.len;
                while (index != 0) {
                    index -= 1;
                    if (std.mem.eql(u8, locals[index].name, name)) break :local locals[index].type;
                }
                var matched: ?Ast.Type = null;
                for (self.functions.items) |function| {
                    if (!functionNameMatches(function.name, name) or function.type_parameters.len != 0) continue;
                    var found_type: ?Ast.Type = null;
                    for (self.function_types.items, 0..) |function_type, function_index| {
                        if (functionTypeMatchesDeclaration(function_type, function)) {
                            found_type = .function(function_index);
                            break;
                        }
                    }
                    if (found_type == null or matched != null) break :local null;
                    matched = found_type;
                }
                break :local matched;
            },
            .call => |call| call_type: {
                if (call.result_type) |result_type| break :call_type result_type;
                if (call.receiver == null) {
                    for (self.functions.items) |function| {
                        if (std.mem.eql(u8, function.name, call.name) and parametersAcceptArity(function.parameters, call.arguments.len)) {
                            break :call_type function.return_type;
                        }
                    }
                    if (self.typeForName(call.name)) |type_value| break :call_type type_value;
                } else if (call.receiver.?.value == .identifier and self.typeForName(call.receiver.?.value.identifier) != null) {
                    break :call_type self.typeForName(call.receiver.?.value.identifier).?;
                } else if (self.inferExpressionType(call.receiver.?, locals)) |receiver_type| {
                    const child = receiver_type.optionalChild() orelse receiver_type;
                    if (self.structureForType(child)) |structure| {
                        for (structure.methods) |method| {
                            if (std.mem.eql(u8, method.name, call.name) and parametersAcceptArity(method.parameters, call.arguments.len)) {
                                break :call_type if (call.safe and method.return_type.optionalChild() == null)
                                    .optional(method.return_type)
                                else
                                    method.return_type;
                            }
                        }
                    }
                }
                break :call_type null;
            },
            .cascade => |cascade| self.inferExpressionType(cascade.receiver, locals),
            .field_access => |access| field_type: {
                const base = self.inferExpressionType(access.base, locals) orelse break :field_type null;
                const child = base.optionalChild() orelse base;
                const structure = self.structureForType(child) orelse break :field_type null;
                for (structure.fields) |field| if (std.mem.eql(u8, field.name, access.name)) {
                    break :field_type if (access.safe and field.type.optionalChild() == null) .optional(field.type) else field.type;
                };
                break :field_type null;
            },
            .unary => |unary| if (unary.operator == .logical_not)
                .bool
            else if (unary.operator == .propagate)
                self.inferPropagatedType(unary.operand, locals)
            else
                self.inferExpressionType(unary.operand, locals),
            .binary => |binary| switch (binary.operator) {
                .less, .less_equal, .greater, .greater_equal, .equal, .not_equal, .logical_and, .logical_or => .bool,
                .coalesce => coalesce: {
                    const left = self.inferExpressionType(binary.left, locals) orelse break :coalesce null;
                    const right = self.inferExpressionType(binary.right, locals);
                    break :coalesce if (right != null and right.? == left) left else left.optionalChild();
                },
                else => self.inferExpressionType(binary.left, locals),
            },
            .conversion => |conversion| conversion.target,
            .string_count => .int,
            .sequence_literal => |literal| literal.inferred_type orelse self.inferSequenceLiteralType(literal.values, locals),
            .tuple_literal => |literal| literal.placeholder_type,
            .index_access => |access| index_type: {
                const base = self.inferExpressionType(access.base, locals) orelse break :index_type null;
                const structure = self.structureForType(base) orelse break :index_type null;
                break :index_type if (structure.collection) |collection| collection.element else null;
            },
            .slice_access => |access| self.inferExpressionType(access.base, locals),
            .match_expression => |match_value| match_type: {
                for (match_value.branches) |branch| if (branch.value) |value| {
                    break :match_type self.inferExpressionType(value, locals);
                };
                break :match_type null;
            },
        };
    }

    fn inferSequenceLiteralType(self: *Specializer, values: []const *Ast.Expression, locals: []const Binding) ?Ast.Type {
        if (values.len == 0) return null;
        const element = self.inferExpressionType(values[0], locals) orelse return null;
        for (values[1..]) |value| if (self.inferExpressionType(value, locals) != element) return null;
        for (self.structures.items) |structure| if (structure.collection) |collection| {
            if (collection.element == element and collection.length == null and !collection.view) {
                return self.typeForName(structure.name);
            }
        };
        for (self.source.structures) |structure| if (structure.collection) |collection| {
            if (collection.element == element and collection.length == null and !collection.view) {
                return self.typeForName(structure.name);
            }
        };
        return null;
    }

    pub fn structureForType(self: *Specializer, type_value: Ast.Type) ?Ast.Structure {
        const index = type_value.structureIndex() orelse return null;
        if (index >= self.type_names.items.len) return null;
        const name = self.type_names.items[index];
        for (self.structures.items) |structure| if (std.mem.eql(u8, structure.name, name)) return structure;
        return null;
    }

    fn inferPropagatedType(self: *Specializer, operand: *const Ast.Expression, locals: []const Binding) ?Ast.Type {
        const operand_type = self.inferExpressionType(operand, locals) orelse return null;
        const enumeration = self.enumForType(operand_type) orelse return null;
        return Result.successType(enumeration);
    }

    pub fn sourceStructureForType(self: *Specializer, type_value: Ast.Type) ?Ast.Structure {
        const index = type_value.structureIndex() orelse return null;
        if (index >= self.type_names.items.len) return null;
        const name = self.type_names.items[index];
        for (self.source.structures) |structure| {
            if (structure.type_parameters.len == 0 and std.mem.eql(u8, structure.name, name)) return structure;
        }
        return null;
    }

    fn collectionForSourceType(self: *Specializer, type_value: Ast.Type) ?Ast.Collection {
        if (self.structureForType(type_value)) |structure| return structure.collection;
        if (self.sourceStructureForType(type_value)) |structure| return structure.collection;
        return null;
    }

    fn collectionNeedsSpecialization(self: *Specializer, structure: Ast.Structure) bool {
        const collection = structure.collection orelse return false;
        return self.typeNeedsSpecialization(collection.element);
    }

    fn typeNeedsSpecialization(self: *Specializer, type_value: Ast.Type) bool {
        if (type_value.optionalChild()) |child| return self.typeNeedsSpecialization(child);
        if (type_value.genericParameterIndex() != null) return true;
        if (type_value.genericInstantiationIndex()) |index| {
            if (index >= self.source.generic_types.len) return true;
            const generic = self.source.generic_types[index];
            if (self.typeNeedsSpecialization(generic.base)) return true;
            for (generic.arguments) |argument| if (self.typeNeedsSpecialization(argument)) return true;
            return false;
        }
        if (type_value.functionIndex()) |index| {
            if (index >= self.source.function_types.len) return false;
            const signature = self.source.function_types[index];
            if (self.typeNeedsSpecialization(signature.return_type)) return true;
            for (signature.parameters) |parameter| if (self.typeNeedsSpecialization(parameter.type)) return true;
        }
        if (self.sourceStructureForType(type_value)) |nested| if (nested.collection != null) {
            return self.collectionNeedsSpecialization(nested);
        };
        if (self.sourceStructureForType(type_value)) |nested| if (nested.is_tuple) {
            return self.tupleNeedsSpecialization(nested);
        };
        return false;
    }

    pub fn structureIndexForType(self: *Specializer, type_value: Ast.Type) ?usize {
        const index = type_value.structureIndex() orelse return null;
        if (index >= self.type_names.items.len) return null;
        const name = self.type_names.items[index];
        for (self.structures.items, 0..) |structure, structure_index| {
            if (std.mem.eql(u8, structure.name, name)) return structure_index;
        }
        return null;
    }

    fn appendMethod(self: *Specializer, structure_index: usize, method: Ast.Function) Allocator.Error!usize {
        const structure = &self.structures.items[structure_index];
        const method_index = structure.methods.len;
        const methods = try self.allocator.alloc(Ast.Function, method_index + 1);
        @memcpy(methods[0..method_index], structure.methods);
        methods[method_index] = method;
        structure.methods = methods;
        return method_index;
    }

    pub fn structureTemplateForType(self: *Specializer, type_value: Ast.Type) ?Ast.Structure {
        const index = type_value.structureIndex() orelse return null;
        if (index >= self.type_names.items.len) return null;
        const name = self.type_names.items[index];
        for (self.source.structures) |structure| {
            if (structure.type_parameters.len != 0 and std.mem.eql(u8, structure.name, name)) return structure;
        }
        return null;
    }

    fn enumTemplateForType(self: *Specializer, type_value: Ast.Type) ?Ast.Enum {
        const index = type_value.structureIndex() orelse return null;
        if (index >= self.type_names.items.len) return null;
        const name = self.type_names.items[index];
        for (self.source.enums) |enumeration| {
            if (enumeration.type_parameters.len != 0 and std.mem.eql(u8, enumeration.name, name)) return enumeration;
        }
        return null;
    }

    fn enumForType(self: *Specializer, type_value: Ast.Type) ?Ast.Enum {
        const index = type_value.structureIndex() orelse return null;
        if (index >= self.type_names.items.len) return null;
        const name = self.type_names.items[index];
        for (self.enums.items) |enumeration| if (std.mem.eql(u8, enumeration.name, name)) return enumeration;
        return null;
    }

    fn structureSpecializationForType(self: *Specializer, type_value: Ast.Type) ?StructureSpecialization {
        for (self.structure_specializations.items) |specialization| if (specialization.type == type_value) return specialization;
        return null;
    }

    fn specializedType(self: *Specializer, type_value: Ast.Type) ?SpecializedType {
        if (self.structureSpecializationForType(type_value)) |specialization| return .{
            .template_position = specialization.template_position,
            .arguments = specialization.arguments,
        };
        for (self.enum_specializations.items) |specialization| if (specialization.type == type_value) return .{
            .template_position = specialization.template_position,
            .arguments = specialization.arguments,
        };
        return null;
    }

    pub fn typeForName(self: *Specializer, name: []const u8) ?Ast.Type {
        for (self.type_names.items, 0..) |candidate, index| if (std.mem.eql(u8, candidate, name)) return .structure(index);
        return null;
    }

    fn validateConstraintDeclarations(self: *Specializer) SpecializeError!void {
        for (self.source.functions) |function| try self.validateConstraints(function.type_parameters);
        for (self.source.structures) |structure| {
            try self.validateConstraints(structure.type_parameters);
            for (structure.methods) |method| try self.validateConstraints(method.type_parameters);
        }
        for (self.source.enums) |enumeration| try self.validateConstraints(enumeration.type_parameters);
    }

    fn validateConstraints(self: *Specializer, parameters: []const Ast.TypeParameter) SpecializeError!void {
        for (parameters) |parameter| if (parameter.constraint) |constraint| {
            const protocol = self.sourceStructureForType(constraint) orelse {
                const message = try std.fmt.allocPrint(self.allocator, "generic constraint on '{s}' must name a protocol", .{parameter.name});
                return self.fail(parameter.position, message);
            };
            if (!protocol.is_protocol) {
                const message = try std.fmt.allocPrint(self.allocator, "generic constraint on '{s}' must name a protocol", .{parameter.name});
                return self.fail(parameter.position, message);
            }
        };
    }

    fn validateArguments(
        self: *Specializer,
        parameters: []const Ast.TypeParameter,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError!void {
        for (parameters, arguments) |parameter, argument| if (parameter.constraint) |protocol| {
            if (Conformances.conforms(self, argument, protocol, position, 0)) continue;
            const message = try std.fmt.allocPrint(
                self.allocator,
                "type '{s}' does not conform to protocol '{s}' required by '{s}'",
                .{ self.typeName(argument), self.typeName(protocol), parameter.name },
            );
            return self.fail(position, message);
        };
    }

    fn specializationName(self: *Specializer, name: []const u8, arguments: []const Ast.Type) Allocator.Error![]const u8 {
        var result = try std.fmt.allocPrint(self.allocator, "{s}<", .{name});
        for (arguments, 0..) |argument, index| {
            result = try std.fmt.allocPrint(
                self.allocator,
                "{s}{s}{s}",
                .{ result, if (index == 0) "" else ",", self.typeName(argument) },
            );
        }
        return std.fmt.allocPrint(self.allocator, "{s}>", .{result});
    }

    pub fn typeName(self: *Specializer, type_value: Ast.Type) []const u8 {
        if (type_value.optionalChild()) |child| {
            return std.fmt.allocPrint(self.allocator, "{s}?", .{self.typeName(child)}) catch "optional";
        }
        if (type_value.structureIndex()) |index| if (index < self.type_names.items.len) return self.type_names.items[index];
        if (type_value.functionIndex()) |index| {
            const signatures = if (index < self.function_types.items.len) self.function_types.items else self.source.function_types;
            if (index < signatures.len) return "function";
        }
        return type_value.name();
    }

    fn ambiguous(self: *Specializer, position: Source.Position, name: []const u8) Source.Error {
        const message = std.fmt.allocPrint(self.allocator, "generic call to '{s}' is ambiguous", .{name}) catch "generic call is ambiguous";
        return self.fail(position, message);
    }

    fn ambiguousMethod(self: *Specializer, position: Source.Position, name: []const u8) Source.Error {
        const message = std.fmt.allocPrint(self.allocator, "generic call to method '{s}' is ambiguous", .{name}) catch "generic method call is ambiguous";
        return self.fail(position, message);
    }

    pub fn fail(self: *Specializer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn compatible(actual: Ast.Type, expected: Ast.Type) bool {
    if (actual == expected or Numeric.canWiden(actual, expected)) return true;
    if (expected.optionalChild()) |child| return actual == child or actual.optionalChild() == child;
    return false;
}

fn sameFunctionType(left: Ast.FunctionType, right: Ast.FunctionType) bool {
    if (left.return_type != right.return_type or left.return_mode != right.return_mode or left.parameters.len != right.parameters.len) return false;
    for (left.parameters, right.parameters) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type or left_parameter.mode != right_parameter.mode) return false;
    }
    return true;
}

fn functionTypeMatchesDeclaration(function_type: Ast.FunctionType, function: Ast.Function) bool {
    if (function_type.return_type != function.return_type or function_type.return_mode != function.return_mode or function_type.parameters.len != function.parameters.len) return false;
    for (function_type.parameters, function.parameters) |parameter_type, parameter| {
        if (parameter_type.type != parameter.type or parameter_type.mode != parameter.mode) return false;
    }
    return true;
}

fn sameTemplateParameters(left: []const Ast.Parameter, right: []const Ast.Parameter) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type or left_parameter.mode != right_parameter.mode or
            !std.mem.eql(u8, left_parameter.name, right_parameter.name)) return false;
    }
    return true;
}

fn functionNameMatches(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    if (!std.mem.endsWith(u8, candidate, requested) or candidate.len == requested.len) return false;
    return candidate[candidate.len - requested.len - 1] == '.';
}

fn parametersAcceptArity(parameters: []const Ast.Parameter, arity: usize) bool {
    var required = parameters.len;
    for (parameters, 0..) |parameter, index| if (parameter.default != null) {
        required = index;
        break;
    };
    return arity >= required and arity <= parameters.len;
}

fn functionVisible(packages: ?Packages.Graph, module_scope_roots: []const []const u8, call: Ast.Expression.Call, function: Ast.Function) bool {
    if (function.is_local) return call.name_position.file == function.position.file;
    if (function.is_public) return true;
    if (function.is_internal) return if (packages) |graph|
        graph.canAccessPackage(call.owner, function.owner)
    else
        call.owner == function.owner;
    if (call.name_position.file == function.position.file) return true;
    const separator = std.mem.lastIndexOfScalar(u8, function.name, '.') orelse return false;
    return ModuleScopes.same(module_scope_roots, call.module, function.name[0..separator]);
}

fn methodVisible(packages: ?Packages.Graph, module_scope_roots: []const []const u8, call: Ast.Expression.Call, structure: Ast.Structure, method: Ast.Function) bool {
    if (call.compiler_generated and method.is_internal) return true;
    if (method.is_local) return call.name_position.file == method.position.file;
    if (method.is_public) return true;
    if (method.is_internal) return if (packages) |graph|
        graph.canAccessPackage(call.owner, method.owner)
    else
        call.owner == method.owner;
    if (method.is_private or method.is_protected) return call.owner == method.owner;
    if (call.name_position.file == method.position.file) return true;
    const separator = std.mem.lastIndexOfScalar(u8, structure.name, '.') orelse return false;
    return ModuleScopes.same(module_scope_roots, call.module, structure.name[0..separator]);
}

fn samePosition(left: Source.Position, right: Source.Position) bool {
    return left.offset == right.offset and left.file == right.file;
}
