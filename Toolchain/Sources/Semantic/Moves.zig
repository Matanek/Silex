const std = @import("std");
const Ast = @import("../Ast.zig");
const Model = @import("Model.zig");
const Support = @import("Support.zig");

pub fn analyze(self: anytype, builder: anytype, unary: Ast.Expression.Unary) !Model.TypedValue {
    const name = switch (unary.operand.value) {
        .identifier => |value| value,
        else => return self.fail(unary.operator_position, "'move' requires a complete local binding or parameter"),
    };
    if (std.mem.eql(u8, name, "self")) return self.fail(unary.operator_position, "'self' cannot be consumed with 'move'");
    const index = Support.findBindingIndex(builder.bindings.items, name) orelse {
        const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{name});
        return self.fail(unary.operand.position, message);
    };
    const value = try self.analyzeExpression(builder, unary.operand);
    builder.bindings.items[index].available = false;
    builder.bindings.items[index].refined_type = null;
    builder.bindings.items[index].refined_value = null;
    return value;
}

pub fn isSelfMove(expression: *const Ast.Expression, name: []const u8) bool {
    if (expression.value != .unary or expression.value.unary.operator != .move) return false;
    return switch (expression.value.unary.operand.value) {
        .identifier => |source| std.mem.eql(u8, source, name),
        else => false,
    };
}
