const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

pub fn parseType(self: anytype, position: Source.Position) !Ast.Type {
    try self.expect(.left_parenthesis, "expected '(' before tuple type");
    var fields: std.ArrayList(Ast.StructureField) = .empty;
    var named: ?bool = null;
    while (true) {
        const field_position = self.current.position;
        const has_name = try nameFollows(self);
        if (named) |expected_named| {
            if (has_name != expected_named) return self.fail("tuple elements must be either all named or all positional");
        } else named = has_name;
        const field_name = if (has_name) name: {
            const value = self.current.lexeme;
            for (fields.items) |field| if (std.mem.eql(u8, field.name, value)) {
                const message = try std.fmt.allocPrint(self.allocator, "tuple element name '{s}' is duplicated", .{value});
                return self.failAt(field_position, message);
            };
            try self.advance();
            try self.expect(.colon, "expected ':' after tuple element name");
            break :name value;
        } else try std.fmt.allocPrint(self.allocator, "{d}", .{fields.items.len});
        const access_mode: Ast.Parameter.Mode = switch (self.current.tag) {
            .at => mode: {
                try self.advance();
                break :mode .read;
            },
            .amp => mode: {
                try self.advance();
                break :mode .mutable;
            },
            else => .value,
        };
        try fields.append(self.allocator, .{
            .position = field_position,
            .name_position = field_position,
            .name = field_name,
            .mutable = false,
            .access_mode = access_mode,
            .type = try self.parseType(),
            .default = null,
        });
        if (self.current.tag != .comma) break;
        try self.advance();
        if (self.current.tag == .right_parenthesis) return self.fail("tuple types require an element after ','");
    }
    if (fields.items.len < 2) return self.failAt(position, "a tuple type requires at least two elements");
    try self.expect(.right_parenthesis, "expected ')' after tuple type");
    return internType(self, position, named.?, try fields.toOwnedSlice(self.allocator));
}

pub fn parseExpression(self: anytype) !*Ast.Expression {
    const position = self.current.position;
    try self.expect(.left_parenthesis, "expected '('");
    if (self.current.tag == .right_parenthesis) return self.fail("a tuple requires at least two elements");

    var elements: std.ArrayList(Ast.Expression.TupleLiteral.Element) = .empty;
    const first_named = try nameFollows(self);
    while (true) {
        const element_position = self.current.position;
        const has_name = try nameFollows(self);
        if (has_name != first_named) return self.fail("tuple elements must be either all named or all positional");
        const name = if (has_name) name: {
            const value = self.current.lexeme;
            for (elements.items) |element| if (std.mem.eql(u8, element.name.?, value)) {
                const message = try std.fmt.allocPrint(self.allocator, "tuple element name '{s}' is duplicated", .{value});
                return self.failAt(element_position, message);
            };
            try self.advance();
            try self.expect(.colon, "expected ':' after tuple element name");
            break :name value;
        } else null;
        const value = try self.parseExpression(true);
        try elements.append(self.allocator, .{ .position = element_position, .name = name, .value = value });
        if (self.current.tag != .comma) {
            if (elements.items.len == 1 and !first_named) {
                try self.expect(.right_parenthesis, "expected ')' after expression");
                return value;
            }
            break;
        }
        try self.advance();
        if (self.current.tag == .right_parenthesis) return self.fail("tuples require an element after ','");
    }
    if (elements.items.len < 2) return self.failAt(position, "a tuple requires at least two elements");
    try self.expect(.right_parenthesis, "expected ')' after tuple");

    const placeholder = try internPlaceholder(self, position, first_named, elements.items);
    return self.newExpression(.{ .position = position, .value = .{ .tuple_literal = .{
        .elements = try elements.toOwnedSlice(self.allocator),
        .placeholder_type = placeholder,
        .named = first_named,
    } } });
}

pub fn parseDestructuring(self: anytype, position: Source.Position, mutable: bool) !Ast.Statement {
    try self.expect(.left_parenthesis, "expected '(' before tuple bindings");
    var bindings: std.ArrayList(Ast.VariableDeclaration.DestructuredBinding) = .empty;
    while (true) {
        if (self.current.tag != .identifier) return self.fail("expected variable name in tuple destructuring");
        const binding_position = self.current.position;
        const name = self.current.lexeme;
        for (bindings.items) |binding| if (std.mem.eql(u8, binding.name, name)) {
            const message = try std.fmt.allocPrint(self.allocator, "binding '{s}' is duplicated in tuple destructuring", .{name});
            return self.failAt(binding_position, message);
        };
        try bindings.append(self.allocator, .{ .position = binding_position, .name = name });
        try self.advance();
        if (self.current.tag != .comma) break;
        try self.advance();
    }
    if (bindings.items.len < 2) return self.failAt(position, "tuple destructuring requires at least two bindings");
    try self.expect(.right_parenthesis, "expected ')' after tuple bindings");
    try self.expect(.equal, "tuple destructuring requires an initializer");
    const initializer = try self.parseExpression(false);
    try self.expectStatementTerminator();
    return .{ .variable_declaration = .{
        .position = position,
        .name_position = bindings.items[0].position,
        .name = "",
        .mutable = mutable,
        .annotation = null,
        .initializer = initializer,
        .destructuring = try bindings.toOwnedSlice(self.allocator),
    } };
}

fn nameFollows(self: anytype) !bool {
    if (self.current.tag != .identifier) return false;
    var lexer = self.lexer;
    return (try lexer.next()).tag == .colon;
}

fn internPlaceholder(
    self: anytype,
    position: Source.Position,
    named: bool,
    elements: []const Ast.Expression.TupleLiteral.Element,
) !Ast.Type {
    const name = try std.fmt.allocPrint(self.allocator, "$tuple.literal.{d}.{d}", .{ position.file, self.tuple_literal_count });
    self.tuple_literal_count += 1;
    const fields = try self.allocator.alloc(Ast.StructureField, elements.len);
    for (elements, 0..) |element, index| fields[index] = .{
        .position = element.position,
        .name_position = element.position,
        .name = element.name orelse try std.fmt.allocPrint(self.allocator, "{d}", .{index}),
        .mutable = false,
        .type = .void,
        .default = null,
    };
    const type_value = try self.internTypeName(name);
    try self.nested_structures.append(self.allocator, .{
        .position = position,
        .name_position = position,
        .name = name,
        .fields = fields,
        .is_tuple = true,
        .tuple_named = named,
        .tuple_placeholder = true,
    });
    return type_value;
}

pub fn internReflectionPlaceholder(self: anytype, position: Source.Position) !Ast.Type {
    const name = try std.fmt.allocPrint(
        self.allocator,
        "$reflection.literal.{d}.{d}",
        .{ position.file, self.tuple_literal_count },
    );
    self.tuple_literal_count += 1;
    const type_value = try self.internTypeName(name);
    try self.nested_structures.append(self.allocator, .{
        .position = position,
        .name_position = position,
        .name = name,
        .fields = &.{},
        .is_tuple = true,
        .tuple_named = true,
        .tuple_placeholder = true,
    });
    return type_value;
}

fn internType(self: anytype, position: Source.Position, named: bool, fields: []const Ast.StructureField) !Ast.Type {
    var name = try self.allocator.dupe(u8, "(");
    for (fields, 0..) |field, index| {
        name = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}{s}{s}", .{
            name,
            if (index == 0) "" else ", ",
            if (named) try std.fmt.allocPrint(self.allocator, "{s}:", .{field.name}) else "",
            switch (field.access_mode) {
                .value => "",
                .read => "@",
                .mutable => "&",
            },
            typeName(self, field.type),
        });
    }
    name = try std.fmt.allocPrint(self.allocator, "{s})", .{name});
    for (self.type_names.items, 0..) |existing, index| if (std.mem.eql(u8, existing, name)) return .structure(index);
    const result = try self.internTypeName(name);
    try self.nested_structures.append(self.allocator, .{
        .position = position,
        .name_position = position,
        .name = name,
        .fields = fields,
        .is_tuple = true,
        .tuple_named = named,
    });
    return result;
}

fn typeName(self: anytype, type_value: Ast.Type) []const u8 {
    if (type_value.optionalChild()) |child| return std.fmt.allocPrint(self.allocator, "{s}?", .{typeName(self, child)}) catch "optional";
    if (type_value.structureIndex()) |index| if (index < self.type_names.items.len) return self.type_names.items[index];
    return type_value.name();
}
