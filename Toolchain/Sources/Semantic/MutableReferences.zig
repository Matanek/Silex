const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");
const Collections = @import("Collections.zig");

const Step = union(enum) {
    field: struct { structure: usize, field: usize },
    index: struct { collection_type: Ast.Type, index: Ir.ValueId, position: @import("../Source.zig").Position },
};

pub const Prepared = struct {
    root_binding: usize,
    type: Ast.Type,
    reference: Ir.ValueId,
    temporary: ?Ir.LocalId,
    steps: []const Step,
};

pub fn prepare(self: anytype, builder: anytype, expression: *const Ast.Expression, expected: ?Ast.Type) !Prepared {
    var steps: std.ArrayList(Step) = .empty;
    const root_name = rootName(expression) orelse return self.fail(expression.position, "mutable reference requires a var, mutable field, or mutable element");
    const root_index = Support.findBindingIndex(builder.bindings.items, root_name) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{root_name});
        return self.fail(expression.position, message);
    };
    const binding = builder.bindings.items[root_index];
    if (binding.borrowed_root == null) try @import("Borrowing.zig").ensureRootUnborrowed(self, builder, root_name, expression.position);
    if (!binding.available) return self.fail(expression.position, "moved value cannot be borrowed mutably");
    if (!binding.mutable or (binding.local == null and binding.reference == null)) {
        return self.fail(expression.position, "mutable reference requires a var root");
    }

    var current = try loadRoot(self, builder, binding);
    var current_type = binding.type;
    try descend(self, builder, expression, root_name, &steps, &current, &current_type);
    if (expected) |expected_type| if (current_type != expected_type) {
        const message = try std.fmt.allocPrint(self.allocator, "mutable reference expects '{s}', found '{s}'", .{ self.typeName(expected_type), self.typeName(current_type) });
        return self.fail(expression.position, message);
    };

    var stable_reference = binding.reference;
    if (stable_reference == null and binding.local != null) {
        stable_reference = try self.newValue(builder, .address);
        try self.emit(builder, .{ .local_address = .{ .result = stable_reference.?, .local = binding.local.? } });
    }
    if (stable_reference != null) {
        var only_fields = true;
        var reference = stable_reference.?;
        for (steps.items) |step| switch (step) {
            .field => |field| {
                const next = try self.newValue(builder, .address);
                try self.emit(builder, .{ .reference_field = .{
                    .result = next,
                    .reference = reference,
                    .structure = field.structure,
                    .field = field.field,
                } });
                reference = next;
            },
            .index => {
                only_fields = false;
                break;
            },
        };
        if (only_fields) return .{
            .root_binding = root_index,
            .type = current_type,
            .reference = reference,
            .temporary = null,
            .steps = try steps.toOwnedSlice(self.allocator),
        };
    }

    const local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, current_type);
    try self.emit(builder, .{ .local_store = .{ .local = local, .operand = current } });
    const reference = try self.newValue(builder, .address);
    try self.emit(builder, .{ .local_address = .{ .result = reference, .local = local } });
    return .{
        .root_binding = root_index,
        .type = current_type,
        .reference = reference,
        .temporary = local,
        .steps = try steps.toOwnedSlice(self.allocator),
    };
}

fn descend(
    self: anytype,
    builder: anytype,
    expression: *const Ast.Expression,
    root: []const u8,
    steps: *std.ArrayList(Step),
    current: *Ir.ValueId,
    current_type: *Ast.Type,
) !void {
    switch (expression.value) {
        .identifier => |name| if (!std.mem.eql(u8, name, root)) return self.fail(expression.position, "mutable reference has no stable root"),
        .field_access => |access| {
            if (access.safe) return self.fail(access.name_position, "safe member access is not a mutable place");
            try descend(self, builder, access.base, root, steps, current, current_type);
            const structure_index = current_type.*.structureIndex() orelse return self.fail(access.name_position, "mutable field access requires a structure");
            const structure = self.structures[structure_index];
            var selected: ?usize = null;
            for (structure.fields, 0..) |field, index| if (std.mem.eql(u8, field.name, access.name)) {
                selected = index;
                break;
            };
            const field_index = selected orelse return self.fail(access.name_position, "unknown structure field");
            const field = structure.fields[field_index];
            if (!field.mutable) {
                const message = try std.fmt.allocPrint(self.allocator, "field '{s}' is immutable and cannot be borrowed as '&'", .{field.name});
                return self.fail(access.name_position, message);
            }
            try steps.append(self.allocator, .{ .field = .{ .structure = structure_index, .field = field_index } });
            const value = try self.newValue(builder, field.type);
            try self.emit(builder, .{ .field_load = .{ .result = value, .base = current.*, .field = field_index } });
            current.* = value;
            current_type.* = field.type;
        },
        .index_access => |access| {
            try descend(self, builder, access.base, root, steps, current, current_type);
            const collection = Collections.collectionForType(self.structures, current_type.*) orelse return self.fail(access.bracket_position, "mutable index requires an array or list");
            const index = try self.analyzeExpressionExpected(builder, access.index, .int);
            try steps.append(self.allocator, .{ .index = .{ .collection_type = current_type.*, .index = index.value, .position = access.bracket_position } });
            const value = try self.newValue(builder, collection.element);
            try self.emit(builder, .{ .collection_load = .{ .result = value, .collection = current.*, .index = index.value, .position = access.bracket_position } });
            current.* = value;
            current_type.* = collection.element;
        },
        else => return self.fail(expression.position, "mutable reference requires a var, mutable field, or mutable element"),
    }
}

pub fn writeBack(self: anytype, builder: anytype, prepared: Prepared) !void {
    const local = prepared.temporary orelse return;
    const binding = builder.bindings.items[prepared.root_binding];
    var bases: std.ArrayList(Ir.ValueId) = .empty;
    var current = try loadRoot(self, builder, binding);
    for (prepared.steps) |step| {
        try bases.append(self.allocator, current);
        current = switch (step) {
            .field => |field| value: {
                const type_value = self.structures[field.structure].fields[field.field].type;
                const value = try self.newValue(builder, type_value);
                try self.emit(builder, .{ .field_load = .{ .result = value, .base = current, .field = field.field } });
                break :value value;
            },
            .index => |index| value: {
                const collection = Collections.collectionForType(self.structures, index.collection_type).?;
                const value = try self.newValue(builder, collection.element);
                try self.emit(builder, .{ .collection_load = .{ .result = value, .collection = current, .index = index.index, .position = index.position } });
                break :value value;
            },
        };
    }
    var replacement = try self.newValue(builder, prepared.type);
    try self.emit(builder, .{ .local_load = .{ .result = replacement, .local = local } });
    var index = prepared.steps.len;
    while (index != 0) {
        index -= 1;
        replacement = switch (prepared.steps[index]) {
            .field => |field| value: {
                const structure = self.structures[field.structure];
                if (structure.is_class) {
                    const result = try self.newValue(builder, .structure(field.structure));
                    try self.emit(builder, .{ .field_store = .{
                        .result = result,
                        .base = bases.items[index],
                        .field = field.field,
                        .replacement = replacement,
                    } });
                    break :value result;
                }
                const fields = try self.allocator.alloc(Ir.ValueId, structure.fields.len);
                for (structure.fields, 0..) |item, field_index| {
                    if (field_index == field.field) fields[field_index] = replacement else {
                        fields[field_index] = try self.newValue(builder, item.type);
                        try self.emit(builder, .{ .field_load = .{ .result = fields[field_index], .base = bases.items[index], .field = field_index } });
                    }
                }
                const result = try self.newValue(builder, .structure(field.structure));
                try self.emit(builder, .{ .structure_init = .{ .result = result, .structure = field.structure, .fields = fields } });
                break :value result;
            },
            .index => |item| value: {
                const result = try self.newValue(builder, item.collection_type);
                try self.emit(builder, .{ .collection_replace = .{ .result = result, .collection = bases.items[index], .index = item.index, .replacement = replacement, .position = item.position } });
                break :value result;
            },
        };
    }
    if (binding.local) |root_local| {
        try self.emit(builder, .{ .local_store = .{ .local = root_local, .operand = replacement } });
    } else try self.emit(builder, .{ .reference_store = .{ .reference = binding.reference.?, .operand = replacement } });
}

fn loadRoot(self: anytype, builder: anytype, binding: Model.Binding) !Ir.ValueId {
    const result = try self.newValue(builder, binding.type);
    if (binding.local) |local| try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } }) else try self.emit(builder, .{ .reference_load = .{ .result = result, .reference = binding.reference.? } });
    return result;
}

fn rootName(expression: *const Ast.Expression) ?[]const u8 {
    return switch (expression.value) {
        .identifier => |name| name,
        .field_access => |access| rootName(access.base),
        .index_access => |access| rootName(access.base),
        else => null,
    };
}

pub fn samePlace(left: *const Ast.Expression, right: *const Ast.Expression) bool {
    return switch (left.value) {
        .identifier => |name| right.value == .identifier and std.mem.eql(u8, name, right.value.identifier),
        .field_access => |access| right.value == .field_access and std.mem.eql(u8, access.name, right.value.field_access.name) and samePlace(access.base, right.value.field_access.base),
        .index_access => |access| right.value == .index_access and samePlace(access.base, right.value.index_access.base) and sameIndex(access.index, right.value.index_access.index),
        else => false,
    };
}

fn sameIndex(left: *const Ast.Expression, right: *const Ast.Expression) bool {
    return switch (left.value) {
        .integer => |value| right.value == .integer and std.mem.eql(u8, value, right.value.integer),
        .identifier => |value| right.value == .identifier and std.mem.eql(u8, value, right.value.identifier),
        else => false,
    };
}
