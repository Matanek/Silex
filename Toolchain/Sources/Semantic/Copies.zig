const Ast = @import("../Ast.zig");
const Model = @import("Model.zig");
const Collections = @import("Collections.zig");

pub fn analyze(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !Model.TypedValue {
    const operand = try self.analyzeExpression(builder, unary.operand);
    if (Collections.isViewType(self.structures, operand.type)) {
        return self.fail(unary.operator_position, "'copy' cannot produce an owned borrowed-view type");
    }
    const result = try self.newValue(builder, operand.type);
    try self.emit(builder, .{ .deep_copy = .{ .result = result, .operand = operand.value } });
    return .{ .type = operand.type, .value = result };
}
