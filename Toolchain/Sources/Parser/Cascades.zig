const std = @import("std");
const Ast = @import("../Ast.zig");
const Generics = @import("Generics.zig");

pub fn parse(self: anytype, receiver: *Ast.Expression) !*Ast.Expression {
    if (self.current.tag != .dot_dot) return receiver;

    var operations: std.ArrayList(Ast.Expression.Cascade.Operation) = .empty;
    while (self.current.tag == .dot_dot) {
        try self.advance();
        if (self.current.tag != .identifier and self.current.tag != .keyword_match) return self.fail("expected member name after '..'");
        const member = self.current;
        try self.advance();
        const type_arguments = if (self.current.tag == .less)
            try Generics.parseTypeArguments(self)
        else
            &.{};

        if (self.current.tag == .left_parenthesis) {
            try self.advance();
            var arguments: std.ArrayList(*Ast.Expression) = .empty;
            var named_arguments: std.ArrayList(Ast.Expression.NamedArgument) = .empty;
            if (self.current.tag != .right_parenthesis) while (true) {
                if (try self.startsNamedArgument()) {
                    const position = self.current.position;
                    const name = self.current.lexeme;
                    try self.advance();
                    try self.expect(.colon, "expected ':' after parameter label");
                    try named_arguments.append(self.allocator, .{ .position = position, .name = name, .value = try self.parseExpression(true) });
                } else {
                    if (named_arguments.items.len != 0) return self.fail("a positional argument cannot follow a named argument");
                    try arguments.append(self.allocator, try self.parseExpression(true));
                }
                if (self.current.tag == .right_parenthesis) break;
                if (self.current.tag != .comma) return self.fail("expected ',' or ')' after cascade method argument");
                try self.advance();
                if (self.current.tag == .right_parenthesis) {
                    if (named_arguments.items.len == 0) return self.fail("expected cascade method argument after ','");
                    break;
                }
            };
            try self.expect(.right_parenthesis, "expected ')' after cascade method arguments");
            try operations.append(self.allocator, .{ .method_call = .{
                .name = member.lexeme,
                .name_position = member.position,
                .arguments = try arguments.toOwnedSlice(self.allocator),
                .named_arguments = try named_arguments.toOwnedSlice(self.allocator),
                .type_arguments = type_arguments,
            } });
            continue;
        }

        if (type_arguments.len != 0) return self.fail("expected '(' after cascade method type arguments");
        if (self.current.tag != .equal) return self.fail("expected '(' or '=' after cascade member");
        try self.advance();
        try operations.append(self.allocator, .{ .field_assignment = .{
            .name = member.lexeme,
            .name_position = member.position,
            .value = try self.parseLogicalOr(false),
        } });
    }

    const cascade = try self.newExpression(.{
        .position = receiver.position,
        .value = .{ .cascade = .{
            .receiver = receiver,
            .operations = try operations.toOwnedSlice(self.allocator),
        } },
    });
    return self.parsePostfix(cascade);
}
