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

    pub fn parse(self: *Parser) ParseError!Ast.Program {
        try self.advance();
        var functions: std.ArrayList(Ast.Function) = .empty;
        while (self.current.tag != .end) {
            if (self.current.tag != .keyword_func) return self.fail("expected function declaration");
            try functions.append(self.allocator, try self.parseFunction());
        }
        return .{ .functions = try functions.toOwnedSlice(self.allocator) };
    }

    fn parseFunction(self: *Parser) ParseError!Ast.Function {
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
        try self.expect(.left_brace, "expected '{' before function body");
        if (self.current.tag != .right_brace) return self.fail("language v0 supports only empty function bodies");
        try self.advance();

        return .{
            .position = position,
            .name_position = name_position,
            .name = name,
            .parameters = try parameters.toOwnedSlice(self.allocator),
            .return_type = return_type,
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
        if (self.current.tag != .identifier) return self.fail("expected type name");
        const result: Ast.Type = if (std.mem.eql(u8, self.current.lexeme, "void"))
            .void
        else if (std.mem.eql(u8, self.current.lexeme, "float") or std.mem.eql(u8, self.current.lexeme, "float32"))
            .float32
        else if (std.mem.eql(u8, self.current.lexeme, "str"))
            .str
        else
            return self.fail("unknown type in language v0");
        try self.advance();
        return result;
    }

    fn expect(self: *Parser, tag: TokenTag, message: []const u8) ParseError!void {
        if (self.current.tag != tag) return self.fail(message);
        try self.advance();
    }

    fn advance(self: *Parser) ParseError!void {
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

test "parse user-defined function signatures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {}
        \\func pow(value:float) float {}
        \\func get_name() str {}
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 3), program.functions.len);
    try std.testing.expectEqualStrings("pow", program.functions[1].name);
    try std.testing.expectEqual(Ast.Type.float32, program.functions[1].parameters[0].type);
    try std.testing.expectEqual(Ast.Type.float32, program.functions[1].return_type);
    try std.testing.expectEqual(Ast.Type.str, program.functions[2].return_type);
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
