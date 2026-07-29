const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parseWhile(self: anytype) !Ast.Statement {
    const position = self.current.position;
    try self.advance();
    const condition = try parseCondition(self);
    return .{ .while_statement = .{
        .position = position,
        .condition = condition,
        .statements = try self.parseBlock(),
    } };
}

pub fn parseMutex(self: anytype) !Ast.Statement {
    const position = self.current.position;
    try self.advance();
    return .{ .mutex_statement = .{
        .position = position,
        .statements = try self.parseBlock(),
    } };
}

pub fn parseLoopControl(self: anytype, is_continue: bool) !Ast.Statement {
    const position = self.current.position;
    try self.advance();
    try self.expectStatementTerminator();
    return if (is_continue)
        .{ .continue_statement = position }
    else
        .{ .break_statement = position };
}

pub fn parseIf(self: anytype) !Ast.Statement {
    const position = self.current.position;
    var branches: std.ArrayList(Ast.ConditionalBranch) = .empty;

    while (self.current.tag == .keyword_if or self.current.tag == .keyword_elif) {
        const branch_position = self.current.position;
        try self.advance();
        const condition = try parseCondition(self);
        const statements = try self.parseBlock();
        try branches.append(self.allocator, .{
            .position = branch_position,
            .condition = condition,
            .statements = statements,
        });
        if (self.current.tag != .keyword_elif) break;
    }

    var else_statements: ?[]const Ast.Statement = null;
    if (self.current.tag == .keyword_else) {
        try self.advance();
        if (self.current.tag == .keyword_if) {
            while (true) {
                const branch_position = self.current.position;
                try self.advance();
                const condition = try parseCondition(self);
                const statements = try self.parseBlock();
                try branches.append(self.allocator, .{
                    .position = branch_position,
                    .condition = condition,
                    .statements = statements,
                });
                if (self.current.tag == .keyword_elif) continue;
                if (self.current.tag == .keyword_else) {
                    try self.advance();
                    else_statements = try self.parseBlock();
                }
                break;
            }
        } else {
            else_statements = try self.parseBlock();
        }
    }

    return .{ .if_statement = .{
        .position = position,
        .branches = try branches.toOwnedSlice(self.allocator),
        .else_statements = else_statements,
    } };
}

fn parseCondition(self: anytype) !Ast.Condition {
    const parenthesized_binding = self.current.tag == .left_parenthesis and try parenthesizedConditionStartsBinding(self);
    const unparenthesized_binding = self.current.tag == .keyword_let or self.current.tag == .keyword_var or
        (self.current.tag == .identifier and try nextTag(self) == .equal);
    if (!parenthesized_binding and !unparenthesized_binding) {
        return .{ .expression = try self.parseExpression(false) };
    }

    if (parenthesized_binding) try self.advance();
    const position = self.current.position;
    const explicit = self.current.tag == .keyword_let or self.current.tag == .keyword_var;
    const mutable = self.current.tag == .keyword_var;
    if (explicit) try self.advance();
    if (self.current.tag != .identifier) return self.fail(if (explicit)
        "expected binding name after 'let' or 'var'"
    else
        "expected conditional binding name");
    const name = self.current.lexeme;
    const name_position = self.current.position;
    if (std.mem.eql(u8, name, "map_error")) return self.failAt(name_position, "'map_error' is a reserved intrinsic function name");
    try self.advance();
    try self.expect(.equal, "expected '=' after conditional binding name");
    const source = try self.parseExpression(parenthesized_binding);
    if (parenthesized_binding) try self.expect(.right_parenthesis, "expected ')' after conditional binding");
    return .{ .binding = .{
        .position = position,
        .name_position = name_position,
        .name = name,
        .mutable = mutable,
        .source = source,
    } };
}

fn parenthesizedConditionStartsBinding(self: anytype) !bool {
    var lexer = self.lexer;
    const first = try lexer.next();
    if (first.tag == .keyword_let or first.tag == .keyword_var) return true;
    if (first.tag != .identifier) return false;
    return (try lexer.next()).tag == .equal;
}

fn nextTag(self: anytype) !@TypeOf(self.current.tag) {
    var lexer = self.lexer;
    return (try lexer.next()).tag;
}
