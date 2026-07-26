const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parseFor(self: anytype) !Ast.Statement {
    const position = self.current.position;
    try self.advance();
    const parenthesized = self.current.tag == .left_parenthesis;
    if (parenthesized) try self.advance();
    const mode: Ast.ForStatement.Mode = switch (self.current.tag) {
        .keyword_let => .copy,
        .keyword_var => .mutable,
        else => .read,
    };
    if (mode != .read) try self.advance();
    if (self.current.tag != .identifier) return self.fail("expected for binding name");
    const name = self.current.lexeme;
    const name_position = self.current.position;
    try self.advance();
    try self.expect(.keyword_in, "expected 'in' after for binding");
    const source: Ast.ForStatement.SourceValue = if (self.current.tag == .keyword_range) range: {
        try self.advance();
        try self.expect(.left_parenthesis, "expected '(' after 'range'");
        const start = try self.parseExpression(true);
        try self.expect(.comma, "expected ',' between range bounds");
        const end = try self.parseExpression(true);
        try self.expect(.right_parenthesis, "expected ')' after range bounds");
        break :range .{ .range = .{ .start = start, .end = end } };
    } else source: {
        const first = try self.parseExpression(parenthesized);
        if (self.current.tag == .dot_dot_dot) {
            try self.advance();
            break :source .{ .range = .{ .start = first, .end = try self.parseExpression(parenthesized) } };
        }
        break :source .{ .collection = first };
    };
    if (parenthesized) try self.expect(.right_parenthesis, "expected ')' after for binding");
    return .{ .for_statement = .{
        .position = position,
        .name_position = name_position,
        .name = name,
        .mode = mode,
        .source = source,
        .statements = try self.parseBlock(),
    } };
}
