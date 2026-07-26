const std = @import("std");
const Ast = @import("../Ast.zig");
const Numeric = @import("../Numeric.zig");
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

pub const Specializer = struct {
    allocator: Allocator,
    source: Ast.Program = undefined,
    functions: std.ArrayList(Ast.Function) = .empty,
    specializations: std.ArrayList(FunctionSpecialization) = .empty,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: Allocator) Specializer {
        return .{ .allocator = allocator };
    }

    pub fn specialize(self: *Specializer, program: Ast.Program) SpecializeError!Ast.Program {
        self.source = program;
        self.diagnostic = null;
        for (program.functions) |function| {
            if (function.type_parameters.len == 0) try self.functions.append(self.allocator, function);
        }

        var function_index: usize = 0;
        while (function_index < self.functions.items.len) : (function_index += 1) {
            var function = self.functions.items[function_index];
            var locals: std.ArrayList(Binding) = .empty;
            for (function.parameters) |parameter| try locals.append(self.allocator, .{ .name = parameter.name, .type = parameter.type });
            function.parameters = try self.rewriteParameters(function.parameters, &.{}, &locals);
            function.statements = try self.rewriteStatements(function.statements, &.{}, &locals);
            self.functions.items[function_index] = function;
        }

        const structures = try self.allocator.alloc(Ast.Structure, program.structures.len);
        for (program.structures, 0..) |structure, structure_index| {
            structures[structure_index] = structure;
            const constructors = try self.allocator.alloc(Ast.Constructor, structure.constructors.len);
            for (structure.constructors, 0..) |constructor, constructor_index| {
                constructors[constructor_index] = constructor;
                var locals: std.ArrayList(Binding) = .empty;
                try locals.append(self.allocator, .{ .name = "self", .type = self.typeForName(structure.name) orelse return error.InvalidSource });
                constructors[constructor_index].parameters = try self.rewriteParameters(constructor.parameters, &.{}, &locals);
                constructors[constructor_index].statements = try self.rewriteStatements(constructor.statements, &.{}, &locals);
            }
            structures[structure_index].constructors = constructors;
            const methods = try self.allocator.alloc(Ast.Function, structure.methods.len);
            for (structure.methods, 0..) |method, method_index| {
                methods[method_index] = method;
                var locals: std.ArrayList(Binding) = .empty;
                try locals.append(self.allocator, .{ .name = "self", .type = self.typeForName(structure.name) orelse return error.InvalidSource });
                methods[method_index].parameters = try self.rewriteParameters(method.parameters, &.{}, &locals);
                methods[method_index].statements = try self.rewriteStatements(method.statements, &.{}, &locals);
            }
            structures[structure_index].methods = methods;
        }

        var result = program;
        result.structures = structures;
        result.functions = try self.functions.toOwnedSlice(self.allocator);
        return result;
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
            rewritten[index].type = substituteType(parameter.type, arguments);
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
                if (copy.annotation) |annotation| copy.annotation = substituteType(annotation, arguments);
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
                for (copy.type_arguments, 0..) |type_argument, index| type_arguments[index] = substituteType(type_argument, arguments);
                copy.type_arguments = type_arguments;
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
                copy.target = substituteType(copy.target, arguments);
                copy.operand = try self.rewriteExpression(copy.operand, arguments, locals);
                break :value .{ .conversion = copy };
            },
            .string_count => |operand| .{ .string_count = try self.rewriteExpression(operand, arguments, locals) },
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
                if (!argumentsMatch(function.parameters, actual_types, call.type_arguments)) continue;
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
        concrete.return_type = substituteType(template.return_type, arguments);
        concrete.statements = try self.rewriteStatements(template.statements, arguments, &locals);
        self.specializations.items[specialization_index].visiting = false;
        try self.functions.append(self.allocator, concrete);
        return name;
    }

    fn inferTypeArguments(self: *Specializer, template: Ast.Function, actual: []const Ast.Type) Allocator.Error!?[]const Ast.Type {
        const inferred = try self.allocator.alloc(?Ast.Type, template.type_parameters.len);
        @memset(inferred, null);
        for (template.parameters[0..actual.len], actual) |parameter, actual_type| {
            if (!unify(parameter.type, actual_type, inferred)) return null;
        }
        const result = try self.allocator.alloc(Ast.Type, inferred.len);
        for (inferred, 0..) |argument, index| result[index] = argument orelse return null;
        if (!argumentsMatch(template.parameters, actual, result)) return null;
        return result;
    }

    fn hasCompatibleConcrete(self: *Specializer, call: Ast.Expression.Call, actual: []const Ast.Type) bool {
        for (self.source.functions) |function| {
            if (function.type_parameters.len != 0 or !std.mem.eql(u8, function.name, call.name) or !functionVisible(call, function)) continue;
            if (!parametersAcceptArity(function.parameters, actual.len)) continue;
            if (argumentsMatch(function.parameters, actual, &.{})) return true;
        }
        return false;
    }

    fn inferExpressionType(self: *Specializer, expression: *const Ast.Expression, locals: []const Binding) ?Ast.Type {
        return switch (expression.value) {
            .integer => .int,
            .floating => .float32,
            .boolean => .bool,
            .string, .interpolated_string => .str,
            .null_value => null,
            .identifier => |name| local: {
                var index = locals.len;
                while (index != 0) {
                    index -= 1;
                    if (std.mem.eql(u8, locals[index].name, name)) break :local locals[index].type;
                }
                break :local null;
            },
            .call => |call| call_type: {
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
            .unary => |unary| if (unary.operator == .logical_not) .bool else self.inferExpressionType(unary.operand, locals),
            .binary => |binary| switch (binary.operator) {
                .less, .less_equal, .greater, .greater_equal, .equal, .not_equal, .logical_and, .logical_or => .bool,
                else => self.inferExpressionType(binary.left, locals),
            },
            .conversion => |conversion| conversion.target,
            .string_count => .int,
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
        if (index >= self.source.type_names.len) return null;
        const name = self.source.type_names[index];
        for (self.source.structures) |structure| if (std.mem.eql(u8, structure.name, name)) return structure;
        return null;
    }

    fn typeForName(self: *Specializer, name: []const u8) ?Ast.Type {
        for (self.source.type_names, 0..) |candidate, index| if (std.mem.eql(u8, candidate, name)) return .structure(index);
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
        if (type_value.optionalChild()) |child| return self.typeName(child);
        if (type_value.structureIndex()) |index| if (index < self.source.type_names.len) return self.source.type_names[index];
        return type_value.name();
    }

    fn ambiguous(self: *Specializer, position: Source.Position, name: []const u8) Source.Error {
        const message = std.fmt.allocPrint(self.allocator, "generic call to '{s}' is ambiguous", .{name}) catch "generic call is ambiguous";
        return self.fail(position, message);
    }

    fn fail(self: *Specializer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn substituteType(type_value: Ast.Type, arguments: []const Ast.Type) Ast.Type {
    if (type_value.optionalChild()) |child| return .optional(substituteType(child, arguments));
    const parameter = type_value.genericParameterIndex() orelse return type_value;
    return if (parameter < arguments.len) arguments[parameter] else type_value;
}

fn unify(pattern: Ast.Type, actual: Ast.Type, inferred: []?Ast.Type) bool {
    if (pattern.optionalChild()) |child| {
        return unify(child, actual.optionalChild() orelse actual, inferred);
    }
    if (pattern.genericParameterIndex()) |index| {
        if (index >= inferred.len or actual == .void) return false;
        if (inferred[index]) |existing| return existing == actual;
        inferred[index] = actual;
        return true;
    }
    return compatible(actual, pattern);
}

fn argumentsMatch(parameters: []const Ast.Parameter, actual: []const Ast.Type, arguments: []const Ast.Type) bool {
    if (!parametersAcceptArity(parameters, actual.len)) return false;
    for (parameters[0..actual.len], actual) |parameter, actual_type| {
        if (!compatible(actual_type, substituteType(parameter.type, arguments))) return false;
    }
    return true;
}

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

fn samePosition(left: Source.Position, right: Source.Position) bool {
    return left.offset == right.offset and left.file == right.file;
}
