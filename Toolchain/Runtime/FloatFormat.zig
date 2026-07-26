const std = @import("std");

const output_capacity = std.fmt.float.bufferSize(.decimal, f64);

pub fn main() void {}

export fn silex_format_float(bits: u64, output: [*]u8, is_double: u64) callconv(.c) usize {
    if (is_double != 0) return format(f64, @bitCast(bits), output);
    return format(f32, @bitCast(@as(u32, @truncate(bits))), output);
}

fn format(comptime Float: type, value: Float, output: [*]u8) usize {
    if (std.math.isNan(value)) return copy(output, "nan");
    if (std.math.isPositiveInf(value)) return copy(output, "inf");
    if (std.math.isNegativeInf(value)) return copy(output, "-inf");
    if (value == 0) return copy(output, if (std.math.signbit(value)) "-0.0" else "0.0");

    const rendered = std.fmt.float.render(output[0..output_capacity], value, .{ .mode = .decimal }) catch return 0;
    var has_separator = false;
    for (rendered) |byte| {
        if (byte == '.' or byte == 'e' or byte == 'E') has_separator = true;
    }
    if (has_separator) return rendered.len;
    output[rendered.len] = '.';
    output[rendered.len + 1] = '0';
    return rendered.len + 2;
}

fn copy(output: [*]u8, value: []const u8) usize {
    for (value, 0..) |byte, index| output[index] = byte;
    return value.len;
}

export fn memset(destination: [*]u8, value: c_int, length: usize) callconv(.c) [*]u8 {
    const volatile_destination: [*]volatile u8 = @ptrCast(destination);
    for (0..length) |index| volatile_destination[index] = @truncate(@as(u32, @bitCast(value)));
    return destination;
}

export fn __udivti3(numerator: u128, denominator: u128) callconv(.c) u128 {
    if (denominator == 0) return 0;
    var quotient: u128 = 0;
    var remainder: u128 = 0;
    var bit: u8 = 128;
    while (bit != 0) {
        bit -= 1;
        const shift: u7 = @intCast(bit);
        remainder = (remainder << 1) | ((numerator >> shift) & 1);
        if (remainder >= denominator) {
            remainder -= denominator;
            quotient |= @as(u128, 1) << shift;
        }
    }
    return quotient;
}
