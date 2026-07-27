const std = @import("std");
const Ast = @import("../Ast.zig");
const Generics = @import("Generics.zig");

pub fn parse(self: anytype, is_public: bool, is_internal: bool, is_class: bool) !Ast.Structure {
    const position = self.current.position;
    try self.advance();
    if (self.current.tag != .identifier) return self.fail(if (is_class) "expected class name" else "expected structure name");
    const name = self.current.lexeme;
    const name_position = self.current.position;
    if (std.mem.eql(u8, name, "Result")) return self.failAt(name_position, "'Result' is a reserved intrinsic type name");
    _ = try self.internTypeName(name);
    try self.advance();
    const type_parameters = try Generics.parseTypeParameters(self);
    if (is_class and type_parameters.len != 0) return self.failAt(name_position, "generic classes are not supported yet");
    const enclosing_type_parameters = self.type_parameters;
    self.type_parameters = if (type_parameters.len == 0) enclosing_type_parameters else type_parameters;
    defer self.type_parameters = enclosing_type_parameters;
    var base: ?Ast.Type = null;
    var base_position = name_position;
    if (self.current.tag == .colon) {
        if (!is_class) return self.fail("only classes can declare a base class");
        try self.advance();
        base_position = self.current.position;
        base = try self.parseType();
    }
    try self.expect(.left_brace, "expected '{' after type declaration");
    var fields: std.ArrayList(Ast.StructureField) = .empty;
    var static_fields: std.ArrayList(Ast.StructureField) = .empty;
    var constructors: std.ArrayList(Ast.Constructor) = .empty;
    var methods: std.ArrayList(Ast.Function) = .empty;
    var drop: ?Ast.Drop = null;
    while (self.current.tag != .right_brace and self.current.tag != .end) {
        var member_override = false;
        if (self.current.tag == .keyword_override) {
            if (!is_class) return self.fail("only class methods can declare override");
            member_override = true;
            try self.advance();
        }
        var member_public = !is_class;
        var member_internal = false;
        var member_private = is_class;
        var member_protected = false;
        var member_visibility = false;
        if (self.current.tag == .keyword_public or self.current.tag == .keyword_internal or
            self.current.tag == .keyword_private or self.current.tag == .keyword_protected)
        {
            member_visibility = true;
            member_public = self.current.tag == .keyword_public;
            member_internal = self.current.tag == .keyword_internal;
            member_private = self.current.tag == .keyword_private;
            member_protected = self.current.tag == .keyword_protected;
            if (!is_class and (member_private or member_protected)) return self.fail("structures only support public or internal members");
            try self.advance();
        }
        var member_static = false;
        if (self.current.tag == .keyword_static) {
            member_static = true;
            try self.advance();
        }
        if (self.current.tag == .keyword_init) {
            if (member_static) return self.fail("constructors cannot be static");
            if (member_override) return self.fail("constructors cannot declare override");
            var constructor = try parseConstructor(self, member_internal, base != null);
            constructor.is_public = member_public;
            constructor.is_private = member_private;
            constructor.is_protected = member_protected;
            try constructors.append(self.allocator, constructor);
            continue;
        }
        if (self.current.tag == .keyword_func) {
            if (member_override and member_static) return self.fail("static methods cannot declare override");
            var method = try self.parseFunction(member_public, member_internal);
            method.is_static = member_static;
            method.is_override = member_override;
            method.is_private = member_private;
            method.is_protected = member_protected;
            try methods.append(self.allocator, method);
            continue;
        }
        if (self.current.tag == .keyword_drop) {
            if (member_static) return self.fail("drop cannot be static");
            if (member_override) return self.fail("drop cannot declare override");
            if (is_class) return self.fail("class drop blocks are not supported yet");
            if (member_visibility) return self.fail("drop cannot declare visibility");
            if (drop != null) return self.fail("structure already declares drop");
            const drop_position = self.current.position;
            try self.advance();
            if (self.current.tag != .left_brace) return self.fail("drop has no parameters or return type");
            drop = .{ .position = drop_position, .statements = try self.parseBlock() };
            continue;
        }
        const mutable = switch (self.current.tag) {
            .keyword_let => false,
            .keyword_var => true,
            else => return self.fail("structure field must start with 'let' or 'var'"),
        };
        if (member_override) return self.fail("fields cannot declare override");
        const field_position = self.current.position;
        try self.advance();
        if (self.current.tag != .identifier) return self.fail("expected field name");
        const field_name = self.current.lexeme;
        const field_name_position = self.current.position;
        try self.advance();
        try self.expect(.colon, "expected ':' after field name");
        const field_type = try self.parseType();
        var default: ?*Ast.Expression = null;
        if (self.current.tag == .equal) {
            try self.advance();
            default = try self.parseExpression(false);
        }
        try self.expectStatementTerminator();
        const parsed_field = Ast.StructureField{
            .is_static = member_static,
            .is_public = member_public,
            .is_internal = member_internal,
            .is_private = member_private,
            .is_protected = member_protected,
            .position = field_position,
            .name_position = field_name_position,
            .name = field_name,
            .mutable = mutable,
            .type = field_type,
            .default = default,
        };
        if (member_static) try static_fields.append(self.allocator, parsed_field) else try fields.append(self.allocator, parsed_field);
    }
    try self.expect(.right_brace, "expected '}' after type members");
    return .{
        .is_public = is_public,
        .is_internal = is_internal,
        .is_class = is_class,
        .position = position,
        .name_position = name_position,
        .name = name,
        .base = base,
        .base_position = base_position,
        .type_parameters = type_parameters,
        .fields = try fields.toOwnedSlice(self.allocator),
        .static_fields = try static_fields.toOwnedSlice(self.allocator),
        .constructors = try constructors.toOwnedSlice(self.allocator),
        .methods = try methods.toOwnedSlice(self.allocator),
        .drop = drop,
    };
}

fn parseConstructor(self: anytype, is_internal: bool, has_base: bool) !Ast.Constructor {
    const position = self.current.position;
    try self.advance();
    if (self.current.tag == .less) return self.fail("constructors cannot declare type parameters");
    try self.expect(.left_parenthesis, "expected '(' after 'init'");
    var parameters: std.ArrayList(Ast.Parameter) = .empty;
    var has_default = false;
    if (self.current.tag != .right_parenthesis) while (true) {
        const parameter = try self.parseParameter();
        if (has_default and parameter.default == null) return self.failAt(parameter.position, "a required parameter cannot follow a parameter with a default value");
        has_default = has_default or parameter.default != null;
        try parameters.append(self.allocator, parameter);
        if (self.current.tag != .comma) break;
        try self.advance();
        if (self.current.tag == .right_parenthesis) return self.fail("expected parameter after ','");
    };
    try self.expect(.right_parenthesis, "expected ')' after constructor parameters");
    var super_arguments: []const *Ast.Expression = &.{};
    if (self.current.tag == .colon) {
        if (!has_base) return self.fail("only a derived class constructor can call super");
        try self.advance();
        try self.expect(.keyword_super, "expected 'super' after ':'");
        try self.expect(.left_parenthesis, "expected '(' after 'super'");
        var arguments: std.ArrayList(*Ast.Expression) = .empty;
        if (self.current.tag != .right_parenthesis) while (true) {
            try arguments.append(self.allocator, try self.parseExpression(true));
            if (self.current.tag != .comma) break;
            try self.advance();
        };
        try self.expect(.right_parenthesis, "expected ')' after super arguments");
        super_arguments = try arguments.toOwnedSlice(self.allocator);
    }
    return .{
        .is_public = !is_internal,
        .is_internal = is_internal,
        .position = position,
        .parameters = try parameters.toOwnedSlice(self.allocator),
        .super_arguments = super_arguments,
        .statements = try self.parseBlock(),
    };
}
