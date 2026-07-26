const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Support = @import("Support.zig");

const PathStep = struct {
    base: Ir.ValueId,
    structure: usize,
    field: usize,
};

pub fn analyzeAssignment(self: anytype, builder: anytype, assignment: Ast.AssignmentStatement) !void {
    const target = assignment.target;
    const binding = Support.findBinding(builder.bindings.items, target.name) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{target.name});
        return self.fail(target.name_position, message);
    };
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

    if (target.fields.len == 0) {
        const current = if (assignment.operator == .assign) null else try loadLocal(self, builder, binding.local.?, binding.type);
        const replacement = try analyzeReplacement(self, builder, assignment, binding.type, current, target.name, false);
        try self.emit(builder, .{ .local_store = .{ .local = binding.local.?, .operand = replacement } });
        return;
    }

    const root = try loadLocal(self, builder, binding.local.?, binding.type);
    var steps: std.ArrayList(PathStep) = .empty;
    var current_type = binding.type;
    var current_value = root;
    for (target.fields) |target_field| {
        const structure_index = current_type.structureIndex() orelse {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no fields", .{self.typeName(current_type)});
            return self.fail(target_field.name_position, message);
        };
        const structure = self.structures[structure_index];
        const source_structure = self.program.structures[structure_index];
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
        try steps.append(self.allocator, .{
            .base = current_value,
            .structure = structure_index,
            .field = field_index,
        });
        const field_value = try self.newValue(builder, field.type);
        try self.emit(builder, .{ .field_load = .{
            .result = field_value,
            .base = current_value,
            .field = field_index,
        } });
        current_type = field.type;
        current_value = field_value;
    }

    const final_field_name = target.fields[target.fields.len - 1].name;
    var replacement = try analyzeReplacement(self, builder, assignment, current_type, current_value, final_field_name, true);
    var index = steps.items.len;
    while (index != 0) {
        index -= 1;
        const step = steps.items[index];
        const structure = self.structures[step.structure];
        const fields = try self.allocator.alloc(Ir.ValueId, structure.fields.len);
        for (structure.fields, 0..) |field, field_index| {
            if (field_index == step.field) {
                fields[field_index] = replacement;
                continue;
            }
            const value = try self.newValue(builder, field.type);
            try self.emit(builder, .{ .field_load = .{
                .result = value,
                .base = step.base,
                .field = field_index,
            } });
            fields[field_index] = value;
        }
        replacement = try self.newValue(builder, .structure(step.structure));
        try self.emit(builder, .{ .structure_init = .{
            .result = replacement,
            .structure = step.structure,
            .fields = fields,
        } });
    }
    try self.emit(builder, .{ .local_store = .{ .local = binding.local.?, .operand = replacement } });
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
            if (target_type.isNumeric() and Support.acceptsNumericContext(assignment.value.?)) target_type else null,
        );
        if (value.type != target_type and Numeric.canWiden(value.type, target_type)) {
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
