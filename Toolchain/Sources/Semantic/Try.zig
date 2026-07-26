const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Result = @import("../Intrinsics/Result.zig");
const Model = @import("Model.zig");
const Resources = @import("Resources.zig");

pub fn analyzeValue(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !Model.TypedValue {
    return (try analyze(self, builder, unary, true)).?;
}

pub fn analyzeStatement(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !void {
    _ = try analyze(self, builder, unary, false);
}

fn analyze(self: anytype, builder: anytype, unary: Ast.Expression.Unary, require_value: bool) !?Model.TypedValue {
    const operand = try self.analyzeExpression(builder, unary.operand);
    try Resources.requireTransfer(self, unary.operand, operand.type, "propagating it with 'try'");
    const source_index = findResult(self.enums, operand.type) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "'try' expects 'Result<T,E>', found '{s}'", .{self.typeName(operand.type)});
        return self.fail(unary.operator_position, message);
    };
    const source = self.enums[source_index];
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
    const values = try self.allocator.alloc(Ir.ValueId, 1);
    values[0] = error_value;
    try self.emit(builder, .{ .enum_init = .{
        .result = propagated,
        .enumeration = destination_index,
        .variant = destination_failure,
        .values = values,
    } });
    try Resources.emitActiveDrops(self, builder, 0);
    self.terminate(builder, .{ .return_value = propagated });

    builder.current_block = success_block;
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
        .variant = source_success,
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
