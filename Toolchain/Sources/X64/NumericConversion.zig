const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const Numeric = @import("../Numeric.zig");
const Integer = @import("IntegerArithmetic.zig");
const Allocator = std.mem.Allocator;

// RAX carries typed bits in and out. RCX/RDX and XMM3...XMM5 are scratch;
// the latter are reserved by the X64 lane allocator on both native ABIs.
// Failure branches are patched by the caller to its diagnostic and epilogue.
pub fn emit(allocator: Allocator, bytes: *std.ArrayList(u8), value: Machine.Instruction.Convert, failures: *std.ArrayList(usize)) Allocator.Error!void {
    if (value.source == value.target) return;
    if (value.source.isInteger()) {
        try Integer.normalize(allocator, bytes, 0, value.source.bitWidth(), value.source.isSignedInteger());
        if (value.target.isInteger()) {
            if (value.checked) {
                if (value.source.isSignedInteger()) {
                    try immediate(allocator, bytes, if (value.target.isSignedInteger()) @bitCast(Numeric.integerMin(value.target)) else 0);
                    try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xd0 });
                    try fail(allocator, bytes, failures, 12); // signed less
                }
                try immediate(allocator, bytes, Numeric.integerMax(value.target));
                try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xd0 });
                try fail(allocator, bytes, failures, if (value.source.isSignedInteger() and value.target.isSignedInteger()) 15 else 7);
            }
            return Integer.normalize(allocator, bytes, 0, value.target.bitWidth(), value.target.isSignedInteger());
        }
        if (value.checked) try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0xc1 }); // original integer in rcx
        const double = value.target == .float64;
        try integerToFloat(allocator, bytes, value.source.isSignedInteger(), double, 3);
        if (value.checked) {
            if (!double) try bytes.appendSlice(allocator, &.{ 0xf3, 0x0f, 0x5a, 0xdb });
            try floatToInteger(allocator, bytes, value.source, failures);
            try bytes.appendSlice(allocator, &.{ 0x48, 0x39, 0xc8 });
            try fail(allocator, bytes, failures, 5);
            if (!double) try bytes.appendSlice(allocator, &.{ 0xf2, 0x0f, 0x5a, 0xdb });
        }
        return floatBits(allocator, bytes, 3, double);
    }
    try bytes.appendSlice(allocator, if (value.source == .float64)
        &.{ 0x66, 0x48, 0x0f, 0x6e, 0xd8 }
    else
        &.{ 0x66, 0x0f, 0x6e, 0xd8, 0xf3, 0x0f, 0x5a, 0xdb });
    if (value.target.isInteger()) {
        try floatToInteger(allocator, bytes, value.target, failures);
        try integerToFloat(allocator, bytes, value.target.isSignedInteger(), true, 5);
        try bytes.appendSlice(allocator, &.{ 0x66, 0x0f, 0x2e, 0xdd });
        try fail(allocator, bytes, failures, 5); // fractional values do not round-trip
        return Integer.normalize(allocator, bytes, 0, value.target.bitWidth(), value.target.isSignedInteger());
    }
    if (value.target == .float64) return floatBits(allocator, bytes, 3, true);
    try bytes.appendSlice(allocator, &.{ 0xf2, 0x0f, 0x5a, 0xe3 }); // cvtsd2ss xmm4,xmm3
    if (value.checked) {
        try bytes.appendSlice(allocator, &.{ 0xf3, 0x0f, 0x5a, 0xec, 0x66, 0x0f, 0x2e, 0xdd });
        try fail(allocator, bytes, failures, 10); // unordered (NaN)
        try fail(allocator, bytes, failures, 5);
    }
    return floatBits(allocator, bytes, 4, false);
}

fn integerToFloat(allocator: Allocator, bytes: *std.ArrayList(u8), signed: bool, double: bool, destination: u3) Allocator.Error!void {
    const prefix: u8 = if (double) 0xf2 else 0xf3;
    const xmm: u8 = @as(u8, destination) << 3;
    if (signed) return bytes.appendSlice(allocator, &.{ prefix, 0x48, 0x0f, 0x2a, 0xc0 | xmm });
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0 });
    const small = try branch(allocator, bytes, 9); // non-negative signed representation
    // Round to odd before halving, preserving correct IEEE rounding when the
    // top bit is set. RAX and the original integer saved in RCX stay intact.
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0xc2, 0x48, 0xd1, 0xea, 0xa8, 1, 0x74, 4, 0x48, 0x83, 0xca, 1 });
    try bytes.appendSlice(allocator, &.{ prefix, 0x48, 0x0f, 0x2a, 0xc2 | xmm });
    try bytes.appendSlice(allocator, &.{ prefix, 0x0f, 0x58, 0xc0 | xmm | @as(u8, destination) });
    const done = try jump(allocator, bytes);
    patch(bytes.items, small);
    try bytes.appendSlice(allocator, &.{ prefix, 0x48, 0x0f, 0x2a, 0xc0 | xmm });
    patch(bytes.items, done);
}

// Input XMM3 is a double. Exact powers-of-two bounds reject NaN, infinity,
// and saturation endpoints before the hardware conversion is attempted.
fn floatToInteger(allocator: Allocator, bytes: *std.ArrayList(u8), target: Numeric.Type, failures: *std.ArrayList(usize)) Allocator.Error!void {
    const lower: f64 = if (target.isSignedInteger()) @floatFromInt(Numeric.integerMin(target)) else 0;
    const upper: f64 = @floatFromInt(@as(u128, Numeric.integerMax(target)) + 1);
    try bound(allocator, bytes, lower);
    try bytes.appendSlice(allocator, &.{ 0x66, 0x0f, 0x2e, 0xdc });
    try fail(allocator, bytes, failures, 2); // below, also rejects unordered
    try bound(allocator, bytes, upper);
    try bytes.appendSlice(allocator, &.{ 0x66, 0x0f, 0x2e, 0xdc });
    try fail(allocator, bytes, failures, 3); // above or equal
    if (target == .uint) {
        try bound(allocator, bytes, 9223372036854775808.0);
        try bytes.appendSlice(allocator, &.{ 0x66, 0x0f, 0x2e, 0xdc });
        const small = try branch(allocator, bytes, 2);
        try bytes.appendSlice(allocator, &.{ 0x66, 0x0f, 0x28, 0xeb, 0xf2, 0x0f, 0x5c, 0xec, 0xf2, 0x48, 0x0f, 0x2c, 0xc5, 0x48, 0x0f, 0xba, 0xe8, 63 });
        const done = try jump(allocator, bytes);
        patch(bytes.items, small);
        try bytes.appendSlice(allocator, &.{ 0xf2, 0x48, 0x0f, 0x2c, 0xc3 });
        patch(bytes.items, done);
    } else try bytes.appendSlice(allocator, &.{ 0xf2, 0x48, 0x0f, 0x2c, 0xc3 });
}

fn floatBits(allocator: Allocator, bytes: *std.ArrayList(u8), register: u3, double: bool) Allocator.Error!void {
    try bytes.append(allocator, 0x66);
    if (double) try bytes.append(allocator, 0x48);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x7e, 0xc0 | (@as(u8, register) << 3) });
}

fn bound(allocator: Allocator, bytes: *std.ArrayList(u8), number: f64) Allocator.Error!void {
    try immediate(allocator, bytes, @bitCast(number));
    try bytes.appendSlice(allocator, &.{ 0x66, 0x48, 0x0f, 0x6e, 0xe2 });
}

fn immediate(allocator: Allocator, bytes: *std.ArrayList(u8), bits: u64) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0xba });
    var encoded: [8]u8 = undefined;
    std.mem.writeInt(u64, &encoded, bits, .little);
    try bytes.appendSlice(allocator, &encoded);
}

fn fail(allocator: Allocator, bytes: *std.ArrayList(u8), failures: *std.ArrayList(usize), condition: u4) Allocator.Error!void {
    try failures.append(allocator, try branch(allocator, bytes, condition));
}

fn branch(allocator: Allocator, bytes: *std.ArrayList(u8), condition: u4) Allocator.Error!usize {
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x80 | @as(u8, condition) });
    const at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    return at;
}

fn jump(allocator: Allocator, bytes: *std.ArrayList(u8)) Allocator.Error!usize {
    try bytes.append(allocator, 0xe9);
    const at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    return at;
}

fn patch(bytes: []u8, at: usize) void {
    std.mem.writeInt(i32, bytes[at..][0..4], @intCast(bytes.len - at - 4), .little);
}
