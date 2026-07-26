const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Optionals = @import("Optionals.zig");
const Model = @import("Model.zig");

pub fn analyzeLiteral(
    self: anytype,
    builder: anytype,
    literal: Ast.Expression.SequenceLiteral,
    expected: ?Ast.Type,
    position: @import("../Source.zig").Position,
) !Model.TypedValue {
    const type_value = expected orelse literal.inferred_type orelse return self.fail(position, "empty or non-fundamental list literal requires an expected collection type");
    const structure_index = type_value.structureIndex() orelse return self.fail(position, "collection literal requires an expected collection type");
    if (structure_index >= self.structures.len) return error.InvalidSource;
    const collection = self.structures[structure_index].collection orelse return self.fail(position, "collection literal requires an expected collection type");
    if (collection.length) |length| if (literal.values.len != length) {
        const message = try std.fmt.allocPrint(self.allocator, "array literal expects {d} values, found {d}", .{ length, literal.values.len });
        return self.fail(position, message);
    };
    const fields = try self.allocator.alloc(Ir.ValueId, literal.values.len);
    for (literal.values, 0..) |expression, index| {
        var value = try self.analyzeExpressionExpected(builder, expression, collection.element);
        if (value.type != collection.element and (Numeric.canWiden(value.type, collection.element) or Optionals.canConvert(value.type, collection.element))) {
            value = try self.coerce(builder, value, collection.element, expression.position);
        }
        if (value.type != collection.element) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "array element {d} expects '{s}', found '{s}'",
                .{ index + 1, self.typeName(collection.element), self.typeName(value.type) },
            );
            return self.fail(expression.position, message);
        }
        fields[index] = value.value;
    }
    const result = try self.newValue(builder, type_value);
    if (collection.length == null)
        try self.emit(builder, .{ .list_init = .{ .result = result, .values = fields } })
    else
        try self.emit(builder, .{ .structure_init = .{ .result = result, .structure = structure_index, .fields = fields } });
    return .{ .type = type_value, .value = result };
}

pub fn analyzeIndex(self: anytype, builder: anytype, access: Ast.Expression.IndexAccess) !Model.TypedValue {
    const source = try self.analyzeExpression(builder, access.base);
    const collection = collectionForType(self.structures, source.type) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "indexing requires an array, found '{s}'", .{self.typeName(source.type)});
        return self.fail(access.bracket_position, message);
    };
    const index = try self.analyzeExpression(builder, access.index);
    if (index.type != .int) {
        const message = try std.fmt.allocPrint(self.allocator, "collection index expects 'int', found '{s}'", .{self.typeName(index.type)});
        return self.fail(access.index.position, message);
    }
    const result = try self.newValue(builder, collection.element);
    try self.emit(builder, .{ .collection_load = .{
        .result = result,
        .collection = source.value,
        .index = index.value,
        .position = access.bracket_position,
    } });
    return .{ .type = collection.element, .value = result };
}

pub fn analyzeCall(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    const receiver_expression = call.receiver orelse return null;
    const receiver_type = inferReceiverType(builder, receiver_expression) orelse return null;
    const collection = collectionForType(self.structures, receiver_type) orelse return null;
    if (call.safe or call.arguments.len != 0 or call.named_arguments.len != 0 or call.type_arguments.len != 0) return null;
    const source = try self.analyzeExpression(builder, receiver_expression);
    if (std.mem.eql(u8, call.name, "count")) {
        const result = try self.newValue(builder, .int);
        if (collection.length) |count|
            try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = count } })
        else
            try self.emit(builder, .{ .collection_count = .{ .result = result, .collection = source.value } });
        return .{ .type = .int, .value = result };
    }
    if (std.mem.eql(u8, call.name, "is_empty")) {
        const count_value = try self.newValue(builder, .int);
        if (collection.length) |count|
            try self.emit(builder, .{ .constant_int = .{ .result = count_value, .bits = count } })
        else
            try self.emit(builder, .{ .collection_count = .{ .result = count_value, .collection = source.value } });
        const zero = try self.newValue(builder, .int);
        try self.emit(builder, .{ .constant_int = .{ .result = zero, .bits = 0 } });
        const result = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .binary = .{ .result = result, .operator = .equal, .left = count_value, .right = zero } });
        return .{ .type = .bool, .value = result };
    }
    return null;
}

pub fn collectionForType(structures: []const Ir.Structure, type_value: Ast.Type) ?Ast.Collection {
    const index = type_value.structureIndex() orelse return null;
    if (index >= structures.len) return null;
    return structures[index].collection;
}

fn inferReceiverType(builder: anytype, expression: *const Ast.Expression) ?Ast.Type {
    return switch (expression.value) {
        .identifier => |name| if (@import("Support.zig").findBinding(builder.bindings.items, name)) |binding| binding.type else null,
        .sequence_literal => |literal| literal.inferred_type,
        .call => |call| call.result_type,
        else => null,
    };
}
