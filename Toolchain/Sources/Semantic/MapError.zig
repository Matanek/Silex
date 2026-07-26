const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Result = @import("../Intrinsics/Result.zig");
const Model = @import("Model.zig");

pub fn analyze(self: anytype, builder: anytype, call: Ast.Expression.Call) !Model.TypedValue {
    const source = try self.analyzeExpression(builder, call.arguments[0]);
    const source_index = findResult(self.enums, source.type) orelse return error.InvalidSource;
    const destination_type = call.result_type orelse return error.InvalidSource;
    const destination_index = findResult(self.enums, destination_type) orelse return error.InvalidSource;
    const source_enum = self.enums[source_index];
    const destination_enum = self.enums[destination_index];
    const success_type = Result.successType(source_enum).?;
    const error_type = Result.errorType(source_enum).?;
    const target_error = Result.errorType(destination_enum).?;
    const transformer_name = call.arguments[1].value.identifier;
    var transformer_index: ?usize = null;
    for (self.program.functions, 0..) |function, index| {
        if (!std.mem.eql(u8, function.name, transformer_name)) continue;
        if (function.parameters.len == 1 and function.parameters[0].type == error_type and function.return_type == target_error) {
            if (transformer_index != null) return self.fail(call.arguments[1].position, "'map_error' transformation function is ambiguous");
            transformer_index = index;
        }
    }
    const function_index = transformer_index orelse return error.InvalidSource;
    const source_success = variantIndex(source_enum, "success").?;
    const source_failure = variantIndex(source_enum, "failure").?;
    const destination_success = variantIndex(destination_enum, "success").?;
    const destination_failure = variantIndex(destination_enum, "failure").?;

    const succeeded = try self.newValue(builder, .bool);
    try self.emit(builder, .{ .enum_test = .{
        .result = succeeded,
        .operand = source.value,
        .enumeration = source_index,
        .variant = source_success,
    } });
    const success_block = try self.newBlock(builder);
    const failure_block = try self.newBlock(builder);
    const merge_block = try self.newBlock(builder);
    self.terminate(builder, .{ .branch = .{
        .condition = succeeded,
        .then_block = success_block,
        .else_block = failure_block,
    } });
    const result_value = try self.newValue(builder, destination_type);

    builder.current_block = success_block;
    var success_values: []const Ir.ValueId = &.{};
    if (success_type != .void) {
        const value = try self.newValue(builder, success_type);
        try self.emit(builder, .{ .enum_payload = .{
            .result = value,
            .operand = source.value,
            .enumeration = source_index,
            .variant = source_success,
            .index = 0,
        } });
        const values = try self.allocator.alloc(Ir.ValueId, 1);
        values[0] = value;
        success_values = values;
    }
    try self.emit(builder, .{ .enum_init = .{
        .result = result_value,
        .enumeration = destination_index,
        .variant = destination_success,
        .values = success_values,
    } });
    self.terminate(builder, .{ .jump = merge_block });

    builder.current_block = failure_block;
    const error_value = try self.newValue(builder, error_type);
    try self.emit(builder, .{ .enum_payload = .{
        .result = error_value,
        .operand = source.value,
        .enumeration = source_index,
        .variant = source_failure,
        .index = 0,
    } });
    const transformed = try self.newValue(builder, target_error);
    const transform_arguments = try self.allocator.alloc(Ir.ValueId, 1);
    transform_arguments[0] = error_value;
    try self.emit(builder, .{ .call = .{
        .result = transformed,
        .function = function_index,
        .arguments = transform_arguments,
    } });
    const failure_values = try self.allocator.alloc(Ir.ValueId, 1);
    failure_values[0] = transformed;
    try self.emit(builder, .{ .enum_init = .{
        .result = result_value,
        .enumeration = destination_index,
        .variant = destination_failure,
        .values = failure_values,
    } });
    self.terminate(builder, .{ .jump = merge_block });
    builder.current_block = merge_block;
    return .{ .type = destination_type, .value = result_value };
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
