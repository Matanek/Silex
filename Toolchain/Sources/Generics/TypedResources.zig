const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

pub const canonical_name = "GFX.Bootstrap.Resources";
pub const order_field_name = "__resource_order";
pub const slot_prefix = "__resource_slot_";

pub fn isResources(self: anytype, structure_type: Ast.Type) bool {
    const structure = self.structureForType(structure_type) orelse return false;
    return std.mem.eql(u8, structure.name, canonical_name);
}

pub fn intrinsicForSpecialization(
    self: anytype,
    structure_type: Ast.Type,
    method_name: []const u8,
    arguments: []const Ast.Type,
    position: Source.Position,
) !?Ast.FunctionIntrinsic {
    if (!isResources(self, structure_type) or arguments.len != 1) return null;
    const slot = try ensureSlot(self, structure_type, arguments[0], position);
    if (std.mem.eql(u8, method_name, "insert")) return .{ .resource_insert = slot };
    if (std.mem.eql(u8, method_name, "has")) return .{ .resource_has = slot };
    if (std.mem.eql(u8, method_name, "get")) return .{ .resource_get = slot };
    if (std.mem.eql(u8, method_name, "get_mut")) return .{ .resource_get_mut = slot };
    if (std.mem.eql(u8, method_name, "try_get")) return .{ .resource_try_get = slot };
    if (std.mem.eql(u8, method_name, "try_get_mut")) return .{ .resource_try_get_mut = slot };
    if (std.mem.eql(u8, method_name, "remove")) return .{ .resource_remove = slot };
    return null;
}

pub fn markConcreteMethods(self: anytype, structure_index: usize) void {
    const structure = &self.structures.items[structure_index];
    if (!std.mem.eql(u8, structure.name, canonical_name)) return;
    for (@constCast(structure.methods)) |*method| {
        if (std.mem.eql(u8, method.name, "clear")) method.intrinsic = .resource_clear;
    }
}

fn ensureSlot(self: anytype, structure_type: Ast.Type, resource_type: Ast.Type, position: Source.Position) !usize {
    const structure_index = self.structureIndexForType(structure_type) orelse return error.InvalidSource;
    const structure = &self.structures.items[structure_index];
    for (structure.fields, 0..) |field, index| {
        if (!std.mem.startsWith(u8, field.name, slot_prefix)) continue;
        if (field.type.optionalChild() == resource_type) return index;
    }

    const field_index = structure.fields.len;
    const fields = try self.allocator.alloc(Ast.StructureField, field_index + 1);
    @memcpy(fields[0..field_index], structure.fields);
    const null_value = try self.allocator.create(Ast.Expression);
    null_value.* = .{ .position = position, .value = .null_value };
    fields[field_index] = .{
        .is_public = false,
        .is_private = true,
        .position = position,
        .name_position = position,
        .name = try std.fmt.allocPrint(self.allocator, "{s}{d}", .{ slot_prefix, field_index }),
        .mutable = true,
        .type = .optional(resource_type),
        .default = null_value,
    };
    structure.fields = fields;
    return field_index;
}
