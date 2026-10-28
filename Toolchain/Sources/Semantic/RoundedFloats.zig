const std = @import("std");
const Ast = @import("../Ast.zig");
const Model = @import("Model.zig");
const Conversions = @import("Conversions.zig");

pub fn target(self: anytype, call: Ast.Expression.Call) !Ast.Type {
    if (call.type_arguments.len != 1) return self.fail(call.name_position, "round_float expects one explicit floating target type");
    const result = call.type_arguments[0];
    if (!result.isFloat()) return self.fail(call.name_position, "round_float target must be float32 or float64");
    return result;
}

pub fn operand(self: anytype, call: Ast.Expression.Call) !*Ast.Expression {
    if (call.arguments.len == 1 and call.named_arguments.len == 0) return call.arguments[0];
    if (call.arguments.len == 0 and call.named_arguments.len == 1 and std.mem.eql(u8, call.named_arguments[0].name, "value")) return call.named_arguments[0].value;
    return self.fail(call.name_position, "round_float expects one numeric value, optionally labeled 'value'");
}

pub fn analyze(self: anytype, builder: anytype, call: Ast.Expression.Call) !Model.TypedValue {
    const result = try target(self, call);
    const expression = try operand(self, call);
    const value = try self.analyzeExpression(builder, expression);
    if (!value.type.isNumeric()) return self.fail(expression.position, "round_float source must be numeric");
    return Conversions.emitNumeric(self, builder, value, result, call.name_position, false);
}
