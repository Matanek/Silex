const std = @import("std");
const Ast = @import("../Ast.zig");
const Iterations = @import("Iterations.zig");
const expressionName = @import("Names.zig").expression;

pub fn activate(self: anytype, module: usize) !void {
    const program = self.units[module].program.?;
    for (program.structures) |structure| {
        if (structure.is_test and (!self.include_tests or module != self.entry_module)) continue;
        for (structure.type_parameters) |parameter| if (parameter.constraint) |constraint| try self.activateType(module, constraint);
        if (structure.base) |base| try self.activateType(module, base);
        for (structure.conformances) |conformance| try self.activateType(module, conformance);
        for (structure.fields) |field| try self.activateType(module, field.type);
        for (structure.static_fields) |field| try self.activateType(module, field.type);
        for (structure.constructors) |constructor| {
            for (constructor.parameters) |parameter| try self.activateType(module, parameter.type);
            for (constructor.super_arguments) |argument| try self.activateExpression(module, argument);
            for (constructor.statements) |statement| try self.activateStatement(module, statement);
        }
        for (structure.methods) |method| {
            for (method.type_parameters) |parameter| if (parameter.constraint) |constraint| try self.activateType(module, constraint);
            for (method.parameters) |parameter| try self.activateType(module, parameter.type);
            try self.activateType(module, method.return_type);
            for (method.statements) |statement| try self.activateStatement(module, statement);
        }
    }
    for (program.extensions) |extension| {
        try self.activateType(module, extension.target);
        for (extension.conformances) |conformance| try self.activateType(module, conformance);
        for (extension.methods) |method| {
            for (method.type_parameters) |parameter| if (parameter.constraint) |constraint| try self.activateType(module, constraint);
            for (method.parameters) |parameter| try self.activateType(module, parameter.type);
            try self.activateType(module, method.return_type);
            for (method.statements) |statement| try self.activateStatement(module, statement);
        }
    }
    for (program.enums) |enumeration| {
        for (enumeration.type_parameters) |parameter| if (parameter.constraint) |constraint| try self.activateType(module, constraint);
        for (enumeration.variants) |variant| {
            for (variant.associated_types) |associated_type| try self.activateType(module, associated_type);
        }
    }
    for (program.enums) |enumeration| {
        if (!enumeration.is_public) continue;
        for (enumeration.type_parameters) |parameter| if (parameter.constraint) |constraint| {
            try self.requirePublicType(module, constraint, parameter.position, "public enum", enumeration.name);
        };
        for (enumeration.variants) |variant| for (variant.associated_types) |associated_type| {
            try self.requirePublicType(module, associated_type, variant.position, "public enum", enumeration.name);
        };
    }
    for (program.functions) |function| {
        if (function.is_test and (!self.include_tests or module != self.entry_module)) continue;
        if (module != self.entry_module and std.mem.eql(u8, function.name, "main")) continue;
        for (function.type_parameters) |parameter| if (parameter.constraint) |constraint| try self.activateType(module, constraint);
        for (function.parameters) |parameter| try self.activateType(module, parameter.type);
        try self.activateType(module, function.return_type);
        for (function.statements) |statement| try self.activateStatement(module, statement);
    }
}

pub fn activateType(self: anytype, module: usize, type_value: Ast.Type) !void {
    if (type_value.optionalChild()) |child| return self.activateType(module, child);
    const index = type_value.structureIndex() orelse return;
    const program = self.units[module].program.?;
    if (index >= program.type_names.len) return;
    const target = try self.nominalCandidate(module, program.type_names[index]) orelse return;
    if (target.module != module) try self.loadModule(target.module, module);
}

pub fn activateStatement(self: anytype, module: usize, statement: Ast.Statement) !void {
    switch (statement) {
        .variable_declaration => |declaration| if (declaration.initializer) |value|
            try self.activateExpression(module, value),
        .assignment_statement => |assignment| {
            if (assignment.value) |value| try self.activateExpression(module, value);
            for (assignment.target.indices) |target_index| try self.activateExpression(module, target_index.value);
        },
        .return_statement => |value| if (value.value) |expression|
            try self.activateExpression(module, expression),
        .expression_statement => |expression| try self.activateExpression(module, expression),
        .print_statement => |print_statement| for (print_statement.values) |value| try self.activateExpression(module, value),
        .panic_statement => |effect| try self.activateExpression(module, effect.value),
        .assert_statement => |assertion| {
            try self.activateExpression(module, assertion.condition);
            try self.activateExpression(module, assertion.message);
        },
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                try self.activateExpression(module, branch.condition.source());
                for (branch.statements) |nested| try self.activateStatement(module, nested);
            }
            if (conditional.else_statements) |statements| {
                for (statements) |nested| try self.activateStatement(module, nested);
            }
        },
        .while_statement => |loop| {
            try self.activateExpression(module, loop.condition.source());
            for (loop.statements) |nested| try self.activateStatement(module, nested);
        },
        .mutex_statement => |mutex| for (mutex.statements) |nested| try self.activateStatement(module, nested),
        .for_statement => |loop| try Iterations.activate(self, module, loop),
        .break_statement, .continue_statement => {},
    }
}

pub fn activateExpression(self: anytype, module: usize, expression: *Ast.Expression) !void {
    switch (expression.value) {
        .call => |call| {
            const qualified_name = if (call.receiver) |receiver|
                if (try expressionName(self.allocator, receiver)) |prefix|
                    try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, call.name })
                else
                    null
            else
                call.name;
            if (qualified_name) |name| {
                if (call.receiver) |receiver| if (try expressionName(self.allocator, receiver)) |prefix| {
                    for (self.units[module].bindings) |binding| {
                        if (std.mem.eql(u8, binding.alias, prefix)) {
                            if (binding.module) |target_module| try self.loadModule(target_module, module);
                        }
                    }
                };
                if (try self.targetForCall(module, name)) |target| {
                    try self.loadModule(target.module, module);
                } else if (call.receiver) |receiver| try self.activateExpression(module, receiver);
            } else if (call.receiver) |receiver| try self.activateExpression(module, receiver);
            for (call.arguments) |argument| try self.activateExpression(module, argument);
            for (call.named_arguments) |argument| try self.activateExpression(module, argument.value);
        },
        .cascade => |cascade| {
            try self.activateExpression(module, cascade.receiver);
            for (cascade.operations) |operation| switch (operation) {
                .method_call => |method| {
                    for (method.arguments) |argument| try self.activateExpression(module, argument);
                    for (method.named_arguments) |argument| try self.activateExpression(module, argument.value);
                },
                .field_assignment => |field| try self.activateExpression(module, field.value),
            };
        },
        .field_access => |access| {
            if (try expressionName(self.allocator, expression)) |name| {
                if (try self.targetForCall(module, name)) |target| {
                    try self.loadModule(target.module, module);
                } else try self.activateExpression(module, access.base);
            } else try self.activateExpression(module, access.base);
        },
        .unary => |unary| {
            try self.activateExpression(module, unary.operand);
            if (unary.try_alternative) |alternative| {
                if (alternative.statements) |statements| for (statements) |statement| try self.activateStatement(module, statement);
                if (alternative.message) |message| try self.activateExpression(module, message);
            }
        },
        .binary => |binary| {
            try self.activateExpression(module, binary.left);
            try self.activateExpression(module, binary.right);
        },
        .conversion => |conversion| try self.activateExpression(module, conversion.operand),
        .string_count => |operand| try self.activateExpression(module, operand),
        .sequence_literal => |literal| for (literal.values) |value| try self.activateExpression(module, value),
        .index_access => |access| {
            try self.activateExpression(module, access.base);
            try self.activateExpression(module, access.index);
        },
        .slice_access => |access| {
            try self.activateExpression(module, access.base);
            try self.activateExpression(module, access.start);
            try self.activateExpression(module, access.end);
        },
        .interpolated_string => |interpolated| for (interpolated.parts) |part| switch (part) {
            .text => {},
            .expression => |value| try self.activateExpression(module, value),
        },
        .match_expression => |match_value| {
            try self.activateExpression(module, match_value.subject);
            for (match_value.branches) |branch| {
                if (branch.value) |value| try self.activateExpression(module, value);
                if (branch.statements) |statements| for (statements) |statement| try self.activateStatement(module, statement);
            }
        },
        else => {},
    }
}
