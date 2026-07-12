const std = @import("std");
const Ast = @import("Ast.zig");
const LexerModule = @import("Lexer.zig");
const Source = @import("Source.zig");

const Allocator = std.mem.Allocator;
const Token = LexerModule.Token;
const TokenTag = LexerModule.TokenTag;
const ParseError = Source.Error || Allocator.Error;

pub const Parser = struct {
    allocator: Allocator,
    lexer: LexerModule.Lexer,
    current: Token = undefined,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: Allocator, source: []const u8) Parser {
        return .{ .allocator = allocator, .lexer = .init(source) };
    }

    pub fn parse(self: *Parser) !Ast.Program {
        try self.advance();

        try self.expect(.keyword_void, "expected 'void'");
        try self.expectIdentifier("main", "expected 'main'");
        try self.expect(.left_parenthesis, "expected '('");
        try self.expect(.right_parenthesis, "expected ')'");
        const statements = try self.parseBlock();
        try self.expect(.end, "expected end of file");
        return .{ .statements = statements };
    }

    fn parseBlock(self: *Parser) ParseError![]const Ast.Statement {
        try self.expect(.left_brace, "expected '{'");
        var statements: std.ArrayList(Ast.Statement) = .empty;
        while (self.current.tag != .right_brace and self.current.tag != .end) {
            try statements.append(self.allocator, try self.parseStatement());
        }
        try self.expect(.right_brace, "expected '}'");
        return statements.toOwnedSlice(self.allocator);
    }

    fn parseStatement(self: *Parser) ParseError!Ast.Statement {
        return switch (self.current.tag) {
            .keyword_print => self.parsePrint(),
            .keyword_let => self.parseVariableDeclaration(.immutable),
            .keyword_var => self.parseVariableDeclaration(.mutable),
            .keyword_if => self.parseIf(),
            .identifier => self.parseAssignment(),
            else => self.fail("expected statement"),
        };
    }

    fn parsePrint(self: *Parser) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        try self.expect(.left_parenthesis, "expected '('");
        const argument = try self.parseExpression();
        try self.expect(.right_parenthesis, "expected ')'");
        try self.expect(.semicolon, "expected ';'");
        return .{ .print = .{ .position = position, .argument = argument } };
    }

    fn parseVariableDeclaration(self: *Parser, mutability: Ast.Mutability) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();

        if (self.current.tag != .identifier) return self.fail("expected variable name");
        const name = self.current.lexeme;
        const name_position = self.current.position;
        try self.advance();

        var annotation: ?Ast.TypeName = null;
        if (self.current.tag == .colon) {
            try self.advance();
            annotation = try self.parseTypeName();
        }

        try self.expect(.equal, "expected '='");
        const initializer = try self.parseExpression();
        try self.expect(.semicolon, "expected ';'");
        return .{ .variable_declaration = .{
            .position = position,
            .name = name,
            .name_position = name_position,
            .mutability = mutability,
            .annotation = annotation,
            .initializer = initializer,
        } };
    }

    fn parseTypeName(self: *Parser) ParseError!Ast.TypeName {
        const type_name: Ast.TypeName = switch (self.current.tag) {
            .keyword_int => .int,
            .keyword_bool => .bool,
            .keyword_string => .string,
            else => return self.fail("expected type name"),
        };
        try self.advance();
        return type_name;
    }

    fn parseAssignment(self: *Parser) ParseError!Ast.Statement {
        const name = self.current.lexeme;
        const position = self.current.position;
        try self.advance();
        try self.expect(.equal, "expected '='");
        const value = try self.parseExpression();
        try self.expect(.semicolon, "expected ';'");
        return .{ .assignment = .{ .position = position, .name = name, .value = value } };
    }

    fn parseIf(self: *Parser) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        try self.expect(.left_parenthesis, "expected '('");
        const condition = try self.parseExpression();
        try self.expect(.right_parenthesis, "expected ')'");
        const body = try self.parseBlock();
        return .{ .if_statement = .{ .position = position, .condition = condition, .body = body } };
    }

    fn parseExpression(self: *Parser) ParseError!*Ast.Expression {
        return self.parseAdditive();
    }

    fn parseAdditive(self: *Parser) ParseError!*Ast.Expression {
        var expression = try self.parseMultiplicative();
        while (self.current.tag == .plus or self.current.tag == .minus) {
            const operator_token = self.current;
            try self.advance();
            const right = try self.parseMultiplicative();
            expression = try self.binaryExpression(expression, right, operator_token);
        }
        return expression;
    }

    fn parseMultiplicative(self: *Parser) ParseError!*Ast.Expression {
        var expression = try self.parsePrimary();
        while (self.current.tag == .star or self.current.tag == .slash) {
            const operator_token = self.current;
            try self.advance();
            const right = try self.parsePrimary();
            expression = try self.binaryExpression(expression, right, operator_token);
        }
        return expression;
    }

    fn parsePrimary(self: *Parser) ParseError!*Ast.Expression {
        const token = self.current;
        switch (token.tag) {
            .integer => {
                try self.advance();
                return self.newExpression(.{ .position = token.position, .value = .{ .integer = token.lexeme } });
            },
            .keyword_true, .keyword_false => {
                try self.advance();
                return self.newExpression(.{
                    .position = token.position,
                    .value = .{ .boolean = token.tag == .keyword_true },
                });
            },
            .string => {
                try self.advance();
                return self.newExpression(.{ .position = token.position, .value = .{ .string = token.lexeme } });
            },
            .identifier => {
                try self.advance();
                return self.newExpression(.{ .position = token.position, .value = .{ .identifier = token.lexeme } });
            },
            .left_parenthesis => {
                try self.advance();
                const expression = try self.parseExpression();
                try self.expect(.right_parenthesis, "expected ')'");
                return expression;
            },
            else => return self.fail("expected expression"),
        }
    }

    fn binaryExpression(
        self: *Parser,
        left: *Ast.Expression,
        right: *Ast.Expression,
        operator_token: Token,
    ) ParseError!*Ast.Expression {
        const operator: Ast.BinaryOperator = switch (operator_token.tag) {
            .plus => .add,
            .minus => .subtract,
            .star => .multiply,
            .slash => .divide,
            else => unreachable,
        };
        return self.newExpression(.{
            .position = left.position,
            .value = .{ .binary = .{
                .operator = operator,
                .operator_position = operator_token.position,
                .left = left,
                .right = right,
            } },
        });
    }

    fn newExpression(self: *Parser, value: Ast.Expression) !*Ast.Expression {
        const result = try self.allocator.create(Ast.Expression);
        result.* = value;
        return result;
    }

    fn expect(self: *Parser, tag: TokenTag, message: []const u8) !void {
        if (self.current.tag != tag) return self.fail(message);
        try self.advance();
    }

    fn expectIdentifier(self: *Parser, expected: []const u8, message: []const u8) !void {
        if (self.current.tag != .identifier or !std.mem.eql(u8, self.current.lexeme, expected)) {
            return self.fail(message);
        }
        try self.advance();
    }

    fn advance(self: *Parser) !void {
        self.current = self.lexer.next() catch |err| {
            self.diagnostic = self.lexer.diagnostic;
            return err;
        };
    }

    fn fail(self: *Parser, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = self.current.position, .message = message };
        return error.InvalidSource;
    }
};

test "multiplication binds tighter than addition" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), "void main() { print(1 + 2 * 3); }");
    const program = try parser.parse();

    const addition = program.statements[0].print.argument.value.binary;
    try std.testing.expectEqual(Ast.BinaryOperator.add, addition.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.multiply, addition.right.value.binary.operator);
}

test "parse inferred and annotated declarations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(
        arena.allocator(),
        "void main() { let count = 5; var hit: bool = true; if (hit) { print(count); } }",
    );
    const program = try parser.parse();

    try std.testing.expectEqual(Ast.Mutability.immutable, program.statements[0].variable_declaration.mutability);
    try std.testing.expectEqual(Ast.TypeName.bool, program.statements[1].variable_declaration.annotation.?);
    try std.testing.expectEqualStrings(
        "count",
        program.statements[2].if_statement.body[0].print.argument.value.identifier,
    );
}

test "reject missing semicolon" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), "void main() { print(1) }");
    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqualStrings("expected ';'", parser.diagnostic.?.message);
}
