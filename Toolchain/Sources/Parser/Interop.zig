const std = @import("std");
const Ast = @import("../Ast.zig");
const Strings = @import("../Strings.zig");

pub fn parseFunction(self: anytype) !Ast.ExternalFunction {
    const position = self.current.position;
    try self.advance();
    if (self.current.tag != .identifier) return self.fail("expected foreign function binding name after 'let'");
    const name = self.current.lexeme;
    const name_position = self.current.position;
    try self.advance();
    try self.expect(.equal, "expected '=' after foreign function binding name");
    try expectIdentifier(self, "C", "a module-level 'let' must use C.function");
    try self.expect(.dot, "expected '.function' after 'C'");
    try expectIdentifier(self, "function", "expected 'function' after 'C.'");
    try self.expect(.less, "expected '<' before foreign function signature");
    try self.expect(.keyword_func, "expected 'func' in C.function signature");
    try self.expect(.left_parenthesis, "expected '(' in foreign function signature");
    var parameters: std.ArrayList(Ast.ExternalType) = .empty;
    if (self.current.tag != .right_parenthesis) while (true) {
        try parameters.append(self.allocator, try parseType(self));
        if (self.current.tag != .comma) break;
        try self.advance();
    };
    try self.expect(.right_parenthesis, "expected ')' after foreign function parameter types");
    const return_type = try parseType(self);
    try self.expect(.greater, "expected '>' after foreign function signature");
    try self.expect(.left_parenthesis, "expected '(' after C.function signature");
    try expectIdentifier(self, "library", "expected 'library' argument in C.function");
    try self.expect(.colon, "expected ':' after 'library'");
    try expectIdentifier(self, "MacOS", "expected a platform library such as MacOS.lib_system");
    try self.expect(.dot, "expected library name after platform");
    if (self.current.tag != .identifier) return self.fail("expected platform library name");
    const library = try std.fmt.allocPrint(self.allocator, "MacOS.{s}", .{self.current.lexeme});
    try self.advance();
    try self.expect(.comma, "expected ',' after C.function library");
    try expectIdentifier(self, "name", "expected 'name' argument in C.function");
    try self.expect(.colon, "expected ':' after 'name'");
    if (self.current.tag != .string) return self.fail("C.function name must be a string literal");
    const source_name = try Strings.decode(self.allocator, self.current.lexeme);
    try self.advance();
    try self.expect(.right_parenthesis, "expected ')' after C.function arguments");
    try self.expectStatementTerminator();
    return .{
        .position = position,
        .name_position = name_position,
        .name = name,
        .parameters = try parameters.toOwnedSlice(self.allocator),
        .return_type = return_type,
        .library = library,
        .source_name = source_name,
    };
}

fn parseType(self: anytype) !Ast.ExternalType {
    if (self.current.tag == .keyword_int32) {
        try self.advance();
        return .int32;
    }
    try expectIdentifier(self, "C", "foreign signatures currently require int32 or a C type");
    try self.expect(.dot, "expected C type name after 'C'");
    if (self.current.tag != .identifier) return self.fail("expected C type name");
    const name = self.current.lexeme;
    try self.advance();
    if (std.mem.eql(u8, name, "Size")) return .size;
    if (std.mem.eql(u8, name, "SignedSize")) return .signed_size;
    if (!std.mem.eql(u8, name, "Pointer")) return self.fail("unknown C foreign type");
    try self.expect(.less, "expected '<' after C.Pointer");
    const child = try self.parseType();
    try self.expect(.greater, "expected '>' after C.Pointer element type");
    return .{ .read_pointer = child };
}

fn expectIdentifier(self: anytype, expected: []const u8, message: []const u8) !void {
    if (self.current.tag != .identifier or !std.mem.eql(u8, self.current.lexeme, expected)) return self.fail(message);
    try self.advance();
}
