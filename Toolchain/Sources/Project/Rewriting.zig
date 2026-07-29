const Ast = @import("../Ast.zig");
const Iterations = @import("Iterations.zig");

pub fn statements(self: anytype, module: usize, source: []const Ast.Statement, type_map: []const Ast.Type) ![]const Ast.Statement {
    const rewritten = try self.allocator.alloc(Ast.Statement, source.len);
    for (source, 0..) |statement, index| rewritten[index] = switch (statement) {
        .variable_declaration => |declaration| variable: {
            var value = declaration;
            if (value.annotation) |annotation| value.annotation = self.remapType(module, type_map, annotation);
            if (value.initializer) |initializer| try self.rewriteExpression(module, initializer, type_map);
            break :variable .{ .variable_declaration = value };
        },
        .assignment_statement => |assignment| assignment_statement: {
            for (@constCast(assignment.target.type_arguments)) |*argument| {
                argument.* = self.remapType(module, type_map, argument.*);
            }
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
        .for_statement => |loop| .{ .for_statement = try Iterations.rewrite(self, module, loop, type_map) },
        .mutex_statement => |mutex| .{ .mutex_statement = .{
            .position = mutex.position,
            .statements = try self.rewriteStatements(module, mutex.statements, type_map),
        } },
        .break_statement => |position| .{ .break_statement = position },
        .continue_statement => |position| .{ .continue_statement = position },
    };
    return rewritten;
}
