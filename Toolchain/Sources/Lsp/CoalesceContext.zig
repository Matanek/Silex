const std = @import("std");
const Lexer = @import("../Lexer.zig").Lexer;
const Tag = @import("../Lexer.zig").TokenTag;

pub const Context = struct {
    left: []const u8,
    right: []const u8,
    full_right: []const u8,
};

const Candidate = struct { first: usize, last: usize, right: usize };
const Frame = struct {
    tag: Tag,
    expression_start: usize,
    candidate: ?Candidate = null,
};

// Locate an unfinished fallback literal, rather than imposing its type on
// later statements or on the enclosing call. Type resolution stays with the
// completion owner and its current lexical/workspace information.
pub fn at(source: []const u8, end: usize) ?Context {
    if (end > source.len) return null;
    var lexer = Lexer.init(source[0..end]);
    var stack: [128]Frame = undefined;
    var depth: usize = 0;
    var expression_start: usize = 0;
    var pending: ?Candidate = null;
    while (true) {
        const token = lexer.next() catch return null;
        switch (token.tag) {
            .end => break,
            .question_question => {
                pending = .{ .first = expression_start, .last = token.start, .right = token.end };
                expression_start = token.end;
            },
            .left_parenthesis, .left_bracket, .left_brace => {
                if (depth == stack.len) return null;
                stack[depth] = .{
                    .tag = token.tag,
                    .expression_start = expression_start,
                    .candidate = if (token.tag == .left_bracket or token.tag == .left_parenthesis) pending else null,
                };
                depth += 1;
                expression_start = token.end;
                pending = null;
            },
            .right_parenthesis, .right_bracket, .right_brace => {
                if (depth == 0) return null;
                depth -= 1;
                const expected: Tag = switch (token.tag) {
                    .right_parenthesis => .left_parenthesis,
                    .right_bracket => .left_bracket,
                    .right_brace => .left_brace,
                    else => unreachable,
                };
                if (stack[depth].tag != expected) return null;
                expression_start = stack[depth].expression_start;
                pending = null;
            },
            .equal, .colon, .comma, .semicolon, .keyword_return, .keyword_let, .keyword_var => {
                expression_start = token.end;
                pending = null;
            },
            else => pending = null,
        }
    }
    while (depth != 0) {
        depth -= 1;
        if (stack[depth].candidate) |candidate| {
            const left = std.mem.trim(u8, source[candidate.first..candidate.last], " \t\r\n");
            if (left.len == 0) return null;
            return .{ .left = left, .right = source[candidate.right..end], .full_right = source[candidate.right..] };
        }
    }
    return null;
}
