const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn independentQuery(self: anytype, target_name: []const u8, dependencies: []const Ast.SystemDependency) ?usize {
    var query_dependency: ?usize = null;
    for (dependencies, 0..) |dependency, index| {
        if (dependency.kind != .query) continue;
        if (query_dependency != null) return null;
        query_dependency = index;
    }
    const dependency_index = query_dependency orelse return null;
    const function = findFunction(self.functions.items, target_name) orelse return null;
    if (function.statements.len != 1 or function.statements[0] != .for_statement) return null;
    const loop = function.statements[0].for_statement;
    if (loop.source != .collection or loop.source.collection.value != .identifier) return null;
    const query_parameter = parameterForDependency(function, dependencies, dependency_index) orelse return null;
    if (!std.mem.eql(u8, loop.source.collection.value.identifier, query_parameter.name)) return null;

    const query = self.structureForType(dependencies[dependency_index].type) orelse return null;
    const pattern = self.structureForType(query.query_pattern orelse return null) orelse return null;
    if (pattern.fields.len != loop.bindings.len) return null;

    var mutable_bindings: std.ArrayList([]const u8) = .empty;
    defer mutable_bindings.deinit(self.allocator);
    for (pattern.fields, loop.bindings) |field, binding| {
        if (field.access_mode == .mutable) mutable_bindings.append(self.allocator, binding.name) catch return null;
    }
    var command_names: std.ArrayList([]const u8) = .empty;
    defer command_names.deinit(self.allocator);
    for (dependencies, function.parameters) |dependency, parameter| {
        if (std.mem.eql(u8, self.typeName(dependency.type), "GFX.ECS.Commands") and dependency.mode == .mutable) {
            command_names.append(self.allocator, parameter.name) catch return null;
        } else if (dependency.kind != .query and dependency.mode == .mutable) {
            return null;
        }
    }
    var locals: std.ArrayList([]const u8) = .empty;
    defer locals.deinit(self.allocator);
    if (!statementsAreIndependent(loop.statements, mutable_bindings.items, command_names.items, &locals, self.allocator)) return null;
    return dependency_index;
}

fn findFunction(functions: []const Ast.Function, requested: []const u8) ?Ast.Function {
    for (functions) |function| {
        if (std.mem.eql(u8, function.name, requested)) return function;
        if (function.name.len > requested.len and std.mem.endsWith(u8, function.name, requested) and
            function.name[function.name.len - requested.len - 1] == '.') return function;
    }
    return null;
}

fn parameterForDependency(
    function: Ast.Function,
    dependencies: []const Ast.SystemDependency,
    dependency_index: usize,
) ?Ast.Parameter {
    if (function.parameters.len != dependencies.len or dependency_index >= function.parameters.len) return null;
    return function.parameters[dependency_index];
}

fn statementsAreIndependent(
    statements: []const Ast.Statement,
    mutable_bindings: []const []const u8,
    command_names: []const []const u8,
    locals: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
) bool {
    for (statements) |statement| switch (statement) {
        .variable_declaration => |declaration| {
            if (declaration.initializer) |initializer| if (!expressionIsSafe(initializer, mutable_bindings, command_names)) return false;
            locals.append(allocator, declaration.name) catch return false;
        },
        .assignment_statement => |assignment| {
            if (!contains(mutable_bindings, assignment.target.name) and !contains(locals.items, assignment.target.name)) return false;
            if (assignment.value) |value| if (!expressionIsSafe(value, mutable_bindings, command_names)) return false;
            for (assignment.target.indices) |index| if (!expressionIsSafe(index.value, mutable_bindings, command_names)) return false;
        },
        .expression_statement => |expression| if (!effectIsSafe(expression, mutable_bindings, command_names)) return false,
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                if (branch.condition != .expression or !expressionIsSafe(branch.condition.expression, mutable_bindings, command_names)) return false;
                const count = locals.items.len;
                if (!statementsAreIndependent(branch.statements, mutable_bindings, command_names, locals, allocator)) return false;
                locals.shrinkRetainingCapacity(count);
            }
            if (conditional.else_statements) |nested| {
                const count = locals.items.len;
                if (!statementsAreIndependent(nested, mutable_bindings, command_names, locals, allocator)) return false;
                locals.shrinkRetainingCapacity(count);
            }
        },
        .continue_statement => {},
        .return_statement,
        .print_statement,
        .assert_statement,
        .panic_statement,
        .while_statement,
        .for_statement,
        .mutex_statement,
        .break_statement,
        => return false,
    };
    return true;
}

fn effectIsSafe(expression: *const Ast.Expression, mutable_bindings: []const []const u8, command_names: []const []const u8) bool {
    if (expression.value != .call) return false;
    const call = expression.value.call;
    const receiver = call.receiver orelse return false;
    const root = expressionRoot(receiver) orelse return false;
    if (!contains(command_names, root) and !contains(mutable_bindings, root)) return false;
    for (call.arguments) |argument| if (!expressionIsSafe(argument, mutable_bindings, command_names)) return false;
    for (call.named_arguments) |argument| if (!expressionIsSafe(argument.value, mutable_bindings, command_names)) return false;
    return true;
}

fn expressionIsSafe(expression: *const Ast.Expression, mutable_bindings: []const []const u8, command_names: []const []const u8) bool {
    return switch (expression.value) {
        .integer, .floating, .boolean, .null_value, .string, .identifier => true,
        .field_access => |access| expressionIsSafe(access.base, mutable_bindings, command_names),
        .unary => |unary| expressionIsSafe(unary.operand, mutable_bindings, command_names),
        .binary => |binary| expressionIsSafe(binary.left, mutable_bindings, command_names) and
            expressionIsSafe(binary.right, mutable_bindings, command_names),
        .conversion => |conversion| expressionIsSafe(conversion.operand, mutable_bindings, command_names),
        .string_count => |operand| expressionIsSafe(operand, mutable_bindings, command_names),
        .index_access => |access| expressionIsSafe(access.base, mutable_bindings, command_names) and
            expressionIsSafe(access.index, mutable_bindings, command_names),
        .slice_access => |access| expressionIsSafe(access.base, mutable_bindings, command_names) and
            expressionIsSafe(access.start, mutable_bindings, command_names) and expressionIsSafe(access.end, mutable_bindings, command_names),
        .tuple_literal => |literal| safe: {
            for (literal.elements) |element| if (!expressionIsSafe(element.value, mutable_bindings, command_names)) break :safe false;
            break :safe true;
        },
        .sequence_literal => |literal| safe: {
            for (literal.values) |value| if (!expressionIsSafe(value, mutable_bindings, command_names)) break :safe false;
            break :safe true;
        },
        .call => |call| safe: {
            const receiver = call.receiver orelse break :safe false;
            const root = expressionRoot(receiver) orelse break :safe false;
            if (!contains(mutable_bindings, root) and !contains(command_names, root)) break :safe false;
            for (call.arguments) |argument| if (!expressionIsSafe(argument, mutable_bindings, command_names)) break :safe false;
            for (call.named_arguments) |argument| if (!expressionIsSafe(argument.value, mutable_bindings, command_names)) break :safe false;
            break :safe true;
        },
        .interpolated_string, .generic_reference, .cascade, .match_expression => false,
    };
}

fn expressionRoot(expression: *const Ast.Expression) ?[]const u8 {
    return switch (expression.value) {
        .identifier => |name| name,
        .field_access => |access| expressionRoot(access.base),
        .index_access => |access| expressionRoot(access.base),
        .slice_access => |access| expressionRoot(access.base),
        else => null,
    };
}

fn contains(values: []const []const u8, expected: []const u8) bool {
    for (values) |value| if (std.mem.eql(u8, value, expected)) return true;
    return false;
}
