const Ast = @import("../Ast.zig");
const Types = @import("../Types.zig");
const Source = @import("../Source.zig");
const Support = @import("Support.zig");
const Model = @import("Model.zig");

pub fn expectedContext(type_value: Types.Type, expression: *const Ast.Expression) ?Types.Type {
    if (type_value.optionalChild() != null) return type_value;
    return if (type_value.isNumeric() and Support.acceptsNumericContext(expression)) type_value else null;
}

pub fn analyzeNull(
    self: anytype,
    builder: anytype,
    expected: ?Types.Type,
    position: Source.Position,
) !Model.TypedValue {
    const type_value = expected orelse return self.fail(position, "'null' requires an expected optional type");
    if (type_value.optionalChild() == null) return self.fail(position, "'null' requires an expected optional type");
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .optional_null = .{ .result = result } });
    return .{ .type = type_value, .value = result };
}

pub fn promote(
    self: anytype,
    builder: anytype,
    value: Model.TypedValue,
    target: Types.Type,
) !?Model.TypedValue {
    if (target.optionalChild() != value.type) return null;
    const result = try self.newValue(builder, target);
    try self.emit(builder, .{ .optional_some = .{ .result = result, .operand = value.value } });
    return .{ .type = target, .value = result };
}

pub fn intrinsic(self: anytype, builder: anytype, type_value: Types.Type) !?Model.TypedValue {
    if (type_value.optionalChild() == null) return null;
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .optional_null = .{ .result = result } });
    return .{ .type = type_value, .value = result };
}

pub fn conversionCost(source: Types.Type, target: Types.Type) ?u8 {
    return if (target.optionalChild() == source) 1 else null;
}

pub fn canConvert(source: Types.Type, target: Types.Type) bool {
    return source == target or conversionCost(source, target) != null;
}
