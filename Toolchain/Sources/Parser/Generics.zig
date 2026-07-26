const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parseTypeParameters(parser: anytype) ![]const Ast.TypeParameter {
    if (parser.current.tag != .less) return &.{};
    try parser.advance();
    var parameters: std.ArrayList(Ast.TypeParameter) = .empty;
    while (true) {
        if (parser.current.tag != .identifier) return parser.fail("expected type parameter name");
        const parameter: Ast.TypeParameter = .{ .position = parser.current.position, .name = parser.current.lexeme };
        for (parameters.items) |previous| if (std.mem.eql(u8, previous.name, parameter.name)) {
            return parser.failAt(parameter.position, "type parameter is already declared");
        };
        try parameters.append(parser.allocator, parameter);
        try parser.advance();
        if (parser.current.tag != .comma) break;
        try parser.advance();
        if (parser.current.tag == .greater or parser.current.tag == .shift_right) {
            return parser.fail("expected type parameter after ','");
        }
    }
    try consumeGreater(parser, "expected '>' after type parameters");
    return parameters.toOwnedSlice(parser.allocator);
}

pub fn parseTypeArguments(parser: anytype) ![]const Ast.Type {
    try parser.expect(.less, "expected '<' before type arguments");
    var arguments: std.ArrayList(Ast.Type) = .empty;
    while (true) {
        try arguments.append(parser.allocator, try parser.parseType());
        if (parser.current.tag != .comma) break;
        try parser.advance();
        if (parser.current.tag == .greater or parser.current.tag == .shift_right) {
            return parser.fail("expected type argument after ','");
        }
    }
    try consumeGreater(parser, "expected '>' after type arguments");
    return arguments.toOwnedSlice(parser.allocator);
}

pub fn callArgumentsFollow(parser: anytype) !bool {
    if (parser.current.tag != .less) return false;
    var lexer = parser.lexer;
    var depth: usize = 1;
    while (depth != 0) {
        const token = lexer.next() catch return false;
        switch (token.tag) {
            .less => depth += 1,
            .greater => depth -= 1,
            .shift_right => {
                if (depth < 2) return false;
                depth -= 2;
            },
            .end, .semicolon, .left_brace, .right_brace => return false,
            else => {},
        }
    }
    return (lexer.next() catch return false).tag == .left_parenthesis;
}

fn consumeGreater(parser: anytype, message: []const u8) !void {
    if (parser.current.tag == .greater) return parser.advance();
    if (parser.current.tag != .shift_right) return parser.fail(message);
    const token = parser.current;
    parser.previous = .{
        .tag = .greater,
        .lexeme = token.lexeme[0..1],
        .position = token.position,
        .start = token.start,
        .end = token.start + 1,
    };
    parser.current = .{
        .tag = .greater,
        .lexeme = token.lexeme[1..2],
        .position = .{
            .offset = token.position.offset + 1,
            .line = token.position.line,
            .column = token.position.column + 1,
            .file = token.position.file,
        },
        .start = token.start + 1,
        .end = token.end,
    };
}
