const std = @import("std");
const Ast = @import("../Ast.zig");
const ModuleScopes = @import("../ModuleScopes.zig");
const Packages = @import("../Packages.zig");

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

pub fn findVisibleFunctionByName(packages: ?Packages.Graph, module_scope_roots: []const []const u8, program: Ast.Program, call: Ast.Expression.Call) ?Ast.Function {
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, call.name) and functionVisible(packages, module_scope_roots, call, function)) return function;
    }
    return null;
}

pub fn functionVisible(packages: ?Packages.Graph, module_scope_roots: []const []const u8, call: Ast.Expression.Call, function: Ast.Function) bool {
    if (function.is_local) return call.name_position.file == function.position.file;
    if (function.is_public) return true;
    if (function.is_internal) return if (packages) |graph|
        graph.canAccessPackage(call.owner, function.owner)
    else
        call.owner == function.owner;
    if (call.name_position.file == function.position.file) return true;
    if (call.owner != function.owner) return false;
    const separator = std.mem.lastIndexOfScalar(u8, function.name, '.') orelse return false;
    return ModuleScopes.same(module_scope_roots, call.module, function.name[0..separator]);
}

pub fn memberVisible(position: @import("../Source.zig").Position, declaration_position: @import("../Source.zig").Position, is_local: bool) bool {
    return !is_local or position.file == declaration_position.file;
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

pub fn parseIntegerMagnitude(self: anytype, lexeme: []const u8, position: @import("../Source.zig").Position) !u64 {
    const literal = try removeSeparators(self.allocator, lexeme);
    const base: u8 = if (literal.len > 2 and literal[0] == '0') switch (literal[1]) {
        'b', 'B' => 2,
        'o', 'O' => 8,
        'x', 'X' => 16,
        else => 10,
    } else 10;
    const digits = if (base == 10) literal else literal[2..];
    return std.fmt.parseInt(u64, digits, base) catch self.fail(position, "integer literal is outside the range of 'uint'");
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
        .coalesce => "??",
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
        for (self.enums) |enumeration| if (enumeration.type_index == index) {
            for (enumeration.variants) |variant| {
                for (variant.associated_types) |associated| {
                    if (!isComparable(self, associated)) return false;
                }
            }
            return true;
        };
        if (index < self.structures.len and self.structures[index].is_protocol) return false;
        if (index < self.structures.len and self.structures[index].is_class) return true;
        for (self.structures[index].fields) |field| {
            if (!isComparable(self, field.type)) return false;
        }
        return true;
    }
    return type_value != .void;
}
