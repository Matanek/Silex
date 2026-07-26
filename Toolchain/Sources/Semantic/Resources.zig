const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");

pub fn isOwner(self: anytype, type_value: Ast.Type) bool {
    const index = type_value.structureIndex() orelse return false;
    if (index >= self.structures.len) return false;
    const name = self.structures[index].name;
    for (self.program.structures) |structure| {
        if (std.mem.eql(u8, structure.name, name)) return structure.drop != null;
    }
    return false;
}

pub fn requireTransfer(self: anytype, expression: *const Ast.Expression, type_value: Ast.Type, action: []const u8) !void {
    if (!isOwner(self, type_value)) return;
    const transferred = switch (expression.value) {
        .unary => |unary| unary.operator == .move,
        .call => true,
        .match_expression => true,
        else => false,
    };
    if (transferred) return;
    const message = try std.fmt.allocPrint(self.allocator, "named owner value requires 'move' when {s}", .{action});
    return self.fail(expression.position, message);
}

pub fn validateParameter(self: anytype, parameter: Ast.Parameter) !void {
    if (parameter.mode == .mutable and isOwner(self, parameter.type)) {
        return self.fail(parameter.position, "an owner structure cannot be passed through '&T'; use '@T' or transfer it");
    }
}

pub fn analyzeDrop(self: anytype, structure_index: usize, declaration: Ast.Structure, drop: Ast.Drop) !Ir.Function {
    try validateDrop(self, drop);
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
    if (!try self.analyzeStatements(&builder, function, drop.statements)) self.terminate(&builder, .return_void);
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

pub fn emitDrop(self: anytype, builder: anytype, type_value: Ast.Type, value: Ir.ValueId) !void {
    const function = dropFunctionId(self, type_value) orelse return;
    try self.emit(builder, .{ .call = .{
        .result = null,
        .function = function,
        .arguments = try self.allocator.dupe(Ir.ValueId, &.{value}),
    } });
}

pub fn emitActiveDrops(self: anytype, builder: anytype, first_binding: usize) !void {
    var index = builder.bindings.items.len;
    while (index > first_binding) {
        index -= 1;
        const binding = builder.bindings.items[index];
        if (!binding.available or binding.borrowed_root != null or binding.parameter_mode != .value or
            std.mem.eql(u8, binding.name, "self") or !isOwner(self, binding.type)) continue;
        const value = if (binding.local) |local| value: {
            const loaded = try self.newValue(builder, binding.type);
            try self.emit(builder, .{ .local_load = .{ .result = loaded, .local = local } });
            break :value loaded;
        } else binding.value orelse continue;
        try emitDrop(self, builder, binding.type, value);
    }
}

fn dropFunctionId(self: anytype, type_value: Ast.Type) ?Ir.FunctionId {
    const type_index = type_value.structureIndex() orelse return null;
    if (type_index >= self.structures.len) return null;
    const name = self.structures[type_index].name;
    var result = self.program.functions.len;
    for (self.program.structures) |structure| result += structure.constructors.len;
    for (self.program.structures) |structure| result += structure.methods.len;
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
            break :call false;
        },
        .sequence_literal => |value| for (value.values) |item| {
            if (expressionHasTry(item)) break true;
        } else false,
        .index_access => |value| expressionHasTry(value.base) or expressionHasTry(value.index),
        .slice_access => |value| expressionHasTry(value.base) or expressionHasTry(value.start) or expressionHasTry(value.end),
        else => false,
    };
}
