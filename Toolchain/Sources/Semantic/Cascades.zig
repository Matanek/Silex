const std = @import("std");
const Ast = @import("../Ast.zig");
const Model = @import("Model.zig");
const Mutation = @import("Mutation.zig");
const Resources = @import("Resources.zig");
const Support = @import("Support.zig");

pub fn analyze(
    self: anytype,
    builder: anytype,
    cascade: Ast.Expression.Cascade,
    expected: ?Ast.Type,
) !Model.TypedValue {
    const binding_count = builder.bindings.items.len;
    defer builder.bindings.shrinkRetainingCapacity(binding_count);
    var transfers_temporary_class = false;

    const target = if (stablePlace(cascade.receiver, builder.bindings.items))
        cascade.receiver
    else target: {
        const receiver = try self.analyzeExpressionExpected(builder, cascade.receiver, expected);
        if (receiver.type == .void) return self.fail(cascade.receiver.position, "cascade receiver cannot have type 'void'");
        if (Resources.requiresRetain(self, receiver.type) and !receiver.transferred) {
            try Resources.retainValue(self, builder, receiver.type, receiver.value);
        }
        transfers_temporary_class = Resources.requiresRetain(self, receiver.type);
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, receiver.type);
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = receiver.value } });
        const name = try std.fmt.allocPrint(self.allocator, "$cascade{d}", .{local});
        try builder.bindings.append(self.allocator, .{
            .name = name,
            .type = receiver.type,
            .local = local,
            .mutable = receiver.borrowed_root == null,
            .borrowed_root = receiver.borrowed_root,
            .borrowed_mode = receiver.borrowed_mode,
        });
        break :target try expression(self, cascade.receiver.position, .{ .identifier = name });
    };

    for (cascade.operations) |operation| switch (operation) {
        .method_call => |method| {
            const call = Ast.Expression.Call{
                .name = method.name,
                .name_position = method.name_position,
                .receiver = target,
                .compiler_generated = method.compiler_generated,
                .arguments = method.arguments,
                .named_arguments = method.named_arguments,
                .type_arguments = method.type_arguments,
            };
            if (try self.analyzeCall(builder, call)) |ignored| {
                if (ignored.transferred and (Resources.needsDrop(self, ignored.type) or Resources.containsClass(self, ignored.type))) {
                    try Resources.emitDrop(self, builder, ignored.type, ignored.value);
                }
            }
        },
        .field_assignment => |field| {
            var assignment_target = try assignmentTarget(self, target);
            const fields = try self.allocator.alloc(Ast.AssignmentTarget.Field, assignment_target.fields.len + 1);
            @memcpy(fields[0..assignment_target.fields.len], assignment_target.fields);
            fields[fields.len - 1] = .{ .name_position = field.name_position, .name = field.name };
            assignment_target.fields = fields;
            try Mutation.analyzeAssignment(self, builder, .{
                .position = field.name_position,
                .target = assignment_target,
                .operator = .assign,
                .value = field.value,
            });
        },
    };

    var result = try self.analyzeExpressionExpected(builder, target, expected);
    if (transfers_temporary_class) result.transferred = true;
    return result;
}

fn stablePlace(expression_value: *const Ast.Expression, bindings: anytype) bool {
    return switch (expression_value.value) {
        .identifier => |name| Support.findBinding(bindings, name) != null,
        .field_access => |access| stablePlace(access.base, bindings),
        else => false,
    };
}

fn assignmentTarget(self: anytype, target: *const Ast.Expression) !Ast.AssignmentTarget {
    var fields: std.ArrayList(Ast.AssignmentTarget.Field) = .empty;
    var current = target;
    while (true) switch (current.value) {
        .identifier => |name| {
            std.mem.reverse(Ast.AssignmentTarget.Field, fields.items);
            return .{
                .name_position = current.position,
                .name = name,
                .fields = try fields.toOwnedSlice(self.allocator),
            };
        },
        .field_access => |access| {
            try fields.append(self.allocator, .{ .name_position = access.name_position, .name = access.name });
            current = access.base;
        },
        else => return self.fail(target.position, "cascade field assignment requires a mutable value or a newly owned temporary"),
    };
}

fn expression(self: anytype, position: @import("../Source.zig").Position, value: Ast.Expression.Value) !*Ast.Expression {
    const result = try self.allocator.create(Ast.Expression);
    result.* = .{ .position = position, .value = value };
    return result;
}
