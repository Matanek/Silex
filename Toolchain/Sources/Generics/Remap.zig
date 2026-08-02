const Ast = @import("../Ast.zig");

pub fn concreteType(type_value: Ast.Type, map: []const ?Ast.Type) Ast.Type {
    if (type_value.optionalChild()) |child| return .optional(concreteType(child, map));
    const index = type_value.structureIndex() orelse return type_value;
    return if (index < map.len) map[index] orelse type_value else type_value;
}

pub fn statementTypes(statements: []const Ast.Statement, map: []const ?Ast.Type) void {
    for (@constCast(statements)) |*statement| switch (statement.*) {
        .variable_declaration => |*declaration| {
            if (declaration.annotation) |annotation| declaration.annotation = concreteType(annotation, map);
            if (declaration.initializer) |initializer| expressionTypes(initializer, map);
        },
        .assignment_statement => |assignment| {
            for (@constCast(assignment.target.type_arguments)) |*argument| argument.* = concreteType(argument.*, map);
            if (assignment.value) |value| expressionTypes(value, map);
            for (assignment.target.indices) |target_index| expressionTypes(target_index.value, map);
        },
        .return_statement => |return_statement| if (return_statement.value) |value| expressionTypes(value, map),
        .expression_statement => |expression| expressionTypes(expression, map),
        .print_statement => |print_statement| for (print_statement.values) |value| expressionTypes(value, map),
        .assert_statement => |assertion| {
            expressionTypes(assertion.condition, map);
            expressionTypes(assertion.message, map);
        },
        .panic_statement => |effect| expressionTypes(effect.value, map),
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                expressionTypes(branch.condition.source(), map);
                statementTypes(branch.statements, map);
            }
            if (conditional.else_statements) |nested| statementTypes(nested, map);
        },
        .while_statement => |loop| {
            expressionTypes(loop.condition.source(), map);
            statementTypes(loop.statements, map);
        },
        .for_statement => |loop| {
            switch (loop.source) {
                .collection => |source| expressionTypes(source, map),
                .range => |range| {
                    expressionTypes(range.start, map);
                    expressionTypes(range.end, map);
                },
            }
            statementTypes(loop.statements, map);
        },
        .mutex_statement => |mutex| statementTypes(mutex.statements, map),
        .break_statement, .continue_statement => {},
    };
}

pub fn expressionTypes(expression: *Ast.Expression, map: []const ?Ast.Type) void {
    switch (expression.value) {
        .call => |*call| {
            if (call.result_type) |result_type| call.result_type = concreteType(result_type, map);
            for (@constCast(call.type_arguments)) |*argument| argument.* = concreteType(argument.*, map);
            for (call.arguments) |argument| expressionTypes(argument, map);
            for (call.named_arguments) |argument| expressionTypes(argument.value, map);
            if (call.receiver) |receiver| expressionTypes(receiver, map);
        },
        .cascade => |cascade| {
            expressionTypes(cascade.receiver, map);
            for (cascade.operations) |operation| switch (operation) {
                .method_call => |method| {
                    for (@constCast(method.type_arguments)) |*argument| argument.* = concreteType(argument.*, map);
                    for (method.arguments) |argument| expressionTypes(argument, map);
                    for (method.named_arguments) |argument| expressionTypes(argument.value, map);
                },
                .field_assignment => |field| expressionTypes(field.value, map),
            };
        },
        .field_access => |access| expressionTypes(access.base, map),
        .generic_reference => |reference| for (@constCast(reference.type_arguments)) |*argument| {
            argument.* = concreteType(argument.*, map);
        },
        .unary => |unary| {
            expressionTypes(unary.operand, map);
            if (unary.try_alternative) |alternative| {
                if (alternative.statements) |statements| statementTypes(statements, map);
                if (alternative.message) |message| expressionTypes(message, map);
            }
        },
        .binary => |binary| {
            expressionTypes(binary.left, map);
            expressionTypes(binary.right, map);
        },
        .conversion => |*conversion| {
            conversion.target = concreteType(conversion.target, map);
            expressionTypes(conversion.operand, map);
        },
        .string_count => |operand| expressionTypes(operand, map),
        .sequence_literal => |*literal| {
            if (literal.inferred_type) |type_value| literal.inferred_type = concreteType(type_value, map);
            for (literal.values) |value| expressionTypes(value, map);
        },
        .tuple_literal => |*literal| {
            literal.placeholder_type = concreteType(literal.placeholder_type, map);
            for (literal.elements) |element| expressionTypes(element.value, map);
        },
        .index_access => |access| {
            expressionTypes(access.base, map);
            expressionTypes(access.index, map);
        },
        .slice_access => |access| {
            expressionTypes(access.base, map);
            expressionTypes(access.start, map);
            expressionTypes(access.end, map);
        },
        .interpolated_string => |interpolated| for (interpolated.parts) |part| switch (part) {
            .text => {},
            .expression => |nested| expressionTypes(nested, map),
        },
        .match_expression => |match_value| {
            expressionTypes(match_value.subject, map);
            for (match_value.branches) |branch| {
                if (branch.value) |value| expressionTypes(value, map);
                if (branch.statements) |statements| statementTypes(statements, map);
            }
        },
        else => {},
    }
}
