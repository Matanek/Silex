const std = @import("std");
const Ast = @import("../Ast.zig");

const Allocator = std.mem.Allocator;

pub fn sameParameterTypes(left: []const Ast.Parameter, right: []const Ast.Parameter) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type) return false;
    }
    return true;
}

pub fn requiredParameterCount(parameters: []const Ast.Parameter) usize {
    for (parameters, 0..) |parameter, index| {
        if (parameter.default != null) return index;
    }
    return parameters.len;
}

pub fn acceptsArity(parameters: []const Ast.Parameter, arity: usize) bool {
    return arity >= requiredParameterCount(parameters) and arity <= parameters.len;
}

pub fn effectiveSignatureCollision(left: []const Ast.Parameter, right: []const Ast.Parameter) ?usize {
    const first_arity = @max(requiredParameterCount(left), requiredParameterCount(right));
    const last_arity = @min(left.len, right.len);
    if (first_arity > last_arity) return null;
    var arity = first_arity;
    while (arity <= last_arity) : (arity += 1) {
        if (sameParameterTypes(left[0..arity], right[0..arity])) return arity;
    }
    return null;
}

pub fn findVisibleFunctionByName(program: Ast.Program, call: Ast.Expression.Call) ?Ast.Function {
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, call.name) and functionVisible(call, function)) return function;
    }
    return null;
}

pub fn functionVisible(call: Ast.Expression.Call, function: Ast.Function) bool {
    if (function.is_internal) return call.name_position.file == function.position.file;
    return call.owner == function.owner or function.is_public;
}

pub fn memberVisible(position: @import("../Source.zig").Position, declaration_position: @import("../Source.zig").Position, is_internal: bool) bool {
    return !is_internal or position.file == declaration_position.file;
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

pub fn findBinding(bindings: anytype, name: []const u8) ?@TypeOf(bindings[0]) {
    var index = bindings.len;
    while (index != 0) {
        index -= 1;
        if (std.mem.eql(u8, bindings[index].name, name)) return bindings[index];
    }
    return null;
}

pub fn findBindingIndex(bindings: anytype, name: []const u8) ?usize {
    var index = bindings.len;
    while (index != 0) {
        index -= 1;
        if (std.mem.eql(u8, bindings[index].name, name)) return index;
    }
    return null;
}

pub fn isComparable(self: anytype, type_value: Ast.Type) bool {
    if (type_value.optionalChild()) |child| return isComparable(self, child);
    if (type_value.structureIndex()) |index| {
        for (self.enums) |enumeration| if (enumeration.type_index == index) return false;
        for (self.structures[index].fields) |field| {
            if (!isComparable(self, field.type)) return false;
        }
        return true;
    }
    return type_value != .void;
}
