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
    return self.newExpression(.{ .position = position, .value = .{ .sequence_literal = try values.toOwnedSlice(self.allocator) } });
}

pub fn internFixedType(self: anytype, position: Source.Position, element: Ast.Type, length: usize) !Ast.Type {
    for (self.collection_structures.items) |structure| if (structure.collection) |collection| {
        if (collection.element == element and collection.length == length) return self.internTypeName(structure.name);
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
        .position = position,
        .name_position = position,
        .name = name,
        .fields = fields,
        .collection = .{ .element = element, .length = length },
    });
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
