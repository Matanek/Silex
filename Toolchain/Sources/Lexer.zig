const std = @import("std");
const Source = @import("Source.zig");

pub const TokenTag = enum {
    keyword_func,
    identifier,
    left_parenthesis,
    right_parenthesis,
    left_brace,
    right_brace,
    colon,
    comma,
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
        self.skipTrivia();
        const token_position = self.position();
        if (self.index == self.source.len) return .{
            .tag = .end,
            .lexeme = self.source[self.index..self.index],
            .position = token_position,
        };

        const start = self.index;
        const byte = self.source[self.index];
        if (isIdentifierStart(byte)) {
            self.advance();
            while (self.index < self.source.len and isIdentifierContinue(self.source[self.index])) self.advance();
            const lexeme = self.source[start..self.index];
            return .{
                .tag = if (std.mem.eql(u8, lexeme, "func")) .keyword_func else .identifier,
                .lexeme = lexeme,
                .position = token_position,
            };
        }

        const tag: TokenTag = switch (byte) {
            '(' => .left_parenthesis,
            ')' => .right_parenthesis,
            '{' => .left_brace,
            '}' => .right_brace,
            ':' => .colon,
            ',' => .comma,
            else => {
                self.diagnostic = .{ .position = token_position, .message = "unexpected character" };
                return error.InvalidSource;
            },
        };
        self.advance();
        return .{ .tag = tag, .lexeme = self.source[start..self.index], .position = token_position };
    }

    fn skipTrivia(self: *Lexer) void {
        while (self.index < self.source.len) {
            const byte = self.source[self.index];
            if (std.ascii.isWhitespace(byte)) {
                self.advance();
                continue;
            }
            if (byte == '/' and self.index + 1 < self.source.len and self.source[self.index + 1] == '/') {
                self.advance();
                self.advance();
                while (self.index < self.source.len and self.source[self.index] != '\n') self.advance();
                continue;
            }
            break;
        }
    }

    fn advance(self: *Lexer) void {
        const byte = self.source[self.index];
        self.index += 1;
        if (byte == '\n') {
            self.line += 1;
            self.column = 1;
        } else {
            self.column += 1;
        }
    }

    fn position(self: Lexer) Source.Position {
        return .{ .offset = self.index, .line = self.line, .column = self.column };
    }
};

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isIdentifierContinue(byte: u8) bool {
    return isIdentifierStart(byte) or std.ascii.isDigit(byte);
}

test "lex empty main" {
    var lexer = Lexer.init("func main() {}");
    const expected = [_]TokenTag{
        .keyword_func,
        .identifier,
        .left_parenthesis,
        .right_parenthesis,
        .left_brace,
        .right_brace,
        .end,
    };
    for (expected) |tag| try std.testing.expectEqual(tag, (try lexer.next()).tag);
}

test "track source positions through comments" {
    var lexer = Lexer.init("// Silex\nfunc main() {}");
    const token = try lexer.next();
    try std.testing.expectEqual(@as(usize, 2), token.position.line);
    try std.testing.expectEqual(@as(usize, 1), token.position.column);
}
