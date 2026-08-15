const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Optionals = @import("Optionals.zig");
const Borrowing = @import("Borrowing.zig");
const Resources = @import("Resources.zig");
const Support = @import("Support.zig");

pub fn analyzeLiteral(
    self: anytype,
    builder: anytype,
    literal: Ast.Expression.TupleLiteral,
    expected: ?Ast.Type,
    position: @import("../Source.zig").Position,
) !Model.TypedValue {
    const target_index = if (expected) |target| target: {
        const index = target.structureIndex() orelse return self.fail(position, "tuple expression requires a tuple type");
        if (index >= self.structures.len or !self.structures[index].is_tuple) {
            return self.fail(position, "tuple expression requires a tuple type");
        }
        break :target index;
    } else literal.placeholder_type.structureIndex().?;

    var target = self.structures[target_index];
    if (target.fields.len != literal.elements.len) {
        const message = try std.fmt.allocPrint(self.allocator, "tuple expects {d} elements, found {d}", .{ target.fields.len, literal.elements.len });
        return self.fail(position, message);
    }
    if (expected != null and target.tuple_named != literal.named) {
        return self.fail(position, if (target.tuple_named)
            "named tuple expression must repeat the declared element names"
        else
            "positional tuple expression cannot provide element names");
    }

    var values: std.ArrayList(Ir.ValueId) = .empty;
    var inferred_fields: std.ArrayList(Ir.StructureField) = .empty;
    var lexical_captures = false;
    var lexical_borrows: std.ArrayList(Model.LexicalBorrow) = .empty;
    for (literal.elements, 0..) |element, index| {
        if (expected != null and target.tuple_named and !std.mem.eql(u8, target.fields[index].name, element.name.?)) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "tuple element {d} expects name '{s}', found '{s}'",
                .{ index + 1, target.fields[index].name, element.name.? },
            );
            return self.fail(element.position, message);
        }
        var value = try self.analyzeExpressionExpected(
            builder,
            element.value,
            if (expected != null) Optionals.expectedContext(target.fields[index].type, element.value) else null,
        );
        if (expected != null and value.type != target.fields[index].type and self.canImplicitlyConvert(value.type, target.fields[index].type)) {
            value = try self.coerce(builder, value, target.fields[index].type, element.value.position);
        }
        if (expected != null and value.type != target.fields[index].type) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "tuple element {d} expects '{s}', found '{s}'",
                .{ index + 1, self.typeName(target.fields[index].type), self.typeName(value.type) },
            );
            return self.fail(element.value.position, message);
        }
        try Borrowing.requireOwned(self, value, element.value.position, "stored in a tuple");
        try values.append(self.allocator, value.value);
        lexical_captures = lexical_captures or value.lexical_captures;
        try lexical_borrows.appendSlice(self.allocator, value.lexical_borrows);
        if (expected == null) try inferred_fields.append(self.allocator, .{
            .name = element.name orelse target.fields[index].name,
            .type = value.type,
            .mutable = false,
        });
    }

    if (expected == null) {
        const fields = try inferred_fields.toOwnedSlice(self.allocator);
        @constCast(&self.structures[target_index]).fields = fields;
        @constCast(&self.structures[target_index]).name = try tupleName(self, literal.named, fields);
        target = self.structures[target_index];
    } else if (literal.placeholder_type.structureIndex()) |placeholder| {
        @constCast(&self.structures[placeholder]).fields = target.fields;
        @constCast(&self.structures[placeholder]).name = target.name;
    }
    const result_type = if (expected) |value| value else literal.placeholder_type;
    const result = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .structure_init = .{
        .result = result,
        .structure = result_type.structureIndex().?,
        .fields = try values.toOwnedSlice(self.allocator),
    } });
    return .{ .type = result_type, .value = result, .lexical_captures = lexical_captures, .lexical_borrows = try lexical_borrows.toOwnedSlice(self.allocator) };
}

fn tupleName(self: anytype, named: bool, fields: []const Ir.StructureField) ![]const u8 {
    var result = try self.allocator.dupe(u8, "(");
    for (fields, 0..) |field, index| result = try std.fmt.allocPrint(self.allocator, "{s}{s}{s}{s}", .{
        result,
        if (index == 0) "" else ", ",
        if (named) try std.fmt.allocPrint(self.allocator, "{s}:", .{field.name}) else "",
        self.typeName(field.type),
    });
    return std.fmt.allocPrint(self.allocator, "{s})", .{result});
}

pub fn analyzeDestructuring(self: anytype, builder: anytype, declaration: Ast.VariableDeclaration) !void {
    const initializer = try self.analyzeExpression(builder, declaration.initializer.?);
    const tuple_index = initializer.type.structureIndex() orelse return self.fail(
        declaration.name_position,
        "tuple destructuring requires a tuple value",
    );
    if (tuple_index >= self.structures.len or !self.structures[tuple_index].is_tuple) {
        return self.fail(declaration.name_position, "tuple destructuring requires a tuple value");
    }
    const tuple = self.structures[tuple_index];
    if (tuple.fields.len != declaration.destructuring.len) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "tuple destructuring expects {d} bindings, found {d}",
            .{ tuple.fields.len, declaration.destructuring.len },
        );
        return self.fail(declaration.name_position, message);
    }
    try Borrowing.requireOwned(self, initializer, declaration.initializer.?.position, "destructured");
    for (declaration.destructuring, 0..) |binding, index| {
        if (Support.findBinding(builder.bindings.items, binding.name) != null) {
            const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{binding.name});
            return self.fail(binding.position, message);
        }
        const field = tuple.fields[index];
        if (!declaration.mutable and Resources.containsClass(self, field.type)) {
            return self.fail(binding.position, "a binding that can reach a class reference must use 'var'");
        }
        const value = try self.newValue(builder, field.type);
        try self.emit(builder, .{ .field_load = .{ .result = value, .base = initializer.value, .field = index } });
        if (declaration.mutable) {
            const local = builder.local_types.items.len;
            try builder.local_types.append(self.allocator, field.type);
            try self.emit(builder, .{ .local_store = .{ .local = local, .operand = value } });
            try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = field.type, .local = local, .mutable = true });
        } else try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = field.type, .value = value });
    }
}
