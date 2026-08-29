const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Ownership = @import("Resources.zig");
const GenericResources = @import("../Generics/TypedResources.zig");

pub fn analyze(self: anytype, structure_index: usize, method_index: usize, method: Ast.Function) !Ir.Function {
    const intrinsic = method.intrinsic orelse return error.InvalidSource;
    const structure_type = Ast.Type.structure(structure_index);
    const borrowed_mutable = method.return_mode == .mutable;
    const flat = flatMethodIndex(self.program, structure_index, method_index);
    const ir_return_type = methodReturnType(self, structure_index, flat, method);
    var builder: Model.FunctionBuilder = .{ .return_type = if (borrowed_mutable) method.return_type else method.return_type };
    try builder.blocks.append(self.allocator, .{});

    const parameter_types = try self.allocator.alloc(Ast.Type, method.parameters.len + 1);
    parameter_types[0] = if (borrowed_mutable) .address else structure_type;
    try builder.value_types.append(self.allocator, parameter_types[0]);
    for (method.parameters, 0..) |parameter, index| {
        parameter_types[index + 1] = parameter.type;
        try builder.value_types.append(self.allocator, parameter.type);
    }

    switch (intrinsic) {
        .resource_scope => try emitScope(self, &builder, structure_index),
        .resource_insert => |field| try emitInsert(self, &builder, structure_index, field, method),
        .resource_discard => try emitDiscard(self, &builder, method),
        .resource_has => |field| try emitHas(self, &builder, structure_index, field),
        .resource_get => |field| try emitGet(self, &builder, structure_index, field, method, false),
        .resource_get_mut => |field| try emitGet(self, &builder, structure_index, field, method, true),
        .resource_try_get => |field| try emitTryGet(self, &builder, structure_index, field, false),
        .resource_try_get_mut => |field| try emitTryGet(self, &builder, structure_index, field, true),
        .resource_remove => |field| try emitRemove(self, &builder, structure_index, field, flat),
        .resource_clear => try emitClear(self, &builder, structure_index),
        .component_get_mut => return error.InvalidSource,
        .world_component_get_mut => return error.InvalidSource,
        .system_adapter => return error.InvalidSource,
    }

    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, index| blocks[index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}#{d}", .{ self.program.structures[structure_index].name, method.name, method_index }),
        .parameter_types = parameter_types,
        .return_type = ir_return_type,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

fn emitScope(self: anytype, builder: anytype, structure: usize) !void {
    const fields = self.structures[structure].fields;
    const parent_field = parentField(self, structure) orelse return error.InvalidSource;
    var values = try self.allocator.alloc(Ir.ValueId, fields.len);
    for (fields, 0..) |field, index| {
        if (index == parent_field) {
            const parent = try self.newValue(builder, field.type);
            try self.emit(builder, .{ .optional_some = .{ .result = parent, .operand = 0 } });
            values[index] = parent;
        } else if (std.mem.eql(u8, field.name, GenericResources.order_field_name)) {
            values[index] = try emptyList(self, builder, field.type);
        } else {
            const empty = try self.newValue(builder, field.type);
            try self.emit(builder, .{ .optional_null = .{ .result = empty } });
            values[index] = empty;
        }
    }
    try Ownership.retainValueOwned(self, builder, .structure(structure), 0, .edge);
    const child = try self.newValue(builder, .structure(structure));
    try self.emit(builder, .{ .structure_init = .{ .result = child, .structure = structure, .fields = values } });
    self.terminate(builder, .{ .return_value = child });
}

fn emitDiscard(self: anytype, builder: anytype, method: Ast.Function) !void {
    const discarded_type = method.parameters[0].type;
    if (Ownership.needsDrop(self, discarded_type) or Ownership.containsClass(self, discarded_type)) {
        try Ownership.emitDrop(self, builder, discarded_type, 1);
    }
    self.terminate(builder, .return_void);
}

fn emitInsert(self: anytype, builder: anytype, structure: usize, field: usize, method: Ast.Function) !void {
    const slot_type = self.structures[structure].fields[field].type;
    const resource_type = slot_type.optionalChild() orelse return error.InvalidSource;
    try Ownership.validateStoredType(self, resource_type, method.name_position, "in Resources");
    const previous = try loadField(self, builder, structure, field, slot_type, 0);
    const order_field = orderField(self, structure) orelse return error.InvalidSource;
    const order_type = self.structures[structure].fields[order_field].type;
    const order = try loadField(self, builder, structure, order_field, order_type, 0);
    const resource_id = try constantInt(self, builder, field);
    const updated_order = try self.newValue(builder, order_type);
    try self.emit(builder, .{ .list_edit = .{
        .result = updated_order,
        .collection = order,
        .kind = .append,
        .argument = resource_id,
        .position = method.name_position,
    } });
    const order_result = try self.newValue(builder, .structure(structure));
    try self.emit(builder, .{ .field_store = .{
        .result = order_result,
        .base = 0,
        .field = order_field,
        .replacement = updated_order,
    } });
    const replacement = try self.newValue(builder, slot_type);
    try self.emit(builder, .{ .optional_some = .{ .result = replacement, .operand = 1 } });
    const result = try self.newValue(builder, .structure(structure));
    try self.emit(builder, .{ .field_store = .{ .result = result, .base = order_result, .field = field, .replacement = replacement } });
    if (Ownership.needsDrop(self, slot_type) or Ownership.containsClass(self, slot_type)) {
        try Ownership.emitDrop(self, builder, slot_type, previous);
    }
    self.terminate(builder, .{ .return_value = result });
}

fn emitHas(self: anytype, builder: anytype, structure: usize, field: usize) !void {
    const slot_type = self.structures[structure].fields[field].type;
    const slot = try loadField(self, builder, structure, field, slot_type, 0);
    const null_value = try self.newValue(builder, slot_type);
    try self.emit(builder, .{ .optional_null = .{ .result = null_value } });
    const present = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .binary = .{ .result = present, .operator = .not_equal, .left = slot, .right = null_value } });
    const local = try self.newBlock(builder);
    const fallback = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = local, .else_block = fallback } });
    builder.current_block = local;
    self.terminate(builder, .{ .return_value = present });
    builder.current_block = fallback;
    try emitParentCallOrValue(self, builder, structure, field, .has, .bool, false, present);
}

fn emitGet(self: anytype, builder: anytype, structure: usize, field: usize, method: Ast.Function, mutable: bool) !void {
    const slot_type = self.structures[structure].fields[field].type;
    const resource_type = slot_type.optionalChild() orelse return error.InvalidSource;
    const slot_reference = if (mutable) try fieldReference(self, builder, structure, field, 0) else null;
    const receiver = if (mutable) receiver: {
        const loaded = try self.newValue(builder, .structure(structure));
        try self.emit(builder, .{ .reference_load = .{ .result = loaded, .reference = 0 } });
        break :receiver loaded;
    } else 0;
    const slot = try loadField(self, builder, structure, field, slot_type, receiver);
    const present = try presence(self, builder, slot_type, slot);
    const found = try self.newBlock(builder);
    const missing = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = found, .else_block = missing } });

    builder.current_block = missing;
    if (parentField(self, structure) != null) {
        const no_parent = try self.newBlock(builder);
        try emitParentCallOrBranch(self, builder, structure, field, if (mutable) .get_mut else .get, if (mutable) .address else resource_type, mutable, no_parent);
        builder.current_block = no_parent;
    }
    const message = try self.newValue(builder, .str);
    try self.emit(builder, .{ .constant_str = .{
        .result = message,
        .value = try std.fmt.allocPrint(self.allocator, "resource '{s}' is not present", .{self.typeName(resource_type)}),
    } });
    self.terminate(builder, .{ .panic = .{ .message = message, .position = method.name_position } });

    builder.current_block = found;
    if (mutable) {
        const payload = try self.newValue(builder, .address);
        try self.emit(builder, .{ .reference_optional = .{ .result = payload, .reference = slot_reference.? } });
        self.terminate(builder, .{ .return_value = payload });
    } else {
        const payload = try self.newValue(builder, resource_type);
        try self.emit(builder, .{ .optional_unwrap = .{ .result = payload, .operand = slot } });
        self.terminate(builder, .{ .return_value = payload });
    }
}

fn emitTryGet(self: anytype, builder: anytype, structure: usize, field: usize, mutable: bool) !void {
    if (mutable) {
        const reference = try fieldReference(self, builder, structure, field, 0);
        const slot_type = self.structures[structure].fields[field].type;
        const slot = try loadField(self, builder, structure, field, slot_type, try loadReceiver(self, builder, structure, 0));
        const present = try presence(self, builder, slot_type, slot);
        const local = try self.newBlock(builder);
        const fallback = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = local, .else_block = fallback } });
        builder.current_block = local;
        self.terminate(builder, .{ .return_value = reference });
        builder.current_block = fallback;
        try emitParentCallOrValue(self, builder, structure, field, .try_get_mut, .address, true, reference);
        return;
    }
    const slot_type = self.structures[structure].fields[field].type;
    const slot = try loadField(self, builder, structure, field, slot_type, 0);
    const present = try presence(self, builder, slot_type, slot);
    const local = try self.newBlock(builder);
    const fallback = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = local, .else_block = fallback } });
    builder.current_block = local;
    self.terminate(builder, .{ .return_value = slot });
    builder.current_block = fallback;
    try emitParentCallOrValue(self, builder, structure, field, .try_get, slot_type, false, slot);
}

fn emitRemove(self: anytype, builder: anytype, structure: usize, field: usize, flat: usize) !void {
    const slot_type = self.structures[structure].fields[field].type;
    const slot = try loadField(self, builder, structure, field, slot_type, 0);
    const null_value = try self.newValue(builder, slot_type);
    try self.emit(builder, .{ .optional_null = .{ .result = null_value } });
    const result = try self.newValue(builder, .structure(structure));
    try self.emit(builder, .{ .field_store = .{ .result = result, .base = 0, .field = field, .replacement = null_value } });
    const result_type = methodResultType(self.program, self.method_mutability, self.program.type_names.len, flat) orelse return error.InvalidSource;
    const returned = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .structure_init = .{
        .result = returned,
        .structure = result_type.structureIndex().?,
        .fields = try self.allocator.dupe(Ir.ValueId, &.{ result, slot }),
    } });
    self.terminate(builder, .{ .return_value = returned });
}

fn emitClear(self: anytype, builder: anytype, structure: usize) !void {
    const order_field = orderField(self, structure) orelse return error.InvalidSource;
    const order_type = self.structures[structure].fields[order_field].type;
    const order = try loadField(self, builder, structure, order_field, order_type, 0);
    const count = try self.newValue(builder, .int);
    try self.emit(builder, .{ .collection_count = .{ .result = count, .collection = order } });
    const one = try constantInt(self, builder, 1);
    const last = try self.newValue(builder, .int);
    try self.emit(builder, .{ .binary = .{ .result = last, .operator = .subtract, .left = count, .right = one } });
    const index_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .int);
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = last } });

    const header = try self.newBlock(builder);
    const body = try self.newBlock(builder);
    const finish = try self.newBlock(builder);
    const decrement = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = header });

    builder.current_block = header;
    const index = try loadLocal(self, builder, index_local, .int);
    const zero = try constantInt(self, builder, 0);
    const has_next = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .binary = .{ .result = has_next, .operator = .greater_equal, .left = index, .right = zero } });
    self.terminate(builder, .{ .branch = .{ .condition = has_next, .then_block = body, .else_block = finish } });

    builder.current_block = body;
    const current_order = try loadField(self, builder, structure, order_field, order_type, 0);
    const current_index = try loadLocal(self, builder, index_local, .int);
    const resource_id = try self.newValue(builder, .int);
    try self.emit(builder, .{ .collection_load = .{
        .result = resource_id,
        .collection = current_order,
        .index = current_index,
        .position = self.program.structures[structure].position,
    } });

    for (self.structures[structure].fields, 0..) |field, field_index| {
        if (!std.mem.startsWith(u8, field.name, GenericResources.slot_prefix)) continue;
        const destroy = try self.newBlock(builder);
        const next = try self.newBlock(builder);
        const expected = try constantInt(self, builder, field_index);
        const matches = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .binary = .{ .result = matches, .operator = .equal, .left = resource_id, .right = expected } });
        self.terminate(builder, .{ .branch = .{ .condition = matches, .then_block = destroy, .else_block = next } });

        builder.current_block = destroy;
        const previous = try loadField(self, builder, structure, field_index, field.type, 0);
        const present = try presence(self, builder, field.type, previous);
        const drop_block = try self.newBlock(builder);
        const skip_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = drop_block, .else_block = skip_block } });

        builder.current_block = drop_block;
        const null_value = try self.newValue(builder, field.type);
        try self.emit(builder, .{ .optional_null = .{ .result = null_value } });
        const result = try self.newValue(builder, .structure(structure));
        try self.emit(builder, .{ .field_store = .{
            .result = result,
            .base = 0,
            .field = field_index,
            .replacement = null_value,
        } });
        if (Ownership.needsDrop(self, field.type) or Ownership.containsClass(self, field.type)) {
            try Ownership.emitDrop(self, builder, field.type, previous);
        }
        self.terminate(builder, .{ .jump = decrement });

        builder.current_block = skip_block;
        self.terminate(builder, .{ .jump = decrement });
        builder.current_block = next;
    }
    self.terminate(builder, .{ .jump = decrement });

    builder.current_block = decrement;
    const previous_index = try loadLocal(self, builder, index_local, .int);
    const decremented = try self.newValue(builder, .int);
    try self.emit(builder, .{ .binary = .{ .result = decremented, .operator = .subtract, .left = previous_index, .right = one } });
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = decremented } });
    self.terminate(builder, .{ .jump = header });

    builder.current_block = finish;
    const final_order = try loadField(self, builder, structure, order_field, order_type, 0);
    const empty_order = try self.newValue(builder, order_type);
    try self.emit(builder, .{ .list_edit = .{
        .result = empty_order,
        .collection = final_order,
        .kind = .clear,
        .position = self.program.structures[structure].position,
    } });
    const order_result = try self.newValue(builder, .structure(structure));
    try self.emit(builder, .{ .field_store = .{
        .result = order_result,
        .base = 0,
        .field = order_field,
        .replacement = empty_order,
    } });
    self.terminate(builder, .{ .return_value = 0 });
}

fn loadField(self: anytype, builder: anytype, structure: usize, field: usize, type_value: Ast.Type, receiver: Ir.ValueId) !Ir.ValueId {
    _ = structure;
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .field_load = .{ .result = result, .base = receiver, .field = field } });
    return result;
}

fn fieldReference(self: anytype, builder: anytype, structure: usize, field: usize, receiver: Ir.ValueId) !Ir.ValueId {
    const result = try self.newValue(builder, .address);
    try self.emit(builder, .{ .reference_field = .{ .result = result, .reference = receiver, .structure = structure, .field = field } });
    return result;
}

fn presence(self: anytype, builder: anytype, slot_type: Ast.Type, slot: Ir.ValueId) !Ir.ValueId {
    const null_value = try self.newValue(builder, slot_type);
    try self.emit(builder, .{ .optional_null = .{ .result = null_value } });
    const result = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .binary = .{ .result = result, .operator = .not_equal, .left = slot, .right = null_value } });
    return result;
}

fn orderField(self: anytype, structure: usize) ?usize {
    for (self.structures[structure].fields, 0..) |field, index| {
        if (std.mem.eql(u8, field.name, GenericResources.order_field_name)) return index;
    }
    return null;
}

fn parentField(self: anytype, structure: usize) ?usize {
    for (self.structures[structure].fields, 0..) |field, index| {
        if (std.mem.eql(u8, field.name, GenericResources.parent_field_name)) return index;
    }
    return null;
}

fn emptyList(self: anytype, builder: anytype, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .list_init = .{ .result = result, .values = &.{} } });
    return result;
}

fn loadReceiver(self: anytype, builder: anytype, structure: usize, reference: Ir.ValueId) !Ir.ValueId {
    const result = try self.newValue(builder, .structure(structure));
    try self.emit(builder, .{ .reference_load = .{ .result = result, .reference = reference } });
    return result;
}

const ResourceLookup = enum { has, get, get_mut, try_get, try_get_mut };

fn emitParentCallOrValue(self: anytype, builder: anytype, structure: usize, field: usize, intrinsic: ResourceLookup, return_type: Ast.Type, mutable: bool, fallback_value: Ir.ValueId) !void {
    const no_parent = try self.newBlock(builder);
    try emitParentCallOrBranch(self, builder, structure, field, intrinsic, return_type, mutable, no_parent);
    builder.current_block = no_parent;
    self.terminate(builder, .{ .return_value = fallback_value });
}

fn emitParentCallOrBranch(self: anytype, builder: anytype, structure: usize, field: usize, intrinsic: ResourceLookup, return_type: Ast.Type, mutable: bool, no_parent: Ir.BlockId) !void {
    const parent_field = parentField(self, structure) orelse {
        self.terminate(builder, .{ .jump = no_parent });
        return;
    };
    const parent_type = self.structures[structure].fields[parent_field].type;
    const receiver = if (mutable) try loadReceiver(self, builder, structure, 0) else 0;
    const parent_optional = try loadField(self, builder, structure, parent_field, parent_type, receiver);
    const present = try presence(self, builder, parent_type, parent_optional);
    const found = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = found, .else_block = no_parent } });
    builder.current_block = found;
    const parent = try self.newValue(builder, .structure(structure));
    try self.emit(builder, .{ .optional_unwrap = .{ .result = parent, .operand = parent_optional } });
    const method = intrinsicMethodIndex(self.program.structures[structure], intrinsic, field) orelse return error.InvalidSource;
    const argument = if (mutable) value: {
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, .structure(structure));
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = parent } });
        const address = try self.newValue(builder, .address);
        try self.emit(builder, .{ .local_address = .{ .result = address, .local = local } });
        break :value address;
    } else parent;
    const result = try self.newValue(builder, return_type);
    try self.emit(builder, .{ .call = .{ .result = result, .function = methodFunctionId(self.program, structure, method), .arguments = try self.allocator.dupe(Ir.ValueId, &.{argument}) } });
    self.terminate(builder, .{ .return_value = result });
}

fn intrinsicMethodIndex(structure: Ast.Structure, wanted: ResourceLookup, field: usize) ?usize {
    for (structure.methods, 0..) |method, index| {
        const candidate = method.intrinsic orelse continue;
        const matches = switch (candidate) {
            .resource_has => |candidate_field| wanted == .has and candidate_field == field,
            .resource_get => |candidate_field| wanted == .get and candidate_field == field,
            .resource_get_mut => |candidate_field| wanted == .get_mut and candidate_field == field,
            .resource_try_get => |candidate_field| wanted == .try_get and candidate_field == field,
            .resource_try_get_mut => |candidate_field| wanted == .try_get_mut and candidate_field == field,
            else => false,
        };
        if (matches) return index;
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

fn constantInt(self: anytype, builder: anytype, value: usize) !Ir.ValueId {
    const result = try self.newValue(builder, .int);
    try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = value } });
    return result;
}

fn loadLocal(self: anytype, builder: anytype, local: Ir.LocalId, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
    return result;
}

fn flatMethodIndex(program: Ast.Program, structure_index: usize, method_index: usize) usize {
    var result: usize = 0;
    for (program.structures[0..structure_index]) |structure| result += structure.methods.len;
    return result + method_index;
}

fn methodReturnType(self: anytype, structure_index: usize, flat: usize, method: Ast.Function) Ast.Type {
    if (method.return_mode == .mutable) return .address;
    if (!self.method_mutability[flat]) return method.return_type;
    if (method.return_type == .void) return .structure(structure_index);
    return methodResultType(self.program, self.method_mutability, self.program.type_names.len, flat).?;
}

fn methodResultType(program: Ast.Program, mutating: []const bool, base_count: usize, target_flat: usize) ?Ast.Type {
    var result = base_count;
    var flat: usize = 0;
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            if (flat == target_flat) return if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable) .structure(result) else null;
            if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable) result += 1;
            flat += 1;
        }
    }
    return null;
}
