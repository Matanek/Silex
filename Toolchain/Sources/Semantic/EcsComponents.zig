const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");

const resources_name = "GFX.ECS.ComponentStore.ComponentPools";
const pool_prefix = "GFX.ECS.ComponentPool<";

pub fn analyze(self: anytype, structure_index: usize, method: Ast.Function) !Ir.Function {
    const intrinsic = method.intrinsic orelse return error.InvalidSource;
    if (intrinsic == .world_component_get_mut) return analyzeWorld(self, structure_index, method);
    if (intrinsic != .component_get_mut) return error.InvalidSource;
    const store = self.program.structures[structure_index];
    const resources_field = fieldNamed(store, "resources") orelse return error.InvalidSource;
    const resources_type = store.fields[resources_field].type;
    const resources_index = resources_type.structureIndex() orelse return error.InvalidSource;
    const resources = self.program.structures[resources_index];
    if (!std.mem.eql(u8, resources.name, resources_name)) return error.InvalidSource;

    const pool_slot = poolSlot(self, resources, method.return_type) orelse return error.InvalidSource;
    const pool_type = resources.fields[pool_slot].type.optionalChild() orelse return error.InvalidSource;
    const pool_index = pool_type.structureIndex() orelse return error.InvalidSource;
    const pool = self.program.structures[pool_index];
    const resource_getter = methodPrefixed(resources, "get_mut<", pool.name) orelse return error.InvalidSource;
    const pool_getter = methodExact(pool, "get_mut") orelse return error.InvalidSource;

    var builder: Model.FunctionBuilder = .{ .return_type = .address };
    try builder.blocks.append(self.allocator, .{});
    try builder.value_types.append(self.allocator, .address);
    const entity_type = method.parameters[0].type;
    try builder.value_types.append(self.allocator, entity_type);

    const store_value = try self.newValue(&builder, .structure(structure_index));
    try self.emit(&builder, .{ .reference_load = .{ .result = store_value, .reference = 0 } });
    const resources_value = try self.newValue(&builder, resources_type);
    try self.emit(&builder, .{ .field_load = .{ .result = resources_value, .base = store_value, .field = resources_field } });
    const resources_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, resources_type);
    try self.emit(&builder, .{ .local_store = .{ .local = resources_local, .operand = resources_value } });
    const resources_reference = try self.newValue(&builder, .address);
    try self.emit(&builder, .{ .local_address = .{ .result = resources_reference, .local = resources_local } });
    const pool_reference = try self.newValue(&builder, .address);
    try self.emit(&builder, .{ .call = .{
        .result = pool_reference,
        .function = methodFunctionId(self.program, resources_index, resource_getter),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{resources_reference}),
    } });
    const component_reference = try self.newValue(&builder, .address);
    try self.emit(&builder, .{ .call = .{
        .result = component_reference,
        .function = methodFunctionId(self.program, pool_index, pool_getter),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{ pool_reference, 1 }),
    } });
    self.terminate(&builder, .{ .return_value = component_reference });

    const blocks = try self.allocator.alloc(Ir.Block, 1);
    blocks[0] = .{
        .instructions = try builder.blocks.items[0].instructions.toOwnedSlice(self.allocator),
        .terminator = builder.blocks.items[0].terminator orelse return error.InvalidSource,
    };

    return .{
        .name = method.name,
        .parameter_types = try self.allocator.dupe(Ast.Type, &.{ .address, entity_type }),
        .return_type = .address,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

fn analyzeWorld(self: anytype, structure_index: usize, method: Ast.Function) !Ir.Function {
    const world = self.program.structures[structure_index];
    const components_field = fieldNamed(world, "components") orelse return error.InvalidSource;
    const store_type = world.fields[components_field].type;
    const store_index = store_type.structureIndex() orelse return error.InvalidSource;
    const store = self.program.structures[store_index];
    const getter_name = try std.fmt.allocPrint(self.allocator, "get_mut<{s}>", .{self.typeName(method.return_type)});
    const getter = methodExact(store, getter_name) orelse return error.InvalidSource;

    var builder: Model.FunctionBuilder = .{ .return_type = .address };
    try builder.blocks.append(self.allocator, .{});
    try builder.value_types.append(self.allocator, .address);
    const entity_type = method.parameters[0].type;
    try builder.value_types.append(self.allocator, entity_type);
    const world_value = try self.newValue(&builder, .structure(structure_index));
    try self.emit(&builder, .{ .reference_load = .{ .result = world_value, .reference = 0 } });
    const store_value = try self.newValue(&builder, store_type);
    try self.emit(&builder, .{ .field_load = .{ .result = store_value, .base = world_value, .field = components_field } });
    const store_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, store_type);
    try self.emit(&builder, .{ .local_store = .{ .local = store_local, .operand = store_value } });
    const store_reference = try self.newValue(&builder, .address);
    try self.emit(&builder, .{ .local_address = .{ .result = store_reference, .local = store_local } });
    const component_reference = try self.newValue(&builder, .address);
    try self.emit(&builder, .{ .call = .{
        .result = component_reference,
        .function = methodFunctionId(self.program, store_index, getter),
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{ store_reference, 1 }),
    } });
    self.terminate(&builder, .{ .return_value = component_reference });
    const blocks = try self.allocator.alloc(Ir.Block, 1);
    blocks[0] = .{
        .instructions = try builder.blocks.items[0].instructions.toOwnedSlice(self.allocator),
        .terminator = builder.blocks.items[0].terminator orelse return error.InvalidSource,
    };
    return .{
        .name = method.name,
        .parameter_types = try self.allocator.dupe(Ast.Type, &.{ .address, entity_type }),
        .return_type = .address,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

fn poolSlot(self: anytype, resources: Ast.Structure, component: Ast.Type) ?usize {
    for (resources.fields, 0..) |field, index| {
        const child = field.type.optionalChild() orelse continue;
        const pool = self.program.structures[child.structureIndex() orelse continue];
        if (!std.mem.startsWith(u8, pool.name, pool_prefix)) continue;
        const values = fieldNamed(pool, "values") orelse continue;
        const collection = self.structures[pool.fields[values].type.structureIndex().?].collection orelse continue;
        if (collection.element == component) return index;
    }
    return null;
}

fn fieldNamed(structure: Ast.Structure, name: []const u8) ?usize {
    for (structure.fields, 0..) |field, index| if (std.mem.eql(u8, field.name, name)) return index;
    return null;
}

fn methodExact(structure: Ast.Structure, name: []const u8) ?usize {
    for (structure.methods, 0..) |method, index| if (std.mem.eql(u8, method.name, name)) return index;
    return null;
}

fn methodPrefixed(structure: Ast.Structure, prefix: []const u8, type_name: []const u8) ?usize {
    for (structure.methods, 0..) |method, index| {
        if (std.mem.startsWith(u8, method.name, prefix) and std.mem.indexOf(u8, method.name, type_name) != null) return index;
    }
    return null;
}

fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| {
        if (!structure.is_protocol) result += structure.methods.len;
    }
    return result + method_index;
}
