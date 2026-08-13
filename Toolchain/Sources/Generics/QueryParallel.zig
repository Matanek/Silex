const std = @import("std");
const Ast = @import("../Ast.zig");
const WorkerSafety = @import("WorkerSafety.zig");

pub fn independentQuery(self: anytype, target_name: []const u8, dependencies: []const Ast.SystemDependency) ?usize {
    var query_dependency: ?usize = null;
    for (dependencies, 0..) |dependency, index| {
        if (dependency.kind != .query) continue;
        if (query_dependency != null) return null;
        query_dependency = index;
    }
    const dependency_index = query_dependency orelse return null;
    const function = findFunction(self.functions.items, target_name) orelse return null;
    var loop_index: ?usize = null;
    for (function.statements, 0..) |statement, index| switch (statement) {
        .variable_declaration => {
            if (loop_index != null) return null;
        },
        .for_statement => {
            if (loop_index != null) return null;
            loop_index = index;
        },
        else => return null,
    };
    const query_loop_index = loop_index orelse return null;
    if (query_loop_index + 1 != function.statements.len) return null;
    const loop = function.statements[query_loop_index].for_statement;
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
    for (function.statements[0..query_loop_index]) |statement| {
        const declaration = statement.variable_declaration;
        if (declaration.initializer) |initializer| {
            if (!expressionIsSafe(self, initializer, mutable_bindings.items, command_names.items, locals.items)) return null;
        }
        locals.append(self.allocator, declaration.name) catch return null;
    }
    if (!statementsAreIndependent(self, loop.statements, mutable_bindings.items, command_names.items, &locals, self.allocator)) return null;
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
    self: anytype,
    statements: []const Ast.Statement,
    mutable_bindings: []const []const u8,
    command_names: []const []const u8,
    locals: *std.ArrayList([]const u8),
    allocator: std.mem.Allocator,
) bool {
    for (statements) |statement| switch (statement) {
        .variable_declaration => |declaration| {
            if (declaration.initializer) |initializer| if (!expressionIsSafe(self, initializer, mutable_bindings, command_names, locals.items)) return false;
            locals.append(allocator, declaration.name) catch return false;
        },
        .assignment_statement => |assignment| {
            if (!contains(mutable_bindings, assignment.target.name) and !contains(locals.items, assignment.target.name)) return false;
            if (assignment.value) |value| if (!expressionIsSafe(self, value, mutable_bindings, command_names, locals.items)) return false;
            for (assignment.target.indices) |index| if (!expressionIsSafe(self, index.value, mutable_bindings, command_names, locals.items)) return false;
        },
        .expression_statement => |expression| if (!effectIsSafe(self, expression, mutable_bindings, command_names, locals.items)) return false,
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                if (branch.condition != .expression or !expressionIsSafe(self, branch.condition.expression, mutable_bindings, command_names, locals.items)) return false;
                const count = locals.items.len;
                if (!statementsAreIndependent(self, branch.statements, mutable_bindings, command_names, locals, allocator)) return false;
                locals.shrinkRetainingCapacity(count);
            }
            if (conditional.else_statements) |nested| {
                const count = locals.items.len;
                if (!statementsAreIndependent(self, nested, mutable_bindings, command_names, locals, allocator)) return false;
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

fn effectIsSafe(self: anytype, expression: *const Ast.Expression, mutable_bindings: []const []const u8, command_names: []const []const u8, locals: []const []const u8) bool {
    if (expression.value != .call) return false;
    const call = expression.value.call;
    const receiver = call.receiver orelse return false;
    const root = expressionRoot(receiver) orelse return false;
    if (!contains(command_names, root) and !contains(mutable_bindings, root)) return false;
    for (call.arguments) |argument| if (!expressionIsSafe(self, argument, mutable_bindings, command_names, locals)) return false;
    for (call.named_arguments) |argument| if (!expressionIsSafe(self, argument.value, mutable_bindings, command_names, locals)) return false;
    return true;
}

fn expressionIsSafe(self: anytype, expression: *const Ast.Expression, mutable_bindings: []const []const u8, command_names: []const []const u8, locals: []const []const u8) bool {
    return switch (expression.value) {
        .integer, .floating, .boolean, .null_value, .string, .identifier => true,
        .field_access => |access| expressionIsSafe(self, access.base, mutable_bindings, command_names, locals),
        .unary => |unary| expressionIsSafe(self, unary.operand, mutable_bindings, command_names, locals),
        .binary => |binary| expressionIsSafe(self, binary.left, mutable_bindings, command_names, locals) and
            expressionIsSafe(self, binary.right, mutable_bindings, command_names, locals),
        .conversion => |conversion| expressionIsSafe(self, conversion.operand, mutable_bindings, command_names, locals),
        .string_count => |operand| expressionIsSafe(self, operand, mutable_bindings, command_names, locals),
        .index_access => |access| expressionIsSafe(self, access.base, mutable_bindings, command_names, locals) and
            expressionIsSafe(self, access.index, mutable_bindings, command_names, locals),
        .slice_access => |access| expressionIsSafe(self, access.base, mutable_bindings, command_names, locals) and
            expressionIsSafe(self, access.start, mutable_bindings, command_names, locals) and expressionIsSafe(self, access.end, mutable_bindings, command_names, locals),
        .tuple_literal => |literal| safe: {
            for (literal.elements) |element| if (!expressionIsSafe(self, element.value, mutable_bindings, command_names, locals)) break :safe false;
            break :safe true;
        },
        .sequence_literal => |literal| safe: {
            for (literal.values) |value| if (!expressionIsSafe(self, value, mutable_bindings, command_names, locals)) break :safe false;
            break :safe true;
        },
        .call => |call| safe: {
            if (call.receiver) |receiver| if (!expressionIsSafe(self, receiver, mutable_bindings, command_names, locals)) break :safe false;
            for (call.arguments) |argument| if (!expressionIsSafe(self, argument, mutable_bindings, command_names, locals)) break :safe false;
            for (call.named_arguments) |argument| if (!expressionIsSafe(self, argument.value, mutable_bindings, command_names, locals)) break :safe false;
            if (std.mem.startsWith(u8, call.name, "STD.Math.")) break :safe true;
            if (call.receiver) |receiver| if (expressionRoot(receiver)) |root| {
                if (contains(mutable_bindings, root) or contains(command_names, root) or contains(locals, root)) break :safe true;
                if (std.mem.eql(u8, call.name, "count") or std.mem.eql(u8, call.name, "is_empty")) break :safe true;
            };
            if (helperCallIsReadOnly(self, call, 0)) break :safe true;
            break :safe WorkerSafety.readOnlyCallIsWorkerSafe(self, call) catch false;
        },
        .interpolated_string, .generic_reference, .cascade, .match_expression => false,
    };
}

fn helperCallIsReadOnly(self: anytype, call: Ast.Expression.Call, depth: usize) bool {
    if (depth == 32) return false;
    if (call.receiver != null) return false;
    const function = findFunction(self.functions.items, call.name) orelse return false;
    if (function.parameters.len != call.arguments.len + call.named_arguments.len) return false;
    var bindings: std.ArrayList([]const u8) = .empty;
    defer bindings.deinit(self.allocator);
    for (function.parameters) |parameter| {
        if (parameter.mode == .mutable) return false;
        bindings.append(self.allocator, parameter.name) catch return false;
    }
    return helperStatementsAreReadOnly(self, function.statements, &bindings, depth + 1);
}

fn helperStatementsAreReadOnly(self: anytype, statements: []const Ast.Statement, bindings: *std.ArrayList([]const u8), depth: usize) bool {
    for (statements) |statement| switch (statement) {
        .variable_declaration => |declaration| {
            if (declaration.initializer) |initializer| if (!helperExpressionIsReadOnly(self, initializer, bindings.items, depth)) return false;
            bindings.append(self.allocator, declaration.name) catch return false;
        },
        .assignment_statement => |assignment| {
            if (!contains(bindings.items, assignment.target.name)) return false;
            if (assignment.value) |value| if (!helperExpressionIsReadOnly(self, value, bindings.items, depth)) return false;
            for (assignment.target.indices) |index| if (!helperExpressionIsReadOnly(self, index.value, bindings.items, depth)) return false;
        },
        .return_statement => |returned| if (returned.value) |value| {
            if (!helperExpressionIsReadOnly(self, value, bindings.items, depth)) return false;
        },
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                if (branch.condition != .expression or !helperExpressionIsReadOnly(self, branch.condition.expression, bindings.items, depth)) return false;
                const count = bindings.items.len;
                if (!helperStatementsAreReadOnly(self, branch.statements, bindings, depth)) return false;
                bindings.shrinkRetainingCapacity(count);
            }
            if (conditional.else_statements) |nested| {
                const count = bindings.items.len;
                if (!helperStatementsAreReadOnly(self, nested, bindings, depth)) return false;
                bindings.shrinkRetainingCapacity(count);
            }
        },
        .while_statement => |loop| {
            if (!helperExpressionIsReadOnly(self, loop.condition.source(), bindings.items, depth)) return false;
            const count = bindings.items.len;
            if (!helperStatementsAreReadOnly(self, loop.statements, bindings, depth)) return false;
            bindings.shrinkRetainingCapacity(count);
        },
        .for_statement => |loop| {
            switch (loop.source) {
                .collection => |collection| if (!helperExpressionIsReadOnly(self, collection, bindings.items, depth)) return false,
                .range => |range| if (!helperExpressionIsReadOnly(self, range.start, bindings.items, depth) or
                    !helperExpressionIsReadOnly(self, range.end, bindings.items, depth)) return false,
            }
            const count = bindings.items.len;
            for (loop.bindings) |binding| bindings.append(self.allocator, binding.name) catch return false;
            if (!helperStatementsAreReadOnly(self, loop.statements, bindings, depth)) return false;
            bindings.shrinkRetainingCapacity(count);
        },
        .break_statement, .continue_statement => {},
        .expression_statement, .print_statement, .assert_statement, .panic_statement, .mutex_statement => return false,
    };
    return true;
}

fn helperExpressionIsReadOnly(self: anytype, expression: *const Ast.Expression, bindings: []const []const u8, depth: usize) bool {
    return switch (expression.value) {
        .integer, .floating, .boolean, .null_value, .string, .identifier => true,
        .field_access => |access| helperExpressionIsReadOnly(self, access.base, bindings, depth),
        .unary => |unary| helperExpressionIsReadOnly(self, unary.operand, bindings, depth),
        .binary => |binary| helperExpressionIsReadOnly(self, binary.left, bindings, depth) and
            helperExpressionIsReadOnly(self, binary.right, bindings, depth),
        .conversion => |conversion| helperExpressionIsReadOnly(self, conversion.operand, bindings, depth),
        .string_count => |operand| helperExpressionIsReadOnly(self, operand, bindings, depth),
        .index_access => |access| helperExpressionIsReadOnly(self, access.base, bindings, depth) and
            helperExpressionIsReadOnly(self, access.index, bindings, depth),
        .slice_access => |access| helperExpressionIsReadOnly(self, access.base, bindings, depth) and
            helperExpressionIsReadOnly(self, access.start, bindings, depth) and helperExpressionIsReadOnly(self, access.end, bindings, depth),
        .tuple_literal => |literal| safe: {
            for (literal.elements) |element| if (!helperExpressionIsReadOnly(self, element.value, bindings, depth)) break :safe false;
            break :safe true;
        },
        .sequence_literal => |literal| safe: {
            for (literal.values) |value| if (!helperExpressionIsReadOnly(self, value, bindings, depth)) break :safe false;
            break :safe true;
        },
        .call => |call| safe: {
            if (call.receiver) |receiver| {
                if (!helperExpressionIsReadOnly(self, receiver, bindings, depth)) break :safe false;
                const root = expressionRoot(receiver) orelse break :safe false;
                if (!contains(bindings, root) and !std.mem.eql(u8, root, "Math")) break :safe false;
            }
            for (call.arguments) |argument| if (!helperExpressionIsReadOnly(self, argument, bindings, depth)) break :safe false;
            for (call.named_arguments) |argument| if (!helperExpressionIsReadOnly(self, argument.value, bindings, depth)) break :safe false;
            if (call.receiver != null) break :safe true;
            break :safe helperCallIsReadOnly(self, call, depth);
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
