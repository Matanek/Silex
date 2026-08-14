const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

pub const canonical_name = "GFX.Application.Resources";
pub const component_pools_name = "GFX.ECS.ComponentStore.ComponentPools";
pub const order_field_name = "__resource_order";
pub const slot_prefix = "__resource_slot_";

pub fn validateDeclarations(self: anytype) !void {
    for (self.source.structures) |structure| {
        if (!structure.is_intrinsic) {
            if (isTypedStoreName(structure.name)) {
                const message = try std.fmt.allocPrint(self.allocator, "'{s}' must be declared as an intrinsic class", .{structure.name});
                return self.fail(structure.name_position, message);
            }
            continue;
        }
        if (!isTypedStoreName(structure.name)) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "intrinsic class '{s}' has no compiler implementation",
                .{structure.name},
            );
            return self.fail(structure.name_position, message);
        }
        try validateStoreContract(self, structure);
    }
}

pub fn isResources(self: anytype, structure_type: Ast.Type) bool {
    const structure = self.structureForType(structure_type) orelse return false;
    return isTypedStoreName(structure.name);
}

pub fn intrinsicForSpecialization(
    self: anytype,
    structure_type: Ast.Type,
    method_name: []const u8,
    arguments: []const Ast.Type,
    position: Source.Position,
) !?Ast.FunctionIntrinsic {
    if (!isResources(self, structure_type) or arguments.len != 1) return null;
    if (std.mem.eql(u8, method_name, "retain_class")) {
        const resource = self.structureForType(arguments[0]) orelse return .resource_discard;
        if (!resource.is_class) return .resource_discard;
        return .{ .resource_insert = try ensureSlot(self, structure_type, arguments[0], position) };
    }
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

pub fn markConcreteMethods(self: anytype, structure_index: usize) !void {
    if (!isTypedStoreName(self.structures.items[structure_index].name)) return;
    const structure = &self.structures.items[structure_index];
    for (@constCast(structure.methods)) |*method| {
        if (std.mem.eql(u8, method.name, "clear")) method.intrinsic = .resource_clear;
    }
}

pub fn prepareConcreteStorage(self: anytype) !void {
    var index: usize = 0;
    while (index < self.structures.items.len) : (index += 1) {
        if (isTypedStoreName(self.structures.items[index].name)) try installStorage(self, index);
    }
}

fn validateStoreContract(self: anytype, structure: Ast.Structure) !void {
    const application_resources = std.mem.eql(u8, structure.name, canonical_name);
    const expected_methods: usize = if (application_resources) 9 else 8;
    if (!structure.is_class or
        (application_resources and !structure.is_public) or
        structure.type_parameters.len != 0 or structure.methods.len != expected_methods)
    {
        return invalidContract(self, structure.name, structure.name_position);
    }
    for (structure.methods) |method| {
        const retain_class = application_resources and std.mem.eql(u8, method.name, "retain_class");
        if ((!method.is_public and !retain_class) or method.is_static or !method.is_intrinsic_declaration) {
            return invalidContract(self, structure.name, method.name_position);
        }
        const generic = Ast.Type.genericParameter(0);
        const valid = if (std.mem.eql(u8, method.name, "insert") or retain_class)
            method.type_parameters.len == 1 and method.parameters.len == 1 and method.parameters[0].type == generic and
                method.parameters[0].mode == .value and method.return_type == .void and method.return_mode == .value
        else if (std.mem.eql(u8, method.name, "has"))
            genericQuery(method, .bool, .value)
        else if (std.mem.eql(u8, method.name, "get"))
            genericQuery(method, generic, .read)
        else if (std.mem.eql(u8, method.name, "get_mut"))
            genericQuery(method, generic, .mutable)
        else if (std.mem.eql(u8, method.name, "try_get"))
            genericQuery(method, .optional(generic), .read)
        else if (std.mem.eql(u8, method.name, "try_get_mut"))
            genericQuery(method, .optional(generic), .mutable)
        else if (std.mem.eql(u8, method.name, "remove"))
            genericQuery(method, .optional(generic), .value)
        else if (std.mem.eql(u8, method.name, "clear"))
            method.type_parameters.len == 0 and method.parameters.len == 0 and method.return_type == .void and method.return_mode == .value
        else
            false;
        if (!valid) return invalidContract(self, structure.name, method.name_position);
    }
}

fn genericQuery(method: Ast.Function, return_type: Ast.Type, return_mode: Ast.Parameter.Mode) bool {
    return method.type_parameters.len == 1 and method.parameters.len == 0 and
        method.return_type == return_type and method.return_mode == return_mode;
}

fn invalidContract(self: anytype, name: []const u8, position: Source.Position) !void {
    const message = try std.fmt.allocPrint(
        self.allocator,
        "intrinsic class '{s}' does not match the compiler-provided contract",
        .{name},
    );
    return self.fail(position, message);
}

fn isTypedStoreName(name: []const u8) bool {
    return std.mem.eql(u8, name, canonical_name) or std.mem.eql(u8, name, component_pools_name);
}

fn installStorage(self: anytype, structure_index: usize) !void {
    const position = self.structures.items[structure_index].position;
    const order_type = try ensureOrderType(self, position);
    const fields = try self.allocator.alloc(Ast.StructureField, 1);
    const empty_order = try self.allocator.create(Ast.Expression);
    empty_order.* = .{ .position = position, .value = .{ .sequence_literal = .{
        .values = &.{},
        .inferred_type = order_type,
    } } };
    fields[0] = .{
        .is_public = false,
        .is_private = true,
        .position = position,
        .name_position = position,
        .name = order_field_name,
        .mutable = true,
        .type = order_type,
        .default = null,
    };
    self.structures.items[structure_index].fields = fields;

    const constructor_statements = try self.allocator.alloc(Ast.Statement, 1);
    constructor_statements[0] = .{ .assignment_statement = .{
        .position = position,
        .target = .{
            .name_position = position,
            .name = "self",
            .fields = try self.allocator.dupe(Ast.AssignmentTarget.Field, &.{.{
                .name_position = position,
                .name = order_field_name,
            }}),
        },
        .operator = .assign,
        .value = empty_order,
    } };
    const constructors = try self.allocator.alloc(Ast.Constructor, 1);
    constructors[0] = .{
        .is_public = true,
        .position = position,
        .parameters = &.{},
        .statements = constructor_statements,
    };
    self.structures.items[structure_index].constructors = constructors;

    const receiver = try self.allocator.create(Ast.Expression);
    receiver.* = .{ .position = position, .value = .{ .identifier = "self" } };
    const call = try self.allocator.create(Ast.Expression);
    call.* = .{ .position = position, .value = .{ .call = .{
        .name = "clear",
        .name_position = position,
        .receiver = receiver,
        .arguments = &.{},
    } } };
    const statements = try self.allocator.alloc(Ast.Statement, 1);
    statements[0] = .{ .expression_statement = call };
    self.structures.items[structure_index].drop = .{ .position = position, .statements = statements };
}

fn ensureOrderType(self: anytype, position: Source.Position) !Ast.Type {
    const name = "int[]";
    const type_value = self.typeForName(name) orelse value: {
        const created = Ast.Type.structure(self.type_names.items.len);
        try self.type_names.append(self.allocator, name);
        break :value created;
    };
    if (self.structureForType(type_value) == null) try self.structures.append(self.allocator, .{
        .is_public = false,
        .position = position,
        .name_position = position,
        .name = name,
        .fields = &.{},
        .collection = .{ .element = .int, .length = null },
    });
    return type_value;
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
