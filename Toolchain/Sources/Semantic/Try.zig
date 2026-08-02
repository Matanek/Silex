const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Result = @import("../Intrinsics/Result.zig");
const Availability = @import("Availability.zig");
const Model = @import("Model.zig");
const Resources = @import("Resources.zig");
const Support = @import("Support.zig");

pub fn analyzeValue(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !Model.TypedValue {
    return (try analyze(self, builder, unary, true)).?;
}

pub fn analyzeStatement(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !void {
    _ = try analyze(self, builder, unary, false);
}

fn analyze(self: anytype, builder: anytype, unary: Ast.Expression.Unary, require_value: bool) !?Model.TypedValue {
    const operand = try self.analyzeExpression(builder, unary.operand);
    const source_index = findResult(self.enums, operand.type) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "'try' expects 'Result<T,E>', found '{s}'", .{self.typeName(operand.type)});
        return self.fail(unary.operator_position, message);
    };
    const source = self.enums[source_index];
    const alternative = unary.try_alternative;
    if (alternative == null) return propagate(self, builder, unary, operand, source_index, source, require_value);

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

fn propagate(
    self: anytype,
    builder: anytype,
    unary: Ast.Expression.Unary,
    operand: Model.TypedValue,
    source_index: usize,
    source: Ir.Enum,
    require_value: bool,
) !?Model.TypedValue {
    const return_type = builder.return_type orelse return self.fail(
        unary.operator_position,
        "'try' requires an enclosing function returning 'Result<U,E>'",
    );
    const destination_index = findResult(self.enums, return_type) orelse return self.fail(
        unary.operator_position,
        "'try' requires an enclosing function returning 'Result<U,E>'",
    );
    const destination = self.enums[destination_index];
    const source_error = Result.errorType(source).?;
    const destination_error = Result.errorType(destination).?;
    if (source_error != destination_error) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "'try' error type '{s}' does not match enclosing error type '{s}'",
            .{ self.typeName(source_error), self.typeName(destination_error) },
        );
        return self.fail(unary.operator_position, message);
    }

    const source_success = variantIndex(source, "success").?;
    const source_failure = variantIndex(source, "failure").?;
    const destination_failure = variantIndex(destination, "failure").?;
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

    builder.current_block = failure_block;
    const error_value = try self.newValue(builder, source_error);
    try self.emit(builder, .{ .enum_payload = .{
        .result = error_value,
        .operand = operand.value,
        .enumeration = source_index,
        .variant = source_failure,
        .index = 0,
    } });
    const propagated = try self.newValue(builder, return_type);
    try self.emit(builder, .{ .enum_init = .{
        .result = propagated,
        .enumeration = destination_index,
        .variant = destination_failure,
        .values = try self.allocator.dupe(Ir.ValueId, &.{error_value}),
    } });
    try Resources.emitActiveDrops(self, builder, 0);
    try Resources.emitMutexUnlocks(self, builder, 0);
    self.terminate(builder, .{ .return_value = propagated });

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
    try Resources.emitActiveDrops(self, builder, 0);
    try Resources.emitMutexUnlocks(self, builder, 0);
    self.terminate(builder, .{ .return_value = propagated });
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
    return .{ .type = success_type, .value = value };
}

fn findResult(enums: []const Ir.Enum, type_value: Ast.Type) ?usize {
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
