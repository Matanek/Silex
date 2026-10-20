const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Result = @import("../Intrinsics/Result.zig");
const Availability = @import("Availability.zig");
const Model = @import("Model.zig");
const Resources = @import("Resources.zig");
const Support = @import("Support.zig");
const Methods = @import("Methods.zig");
const Source = @import("../Source.zig");
const AnalyzeError = std.mem.Allocator.Error || Source.Error;
const Diagnostic = @import("ResultDiagnostic.zig");

pub fn finishCall(self: anytype, builder: anytype, call: Ast.Expression.Call, result: ?Model.TypedValue) AnalyzeError!?Model.TypedValue {
    const operand = result orelse return null;
    const source_index = findResult(self.enums, operand.type) orelse {
        if (call.capture_result) {
            const message = try std.fmt.allocPrint(self.allocator, "'try' expects 'Result<T,E>', found '{s}'", .{self.typeName(operand.type)});
            return self.fail(call.name_position, message);
        }
        return operand;
    };
    if (call.capture_result) return operand;
    const source = self.enums[source_index];
    const succeeded = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .enum_test = .{
        .result = succeeded,
        .operand = operand.value,
        .enumeration = source_index,
        .variant = variantIndex(source, "success").?,
    } });
    const success_block = try self.newBlock(builder);
    const failure_block = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{
        .condition = succeeded,
        .then_block = success_block,
        .else_block = failure_block,
    } });
    builder.current_block = failure_block;
    const error_type = Result.errorType(source).?;
    const error_value = try self.newValue(builder, error_type);
    try self.emit(builder, .{ .enum_payload = .{
        .result = error_value,
        .operand = operand.value,
        .enumeration = source_index,
        .variant = variantIndex(source, "failure").?,
        .index = 0,
    } });
    var message = try Diagnostic.format(self, builder, .{ .type = error_type, .value = error_value }, 0);
    if (error_type != .str) {
        const prefix = try self.emitString(builder, try std.fmt.allocPrint(self.allocator, "call to '{s}' failed: ", .{call.name}));
        message = try Diagnostic.concat(self, builder, prefix, message);
    }
    self.terminate(builder, .{ .panic = .{ .message = message.value, .position = call.name_position } });
    builder.current_block = success_block;
    const success_type = Result.successType(source).?;
    if (success_type == .void) return null;
    const value = try self.newValue(builder, success_type);
    try self.emit(builder, .{ .enum_payload = .{
        .result = value,
        .operand = operand.value,
        .enumeration = source_index,
        .variant = variantIndex(source, "success").?,
        .index = 0,
    } });
    return .{
        .type = success_type,
        .value = value,
        .transferred = operand.transferred and Resources.ownsValue(self, success_type),
        .borrowed_root = operand.borrowed_root,
        .borrowed_mode = operand.borrowed_mode,
        .lexical_captures = operand.lexical_captures,
        .lexical_borrows = operand.lexical_borrows,
    };
}

pub fn analyzeValue(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !Model.TypedValue {
    return (try analyze(self, builder, unary, true)).?;
}

pub fn analyzeStatement(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !void {
    _ = try analyze(self, builder, unary, false);
}

fn analyze(self: anytype, builder: anytype, unary: Ast.Expression.Unary, require_value: bool) !?Model.TypedValue {
    const operand = try self.analyzeExpression(builder, unary.operand);
    const alternative = unary.try_alternative;
    if (alternative == null) {
        const captured = if (unary.operand.value == .call and unary.operand.value.call.safe)
            operand.type.optionalChild() orelse operand.type
        else
            operand.type;
        if (findResult(self.enums, captured) == null) {
            const message = try std.fmt.allocPrint(self.allocator, "'try' expects 'Result<T,E>', found '{s}'", .{self.typeName(operand.type)});
            return self.fail(unary.operator_position, message);
        }
        if (!require_value) return self.fail(unary.operator_position, "the Result captured by 'try' must be used");
        return operand;
    }
    const source_index = findResult(self.enums, operand.type) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "'try' expects 'Result<T,E>', found '{s}'", .{self.typeName(operand.type)});
        return self.fail(unary.operator_position, message);
    };
    const source = self.enums[source_index];

    const function = self.function_context orelse return self.fail(
        alternative.?.position,
        "'try else' is not allowed in this context",
    );
    if (builder.return_type == null) return self.fail(alternative.?.position, "'try else' is not allowed in this context");

    const source_success = variantIndex(source, "success").?;
    const source_failure = variantIndex(source, "failure").?;
    const succeeded = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .enum_test = .{
        .result = succeeded,
        .operand = operand.value,
        .enumeration = source_index,
        .variant = source_success,
    } });
    const success_block = try self.newBlock(builder);
    const failure_block = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{
        .condition = succeeded,
        .then_block = success_block,
        .else_block = failure_block,
    } });

    const availability_count = builder.bindings.items.len;
    const success_availability = try Availability.snapshot(self.allocator, builder.bindings.items, availability_count);
    builder.current_block = failure_block;
    const error_type = Result.errorType(source).?;
    const error_value = try self.newValue(builder, error_type);
    try self.emit(builder, .{ .enum_payload = .{
        .result = error_value,
        .operand = operand.value,
        .enumeration = source_index,
        .variant = source_failure,
        .index = 0,
    } });
    if (!operand.transferred and Resources.requiresRetain(self, error_type)) {
        try Resources.retainValue(self, builder, error_type, error_value);
    }

    if (alternative.?.message) |message_expression| {
        try analyzeMessagePropagation(
            self,
            builder,
            alternative.?,
            error_type,
            error_value,
            message_expression,
        );
    } else {
        try analyzeLocalBranch(self, builder, function, alternative.?, error_type, error_value);
    }
    builder.bindings.shrinkRetainingCapacity(availability_count);
    Availability.restore(builder.bindings.items, success_availability);

    builder.current_block = success_block;
    return extractSuccess(self, builder, unary, operand, source_index, source, require_value);
}

fn analyzeLocalBranch(
    self: anytype,
    builder: anytype,
    function: Ast.Function,
    alternative: Ast.Expression.TryAlternative,
    error_type: Ast.Type,
    error_value: Ir.ValueId,
) !void {
    const binding_name = if (alternative.error_position != null) "error" else "$try-error";
    if (alternative.error_position) |position| if (Support.findBinding(builder.bindings.items, binding_name) != null) {
        return self.fail(position, "variable 'error' is already declared in this scope");
    };
    try builder.bindings.append(self.allocator, .{
        .name = binding_name,
        .type = error_type,
        .value = error_value,
    });
    const terminated = try self.analyzeStatements(builder, function, alternative.statements.?);
    if (!terminated) return self.fail(alternative.position, "'try else' branch must exit the current flow on every path");
}

fn analyzeMessagePropagation(
    self: anytype,
    builder: anytype,
    alternative: Ast.Expression.TryAlternative,
    error_type: Ast.Type,
    error_value: Ir.ValueId,
    message_expression: *Ast.Expression,
) !void {
    const return_type = builder.return_type.?;
    const destination_index = findResult(self.enums, return_type) orelse return self.fail(
        alternative.position,
        "'try else error' requires an enclosing function returning 'Result<U,str>'",
    );
    const destination = self.enums[destination_index];
    if (Result.errorType(destination).? != .str) return self.fail(
        alternative.position,
        "'try else error' requires an enclosing function returning 'Result<U,str>'",
    );

    try builder.bindings.append(self.allocator, .{
        .name = "$try-error",
        .type = error_type,
        .value = error_value,
    });
    const message = try self.analyzeExpression(builder, message_expression);
    if (message.type != .str) {
        const diagnostic = try std.fmt.allocPrint(
            self.allocator,
            "'try else error' message expects 'str', found '{s}'",
            .{self.typeName(message.type)},
        );
        return self.fail(message_expression.position, diagnostic);
    }
    const propagated = try self.newValue(builder, return_type);
    try self.emit(builder, .{ .enum_init = .{
        .result = propagated,
        .enumeration = destination_index,
        .variant = variantIndex(destination, "failure").?,
        .values = try self.allocator.dupe(Ir.ValueId, &.{message.value}),
    } });
    try emitPropagatedReturn(self, builder, return_type, propagated);
}

fn extractSuccess(
    self: anytype,
    builder: anytype,
    unary: Ast.Expression.Unary,
    operand: Model.TypedValue,
    source_index: usize,
    source: Ir.Enum,
    require_value: bool,
) !?Model.TypedValue {
    const success_type = Result.successType(source).?;
    if (success_type == .void) {
        if (require_value) return self.fail(unary.operator_position, "'try' of 'Result<void,E>' does not produce a value");
        return null;
    }
    if (!require_value) return self.fail(unary.operator_position, "the success value produced by 'try' must be used");
    const value = try self.newValue(builder, success_type);
    try self.emit(builder, .{ .enum_payload = .{
        .result = value,
        .operand = operand.value,
        .enumeration = source_index,
        .variant = variantIndex(source, "success").?,
        .index = 0,
    } });
    return .{
        .type = success_type,
        .value = value,
        .transferred = operand.transferred and Resources.ownsValue(self, success_type),
        .borrowed_root = operand.borrowed_root,
        .borrowed_mode = operand.borrowed_mode,
        .lexical_captures = operand.lexical_captures,
        .lexical_borrows = operand.lexical_borrows,
    };
}

pub fn findResult(enums: []const Ir.Enum, type_value: Ast.Type) ?usize {
    const type_index = type_value.structureIndex() orelse return null;
    for (enums, 0..) |enumeration, index| {
        if (enumeration.type_index == type_index and Result.isConcrete(enumeration)) return index;
    }
    return null;
}

fn variantIndex(enumeration: Ir.Enum, name: []const u8) ?usize {
    for (enumeration.variants, 0..) |variant, index| if (std.mem.eql(u8, variant.name, name)) return index;
    return null;
}

fn emitPropagatedReturn(self: anytype, builder: anytype, return_type: Ast.Type, value: Ir.ValueId) !void {
    if (builder.mutating_return) |context| {
        try Methods.emitMutatingReturn(
            self,
            builder,
            context.structure_index,
            context.flat,
            context.self_local,
            self.function_context.?,
            .{ .type = return_type, .value = value, .transferred = true },
        );
        return;
    }
    try Resources.emitActiveDrops(self, builder, 0);
    try Resources.emitMutexUnlocks(self, builder, 0);
    self.terminate(builder, .{ .return_value = value });
}
