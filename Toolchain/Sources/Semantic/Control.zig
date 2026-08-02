const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");
const Model = @import("Model.zig");
const Optionals = @import("Optionals.zig");
const Support = @import("Support.zig");
const Collections = @import("Collections.zig");
const Availability = @import("Availability.zig");
const Resources = @import("Resources.zig");

pub const ConditionalValue = struct {
    condition: Model.TypedValue,
    binding: ?BindingValue = null,
    expression: ?*Ast.Expression = null,
};

pub fn analyzeMutex(self: anytype, builder: anytype, function: Ast.Function, mutex: Ast.MutexStatement) !bool {
    try self.emit(builder, .mutex_lock);
    builder.mutex_depth += 1;
    defer builder.mutex_depth -= 1;

    const binding_count = builder.bindings.items.len;
    const terminated = try self.analyzeStatements(builder, function, mutex.statements);
    if (!terminated) {
        try Resources.emitActiveDrops(self, builder, binding_count);
        try self.emit(builder, .mutex_unlock);
    }
    builder.bindings.shrinkRetainingCapacity(binding_count);
    return terminated;
}

const BindingValue = struct {
    declaration: Ast.ConditionalBinding,
    source: Model.TypedValue,
    child_type: Ast.Type,
};

pub fn analyzeIf(self: anytype, builder: anytype, function: Ast.Function, conditional: Ast.IfStatement) !bool {
    var exits: std.ArrayList(Ir.BlockId) = .empty;
    var exit_availabilities: std.ArrayList([]const bool) = .empty;
    var fallthrough_refinements: std.ArrayList(Optionals.SavedRefinement) = .empty;
    const availability_count = builder.bindings.items.len;
    var fallthrough_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    for (conditional.branches) |branch| {
        Availability.restore(builder.bindings.items, fallthrough_availability);
        const analyzed = try analyzeCondition(self, builder, branch.condition, "if");
        fallthrough_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
        const proof = if (analyzed.expression) |expression| Optionals.presenceProof(expression) else null;

        const body_block = try self.newBlock(builder);
        const next_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{
            .condition = analyzed.condition.value,
            .then_block = body_block,
            .else_block = next_block,
        } });

        builder.current_block = body_block;
        const binding_count = builder.bindings.items.len;
        if (analyzed.binding) |binding| try enterBinding(self, builder, binding);
        const body_refinement = if (proof != null and proof.?.present_when_true)
            try Optionals.applyRefinement(self, builder, proof.?)
        else
            null;
        const terminated = try self.analyzeStatements(builder, function, branch.statements);
        if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
        builder.bindings.shrinkRetainingCapacity(binding_count);
        if (body_refinement) |saved| Optionals.restoreRefinement(builder, saved);
        if (!terminated) {
            try exits.append(self.allocator, builder.current_block);
            try exit_availabilities.append(self.allocator, try Availability.snapshot(self.allocator, builder.bindings.items, availability_count));
        }
        builder.current_block = next_block;
        Availability.restore(builder.bindings.items, fallthrough_availability);
        if (proof != null and !proof.?.present_when_true) {
            if (try Optionals.applyRefinement(self, builder, proof.?)) |saved| {
                try fallthrough_refinements.append(self.allocator, saved);
            }
        }
    }

    if (conditional.else_statements) |statements| {
        Availability.restore(builder.bindings.items, fallthrough_availability);
        const binding_count = builder.bindings.items.len;
        const terminated = try self.analyzeStatements(builder, function, statements);
        if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
        builder.bindings.shrinkRetainingCapacity(binding_count);
        if (!terminated) {
            try exits.append(self.allocator, builder.current_block);
            try exit_availabilities.append(self.allocator, try Availability.snapshot(self.allocator, builder.bindings.items, availability_count));
        }
    } else {
        try exits.append(self.allocator, builder.current_block);
        try exit_availabilities.append(self.allocator, fallthrough_availability);
    }

    var refinement_index = fallthrough_refinements.items.len;
    while (refinement_index != 0) {
        refinement_index -= 1;
        Optionals.restoreRefinement(builder, fallthrough_refinements.items[refinement_index]);
    }

    if (exits.items.len == 0) return true;
    const merged_availability = try self.allocator.dupe(bool, exit_availabilities.items[0]);
    for (exit_availabilities.items[1..]) |state| Availability.merge(merged_availability, state);
    Availability.restore(builder.bindings.items, merged_availability);
    const merge_block = try self.newBlock(builder);
    for (exits.items) |block_id| builder.blocks.items[block_id].terminator = .{ .jump = merge_block };
    builder.current_block = merge_block;
    return false;
}

pub fn analyzeWhile(self: anytype, builder: anytype, function: Ast.Function, loop: Ast.WhileStatement) !bool {
    const availability_count = builder.bindings.items.len;
    const header_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = condition_block;
    const analyzed = try analyzeCondition(self, builder, loop.condition, "while");
    const false_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    self.terminate(builder, .{ .branch = .{
        .condition = analyzed.condition.value,
        .then_block = body_block,
        .else_block = exit_block,
    } });

    builder.current_block = body_block;
    try builder.loops.append(self.allocator, .{
        .continue_block = condition_block,
        .break_block = exit_block,
        .availability_count = availability_count,
        .drop_binding_count = availability_count,
        .header_availability = header_availability,
        .mutex_depth = builder.mutex_depth,
    });
    const loop_index = builder.loops.items.len - 1;
    const binding_count = builder.bindings.items.len;
    if (analyzed.binding) |binding| try enterBinding(self, builder, binding);
    const terminated = try self.analyzeStatements(builder, function, loop.statements);
    if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    const loop_context = builder.loops.items[loop_index];
    builder.loops.items.len -= 1;
    if (!terminated) {
        try Availability.requireHeader(self, builder.bindings.items, header_availability, loop.position);
        self.terminate(builder, .{ .jump = condition_block });
    }

    builder.current_block = exit_block;
    const exit_availability = try self.allocator.dupe(bool, false_availability);
    for (loop_context.break_availabilities.items) |state| Availability.merge(exit_availability, state);
    Availability.restore(builder.bindings.items, exit_availability);
    return false;
}

pub fn analyzeFor(self: anytype, builder: anytype, function: Ast.Function, loop: Ast.ForStatement) !bool {
    if (loop.index_name) |name| {
        if (Support.findBinding(builder.bindings.items, name) != null) {
            const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{name});
            return self.fail(loop.index_position.?, message);
        }
    }
    const bindings = if (loop.bindings.len == 0)
        &[_]Ast.VariableDeclaration.DestructuredBinding{.{ .position = loop.name_position, .name = loop.name }}
    else
        loop.bindings;
    for (bindings) |binding| if (Support.findBinding(builder.bindings.items, binding.name) != null) {
        const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{binding.name});
        return self.fail(binding.position, message);
    };
    return switch (loop.source) {
        .collection => |source| analyzeCollectionFor(self, builder, function, loop, source),
        .range => |range| if (loop.index_name != null)
            self.fail(loop.index_position.?, "double for binding requires an indexed() array or list source")
        else
            analyzeRangeFor(self, builder, function, loop, range),
    };
}

fn analyzeCollectionFor(self: anytype, builder: anytype, function: Ast.Function, loop: Ast.ForStatement, source_expression: *Ast.Expression) !bool {
    const indexed_call: ?Ast.Expression.Call = if (source_expression.value == .call and
        std.mem.eql(u8, source_expression.value.call.name, "indexed"))
        source_expression.value.call
    else
        null;
    const collection_expression = if (loop.index_name != null) indexed: {
        const call = indexed_call orelse return self.fail(loop.index_position.?, "double for binding requires an indexed() array or list source");
        if (call.receiver == null or call.safe or call.arguments.len != 0 or call.named_arguments.len != 0 or call.type_arguments.len != 0) {
            return self.fail(call.name_position, "indexed() expects no arguments and a direct collection receiver");
        }
        break :indexed call.receiver.?;
    } else ordinary: {
        if (indexed_call) |call| return self.fail(call.name_position, "indexed() traversal requires two for bindings");
        break :ordinary source_expression;
    };
    const source = try self.analyzeExpression(builder, collection_expression);
    if (loop.index_name == null) {
        if (source.type.structureIndex()) |structure_index| {
            const structure = self.program.structures[structure_index];
            if (structure.query_pattern != null) return analyzeQueryFor(self, builder, function, loop, source_expression, source, structure);
        }
    }
    const collection = Collections.collectionForType(self.structures, source.type) orelse return self.fail(
        collection_expression.position,
        if (loop.index_name != null) "indexed() expects an array or list" else "for source expects an array or list",
    );
    if (loop.index_name != null and collection.view) return self.fail(collection_expression.position, "indexed() expects an array or list");
    const source_root: ?[]const u8 = switch (collection_expression.value) {
        .identifier => |name| name,
        else => null,
    };
    const outer_binding_count = builder.bindings.items.len;
    const collection_local: Ir.LocalId = if (loop.mode == .mutable) mutable: {
        const name = switch (collection_expression.value) {
            .identifier => |value| value,
            else => return self.fail(collection_expression.position, "for var requires a var collection binding"),
        };
        const binding = Support.findBinding(builder.bindings.items, name) orelse return self.fail(collection_expression.position, "unknown collection variable");
        if (!binding.mutable or binding.local == null) return self.fail(collection_expression.position, "for var requires a var collection binding");
        break :mutable binding.local.?;
    } else local: {
        const value = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, source.type);
        try self.emit(builder, .{ .local_store = .{ .local = value, .operand = source.value } });
        break :local value;
    };
    const owns_source = source_root == null and (Resources.needsDrop(self, source.type) or Resources.containsClass(self, source.type));
    if (owns_source) try builder.bindings.append(self.allocator, .{
        .name = "$for-source",
        .type = source.type,
        .local = collection_local,
    });
    const index_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .int);
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = try emitInt(self, builder, 0) } });
    const availability_count = builder.bindings.items.len;
    const header_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);

    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const update_block = try self.newBlock(builder);
    const break_update_block = if (loop.mode == .mutable) try self.newBlock(builder) else 0;
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = condition_block;
    const index = try loadLocalValue(self, builder, index_local, .int);
    const count = if (collection.length) |length| try emitInt(self, builder, length) else count: {
        const value = try loadLocalValue(self, builder, collection_local, source.type);
        const result = try self.newValue(builder, .int);
        try self.emit(builder, .{ .collection_count = .{ .result = result, .collection = value } });
        break :count result;
    };
    const condition = try emitBinary(self, builder, .less, index, count, .bool);
    self.terminate(builder, .{ .branch = .{ .condition = condition, .then_block = body_block, .else_block = exit_block } });

    builder.current_block = body_block;
    const collection_value = try loadLocalValue(self, builder, collection_local, source.type);
    const element = try self.newValue(builder, collection.element);
    try self.emit(builder, .{ .collection_load = .{ .result = element, .collection = collection_value, .index = index, .position = loop.position } });
    const binding_count = builder.bindings.items.len;
    if (loop.index_name) |name| try builder.bindings.append(self.allocator, .{
        .name = name,
        .type = .int,
        .value = index,
    });
    var element_local: ?Ir.LocalId = null;
    if (loop.mode == .mutable) {
        element_local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, collection.element);
        try self.emit(builder, .{ .local_store = .{ .local = element_local.?, .operand = element } });
        try builder.bindings.append(self.allocator, .{
            .name = loop.name,
            .type = collection.element,
            .local = element_local,
            .mutable = true,
        });
    } else try builder.bindings.append(self.allocator, .{
        .name = loop.name,
        .type = collection.element,
        .value = element,
    });
    try builder.loops.append(self.allocator, .{
        .continue_block = update_block,
        .break_block = if (loop.mode == .mutable) break_update_block else exit_block,
        .availability_count = availability_count,
        .drop_binding_count = if (loop.mode == .mutable) binding_count + 1 + @as(usize, @intFromBool(loop.index_name != null)) else binding_count,
        .header_availability = header_availability,
        .mutex_depth = builder.mutex_depth,
    });
    const loop_index = builder.loops.items.len - 1;
    const terminated = try self.analyzeStatements(builder, function, loop.statements);
    const loop_context = builder.loops.items[loop_index];
    builder.loops.items.len -= 1;
    if (!terminated) try Resources.emitActiveDrops(self, builder, if (loop.mode == .mutable) binding_count + 1 else binding_count);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    if (!terminated) {
        try Availability.requireHeader(self, builder.bindings.items, header_availability, loop.position);
        self.terminate(builder, .{ .jump = update_block });
    }

    builder.current_block = update_block;
    if (element_local) |local| try writeCollectionElement(self, builder, collection_local, source.type, index_local, local, collection.element, loop.position);
    const next = try emitBinary(
        self,
        builder,
        .add,
        try loadLocalValue(self, builder, index_local, .int),
        try emitInt(self, builder, 1),
        .int,
    );
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = next } });
    self.terminate(builder, .{ .jump = condition_block });

    if (element_local) |local| {
        builder.current_block = break_update_block;
        try writeCollectionElement(self, builder, collection_local, source.type, index_local, local, collection.element, loop.position);
        self.terminate(builder, .{ .jump = exit_block });
    }
    builder.current_block = exit_block;
    const exit_availability = try self.allocator.dupe(bool, header_availability);
    for (loop_context.break_availabilities.items) |state| Availability.merge(exit_availability, state);
    Availability.restore(builder.bindings.items, exit_availability);
    if (owns_source) {
        try Resources.emitActiveDrops(self, builder, outer_binding_count);
        builder.bindings.shrinkRetainingCapacity(outer_binding_count);
    }
    return false;
}

fn analyzeQueryFor(
    self: anytype,
    builder: anytype,
    function: Ast.Function,
    loop: Ast.ForStatement,
    source_expression: *Ast.Expression,
    source: Model.TypedValue,
    query: Ast.Structure,
) !bool {
    if (loop.bindings.len == 0) return self.fail(loop.name_position, "ECS.Query iteration requires tuple destructuring");
    const pattern_type = query.query_pattern.?;
    const pattern_index = pattern_type.structureIndex() orelse return error.InvalidSource;
    const pattern = self.program.structures[pattern_index];
    if (!pattern.is_tuple or pattern.fields.len != loop.bindings.len) {
        return self.fail(loop.name_position, "ECS.Query bindings must match its component access pattern");
    }
    if (query.fields.len != 1) return error.InvalidSource;
    const world_type = query.fields[0].type;
    const world_index = world_type.structureIndex() orelse return error.InvalidSource;
    const world = self.program.structures[world_index];
    const world_value = try self.newValue(builder, world_type);
    try self.emit(builder, .{ .field_load = .{ .result = world_value, .base = source.value, .field = 0 } });
    const records_field = fieldNamed(world, "records") orelse return error.InvalidSource;
    const records_type = world.fields[records_field].type;
    const records_collection = Collections.collectionForType(self.structures, records_type) orelse return error.InvalidSource;
    const record_type = records_collection.element;
    const record_index = record_type.structureIndex() orelse return error.InvalidSource;
    const record = self.program.structures[record_index];
    const generation_field = fieldNamed(record, "current_generation") orelse return error.InvalidSource;
    const alive_field = fieldNamed(record, "alive") orelse return error.InvalidSource;
    const components_field = fieldNamed(record, "component_store") orelse return error.InvalidSource;
    const resources_type = record.fields[components_field].type;
    const resources_index = resources_type.structureIndex() orelse return error.InvalidSource;
    const resources = self.program.structures[resources_index];
    const records_value = try self.newValue(builder, records_type);
    try self.emit(builder, .{ .field_load = .{ .result = records_value, .base = world_value, .field = records_field } });
    const records_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, records_type);
    try self.emit(builder, .{ .local_store = .{ .local = records_local, .operand = records_value } });

    const index_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .int);
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = try emitInt(self, builder, 0) } });
    const availability_count = builder.bindings.items.len;
    const header_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    const condition_block = try self.newBlock(builder);
    const candidate_block = try self.newBlock(builder);
    const components_block = try self.newBlock(builder);
    const matched_block = try self.newBlock(builder);
    const update_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = condition_block;
    const index = try loadLocalValue(self, builder, index_local, .int);
    const records = try loadLocalValue(self, builder, records_local, records_type);
    const count = try self.newValue(builder, .int);
    try self.emit(builder, .{ .collection_count = .{ .result = count, .collection = records } });
    const has_entity = try emitBinary(self, builder, .less, index, count, .bool);
    self.terminate(builder, .{ .branch = .{ .condition = has_entity, .then_block = candidate_block, .else_block = exit_block } });

    builder.current_block = candidate_block;
    const record_value = try self.newValue(builder, record_type);
    try self.emit(builder, .{ .collection_load = .{
        .result = record_value,
        .collection = records,
        .index = index,
        .position = loop.position,
    } });
    const alive = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .field_load = .{ .result = alive, .base = record_value, .field = alive_field } });
    self.terminate(builder, .{ .branch = .{ .condition = alive, .then_block = components_block, .else_block = update_block } });

    builder.current_block = components_block;
    const components = try self.newValue(builder, resources_type);
    try self.emit(builder, .{ .field_load = .{ .result = components, .base = record_value, .field = components_field } });
    const components_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, resources_type);
    try self.emit(builder, .{ .local_store = .{ .local = components_local, .operand = components } });
    var component_count: usize = 0;
    for (pattern.fields) |field| {
        if (!isEntityType(self, field.type)) component_count += 1;
    }
    if (component_count == 0) self.terminate(builder, .{ .jump = matched_block });
    var component_index: usize = 0;
    for (pattern.fields) |field| {
        if (isEntityType(self, field.type)) continue;
        const has_name = try std.fmt.allocPrint(self.allocator, "has<{s}>", .{self.typeName(field.type)});
        const has_method = methodNamed(resources, has_name) orelse return error.InvalidSource;
        const current_components = try loadLocalValue(self, builder, components_local, resources_type);
        const present = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .call = .{
            .result = present,
            .function = methodFunctionId(self.program, resources_index, has_method),
            .arguments = try self.allocator.dupe(Ir.ValueId, &.{current_components}),
        } });
        component_index += 1;
        const next_match = if (component_index == component_count) matched_block else try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = next_match, .else_block = update_block } });
        builder.current_block = next_match;
    }
    const binding_count = builder.bindings.items.len;
    const root = switch (source_expression.value) {
        .identifier => |name| name,
        else => "$query",
    };
    for (pattern.fields, loop.bindings) |field, binding| {
        if (isEntityType(self, field.type)) {
            const generation = try self.newValue(builder, .int);
            try self.emit(builder, .{ .field_load = .{ .result = generation, .base = record_value, .field = generation_field } });
            const entity = try self.newValue(builder, field.type);
            try self.emit(builder, .{ .structure_init = .{
                .result = entity,
                .structure = field.type.structureIndex().?,
                .fields = try self.allocator.dupe(Ir.ValueId, &.{ index, generation }),
            } });
            try builder.bindings.append(self.allocator, .{ .name = binding.name, .type = field.type, .value = entity });
            continue;
        }
        const getter_name = try std.fmt.allocPrint(
            self.allocator,
            "{s}<{s}>",
            .{ if (field.access_mode == .mutable) "get_mut" else "get", self.typeName(field.type) },
        );
        if (field.access_mode == .mutable) {
            const getter_index = methodNamed(resources, getter_name) orelse return error.InvalidSource;
            const components_reference = try self.newValue(builder, .address);
            try self.emit(builder, .{ .local_address = .{ .result = components_reference, .local = components_local } });
            const reference = try self.newValue(builder, .address);
            try self.emit(builder, .{ .call = .{
                .result = reference,
                .function = methodFunctionId(self.program, resources_index, getter_index),
                .arguments = try self.allocator.dupe(Ir.ValueId, &.{components_reference}),
            } });
            try builder.bindings.append(self.allocator, .{
                .name = binding.name,
                .type = field.type,
                .reference = reference,
                .mutable = true,
                .borrowed_root = root,
                .borrowed_mode = .mutable,
            });
        } else {
            const getter_index = methodNamed(resources, getter_name) orelse return error.InvalidSource;
            const current_components = try loadLocalValue(self, builder, components_local, resources_type);
            const value = try self.newValue(builder, field.type);
            try self.emit(builder, .{ .call = .{
                .result = value,
                .function = methodFunctionId(self.program, resources_index, getter_index),
                .arguments = try self.allocator.dupe(Ir.ValueId, &.{current_components}),
            } });
            try builder.bindings.append(self.allocator, .{
                .name = binding.name,
                .type = field.type,
                .value = value,
                .borrowed_root = root,
                .borrowed_mode = .read,
            });
        }
    }
    try builder.loops.append(self.allocator, .{
        .continue_block = update_block,
        .break_block = exit_block,
        .availability_count = availability_count,
        .drop_binding_count = binding_count,
        .header_availability = header_availability,
        .mutex_depth = builder.mutex_depth,
    });
    const loop_index = builder.loops.items.len - 1;
    const terminated = try self.analyzeStatements(builder, function, loop.statements);
    const loop_context = builder.loops.items[loop_index];
    builder.loops.items.len -= 1;
    if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    if (!terminated) self.terminate(builder, .{ .jump = update_block });

    builder.current_block = update_block;
    const next = try emitBinary(
        self,
        builder,
        .add,
        try loadLocalValue(self, builder, index_local, .int),
        try emitInt(self, builder, 1),
        .int,
    );
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = next } });
    self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = exit_block;
    const exit_availability = try self.allocator.dupe(bool, header_availability);
    for (loop_context.break_availabilities.items) |state| Availability.merge(exit_availability, state);
    Availability.restore(builder.bindings.items, exit_availability);
    return false;
}

fn fieldNamed(structure: Ast.Structure, name: []const u8) ?usize {
    for (structure.fields, 0..) |field, index| if (std.mem.eql(u8, field.name, name)) return index;
    return null;
}

fn isEntityType(self: anytype, type_value: Ast.Type) bool {
    return std.mem.eql(u8, self.typeName(type_value), "GFX.ECS.Entity");
}

fn methodNamed(structure: Ast.Structure, name: []const u8) ?usize {
    for (structure.methods, 0..) |method, index| if (std.mem.eql(u8, method.name, name)) return index;
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

fn analyzeRangeFor(self: anytype, builder: anytype, function: Ast.Function, loop: Ast.ForStatement, range: Ast.ForStatement.Range) !bool {
    const start = try self.analyzeExpression(builder, range.start);
    const end = try self.analyzeExpression(builder, range.end);
    if (start.type != .int or end.type != .int) return self.fail(loop.position, "range bounds expect 'int'");
    const current_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .int);
    const end_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .int);
    const step_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .int);
    try self.emit(builder, .{ .local_store = .{ .local = current_local, .operand = start.value } });
    try self.emit(builder, .{ .local_store = .{ .local = end_local, .operand = end.value } });
    try self.emit(builder, .{ .local_store = .{ .local = step_local, .operand = try emitInt(self, builder, std.math.maxInt(u64)) } });
    const availability_count = builder.bindings.items.len;
    const header_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    const ascending_block = try self.newBlock(builder);
    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const update_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    const ascending = try emitBinary(self, builder, .less, start.value, end.value, .bool);
    self.terminate(builder, .{ .branch = .{ .condition = ascending, .then_block = ascending_block, .else_block = condition_block } });
    builder.current_block = ascending_block;
    try self.emit(builder, .{ .local_store = .{ .local = step_local, .operand = try emitInt(self, builder, 1) } });
    self.terminate(builder, .{ .jump = condition_block });

    builder.current_block = condition_block;
    const current = try loadLocalValue(self, builder, current_local, .int);
    const limit = try loadLocalValue(self, builder, end_local, .int);
    const condition = try emitBinary(self, builder, .not_equal, current, limit, .bool);
    self.terminate(builder, .{ .branch = .{ .condition = condition, .then_block = body_block, .else_block = exit_block } });
    builder.current_block = body_block;
    const binding_count = builder.bindings.items.len;
    if (loop.mode == .mutable) {
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, .int);
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = current } });
        try builder.bindings.append(self.allocator, .{ .name = loop.name, .type = .int, .local = local, .mutable = true });
    } else try builder.bindings.append(self.allocator, .{ .name = loop.name, .type = .int, .value = current });
    try builder.loops.append(self.allocator, .{
        .continue_block = update_block,
        .break_block = exit_block,
        .availability_count = availability_count,
        .drop_binding_count = availability_count,
        .header_availability = header_availability,
        .mutex_depth = builder.mutex_depth,
    });
    const loop_index = builder.loops.items.len - 1;
    const terminated = try self.analyzeStatements(builder, function, loop.statements);
    const loop_context = builder.loops.items[loop_index];
    builder.loops.items.len -= 1;
    if (!terminated) try Resources.emitActiveDrops(self, builder, binding_count);
    builder.bindings.shrinkRetainingCapacity(binding_count);
    if (!terminated) {
        try Availability.requireHeader(self, builder.bindings.items, header_availability, loop.position);
        self.terminate(builder, .{ .jump = update_block });
    }
    builder.current_block = update_block;
    const next = try emitBinary(self, builder, .add, try loadLocalValue(self, builder, current_local, .int), try loadLocalValue(self, builder, step_local, .int), .int);
    try self.emit(builder, .{ .local_store = .{ .local = current_local, .operand = next } });
    self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = exit_block;
    const exit_availability = try self.allocator.dupe(bool, header_availability);
    for (loop_context.break_availabilities.items) |state| Availability.merge(exit_availability, state);
    Availability.restore(builder.bindings.items, exit_availability);
    return false;
}

fn writeCollectionElement(self: anytype, builder: anytype, collection_local: Ir.LocalId, collection_type: Ast.Type, index_local: Ir.LocalId, element_local: Ir.LocalId, element_type: Ast.Type, position: Source.Position) !void {
    const collection = try loadLocalValue(self, builder, collection_local, collection_type);
    const index = try loadLocalValue(self, builder, index_local, .int);
    const element = try loadLocalValue(self, builder, element_local, element_type);
    if (Resources.containsClass(self, element_type)) try Resources.retainValue(self, builder, element_type, element);
    if (Resources.needsDrop(self, element_type) or Resources.containsClass(self, element_type)) {
        const previous = try self.newValue(builder, element_type);
        try self.emit(builder, .{ .collection_load = .{ .result = previous, .collection = collection, .index = index, .position = position } });
        try Resources.emitDrop(self, builder, element_type, previous);
    }
    const updated = try self.newValue(builder, collection_type);
    try self.emit(builder, .{ .collection_replace = .{ .result = updated, .collection = collection, .index = index, .replacement = element, .position = position } });
    try self.emit(builder, .{ .local_store = .{ .local = collection_local, .operand = updated } });
    if (Resources.needsDrop(self, element_type) or Resources.containsClass(self, element_type)) {
        try Resources.emitDrop(self, builder, element_type, element);
    }
}

fn emitInt(self: anytype, builder: anytype, bits: u64) !Ir.ValueId {
    const result = try self.newValue(builder, .int);
    try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = bits } });
    return result;
}

fn loadLocalValue(self: anytype, builder: anytype, local: Ir.LocalId, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
    return result;
}

fn emitBinary(self: anytype, builder: anytype, operator: Ir.BinaryOperator, left: Ir.ValueId, right: Ir.ValueId, type_value: Ast.Type) !Ir.ValueId {
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .binary = .{ .result = result, .operator = operator, .left = left, .right = right } });
    return result;
}

pub fn analyzeCondition(self: anytype, builder: anytype, condition: Ast.Condition, keyword: []const u8) !ConditionalValue {
    return switch (condition) {
        .expression => |expression| expression_condition: {
            const value = try self.analyzeExpression(builder, expression);
            if (value.type != .bool) {
                const message = try std.fmt.allocPrint(self.allocator, "{s} condition expects 'bool'", .{keyword});
                return self.fail(expression.position, message);
            }
            break :expression_condition .{ .condition = value, .expression = expression };
        },
        .binding => |binding| binding_condition: {
            if (Support.findBinding(builder.bindings.items, binding.name) != null) {
                const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{binding.name});
                return self.fail(binding.name_position, message);
            }
            const source = try self.analyzeExpression(builder, binding.source);
            const child = source.type.optionalChild() orelse {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "conditional binding '{s}' expects an optional source, found '{s}'",
                    .{ binding.name, self.typeName(source.type) },
                );
                return self.fail(binding.source.position, message);
            };
            const absent = (try Optionals.intrinsic(self, builder, source.type)).?;
            const result = try self.newValue(builder, .bool);
            try self.emit(builder, .{ .binary = .{
                .result = result,
                .operator = .not_equal,
                .left = source.value,
                .right = absent.value,
            } });
            break :binding_condition .{
                .condition = .{ .type = .bool, .value = result },
                .binding = .{ .declaration = binding, .source = source, .child_type = child },
            };
        },
    };
}

pub fn enterBinding(self: anytype, builder: anytype, binding: BindingValue) !void {
    const value = try self.newValue(builder, binding.child_type);
    try self.emit(builder, .{ .optional_unwrap = .{ .result = value, .operand = binding.source.value } });
    if (binding.declaration.mutable) {
        const local = builder.local_types.items.len;
        try builder.local_types.append(self.allocator, binding.child_type);
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = value } });
        try builder.bindings.append(self.allocator, .{
            .name = binding.declaration.name,
            .type = binding.child_type,
            .local = local,
            .mutable = true,
        });
    } else try builder.bindings.append(self.allocator, .{
        .name = binding.declaration.name,
        .type = binding.child_type,
        .value = value,
    });
}

pub fn analyzeLoopControl(
    self: anytype,
    builder: anytype,
    position: Source.Position,
    is_continue: bool,
) !bool {
    if (builder.loops.items.len == 0) {
        return self.fail(position, if (is_continue)
            "'continue' is only valid inside a loop"
        else
            "'break' is only valid inside a loop");
    }
    const loop = &builder.loops.items[builder.loops.items.len - 1];
    if (is_continue) {
        try Availability.requireHeader(self, builder.bindings.items, loop.header_availability, position);
    } else {
        try loop.break_availabilities.append(
            self.allocator,
            try Availability.snapshot(self.allocator, builder.bindings.items, loop.availability_count),
        );
    }
    try Resources.emitActiveDrops(self, builder, loop.drop_binding_count);
    try Resources.emitMutexUnlocks(self, builder, loop.mutex_depth);
    self.terminate(builder, .{ .jump = if (is_continue) loop.continue_block else loop.break_block });
    return true;
}
