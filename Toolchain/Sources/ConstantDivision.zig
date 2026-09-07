const std = @import("std");

/// Target-independent recipe for replacing a signed 64-bit division by a
/// non-trivial constant. Narrow Silex integers reach the native backends
/// sign-extended, so the same recipe covers int8, int16, int32 and int.
pub const Signed = struct {
    multiplier: i64,
    shift: u6,
    adjustment: enum { none, add_dividend, subtract_dividend },
};

/// Target-independent recipe for replacing an unsigned 64-bit division by a
/// non-trivial constant. Narrow Silex integers reach the native backends
/// zero-extended, so the same recipe covers uint8, uint16, uint32 and uint.
pub const Unsigned = struct {
    multiplier: u64,
    shift: u6,
    add_dividend: bool,
};

/// Computes the Hacker's Delight signed-division recipe used by LLVM's
/// DivisionByConstantInfo. Zero, +/-1 and powers of two remain on the ordinary
/// division path until their dedicated selections are qualified separately.
pub fn signed(divisor: i64) ?Signed {
    if (divisor == 0 or divisor == 1 or divisor == -1 or divisor == std.math.minInt(i64)) return null;
    const absolute: u64 = if (divisor < 0) @bitCast(-%divisor) else @intCast(divisor);
    if (std.math.isPowerOfTwo(absolute)) return null;

    const signed_min: u64 = @as(u64, 1) << 63;
    const divisor_bits: u64 = @bitCast(divisor);
    const t = signed_min +% (divisor_bits >> 63);
    const anc = t -% 1 -% (t % absolute);
    var p: u8 = 63;
    var q1 = signed_min / anc;
    var r1 = signed_min - q1 * anc;
    var q2 = signed_min / absolute;
    var r2 = signed_min - q2 * absolute;

    while (true) {
        p += 1;
        q1 = q1 << 1;
        r1 = r1 << 1;
        if (r1 >= anc) {
            q1 +%= 1;
            r1 -%= anc;
        }
        q2 = q2 << 1;
        r2 = r2 << 1;
        if (r2 >= absolute) {
            q2 +%= 1;
            r2 -%= absolute;
        }
        const delta = absolute - r2;
        if (!(q1 < delta or (q1 == delta and r1 == 0))) break;
    }

    var multiplier_bits = q2 +% 1;
    if (divisor < 0) multiplier_bits = 0 -% multiplier_bits;
    const multiplier: i64 = @bitCast(multiplier_bits);
    return .{
        .multiplier = multiplier,
        .shift = @intCast(p - 64),
        .adjustment = if (divisor > 0 and multiplier < 0)
            .add_dividend
        else if (divisor < 0 and multiplier > 0)
            .subtract_dividend
        else
            .none,
    };
}

/// Computes the Hacker's Delight unsigned-division recipe used by LLVM's
/// DivisionByConstantInfo. Powers of two remain on the ordinary division path
/// until their direct-shift selection is qualified separately.
pub fn unsigned(divisor: u64) ?Unsigned {
    if (divisor <= 1 or std.math.isPowerOfTwo(divisor)) return null;

    const signed_min: u64 = @as(u64, 1) << 63;
    const signed_max: u64 = signed_min - 1;
    const nc = std.math.maxInt(u64) - ((0 -% divisor) % divisor);
    var p: u8 = 63;
    var q1 = signed_min / nc;
    var r1 = signed_min - q1 * nc;
    var q2 = signed_max / divisor;
    var r2 = signed_max - q2 * divisor;
    var is_add = false;

    while (true) {
        p += 1;
        if (r1 >= nc - r1) {
            q1 = (q1 << 1) +% 1;
            r1 = (r1 << 1) -% nc;
        } else {
            q1 = q1 << 1;
            r1 = r1 << 1;
        }
        if (r2 +% 1 >= divisor - r2) {
            if (q2 >= signed_max) is_add = true;
            q2 = (q2 << 1) +% 1;
            r2 = (r2 << 1) +% 1 -% divisor;
        } else {
            if (q2 >= signed_min) is_add = true;
            q2 = q2 << 1;
            r2 = (r2 << 1) +% 1;
        }
        const delta = divisor - 1 - r2;
        if (p >= 128 or !(q1 < delta or (q1 == delta and r1 == 0))) break;
    }

    var shift = p - 64;
    if (is_add) {
        std.debug.assert(shift > 0);
        shift -= 1;
    }
    return .{
        .multiplier = q2 +% 1,
        .shift = @intCast(shift),
        .add_dividend = is_add,
    };
}

fn applySigned(dividend: i64, plan: Signed) i64 {
    const product = @as(i128, dividend) * @as(i128, plan.multiplier);
    var quotient: i64 = @intCast(product >> 64);
    quotient = switch (plan.adjustment) {
        .none => quotient,
        .add_dividend => quotient +% dividend,
        .subtract_dividend => quotient -% dividend,
    };
    quotient >>= plan.shift;
    return quotient +% @as(i64, @intCast(@as(u64, @bitCast(quotient)) >> 63));
}

fn applyUnsigned(dividend: u64, plan: Unsigned) u64 {
    const product = @as(u128, dividend) * @as(u128, plan.multiplier);
    var quotient: u64 = @intCast(product >> 64);
    if (plan.add_dividend) quotient = ((dividend -% quotient) >> 1) +% quotient;
    return quotient >> plan.shift;
}

test "signed reciprocal plan matches every narrow dividend and wide boundaries" {
    const expected_magic: i64 = @bitCast(@as(u64, 0x8637a2a24e5ace35));
    const benchmark_plan = signed(1_000_003).?;
    try std.testing.expectEqual(expected_magic, benchmark_plan.multiplier);
    try std.testing.expectEqual(@as(u6, 19), benchmark_plan.shift);
    try std.testing.expectEqual(.add_dividend, benchmark_plan.adjustment);

    const narrow_divisors = [_]i64{ -32767, -257, -17, -7, -3, 3, 5, 7, 17, 257, 32767 };
    for (narrow_divisors) |divisor| {
        const plan = signed(divisor).?;
        var dividend: i64 = std.math.minInt(i16);
        while (dividend <= std.math.maxInt(i16)) : (dividend += 1) {
            try std.testing.expectEqual(@divTrunc(dividend, divisor), applySigned(dividend, plan));
        }
    }

    const wide_divisors = [_]i64{
        -std.math.maxInt(i64), -1_000_003, -65_537,   -3,
        3,                     65_537,     1_000_003, std.math.maxInt(i64),
    };
    const boundaries = [_]i64{
        std.math.minInt(i64), std.math.minInt(i32), -1_000_004,           -1_000_003,
        -1,                   0,                    1,                    1_000_002,
        1_000_003,            std.math.maxInt(i32), std.math.maxInt(i64),
    };
    for (wide_divisors) |divisor| {
        const plan = signed(divisor).?;
        for (boundaries) |dividend| {
            try std.testing.expectEqual(@divTrunc(dividend, divisor), applySigned(dividend, plan));
        }
        var bits: u64 = 0x4d595df4d0f33173;
        for (0..10_000) |_| {
            bits = bits *% 6364136223846793005 +% 1442695040888963407;
            const dividend: i64 = @bitCast(bits);
            try std.testing.expectEqual(@divTrunc(dividend, divisor), applySigned(dividend, plan));
        }
    }
}

test "unsigned reciprocal plan matches every narrow dividend and wide boundaries" {
    const narrow_divisors = [_]u64{ 3, 5, 7, 10, 17, 255, 257, 65_535 };
    for (narrow_divisors) |divisor| {
        const plan = unsigned(divisor).?;
        var dividend: u64 = 0;
        while (dividend <= std.math.maxInt(u16)) : (dividend += 1) {
            try std.testing.expectEqual(dividend / divisor, applyUnsigned(dividend, plan));
        }
    }

    const wide_divisors = [_]u64{ 3, 7, 65_537, 1_000_003, (@as(u64, 1) << 63) + 1, std.math.maxInt(u64) };
    const boundaries = [_]u64{
        0,                       1,                 2,                    std.math.maxInt(u8), std.math.maxInt(u16), std.math.maxInt(u32),
        (@as(u64, 1) << 63) - 1, @as(u64, 1) << 63, std.math.maxInt(u64),
    };
    for (wide_divisors) |divisor| {
        const plan = unsigned(divisor).?;
        for (boundaries) |dividend| {
            try std.testing.expectEqual(dividend / divisor, applyUnsigned(dividend, plan));
        }
        var dividend: u64 = 0x4d595df4d0f33173;
        for (0..10_000) |_| {
            dividend = dividend *% 6364136223846793005 +% 1442695040888963407;
            try std.testing.expectEqual(dividend / divisor, applyUnsigned(dividend, plan));
        }
    }
}
