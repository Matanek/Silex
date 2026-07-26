const std = @import("std");
const Ast = @import("../Ast.zig");
const Numeric = @import("../Numeric.zig");
const Result = @import("../Intrinsics/Result.zig");
const Source = @import("../Source.zig");

const Allocator = std.mem.Allocator;
const SpecializeError = Source.Error || Allocator.Error;

const Binding = struct {
    name: []const u8,
    type: Ast.Type,
};

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
    specializations: std.ArrayList(FunctionSpecialization) = .empty,
    structure_specializations: std.ArrayList(StructureSpecialization) = .empty,
    enum_specializations: std.ArrayList(EnumSpecialization) = .empty,
    method_specializations: std.ArrayList(MethodSpecialization) = .empty,
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
        for (program.enums) |enumeration| {
            if (enumeration.type_parameters.len == 0) try self.enums.append(self.allocator, enumeration);
        }
        const concrete_enum_count = self.enums.items.len;
        for (0..concrete_enum_count) |enum_index| try self.rewriteEnumAt(enum_index, &.{});
        for (program.structures) |structure| {
            if (structure.type_parameters.len == 0) try self.structures.append(self.allocator, structure);
        }
        const concrete_structure_count = self.structures.items.len;
        for (0..concrete_structure_count) |structure_index| {
            try self.rewriteStructureAt(structure_index, &.{});
        }
        for (program.functions) |function| {
            if (function.type_parameters.len == 0) try self.functions.append(self.allocator, function);
        }

        for (self.functions.items) |*function| {
            var locals: std.ArrayList(Binding) = .empty;
            function.parameters = try self.rewriteParameters(function.parameters, &.{}, &locals);
            function.return_type = try self.rewriteType(function.return_type, &.{}, function.name_position);
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
        result.structures = try self.structures.toOwnedSlice(self.allocator);
        result.enums = try self.enums.toOwnedSlice(self.allocator);
        result.functions = try self.functions.toOwnedSlice(self.allocator);
        return result;
    }

    fn compactTypeNames(self: *Specializer) SpecializeError!void {
        const map = try self.allocator.alloc(?Ast.Type, self.type_names.items.len);
        @memset(map, null);
        var names: std.ArrayList([]const u8) = .empty;
        for (self.type_names.items, 0..) |name, index| {
            var keep = false;
            for (self.structures.items) |structure| if (std.mem.eql(u8, structure.name, name)) {
                keep = true;
                break;
            };
            if (!keep) for (self.enums.items) |enumeration| if (std.mem.eql(u8, enumeration.name, name)) {
                keep = true;
                break;
            };
            if (!keep) continue;
            map[index] = .structure(names.items.len);
            try names.append(self.allocator, name);
        }
        for (self.structures.items) |*structure| {
            if (structure.collection) |collection| structure.collection.?.element = remapConcreteType(collection.element, map);
            for (@constCast(structure.fields)) |*field| field.type = remapConcreteType(field.type, map);
            for (@constCast(structure.constructors)) |*constructor| {
                for (@constCast(constructor.parameters)) |*parameter| parameter.type = remapConcreteType(parameter.type, map);
                remapStatementTypes(constructor.statements, map);
            }
            for (@constCast(structure.methods)) |*method| {
                for (@constCast(method.parameters)) |*parameter| parameter.type = remapConcreteType(parameter.type, map);
                method.return_type = remapConcreteType(method.return_type, map);
                remapStatementTypes(method.statements, map);
            }
        }
        for (self.functions.items) |*function| {
            for (@constCast(function.parameters)) |*parameter| parameter.type = remapConcreteType(parameter.type, map);
            function.return_type = remapConcreteType(function.return_type, map);
            remapStatementTypes(function.statements, map);
        }
        for (self.enums.items) |*enumeration| {
            for (@constCast(enumeration.variants)) |*variant| {
                for (@constCast(variant.associated_types)) |*associated_type| {
                    associated_type.* = remapConcreteType(associated_type.*, map);
                }
            }
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

    fn rewriteStructureAt(self: *Specializer, structure_index: usize, arguments: []const Ast.Type) SpecializeError!void {
        var structure = self.structures.items[structure_index];
        structure.type_parameters = &.{};
        const self_type = self.typeForName(structure.name) orelse return error.InvalidSource;
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
        if (structure.collection) |collection| structure.collection.?.element = try self.rewriteType(collection.element, arguments, structure.position);
        self.structures.items[structure_index] = structure;

        const constructors = try self.allocator.alloc(Ast.Constructor, structure.constructors.len);
        for (structure.constructors, 0..) |constructor, constructor_index| {
            constructors[constructor_index] = constructor;
            var locals: std.ArrayList(Binding) = .empty;
            try locals.append(self.allocator, .{ .name = "self", .type = self_type });
            constructors[constructor_index].parameters = try self.rewriteParameters(constructor.parameters, arguments, &locals);
            constructors[constructor_index].statements = try self.rewriteStatements(constructor.statements, arguments, &locals);
        }
        structure.constructors = constructors;
        var concrete_methods: std.ArrayList(Ast.Function) = .empty;
        for (structure.methods) |method| if (method.type_parameters.len == 0) {
            try concrete_methods.append(self.allocator, method);
        };
        structure.methods = try concrete_methods.toOwnedSlice(self.allocator);
        self.structures.items[structure_index] = structure;
        const initial_method_count = structure.methods.len;
        for (0..initial_method_count) |method_index| {
            var method = self.structures.items[structure_index].methods[method_index];
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
                if (copy.receiver != null and copy.named_arguments.len == 0) {
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
            .field_access => |access| value: {
                var copy = access;
                copy.base = try self.rewriteExpression(access.base, arguments, locals);
                break :value .{ .field_access = copy };
            },
            .unary => |unary| value: {
                var copy = unary;
                copy.operand = try self.rewriteExpression(unary.operand, arguments, locals);
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
            .index_access => |access| value: {
                var copy = access;
                copy.base = try self.rewriteExpression(access.base, arguments, locals);
                copy.index = try self.rewriteExpression(access.index, arguments, locals);
                break :value .{ .index_access = copy };
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
        const actual_types = try self.allocator.alloc(Ast.Type, call.arguments.len);
        for (call.arguments, 0..) |argument, index| {
            actual_types[index] = self.inferExpressionType(argument, locals) orelse {
                if (call.type_arguments.len == 0) return null;
                return self.fail(call.arguments[index].position, "cannot determine argument type for generic specialization");
            };
        }

        if (call.type_arguments.len == 0 and self.hasCompatibleConcrete(call, actual_types)) return null;

        var selected: ?*const Ast.Function = null;
        var selected_arguments: []const Ast.Type = &.{};
        var saw_generic = false;
        var saw_arity = false;
        for (self.source.functions) |*function| {
            if (function.type_parameters.len == 0 or !std.mem.eql(u8, function.name, call.name) or !functionVisible(call, function.*)) continue;
            saw_generic = true;
            if (call.type_arguments.len != 0) {
                if (call.type_arguments.len != function.type_parameters.len) continue;
                saw_arity = true;
                if (!parametersAcceptArity(function.parameters, actual_types.len)) continue;
                if (!self.argumentsMatch(function.parameters, actual_types, call.type_arguments)) continue;
                if (selected != null) return self.ambiguous(call.name_position, call.name);
                selected = function;
                selected_arguments = call.type_arguments;
                continue;
            }
            if (!parametersAcceptArity(function.parameters, actual_types.len)) continue;
            saw_arity = true;
            const inferred = try self.inferTypeArguments(function.*, actual_types) orelse continue;
            if (selected != null) return self.ambiguous(call.name_position, call.name);
            selected = function;
            selected_arguments = inferred;
        }

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
        const receiver_type = self.inferExpressionType(call.receiver.?, locals) orelse return null;
        const concrete_receiver = receiver_type.optionalChild() orelse receiver_type;
        const structure = self.structureForType(concrete_receiver) orelse return null;
        const source_structure = self.sourceStructureForType(concrete_receiver) orelse return null;
        const actual_types = try self.allocator.alloc(Ast.Type, call.arguments.len);
        for (call.arguments, 0..) |argument, index| {
            actual_types[index] = self.inferExpressionType(argument, locals) orelse {
                if (call.type_arguments.len == 0) return null;
                return self.fail(call.arguments[index].position, "cannot determine argument type for generic method specialization");
            };
        }
        if (call.type_arguments.len == 0) {
            for (structure.methods) |method| {
                if (!std.mem.eql(u8, method.name, call.name) or !methodVisible(call, method)) continue;
                if (self.argumentsMatch(method.parameters, actual_types, &.{})) return null;
            }
        }

        var selected: ?Ast.Function = null;
        var selected_arguments: []const Ast.Type = &.{};
        var saw_generic = false;
        var saw_type_arity = false;
        for (source_structure.methods) |method| {
            if (method.type_parameters.len == 0 or !std.mem.eql(u8, method.name, call.name) or !methodVisible(call, method)) continue;
            saw_generic = true;
            if (call.type_arguments.len != 0) {
                if (call.type_arguments.len != method.type_parameters.len) continue;
                saw_type_arity = true;
                if (!parametersAcceptArity(method.parameters, actual_types.len) or
                    !self.argumentsMatch(method.parameters, actual_types, call.type_arguments)) continue;
                if (selected != null) return self.ambiguousMethod(call.name_position, call.name);
                selected = method;
                selected_arguments = call.type_arguments;
            } else {
                if (!parametersAcceptArity(method.parameters, actual_types.len)) continue;
                saw_type_arity = true;
                const inferred = try self.inferTypeArguments(method, actual_types) orelse continue;
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

    fn instantiateMethod(
        self: *Specializer,
        structure_type: Ast.Type,
        template: Ast.Function,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError![]const u8 {
        for (arguments) |argument| if (argument == .void) return self.fail(position, "'void' is not a generic type argument");
        for (self.method_specializations.items) |specialization| {
            if (specialization.structure != structure_type or !samePosition(specialization.template_position, template.name_position)) continue;
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
        const name = try self.specializationName(template.name, arguments);
        const specialization_index = self.method_specializations.items.len;
        try self.method_specializations.append(self.allocator, .{
            .structure = structure_type,
            .template_position = template.name_position,
            .arguments = try self.allocator.dupe(Ast.Type, arguments),
            .name = name,
        });
        var concrete = template;
        concrete.name = name;
        concrete.type_parameters = &.{};
        var locals: std.ArrayList(Binding) = .empty;
        try locals.append(self.allocator, .{ .name = "self", .type = structure_type });
        concrete.parameters = try self.rewriteParameters(template.parameters, arguments, &locals);
        concrete.return_type = try self.rewriteType(template.return_type, arguments, template.name_position);
        const structure_index = self.structureIndexForType(structure_type) orelse return error.InvalidSource;
        const method_index = try self.appendMethod(structure_index, concrete);
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
        for (arguments) |argument| if (argument == .void) return self.fail(position, "'void' is not a generic type argument");
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
        var locals: std.ArrayList(Binding) = .empty;
        concrete.parameters = try self.rewriteParameters(template.parameters, arguments, &locals);
        concrete.return_type = try self.rewriteType(template.return_type, arguments, template.name_position);
        concrete.statements = try self.rewriteStatements(template.statements, arguments, &locals);
        self.specializations.items[specialization_index].visiting = false;
        try self.functions.append(self.allocator, concrete);
        return name;
    }

    fn rewriteType(
        self: *Specializer,
        type_value: Ast.Type,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError!Ast.Type {
        if (type_value.optionalChild()) |child| return .optional(try self.rewriteType(child, arguments, position));
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
        if (self.structureTemplateForType(type_value)) |template| {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "generic struct '{s}' requires {d} type argument{s}",
                .{ template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s" },
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
        return type_value;
    }

    fn specializeStructureCall(self: *Specializer, call: Ast.Expression.Call) SpecializeError!?[]const u8 {
        const base = self.typeForName(call.name) orelse return null;
        if (self.structureTemplateForType(base)) |template| {
            if (call.type_arguments.len == 0) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "generic struct '{s}' requires {d} type argument{s}",
                    .{ template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s" },
                );
                return self.fail(call.name_position, message);
            }
            const specialized = try self.instantiateStructure(base, call.type_arguments, call.name_position);
            return self.typeName(specialized);
        }
        if (call.type_arguments.len != 0 and self.structureForType(base) != null) {
            const message = try std.fmt.allocPrint(self.allocator, "struct '{s}' does not accept type arguments", .{call.name});
            return self.fail(call.name_position, message);
        }
        return null;
    }

    fn instantiateStructure(
        self: *Specializer,
        base: Ast.Type,
        arguments: []const Ast.Type,
        position: Source.Position,
    ) SpecializeError!Ast.Type {
        const template = self.structureTemplateForType(base) orelse {
            const name = self.typeName(base);
            const message = try std.fmt.allocPrint(self.allocator, "struct '{s}' does not accept type arguments", .{name});
            return self.fail(position, message);
        };
        if (arguments.len != template.type_parameters.len) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "generic struct '{s}' expects {d} type argument{s}, found {d}",
                .{ template.name, template.type_parameters.len, if (template.type_parameters.len == 1) "" else "s", arguments.len },
            );
            return self.fail(position, message);
        }
        for (arguments) |argument| if (argument == .void) return self.fail(position, "'void' is not a generic type argument");
        for (self.structure_specializations.items) |specialization| {
            if (!samePosition(specialization.template_position, template.name_position)) continue;
            if (std.mem.eql(Ast.Type, specialization.arguments, arguments)) return specialization.type;
            if (specialization.visiting) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "generic struct '{s}' recursively expands with different type arguments",
                    .{template.name},
                );
                return self.fail(position, message);
            }
        }

        const name = try self.specializationName(template.name, arguments);
        const type_value: Ast.Type = .structure(self.type_names.items.len);
        try self.type_names.append(self.allocator, name);
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
        const structure_index = self.structures.items.len;
        try self.structures.append(self.allocator, concrete);
        try self.rewriteStructureAt(structure_index, arguments);
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
        const type_value: Ast.Type = .structure(self.type_names.items.len);
        try self.type_names.append(self.allocator, name);
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
            if (!std.mem.eql(u8, function.name, call.name) or !functionVisible(call, function)) continue;
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
        return compatible(actual, pattern);
    }

    fn argumentsMatch(self: *Specializer, parameters: []const Ast.Parameter, actual: []const Ast.Type, arguments: []const Ast.Type) bool {
        if (!parametersAcceptArity(parameters, actual.len)) return false;
        for (parameters[0..actual.len], actual) |parameter, actual_type| {
            if (!self.matchesPattern(parameter.type, actual_type, arguments)) return false;
        }
        return true;
    }

    fn matchesPattern(self: *Specializer, pattern: Ast.Type, actual: Ast.Type, arguments: []const Ast.Type) bool {
        if (pattern.optionalChild()) |child| {
            const expected_child = self.substitutedPattern(child, arguments) orelse return false;
            return compatible(actual, .optional(expected_child));
        }
        if (pattern.genericParameterIndex()) |index| {
            return index < arguments.len and compatible(actual, arguments[index]);
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
        return compatible(actual, pattern);
    }

    fn substitutedPattern(self: *Specializer, pattern: Ast.Type, arguments: []const Ast.Type) ?Ast.Type {
        _ = self;
        if (pattern.genericParameterIndex()) |index| return if (index < arguments.len) arguments[index] else null;
        return pattern;
    }

    fn inferExpressionType(self: *Specializer, expression: *const Ast.Expression, locals: []const Binding) ?Ast.Type {
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
                break :local null;
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
                else => self.inferExpressionType(binary.left, locals),
            },
            .conversion => |conversion| conversion.target,
            .string_count => .int,
            .sequence_literal => |literal| literal.inferred_type,
            .index_access => |access| index_type: {
                const base = self.inferExpressionType(access.base, locals) orelse break :index_type null;
                const structure = self.structureForType(base) orelse break :index_type null;
                break :index_type if (structure.collection) |collection| collection.element else null;
            },
            .match_expression => |match_value| match_type: {
                for (match_value.branches) |branch| if (branch.value) |value| {
                    break :match_type self.inferExpressionType(value, locals);
                };
                break :match_type null;
            },
        };
    }

    fn structureForType(self: *Specializer, type_value: Ast.Type) ?Ast.Structure {
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

    fn sourceStructureForType(self: *Specializer, type_value: Ast.Type) ?Ast.Structure {
        const index = type_value.structureIndex() orelse return null;
        if (index >= self.type_names.items.len) return null;
        const name = self.type_names.items[index];
        for (self.source.structures) |structure| {
            if (structure.type_parameters.len == 0 and std.mem.eql(u8, structure.name, name)) return structure;
        }
        return null;
    }

    fn structureIndexForType(self: *Specializer, type_value: Ast.Type) ?usize {
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

    fn structureTemplateForType(self: *Specializer, type_value: Ast.Type) ?Ast.Structure {
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

    fn typeForName(self: *Specializer, name: []const u8) ?Ast.Type {
        for (self.type_names.items, 0..) |candidate, index| if (std.mem.eql(u8, candidate, name)) return .structure(index);
        return null;
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

    fn typeName(self: *Specializer, type_value: Ast.Type) []const u8 {
        if (type_value.optionalChild()) |child| {
            return std.fmt.allocPrint(self.allocator, "{s}?", .{self.typeName(child)}) catch "optional";
        }
        if (type_value.structureIndex()) |index| if (index < self.type_names.items.len) return self.type_names.items[index];
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

    fn fail(self: *Specializer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn compatible(actual: Ast.Type, expected: Ast.Type) bool {
    if (actual == expected or Numeric.canWiden(actual, expected)) return true;
    if (expected.optionalChild()) |child| return actual == child or actual.optionalChild() == child;
    return false;
}

fn parametersAcceptArity(parameters: []const Ast.Parameter, arity: usize) bool {
    var required = parameters.len;
    for (parameters, 0..) |parameter, index| if (parameter.default != null) {
        required = index;
        break;
    };
    return arity >= required and arity <= parameters.len;
}

fn functionVisible(call: Ast.Expression.Call, function: Ast.Function) bool {
    if (function.is_internal) return call.name_position.file == function.position.file;
    return call.owner == function.owner or function.is_public;
}

fn methodVisible(call: Ast.Expression.Call, method: Ast.Function) bool {
    if (method.is_internal) return call.name_position.file == method.position.file;
    return call.owner == method.owner or method.is_public;
}

fn samePosition(left: Source.Position, right: Source.Position) bool {
    return left.offset == right.offset and left.file == right.file;
}

fn remapConcreteType(type_value: Ast.Type, map: []const ?Ast.Type) Ast.Type {
    if (type_value.optionalChild()) |child| return .optional(remapConcreteType(child, map));
    const index = type_value.structureIndex() orelse return type_value;
    return if (index < map.len) map[index] orelse type_value else type_value;
}

fn remapStatementTypes(statements: []const Ast.Statement, map: []const ?Ast.Type) void {
    for (@constCast(statements)) |*statement| switch (statement.*) {
        .variable_declaration => |*declaration| {
            if (declaration.annotation) |annotation| declaration.annotation = remapConcreteType(annotation, map);
            if (declaration.initializer) |initializer| remapExpressionTypes(initializer, map);
        },
        .assignment_statement => |assignment| {
            if (assignment.value) |value| remapExpressionTypes(value, map);
            for (assignment.target.indices) |target_index| remapExpressionTypes(target_index.value, map);
        },
        .return_statement => |return_statement| if (return_statement.value) |value| remapExpressionTypes(value, map),
        .expression_statement => |expression| remapExpressionTypes(expression, map),
        .print_statement => |print_statement| for (print_statement.values) |value| remapExpressionTypes(value, map),
        .assert_statement => |assertion| {
            remapExpressionTypes(assertion.condition, map);
            remapExpressionTypes(assertion.message, map);
        },
        .panic_statement => |effect| remapExpressionTypes(effect.value, map),
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                remapExpressionTypes(branch.condition.source(), map);
                remapStatementTypes(branch.statements, map);
            }
            if (conditional.else_statements) |nested| remapStatementTypes(nested, map);
        },
        .while_statement => |loop| {
            remapExpressionTypes(loop.condition.source(), map);
            remapStatementTypes(loop.statements, map);
        },
        .break_statement, .continue_statement => {},
    };
}

fn remapExpressionTypes(expression: *Ast.Expression, map: []const ?Ast.Type) void {
    switch (expression.value) {
        .call => |*call| {
            if (call.result_type) |result_type| call.result_type = remapConcreteType(result_type, map);
            for (@constCast(call.type_arguments)) |*argument| argument.* = remapConcreteType(argument.*, map);
            for (call.arguments) |argument| remapExpressionTypes(argument, map);
            for (call.named_arguments) |argument| remapExpressionTypes(argument.value, map);
            if (call.receiver) |receiver| remapExpressionTypes(receiver, map);
        },
        .field_access => |access| remapExpressionTypes(access.base, map),
        .generic_reference => |reference| for (@constCast(reference.type_arguments)) |*argument| {
            argument.* = remapConcreteType(argument.*, map);
        },
        .unary => |unary| remapExpressionTypes(unary.operand, map),
        .binary => |binary| {
            remapExpressionTypes(binary.left, map);
            remapExpressionTypes(binary.right, map);
        },
        .conversion => |*conversion| {
            conversion.target = remapConcreteType(conversion.target, map);
            remapExpressionTypes(conversion.operand, map);
        },
        .string_count => |operand| remapExpressionTypes(operand, map),
        .sequence_literal => |*literal| {
            if (literal.inferred_type) |type_value| literal.inferred_type = remapConcreteType(type_value, map);
            for (literal.values) |value| remapExpressionTypes(value, map);
        },
        .index_access => |access| {
            remapExpressionTypes(access.base, map);
            remapExpressionTypes(access.index, map);
        },
        .interpolated_string => |interpolated| for (interpolated.parts) |part| switch (part) {
            .text => {},
            .expression => |nested| remapExpressionTypes(nested, map),
        },
        .match_expression => |match_value| {
            remapExpressionTypes(match_value.subject, map);
            for (match_value.branches) |branch| {
                if (branch.value) |value| remapExpressionTypes(value, map);
                if (branch.statements) |statements| remapStatementTypes(statements, map);
            }
        },
        else => {},
    }
}
