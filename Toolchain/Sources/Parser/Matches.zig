const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parse(parser: anytype) !*Ast.Expression {
    const position = parser.current.position;
    if (parser.match_depth != 0) return parser.fail("nested match expressions are not available");
    parser.match_depth += 1;
    defer parser.match_depth -= 1;
    try parser.advance();
    const subject = try parser.parseExpression(false);
    try parser.expect(.left_brace, "expected '{' after match subject");

    var branches: std.ArrayList(Ast.Expression.MatchBranch) = .empty;
    var imperative: ?bool = null;
    while (parser.current.tag != .right_brace and parser.current.tag != .end) {
        const is_else = parser.current.tag == .keyword_else;
        if (!is_else and parser.current.tag != .identifier) return parser.fail("expected enum variant or 'else' in match branch");
        const branch_position = parser.current.position;
        const variant = if (is_else) "" else parser.current.lexeme;
        try parser.advance();

        var bindings: std.ArrayList(Ast.Expression.MatchBinding) = .empty;
        if (parser.current.tag == .left_parenthesis) {
            if (is_else) return parser.fail("else match branch cannot bind associated values");
            try parser.advance();
            if (parser.current.tag == .right_parenthesis) return parser.fail("an empty variant pattern does not use parentheses");
            while (true) {
                var mutable = false;
                if (parser.current.tag == .keyword_let or parser.current.tag == .keyword_var) {
                    mutable = parser.current.tag == .keyword_var;
                    try parser.advance();
                }
                if (parser.current.tag != .identifier) return parser.fail("expected associated value binding");
                try bindings.append(parser.allocator, .{
                    .position = parser.current.position,
                    .name = parser.current.lexeme,
                    .mutable = mutable,
                });
                try parser.advance();
                if (parser.current.tag != .comma) break;
                try parser.advance();
                if (parser.current.tag == .right_parenthesis) return parser.fail("expected associated value binding after ','");
            }
            try parser.expect(.right_parenthesis, "expected ')' after match bindings");
        }
        try parser.expect(.fat_arrow, "expected '=>' after match pattern");
        const branch_imperative = parser.current.tag == .left_brace;
        if (imperative) |expected| {
            if (expected != branch_imperative) return parser.fail("match cannot mix expression and block branches");
        } else imperative = branch_imperative;
        const statements = if (branch_imperative) try parser.parseBlock() else null;
        const value = if (branch_imperative) null else try parser.parseExpression(false);
        try parser.expectStatementTerminator();
        try branches.append(parser.allocator, .{
            .position = branch_position,
            .variant = variant,
            .is_else = is_else,
            .bindings = try bindings.toOwnedSlice(parser.allocator),
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
        .imperative = imperative.?,
    } } });
}
