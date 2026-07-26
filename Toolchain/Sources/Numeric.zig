const std = @import("std");
const Types = @import("Types.zig");

pub const Type = Types.Type;

pub const Integer = struct {
    type: Type,
    bits: u64,

    pub fn signed(self: Integer) i64 {
        return @bitCast(signExtend(self.bits, self.type.bitWidth()));
    }
};

pub fn integerMin(type_value: Type) i64 {
    std.debug.assert(type_value.isSignedInteger());
    const width = type_value.bitWidth();
    if (width == 64) return std.math.minInt(i64);
    return -(@as(i64, 1) << @intCast(width - 1));
}

pub fn integerMax(type_value: Type) u64 {
    std.debug.assert(type_value.isInteger());
    const width = type_value.bitWidth();
    if (!type_value.isSignedInteger()) return mask(width);
    if (width == 64) return std.math.maxInt(i64);
    return (@as(u64, 1) << @intCast(width - 1)) - 1;
}

pub fn normalize(bits: u64, type_value: Type) u64 {
    return bits & mask(type_value.bitWidth());
}

pub fn signExtend(bits: u64, width: u7) u64 {
    if (width == 64) return bits;
    const value = bits & mask(width);
    const sign = @as(u64, 1) << @intCast(width - 1);
    return if (value & sign == 0) value else value | ~mask(width);
}

pub fn fitsMagnitude(magnitude: u64, negative: bool, type_value: Type) bool {
    if (!type_value.isInteger()) return false;
    if (!type_value.isSignedInteger()) return (!negative and magnitude <= integerMax(type_value)) or magnitude == 0;
    if (!negative) return magnitude <= integerMax(type_value);
    const minimum_magnitude = @as(u64, integerMax(type_value)) + 1;
    return magnitude <= minimum_magnitude;
}

pub fn fromMagnitude(magnitude: u64, negative: bool, type_value: Type) Integer {
    std.debug.assert(fitsMagnitude(magnitude, negative, type_value));
    const bits = if (negative and magnitude != 0) 0 -% magnitude else magnitude;
    return .{ .type = type_value, .bits = normalize(bits, type_value) };
}

pub fn canWiden(source: Type, target: Type) bool {
    if (source == target) return true;
    if (source.isInteger() and target.isInteger()) {
        return source.isSignedInteger() == target.isSignedInteger() and source.bitWidth() < target.bitWidth();
    }
    if (source == .float32 and target == .float64) return true;
    return source.isInteger() and target.isFloat();
}

pub fn commonInteger(left: Type, right: Type) ?Type {
    if (!left.isInteger() or !right.isInteger()) return null;
    if (left.isSignedInteger() != right.isSignedInteger()) return null;
    return if (left.bitWidth() >= right.bitWidth()) left else right;
}

pub fn commonNumeric(left: Type, right: Type) ?Type {
    if (left.isInteger() and right.isInteger()) return commonInteger(left, right);
    if (!left.isNumeric() or !right.isNumeric()) return null;
    if (left == .float64 or right == .float64) return .float64;
    return .float32;
}

pub fn mask(width: u7) u64 {
    return if (width == 64) std.math.maxInt(u64) else (@as(u64, 1) << @intCast(width)) - 1;
}

test "integer domains and widening are target independent" {
    try std.testing.expectEqual(@as(i64, -128), integerMin(.int8));
    try std.testing.expectEqual(@as(u64, 255), integerMax(.uint8));
    try std.testing.expectEqual(std.math.maxInt(u64), integerMax(.uint));
    try std.testing.expect(canWiden(.int8, .int));
    try std.testing.expect(!canWiden(.int8, .uint));
}
