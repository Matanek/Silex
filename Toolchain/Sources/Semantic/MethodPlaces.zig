const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");
const Optionals = @import("Optionals.zig");
const Resources = @import("Resources.zig");
const StorageOwnership = @import("StorageOwnership.zig");

pub const Place = struct {
    local: ?Ir.LocalId,
    reference: ?Ir.ValueId,
    root_type: Ast.Type,
    fields: []const usize,
    receiver_type: ?Ast.Type = null,
    receiver_domain: StorageOwnership.Domain = .edge,
};

pub fn requireMutablePlace(self: anytype, builder: anytype, expression: *const Ast.Expression, method_name: []const u8) !Place {
    var names: std.ArrayList([]const u8) = .empty;
    var current = expression;
    while (true) switch (current.value) {
        .identifier => |name| {
            const binding = Support.findBinding(builder.bindings.items, name) orelse {
                const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{name});
                return self.fail(current.position, message);
            };
            if (!binding.mutable or (binding.local == null and binding.reference == null)) {
                const message = try std.fmt.allocPrint(self.allocator, "mutating method '{s}' requires a var receiver", .{method_name});
                return self.fail(expression.position, message);
            }
            std.mem.reverse([]const u8, names.items);
            const field_indices = try self.allocator.alloc(usize, names.items.len);
            var type_value = binding.type;
            for (names.items, 0..) |field_name, path_index| {
                const structure_index = type_value.structureIndex() orelse return error.InvalidSource;
                const structure = self.structures[structure_index];
                var selected: ?usize = null;
                for (structure.fields, 0..) |field, field_index| {
                    if (std.mem.eql(u8, field.name, field_name)) {
                        selected = field_index;
                        break;
                    }
                }
                const field_index = selected orelse return error.InvalidSource;
                if (!structure.fields[field_index].mutable) {
                    const message = try std.fmt.allocPrint(self.allocator, "mutating method '{s}' cannot write through immutable field '{s}'", .{ method_name, field_name });
                    return self.fail(expression.position, message);
                }
                field_indices[path_index] = field_index;
                type_value = structure.fields[field_index].type;
            }
            return .{ .local = binding.local, .reference = binding.reference, .root_type = binding.type, .fields = field_indices };
        },
        .field_access => |access| {
            try names.append(self.allocator, access.name);
            current = access.base;
        },
        else => {
            const message = try std.fmt.allocPrint(self.allocator, "mutating method '{s}' requires a var receiver", .{method_name});
            return self.fail(expression.position, message);
        },
    };
}

pub fn findMutablePlace(self: anytype, builder: anytype, expression: *const Ast.Expression) !?Place {
    var names: std.ArrayList([]const u8) = .empty;
    var current = expression;
    while (true) switch (current.value) {
        .identifier => |name| {
            const binding = Support.findBinding(builder.bindings.items, name) orelse return null;
            if (!binding.mutable or (binding.local == null and binding.reference == null)) return null;
            std.mem.reverse([]const u8, names.items);
            const field_indices = try self.allocator.alloc(usize, names.items.len);
            var type_value = binding.type;
            for (names.items, 0..) |field_name, path_index| {
                const structure_index = type_value.structureIndex() orelse return null;
                const structure = self.structures[structure_index];
                var selected: ?usize = null;
                for (structure.fields, 0..) |field, field_index| {
                    if (std.mem.eql(u8, field.name, field_name)) {
                        selected = field_index;
                        break;
                    }
                }
                const field_index = selected orelse return null;
                if (!structure.fields[field_index].mutable) return null;
                field_indices[path_index] = field_index;
                type_value = structure.fields[field_index].type;
            }
            return .{ .local = binding.local, .reference = binding.reference, .root_type = binding.type, .fields = field_indices };
        },
        .field_access => |access| {
            try names.append(self.allocator, access.name);
            current = access.base;
        },
        else => return null,
    };
}

/// Mutating value receivers are returned by value. Keep the original class
/// edge alive until write-back, so reentrant aliases see the stored value and
/// collection mutations cannot consume an ownership domain they do not own.
pub fn prepareReceiverPlace(self: anytype, builder: anytype, place: Place, receiver: Model.TypedValue, optional_type: ?Ast.Type) !Place {
    var type_value = place.root_type;
    var edge = false;
    for (place.fields) |field_index| {
        const structure = self.structures[type_value.structureIndex().?];
        edge = edge or structure.is_class;
        type_value = structure.fields[field_index].type;
    }
    if ((!edge and place.reference == null) or !Resources.requiresRetain(self, receiver.type)) return place;
    const value = if (optional_type) |wrapped|
        (try Optionals.promote(self, builder, receiver, wrapped)).?
    else
        receiver;
    try Resources.retainValue(self, builder, value.type, value.value);
    var prepared = place;
    prepared.receiver_type = value.type;
    prepared.receiver_domain = if (edge) .edge else try StorageOwnership.reference(self, builder, place.reference.?);
    return prepared;
}

pub fn writePlace(self: anytype, builder: anytype, place: Place, replacement_value: Ir.ValueId) !void {
    if (place.receiver_type) |type_value| {
        try StorageOwnership.apply(self, builder, place.receiver_domain, .retain, type_value, replacement_value);
        try Resources.releaseTransferredRoot(self, builder, type_value, replacement_value);
    }
    if (place.fields.len == 0) {
        const previous = if (place.receiver_type) |type_value| previous: {
            const value = try self.newValue(builder, type_value);
            try self.emit(builder, .{ .reference_load = .{ .result = value, .reference = place.reference.? } });
            break :previous value;
        } else null;
        if (place.local) |local| try self.emit(builder, .{ .local_store = .{ .local = local, .operand = replacement_value } }) else try self.emit(builder, .{ .reference_store = .{ .reference = place.reference.?, .operand = replacement_value } });
        if (place.receiver_type) |type_value| try StorageOwnership.apply(self, builder, place.receiver_domain, .release, type_value, previous.?);
        return;
    }
    const root = try self.newValue(builder, place.root_type);
    if (place.local) |local| try self.emit(builder, .{ .local_load = .{ .result = root, .local = local } }) else try self.emit(builder, .{ .reference_load = .{ .result = root, .reference = place.reference.? } });
    const bases = try self.allocator.alloc(Ir.ValueId, place.fields.len);
    const structure_indices = try self.allocator.alloc(usize, place.fields.len);
    var current = root;
    var current_type = place.root_type;
    for (place.fields, 0..) |field_index, path_index| {
        bases[path_index] = current;
        structure_indices[path_index] = current_type.structureIndex().?;
        if (path_index + 1 < place.fields.len) {
            const field_type = self.structures[structure_indices[path_index]].fields[field_index].type;
            current = try self.newValue(builder, field_type);
            try self.emit(builder, .{ .field_load = .{ .result = current, .base = bases[path_index], .field = field_index } });
            current_type = field_type;
        }
    }

    // An alias may have replaced the field while the value method ran. Release
    // the value currently stored here, not the original receiver's old bits.
    const previous_receiver = if (place.receiver_type) |type_value| previous: {
        const value = try self.newValue(builder, type_value);
        const last = place.fields.len - 1;
        try self.emit(builder, .{ .field_load = .{ .result = value, .base = bases[last], .field = place.fields[last] } });
        break :previous value;
    } else null;

    var replacement = replacement_value;
    var path_index = place.fields.len;
    while (path_index != 0) {
        path_index -= 1;
        const structure_index = structure_indices[path_index];
        const structure = self.structures[structure_index];
        if (structure.is_class) {
            const result = try self.newValue(builder, .structure(structure_index));
            try self.emit(builder, .{ .field_store = .{
                .result = result,
                .base = bases[path_index],
                .field = place.fields[path_index],
                .replacement = replacement,
            } });
            replacement = result;
            continue;
        }
        const fields = try self.allocator.alloc(Ir.ValueId, structure.fields.len);
        for (structure.fields, 0..) |field, field_index| {
            if (field_index == place.fields[path_index]) {
                fields[field_index] = replacement;
            } else {
                fields[field_index] = try self.newValue(builder, field.type);
                try self.emit(builder, .{ .field_load = .{ .result = fields[field_index], .base = bases[path_index], .field = field_index } });
            }
        }
        replacement = try self.newValue(builder, .structure(structure_index));
        try self.emit(builder, .{ .structure_init = .{
            .result = replacement,
            .structure = structure_index,
            .fields = fields,
        } });
    }
    if (place.local) |local| try self.emit(builder, .{ .local_store = .{ .local = local, .operand = replacement } }) else try self.emit(builder, .{ .reference_store = .{ .reference = place.reference.?, .operand = replacement } });
    if (place.receiver_type) |type_value| {
        try StorageOwnership.apply(self, builder, place.receiver_domain, .release, type_value, previous_receiver.?);
    }
}
