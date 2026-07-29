const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parse(self: anytype, is_public: bool, is_internal: bool) !Ast.Structure {
    const position = self.current.position;
    try self.advance();
    if (self.current.tag != .identifier) return self.fail("expected protocol name");
    const name = self.current.lexeme;
    const name_position = self.current.position;
    if (std.mem.eql(u8, name, "Result")) return self.failAt(name_position, "'Result' is a reserved intrinsic type name");
    _ = try self.internTypeName(name);
    try self.advance();
    if (self.current.tag == .less) return self.fail("generic protocols are not supported");
    if (self.current.tag == .colon) return self.fail("protocol inheritance is not supported");
    try self.expect(.left_brace, "expected '{' after protocol name");
    var requirements: std.ArrayList(Ast.Function) = .empty;
    while (self.current.tag != .right_brace and self.current.tag != .end) {
        if (self.current.tag != .keyword_func) return self.fail("a protocol can declare only instance method requirements");
        try requirements.append(self.allocator, try parseRequirement(self));
    }
    try self.expect(.right_brace, "expected '}' after protocol requirements");
    return .{
        .is_public = is_public,
        .is_internal = is_internal,
        .is_protocol = true,
        .position = position,
        .name_position = name_position,
        .name = name,
        .fields = &.{},
        .methods = try requirements.toOwnedSlice(self.allocator),
    };
}

fn parseRequirement(self: anytype) !Ast.Function {
    const position = self.current.position;
    try self.advance();
    if (self.current.tag != .identifier) return self.fail("expected protocol method name");
    const name = self.current.lexeme;
    const name_position = self.current.position;
    try self.advance();
    if (self.current.tag == .less) return self.fail("generic protocol methods are not supported");
    try self.expect(.left_parenthesis, "expected '(' after protocol method name");
    var parameters: std.ArrayList(Ast.Parameter) = .empty;
    if (self.current.tag != .right_parenthesis) while (true) {
        const parameter = try self.parseParameter();
        if (parameter.default != null) return self.failAt(parameter.position, "protocol requirements cannot declare parameter defaults");
        try parameters.append(self.allocator, parameter);
        if (self.current.tag != .comma) break;
        try self.advance();
        if (self.current.tag == .right_parenthesis) break;
    };
    try self.expect(.right_parenthesis, "expected ')' after parameters");
    var return_mode: Ast.Parameter.Mode = .value;
    if (self.current.tag == .at or self.current.tag == .amp) {
        return_mode = if (self.current.tag == .at) .read else .mutable;
        try self.advance();
    }
    if (self.current.tag == .left_brace) return self.fail("protocol requirements cannot declare a body");
    const return_type: Ast.Type = if (self.current.tag == .semicolon or self.current.tag == .right_brace or
        self.current.position.line > self.previous.position.line) .void else try self.parseType();
    if (self.current.tag == .left_brace) return self.fail("protocol requirements cannot declare a body");
    try self.expectStatementTerminator();
    return .{
        .is_public = true,
        .position = position,
        .name_position = name_position,
        .name = name,
        .parameters = try parameters.toOwnedSlice(self.allocator),
        .return_type = return_type,
        .return_mode = return_mode,
        .statements = &.{},
    };
}
