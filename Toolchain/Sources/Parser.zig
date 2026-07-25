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
    previous: Token = undefined,
    started: bool = false,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: Allocator, source: []const u8) Parser {
        return .{ .allocator = allocator, .lexer = .init(source) };
    }

    pub fn initFile(allocator: Allocator, source: []const u8, file: usize) Parser {
        return .{ .allocator = allocator, .lexer = .initFile(source, file) };
    }

    pub fn parse(self: *Parser) ParseError!Ast.Program {
        try self.advance();
        var uses: std.ArrayList(Ast.Use) = .empty;
        var functions: std.ArrayList(Ast.Function) = .empty;
        while (self.current.tag != .end) {
            switch (self.current.tag) {
                .keyword_use => try uses.append(self.allocator, try self.parseUse(false)),
                .keyword_func => try functions.append(self.allocator, try self.parseFunction(false)),
                .keyword_public => {
                    try self.advance();
                    if (self.current.tag != .keyword_func) {
                        return self.fail("only function declarations can be public in language v0");
                    }
                    try functions.append(self.allocator, try self.parseFunction(true));
                },
                else => return self.fail("expected use or function declaration"),
            }
        }
        return .{
            .uses = try uses.toOwnedSlice(self.allocator),
            .functions = try functions.toOwnedSlice(self.allocator),
        };
    }

    fn parseUse(self: *Parser, is_public: bool) ParseError!Ast.Use {
        const position = self.current.position;
        try self.expect(.keyword_use, "expected 'use'");
        if (self.current.tag != .identifier) return self.fail("expected module path after 'use'");
        var path = self.current.lexeme;
        try self.advance();
        while (self.current.tag == .dot) {
            try self.advance();
            if (self.current.tag != .identifier) return self.fail("expected name after '.' in use path");
            path = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ path, self.current.lexeme });
            try self.advance();
        }

        var alias: ?[]const u8 = null;
        var alias_position: ?Source.Position = null;
        if (self.current.tag == .keyword_as) {
            try self.advance();
            if (self.current.tag != .identifier) return self.fail("expected alias after 'as'");
            alias = self.current.lexeme;
            alias_position = self.current.position;
            try self.advance();
        }
        try self.expectStatementTerminator();
        return .{
            .position = position,
            .path = path,
            .alias = alias,
            .alias_position = alias_position,
            .is_public = is_public,
        };
    }

    fn parseFunction(self: *Parser, is_public: bool) ParseError!Ast.Function {
        const position = self.current.position;
        try self.expect(.keyword_func, "expected 'func'");
        if (self.current.tag != .identifier) return self.fail("expected function name");
        const name = self.current.lexeme;
        const name_position = self.current.position;
        try self.advance();
        try self.expect(.left_parenthesis, "expected '(' after function name");

        var parameters: std.ArrayList(Ast.Parameter) = .empty;
        if (self.current.tag != .right_parenthesis) {
            while (true) {
                try parameters.append(self.allocator, try self.parseParameter());
                if (self.current.tag != .comma) break;
                try self.advance();
                if (self.current.tag == .right_parenthesis) return self.fail("expected parameter after ','");
            }
        }
        try self.expect(.right_parenthesis, "expected ')' after parameters");

        const return_type: Ast.Type = if (self.current.tag == .left_brace) .void else try self.parseType();
        return .{
            .is_public = is_public,
            .position = position,
            .name_position = name_position,
            .name = name,
            .parameters = try parameters.toOwnedSlice(self.allocator),
            .return_type = return_type,
            .statements = try self.parseBlock(),
        };
    }

    fn parseParameter(self: *Parser) ParseError!Ast.Parameter {
        if (self.current.tag != .identifier) return self.fail("expected parameter name");
        const position = self.current.position;
        const name = self.current.lexeme;
        try self.advance();
        try self.expect(.colon, "expected ':' after parameter name");
        return .{ .position = position, .name = name, .type = try self.parseType() };
    }

    fn parseType(self: *Parser) ParseError!Ast.Type {
        const result: Ast.Type = switch (self.current.tag) {
            .keyword_void => .void,
            .keyword_int => .int,
            .keyword_bool => .bool,
            .keyword_float, .keyword_float32 => .float32,
            .keyword_str => .str,
            .identifier => return self.fail("unknown type in language v0"),
            else => return self.fail("expected type name"),
        };
        try self.advance();
        return result;
    }

    fn parseBlock(self: *Parser) ParseError![]const Ast.Statement {
        try self.expect(.left_brace, "expected '{' before function body");
        var statements: std.ArrayList(Ast.Statement) = .empty;
        while (self.current.tag != .right_brace and self.current.tag != .end) {
            try statements.append(self.allocator, try self.parseStatement());
        }
        try self.expect(.right_brace, "expected '}' after function body");
        return statements.toOwnedSlice(self.allocator);
    }

    fn parseStatement(self: *Parser) ParseError!Ast.Statement {
        return switch (self.current.tag) {
            .keyword_let => self.parseVariableDeclaration(),
            .keyword_return => self.parseReturn(),
            .identifier => self.parseCallStatement(),
            else => self.fail("expected statement"),
        };
    }

    fn parseVariableDeclaration(self: *Parser) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        if (self.current.tag != .identifier) return self.fail("expected variable name");
        const name = self.current.lexeme;
        const name_position = self.current.position;
        try self.advance();

        var annotation: ?Ast.Type = null;
        if (self.current.tag == .colon) {
            try self.advance();
            annotation = try self.parseType();
        }

        var initializer: ?*Ast.Expression = null;
        if (self.current.tag == .equal) {
            try self.advance();
            initializer = try self.parseExpression(false);
        } else if (annotation == null) {
            return self.failAt(name_position, "variable declaration requires a type or initializer");
        }
        try self.expectStatementTerminator();
        return .{ .variable_declaration = .{
            .position = position,
            .name_position = name_position,
            .name = name,
            .annotation = annotation,
            .initializer = initializer,
        } };
    }

    fn parseReturn(self: *Parser) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        var value: ?*Ast.Expression = null;
        if (self.current.tag != .semicolon and self.current.tag != .right_brace and
            self.current.tag != .end and self.current.position.line == position.line)
        {
            value = try self.parseExpression(false);
        }
        try self.expectStatementTerminator();
        return .{ .return_statement = .{ .position = position, .value = value } };
    }

    fn parseCallStatement(self: *Parser) ParseError!Ast.Statement {
        const expression = try self.parseExpression(false);
        switch (expression.value) {
            .call => {},
            else => return self.failAt(expression.position, "only a function call can be used as an expression statement"),
        }
        try self.expectStatementTerminator();
        return .{ .expression_statement = expression };
    }

    fn parseExpression(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        return self.parseAdditive(allow_line_breaks);
    }

    fn parseAdditive(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseMultiplicative(allow_line_breaks);
        while ((self.current.tag == .plus or self.current.tag == .minus) and
            self.canContinueExpression(allow_line_breaks))
        {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseMultiplicative(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseMultiplicative(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseUnary(allow_line_breaks);
        while ((self.current.tag == .star or self.current.tag == .slash or self.current.tag == .percent) and
            self.canContinueExpression(allow_line_breaks))
        {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseUnary(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseUnary(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        if (self.current.tag != .minus) return self.parsePrimary();
        const operator = self.current;
        try self.advance();
        return self.newExpression(.{
            .position = operator.position,
            .value = .{ .unary = .{
                .operator = .negate,
                .operator_position = operator.position,
                .operand = try self.parseUnary(allow_line_breaks),
            } },
        });
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
            .identifier => {
                try self.advance();
                var name = token.lexeme;
                while (self.current.tag == .dot) {
                    try self.advance();
                    if (self.current.tag != .identifier) return self.fail("expected name after '.'");
                    name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ name, self.current.lexeme });
                    try self.advance();
                }
                if (self.current.tag != .left_parenthesis) {
                    return self.newExpression(.{ .position = token.position, .value = .{ .identifier = name } });
                }
                return self.parseCallAfterName(.{
                    .tag = .identifier,
                    .lexeme = name,
                    .position = token.position,
                    .start = token.start,
                    .end = token.end,
                });
            },
            .left_parenthesis => {
                try self.advance();
                const expression = try self.parseExpression(true);
                try self.expect(.right_parenthesis, "expected ')' after expression");
                return expression;
            },
            else => return self.fail("expected expression"),
        }
    }

    fn parseCallAfterName(self: *Parser, name: Token) ParseError!*Ast.Expression {
        try self.expect(.left_parenthesis, "expected '(' after function name");
        var arguments: std.ArrayList(*Ast.Expression) = .empty;
        if (self.current.tag != .right_parenthesis) {
            while (true) {
                try arguments.append(self.allocator, try self.parseExpression(true));
                if (self.current.tag == .right_parenthesis) break;
                if (self.current.tag != .comma) return self.fail("expected ',' or ')' after argument");
                try self.advance();
                if (self.current.tag == .right_parenthesis) return self.fail("expected argument after ','");
            }
        }
        try self.expect(.right_parenthesis, "expected ')' after arguments");
        return self.newExpression(.{
            .position = name.position,
            .value = .{ .call = .{
                .name = name.lexeme,
                .name_position = name.position,
                .arguments = try arguments.toOwnedSlice(self.allocator),
            } },
        });
    }

    fn newBinary(self: *Parser, left: *Ast.Expression, right: *Ast.Expression, token: Token) Allocator.Error!*Ast.Expression {
        const operator: Ast.BinaryOperator = switch (token.tag) {
            .plus => .add,
            .minus => .subtract,
            .star => .multiply,
            .slash => .divide,
            .percent => .remainder,
            else => unreachable,
        };
        return self.newExpression(.{
            .position = left.position,
            .value = .{ .binary = .{
                .left = left,
                .operator = operator,
                .operator_position = token.position,
                .right = right,
            } },
        });
    }

    fn newExpression(self: *Parser, expression: Ast.Expression) Allocator.Error!*Ast.Expression {
        const result = try self.allocator.create(Ast.Expression);
        result.* = expression;
        return result;
    }

    fn expectStatementTerminator(self: *Parser) ParseError!void {
        if (self.current.tag == .semicolon and self.current.position.line == self.previous.position.line) {
            try self.advance();
            return;
        }
        if (self.current.tag == .right_brace or self.current.tag == .end) return;
        if (self.current.position.line > self.previous.position.line) return;
        return self.fail("expected ';' or line break");
    }

    fn canContinueExpression(self: *const Parser, allow_line_breaks: bool) bool {
        return allow_line_breaks or self.current.position.line == self.previous.position.line;
    }

    fn expect(self: *Parser, tag: TokenTag, message: []const u8) ParseError!void {
        if (self.current.tag != tag) return self.fail(message);
        try self.advance();
    }

    fn advance(self: *Parser) ParseError!void {
        const next = self.lexer.next() catch |err| {
            self.diagnostic = self.lexer.diagnostic;
            return err;
        };
        if (self.started) {
            self.previous = self.current;
        } else {
            self.started = true;
        }
        self.current = next;
    }

    fn fail(self: *Parser, message: []const u8) Source.Error {
        return self.failAt(self.current.position, message);
    }

    fn failAt(self: *Parser, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn expectParseError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), source);
    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqualStrings(message, parser.diagnostic.?.message);
}

test "parse user-defined function signatures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {}
        \\func add(left:int, right:int) int {}
        \\func enabled() bool {}
        \\func pow(value:float) float32 {}
        \\func get_name() str {}
        \\func explicit_void() void {}
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 6), program.functions.len);
    try std.testing.expectEqual(Ast.Type.int, program.functions[1].parameters[0].type);
    try std.testing.expectEqual(Ast.Type.int, program.functions[1].return_type);
    try std.testing.expectEqual(Ast.Type.bool, program.functions[2].return_type);
    try std.testing.expectEqual(Ast.Type.float32, program.functions[3].return_type);
    try std.testing.expectEqual(Ast.Type.str, program.functions[4].return_type);
    try std.testing.expectEqual(Ast.Type.void, program.functions[5].return_type);
}

test "parse let literals and arithmetic precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func calculate() int {
        \\    let inferred = 20
        \\    let explicit:int = -2 + 3 * 4 - 5 / 6 % 7
        \\    let intrinsic:bool
        \\    return explicit
        \\}
        \\func main() {}
    );
    const program = try parser.parse();
    const statements = program.functions[0].statements;
    try std.testing.expectEqual(@as(usize, 4), statements.len);
    try std.testing.expectEqualStrings("20", statements[0].variable_declaration.initializer.?.value.integer);
    try std.testing.expectEqual(Ast.Type.int, statements[1].variable_declaration.annotation.?);
    try std.testing.expectEqual(Ast.Type.bool, statements[2].variable_declaration.annotation.?);

    const outer = statements[1].variable_declaration.initializer.?.value.binary;
    try std.testing.expectEqual(Ast.BinaryOperator.subtract, outer.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.add, outer.left.value.binary.operator);
    try std.testing.expectEqual(Ast.UnaryOperator.negate, outer.left.value.binary.left.value.unary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.multiply, outer.left.value.binary.right.value.binary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.remainder, outer.right.value.binary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.divide, outer.right.value.binary.left.value.binary.operator);
}

test "parse booleans nested calls and call statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func enabled() bool { return true }
        \\func main() {
        \\    choose(enabled(), false)
        \\}
    );
    const program = try parser.parse();
    try std.testing.expect(program.functions[0].statements[0].return_statement.value.?.value.boolean);
    const call = program.functions[1].statements[0].expression_statement.value.call;
    try std.testing.expectEqualStrings("choose", call.name);
    try std.testing.expectEqual(@as(usize, 2), call.arguments.len);
    try std.testing.expectEqualStrings("enabled", call.arguments[0].value.call.name);
    try std.testing.expect(!call.arguments[1].value.boolean);
}

test "parse module uses aliases and qualified calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\use Math.Operations
        \\use Math.Integer.Checked as Checked
        \\func main() { Operations.add(Checked.value(), 2) }
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 2), program.uses.len);
    try std.testing.expectEqualStrings("Math.Operations", program.uses[0].path);
    try std.testing.expect(program.uses[0].alias == null);
    try std.testing.expectEqualStrings("Checked", program.uses[1].alias.?);
    const call = program.functions[0].statements[0].expression_statement.value.call;
    try std.testing.expectEqualStrings("Operations.add", call.name);
    try std.testing.expectEqualStrings("Checked.value", call.arguments[0].value.call.name);
}

test "parse public functions and keep functions private by default" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\public func exposed(value:int) int { return value }
        \\func hidden() {}
    );
    const program = try parser.parse();
    try std.testing.expect(program.functions[0].is_public);
    try std.testing.expect(!program.functions[1].is_public);
}

test "continue expressions after operators and inside parentheses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func value() int {
        \\    return (1
        \\        + 2) *
        \\        3
        \\}
        \\func main() {}
    );
    const program = try parser.parse();
    const expression = program.functions[0].statements[0].return_statement.value.?;
    try std.testing.expectEqual(Ast.BinaryOperator.multiply, expression.value.binary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.add, expression.value.binary.left.value.binary.operator);
}

test "semicolon separates statements on one line" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), "func main() { let first = 1; let second = 2 }");
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 2), program.functions[0].statements.len);
}

test "report malformed parameter at its source position" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), "func main(value float) {}");
    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqual(@as(usize, 1), parser.diagnostic.?.position.line);
    try std.testing.expectEqual(@as(usize, 17), parser.diagnostic.?.position.column);
    try std.testing.expectEqualStrings("expected ':' after parameter name", parser.diagnostic.?.message);
}

test "report malformed fundamental statements and expressions" {
    try expectParseError("func main() { let value\n}", "variable declaration requires a type or initializer");
    try expectParseError("func main() { return 1 +\n}", "expected expression");
    try expectParseError("func main() { call(1 2) }", "expected ',' or ')' after argument");
    try expectParseError("func main() { return 1 return }", "expected ';' or line break");
    try expectParseError("func main() { let first = 1 let second = 2 }", "expected ';' or line break");
}
