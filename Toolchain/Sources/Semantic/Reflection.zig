const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Enums = @import("Enums.zig");
const Resources = @import("Resources.zig");
const Support = @import("Support.zig");
const Visibility = @import("Visibility.zig");
const Allocator = std.mem.Allocator;

pub fn analyze(self: anytype, builder: anytype, call: Ast.Expression.Call) !Model.TypedValue {
    if (call.receiver != null or call.arguments.len != 1 or call.named_arguments.len != 0 or call.type_arguments.len != 0) {
        return self.fail(call.name_position, "reflect expects exactly one value");
    }
    const result_type = call.result_type orelse return error.InvalidSource;
    const result_index = result_type.structureIndex() orelse return error.InvalidSource;
    if (result_index >= self.structures.len) return error.InvalidSource;

    const expression = call.arguments[0];
    const operand = try self.analyzeExpression(builder, expression);
    const type_name = try typeSpelling(self, operand.type, call);
    var fields: std.ArrayList(Ir.StructureField) = .empty;
    var values: std.ArrayList(Ir.ValueId) = .empty;
    try appendString(self, builder, &fields, &values, "type", type_name);

    if (Enums.findByType(self, operand.type)) |enum_index| {
        const enumeration = self.enums[enum_index];
        try appendValue(self, &fields, &values, "name", .str, try enumName(self, builder, operand.value, enum_index, type_name));
        var variants: std.ArrayList([]const u8) = .empty;
        for (enumeration.variants) |variant| try variants.append(self.allocator, variant.name);
        try appendNames(self, builder, &fields, &values, "variants", variants.items);
    } else if (operand.type.functionIndex()) |function_index| {
        if (try declarationName(self, builder, expression, operand.type, call)) |name| {
            try appendString(self, builder, &fields, &values, "name", name);
        }
        if (function_index >= self.program.function_types.len) return error.InvalidSource;
        const signature = self.program.function_types[function_index];
        var parameters: std.ArrayList([]const u8) = .empty;
        for (signature.parameters) |parameter| try parameters.append(
            self.allocator,
            try parameterSpelling(self, parameter.mode, parameter.type, call),
        );
        try appendNames(self, builder, &fields, &values, "parameters", parameters.items);
        try appendString(self, builder, &fields, &values, "return_type", try returnSpelling(self, signature, call));
    } else if (reflectedStructure(self, operand.type)) |reflected| {
        try appendString(self, builder, &fields, &values, "name", type_name);
        var field_names: std.ArrayList([]const u8) = .empty;
        var property_names: std.ArrayList([]const u8) = .empty;
        for (reflected.declaration.fields) |field| {
            if (field.is_static or !Visibility.memberVisible(self, reflected.index, field, call.name_position)) continue;
            if (field.property != null)
                try property_names.append(self.allocator, field.name)
            else
                try field_names.append(self.allocator, field.name);
        }
        var method_names: std.ArrayList([]const u8) = .empty;
        for (reflected.declaration.methods) |method| {
            if (method.is_static or method.accessor != null or !Visibility.memberVisible(self, reflected.index, method, call.name_position)) continue;
            try method_names.append(self.allocator, method.name);
        }
        try appendNames(self, builder, &fields, &values, "fields", field_names.items);
        try appendNames(self, builder, &fields, &values, "properties", property_names.items);
        try appendNames(self, builder, &fields, &values, "methods", method_names.items);
    } else {
        if (try declarationName(self, builder, expression, operand.type, call)) |name| {
            try appendString(self, builder, &fields, &values, "name", name);
        }
    }

    if (operand.transferred and (Resources.needsDrop(self, operand.type) or Resources.containsClass(self, operand.type))) {
        try Resources.emitDrop(self, builder, operand.type, operand.value);
    }

    const metadata = try fields.toOwnedSlice(self.allocator);
    @constCast(&self.structures[result_index]).fields = metadata;
    @constCast(&self.structures[result_index]).name = try tupleName(self, metadata);
    const result = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .structure_init = .{
        .result = result,
        .structure = result_index,
        .fields = try values.toOwnedSlice(self.allocator),
    } });
    return .{
        .type = result_type,
        .value = result,
        .transferred = Resources.ownsValue(self, result_type),
    };
}

const ReflectedStructure = struct {
    index: usize,
    declaration: Ast.Structure,
};

fn reflectedStructure(self: anytype, type_value: Ast.Type) ?ReflectedStructure {
    const index = type_value.structureIndex() orelse return null;
    if (index >= self.structures.len) return null;
    const structure = self.structures[index];
    if (structure.is_tuple or structure.is_protocol or structure.collection != null) return null;
    for (self.program.structures) |declaration| if (std.mem.eql(u8, declaration.name, structure.name)) {
        return .{ .index = index, .declaration = declaration };
    };
    return null;
}

fn appendString(
    self: anytype,
    builder: anytype,
    fields: *std.ArrayList(Ir.StructureField),
    values: *std.ArrayList(Ir.ValueId),
    name: []const u8,
    value: []const u8,
) !void {
    const emitted = try self.emitString(builder, value);
    try appendValue(self, fields, values, name, .str, emitted.value);
}

fn appendNames(
    self: anytype,
    builder: anytype,
    fields: *std.ArrayList(Ir.StructureField),
    values: *std.ArrayList(Ir.ValueId),
    name: []const u8,
    names: []const []const u8,
) !void {
    const list_type = stringListType(self) orelse return error.InvalidSource;
    const items = try self.allocator.alloc(Ir.ValueId, names.len);
    for (names, 0..) |item, index| items[index] = (try self.emitString(builder, item)).value;
    const list = try self.newValue(builder, list_type);
    try self.emit(builder, .{ .list_init = .{ .result = list, .values = items } });
    try appendValue(self, fields, values, name, list_type, list);
}

fn appendValue(
    self: anytype,
    fields: *std.ArrayList(Ir.StructureField),
    values: *std.ArrayList(Ir.ValueId),
    name: []const u8,
    type_value: Ast.Type,
    value: Ir.ValueId,
) !void {
    try fields.append(self.allocator, .{ .name = name, .type = type_value, .mutable = false });
    try values.append(self.allocator, value);
}

fn stringListType(self: anytype) ?Ast.Type {
    for (self.structures, 0..) |structure, index| if (structure.collection) |collection| {
        if (collection.element == .str and collection.length == null and !collection.view) return .structure(index);
    };
    return null;
}

fn enumName(
    self: anytype,
    builder: anytype,
    operand: Ir.ValueId,
    enum_index: usize,
    type_name: []const u8,
) !Ir.ValueId {
    const enumeration = self.enums[enum_index];
    if (enumeration.variants.len == 0) return error.InvalidSource;
    const local = builder.local_types.items.len;
    try builder.local_types.append(self.allocator, .str);
    const merge = try self.newBlock(builder);

    for (enumeration.variants[0 .. enumeration.variants.len - 1], 0..) |variant, variant_index| {
        const selected = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .enum_test = .{
            .result = selected,
            .operand = operand,
            .enumeration = enum_index,
            .variant = variant_index,
        } });
        const matched = try self.newBlock(builder);
        const next = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = selected, .then_block = matched, .else_block = next } });
        builder.current_block = matched;
        const name = try self.emitString(builder, try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ type_name, variant.name }));
        try self.emit(builder, .{ .local_store = .{ .local = local, .operand = name.value } });
        self.terminate(builder, .{ .jump = merge });
        builder.current_block = next;
    }
    const last = enumeration.variants[enumeration.variants.len - 1];
    const name = try self.emitString(builder, try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ type_name, last.name }));
    try self.emit(builder, .{ .local_store = .{ .local = local, .operand = name.value } });
    self.terminate(builder, .{ .jump = merge });
    builder.current_block = merge;
    const result = try self.newValue(builder, .str);
    try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
    return result;
}

fn tupleName(self: anytype, fields: []const Ir.StructureField) ![]const u8 {
    var result = try self.allocator.dupe(u8, "(");
    for (fields, 0..) |field, index| result = try std.fmt.allocPrint(
        self.allocator,
        "{s}{s}{s}:{s}",
        .{ result, if (index == 0) "" else ", ", field.name, self.typeName(field.type) },
    );
    return std.fmt.allocPrint(self.allocator, "{s})", .{result});
}

fn typeSpelling(self: anytype, type_value: Ast.Type, call: Ast.Expression.Call) Allocator.Error![]const u8 {
    if (type_value.optionalChild()) |child| return std.fmt.allocPrint(self.allocator, "{s}?", .{try typeSpelling(self, child, call)});
    if (type_value.functionIndex()) |index| {
        if (index >= self.program.function_types.len) return displayName(self, self.typeName(type_value), call);
        const signature = self.program.function_types[index];
        var result = try self.allocator.dupe(u8, "func(");
        for (signature.parameters, 0..) |parameter, parameter_index| result = try std.fmt.allocPrint(
            self.allocator,
            "{s}{s}{s}",
            .{ result, if (parameter_index == 0) "" else ",", try parameterSpelling(self, parameter.mode, parameter.type, call) },
        );
        result = try std.fmt.allocPrint(self.allocator, "{s})", .{result});
        if (signature.return_type == .void and signature.return_mode == .value) return result;
        return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ result, try returnSpelling(self, signature, call) });
    }
    return displayName(self, self.typeName(type_value), call);
}

fn parameterSpelling(self: anytype, mode: Ast.Parameter.Mode, type_value: Ast.Type, call: Ast.Expression.Call) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ modeSpelling(mode), try typeSpelling(self, type_value, call) });
}

fn returnSpelling(self: anytype, signature: Ast.FunctionType, call: Ast.Expression.Call) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(self.allocator, "{s}{s}", .{ modeSpelling(signature.return_mode), try typeSpelling(self, signature.return_type, call) });
}

fn declarationName(
    self: anytype,
    builder: anytype,
    expression: *const Ast.Expression,
    operand_type: Ast.Type,
    call: Ast.Expression.Call,
) Allocator.Error!?[]const u8 {
    if (expression.value == .field_access) {
        const access = expression.value.field_access;
        if (qualifiedExpressionName(self, builder, access.base)) |owner| {
            return @as(?[]const u8, try displayName(self, try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ owner, access.name }), call));
        }
        if (inferExpressionType(self, builder, access.base)) |owner_type| {
            if (owner_type.structureIndex() != null) return @as(?[]const u8, try std.fmt.allocPrint(
                self.allocator,
                "{s}.{s}",
                .{ try typeSpelling(self, owner_type, call), access.name },
            ));
        }
    }
    if (operand_type.functionIndex() != null and expression.value == .identifier and
        Support.findBinding(builder.bindings.items, expression.value.identifier) == null)
    {
        if (functionName(self, expression.value.identifier)) |name| return @as(?[]const u8, try displayName(self, name, call));
    }
    return null;
}

fn qualifiedExpressionName(self: anytype, builder: anytype, expression: *const Ast.Expression) ?[]const u8 {
    return switch (expression.value) {
        .identifier => |name| if (Support.findBinding(builder.bindings.items, name) == null) name else null,
        .generic_reference => |reference| reference.name,
        .field_access => |access| if (qualifiedExpressionName(self, builder, access.base)) |base|
            std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ base, access.name }) catch null
        else
            null,
        .call => |call| if (call.receiver == null and self.structureIndex(call.name) != null) call.name else null,
        else => null,
    };
}

fn inferExpressionType(self: anytype, builder: anytype, expression: *const Ast.Expression) ?Ast.Type {
    return switch (expression.value) {
        .identifier => |name| if (Support.findBinding(builder.bindings.items, name)) |binding| binding.type else null,
        .call => |call| if (call.receiver == null) if (self.structureIndex(call.name)) |index| .structure(index) else null else null,
        .field_access => |access| field: {
            const base = inferExpressionType(self, builder, access.base) orelse break :field null;
            const index = base.structureIndex() orelse break :field null;
            if (index >= self.structures.len) break :field null;
            for (self.structures[index].fields) |candidate| {
                if (std.mem.eql(u8, candidate.name, access.name)) break :field candidate.type;
            }
            break :field null;
        },
        else => null,
    };
}

fn functionName(self: anytype, requested: []const u8) ?[]const u8 {
    var selected: ?[]const u8 = null;
    for (self.program.functions) |function| {
        const matches = std.mem.eql(u8, function.name, requested) or
            (function.name.len > requested.len and std.mem.endsWith(u8, function.name, requested) and
                function.name[function.name.len - requested.len - 1] == '.');
        if (!matches or function.is_anonymous) continue;
        if (selected != null) return null;
        selected = function.name;
    }
    return selected;
}

fn displayName(self: anytype, canonical: []const u8, call: Ast.Expression.Call) Allocator.Error![]const u8 {
    if (!call.entry_module or call.module.len == 0 or canonical.len <= call.module.len or
        !std.mem.startsWith(u8, canonical, call.module) or canonical[call.module.len] != '.')
    {
        return self.allocator.dupe(u8, canonical);
    }
    return self.allocator.dupe(u8, canonical[call.module.len + 1 ..]);
}

fn modeSpelling(mode: Ast.Parameter.Mode) []const u8 {
    return switch (mode) {
        .value => "",
        .read => "@",
        .mutable => "&",
    };
}
