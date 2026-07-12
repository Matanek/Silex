const std = @import("std");
const Ast = @import("Ast.zig");
const Source = @import("Source.zig");

const Allocator = std.mem.Allocator;
const AnalyzeError = Source.Error || Allocator.Error;

pub const Type = enum {
    int,
    bool,
    string,
};

pub const Expression = struct {
    type: Type,
    position: Source.Position,
    value: union(enum) {
        integer: i64,
        boolean: bool,
        string: []const u8,
        variable: []const u8,
        unary: Unary,
        binary: Binary,
    },

    pub const Unary = struct {
        operator: Ast.UnaryOperator,
        operand: *Expression,
    };

    pub const Binary = struct {
        operator: Ast.BinaryOperator,
        left: *Expression,
        right: *Expression,
    };
};

pub const Statement = union(enum) {
    print: *Expression,
    variable_declaration: VariableDeclaration,
    assignment: Assignment,
    if_statement: If,
    while_statement: While,

    pub const VariableDeclaration = struct {
        generated_name: []const u8,
        type: Type,
        mutability: Ast.Mutability,
        initializer: *Expression,
    };

    pub const Assignment = struct {
        generated_name: []const u8,
        value: *Expression,
    };

    pub const If = struct {
        condition: *Expression,
        body: []const Statement,
        else_body: ?[]const Statement,
    };

    pub const While = struct {
        condition: *Expression,
        body: []const Statement,
    };
};

pub const Program = struct {
    statements: []const Statement,
};

const Symbol = struct {
    source_name: []const u8,
    generated_name: []const u8,
    type: Type,
    mutability: Ast.Mutability,
};

const Scope = struct {
    parent: ?*const Scope,
    symbols: std.ArrayList(Symbol) = .empty,
};

pub const Analyzer = struct {
    allocator: Allocator,
    next_symbol_id: usize = 0,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: Allocator) Analyzer {
        return .{ .allocator = allocator };
    }

    pub fn analyze(self: *Analyzer, program: Ast.Program) !Program {
        var root_scope = Scope{ .parent = null };
        return .{ .statements = try self.statements(program.statements, &root_scope) };
    }

    fn statements(
        self: *Analyzer,
        ast_statements: []const Ast.Statement,
        scope: *Scope,
    ) AnalyzeError![]const Statement {
        var result: std.ArrayList(Statement) = .empty;
        for (ast_statements) |ast_statement| {
            try result.append(self.allocator, try self.statement(ast_statement, scope));
        }
        return result.toOwnedSlice(self.allocator);
    }

    fn statement(self: *Analyzer, ast: Ast.Statement, scope: *Scope) AnalyzeError!Statement {
        return switch (ast) {
            .print => |print| .{ .print = try self.expression(print.argument, scope) },
            .variable_declaration => |declaration| self.variableDeclaration(declaration, scope),
            .assignment => |ast_assignment| self.assignment(ast_assignment, scope),
            .if_statement => |if_statement| self.ifStatement(if_statement, scope),
            .while_statement => |while_statement| self.whileStatement(while_statement, scope),
        };
    }

    fn variableDeclaration(
        self: *Analyzer,
        declaration: Ast.Statement.VariableDeclaration,
        scope: *Scope,
    ) AnalyzeError!Statement {
        if (findInCurrentScope(scope, declaration.name) != null) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "variable '{s}' is already declared in this scope",
                .{declaration.name},
            );
            return self.fail(declaration.name_position, message);
        }

        const initializer = try self.expression(declaration.initializer, scope);
        const declared_type = if (declaration.annotation) |annotation| typeFromAnnotation(annotation) else initializer.type;
        if (declared_type != initializer.type) {
            const message = try typeMismatchMessage(self.allocator, declared_type, initializer.type);
            return self.fail(declaration.initializer.position, message);
        }

        const generated_name = try std.fmt.allocPrint(self.allocator, "silexValue{d}", .{self.next_symbol_id});
        self.next_symbol_id += 1;
        try scope.symbols.append(self.allocator, .{
            .source_name = declaration.name,
            .generated_name = generated_name,
            .type = declared_type,
            .mutability = declaration.mutability,
        });

        return .{ .variable_declaration = .{
            .generated_name = generated_name,
            .type = declared_type,
            .mutability = declaration.mutability,
            .initializer = initializer,
        } };
    }

    fn assignment(
        self: *Analyzer,
        ast: Ast.Statement.Assignment,
        scope: *const Scope,
    ) AnalyzeError!Statement {
        const symbol = findSymbol(scope, ast.name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{ast.name});
            return self.fail(ast.position, message);
        };
        if (symbol.mutability == .immutable) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "cannot assign to immutable variable '{s}'",
                .{ast.name},
            );
            return self.fail(ast.position, message);
        }

        const value = try self.expression(ast.value, scope);
        if (symbol.type != value.type) {
            const message = try typeMismatchMessage(self.allocator, symbol.type, value.type);
            return self.fail(ast.value.position, message);
        }
        return .{ .assignment = .{ .generated_name = symbol.generated_name, .value = value } };
    }

    fn ifStatement(
        self: *Analyzer,
        ast: Ast.Statement.If,
        parent_scope: *const Scope,
    ) AnalyzeError!Statement {
        const condition = try self.expression(ast.condition, parent_scope);
        if (condition.type != .bool) {
            const message = try typeMismatchMessage(self.allocator, .bool, condition.type);
            return self.fail(ast.condition.position, message);
        }

        var body_scope = Scope{ .parent = parent_scope };
        const body = try self.statements(ast.body, &body_scope);

        var else_body: ?[]const Statement = null;
        if (ast.else_body) |ast_else_body| {
            var else_scope = Scope{ .parent = parent_scope };
            else_body = try self.statements(ast_else_body, &else_scope);
        }

        return .{ .if_statement = .{
            .condition = condition,
            .body = body,
            .else_body = else_body,
        } };
    }

    fn whileStatement(
        self: *Analyzer,
        ast: Ast.Statement.While,
        parent_scope: *const Scope,
    ) AnalyzeError!Statement {
        const condition = try self.expression(ast.condition, parent_scope);
        if (condition.type != .bool) {
            const message = try typeMismatchMessage(self.allocator, .bool, condition.type);
            return self.fail(ast.condition.position, message);
        }

        var body_scope = Scope{ .parent = parent_scope };
        return .{ .while_statement = .{
            .condition = condition,
            .body = try self.statements(ast.body, &body_scope),
        } };
    }

    fn expression(self: *Analyzer, ast: *const Ast.Expression, scope: *const Scope) AnalyzeError!*Expression {
        return switch (ast.value) {
            .integer => |lexeme| self.integerExpression(ast.position, lexeme),
            .boolean => |value| self.newExpression(.{
                .type = .bool,
                .position = ast.position,
                .value = .{ .boolean = value },
            }),
            .string => |value| self.newExpression(.{
                .type = .string,
                .position = ast.position,
                .value = .{ .string = value },
            }),
            .identifier => |name| self.variableExpression(ast.position, name, scope),
            .unary => |unary| self.unaryExpression(unary, scope),
            .binary => |binary| self.binaryExpression(binary, scope),
        };
    }

    fn integerExpression(self: *Analyzer, position: Source.Position, lexeme: []const u8) AnalyzeError!*Expression {
        const value = std.fmt.parseInt(i64, lexeme, 10) catch {
            return self.fail(position, "integer literal is outside the range of 'int'");
        };
        return self.newExpression(.{
            .type = .int,
            .position = position,
            .value = .{ .integer = value },
        });
    }

    fn variableExpression(
        self: *Analyzer,
        position: Source.Position,
        name: []const u8,
        scope: *const Scope,
    ) AnalyzeError!*Expression {
        const symbol = findSymbol(scope, name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{name});
            return self.fail(position, message);
        };
        return self.newExpression(.{
            .type = symbol.type,
            .position = position,
            .value = .{ .variable = symbol.generated_name },
        });
    }

    fn binaryExpression(
        self: *Analyzer,
        binary: Ast.Expression.Binary,
        scope: *const Scope,
    ) AnalyzeError!*Expression {
        const left = try self.expression(binary.left, scope);
        const right = try self.expression(binary.right, scope);
        const result_type: Type = switch (binary.operator) {
            .add, .subtract, .multiply, .divide => try self.requireBinaryOperands(
                binary.operator_position,
                "arithmetic operator",
                .int,
                left.type,
                right.type,
                .int,
            ),
            .less, .less_equal, .greater, .greater_equal => try self.requireBinaryOperands(
                binary.operator_position,
                "comparison operator",
                .int,
                left.type,
                right.type,
                .bool,
            ),
            .logical_and, .logical_or => try self.requireBinaryOperands(
                binary.operator_position,
                "logical operator",
                .bool,
                left.type,
                right.type,
                .bool,
            ),
            .equal, .not_equal => equality: {
                if (left.type != right.type) {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "equality operator requires operands of the same type, found '{s}' and '{s}'",
                        .{ @tagName(left.type), @tagName(right.type) },
                    );
                    return self.fail(binary.operator_position, message);
                }
                break :equality .bool;
            },
        };
        return self.newExpression(.{
            .type = result_type,
            .position = left.position,
            .value = .{ .binary = .{ .operator = binary.operator, .left = left, .right = right } },
        });
    }

    fn unaryExpression(
        self: *Analyzer,
        unary: Ast.Expression.Unary,
        scope: *const Scope,
    ) AnalyzeError!*Expression {
        const operand = try self.expression(unary.operand, scope);
        if (operand.type != .bool) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "logical operator '!' requires a 'bool' operand, found '{s}'",
                .{@tagName(operand.type)},
            );
            return self.fail(unary.operator_position, message);
        }
        return self.newExpression(.{
            .type = .bool,
            .position = unary.operator_position,
            .value = .{ .unary = .{ .operator = unary.operator, .operand = operand } },
        });
    }

    fn requireBinaryOperands(
        self: *Analyzer,
        position: Source.Position,
        operator_name: []const u8,
        required_type: Type,
        left_type: Type,
        right_type: Type,
        result_type: Type,
    ) AnalyzeError!Type {
        if (left_type == required_type and right_type == required_type) return result_type;
        const message = try std.fmt.allocPrint(
            self.allocator,
            "{s} requires '{s}' operands, found '{s}' and '{s}'",
            .{ operator_name, @tagName(required_type), @tagName(left_type), @tagName(right_type) },
        );
        return self.fail(position, message);
    }

    fn newExpression(self: *Analyzer, value: Expression) !*Expression {
        const result = try self.allocator.create(Expression);
        result.* = value;
        return result;
    }

    fn fail(self: *Analyzer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn findInCurrentScope(scope: *const Scope, name: []const u8) ?*const Symbol {
    for (scope.symbols.items) |*symbol| {
        if (std.mem.eql(u8, symbol.source_name, name)) return symbol;
    }
    return null;
}

fn findSymbol(scope: *const Scope, name: []const u8) ?*const Symbol {
    var current: ?*const Scope = scope;
    while (current) |value| : (current = value.parent) {
        if (findInCurrentScope(value, name)) |symbol| return symbol;
    }
    return null;
}

fn typeFromAnnotation(annotation: Ast.TypeName) Type {
    return switch (annotation) {
        .int => .int,
        .bool => .bool,
        .string => .string,
    };
}

fn typeMismatchMessage(allocator: Allocator, expected: Type, found: Type) ![]const u8 {
    return std.fmt.allocPrint(
        allocator,
        "expected '{s}', found '{s}'",
        .{ @tagName(expected), @tagName(found) },
    );
}

test "infer variables and resolve nested scope" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { let count = 5; if (true) { print(count); } }");
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());

    try std.testing.expectEqual(Type.int, program.statements[0].variable_declaration.type);
    try std.testing.expectEqual(
        Type.int,
        program.statements[1].if_statement.body[0].print.type,
    );
}

test "reject assignment to immutable variable" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { let count = 5; count = 6; }");
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        "cannot assign to immutable variable 'count'",
        analyzer.diagnostic.?.message,
    );
}

test "reject duplicate variable in same scope" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { let count = 5; let count = 6; }");
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        "variable 'count' is already declared in this scope",
        analyzer.diagnostic.?.message,
    );
}

test "block variables do not escape their scope" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(
        allocator,
        "void main() { if (true) { let inside = 5; } print(inside); }",
    );
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings("unknown variable 'inside'", analyzer.diagnostic.?.message);
}

test "nested scope may shadow an outer variable" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(
        allocator,
        "void main() { let value = 1; if (true) { let value = 2; print(value); } print(value); }",
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());

    const outer_name = program.statements[0].variable_declaration.generated_name;
    const inner_name = program.statements[1].if_statement.body[0].variable_declaration.generated_name;
    try std.testing.expect(!std.mem.eql(u8, outer_name, inner_name));
    try std.testing.expectEqualStrings(
        inner_name,
        program.statements[1].if_statement.body[1].print.value.variable,
    );
    try std.testing.expectEqualStrings(outer_name, program.statements[2].print.value.variable);
}

test "reject incompatible type annotation" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { let count: bool = 5; }");
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings("expected 'bool', found 'int'", analyzer.diagnostic.?.message);
}

test "reject arithmetic between string and int" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { print(\"Hello\" + 2); }");
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqual(@as(usize, 37), analyzer.diagnostic.?.position.column);
}

test "comparison and logical expressions produce bool" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(
        allocator,
        "void main() { let result = !(1 >= 2) && \"Silex\" == \"Silex\"; }",
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(Type.bool, program.statements[0].variable_declaration.type);
}

test "reject logical operator with int operand" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { let result = 1 && true; }");
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        "logical operator requires 'bool' operands, found 'int' and 'bool'",
        analyzer.diagnostic.?.message,
    );
}

test "reject comparison with string operand" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { let result = \"one\" < 2; }");
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        "comparison operator requires 'int' operands, found 'string' and 'int'",
        analyzer.diagnostic.?.message,
    );
}

test "reject equality between different types" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { let result = 1 == true; }");
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        "equality operator requires operands of the same type, found 'int' and 'bool'",
        analyzer.diagnostic.?.message,
    );
}

test "if and else use separate scopes" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(
        allocator,
        "void main() { if (true) { let value = 1; } else { let value = 2; } }",
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 1), program.statements[0].if_statement.else_body.?.len);
}

test "while requires bool condition and creates a scope" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(
        allocator,
        "void main() { var count = 2; while (count > 0) { let inside = count; count = count - 1; } }",
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(Type.bool, program.statements[1].while_statement.condition.type);
    try std.testing.expectEqual(@as(usize, 2), program.statements[1].while_statement.body.len);
}

test "reject while condition that is not bool" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator, "void main() { while (1) { print(1); } }");
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings("expected 'bool', found 'int'", analyzer.diagnostic.?.message);
}
