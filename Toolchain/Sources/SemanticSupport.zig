const std = @import("std");
const Ast = @import("Ast.zig");

const Allocator = std.mem.Allocator;

pub fn sameParameterTypes(left: []const Ast.Parameter, right: []const Ast.Parameter) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type) return false;
    }
    return true;
}

pub fn findVisibleFunctionByName(program: Ast.Program, call: Ast.Expression.Call) ?Ast.Function {
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, call.name) and functionVisible(call, function)) return function;
    }
    return null;
}

pub fn functionVisible(call: Ast.Expression.Call, function: Ast.Function) bool {
    return call.owner == function.owner or function.is_public;
}

pub fn removeSeparators(allocator: Allocator, text: []const u8) Allocator.Error![]const u8 {
    const normalized = try allocator.alloc(u8, text.len);
    var length: usize = 0;
    for (text) |character| {
        if (character == '_') continue;
        normalized[length] = character;
        length += 1;
    }
    return normalized[0..length];
}

pub fn isNumericLiteral(expression: *const Ast.Expression) bool {
    return switch (expression.value) {
        .integer, .floating => true,
        .unary => |unary| unary.operator == .negate and isNumericLiteral(unary.operand),
        else => false,
    };
}

pub fn acceptsNumericContext(expression: *const Ast.Expression) bool {
    return switch (expression.value) {
        .integer, .floating, .unary, .binary => true,
        else => false,
    };
}

pub fn binaryOperatorText(operator: Ast.BinaryOperator) []const u8 {
    return switch (operator) {
        .add => "+",
        .subtract => "-",
        .multiply => "*",
        .divide => "/",
        .remainder => "%",
        .less => "<",
        .less_equal => "<=",
        .greater => ">",
        .greater_equal => ">=",
        .equal => "==",
        .not_equal => "!=",
        .logical_and => "&&",
        .logical_or => "||",
        .bit_and => "&",
        .bit_xor => "^",
        .shift_left => "<<",
        .shift_right => ">>",
    };
}
