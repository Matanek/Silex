const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

pub fn internNamedType(self: anytype, name: []const u8) !Ast.Type {
    for (self.type_names.items, 0..) |existing, index| {
        if (std.mem.eql(u8, existing, name)) return .structure(index);
    }
    const index = self.type_names.items.len;
    try self.type_names.append(self.allocator, name);
    return .structure(index);
}

pub fn internGenericType(self: anytype, position: Source.Position, base: Ast.Type, arguments: []const Ast.Type) !Ast.Type {
    for (self.generic_types.items, 0..) |existing, index| {
        if (existing.base == base and std.mem.eql(Ast.Type, existing.arguments, arguments)) return .genericInstantiation(index);
    }
    const index = self.generic_types.items.len;
    try self.generic_types.append(self.allocator, .{ .position = position, .base = base, .arguments = arguments });
    return .genericInstantiation(index);
}

pub fn parseLiteral(self: anytype, position: Source.Position) !*Ast.Expression {
    try self.advance();
    var values: std.ArrayList(*Ast.Expression) = .empty;
    if (self.current.tag != .right_bracket) while (true) {
        try values.append(self.allocator, try self.parseExpression(true));
        if (self.current.tag != .comma) break;
        try self.advance();
        if (self.current.tag == .right_bracket) break;
    };
    try self.expect(.right_bracket, "expected ']' after array literal");
    const items = try values.toOwnedSlice(self.allocator);
    const inferred_type = if (items.len == 0) null else if (syntacticType(items[0])) |element|
        try internDynamicType(self, position, element)
    else
        null;
    return self.newExpression(.{ .position = position, .value = .{ .sequence_literal = .{ .values = items, .inferred_type = inferred_type } } });
}

pub fn parsePostfix(self: anytype, base: *Ast.Expression, position: Source.Position) !*Ast.Expression {
    try self.advance();
    if (self.current.tag == .right_bracket or self.current.tag == .colon) return self.fail("slice and index bounds cannot be omitted");
    const first = try self.parseExpression(true);
    if (self.current.tag != .colon) {
        try self.expect(.right_bracket, "expected ']' after collection index");
        return self.newExpression(.{ .position = base.position, .value = .{ .index_access = .{ .base = base, .index = first, .bracket_position = position } } });
    }
    try self.advance();
    if (self.current.tag == .right_bracket) return self.fail("slice end cannot be omitted");
    const end = try self.parseExpression(true);
    try self.expect(.right_bracket, "expected ']' after slice end");
    return self.newExpression(.{ .position = base.position, .value = .{ .slice_access = .{ .base = base, .start = first, .end = end, .bracket_position = position } } });
}

fn syntacticType(expression: *const Ast.Expression) ?Ast.Type {
    return switch (expression.value) {
        .integer => .int,
        .floating => .float64,
        .boolean => .bool,
        .string, .interpolated_string => .str,
        .sequence_literal => |literal| literal.inferred_type,
        else => null,
    };
}

pub fn internDynamicType(self: anytype, position: Source.Position, element: Ast.Type) !Ast.Type {
    for (self.collection_structures.items) |*structure| if (structure.collection) |collection| {
        if (collection.element == element and collection.length == null and !collection.view) {
            if (self.test_prefix == null) structure.is_test = false;
            return self.internTypeName(structure.name);
        }
    };
    const name = try std.fmt.allocPrint(self.allocator, "{s}[]", .{try typeSpelling(self, element)});
    const type_value = try self.internTypeName(name);
    try self.collection_structures.append(self.allocator, .{
        .is_test = self.test_prefix != null,
        .is_public = true,
        .position = position,
        .name_position = position,
        .name = name,
        .fields = &.{},
        .collection = .{ .element = element, .length = null },
    });
    _ = try internViewType(self, position, element);
    return type_value;
}

pub fn internViewType(self: anytype, position: Source.Position, element: Ast.Type) !Ast.Type {
    for (self.collection_structures.items) |*structure| if (structure.collection) |collection| {
        if (collection.element == element and collection.view) {
            if (self.test_prefix == null) structure.is_test = false;
            return self.internTypeName(structure.name);
        }
    };
    const name = try std.fmt.allocPrint(self.allocator, "{s}[..]", .{try typeSpelling(self, element)});
    const type_value = try self.internTypeName(name);
    try self.collection_structures.append(self.allocator, .{
        .is_test = self.test_prefix != null,
        .is_public = true,
        .position = position,
        .name_position = position,
        .name = name,
        .fields = &.{},
        .collection = .{ .element = element, .length = null, .view = true },
    });
    return type_value;
}

pub fn internFixedType(self: anytype, position: Source.Position, element: Ast.Type, length: usize) !Ast.Type {
    for (self.collection_structures.items) |*structure| if (structure.collection) |collection| {
        if (collection.element == element and collection.length == length) {
            if (self.test_prefix == null) structure.is_test = false;
            return self.internTypeName(structure.name);
        }
    };
    const name = try std.fmt.allocPrint(self.allocator, "{s}[{d}]", .{ try typeSpelling(self, element), length });
    const type_value = try self.internTypeName(name);
    const fields = try self.allocator.alloc(Ast.StructureField, length);
    for (fields, 0..) |*field, index| field.* = .{
        .position = position,
        .name_position = position,
        .name = try std.fmt.allocPrint(self.allocator, "{d}", .{index}),
        .mutable = true,
        .type = element,
        .default = null,
    };
    try self.collection_structures.append(self.allocator, .{
        .is_test = self.test_prefix != null,
        .is_public = true,
        .position = position,
        .name_position = position,
        .name = name,
        .fields = fields,
        .collection = .{ .element = element, .length = length },
    });
    _ = try internViewType(self, position, element);
    return type_value;
}

fn typeSpelling(self: anytype, type_value: Ast.Type) ![]const u8 {
    if (type_value.optionalChild()) |child| return std.fmt.allocPrint(self.allocator, "{s}?", .{try typeSpelling(self, child)});
    if (type_value.structureIndex()) |index| if (index < self.type_names.items.len) return self.type_names.items[index];
    if (type_value.genericParameterIndex()) |index| if (index < self.type_parameters.len) return self.type_parameters[index].name;
    if (type_value.genericInstantiationIndex()) |index| if (index < self.generic_types.items.len) {
        const generic = self.generic_types.items[index];
        var name = try self.allocator.dupe(u8, try typeSpelling(self, generic.base));
        for (generic.arguments, 0..) |argument, argument_index| name = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}{s}",
            .{ name, if (argument_index == 0) "<" else ",", try typeSpelling(self, argument) },
        );
        return std.fmt.allocPrint(self.allocator, "{s}>", .{name});
    };
    return type_value.name();
}
