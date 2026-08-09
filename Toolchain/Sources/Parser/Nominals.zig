const std = @import("std");
const Ast = @import("../Ast.zig");
const Generics = @import("Generics.zig");

pub fn parse(self: anytype, is_public: bool, is_internal: bool, is_local: bool, is_class: bool) !Ast.Structure {
    return parseType(self, is_public, is_internal, is_local, false, false, is_class, false, false);
}

pub fn parseIntrinsicClass(self: anytype, is_public: bool) !Ast.Structure {
    try self.advance();
    if (self.current.tag != .keyword_class) return self.fail("expected 'class' after 'intrinsic'");
    return parseType(self, is_public, false, false, false, false, true, false, true);
}

pub fn parseStaticClass(self: anytype, is_public: bool, is_internal: bool, is_local: bool) !Ast.Structure {
    try self.advance();
    if (self.current.tag != .keyword_class) return self.fail("expected 'class' after 'static'");
    return parseType(self, is_public, is_internal, is_local, false, false, true, true, false);
}

fn parseType(
    self: anytype,
    is_public: bool,
    is_internal: bool,
    is_local: bool,
    is_private: bool,
    is_protected: bool,
    is_class: bool,
    is_static_class: bool,
    is_intrinsic: bool,
) !Ast.Structure {
    const position = self.current.position;
    try self.advance();
    if (self.current.tag != .identifier) return self.fail(if (is_class) "expected class name" else "expected structure name");
    const short_name = self.current.lexeme;
    const enclosing = self.nominal_prefix;
    const name = if (enclosing) |prefix| try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, short_name }) else short_name;
    const name_position = self.current.position;
    if (std.mem.eql(u8, short_name, "Result")) return self.failAt(name_position, "'Result' is a reserved intrinsic type name");
    _ = try self.internTypeName(name);
    try self.advance();
    const own_type_parameters = try Generics.parseTypeParameters(self);
    if (is_static_class and own_type_parameters.len != 0) return self.failAt(name_position, "static classes cannot be generic");
    const enclosing_type_parameters = self.type_parameters;
    const type_parameters = try self.allocator.alloc(Ast.TypeParameter, enclosing_type_parameters.len + own_type_parameters.len);
    @memcpy(type_parameters[0..enclosing_type_parameters.len], enclosing_type_parameters);
    for (own_type_parameters, 0..) |parameter, index| {
        for (enclosing_type_parameters) |outer| if (std.mem.eql(u8, outer.name, parameter.name)) {
            return self.failAt(parameter.position, "type parameter is already declared by an enclosing type");
        };
        type_parameters[enclosing_type_parameters.len + index] = parameter;
    }
    self.type_parameters = type_parameters;
    defer self.type_parameters = enclosing_type_parameters;
    const previous_prefix = self.nominal_prefix;
    self.nominal_prefix = name;
    defer self.nominal_prefix = previous_prefix;
    var base: ?Ast.Type = null;
    var conformances: std.ArrayList(Ast.Type) = .empty;
    var base_position = name_position;
    if (self.current.tag == .colon) {
        if (is_intrinsic) return self.fail("intrinsic classes cannot declare a base or conformances");
        if (is_static_class) return self.fail("static classes cannot declare a base");
        try self.advance();
        while (true) {
            const relation_position = self.current.position;
            const relation = try self.parseType();
            if (is_class and base == null) {
                base = relation;
                base_position = relation_position;
            } else try conformances.append(self.allocator, relation);
            if (self.current.tag != .comma) break;
            try self.advance();
        }
    }
    try self.expect(.left_brace, "expected '{' after type declaration");
    var fields: std.ArrayList(Ast.StructureField) = .empty;
    var static_fields: std.ArrayList(Ast.StructureField) = .empty;
    var constructors: std.ArrayList(Ast.Constructor) = .empty;
    var methods: std.ArrayList(Ast.Function) = .empty;
    var nested_names: std.ArrayList([]const u8) = .empty;
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
        var member_local = false;
        var member_private = is_class;
        var member_protected = false;
        var member_visibility = false;
        if (self.current.tag == .keyword_public or self.current.tag == .keyword_internal or self.current.tag == .keyword_local or
            self.current.tag == .keyword_private or self.current.tag == .keyword_protected)
        {
            member_visibility = true;
            member_public = self.current.tag == .keyword_public;
            member_internal = self.current.tag == .keyword_internal;
            member_local = self.current.tag == .keyword_local;
            member_private = self.current.tag == .keyword_private;
            member_protected = self.current.tag == .keyword_protected;
            if (is_static_class and member_protected) return self.fail("static classes do not support protected members");
            if (!is_class and member_protected) return self.fail("structures only support public, internal, local, or private members");
            try self.advance();
        }
        var member_static = false;
        if (self.current.tag == .keyword_static) {
            member_static = true;
            try self.advance();
        }
        if (self.current.tag == .keyword_struct or self.current.tag == .keyword_class) {
            if (member_override) return self.fail("nested types cannot declare override");
            const nested_is_class = self.current.tag == .keyword_class;
            const nested_is_static = member_static;
            if (nested_is_static and !nested_is_class) return self.fail("'static' before a nested type requires 'class'");
            if (member_protected and (!nested_is_class or nested_is_static)) {
                return self.fail("protected nested types must be ordinary classes");
            }
            const nested_short_name = blk: {
                var lexer = self.lexer;
                const token = try lexer.next();
                break :blk token.lexeme;
            };
            for (static_fields.items) |field| if (std.mem.eql(u8, field.name, nested_short_name)) {
                return self.fail("a nested type and static member cannot share a name");
            };
            for (methods.items) |method| if (method.is_static and std.mem.eql(u8, method.name, nested_short_name)) {
                return self.fail("a nested type and static member cannot share a name");
            };
            try nested_names.append(self.allocator, nested_short_name);
            const nested = try parseType(
                self,
                member_public,
                member_internal,
                member_local,
                member_private,
                member_protected,
                nested_is_class,
                nested_is_static,
                false,
            );
            try self.nested_structures.append(self.allocator, nested);
            continue;
        }
        if (self.current.tag == .keyword_init) {
            if (is_intrinsic) return self.fail("intrinsic classes cannot declare constructors");
            if (is_static_class) return self.fail("static classes cannot declare constructors");
            if (member_static) return self.fail("constructors cannot be static");
            if (member_override) return self.fail("constructors cannot declare override");
            var constructor = try parseConstructor(self, member_internal, member_local, base != null);
            constructor.is_public = member_public;
            constructor.is_internal = member_internal;
            constructor.is_private = member_private;
            constructor.is_protected = member_protected;
            try constructors.append(self.allocator, constructor);
            continue;
        }
        if (self.current.tag == .keyword_func) {
            if (is_static_class and !member_static) return self.fail("static class methods must start with 'static func'");
            if (member_override and member_static) return self.fail("static methods cannot declare override");
            var method = if (is_intrinsic)
                try self.parseIntrinsicMethod(member_public, member_internal, member_local)
            else
                try self.parseFunction(member_public, member_internal, member_local);
            method.is_static = member_static;
            method.is_override = member_override;
            method.is_private = member_private;
            method.is_protected = member_protected;
            if (member_static) for (nested_names.items) |nested_name| if (std.mem.eql(u8, nested_name, method.name)) {
                return self.failAt(method.name_position, "a nested type and static member cannot share a name");
            };
            try methods.append(self.allocator, method);
            continue;
        }
        if (self.current.tag == .keyword_drop) {
            if (is_intrinsic) return self.fail("intrinsic classes cannot declare drop");
            if (is_static_class) return self.fail("static classes cannot declare drop");
            if (member_static) return self.fail("drop cannot be static");
            if (member_override) return self.fail("drop cannot declare override");
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
        if (is_intrinsic) return self.fail("intrinsic classes cannot declare fields");
        if (is_static_class and !member_static) return self.fail("static class fields must start with 'static let' or 'static var'");
        if (member_override) return self.fail("fields cannot declare override");
        const field_position = self.current.position;
        try self.advance();
        if (self.current.tag != .identifier) return self.fail("expected field name");
        const field_name = self.current.lexeme;
        const field_name_position = self.current.position;
        try self.advance();
        if (member_static) for (nested_names.items) |nested_name| if (std.mem.eql(u8, nested_name, field_name)) {
            return self.failAt(field_name_position, "a nested type and static member cannot share a name");
        };
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
            .is_local = member_local,
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
        .is_local = is_local,
        .is_private = is_private,
        .is_protected = is_protected,
        .is_class = is_class,
        .is_intrinsic = is_intrinsic,
        .is_static = is_static_class,
        .enclosing = enclosing,
        .position = position,
        .name_position = name_position,
        .name = name,
        .base = base,
        .base_position = base_position,
        .conformances = try conformances.toOwnedSlice(self.allocator),
        .type_parameters = type_parameters,
        .fields = try fields.toOwnedSlice(self.allocator),
        .static_fields = try static_fields.toOwnedSlice(self.allocator),
        .constructors = try constructors.toOwnedSlice(self.allocator),
        .methods = try methods.toOwnedSlice(self.allocator),
        .drop = drop,
    };
}

fn parseConstructor(self: anytype, is_internal: bool, is_local: bool, has_base: bool) !Ast.Constructor {
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
        if (self.current.tag == .right_parenthesis) break;
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
        .is_public = !is_internal and !is_local,
        .is_internal = is_internal,
        .is_local = is_local,
        .position = position,
        .parameters = try parameters.toOwnedSlice(self.allocator),
        .super_arguments = super_arguments,
        .statements = try self.parseBlock(),
    };
}
