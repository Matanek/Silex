const std = @import("std");

pub const Precision = enum { float32, float64 };
pub const Arity = enum { unary, binary };
pub const Operation = enum {
    sqrt,
    cbrt,
    exp,
    exp2,
    log,
    log2,
    log10,
    sin,
    cos,
    tan,
    asin,
    acos,
    atan,
    atan2,
    sinh,
    cosh,
    tanh,
    asinh,
    acosh,
    atanh,
    trunc,
    floor,
    ceil,
    round,
    copy_sign,
    pow,
};

pub const Function = struct {
    operation: Operation,
    precision: Precision,
    arity: Arity,
};

pub fn identify(name: []const u8) ?Function {
    const names32 = [_][]const u8{
        "sqrtf", "cbrtf", "expf", "exp2f", "logf", "log2f", "log10f", "sinf", "cosf", "tanf",
        "asinf", "acosf", "atanf", "atan2f", "sinhf", "coshf", "tanhf", "asinhf", "acoshf",
        "atanhf", "truncf", "floorf", "ceilf", "roundf", "copysignf", "powf",
    };
    const names64 = [_][]const u8{
        "sqrt", "cbrt", "exp", "exp2", "log", "log2", "log10", "sin", "cos", "tan", "asin", "acos",
        "atan", "atan2", "sinh", "cosh", "tanh", "asinh", "acosh", "atanh", "trunc", "floor", "ceil",
        "round", "copysign", "pow",
    };
    const operations = [_]Operation{
        .sqrt, .cbrt, .exp, .exp2, .log, .log2, .log10, .sin, .cos, .tan, .asin, .acos, .atan, .atan2,
        .sinh, .cosh, .tanh, .asinh, .acosh, .atanh, .trunc, .floor, .ceil, .round, .copy_sign, .pow,
    };
    for (names32, operations) |candidate, operation| if (std.mem.eql(u8, name, candidate)) return .{
        .operation = operation,
        .precision = .float32,
        .arity = arity(operation),
    };
    for (names64, operations) |candidate, operation| if (std.mem.eql(u8, name, candidate)) return .{
        .operation = operation,
        .precision = .float64,
        .arity = arity(operation),
    };
    return null;
}

pub fn unary32(operation: Operation, value: f32) ?f32 {
    return switch (operation) {
        .sqrt => @sqrt(value),
        .cbrt => std.math.cbrt(value),
        .exp => @exp(value),
        .exp2 => @exp2(value),
        .log => @log(value),
        .log2 => @log2(value),
        .log10 => std.math.log10(value),
        .sin => @sin(value),
        .cos => @cos(value),
        .tan => @tan(value),
        .asin => std.math.asin(value),
        .acos => std.math.acos(value),
        .atan => std.math.atan(value),
        .sinh => std.math.sinh(value),
        .cosh => std.math.cosh(value),
        .tanh => std.math.tanh(value),
        .asinh => std.math.asinh(value),
        .acosh => std.math.acosh(value),
        .atanh => std.math.atanh(value),
        .trunc => @trunc(value),
        .floor => @floor(value),
        .ceil => @ceil(value),
        .round => @round(value),
        else => null,
    };
}

pub fn unary64(operation: Operation, value: f64) ?f64 {
    return switch (operation) {
        .sqrt => @sqrt(value),
        .cbrt => std.math.cbrt(value),
        .exp => @exp(value),
        .exp2 => @exp2(value),
        .log => @log(value),
        .log2 => @log2(value),
        .log10 => std.math.log10(value),
        .sin => @sin(value),
        .cos => @cos(value),
        .tan => @tan(value),
        .asin => std.math.asin(value),
        .acos => std.math.acos(value),
        .atan => std.math.atan(value),
        .sinh => std.math.sinh(value),
        .cosh => std.math.cosh(value),
        .tanh => std.math.tanh(value),
        .asinh => std.math.asinh(value),
        .acosh => std.math.acosh(value),
        .atanh => std.math.atanh(value),
        .trunc => @trunc(value),
        .floor => @floor(value),
        .ceil => @ceil(value),
        .round => @round(value),
        else => null,
    };
}

pub fn binary32(operation: Operation, left: f32, right: f32) ?f32 {
    return switch (operation) {
        .atan2 => std.math.atan2(left, right),
        .copy_sign => std.math.copysign(left, right),
        .pow => std.math.pow(f32, left, right),
        else => null,
    };
}

pub fn binary64(operation: Operation, left: f64, right: f64) ?f64 {
    return switch (operation) {
        .atan2 => std.math.atan2(left, right),
        .copy_sign => std.math.copysign(left, right),
        .pow => std.math.pow(f64, left, right),
        else => null,
    };
}

fn arity(operation: Operation) Arity {
    return switch (operation) {
        .atan2, .copy_sign, .pow => .binary,
        else => .unary,
    };
}

test "identify typed math boundary operations" {
    try std.testing.expectEqual(Function{ .operation = .sqrt, .precision = .float32, .arity = .unary }, identify("sqrtf").?);
    try std.testing.expectEqual(Function{ .operation = .pow, .precision = .float64, .arity = .binary }, identify("pow").?);
    try std.testing.expect(identify("write") == null);
}
