const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Optionals = @import("Optionals.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");
const Borrowing = @import("Borrowing.zig");
const Resources = @import("Resources.zig");

pub fn isMutation(name: []const u8) bool {
    return std.mem.eql(u8, name, "swap") or std.mem.eql(u8, name, "reverse") or std.mem.eql(u8, name, "replace") or
        std.mem.eql(u8, name, "append") or std.mem.eql(u8, name, "prepend") or std.mem.eql(u8, name, "insert") or
        std.mem.eql(u8, name, "take") or std.mem.eql(u8, name, "take_first") or std.mem.eql(u8, name, "take_last") or
        std.mem.eql(u8, name, "clear");
}

pub fn receiverIsCollection(structures: []const Ir.Structure, builder: anytype, expression: *const Ast.Expression) bool {
    const type_value = inferReceiverType(structures, builder, expression) orelse return false;
    return collectionForType(structures, type_value) != null;
}

pub fn analyzeMutation(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    const receiver_expression = call.receiver.?;
    var source: Model.TypedValue = undefined;
    var ownership: Ir.Ownership = .root;
    const binding: Model.Binding = switch (receiver_expression.value) {
        .identifier => |name| binding: {
            const existing = findBinding(builder.bindings.items, name) orelse return self.fail(receiver_expression.position, "unknown collection variable");
            if (collectionForType(self.structures, existing.type) == null) return null;
            if (existing.borrowed_root == null) try @import("Borrowing.zig").ensureRootUnborrowed(self, builder, name, receiver_expression.position);
            if (!existing.mutable or (existing.local == null and existing.reference == null)) return self.fail(receiver_expression.position, "collection mutation requires a var receiver");
            source = try self.analyzeExpression(builder, receiver_expression);
            break :binding existing;
        },
        .field_access => binding: {
            source = try self.analyzeExpression(builder, receiver_expression);
            if (collectionForType(self.structures, source.type) == null) return null;
            const access = receiver_expression.value.field_access;
            if (inferReceiverType(self.structures, builder, access.base)) |base_type| {
                if (base_type.structureIndex()) |base_index| {
                    if (self.structures[base_index].is_class) ownership = .edge;
                }
            }
            var reference = source.reference;
            if (reference == null) {
                if (access.base.value == .identifier) {
                    const root = findBinding(builder.bindings.items, access.base.value.identifier) orelse
                        return self.fail(receiver_expression.position, "collection mutation requires a mutable field receiver");
                    if (!root.mutable or (root.local == null and root.reference == null)) {
                        return self.fail(receiver_expression.position, "collection mutation requires a mutable field receiver");
                    }
                    const structure_index = root.type.structureIndex() orelse
                        return self.fail(receiver_expression.position, "collection mutation requires a mutable field receiver");
                    var field_index: ?usize = null;
                    for (self.structures[structure_index].fields, 0..) |field, index| if (std.mem.eql(u8, field.name, access.name)) {
                        if (!field.mutable) return self.fail(access.name_position, "collection mutation requires a mutable field receiver");
                        field_index = index;
                        break;
                    };
                    const root_reference = if (root.reference) |existing|
                        existing
                    else root_reference: {
                        const created = try self.newValue(builder, .address);
                        try self.emit(builder, .{ .local_address = .{ .result = created, .local = root.local.? } });
                        break :root_reference created;
                    };
                    reference = try self.newValue(builder, .address);
                    try self.emit(builder, .{ .reference_field = .{
                        .result = reference.?,
                        .reference = root_reference,
                        .structure = structure_index,
                        .field = field_index orelse return self.fail(access.name_position, "unknown structure field"),
                    } });
                }
            }
            const stable_reference = reference orelse return self.fail(receiver_expression.position, "collection mutation requires a mutable field receiver");
            break :binding .{ .name = "<field>", .type = source.type, .reference = stable_reference, .mutable = true };
        },
        else => return null,
    };
    const collection = collectionForType(self.structures, binding.type) orelse return self.fail(receiver_expression.position, "collection mutation requires an array or list");
    if (call.safe or call.named_arguments.len != 0 or call.type_arguments.len != 0) return self.fail(call.name_position, "collection mutations use positional arguments");
    if (collection.view and binding.borrowed_mode != .mutable and binding.parameter_mode != .mutable) {
        return self.fail(receiver_expression.position, "a shared view cannot be mutated");
    }
    if (collection.view and !std.mem.eql(u8, call.name, "swap")) {
        return self.fail(call.name_position, "views only support in-place 'swap'; resizing, extraction, replacement, and global reordering are unavailable");
    }
    if (std.mem.eql(u8, call.name, "replace")) {
        try requireArity(self, call, 2);
        const index = try requireIndex(self, builder, call.arguments[0]);
        const replacement = try self.analyzeExpressionExpected(builder, call.arguments[1], collection.element);
        if (Resources.requiresRetain(self, collection.element)) try Resources.retainValueOwned(self, builder, collection.element, replacement.value, ownership);
        const previous = try self.newValue(builder, collection.element);
        try self.emit(builder, .{ .collection_load = .{ .result = previous, .collection = source.value, .index = index.value, .position = call.name_position } });
        const updated = try self.newValue(builder, binding.type);
        try self.emit(builder, .{ .collection_replace = .{ .result = updated, .collection = source.value, .index = index.value, .replacement = replacement.value, .ownership = ownership, .position = call.name_position } });
        try storeBinding(self, builder, binding, updated);
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
        try self.emit(builder, .{ .collection_replace = .{ .result = first, .collection = source.value, .index = left_index.value, .replacement = right, .ownership = ownership, .position = call.name_position } });
        try self.emit(builder, .{ .collection_replace = .{ .result = updated, .collection = first, .index = right_index.value, .replacement = left, .ownership = ownership, .position = call.name_position } });
        try storeBinding(self, builder, binding, updated);
        return null;
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
            try self.emit(builder, .{ .collection_replace = .{ .result = first, .collection = updated, .index = left_constant, .replacement = right, .ownership = ownership, .position = call.name_position } });
            try self.emit(builder, .{ .collection_replace = .{ .result = next, .collection = first, .index = right_constant, .replacement = left, .ownership = ownership, .position = call.name_position } });
            updated = next;
        }
        try storeBinding(self, builder, binding, updated);
        return null;
    }
    if (collection.length != null or collection.view) return self.fail(call.name_position, "fixed arrays only support swap, reverse, and replace");

    var kind: Ir.Instruction.ListEditKind = undefined;
    var index: ?Ir.ValueId = null;
    var argument: ?Ir.ValueId = null;
    var argument_type: ?Ast.Type = null;
    var argument_transferred = false;
    var removed: ?Ir.ValueId = null;
    var return_type = binding.type;
    if (std.mem.eql(u8, call.name, "reverse")) {
        try requireArity(self, call, 0);
        kind = .reverse;
    } else if (std.mem.eql(u8, call.name, "clear")) {
        try requireArity(self, call, 0);
        if (Resources.needsDrop(self, binding.type) or Resources.containsClass(self, binding.type)) {
            try Resources.emitCollectionElementsDropOwned(self, builder, binding.type, source.value, ownership);
        }
        kind = .clear;
    } else if (std.mem.eql(u8, call.name, "append")) {
        try requireArity(self, call, 1);
        const value = try self.analyzeExpression(builder, call.arguments[0]);
        if (value.type == collection.element) {
            kind = .append;
            argument = value.value;
            argument_type = collection.element;
        } else if (self.canImplicitlyConvert(value.type, collection.element)) {
            const converted = try self.coerce(builder, value, collection.element, call.arguments[0].position);
            kind = .append;
            argument = converted.value;
            argument_type = collection.element;
        } else if (collectionForType(self.structures, value.type)) |other| {
            if (other.element != collection.element) return self.fail(call.arguments[0].position, "append sequence element type is incompatible");
            kind = .append_sequence;
            argument = value.value;
            argument_type = value.type;
            argument_transferred = value.transferred;
        } else return self.fail(call.arguments[0].position, "append expects an element or compatible sequence");
    } else if (std.mem.eql(u8, call.name, "prepend")) {
        try requireArity(self, call, 1);
        kind = .prepend;
        argument = (try self.analyzeExpressionExpected(builder, call.arguments[0], collection.element)).value;
        argument_type = collection.element;
    } else if (std.mem.eql(u8, call.name, "insert")) {
        try requireArity(self, call, 2);
        kind = .insert;
        index = (try requireIndex(self, builder, call.arguments[0])).value;
        argument = (try self.analyzeExpressionExpected(builder, call.arguments[1], collection.element)).value;
        argument_type = collection.element;
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
    if (argument) |value| if (Resources.requiresRetain(self, argument_type.?)) {
        try Resources.retainValueOwned(self, builder, argument_type.?, value, ownership);
    };
    const updated = try self.newValue(builder, binding.type);
    try self.emit(builder, .{ .list_edit = .{ .result = updated, .collection = source.value, .ownership = ownership, .kind = kind, .index = index, .argument = argument, .argument_transferred = argument_transferred, .removed = removed, .position = call.name_position } });
    try storeBinding(self, builder, binding, updated);
    if (kind != .append and kind != .clear) try self.emit(builder, .{ .list_drop = .{
        .operand = source.value,
        .ownership = ownership,
        .deallocate = true,
    } });
    if (removed) |value| {
        if (ownership == .edge and Resources.requiresRetain(self, return_type)) {
            try Resources.retainValue(self, builder, return_type, value);
            try Resources.emitDropOwned(self, builder, return_type, value, .edge);
        }
        return .{ .type = return_type, .value = value, .transferred = Resources.ownsValue(self, return_type) };
    }
    return null;
}

fn storeBinding(self: anytype, builder: anytype, binding: anytype, value: Ir.ValueId) !void {
    if (binding.local) |local| return self.emit(builder, .{ .local_store = .{ .local = local, .operand = value } });
    return self.emit(builder, .{ .reference_store = .{ .reference = binding.reference.?, .operand = value } });
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
    if (collection.view) return self.fail(position, "a view cannot own a collection literal");
    if (collection.length) |length| if (literal.values.len != length) {
        const message = try std.fmt.allocPrint(self.allocator, "array literal expects {d} values, found {d}", .{ length, literal.values.len });
        return self.fail(position, message);
    };
    const fields = try self.allocator.alloc(Ir.ValueId, literal.values.len);
    var lexical_captures = false;
    var lexical_borrows: std.ArrayList(Model.LexicalBorrow) = .empty;
    for (literal.values, 0..) |expression, index| {
        var value = try self.analyzeExpressionExpected(builder, expression, collection.element);
        if (value.type != collection.element and self.canImplicitlyConvert(value.type, collection.element)) {
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
        try Borrowing.requireOwned(self, value, expression.position, "stored in a collection");
        if (Resources.requiresRetain(self, collection.element) and !value.transferred) {
            try Resources.retainValue(self, builder, collection.element, value.value);
        }
        fields[index] = value.value;
        lexical_captures = lexical_captures or value.lexical_captures;
        try lexical_borrows.appendSlice(self.allocator, value.lexical_borrows);
    }
    const result = try self.newValue(builder, type_value);
    if (collection.length == null)
        try self.emit(builder, .{ .list_init = .{ .result = result, .values = fields } })
    else
        try self.emit(builder, .{ .structure_init = .{ .result = result, .structure = structure_index, .fields = fields } });
    return .{
        .type = type_value,
        .value = result,
        .transferred = collection.length == null,
        .lexical_captures = lexical_captures,
        .lexical_borrows = try lexical_borrows.toOwnedSlice(self.allocator),
    };
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
    const aliases_source = Resources.needsDrop(self, collection.element) or Resources.containsClass(self, collection.element);
    return .{
        .type = collection.element,
        .value = result,
        .borrowed_root = if (aliases_source) source.borrowed_root else null,
        .borrowed_mode = if (aliases_source) source.borrowed_mode else .value,
        .lexical_captures = source.lexical_captures,
        .lexical_borrows = source.lexical_borrows,
    };
}

pub fn analyzeSlice(self: anytype, builder: anytype, access: Ast.Expression.SliceAccess, expected: ?Ast.Type) !Model.TypedValue {
    const source = try self.analyzeExpression(builder, access.base);
    const collection = collectionForType(self.structures, source.type) orelse return self.fail(access.bracket_position, "slicing requires an array or list");
    const start = try requireIndex(self, builder, access.start);
    const end = try requireIndex(self, builder, access.end);
    var result_type: ?Ast.Type = null;
    if (expected) |type_value| if (collectionForType(self.structures, type_value)) |target| {
        if (target.length == null and !target.view and target.element == collection.element) result_type = type_value;
    };
    if (result_type == null and collection.length == null) result_type = source.type;
    if (result_type == null) for (self.structures, 0..) |structure, index| if (structure.collection) |candidate| {
        if (candidate.length == null and !candidate.view and candidate.element == collection.element) {
            result_type = .structure(index);
            break;
        }
    };
    const target = result_type orelse return self.fail(access.bracket_position, "a fixed-array slice requires an expected dynamic list type");
    const result = try self.newValue(builder, target);
    try self.emit(builder, .{ .collection_slice = .{ .result = result, .collection = source.value, .start = start.value, .end = end.value } });
    return .{ .type = target, .value = result, .borrowed_root = source.borrowed_root, .borrowed_mode = source.borrowed_mode };
}

pub fn analyzeView(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !Model.TypedValue {
    if (unary.operand.value == .index_access) return analyzeElementReference(self, builder, unary);
    const access = switch (unary.operand.value) {
        .slice_access => |value| value,
        else => return self.fail(unary.operator_position, "'@' and '&' expressions require a bounded collection slice"),
    };
    const source = try self.analyzeExpression(builder, access.base);
    const collection = collectionForType(self.structures, source.type) orelse return self.fail(access.bracket_position, "a borrowed view requires an array, list, or view source");
    const root = source.borrowed_root orelse @import("Borrowing.zig").rootName(access.base) orelse
        return self.fail(unary.operator_position, "a borrowed view requires a stable collection root");
    const mode: Ast.Parameter.Mode = if (unary.operator == .borrow_mutable) .mutable else .read;
    if (mode == .mutable) {
        const root_name = @import("Borrowing.zig").rootName(access.base).?;
        const binding = findBinding(builder.bindings.items, root_name) orelse return self.fail(access.base.position, "unknown collection root");
        if (!binding.mutable and binding.borrowed_mode != .mutable and binding.parameter_mode != .mutable) {
            return self.fail(access.base.position, "a mutable view requires a var collection root");
        }
        if (binding.borrowed_root == null) try @import("Borrowing.zig").ensureRootUnborrowed(self, builder, root_name, unary.operator_position);
    }
    const start = try requireIndex(self, builder, access.start);
    const end = try requireIndex(self, builder, access.end);
    const result_type = viewTypeForElement(self.structures, collection.element) orelse return self.fail(unary.operator_position, "view type is unavailable");
    const result = try self.newValue(builder, result_type);
    var reference: ?Ir.ValueId = null;
    if (mode == .mutable) {
        const binding = findBinding(builder.bindings.items, @import("Borrowing.zig").rootName(access.base).?).?;
        reference = binding.reference;
        if (reference == null and binding.local != null) {
            reference = try self.newValue(builder, .address);
            try self.emit(builder, .{ .local_address = .{ .result = reference.?, .local = binding.local.? } });
        }
    }
    try self.emit(builder, .{ .collection_view = .{
        .result = result,
        .collection = source.value,
        .start = start.value,
        .end = end.value,
        .reference = reference,
    } });
    return .{ .type = result_type, .value = result, .borrowed_root = root, .borrowed_mode = mode };
}

fn analyzeElementReference(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !Model.TypedValue {
    const access = unary.operand.value.index_access;
    const source = try self.analyzeExpression(builder, access.base);
    const collection = collectionForType(self.structures, source.type) orelse
        return self.fail(access.bracket_position, "a borrowed element requires an array, list, or view source");
    const root = source.borrowed_root orelse @import("Borrowing.zig").rootName(access.base) orelse
        return self.fail(unary.operator_position, "a borrowed element requires a stable collection root");
    const mode: Ast.Parameter.Mode = if (unary.operator == .borrow_mutable) .mutable else .read;
    if (mode == .mutable and (source.borrowed_mode != .mutable or source.reference == null)) {
        return self.fail(unary.operator_position, "a mutable element reference requires a mutable collection place");
    }
    const index = try requireIndex(self, builder, access.index);
    const result = try self.newValue(builder, .address);
    try self.emit(builder, .{ .collection_reference = .{
        .result = result,
        .collection = source.value,
        .reference = source.reference,
        .index = index.value,
        .position = access.bracket_position,
    } });
    const value = try self.newValue(builder, collection.element);
    try self.emit(builder, .{ .reference_load = .{ .result = value, .reference = result } });
    return .{
        .type = collection.element,
        .value = value,
        .borrowed_root = root,
        .borrowed_mode = mode,
        .reference = result,
    };
}

pub fn analyzeCall(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    const receiver_expression = call.receiver orelse return null;
    const receiver_type = inferReceiverType(self.structures, builder, receiver_expression) orelse return null;
    const collection = collectionForType(self.structures, receiver_type) orelse {
        if (std.mem.eql(u8, call.name, "indexed")) return self.fail(call.name_position, "indexed() expects an array or list");
        return null;
    };
    if (call.safe or call.arguments.len != 0 or call.named_arguments.len != 0 or call.type_arguments.len != 0) return null;
    if (std.mem.eql(u8, call.name, "indexed")) {
        if (collection.view) return self.fail(call.name_position, "indexed() expects an array or list");
        return self.fail(call.name_position, "indexed() is available only as a for source with two bindings");
    }
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

fn findBinding(bindings: []const Model.Binding, requested: []const u8) ?Model.Binding {
    if (Support.findBinding(bindings, requested)) |binding| return binding;
    const dot = std.mem.lastIndexOfScalar(u8, requested, '.') orelse return null;
    return Support.findBinding(bindings, requested[dot + 1 ..]);
}

pub fn collectionForType(structures: []const Ir.Structure, type_value: Ast.Type) ?Ast.Collection {
    const index = type_value.structureIndex() orelse return null;
    if (index >= structures.len) return null;
    return structures[index].collection;
}

pub fn isViewType(structures: []const Ir.Structure, type_value: Ast.Type) bool {
    const collection = collectionForType(structures, type_value) orelse return false;
    return collection.view;
}

pub fn loweredBorrowType(structures: []const Ir.Structure, mode: Ast.Parameter.Mode, type_value: Ast.Type) Ast.Type {
    return if (mode == .mutable and !isViewType(structures, type_value)) .address else type_value;
}

pub fn bindFunctionParameter(self: anytype, builder: anytype, parameter: Ast.Parameter, value: Ir.ValueId) !Ast.Type {
    const lowered = loweredBorrowType(self.structures, parameter.mode, parameter.type);
    try builder.value_types.append(self.allocator, lowered);
    if (parameter.mode == .mutable and isViewType(self.structures, parameter.type)) {
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, parameter.type);
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = value } });
        try builder.bindings.append(self.allocator, .{
            .name = parameter.name,
            .type = parameter.type,
            .local = local,
            .mutable = true,
            .parameter = true,
            .parameter_mode = .mutable,
        });
    } else if (parameter.mode == .value and parameter.type.structureIndex() != null and
        !self.structures[parameter.type.structureIndex().?].is_class)
    {
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, parameter.type);
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = value } });
        try builder.bindings.append(self.allocator, .{
            .name = parameter.name,
            .type = parameter.type,
            .local = local,
            .mutable = true,
            .parameter = true,
        });
    } else try builder.bindings.append(self.allocator, .{
        .name = parameter.name,
        .type = parameter.type,
        .value = if (parameter.mode == .mutable) null else value,
        .reference = if (parameter.mode == .mutable) value else null,
        .mutable = parameter.mode == .mutable,
        .parameter = true,
        .parameter_mode = parameter.mode,
    });
    return lowered;
}

fn viewTypeForElement(structures: []const Ir.Structure, element: Ast.Type) ?Ast.Type {
    for (structures, 0..) |structure, index| if (structure.collection) |collection| {
        if (collection.view and collection.element == element) return .structure(index);
    };
    return null;
}

fn inferReceiverType(structures: []const Ir.Structure, builder: anytype, expression: *const Ast.Expression) ?Ast.Type {
    return switch (expression.value) {
        .identifier => |name| if (@import("Support.zig").findBinding(builder.bindings.items, name)) |binding| binding.type else null,
        .field_access => |access| field: {
            const base = inferReceiverType(structures, builder, access.base) orelse break :field null;
            const structure_index = base.structureIndex() orelse break :field null;
            if (structure_index >= structures.len) break :field null;
            for (structures[structure_index].fields) |item| if (std.mem.eql(u8, item.name, access.name)) break :field item.type;
            break :field null;
        },
        .sequence_literal => |literal| literal.inferred_type,
        .call => |call| call.result_type,
        .cascade => |cascade| inferReceiverType(structures, builder, cascade.receiver),
        else => null,
    };
}
