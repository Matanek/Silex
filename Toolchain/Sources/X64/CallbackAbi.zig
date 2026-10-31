const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const Platform = @import("ExternalCalls.zig").Platform;
const Allocator = std.mem.Allocator;
const Bytes = std.ArrayList(u8);
const CAbi = @import("../Arm64/CAbi.zig");

fn outgoing(signature: Machine.ExternalFunction.Signature) usize {
    return std.mem.alignForward(usize, (CAbi.internalCount(signature, .x64) -| 8) * 8, 16);
}
fn frame(platform: Platform, signature: Machine.ExternalFunction.Signature) u32 {
    return @intCast(std.mem.alignForward(usize, outgoing(signature) + (if (platform == .windows) @as(usize, 160) else 0) + CAbi.homeSize(signature), 16));
}
fn immediate(a: Allocator, b: *Bytes, value: u32) !void {
    try b.appendSlice(a, &std.mem.toBytes(std.mem.nativeToLittle(u32, value)));
}
fn stack(a: Allocator, b: *Bytes, amount: u32, add: bool) !void {
    if (amount == 0) return;
    try b.appendSlice(a, &.{ 0x48, 0x81, if (add) @as(u8, 0xc4) else 0xec });
    try immediate(a, b, amount);
}
fn memoryBase(a: Allocator, b: *Bytes, register: u4, base: u4, offset: usize, load: bool) !void {
    try b.appendSlice(a, &.{ 0x48 | (@as(u8, @intFromBool(register >= 8)) << 2) | @intFromBool(base >= 8), if (load) @as(u8, 0x8b) else 0x89, 0x80 | ((@as(u8, register) & 7) << 3) | (@as(u8, base) & 7) });
    if (base & 7 == 4) try b.append(a, 0x24);
    try immediate(a, b, @intCast(offset));
}
fn memory(a: Allocator, b: *Bytes, register: u4, offset: usize, load: bool) !void {
    try memoryBase(a, b, register, 4, offset, load);
}
fn move(a: Allocator, b: *Bytes, destination: u4, source: u4) !void {
    try b.appendSlice(a, &.{ 0x48 | (@as(u8, @intFromBool(source >= 8)) << 2) | @intFromBool(destination >= 8), 0x89, 0xc0 | ((@as(u8, source) & 7) << 3) | (@as(u8, destination) & 7) });
}
fn address(a: Allocator, b: *Bytes, register: u4, offset: usize) !void {
    try b.appendSlice(a, &.{ 0x48 | (@as(u8, @intFromBool(register >= 8)) << 2), 0x8d, 0x84 | ((@as(u8, register) & 7) << 3), 0x24 });
    try immediate(a, b, @intCast(offset));
}
fn normalize(a: Allocator, b: *Bytes, kind: Machine.AbiValue) !void {
    switch (kind) {
        .uint8 => try b.appendSlice(a, &.{ 0x0f, 0xb6, 0xc0 }),
        .uint16 => try b.appendSlice(a, &.{ 0x0f, 0xb7, 0xc0 }),
        .uint32, .float32 => try b.appendSlice(a, &.{ 0x89, 0xc0 }),
        .int32 => try b.appendSlice(a, &.{ 0x48, 0x63, 0xc0 }),
        else => {},
    }
}
fn floatBits(a: Allocator, b: *Bytes, xmm: u4, general: u4, to_general: bool) !void {
    try b.appendSlice(a, &.{ 0x66, 0x48 | (@as(u8, @intFromBool(xmm >= 8)) << 2) | @intFromBool(general >= 8), 0x0f, if (to_general) @as(u8, 0x7e) else 0x6e, 0xc0 | ((@as(u8, xmm) & 7) << 3) | (@as(u8, general) & 7) });
}
fn vectors(a: Allocator, b: *Bytes, offset: usize, load: bool) !void {
    for (6..16) |index| {
        try b.append(a, 0xf3);
        if (index >= 8) try b.append(a, 0x44);
        try b.appendSlice(a, &.{ 0x0f, if (load) @as(u8, 0x6f) else 0x7f, 0x84 | ((@as(u8, @intCast(index)) & 7) << 3), 0x24 });
        try immediate(a, b, @intCast(offset + (index - 6) * 16));
    }
}
pub fn emit(a: Allocator, b: *Bytes, platform: Platform, signature: Machine.ExternalFunction.Signature) Machine.Error!void {
    const native = try CAbi.plan(a, .x64, platform, signature);
    defer native.deinit(a);
    const allocation = frame(platform, signature);
    if (allocation > 4080) return error.FrameTooLarge;
    try b.appendSlice(a, &.{ 0x53, 0x56, 0x57, 0x41, 0x54, 0x41, 0x55, 0x41, 0x56, 0x41, 0x57 });
    try stack(a, b, allocation, false);
    if (platform == .windows) try vectors(a, b, outgoing(signature), false);
    const home = outgoing(signature) + (if (platform == .windows) @as(usize, 160) else 0);
    const win = [_]u4{ 1, 2, 8, 9 };
    const sysv = [_]u4{ 7, 6, 2, 1, 8, 9 };
    var offset = home;
    for (signature.arguments, native.arguments, 0..) |kind, argument, index| {
        const leaves = CAbi.fields(signature, index);
        if (argument.indirect) {
            switch (argument.locations[0]) {
                .general => |lane| try move(a, b, 11, if (platform == .windows) win[lane] else sysv[lane]),
                .stack => |at| try memory(a, b, 11, allocation + 64 + @as(usize, at), true),
                .floating => return error.InvalidMachineProgram,
            }
            for (leaves, 0..) |_, leaf| {
                try memoryBase(a, b, 0, 11, leaf * 8, true);
                try memory(a, b, 0, offset + leaf * 8, false);
            }
        } else for (argument.locations, 0..) |location, leaf| {
            switch (location) {
                .general => |lane| try move(a, b, 0, if (platform == .windows) win[lane] else sysv[lane]),
                .floating => |lane| try floatBits(a, b, lane, 0, true),
                .stack => |at| try memory(a, b, 0, allocation + 64 + @as(usize, at), true),
            }
            try normalize(a, b, if (kind == .record) leaves[leaf] else kind);
            try memory(a, b, 0, offset + leaf * 8, false);
        }
        offset += CAbi.width(signature, index) * 8;
    }
    const internal = [_]u4{ 7, 6, 2, 1, 8, 9, 10, 11 };
    offset = home;
    for (signature.arguments, 0..) |kind, index| {
        const destination: u4 = if (index < 8) internal[index] else 0;
        if (kind == .record) try address(a, b, destination, offset) else try memory(a, b, destination, offset, true);
        if (index >= 8) try memory(a, b, 0, (index - 8) * 8, false);
        offset += CAbi.width(signature, index) * 8;
    }
}
pub fn finish(a: Allocator, b: *Bytes, platform: Platform, signature: Machine.ExternalFunction.Signature) Machine.Error!void {
    if (signature.result == .float32 or signature.result == .float64) try floatBits(a, b, 0, 0, false);
    if (platform == .windows) try vectors(a, b, outgoing(signature), true);
    try stack(a, b, frame(platform, signature), true);
    try b.appendSlice(a, &.{ 0x41, 0x5f, 0x41, 0x5e, 0x41, 0x5d, 0x41, 0x5c, 0x5f, 0x5e, 0x5b, 0xc3 });
}
