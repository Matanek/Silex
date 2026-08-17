const std = @import("std");
const Ast = @import("../Ast.zig");

pub fn parse(self: anytype, is_public: bool, is_internal: bool, is_local: bool) !Ast.Structure {
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
        var member_public = is_public;
        var member_internal = is_internal;
        var member_local = is_local;
        var member_private = false;
        var explicit = false;
        if (self.current.tag == .keyword_public or self.current.tag == .keyword_internal or self.current.tag == .keyword_package or
            self.current.tag == .keyword_module or self.current.tag == .keyword_local or self.current.tag == .keyword_private or
            self.current.tag == .keyword_protected)
        {
            explicit = true;
            const requested = self.current.tag;
            if (requested == .keyword_protected) return self.fail("protected visibility is reserved for class members");
            const container_rank: u8 = if (is_public) 3 else if (is_internal) 2 else if (is_local) 0 else 1;
            const requested_rank: u8 = if (requested == .keyword_public)
                3
            else if (requested == .keyword_internal or requested == .keyword_package)
                2
            else if (requested == .keyword_module)
                1
            else
                0;
            if (requested != .keyword_private and requested_rank > container_rank) {
                const requested_name = if (requested == .keyword_internal) "package" else self.current.lexeme;
                const container_name = if (is_public) "public" else if (is_internal) "package" else if (is_local) "local" else "module";
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "member requests '{s}' visibility, but container '{s}' is '{s}'; '{s}' crosses the '{s}' boundary",
                    .{ requested_name, name, container_name, requested_name, container_name },
                );
                return self.failAt(self.current.position, message);
            }
            member_public = requested == .keyword_public;
            member_internal = requested == .keyword_internal or requested == .keyword_package;
            member_local = requested == .keyword_local;
            member_private = requested == .keyword_private;
            try self.advance();
        }
        if (self.current.tag != .keyword_func) return self.fail("a protocol can declare only instance method requirements");
        var requirement = try parseRequirement(self);
        requirement.is_public = member_public;
        requirement.is_internal = member_internal;
        requirement.is_local = member_local;
        requirement.is_private = member_private;
        requirement.visibility_explicit = explicit;
        try requirements.append(self.allocator, requirement);
    }
    try self.expect(.right_brace, "expected '}' after protocol requirements");
    return .{
        .is_public = is_public,
        .is_internal = is_internal,
        .is_local = is_local,
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
        .position = position,
        .name_position = name_position,
        .name = name,
        .parameters = try parameters.toOwnedSlice(self.allocator),
        .return_type = return_type,
        .return_mode = return_mode,
        .statements = &.{},
    };
}
