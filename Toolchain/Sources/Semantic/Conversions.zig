const std = @import("std");
const Types = @import("../Types.zig");
const Model = @import("Model.zig");
const Numeric = @import("../Numeric.zig");
const Optionals = @import("Optionals.zig");
const Inheritance = @import("Inheritance.zig");
const ProtocolValues = @import("ProtocolValues.zig");

pub fn coerce(self: anytype, builder: anytype, value: Model.TypedValue, target: Types.Type, position: @import("../Source.zig").Position) !Model.TypedValue {
    if (value.type == target) return value;
    if (sameFunctionType(self, value.type, target)) return .{ .type = target, .value = value.value };
    if (try Optionals.promote(self, builder, value, target)) |promoted| return promoted;
    if (target.optionalChild()) |child| {
        if (Inheritance.canUpcast(self, value.type, child) or ProtocolValues.canErase(self, value.type, child)) {
            const converted = try coerce(self, builder, value, child, position);
            return (try Optionals.promote(self, builder, converted, target)).?;
        }
    }
    if (ProtocolValues.canErase(self, value.type, target)) return ProtocolValues.erase(self, builder, value, target, position);
    if (Inheritance.canUpcast(self, value.type, target)) {
        const result = try self.newValue(builder, target);
        try self.emit(builder, .{ .class_cast = .{ .result = result, .operand = value.value } });
        return .{ .type = target, .value = result };
    }
    if (!Numeric.canWiden(value.type, target)) {
        const message = try std.fmt.allocPrint(self.allocator, "cannot implicitly convert '{s}' to '{s}'", .{ self.typeName(value.type), self.typeName(target) });
        return self.fail(position, message);
    }
    return emitNumeric(self, builder, value, target, position, false);
}

pub fn canImplicitlyConvert(self: anytype, source: Types.Type, target: Types.Type) bool {
    if (source == target or sameFunctionType(self, source, target) or Numeric.canWiden(source, target) or Optionals.canConvert(source, target) or
        Inheritance.canUpcast(self, source, target) or ProtocolValues.canErase(self, source, target)) return true;
    return if (target.optionalChild()) |child|
        Inheritance.canUpcast(self, source, child) or ProtocolValues.canErase(self, source, child)
    else false;
}

pub fn cost(self: anytype, source: Types.Type, target: Types.Type) ?u8 {
    if (source == target or sameFunctionType(self, source, target)) return 0;
    if (Optionals.conversionCost(source, target)) |value| return value;
    if (Inheritance.canUpcast(self, source, target) or ProtocolValues.canErase(self, source, target)) return 1;
    if (target.optionalChild()) |child| if (Inheritance.canUpcast(self, source, child) or ProtocolValues.canErase(self, source, child)) return 2;
    if (!Numeric.canWiden(source, target)) return null;
    if (source.isInteger() and target.isFloat()) {
        // `float` is the language's canonical floating type. Prefer it when an
        // integer argument can feed otherwise identical float/float64
        // overloads, while keeping an explicit float64 value exact.
        return if (target == .float32) 2 else 3;
    }
    return 1;
}

fn sameFunctionType(self: anytype, left: Types.Type, right: Types.Type) bool {
    const left_index = left.functionIndex() orelse return false;
    const right_index = right.functionIndex() orelse return false;
    if (left_index >= self.program.function_types.len or right_index >= self.program.function_types.len) return false;
    const left_signature = self.program.function_types[left_index];
    const right_signature = self.program.function_types[right_index];
    if (left_signature.return_type != right_signature.return_type or
        left_signature.return_mode != right_signature.return_mode or
        left_signature.parameters.len != right_signature.parameters.len) return false;
    for (left_signature.parameters, right_signature.parameters) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type or left_parameter.mode != right_parameter.mode) return false;
    }
    return true;
}

pub fn emitNumeric(self: anytype, builder: anytype, value: Model.TypedValue, target: Types.Type, position: @import("../Source.zig").Position, checked: bool) !Model.TypedValue {
    if (value.type == target) return value;
    const result = try self.newValue(builder, target);
    try self.emit(builder, .{ .convert = .{ .result = result, .operand = value.value, .source = value.type, .target = target, .position = position, .checked = checked } });
    return .{ .type = target, .value = result };
}
