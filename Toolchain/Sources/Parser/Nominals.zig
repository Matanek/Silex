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

pub fn parseStaticType(self: anytype, is_public: bool, is_internal: bool, is_local: bool) !Ast.Structure {
    try self.advance();
    const is_class = switch (self.current.tag) {
        .keyword_class => true,
        .keyword_struct => false,
        else => return self.fail("expected 'class' or 'struct' after 'static'"),
    };
    return parseType(self, is_public, is_internal, is_local, false, false, is_class, true, false);
}

fn parseType(
    self: anytype,
    is_public: bool,
    is_internal: bool,
    is_local: bool,
    is_private: bool,
    is_protected: bool,
    is_class: bool,
    is_static_container: bool,
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
    if (is_static_container and own_type_parameters.len != 0) {
        const message = try std.fmt.allocPrint(self.allocator, "static {s}s cannot be generic", .{if (is_class) "classe" else "structure"});
        return self.failAt(name_position, message);
    }
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
        if (is_static_container) {
            const message = try std.fmt.allocPrint(self.allocator, "static {s}s cannot declare a base or conformances", .{if (is_class) "classe" else "structure"});
            return self.fail(message);
        }
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
        var member_public = is_public;
        var member_internal = is_internal;
        var member_local = is_local;
        var member_private = is_private;
        var member_protected = is_protected;
        var member_visibility = false;
        if (self.current.tag == .keyword_public or self.current.tag == .keyword_package or
            self.current.tag == .keyword_module or self.current.tag == .keyword_local or self.current.tag == .keyword_private or
            self.current.tag == .keyword_protected)
        {
            member_visibility = true;
            const requested = visibilityFromToken(self.current.tag);
            const container = visibilityFromFlags(is_public, is_internal, is_local, is_private, is_protected);
            if (!visibilityFits(requested, container)) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "member requests '{s}' visibility, but container '{s}' is '{s}'; '{s}' crosses the '{s}' boundary",
                    .{ visibilityName(requested), short_name, visibilityName(container), visibilityName(requested), visibilityName(container) },
                );
                return self.failAt(self.current.position, message);
            }
            member_public = requested == .public;
            member_internal = requested == .package;
            member_local = requested == .local;
            member_private = requested == .private;
            member_protected = requested == .protected;
            if (is_static_container and member_protected) {
                const message = try std.fmt.allocPrint(self.allocator, "static {s}s do not support protected members", .{if (is_class) "classe" else "structure"});
                return self.fail(message);
            }
            if (!is_class and member_protected) return self.fail("structures only support public, package, module, local, or private members");
            try self.advance();
        }
        var member_static_explicit = false;
        if (self.current.tag == .keyword_static) {
            member_static_explicit = true;
            try self.advance();
        }
        const member_static = is_static_container or member_static_explicit;
        if (self.current.tag == .keyword_struct or self.current.tag == .keyword_class) {
            if (member_override) return self.fail("nested types cannot declare override");
            const nested_is_class = self.current.tag == .keyword_class;
            const nested_is_static = member_static_explicit;
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
            if (is_static_container) {
                const message = try std.fmt.allocPrint(self.allocator, "static {s}s cannot declare constructors", .{if (is_class) "classe" else "structure"});
                return self.fail(message);
            }
            if (member_static) return self.fail("constructors cannot be static");
            if (member_override) return self.fail("constructors cannot declare override");
            var constructor = try parseConstructor(self, member_internal, member_local, base != null);
            constructor.is_public = member_public;
            constructor.is_internal = member_internal;
            constructor.is_local = member_local;
            constructor.is_private = member_private;
            constructor.is_protected = member_protected;
            constructor.visibility_explicit = member_visibility;
            try constructors.append(self.allocator, constructor);
            continue;
        }
        if (self.current.tag == .keyword_func) {
            if (member_override and member_static) return self.fail("static methods cannot declare override");
            var method = if (is_intrinsic)
                try self.parseIntrinsicMethod(member_public, member_internal, member_local)
            else
                try self.parseFunction(member_public, member_internal, member_local);
            method.is_static = member_static;
            method.is_override = member_override;
            method.is_private = member_private;
            method.is_protected = member_protected;
            method.visibility_explicit = member_visibility;
            if (member_static) for (nested_names.items) |nested_name| if (std.mem.eql(u8, nested_name, method.name)) {
                return self.failAt(method.name_position, "a nested type and static member cannot share a name");
            };
            try methods.append(self.allocator, method);
            continue;
        }
        if (self.current.tag == .keyword_drop) {
            if (is_intrinsic) return self.fail("intrinsic classes cannot declare drop");
            if (is_static_container) {
                const message = try std.fmt.allocPrint(self.allocator, "static {s}s cannot declare drop", .{if (is_class) "classe" else "structure"});
                return self.fail(message);
            }
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
        if (self.current.tag == .left_brace) {
            const property = try parsePropertyAccessors(
                self,
                name,
                field_name,
                field_name_position,
                field_type,
                mutable,
                member_static,
                member_public,
                member_internal,
                member_local,
                member_private,
                member_protected,
                &methods,
            );
            const parsed_field = Ast.StructureField{
                .is_static = member_static,
                .is_public = member_public,
                .is_internal = member_internal,
                .is_local = member_local,
                .is_private = member_private,
                .is_protected = member_protected,
                .visibility_explicit = member_visibility,
                .position = field_position,
                .name_position = field_name_position,
                .name = field_name,
                // The optional layer is private backing storage. Externally,
                // the property still has exactly `field_type`.
                .mutable = true,
                .type = .optional(field_type),
                .default = default,
                .property = property,
            };
            if (member_static) try static_fields.append(self.allocator, parsed_field) else try fields.append(self.allocator, parsed_field);
            continue;
        }
        try self.expectStatementTerminator();
        const parsed_field = Ast.StructureField{
            .is_static = member_static,
            .is_public = member_public,
            .is_internal = member_internal,
            .is_local = member_local,
            .is_private = member_private,
            .is_protected = member_protected,
            .visibility_explicit = member_visibility,
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
        .is_static = is_static_container,
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

fn parsePropertyAccessors(
    self: anytype,
    owner_name: []const u8,
    property_name: []const u8,
    property_position: @import("../Source.zig").Position,
    property_type: Ast.Type,
    writable: bool,
    is_static: bool,
    is_public: bool,
    is_internal: bool,
    is_local: bool,
    is_private: bool,
    is_protected: bool,
    methods: *std.ArrayList(Ast.Function),
) !Ast.StructureField.Property {
    try self.expect(.left_brace, "expected '{' before property accessors");
    var getter_method: ?usize = null;
    var setter_method: ?usize = null;
    while (self.current.tag != .right_brace and self.current.tag != .end) {
        if (self.current.tag != .identifier) return self.fail("expected 'get' or 'set' in property declaration");
        const accessor_position = self.current.position;
        const accessor_name = self.current.lexeme;
        if (std.mem.eql(u8, accessor_name, "get")) {
            if (getter_method != null) return self.failAt(accessor_position, "property already declares a getter");
            try self.advance();
            if (self.current.tag == .left_parenthesis) return self.fail("a getter has no parameters");
            const generated_name = try std.fmt.allocPrint(self.allocator, "$get.{s}", .{property_name});
            getter_method = methods.items.len;
            const body = try self.parseBlock();
            const statements = if (is_static) synchronized: {
                const wrapped = try self.allocator.alloc(Ast.Statement, 1);
                wrapped[0] = .{ .mutex_statement = .{ .position = accessor_position, .statements = body } };
                break :synchronized wrapped;
            } else body;
            try methods.append(self.allocator, .{
                .is_static = is_static,
                .is_public = is_public,
                .is_internal = is_internal,
                .is_local = is_local,
                .is_private = is_private,
                .is_protected = is_protected,
                .position = accessor_position,
                .name_position = accessor_position,
                .name = generated_name,
                .parameters = &.{},
                .return_type = property_type,
                .accessor = .{ .owner = owner_name, .property = property_name, .kind = .get },
                .statements = statements,
            });
            continue;
        }
        if (std.mem.eql(u8, accessor_name, "set")) {
            if (!writable) return self.failAt(accessor_position, "a 'let' property cannot declare a setter");
            if (setter_method != null) return self.failAt(accessor_position, "property already declares a setter");
            try self.advance();
            try self.expect(.left_parenthesis, "expected '(' after 'set'");
            if (self.current.tag != .identifier) return self.fail("expected setter value name");
            const value_position = self.current.position;
            const value_name = self.current.lexeme;
            try self.advance();
            try self.expect(.right_parenthesis, "expected ')' after setter value name");
            const parameters = try self.allocator.alloc(Ast.Parameter, 1);
            parameters[0] = .{ .position = value_position, .name = value_name, .type = property_type };
            const generated_name = try std.fmt.allocPrint(self.allocator, "$set.{s}", .{property_name});
            setter_method = methods.items.len;
            try methods.append(self.allocator, .{
                .is_static = is_static,
                .is_public = is_public,
                .is_internal = is_internal,
                .is_local = is_local,
                .is_private = is_private,
                .is_protected = is_protected,
                .position = accessor_position,
                .name_position = accessor_position,
                .name = generated_name,
                .parameters = parameters,
                .return_type = .void,
                .accessor = .{ .owner = owner_name, .property = property_name, .kind = .set },
                .statements = try self.parseBlock(),
            });
            continue;
        }
        return self.failAt(accessor_position, "expected 'get' or 'set' in property declaration");
    }
    try self.expect(.right_brace, "expected '}' after property accessors");
    if (getter_method == null) return self.failAt(property_position, "a property must declare a getter");
    if (writable and setter_method == null) {
        setter_method = methods.items.len;
        try methods.append(self.allocator, try defaultPropertySetter(
            self,
            owner_name,
            property_name,
            property_position,
            property_type,
            is_static,
            is_public,
            is_internal,
            is_local,
            is_private,
            is_protected,
        ));
    }
    return .{
        .value_type = property_type,
        .getter_method = getter_method.?,
        .setter_method = setter_method,
    };
}

fn defaultPropertySetter(
    self: anytype,
    owner_name: []const u8,
    property_name: []const u8,
    property_position: @import("../Source.zig").Position,
    property_type: Ast.Type,
    is_static: bool,
    is_public: bool,
    is_internal: bool,
    is_local: bool,
    is_private: bool,
    is_protected: bool,
) !Ast.Function {
    const receiver_name = if (is_static) owner_name else "self";
    const receiver = try self.allocator.create(Ast.Expression);
    receiver.* = .{ .position = property_position, .value = .{ .identifier = receiver_name } };
    const field = try self.allocator.create(Ast.Expression);
    field.* = .{ .position = property_position, .value = .{ .field_access = .{
        .base = receiver,
        .name = property_name,
        .name_position = property_position,
    } } };
    const value = try self.allocator.create(Ast.Expression);
    value.* = .{ .position = property_position, .value = .{ .identifier = "value" } };
    const target_fields = try self.allocator.alloc(Ast.AssignmentTarget.Field, 1);
    target_fields[0] = .{ .name_position = property_position, .name = property_name };
    const statements = try self.allocator.alloc(Ast.Statement, 1);
    statements[0] = .{ .assignment_statement = .{
        .position = property_position,
        .target = .{
            .source = field,
            .name_position = property_position,
            .name = receiver_name,
            .fields = target_fields,
        },
        .operator = .assign,
        .value = value,
    } };
    const parameters = try self.allocator.alloc(Ast.Parameter, 1);
    parameters[0] = .{ .position = property_position, .name = "value", .type = property_type };
    return .{
        .is_static = is_static,
        .is_public = is_public,
        .is_internal = is_internal,
        .is_local = is_local,
        .is_private = is_private,
        .is_protected = is_protected,
        .position = property_position,
        .name_position = property_position,
        .name = try std.fmt.allocPrint(self.allocator, "$set.{s}", .{property_name}),
        .parameters = parameters,
        .return_type = .void,
        .accessor = .{ .owner = owner_name, .property = property_name, .kind = .set, .synthetic = true },
        .statements = statements,
    };
}

const Visibility = enum { public, package, module, local, private, protected };

fn visibilityFromToken(tag: @import("../Lexer.zig").TokenTag) Visibility {
    return switch (tag) {
        .keyword_public => .public,
        .keyword_package => .package,
        .keyword_module => .module,
        .keyword_local => .local,
        .keyword_private => .private,
        .keyword_protected => .protected,
        else => unreachable,
    };
}

fn visibilityFromFlags(is_public: bool, is_internal: bool, is_local: bool, is_private: bool, is_protected: bool) Visibility {
    if (is_public) return .public;
    if (is_internal) return .package;
    if (is_local) return .local;
    if (is_private) return .private;
    if (is_protected) return .protected;
    return .module;
}

fn visibilityFits(requested: Visibility, container: Visibility) bool {
    return switch (container) {
        .public => true,
        .package => requested != .public,
        .module => requested != .public and requested != .package,
        .local => requested == .local or requested == .private or requested == .protected,
        .private => requested == .private,
        .protected => requested == .protected or requested == .private,
    };
}

fn visibilityName(visibility: Visibility) []const u8 {
    return @tagName(visibility);
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
