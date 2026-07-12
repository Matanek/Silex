const std = @import("std");
const Source = @import("Source.zig");

pub const TokenTag = enum {
    keyword_void,
    keyword_let,
    keyword_var,
    keyword_if,
    keyword_true,
    keyword_false,
    keyword_int,
    keyword_bool,
    keyword_string,
    keyword_print,
    identifier,
    integer,
    string,
    plus,
    minus,
    star,
    slash,
    equal,
    colon,
    left_parenthesis,
    right_parenthesis,
    left_brace,
    right_brace,
    semicolon,
    end,
};

pub const Token = struct {
    tag: TokenTag,
    lexeme: []const u8,
    position: Source.Position,
};

pub const Lexer = struct {
    source: []const u8,
    index: usize = 0,
    line: usize = 1,
    column: usize = 1,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(source: []const u8) Lexer {
        return .{ .source = source };
    }

    pub fn next(self: *Lexer) Source.Error!Token {
        self.skipIgnored();

        if (self.index == self.source.len) {
            return self.token(.end, self.index, self.currentPosition());
        }

        const start = self.index;
        const position = self.currentPosition();
        const character = self.source[self.index];

        if (isIdentifierStart(character)) {
            self.advance();
            while (self.index < self.source.len and isIdentifierContinue(self.source[self.index])) {
                self.advance();
            }

            const lexeme = self.source[start..self.index];
            return .{ .tag = keywordTag(lexeme) orelse .identifier, .lexeme = lexeme, .position = position };
        }

        if (std.ascii.isDigit(character)) {
            self.advance();
            while (self.index < self.source.len and std.ascii.isDigit(self.source[self.index])) {
                self.advance();
            }
            return self.token(.integer, start, position);
        }

        if (character == '"') return self.stringToken(position);

        self.advance();
        return switch (character) {
            '+' => self.token(.plus, start, position),
            '-' => self.token(.minus, start, position),
            '*' => self.token(.star, start, position),
            '/' => self.token(.slash, start, position),
            '=' => self.token(.equal, start, position),
            ':' => self.token(.colon, start, position),
            '(' => self.token(.left_parenthesis, start, position),
            ')' => self.token(.right_parenthesis, start, position),
            '{' => self.token(.left_brace, start, position),
            '}' => self.token(.right_brace, start, position),
            ';' => self.token(.semicolon, start, position),
            else => self.fail(position, "invalid character"),
        };
    }

    fn stringToken(self: *Lexer, position: Source.Position) Source.Error!Token {
        self.advance();
        const contents_start = self.index;
        while (self.index < self.source.len) {
            switch (self.source[self.index]) {
                '"' => {
                    const lexeme = self.source[contents_start..self.index];
                    self.advance();
                    return .{ .tag = .string, .lexeme = lexeme, .position = position };
                },
                '\n', '\r' => return self.fail(position, "unterminated string literal"),
                '\\' => {
                    self.advance();
                    if (self.index == self.source.len) {
                        return self.fail(position, "unterminated string literal");
                    }
                    self.advance();
                },
                else => self.advance(),
            }
        }
        return self.fail(position, "unterminated string literal");
    }

    fn skipIgnored(self: *Lexer) void {
        while (self.index < self.source.len) {
            switch (self.source[self.index]) {
                ' ', '\t', '\r' => self.advance(),
                '\n' => self.newline(),
                '/' => {
                    if (self.index + 1 >= self.source.len or self.source[self.index + 1] != '/') return;
                    while (self.index < self.source.len and self.source[self.index] != '\n') self.advance();
                },
                else => return,
            }
        }
    }

    fn advance(self: *Lexer) void {
        self.index += 1;
        self.column += 1;
    }

    fn newline(self: *Lexer) void {
        self.index += 1;
        self.line += 1;
        self.column = 1;
    }

    fn currentPosition(self: *const Lexer) Source.Position {
        return .{ .line = self.line, .column = self.column };
    }

    fn token(self: *const Lexer, tag: TokenTag, start: usize, position: Source.Position) Token {
        return .{ .tag = tag, .lexeme = self.source[start..self.index], .position = position };
    }

    fn fail(self: *Lexer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn keywordTag(lexeme: []const u8) ?TokenTag {
    const keywords = .{
        .{ "void", TokenTag.keyword_void },
        .{ "let", TokenTag.keyword_let },
        .{ "var", TokenTag.keyword_var },
        .{ "if", TokenTag.keyword_if },
        .{ "true", TokenTag.keyword_true },
        .{ "false", TokenTag.keyword_false },
        .{ "int", TokenTag.keyword_int },
        .{ "bool", TokenTag.keyword_bool },
        .{ "string", TokenTag.keyword_string },
        .{ "print", TokenTag.keyword_print },
    };
    inline for (keywords) |keyword| {
        if (std.mem.eql(u8, lexeme, keyword[0])) return keyword[1];
    }
    return null;
}

fn isIdentifierStart(character: u8) bool {
    return std.ascii.isAlphabetic(character) or character == '_';
}

fn isIdentifierContinue(character: u8) bool {
    return isIdentifierStart(character) or std.ascii.isDigit(character);
}

test "recognize declaration keywords" {
    var lexer = Lexer.init("let value: bool = true;");
    try std.testing.expectEqual(TokenTag.keyword_let, (try lexer.next()).tag);
    try std.testing.expectEqual(TokenTag.identifier, (try lexer.next()).tag);
    try std.testing.expectEqual(TokenTag.colon, (try lexer.next()).tag);
    try std.testing.expectEqual(TokenTag.keyword_bool, (try lexer.next()).tag);
    try std.testing.expectEqual(TokenTag.equal, (try lexer.next()).tag);
    try std.testing.expectEqual(TokenTag.keyword_true, (try lexer.next()).tag);
}

test "skip line comments" {
    var lexer = Lexer.init("// comment\n42");
    const token = try lexer.next();
    try std.testing.expectEqual(TokenTag.integer, token.tag);
    try std.testing.expectEqual(@as(usize, 2), token.position.line);
}
