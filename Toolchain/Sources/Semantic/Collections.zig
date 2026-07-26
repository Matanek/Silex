const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Optionals = @import("Optionals.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");

pub fn isMutation(name: []const u8) bool {
    return std.mem.eql(u8, name, "swap") or std.mem.eql(u8, name, "reverse") or std.mem.eql(u8, name, "replace") or
        std.mem.eql(u8, name, "append") or std.mem.eql(u8, name, "prepend") or std.mem.eql(u8, name, "insert") or
        std.mem.eql(u8, name, "take") or std.mem.eql(u8, name, "take_first") or std.mem.eql(u8, name, "take_last") or
        std.mem.eql(u8, name, "clear");
}

pub fn receiverIsCollection(structures: []const Ir.Structure, builder: anytype, expression: *const Ast.Expression) bool {
    const name = switch (expression.value) {
        .identifier => |value| value,
        else => return false,
    };
    const binding = Support.findBinding(builder.bindings.items, name) orelse return false;
    return collectionForType(structures, binding.type) != null;
}

pub fn analyzeMutation(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    if (call.safe or call.named_arguments.len != 0 or call.type_arguments.len != 0) return self.fail(call.name_position, "collection mutations use positional arguments");
    const receiver_expression = call.receiver.?;
    const name = switch (receiver_expression.value) {
        .identifier => |value| value,
        else => return self.fail(receiver_expression.position, "collection mutation requires a var receiver"),
    };
    const binding = Support.findBinding(builder.bindings.items, name) orelse return self.fail(receiver_expression.position, "unknown collection variable");
    if (!binding.mutable or binding.local == null) return self.fail(receiver_expression.position, "collection mutation requires a var receiver");
    const collection = collectionForType(self.structures, binding.type) orelse return self.fail(receiver_expression.position, "collection mutation requires an array or list");
    const source = try self.analyzeExpression(builder, receiver_expression);

    if (std.mem.eql(u8, call.name, "replace")) {
        try requireArity(self, call, 2);
        const index = try requireIndex(self, builder, call.arguments[0]);
        const replacement = try self.analyzeExpressionExpected(builder, call.arguments[1], collection.element);
        const previous = try self.newValue(builder, collection.element);
        try self.emit(builder, .{ .collection_load = .{ .result = previous, .collection = source.value, .index = index.value, .position = call.name_position } });
        const updated = try self.newValue(builder, binding.type);
        try self.emit(builder, .{ .collection_replace = .{ .result = updated, .collection = source.value, .index = index.value, .replacement = replacement.value, .position = call.name_position } });
        try self.emit(builder, .{ .local_store = .{ .local = binding.local.?, .operand = updated } });
        return .{ .type = collection.element, .value = previous };
    }
    if (std.mem.eql(u8, call.name, "swap")) {
        try requireArity(self, call, 2);
        const left_index = try requireIndex(self, builder, call.arguments[0]);
        const right_index = try requireIndex(self, builder, call.arguments[1]);
        const left = try self.newValue(builder, collection.element);
        const right = try self.newValue(builder, collection.element);
        try self.emit(builder, .{ .collection_load = .{ .result = left, .collection = source.value, .index = left_index.value, .position = call.name_position } });
        try self.emit(builder, .{ .collection_load = .{ .result = right, .collection = source.value, .index = right_index.value, .position = call.name_position } });
        const first = try self.newValue(builder, binding.type);
        const updated = try self.newValue(builder, binding.type);
        try self.emit(builder, .{ .collection_replace = .{ .result = first, .collection = source.value, .index = left_index.value, .replacement = right, .position = call.name_position } });
        try self.emit(builder, .{ .collection_replace = .{ .result = updated, .collection = first, .index = right_index.value, .replacement = left, .position = call.name_position } });
        try self.emit(builder, .{ .local_store = .{ .local = binding.local.?, .operand = updated } });
        return .{ .type = binding.type, .value = updated };
    }
    if (collection.length != null and std.mem.eql(u8, call.name, "reverse")) {
        try requireArity(self, call, 0);
        var updated = source.value;
        for (0..collection.length.? / 2) |left_index| {
            const right_index = collection.length.? - 1 - left_index;
            const left_constant = try constantIndex(self, builder, left_index);
            const right_constant = try constantIndex(self, builder, right_index);
            const left = try self.newValue(builder, collection.element);
            const right = try self.newValue(builder, collection.element);
            try self.emit(builder, .{ .collection_load = .{ .result = left, .collection = updated, .index = left_constant, .position = call.name_position } });
            try self.emit(builder, .{ .collection_load = .{ .result = right, .collection = updated, .index = right_constant, .position = call.name_position } });
            const first = try self.newValue(builder, binding.type);
            const next = try self.newValue(builder, binding.type);
            try self.emit(builder, .{ .collection_replace = .{ .result = first, .collection = updated, .index = left_constant, .replacement = right, .position = call.name_position } });
            try self.emit(builder, .{ .collection_replace = .{ .result = next, .collection = first, .index = right_constant, .replacement = left, .position = call.name_position } });
            updated = next;
        }
        try self.emit(builder, .{ .local_store = .{ .local = binding.local.?, .operand = updated } });
        return .{ .type = binding.type, .value = updated };
    }
    if (collection.length != null) return self.fail(call.name_position, "fixed arrays only support swap, reverse, and replace");

    var kind: Ir.Instruction.ListEditKind = undefined;
    var index: ?Ir.ValueId = null;
    var argument: ?Ir.ValueId = null;
    var removed: ?Ir.ValueId = null;
    var return_type = binding.type;
    if (std.mem.eql(u8, call.name, "reverse")) {
        try requireArity(self, call, 0);
        kind = .reverse;
    } else if (std.mem.eql(u8, call.name, "clear")) {
        try requireArity(self, call, 0);
        kind = .clear;
    } else if (std.mem.eql(u8, call.name, "append")) {
        try requireArity(self, call, 1);
        const value = try self.analyzeExpression(builder, call.arguments[0]);
        if (value.type == collection.element) {
            kind = .append;
            argument = value.value;
        } else if (collectionForType(self.structures, value.type)) |other| {
            if (other.element != collection.element) return self.fail(call.arguments[0].position, "append sequence element type is incompatible");
            kind = .append_sequence;
            argument = value.value;
        } else return self.fail(call.arguments[0].position, "append expects an element or compatible sequence");
    } else if (std.mem.eql(u8, call.name, "prepend")) {
        try requireArity(self, call, 1);
        kind = .prepend;
        argument = (try self.analyzeExpressionExpected(builder, call.arguments[0], collection.element)).value;
    } else if (std.mem.eql(u8, call.name, "insert")) {
        try requireArity(self, call, 2);
        kind = .insert;
        index = (try requireIndex(self, builder, call.arguments[0])).value;
        argument = (try self.analyzeExpressionExpected(builder, call.arguments[1], collection.element)).value;
    } else {
        return_type = collection.element;
        removed = try self.newValue(builder, collection.element);
        if (std.mem.eql(u8, call.name, "take")) {
            try requireArity(self, call, 1);
            kind = .take;
            index = (try requireIndex(self, builder, call.arguments[0])).value;
        } else if (std.mem.eql(u8, call.name, "take_first")) {
            try requireArity(self, call, 0);
            kind = .take_first;
        } else {
            try requireArity(self, call, 0);
            kind = .take_last;
        }
    }
    const updated = try self.newValue(builder, binding.type);
    try self.emit(builder, .{ .list_edit = .{ .result = updated, .collection = source.value, .kind = kind, .index = index, .argument = argument, .removed = removed, .position = call.name_position } });
    try self.emit(builder, .{ .local_store = .{ .local = binding.local.?, .operand = updated } });
    return .{ .type = return_type, .value = removed orelse updated };
}

fn requireArity(self: anytype, call: Ast.Expression.Call, expected: usize) !void {
    if (call.arguments.len == expected) return;
    const message = try std.fmt.allocPrint(self.allocator, "collection operation '{s}' expects {d} arguments, found {d}", .{ call.name, expected, call.arguments.len });
    return self.fail(call.name_position, message);
}

fn requireIndex(self: anytype, builder: anytype, expression: *const Ast.Expression) !Model.TypedValue {
    const value = try self.analyzeExpression(builder, expression);
    if (value.type != .int) return self.fail(expression.position, "collection index expects 'int'");
    return value;
}

fn constantIndex(self: anytype, builder: anytype, value: usize) !Ir.ValueId {
    const result = try self.newValue(builder, .int);
    try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = value } });
    return result;
}

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

pub fn analyzeSlice(self: anytype, builder: anytype, access: Ast.Expression.SliceAccess, expected: ?Ast.Type) !Model.TypedValue {
    const source = try self.analyzeExpression(builder, access.base);
    const collection = collectionForType(self.structures, source.type) orelse return self.fail(access.bracket_position, "slicing requires an array or list");
    const start = try requireIndex(self, builder, access.start);
    const end = try requireIndex(self, builder, access.end);
    var result_type: ?Ast.Type = null;
    if (expected) |type_value| if (collectionForType(self.structures, type_value)) |target| {
        if (target.length == null and target.element == collection.element) result_type = type_value;
    };
    if (result_type == null and collection.length == null) result_type = source.type;
    if (result_type == null) for (self.structures, 0..) |structure, index| if (structure.collection) |candidate| {
        if (candidate.length == null and candidate.element == collection.element) {
            result_type = .structure(index);
            break;
        }
    };
    const target = result_type orelse return self.fail(access.bracket_position, "a fixed-array slice requires an expected dynamic list type");
    const result = try self.newValue(builder, target);
    try self.emit(builder, .{ .collection_slice = .{ .result = result, .collection = source.value, .start = start.value, .end = end.value } });
    return .{ .type = target, .value = result };
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
