const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parseFor(self: anytype) !Ast.Statement {
    const position = self.current.position;
    try self.advance();
    const parenthesized = self.current.tag == .left_parenthesis and !try tupleBindingFollows(self);
    if (parenthesized) try self.advance();
    var mode: Ast.ForStatement.Mode = switch (self.current.tag) {
        .keyword_let => .copy,
        .keyword_var => .mutable,
        else => .read,
    };
    if (mode != .read) try self.advance();
    var bindings: std.ArrayList(Ast.VariableDeclaration.DestructuredBinding) = .empty;
    const destructuring = self.current.tag == .left_parenthesis;
    if (destructuring) {
        if (mode != .read) return self.fail("tuple for bindings use their query access modes");
        try self.advance();
        while (true) {
            if (self.current.tag != .identifier) return self.fail("expected for binding name");
            const binding: Ast.VariableDeclaration.DestructuredBinding = .{
                .position = self.current.position,
                .name = self.current.lexeme,
            };
            for (bindings.items) |previous| if (std.mem.eql(u8, previous.name, binding.name)) {
                return self.failAt(binding.position, "for binding is duplicated");
            };
            try bindings.append(self.allocator, binding);
            try self.advance();
            if (self.current.tag != .comma) break;
            try self.advance();
        }
        if (bindings.items.len < 2) return self.fail("tuple for binding requires at least two names");
        try self.expect(.right_parenthesis, "expected ')' after for bindings");
    } else {
        if (self.current.tag != .identifier) return self.fail("expected for binding name");
        try bindings.append(self.allocator, .{ .position = self.current.position, .name = self.current.lexeme });
        try self.advance();
        if (self.current.tag == .comma) {
            if (mode != .read) return self.failAt(bindings.items[0].position, "indexed for binding mode belongs before the element");
            try self.advance();
            mode = switch (self.current.tag) {
                .keyword_let => .copy,
                .keyword_var => .mutable,
                else => .read,
            };
            if (mode != .read) try self.advance();
            if (self.current.tag != .identifier) return self.fail("expected indexed for element binding name");
            if (std.mem.eql(u8, bindings.items[0].name, self.current.lexeme)) {
                return self.failAt(self.current.position, "for binding is duplicated");
            }
            try bindings.append(self.allocator, .{ .position = self.current.position, .name = self.current.lexeme });
            try self.advance();
        }
    }
    const indexed = !destructuring and bindings.items.len == 2;
    const element_binding = if (indexed) bindings.items[1] else bindings.items[0];
    const name = if (destructuring) "" else element_binding.name;
    const name_position = element_binding.position;
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
        .index_position = if (indexed) bindings.items[0].position else null,
        .index_name = if (indexed) bindings.items[0].name else null,
        .bindings = if (destructuring) try bindings.toOwnedSlice(self.allocator) else &.{},
        .mode = mode,
        .source = source,
        .statements = try self.parseBlock(),
    } };
}

fn tupleBindingFollows(self: anytype) !bool {
    if (self.current.tag != .left_parenthesis) return false;
    var lexer = self.lexer;
    if ((try lexer.next()).tag != .identifier) return false;
    return (try lexer.next()).tag == .comma;
}
