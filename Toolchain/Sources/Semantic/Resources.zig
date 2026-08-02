const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");

const AnalyzeError = error{ InvalidSource, OutOfMemory };

pub fn needsDrop(self: anytype, type_value: Ast.Type) bool {
    return needsDropInner(self, type_value, 0);
}

pub fn isClassType(self: anytype, type_value: Ast.Type) bool {
    const index = type_value.structureIndex() orelse return false;
    return index < self.structures.len and self.structures[index].is_class;
}

pub fn containsClass(self: anytype, type_value: Ast.Type) bool {
    return containsClassInner(self, type_value, 0);
}

fn containsClassInner(self: anytype, type_value: Ast.Type, depth: usize) bool {
    if (depth > self.structures.len + self.enums.len + 1) return false;
    if (type_value.optionalChild()) |child| return containsClassInner(self, child, depth + 1);
    const index = type_value.structureIndex() orelse return false;
    if (index >= self.structures.len) return false;
    const structure = self.structures[index];
    if (structure.is_protocol) return true;
    if (structure.is_class) return true;
    if (structure.collection) |collection| {
        if (collection.view) return false;
        return containsClassInner(self, collection.element, depth + 1);
    }
    for (self.enums) |enumeration| if (enumeration.type_index == index) {
        for (enumeration.variants) |variant| for (variant.associated_types) |associated| {
            if (containsClassInner(self, associated, depth + 1)) return true;
        };
        return false;
    };
    for (structure.fields) |field| if (containsClassInner(self, field.type, depth + 1)) return true;
    return false;
}

fn needsDropInner(self: anytype, type_value: Ast.Type, depth: usize) bool {
    if (depth > self.structures.len + self.enums.len + 1) return false;
    if (type_value.optionalChild()) |child| return needsDropInner(self, child, depth + 1);
    const index = type_value.structureIndex() orelse return false;
    if (index >= self.structures.len) return false;
    if (self.structures[index].is_protocol) return false;
    if (self.structures[index].is_class) return false;
    if (self.structures[index].collection) |collection| {
        if (collection.view) return false;
        return needsDropInner(self, collection.element, depth + 1);
    }
    for (self.enums) |enumeration| if (enumeration.type_index == index) {
        for (enumeration.variants) |variant| for (variant.associated_types) |associated| {
            if (needsDropInner(self, associated, depth + 1)) return true;
        };
        return false;
    };
    const name = self.structures[index].name;
    for (self.program.structures) |structure| {
        if (!std.mem.eql(u8, structure.name, name)) continue;
        if (structure.drop != null) return true;
        for (self.structures[index].fields) |field| {
            if (needsDropInner(self, field.type, depth + 1)) return true;
        }
        return false;
    }
    return false;
}

pub fn validateParameter(self: anytype, parameter: Ast.Parameter) !void {
    if (isProtocolValue(self, parameter.type) and parameter.mode != .value) return self.fail(parameter.position, "dynamic protocol values cannot use '@' or '&'");
    const direct_view = @import("Collections.zig").isViewType(self.structures, parameter.type);
    if (containsView(self, parameter.type) and (!direct_view or parameter.mode == .value)) {
        return self.fail(parameter.position, "a view parameter must use '@T[..]' or '&T[..]'");
    }
}

pub fn validateReturn(self: anytype, function: Ast.Function) !void {
    if (isProtocolValue(self, function.return_type) and function.return_mode != .value) return self.fail(function.name_position, "dynamic protocol values cannot use '@' or '&'");
    const direct_view = @import("Collections.zig").isViewType(self.structures, function.return_type);
    if (containsView(self, function.return_type) and (!direct_view or function.return_mode == .value)) {
        return self.fail(function.name_position, "a view return must use '@T[..]' or '&T[..]' and name compatible provenance");
    }
}

pub fn validateStoredType(self: anytype, type_value: Ast.Type, position: @import("../Source.zig").Position, context: []const u8) !void {
    if (!containsView(self, type_value)) return;
    const message = try std.fmt.allocPrint(self.allocator, "a borrowed view cannot be stored {s}", .{context});
    return self.fail(position, message);
}

pub fn isProtocolValue(self: anytype, type_value: Ast.Type) bool {
    const child = type_value.optionalChild() orelse type_value;
    const index = child.structureIndex() orelse return false;
    return index < self.structures.len and self.structures[index].is_protocol;
}

fn containsView(self: anytype, type_value: Ast.Type) bool {
    if (type_value.optionalChild()) |child| return containsView(self, child);
    const index = type_value.structureIndex() orelse return false;
    if (index >= self.structures.len) return false;
    if (self.structures[index].collection) |collection| return collection.view or containsView(self, collection.element);
    return false;
}

pub fn analyzeDrop(self: anytype, structure_index: usize, declaration: Ast.Structure, drop: Ast.Drop) !Ir.Function {
    try validateDrop(self, drop);
    const previous_owner_context = self.owner_context;
    self.owner_context = declaration.owner;
    defer self.owner_context = previous_owner_context;
    const previous_context = self.member_context;
    self.member_context = structure_index;
    defer self.member_context = previous_context;
    const structure_type = Ast.Type.structure(structure_index);
    var builder: Model.FunctionBuilder = .{ .return_type = .void };
    try builder.blocks.append(self.allocator, .{});
    try builder.value_types.append(self.allocator, structure_type);
    try builder.bindings.append(self.allocator, .{
        .name = "self",
        .type = structure_type,
        .value = 0,
        .parameter = true,
    });
    const function: Ast.Function = .{
        .position = drop.position,
        .name_position = drop.position,
        .name = "$drop",
        .parameters = &.{},
        .return_type = .void,
        .statements = drop.statements,
    };
    if (!try self.analyzeStatements(&builder, function, drop.statements)) {
        try emitActiveDrops(self, &builder, 1);
        self.terminate(&builder, .return_void);
    }
    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, index| blocks[index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.$drop", .{declaration.name}),
        .parameter_types = try self.allocator.dupe(Ast.Type, &.{structure_type}),
        .return_type = .void,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

pub fn analyzeClassFields(self: anytype, structure_index: usize, declaration: Ast.Structure) !Ir.Function {
    const structure_type = Ast.Type.structure(structure_index);
    var builder: Model.FunctionBuilder = .{ .return_type = .void };
    try builder.blocks.append(self.allocator, .{});
    try builder.value_types.append(self.allocator, structure_type);
    var field_index = self.structures[structure_index].fields.len;
    while (field_index > 0) {
        field_index -= 1;
        const field = self.structures[structure_index].fields[field_index];
        if (!needsDrop(self, field.type) and !containsClass(self, field.type)) continue;
        const field_value = try self.newValue(&builder, field.type);
        try self.emit(&builder, .{ .field_load = .{ .result = field_value, .base = 0, .field = field_index } });
        try emitDrop(self, &builder, field.type, field_value);
    }
    self.terminate(&builder, .return_void);
    const blocks = try self.allocator.alloc(Ir.Block, builder.blocks.items.len);
    for (builder.blocks.items, 0..) |*block, block_index| blocks[block_index] = .{
        .instructions = try block.instructions.toOwnedSlice(self.allocator),
        .terminator = block.terminator orelse return error.InvalidSource,
    };
    return .{
        .name = try std.fmt.allocPrint(self.allocator, "{s}.$fields", .{declaration.name}),
        .parameter_types = try self.allocator.dupe(Ast.Type, &.{structure_type}),
        .return_type = .void,
        .value_types = try builder.value_types.toOwnedSlice(self.allocator),
        .local_types = try builder.local_types.toOwnedSlice(self.allocator),
        .blocks = blocks,
    };
}

pub fn emitDrop(self: anytype, builder: anytype, type_value: Ast.Type, value: Ir.ValueId) AnalyzeError!void {
    if (type_value.optionalChild()) |child| {
        if (!needsDrop(self, child) and !containsClass(self, child)) return;
        const absent = try self.newValue(builder, type_value);
        try self.emit(builder, .{ .optional_null = .{ .result = absent } });
        const present = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .binary = .{ .result = present, .operator = .not_equal, .left = value, .right = absent } });
        const drop_block = try self.newBlock(builder);
        const merge_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = drop_block, .else_block = merge_block } });
        builder.current_block = drop_block;
        const payload = try self.newValue(builder, child);
        try self.emit(builder, .{ .optional_unwrap = .{ .result = payload, .operand = value } });
        try emitDrop(self, builder, child, payload);
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = merge_block;
        return;
    }
    const type_index = type_value.structureIndex() orelse return;
    if (type_index >= self.structures.len) return;
    if (self.structures[type_index].is_protocol) return emitProtocolResource(self, builder, type_index, value, false);
    if (self.structures[type_index].is_class) {
        try self.emit(builder, .{ .class_drop = .{
            .operand = value,
            .plans = try classDropPlans(self, type_index),
        } });
        return;
    }
    if (enumIndex(self, type_index)) |enumeration_index| {
        try emitEnumDrop(self, builder, enumeration_index, value);
        return;
    }
    if (self.structures[type_index].collection) |collection| {
        if (collection.view) return;
        try emitCollectionDrop(self, builder, type_value, collection, value);
        return;
    }
    if (dropFunctionId(self, type_value)) |function| try self.emit(builder, .{ .call = .{
        .result = null,
        .function = function,
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{value}),
    } });
    var field_index = self.structures[type_index].fields.len;
    while (field_index > 0) {
        field_index -= 1;
        const field = self.structures[type_index].fields[field_index];
        if (!needsDrop(self, field.type) and !containsClass(self, field.type)) continue;
        const field_value = try self.newValue(builder, field.type);
        try self.emit(builder, .{ .field_load = .{ .result = field_value, .base = value, .field = field_index } });
        try emitDrop(self, builder, field.type, field_value);
    }
}

pub fn emitActiveDrops(self: anytype, builder: anytype, first_binding: usize) !void {
    var index = builder.bindings.items.len;
    while (index > first_binding) {
        index -= 1;
        const binding = builder.bindings.items[index];
        if (!binding.available or binding.borrowed_root != null or binding.parameter_mode != .value or
            std.mem.eql(u8, binding.name, "self") or
            (!needsDrop(self, binding.type) and !containsClass(self, binding.type))) continue;
        const value = if (binding.local) |local| value: {
            const loaded = try self.newValue(builder, binding.type);
            try self.emit(builder, .{ .local_load = .{ .result = loaded, .local = local } });
            break :value loaded;
        } else binding.value orelse continue;
        try emitDrop(self, builder, binding.type, value);
    }
}

pub fn emitMutexUnlocks(self: anytype, builder: anytype, target_depth: usize) !void {
    var depth = builder.mutex_depth;
    while (depth > target_depth) : (depth -= 1) {
        try self.emit(builder, .mutex_unlock);
    }
}

pub fn retainValue(self: anytype, builder: anytype, type_value: Ast.Type, value: Ir.ValueId) AnalyzeError!void {
    if (type_value.optionalChild()) |child| {
        if (!containsClass(self, child)) return;
        const absent = try self.newValue(builder, type_value);
        try self.emit(builder, .{ .optional_null = .{ .result = absent } });
        const present = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .binary = .{ .result = present, .operator = .not_equal, .left = value, .right = absent } });
        const retain_block = try self.newBlock(builder);
        const merge_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = present, .then_block = retain_block, .else_block = merge_block } });
        builder.current_block = retain_block;
        const payload = try self.newValue(builder, child);
        try self.emit(builder, .{ .optional_unwrap = .{ .result = payload, .operand = value } });
        try retainValue(self, builder, child, payload);
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = merge_block;
        return;
    }
    const type_index = type_value.structureIndex() orelse return;
    if (type_index >= self.structures.len) return;
    if (self.structures[type_index].is_protocol) return emitProtocolResource(self, builder, type_index, value, true);
    if (self.structures[type_index].is_class) {
        try self.emit(builder, .{ .class_retain = .{ .operand = value } });
        return;
    }
    if (self.structures[type_index].collection) |collection| {
        if (!collection.view) try emitCollectionRetain(self, builder, collection, value);
        return;
    }
    for (self.structures[type_index].fields, 0..) |field, field_index| {
        if (!containsClass(self, field.type)) continue;
        const field_value = try self.newValue(builder, field.type);
        try self.emit(builder, .{ .field_load = .{ .result = field_value, .base = value, .field = field_index } });
        try retainValue(self, builder, field.type, field_value);
    }
}

fn emitProtocolResource(self: anytype, builder: anytype, protocol_index: usize, value: Ir.ValueId, retain: bool) AnalyzeError!void {
    const ProtocolValues = @import("ProtocolValues.zig");
    const conformers = try ProtocolValues.conformers(self, protocol_index);
    if (conformers.len == 0) return;
    const merge_block = try self.newBlock(builder);
    for (conformers) |structure_index| {
        const action_block = try self.newBlock(builder);
        const next_block = try self.newBlock(builder);
        const matches = try ProtocolValues.emitTest(self, builder, value, structure_index);
        self.terminate(builder, .{ .branch = .{ .condition = matches, .then_block = action_block, .else_block = next_block } });
        builder.current_block = action_block;
        const concrete = try ProtocolValues.emitExtract(self, builder, value, structure_index);
        if (retain)
            try retainValue(self, builder, Ast.Type.structure(structure_index), concrete)
        else
            try emitDrop(self, builder, Ast.Type.structure(structure_index), concrete);
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = next_block;
    }
    self.terminate(builder, .{ .jump = merge_block });
    builder.current_block = merge_block;
}

fn classDropPlans(self: anytype, static_type: usize) ![]const Ir.Instruction.ClassDrop.Plan {
    var plans: std.ArrayList(Ir.Instruction.ClassDrop.Plan) = .empty;
    for (self.structures, 0..) |structure, candidate| {
        if (!structure.is_class or structure.is_static or
            (candidate != static_type and !@import("Inheritance.zig").isDescendant(self, candidate, static_type))) continue;
        try plans.append(self.allocator, .{
            .structure = candidate,
            .functions = try classDropFunctions(self, candidate),
        });
    }
    return plans.toOwnedSlice(self.allocator);
}

fn classDropFunctions(self: anytype, dynamic_type: usize) ![]const Ir.Instruction.ClassDrop.Finalizer {
    var functions: std.ArrayList(Ir.Instruction.ClassDrop.Finalizer) = .empty;
    var current: ?usize = dynamic_type;
    while (current) |structure_index| : (current = self.structures[structure_index].base) {
        if (dropFunctionId(self, .structure(structure_index))) |function| try functions.append(self.allocator, .{
            .structure = structure_index,
            .function = function,
        });
    }
    try functions.append(self.allocator, .{
        .structure = dynamic_type,
        .function = classFieldDropFunctionId(self, dynamic_type),
    });
    return functions.toOwnedSlice(self.allocator);
}

fn classFieldDropFunctionId(self: anytype, type_index: usize) Ir.FunctionId {
    var result = self.program.functions.len;
    for (self.program.structures) |structure| {
        result += structure.constructors.len;
        if (!structure.is_protocol) result += structure.methods.len;
    }
    for (self.program.structures) |structure| {
        if (structure.drop != null) result += 1;
    }
    for (self.program.structures) |structure| {
        if (!structure.is_class or structure.is_static) continue;
        if (std.mem.eql(u8, structure.name, self.structures[type_index].name)) return result;
        result += 1;
    }
    unreachable;
}

fn emitEnumDrop(self: anytype, builder: anytype, enumeration_index: usize, value: Ir.ValueId) AnalyzeError!void {
    const enumeration = self.enums[enumeration_index];
    const merge_block = try self.newBlock(builder);
    for (enumeration.variants, 0..) |variant, variant_index| {
        var needs_drop = false;
        for (variant.associated_types) |payload_type| if (needsDrop(self, payload_type) or containsClass(self, payload_type)) {
            needs_drop = true;
            break;
        };
        if (!needs_drop) continue;
        const active = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .enum_test = .{
            .result = active,
            .operand = value,
            .enumeration = enumeration_index,
            .variant = variant_index,
        } });
        const drop_block = try self.newBlock(builder);
        const next_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = active, .then_block = drop_block, .else_block = next_block } });
        builder.current_block = drop_block;
        var payload_index = variant.associated_types.len;
        while (payload_index > 0) {
            payload_index -= 1;
            const payload_type = variant.associated_types[payload_index];
            if (!needsDrop(self, payload_type) and !containsClass(self, payload_type)) continue;
            const payload = try self.newValue(builder, payload_type);
            try self.emit(builder, .{ .enum_payload = .{
                .result = payload,
                .operand = value,
                .enumeration = enumeration_index,
                .variant = variant_index,
                .index = payload_index,
            } });
            try emitDrop(self, builder, payload_type, payload);
        }
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = next_block;
    }
    self.terminate(builder, .{ .jump = merge_block });
    builder.current_block = merge_block;
}

fn emitCollectionDrop(self: anytype, builder: anytype, collection_type: Ast.Type, collection: Ast.Collection, value: Ir.ValueId) AnalyzeError!void {
    if (!needsDrop(self, collection.element) and !containsClass(self, collection.element)) return;
    const index_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .int);
    const count = try self.newValue(builder, .int);
    if (collection.length) |length|
        try self.emit(builder, .{ .constant_int = .{ .result = count, .bits = length } })
    else
        try self.emit(builder, .{ .collection_count = .{ .result = count, .collection = value } });
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = count } });
    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = condition_block;
    const index = try self.newValue(builder, .int);
    try self.emit(builder, .{ .local_load = .{ .result = index, .local = index_local } });
    const zero = try self.newValue(builder, .int);
    try self.emit(builder, .{ .constant_int = .{ .result = zero, .bits = 0 } });
    const has_value = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .binary = .{ .result = has_value, .operator = .not_equal, .left = index, .right = zero } });
    self.terminate(builder, .{ .branch = .{ .condition = has_value, .then_block = body_block, .else_block = exit_block } });
    builder.current_block = body_block;
    const one = try self.newValue(builder, .int);
    try self.emit(builder, .{ .constant_int = .{ .result = one, .bits = 1 } });
    const previous = try self.newValue(builder, .int);
    try self.emit(builder, .{ .binary = .{ .result = previous, .operator = .subtract, .left = index, .right = one } });
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = previous } });
    const element = try self.newValue(builder, collection.element);
    try self.emit(builder, .{ .collection_load = .{
        .result = element,
        .collection = value,
        .index = previous,
        .position = .{ .offset = 0, .line = 1, .column = 1 },
    } });
    try emitDrop(self, builder, collection.element, element);
    self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = exit_block;
    _ = collection_type;
}

fn emitCollectionRetain(self: anytype, builder: anytype, collection: Ast.Collection, value: Ir.ValueId) AnalyzeError!void {
    if (!containsClass(self, collection.element)) return;
    const index_local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .int);
    const zero = try self.newValue(builder, .int);
    try self.emit(builder, .{ .constant_int = .{ .result = zero, .bits = 0 } });
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = zero } });
    const count = try self.newValue(builder, .int);
    if (collection.length) |length|
        try self.emit(builder, .{ .constant_int = .{ .result = count, .bits = length } })
    else
        try self.emit(builder, .{ .collection_count = .{ .result = count, .collection = value } });
    const condition_block = try self.newBlock(builder);
    const body_block = try self.newBlock(builder);
    const exit_block = try self.newBlock(builder);
    self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = condition_block;
    const index = try self.newValue(builder, .int);
    try self.emit(builder, .{ .local_load = .{ .result = index, .local = index_local } });
    const has_value = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .binary = .{ .result = has_value, .operator = .less, .left = index, .right = count } });
    self.terminate(builder, .{ .branch = .{ .condition = has_value, .then_block = body_block, .else_block = exit_block } });
    builder.current_block = body_block;
    const element = try self.newValue(builder, collection.element);
    try self.emit(builder, .{ .collection_load = .{
        .result = element,
        .collection = value,
        .index = index,
        .position = .{ .offset = 0, .line = 1, .column = 1 },
    } });
    try retainValue(self, builder, collection.element, element);
    const one = try self.newValue(builder, .int);
    try self.emit(builder, .{ .constant_int = .{ .result = one, .bits = 1 } });
    const next = try self.newValue(builder, .int);
    try self.emit(builder, .{ .binary = .{ .result = next, .operator = .add, .left = index, .right = one } });
    try self.emit(builder, .{ .local_store = .{ .local = index_local, .operand = next } });
    self.terminate(builder, .{ .jump = condition_block });
    builder.current_block = exit_block;
}

fn enumIndex(self: anytype, type_index: usize) ?usize {
    for (self.enums, 0..) |enumeration, index| if (enumeration.type_index == type_index) return index;
    return null;
}

fn dropFunctionId(self: anytype, type_value: Ast.Type) ?Ir.FunctionId {
    const type_index = type_value.structureIndex() orelse return null;
    if (type_index >= self.structures.len) return null;
    const name = self.structures[type_index].name;
    var result = self.program.functions.len;
    for (self.program.structures) |structure| result += structure.constructors.len;
    for (self.program.structures) |structure| {
        if (!structure.is_protocol) result += structure.methods.len;
    }
    for (self.program.structures) |structure| {
        if (structure.drop != null) {
            if (std.mem.eql(u8, structure.name, name)) return result;
            result += 1;
        }
    }
    return null;
}

pub fn validateDrop(self: anytype, drop: Ast.Drop) !void {
    for (drop.statements) |statement| if (statementForbidden(statement)) {
        return self.fail(statement.position(), "drop cannot contain 'return' or 'try'");
    };
}

fn statementForbidden(statement: Ast.Statement) bool {
    return switch (statement) {
        .return_statement => true,
        .variable_declaration => |value| if (value.initializer) |expression| expressionHasTry(expression) else false,
        .assignment_statement => |value| if (value.value) |expression| expressionHasTry(expression) else false,
        .expression_statement => |value| expressionHasTry(value),
        .print_statement => |value| for (value.values) |expression| {
            if (expressionHasTry(expression)) break true;
        } else false,
        .assert_statement => |value| expressionHasTry(value.condition) or expressionHasTry(value.message),
        .panic_statement => |value| expressionHasTry(value.value),
        .if_statement => |value| forbidden: {
            for (value.branches) |branch| {
                if (expressionHasTry(branch.condition.source()) or statementsForbidden(branch.statements)) break :forbidden true;
            }
            if (value.else_statements) |statements| if (statementsForbidden(statements)) break :forbidden true;
            break :forbidden false;
        },
        .while_statement => |value| expressionHasTry(value.condition.source()) or statementsForbidden(value.statements),
        .for_statement => |value| statementsForbidden(value.statements),
        .mutex_statement => |value| statementsForbidden(value.statements),
        .break_statement, .continue_statement => false,
    };
}

fn statementsForbidden(statements: []const Ast.Statement) bool {
    for (statements) |statement| if (statementForbidden(statement)) return true;
    return false;
}

fn expressionHasTry(expression: *const Ast.Expression) bool {
    return switch (expression.value) {
        .unary => |value| value.operator == .propagate or expressionHasTry(value.operand),
        .field_access => |value| expressionHasTry(value.base),
        .binary => |value| expressionHasTry(value.left) or expressionHasTry(value.right),
        .conversion => |value| expressionHasTry(value.operand),
        .string_count => |value| expressionHasTry(value),
        .call => |value| call: {
            if (value.receiver) |receiver| if (expressionHasTry(receiver)) break :call true;
            for (value.arguments) |argument| if (expressionHasTry(argument)) break :call true;
            for (value.named_arguments) |argument| if (expressionHasTry(argument.value)) break :call true;
            break :call false;
        },
        .cascade => |cascade| cascade_try: {
            if (expressionHasTry(cascade.receiver)) break :cascade_try true;
            for (cascade.operations) |operation| switch (operation) {
                .method_call => |method| {
                    for (method.arguments) |argument| if (expressionHasTry(argument)) break :cascade_try true;
                    for (method.named_arguments) |argument| if (expressionHasTry(argument.value)) break :cascade_try true;
                },
                .field_assignment => |field| if (expressionHasTry(field.value)) break :cascade_try true,
            };
            break :cascade_try false;
        },
        .sequence_literal => |value| for (value.values) |item| {
            if (expressionHasTry(item)) break true;
        } else false,
        .index_access => |value| expressionHasTry(value.base) or expressionHasTry(value.index),
        .slice_access => |value| expressionHasTry(value.base) or expressionHasTry(value.start) or expressionHasTry(value.end),
        else => false,
    };
}
