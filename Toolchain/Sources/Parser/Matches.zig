const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parse(parser: anytype) !*Ast.Expression {
    const position = parser.current.position;
    try parser.advance();
    const subject = if (parser.current.tag == .left_brace) null else try parser.parseExpression(false);
    try parser.expect(.left_brace, if (subject == null) "expected '{' after match" else "expected '{' after match subject");

    var branches: std.ArrayList(Ast.Expression.MatchBranch) = .empty;
    while (parser.current.tag != .right_brace and parser.current.tag != .end) {
        const is_else = parser.current.tag == .keyword_else;
        const branch_position = parser.current.position;
        var condition: ?*Ast.Expression = null;
        var variant: []const u8 = "";
        var literal: ?Ast.Expression.MatchLiteral = null;
        if (is_else) {
            try parser.advance();
        } else if (subject == null) {
            condition = try parser.parseExpression(false);
        } else switch (parser.current.tag) {
            .identifier, .keyword_in => {
                variant = parser.current.lexeme;
                try parser.advance();
            },
            .integer => {
                literal = .{ .integer = .{ .lexeme = parser.current.lexeme } };
                try parser.advance();
            },
            .minus => {
                try parser.advance();
                if (parser.current.tag != .integer) return parser.fail("expected integer literal after '-' in match branch");
                literal = .{ .integer = .{ .lexeme = parser.current.lexeme, .negative = true } };
                try parser.advance();
            },
            .keyword_true, .keyword_false => {
                literal = .{ .boolean = parser.current.tag == .keyword_true };
                try parser.advance();
            },
            .string => {
                literal = .{ .string = try parser.decodeStringToken(parser.current) };
                try parser.advance();
            },
            else => return parser.fail("expected enum variant, scalar literal, or 'else' in match branch"),
        }

        var bindings: std.ArrayList(Ast.Expression.MatchBinding) = .empty;
        if (parser.current.tag == .left_parenthesis) {
            if (subject == null) return parser.fail("condition match branch cannot bind associated values");
            if (is_else) return parser.fail("else match branch cannot bind associated values");
            if (literal != null) return parser.fail("literal match branch cannot bind associated values");
            try parser.advance();
            if (parser.current.tag == .right_parenthesis) return parser.fail("an empty variant pattern does not use parentheses");
            while (true) {
                var mutable = false;
                var binding_keyword: ?[]const u8 = null;
                if (parser.current.tag == .keyword_let or parser.current.tag == .keyword_var) {
                    mutable = parser.current.tag == .keyword_var;
                    binding_keyword = parser.current.lexeme;
                    try parser.advance();
                }
                if (parser.current.tag != .identifier) return parser.fail("expected associated value binding");
                const ignored = std.mem.eql(u8, parser.current.lexeme, "_");
                if (ignored and binding_keyword != null) {
                    const message = try std.fmt.allocPrint(parser.allocator, "ignored match payload cannot use '{s}'", .{binding_keyword.?});
                    return parser.fail(message);
                }
                try bindings.append(parser.allocator, .{
                    .position = parser.current.position,
                    .name = parser.current.lexeme,
                    .mutable = mutable,
                    .ignored = ignored,
                });
                try parser.advance();
                if (parser.current.tag != .comma) break;
                try parser.advance();
                if (parser.current.tag == .right_parenthesis) return parser.fail("expected associated value binding after ','");
            }
            try parser.expect(.right_parenthesis, "expected ')' after match bindings");
        }
        const guard = if (parser.current.tag == .keyword_if) guard: {
            if (subject == null) return parser.fail("condition match branch cannot have a guard");
            if (is_else) return parser.fail("else match branch cannot have a guard");
            try parser.advance();
            break :guard try parser.parseExpression(false);
        } else null;
        try parser.expect(.fat_arrow, "expected '=>' after match pattern or guard");
        const branch_imperative = parser.current.tag == .left_brace;
        const statements = if (branch_imperative) try parser.parseBlock() else null;
        const value = if (branch_imperative) null else try parser.parseExpression(false);
        try parser.expectStatementTerminator();
        try branches.append(parser.allocator, .{
            .position = branch_position,
            .condition = condition,
            .variant = variant,
            .literal = literal,
            .is_else = is_else,
            .bindings = try bindings.toOwnedSlice(parser.allocator),
            .guard = guard,
            .value = value,
            .statements = statements,
        });
        if (is_else and parser.current.tag != .right_brace) return parser.fail("else match branch must be last");
    }
    try parser.expect(.right_brace, "expected '}' after match branches");
    if (branches.items.len == 0) return parser.failAt(position, "match requires at least one branch");
    return parser.newExpression(.{ .position = position, .value = .{ .match_expression = .{
        .subject = subject,
        .branches = try branches.toOwnedSlice(parser.allocator),
    } } });
}
