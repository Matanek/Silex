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
        if (self.current.tag == .keyword_public or self.current.tag == .keyword_package or
            self.current.tag == .keyword_module or self.current.tag == .keyword_local or self.current.tag == .keyword_private or
            self.current.tag == .keyword_protected)
        {
            explicit = true;
            const requested = self.current.tag;
            if (requested == .keyword_protected) return self.fail("protected visibility is reserved for class members");
            const container_rank: u8 = if (is_public) 3 else if (is_internal) 2 else if (is_local) 0 else 1;
            const requested_rank: u8 = if (requested == .keyword_public)
                3
            else if (requested == .keyword_package)
                2
            else if (requested == .keyword_module)
                1
            else
                0;
            if (requested != .keyword_private and requested_rank > container_rank) {
                const requested_name = self.current.lexeme;
                const container_name = if (is_public) "public" else if (is_internal) "package" else if (is_local) "local" else "module";
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "member requests '{s}' visibility, but container '{s}' is '{s}'; '{s}' crosses the '{s}' boundary",
                    .{ requested_name, name, container_name, requested_name, container_name },
                );
                return self.failAt(self.current.position, message);
            }
            member_public = requested == .keyword_public;
            member_internal = requested == .keyword_package;
            member_local = requested == .keyword_local;
            member_private = requested == .keyword_private;
            try self.advance();
        }
        if (self.current.tag == .keyword_func) {
            var requirement = try parseRequirement(self);
            requirement.is_public = member_public;
            requirement.is_internal = member_internal;
            requirement.is_local = member_local;
            requirement.is_private = member_private;
            requirement.visibility_explicit = explicit;
            try requirements.append(self.allocator, requirement);
        } else try parsePropertyRequirement(
            self,
            name,
            member_public,
            member_internal,
            member_local,
            member_private,
            explicit,
            &requirements,
        );
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

fn parsePropertyRequirement(
    self: anytype,
    owner_name: []const u8,
    is_public: bool,
    is_internal: bool,
    is_local: bool,
    is_private: bool,
    visibility_explicit: bool,
    requirements: *std.ArrayList(Ast.Function),
) !void {
    if (self.current.tag != .identifier) return self.fail("a protocol can declare only method or property requirements");
    const name = self.current.lexeme;
    const position = self.current.position;
    try self.advance();
    try self.expect(.colon, "expected ':' after protocol property name");
    const type_value = try self.parseType();
    try self.expect(.left_brace, "expected '{' before protocol property accessors");
    var has_get = false;
    var has_set = false;
    while (self.current.tag != .right_brace and self.current.tag != .end) {
        if (self.current.tag != .identifier) return self.fail("expected 'get' or 'set' in protocol property requirement");
        if (std.mem.eql(u8, self.current.lexeme, "get")) {
            if (has_get) return self.failAt(self.current.position, "protocol property already requires get");
            has_get = true;
        } else if (std.mem.eql(u8, self.current.lexeme, "set")) {
            if (has_set) return self.failAt(self.current.position, "protocol property already requires set");
            has_set = true;
        } else return self.fail("expected 'get' or 'set' in protocol property requirement");
        try self.advance();
        if (self.current.tag == .semicolon) try self.advance();
    }
    try self.expect(.right_brace, "expected '}' after protocol property requirement");
    if (!has_get) return self.failAt(position, "a protocol property must require get");
    try requirements.append(self.allocator, .{
        .is_public = is_public,
        .is_internal = is_internal,
        .is_local = is_local,
        .is_private = is_private,
        .visibility_explicit = visibility_explicit,
        .position = position,
        .name_position = position,
        .name = try std.fmt.allocPrint(self.allocator, "$get.{s}", .{name}),
        .parameters = &.{},
        .return_type = type_value,
        .accessor = .{ .owner = owner_name, .property = name, .kind = .get },
        .statements = &.{},
    });
    if (!has_set) return;
    const parameters = try self.allocator.alloc(Ast.Parameter, 1);
    parameters[0] = .{ .position = position, .name = "value", .type = type_value };
    try requirements.append(self.allocator, .{
        .is_public = is_public,
        .is_internal = is_internal,
        .is_local = is_local,
        .is_private = is_private,
        .visibility_explicit = visibility_explicit,
        .position = position,
        .name_position = position,
        .name = try std.fmt.allocPrint(self.allocator, "$set.{s}", .{name}),
        .parameters = parameters,
        .return_type = .void,
        .accessor = .{ .owner = owner_name, .property = name, .kind = .set },
        .statements = &.{},
    });
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
