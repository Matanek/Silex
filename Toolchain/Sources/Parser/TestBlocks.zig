const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parse(self: anytype) ![]const Ast.Function {
    const position = self.current.position;
    if (self.current.tag != .identifier or !std.mem.eql(u8, self.current.lexeme, "test")) return self.fail("expected 'test'");
    try self.advance();
    const test_name = if (self.current.tag == .string) name: {
        const decoded = try self.decodeStringToken(self.current);
        try self.advance();
        break :name decoded;
    } else null;
    if (self.current.tag != .left_brace) return self.fail("expected '{' after test name");
    try self.advance();

    const prefix = try std.fmt.allocPrint(self.allocator, "__silex_test_{d}", .{position.offset});
    const previous_prefix = self.test_prefix;
    const previous_local_count = self.test_local_functions.items.len;
    self.test_prefix = prefix;
    defer {
        self.test_prefix = previous_prefix;
        self.test_local_functions.items.len = previous_local_count;
    }
    try predeclareFunctions(self, prefix);

    var functions: std.ArrayList(Ast.Function) = .empty;
    var statements: std.ArrayList(Ast.Statement) = .empty;
    while (self.current.tag != .right_brace and self.current.tag != .end) {
        if (self.current.tag == .keyword_func) {
            try functions.append(self.allocator, try self.parseFunction(false, false, false));
        } else {
            try statements.append(self.allocator, try self.parseStatement());
        }
    }
    try self.expect(.right_brace, "expected '}' after test block");
    try functions.append(self.allocator, .{
        .is_test = true,
        .is_test_entry = true,
        .test_name = test_name,
        .test_owner = prefix,
        .is_local = true,
        .position = position,
        .name_position = position,
        .name = prefix,
        .parameters = &.{},
        .return_type = .void,
        .statements = try statements.toOwnedSlice(self.allocator),
    });
    return functions.toOwnedSlice(self.allocator);
}

fn predeclareFunctions(self: anytype, prefix: []const u8) !void {
    var token = self.current;
    var lexer = self.lexer;
    var depth: usize = 0;
    while (true) {
        if (token.tag == .right_brace and depth == 0) return;
        if (token.tag == .end) return self.fail("expected '}' after test block");
        if (token.tag == .keyword_func and depth == 0) {
            const name = try lexer.next();
            if (name.tag == .identifier or name.tag == .keyword_copy) {
                for (self.test_local_functions.items) |existing| {
                    if (!std.mem.eql(u8, existing.source, name.lexeme)) continue;
                    return self.failAt(name.position, "test function is already declared in this block");
                }
                try self.test_local_functions.append(self.allocator, .{
                    .source = name.lexeme,
                    .generated = try std.fmt.allocPrint(self.allocator, "{s}_{s}", .{ prefix, name.lexeme }),
                    .position = name.position,
                });
            }
        }
        if (token.tag == .left_brace) depth += 1 else if (token.tag == .right_brace) depth -= 1;
        token = try lexer.next();
    }
}
