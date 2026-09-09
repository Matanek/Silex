const std = @import("std");
const Ast = @import("../Ast.zig");
const Borrowing = @import("Borrowing.zig");
const Conversions = @import("Conversions.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Resources = @import("Resources.zig");
const Source = @import("../Source.zig");
const Support = @import("Support.zig");

pub fn functionOperator(binary: Ast.BinaryOperator) ?Ast.FunctionOperator {
    return switch (binary) {
        .add => .add,
        .subtract => .subtract,
        .multiply => .multiply,
        .divide => .divide,
        else => null,
    };
}

pub fn analyzeUnary(
    self: anytype,
    builder: anytype,
    unary: Ast.Expression.Unary,
    operand: Model.TypedValue,
) !?Model.TypedValue {
    if (unary.operator != .negate) return null;
    return analyze(
        self,
        builder,
        .subtract,
        unary.operator_position,
        unary.owner,
        unary.module,
        &.{unary.operand.position},
        &.{operand},
    );
}

pub fn analyzeBinary(
    self: anytype,
    builder: anytype,
    binary: Ast.Expression.Binary,
    left: Model.TypedValue,
    right: Model.TypedValue,
) !?Model.TypedValue {
    const operator = functionOperator(binary.operator) orelse return null;
    return analyze(
        self,
        builder,
        operator,
        binary.operator_position,
        binary.owner,
        binary.module,
        &.{ binary.left.position, binary.right.position },
        &.{ left, right },
    );
}

pub fn analyzeValues(
    self: anytype,
    builder: anytype,
    operator: Ast.FunctionOperator,
    position: @import("../Source.zig").Position,
    owner: usize,
    module: []const u8,
    positions: []const Source.Position,
    arguments: []const Model.TypedValue,
) !?Model.TypedValue {
    return analyze(self, builder, operator, position, owner, module, positions, arguments);
}

fn analyze(
    self: anytype,
    builder: anytype,
    operator: Ast.FunctionOperator,
    position: @import("../Source.zig").Position,
    owner: usize,
    module: []const u8,
    positions: []const Source.Position,
    arguments: []const Model.TypedValue,
) !?Model.TypedValue {
    var visible: std.ArrayList(Ir.FunctionId) = .empty;
    const context: Ast.Expression.Call = .{
        .name = operator.name(),
        .name_position = position,
        .arguments = &.{},
        .owner = owner,
        .module = module,
    };
    for (self.program.functions, 0..) |function, function_id| {
        if (function.operator != operator or function.parameters.len != arguments.len) continue;
        if (!Support.functionVisible(self.packages, self.module_scope_roots, context, function)) continue;
        try visible.append(self.allocator, function_id);
    }
    if (visible.items.len == 0) return null;

    var viable: std.ArrayList(Ir.FunctionId) = .empty;
    for (visible.items) |function_id| {
        const function = self.program.functions[function_id];
        for (function.parameters, arguments) |parameter, argument| {
            if (Conversions.cost(self, argument.type, parameter.type) == null) break;
        } else try viable.append(self.allocator, function_id);
    }

    var selected: ?Ir.FunctionId = null;
    var nondominated: usize = 0;
    for (viable.items) |candidate_id| {
        var dominated = false;
        for (viable.items) |other_id| {
            if (candidate_id == other_id) continue;
            if (dominates(self, self.program.functions[other_id].parameters, self.program.functions[candidate_id].parameters, arguments)) {
                dominated = true;
                break;
            }
        }
        if (!dominated) {
            selected = candidate_id;
            nondominated += 1;
        }
    }
    if (nondominated > 1) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "operator '{s}' is ambiguous for {s}",
            .{ operator.text(), try operandTypes(self, arguments) },
        );
        return self.fail(position, message);
    }
    const function_id = selected orelse {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "operator '{s}' does not accept {s}",
            .{ operator.text(), try operandTypes(self, arguments) },
        );
        return self.fail(position, message);
    };
    const function = self.program.functions[function_id];

    var ids: std.ArrayList(Ir.ValueId) = .empty;
    for (function.parameters, arguments, positions) |parameter, argument, argument_position| {
        try Borrowing.requireOwned(self, argument, argument_position, "passed to an operator");
        const converted = try self.coerce(builder, argument, parameter.type, argument_position);
        if (Resources.requiresRetain(self, parameter.type) and !converted.transferred) {
            try Resources.retainValue(self, builder, parameter.type, converted.value);
        }
        try ids.append(self.allocator, converted.value);
    }
    const result = try self.newValue(builder, function.return_type);
    try self.emit(builder, .{ .call = .{
        .result = result,
        .function = function_id,
        .arguments = try ids.toOwnedSlice(self.allocator),
    } });
    return .{
        .type = function.return_type,
        .value = result,
        .transferred = Resources.ownsValue(self, function.return_type),
    };
}

fn dominates(self: anytype, better: []const Ast.Parameter, worse: []const Ast.Parameter, arguments: []const Model.TypedValue) bool {
    var strictly_better = false;
    for (arguments, 0..) |argument, index| {
        const better_cost = Conversions.cost(self, argument.type, better[index].type) orelse return false;
        const worse_cost = Conversions.cost(self, argument.type, worse[index].type) orelse return false;
        if (better_cost > worse_cost) return false;
        if (better_cost < worse_cost) strictly_better = true;
    }
    return strictly_better;
}

fn operandTypes(self: anytype, arguments: []const Model.TypedValue) ![]const u8 {
    if (arguments.len == 1) return std.fmt.allocPrint(self.allocator, "'{s}'", .{self.typeName(arguments[0].type)});
    return std.fmt.allocPrint(
        self.allocator,
        "'{s}' and '{s}'",
        .{ self.typeName(arguments[0].type), self.typeName(arguments[1].type) },
    );
}
