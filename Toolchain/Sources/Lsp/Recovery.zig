const std = @import("std");
const LexerModule = @import("../Lexer.zig");
const ParserModule = @import("../Parser.zig");

const Allocator = std.mem.Allocator;
const Token = LexerModule.Token;
const TokenTag = LexerModule.TokenTag;

pub const Kind = enum {
    complete,
    completion_site,
    isolated_invalid_declaration,
    discarded_completion_line,
    unavailable,
};

const TopLevelChunk = struct { start: usize, end: usize };

pub fn isolateInvalidTopLevelDeclarations(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
) !?[]const u8 {
    const tokens = try tokensUntil(allocator, source, source.len);
    var chunks: std.ArrayList(TopLevelChunk) = .empty;
    var chunk_start: ?usize = null;
    var brace_depth: usize = 0;
    var line_terminated = false;
    var last_token_line: usize = 0;
    var last_token_end: usize = 0;
    for (tokens) |token| {
        if (chunk_start != null and brace_depth == 0 and line_terminated and
            token.position.line > last_token_line)
        {
            try chunks.append(allocator, .{ .start = chunk_start.?, .end = last_token_end });
            chunk_start = null;
            line_terminated = false;
        }
        if (chunk_start == null) chunk_start = token.start;
        switch (token.tag) {
            .left_brace => brace_depth += 1,
            .right_brace => {
                brace_depth -|= 1;
                if (brace_depth == 0) {
                    try chunks.append(allocator, .{ .start = chunk_start.?, .end = token.end });
                    chunk_start = null;
                    line_terminated = false;
                }
            },
            .semicolon => if (brace_depth == 0) {
                try chunks.append(allocator, .{ .start = chunk_start.?, .end = token.end });
                chunk_start = null;
                line_terminated = false;
            },
            .keyword_use, .keyword_let => if (brace_depth == 0) {
                line_terminated = true;
            },
            else => {},
        }
        last_token_line = token.position.line;
        last_token_end = token.end;
    }
    if (chunk_start) |start| try chunks.append(allocator, .{ .start = start, .end = source.len });

    var sanitized = try allocator.dupe(u8, source);
    var changed = false;
    for (chunks.items) |chunk| {
        if (cursor >= chunk.start and cursor <= chunk.end) continue;
        var parser = ParserModule.Parser.init(allocator, source[chunk.start..chunk.end]);
        _ = parser.parse() catch {
            for (sanitized[chunk.start..chunk.end]) |*character| {
                if (character.* != '\n' and character.* != '\r') character.* = ' ';
            }
            changed = true;
            continue;
        };
    }
    return if (changed) sanitized else null;
}

pub fn unmatchedLineClosers(
    allocator: Allocator,
    source: []const u8,
    line_start: usize,
    cursor: usize,
) ![]const u8 {
    var suffix = cursor;
    while (suffix < source.len and std.ascii.isWhitespace(source[suffix])) suffix += 1;
    if (suffix >= source.len or source[suffix] != '}') return "";

    const tokens = try tokensUntil(allocator, source[line_start..cursor], cursor - line_start);
    var stack: [128]TokenTag = undefined;
    var depth: usize = 0;
    for (tokens) |token| switch (token.tag) {
        .left_parenthesis, .left_bracket => {
            if (depth == stack.len) return "";
            stack[depth] = token.tag;
            depth += 1;
        },
        .right_parenthesis => {
            if (depth != 0 and stack[depth - 1] == .left_parenthesis) depth -= 1;
        },
        .right_bracket => {
            if (depth != 0 and stack[depth - 1] == .left_bracket) depth -= 1;
        },
        else => {},
    };
    if (depth == 0) return "";
    const closers = try allocator.alloc(u8, depth);
    var index: usize = 0;
    while (depth != 0) : (index += 1) {
        depth -= 1;
        closers[index] = if (stack[depth] == .left_parenthesis) ')' else ']';
    }
    return closers;
}

pub fn separateAdjacentControlStatement(
    allocator: Allocator,
    source: []const u8,
    cursor: usize,
) !?[]u8 {
    const tokens = try tokensUntil(allocator, source, @min(cursor, source.len));
    var candidate: ?Token = null;
    var previous: ?Token = null;
    for (tokens) |token| {
        if (token.tag == .keyword_if or token.tag == .keyword_while) {
            if (previous) |before| {
                const boundary = before.tag == .left_brace or before.tag == .semicolon or
                    before.tag == .keyword_else or before.position.line != token.position.line;
                if (!boundary and before.end < token.start and
                    std.mem.trim(u8, source[before.end..token.start], " \t\r").len == 0)
                {
                    candidate = token;
                }
            }
        }
        previous = token;
    }
    const control = candidate orelse return null;
    var separated = try allocator.dupe(u8, source);
    var boundary = control.start;
    while (boundary != 0 and (separated[boundary - 1] == ' ' or separated[boundary - 1] == '\t')) boundary -= 1;
    if (boundary == control.start) return null;
    separated[control.start - 1] = '\n';
    return separated;
}

fn tokensUntil(allocator: Allocator, source: []const u8, end: usize) ![]const Token {
    var tokens: std.ArrayList(Token) = .empty;
    var lexer = LexerModule.Lexer.init(source[0..end]);
    while (true) {
        const token = lexer.next() catch break;
        if (token.tag == .end) break;
        try tokens.append(allocator, token);
    }
    return tokens.toOwnedSlice(allocator);
}

test "isolating an invalid declaration preserves a preceding use" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\use GFX.Canvas
        \\func broken( { }
        \\func okay() {}
    ;
    const cursor = std.mem.indexOf(u8, source, "okay").?;
    const isolated = (try isolateInvalidTopLevelDeclarations(allocator, source, cursor)).?;

    var parser = ParserModule.Parser.init(allocator, isolated);
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 1), program.uses.len);
    try std.testing.expectEqualStrings("GFX.Canvas", program.uses[0].path);
    try std.testing.expectEqual(@as(usize, 1), program.functions.len);
    try std.testing.expectEqualStrings("okay", program.functions[0].name);
}

test "separate an adjacent control statement without shifting source offsets" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "func inspect() { let value = make() if value.member() {} }";
    const cursor = std.mem.indexOf(u8, source, "member").? + "member".len;
    const separated = (try separateAdjacentControlStatement(arena.allocator(), source, cursor)).?;
    try std.testing.expectEqual(source.len, separated.len);
    try std.testing.expectEqualStrings(
        "func inspect() { let value = make()\nif value.member() {} }",
        separated,
    );
    var parser = ParserModule.Parser.init(arena.allocator(), separated);
    _ = try parser.parse();
}
