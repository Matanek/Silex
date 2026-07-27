const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Support = @import("Support.zig");
const Optionals = @import("Optionals.zig");
const Enums = @import("Enums.zig");
const Collections = @import("Collections.zig");
const Moves = @import("Moves.zig");
const Borrowing = @import("Borrowing.zig");
const Resources = @import("Resources.zig");

const PathStep = union(enum) {
    field: struct { base: Ir.ValueId, structure: usize, field: usize },
    collection: struct { base: Ir.ValueId, type: Ast.Type, index: Ir.ValueId, position: @import("../Source.zig").Position },
};

pub fn analyzeAssignment(self: anytype, builder: anytype, assignment: Ast.AssignmentStatement) !void {
    const target = assignment.target;
    const binding = Support.findBinding(builder.bindings.items, target.name) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{target.name});
        return self.fail(target.name_position, message);
    };
    const binding_index = Support.findBindingIndex(builder.bindings.items, target.name).?;
    if (Collections.isViewType(self.structures, binding.type) and target.fields.len == 0 and target.indices.len == 0) {
        return self.fail(target.name_position, "a view binding cannot be replaced as a whole");
    }
    if (Collections.isViewType(self.structures, binding.type) and target.indices.len != 0) {
        const element = Collections.collectionForType(self.structures, binding.type).?.element;
        if (Resources.isNoncopyable(self, element)) return self.fail(target.name_position, "a view cannot replace or transfer a noncopyable element");
    }
    if (binding.borrowed_root == null) try Borrowing.ensureRootUnborrowed(self, builder, target.name, target.name_position);
    const complete_assignment = target.fields.len == 0 and target.indices.len == 0 and assignment.operator == .assign;
    if (!binding.available and !(binding.mutable and complete_assignment)) {
        const message = try std.fmt.allocPrint(self.allocator, "value '{s}' was moved and is unavailable", .{target.name});
        return self.fail(target.name_position, message);
    }
    if (!binding.mutable) {
        const message = if (assignment.operator == .assign)
            if (binding.parameter)
                try std.fmt.allocPrint(self.allocator, "cannot assign to parameter '{s}'", .{target.name})
            else
                try std.fmt.allocPrint(self.allocator, "cannot assign to immutable variable '{s}'", .{target.name})
        else if (binding.parameter)
            try std.fmt.allocPrint(
                self.allocator,
                "cannot apply '{s}' to parameter '{s}'",
                .{ operatorText(assignment.operator), target.name },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "cannot apply '{s}' to immutable variable '{s}'",
                .{ operatorText(assignment.operator), target.name },
            );
        return self.fail(target.name_position, message);
    }

    if (target.fields.len == 0 and target.indices.len == 0) {
        if (assignment.value) |value| if (Moves.isSelfMove(value, target.name)) {
            const message = try std.fmt.allocPrint(self.allocator, "cannot move value '{s}' into itself", .{target.name});
            return self.fail(value.position, message);
        };
        if (assignment.operator == .assign and assignment.value != null) {
            try Resources.requireTransfer(self, assignment.value.?, binding.type, "assigning it");
            if (binding.available and Resources.isNoncopyable(self, binding.type)) {
                try Resources.emitDrop(self, builder, binding.type, try loadBinding(self, builder, binding));
            }
        }
        const current = if (assignment.operator == .assign) null else try loadBinding(self, builder, binding);
        const replacement = try analyzeReplacement(self, builder, assignment, binding.type, current, target.name, false);
        try storeBinding(self, builder, binding, replacement);
        builder.bindings.items[binding_index].available = true;
        Optionals.invalidateRefinement(builder, target.name);
        return;
    }

    const root = try loadBinding(self, builder, binding);
    var steps: std.ArrayList(PathStep) = .empty;
    var current_type = binding.type;
    var current_value = root;
    for (target.fields) |target_field| {
        const structure_index = current_type.structureIndex() orelse {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no fields", .{self.typeName(current_type)});
            return self.fail(target_field.name_position, message);
        };
        if (Enums.findByType(self, current_type) != null) {
            if (std.mem.eql(u8, target_field.name, "raw_value")) {
                return self.fail(target_field.name_position, "enum property 'raw_value' is read-only");
            }
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no assignable fields", .{self.typeName(current_type)});
            return self.fail(target_field.name_position, message);
        }
        const structure = self.structures[structure_index];
        const source_structure = self.program.structures[structure_index];
        if (source_structure.drop != null and !self.ownerStorageVisible(structure_index, target_field.name_position)) {
            return self.fail(target_field.name_position, "owner structure storage is private to its declaring file and direct module users");
        }
        if (source_structure.is_internal and target_field.name_position.file != source_structure.position.file) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "members of internal structure '{s}' are unavailable outside its source file",
                .{structure.name},
            );
            return self.fail(target_field.name_position, message);
        }
        var selected: ?usize = null;
        for (structure.fields, 0..) |field, field_index| {
            if (std.mem.eql(u8, field.name, target_field.name)) {
                selected = field_index;
                break;
            }
        }
        const field_index = selected orelse {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "structure '{s}' has no field named '{s}'",
                .{ structure.name, target_field.name },
            );
            return self.fail(target_field.name_position, message);
        };
        const field = structure.fields[field_index];
        const source_field = source_structure.fields[field_index];
        if (!Support.memberVisible(target_field.name_position, source_field.position, source_field.is_internal)) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "field '{s}' is internal to its source file",
                .{field.name},
            );
            return self.fail(target_field.name_position, message);
        }
        if (!field.mutable) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "cannot assign through immutable field '{s}'",
                .{field.name},
            );
            return self.fail(target_field.name_position, message);
        }
        try steps.append(self.allocator, .{ .field = .{
            .base = current_value,
            .structure = structure_index,
            .field = field_index,
        } });
        const field_value = try self.newValue(builder, field.type);
        try self.emit(builder, .{ .field_load = .{
            .result = field_value,
            .base = current_value,
            .field = field_index,
        } });
        current_type = field.type;
        current_value = field_value;
    }

    for (target.indices) |target_index| {
        const collection = Collections.collectionForType(self.structures, current_type) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "indexing requires an array, found '{s}'", .{self.typeName(current_type)});
            return self.fail(target_index.position, message);
        };
        const index_value = try self.analyzeExpressionExpected(builder, target_index.value, .int);
        if (index_value.type != .int) {
            const message = try std.fmt.allocPrint(self.allocator, "collection index expects 'int', found '{s}'", .{self.typeName(index_value.type)});
            return self.fail(target_index.value.position, message);
        }
        try steps.append(self.allocator, .{ .collection = .{
            .base = current_value,
            .type = current_type,
            .index = index_value.value,
            .position = target_index.position,
        } });
        const element = try self.newValue(builder, collection.element);
        try self.emit(builder, .{ .collection_load = .{
            .result = element,
            .collection = current_value,
            .index = index_value.value,
            .position = target_index.position,
        } });
        current_type = collection.element;
        current_value = element;
    }

    const final_name = if (target.indices.len != 0) "collection element" else target.fields[target.fields.len - 1].name;
    var replacement = try analyzeReplacement(self, builder, assignment, current_type, current_value, final_name, target.indices.len == 0);
    var index = steps.items.len;
    while (index != 0) {
        index -= 1;
        switch (steps.items[index]) {
            .field => |step| {
                const structure = self.structures[step.structure];
                if (structure.is_class) {
                    const result = try self.newValue(builder, .structure(step.structure));
                    try self.emit(builder, .{ .field_store = .{
                        .result = result,
                        .base = step.base,
                        .field = step.field,
                        .replacement = replacement,
                    } });
                    replacement = result;
                    continue;
                }
                const fields = try self.allocator.alloc(Ir.ValueId, structure.fields.len);
                for (structure.fields, 0..) |field, field_index| {
                    if (field_index == step.field) {
                        fields[field_index] = replacement;
                        continue;
                    }
                    const value = try self.newValue(builder, field.type);
                    try self.emit(builder, .{ .field_load = .{ .result = value, .base = step.base, .field = field_index } });
                    fields[field_index] = value;
                }
                replacement = try self.newValue(builder, .structure(step.structure));
                try self.emit(builder, .{ .structure_init = .{ .result = replacement, .structure = step.structure, .fields = fields } });
            },
            .collection => |step| {
                const result = try self.newValue(builder, step.type);
                try self.emit(builder, .{ .collection_replace = .{
                    .result = result,
                    .collection = step.base,
                    .index = step.index,
                    .replacement = replacement,
                    .position = step.position,
                } });
                replacement = result;
            },
        }
    }
    try storeBinding(self, builder, binding, replacement);
}

fn loadBinding(self: anytype, builder: anytype, binding: anytype) !Ir.ValueId {
    if (binding.local) |local| return loadLocal(self, builder, local, binding.type);
    if (binding.reference) |reference| {
        const result = try self.newValue(builder, binding.type);
        try self.emit(builder, .{ .reference_load = .{ .result = result, .reference = reference } });
        return result;
    }
    return error.InvalidSource;
}

fn storeBinding(self: anytype, builder: anytype, binding: anytype, value: Ir.ValueId) !void {
    if (binding.local) |local| return self.emit(builder, .{ .local_store = .{ .local = local, .operand = value } });
    if (binding.reference) |reference| return self.emit(builder, .{ .reference_store = .{ .reference = reference, .operand = value } });
    return error.InvalidSource;
}

fn loadLocal(self: anytype, builder: anytype, local: Ir.LocalId, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
    return result;
}

fn analyzeReplacement(
    self: anytype,
    builder: anytype,
    assignment: Ast.AssignmentStatement,
    target_type: Ast.Type,
    current: ?Ir.ValueId,
    target_name: []const u8,
    field_target: bool,
) !Ir.ValueId {
    if (assignment.operator == .assign) {
        var value = try self.analyzeExpressionExpected(
            builder,
            assignment.value.?,
            Optionals.expectedContext(target_type, assignment.value.?),
        );
        if (value.type != target_type and (Numeric.canWiden(value.type, target_type) or Optionals.canConvert(value.type, target_type))) {
            value = try self.coerce(builder, value, target_type, assignment.value.?.position);
        }
        if (value.type != target_type) {
            const message = if (field_target)
                try std.fmt.allocPrint(
                    self.allocator,
                    "assignment to field '{s}' expects '{s}', found '{s}'",
                    .{ target_name, self.typeName(target_type), self.typeName(value.type) },
                )
            else
                try std.fmt.allocPrint(
                    self.allocator,
                    "assignment to '{s}' expects '{s}', found '{s}'",
                    .{ target_name, self.typeName(target_type), self.typeName(value.type) },
                );
            return self.fail(assignment.value.?.position, message);
        }
        try Borrowing.requireOwned(self, value, assignment.value.?.position, "stored");
        return value.value;
    }

    if (!target_type.isNumeric()) {
        const message = if (field_target)
            try std.fmt.allocPrint(
                self.allocator,
                "operator '{s}' requires a numeric field, found '{s}'",
                .{ operatorText(assignment.operator), self.typeName(target_type) },
            )
        else
            try std.fmt.allocPrint(
                self.allocator,
                "operator '{s}' requires a numeric variable, found '{s}'",
                .{ operatorText(assignment.operator), self.typeName(target_type) },
            );
        return self.fail(assignment.position, message);
    }
    const right = switch (assignment.operator) {
        .increment, .decrement => try emitOne(self, builder, target_type),
        else => rhs: {
            var value = try self.analyzeExpressionExpected(
                builder,
                assignment.value.?,
                if (Support.acceptsNumericContext(assignment.value.?)) target_type else null,
            );
            if (value.type != target_type and Numeric.canWiden(value.type, target_type)) {
                value = try self.coerce(builder, value, target_type, assignment.value.?.position);
            }
            if (value.type != target_type) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "operator '{s}' does not accept '{s}' and '{s}'",
                    .{ operatorText(assignment.operator), self.typeName(target_type), self.typeName(value.type) },
                );
                return self.fail(assignment.value.?.position, message);
            }
            break :rhs value.value;
        },
        .assign => unreachable,
    };
    const result = try self.newValue(builder, target_type);
    try self.emit(builder, .{ .binary = .{
        .result = result,
        .operator = switch (assignment.operator) {
            .add, .increment => .add,
            .subtract, .decrement => .subtract,
            .multiply => .multiply,
            .divide => .divide,
            .assign => unreachable,
        },
        .left = current.?,
        .right = right,
    } });
    return result;
}

fn emitOne(self: anytype, builder: anytype, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, switch (type_value) {
        .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint => .{
            .constant_int = .{ .result = result, .bits = 1 },
        },
        .float32 => .{ .constant_float32 = .{ .result = result, .bits = @bitCast(@as(f32, 1.0)) } },
        .float64 => .{ .constant_float64 = .{ .result = result, .bits = @bitCast(@as(f64, 1.0)) } },
        else => unreachable,
    });
    return result;
}

fn operatorText(operator: Ast.AssignmentOperator) []const u8 {
    return switch (operator) {
        .assign => "=",
        .add => "+=",
        .subtract => "-=",
        .multiply => "*=",
        .divide => "/=",
        .increment => "++",
        .decrement => "--",
    };
}
