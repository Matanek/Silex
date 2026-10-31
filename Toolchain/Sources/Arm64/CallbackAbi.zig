const std = @import("std");
const I = @import("Instructions.zig");
const Machine = @import("Machine.zig");
const System = @import("System.zig");
const CAbi = @import("CAbi.zig");

fn loadIncoming(allocator: std.mem.Allocator, words: *std.ArrayList(u32), location: CAbi.Location, kind: Machine.AbiValue, platform: System.Platform, destination: I.Register) !void {
    switch (location) {
        .general => |lane| try words.append(allocator, I.moveRegister(destination, @enumFromInt(lane))),
        .floating => |lane| try words.append(allocator, I.moveFloatToGeneral(destination, @enumFromInt(lane), kind == .float64)),
        .stack => |offset| {
            try words.append(allocator, I.addSubtractImmediate(.x11, .x29, @intCast(16 + @as(usize, offset)), true));
            const size = if (platform == .darwin) CAbi.scalarSize(kind) else 8;
            try words.append(allocator, switch (size) {
                1 => I.loadByte(destination, .x11),
                2 => I.load16(destination, .x11),
                4 => I.load32(destination, .x11),
                else => I.load64(destination, .x11, 0),
            });
        },
    }
    switch (kind) {
        .uint8 => try words.append(allocator, I.zeroExtendRegister(destination, destination, 8)),
        .uint16 => try words.append(allocator, I.zeroExtendRegister(destination, destination, 16)),
        .uint32 => try words.append(allocator, I.zeroExtendRegister(destination, destination, 32)),
        .int32 => try words.append(allocator, I.signExtendRegister(destination, destination, 32)),
        else => {},
    }
}

// Snapshot C arguments before assigning any internal register. A record has
// C layout on entry and Silex aggregate semantics only after this conversion.
pub fn emit(allocator: std.mem.Allocator, words: *std.ArrayList(u32), platform: System.Platform, signature: Machine.ExternalFunction.Signature, target: usize) Machine.Error!void {
    const native = try CAbi.plan(allocator, .arm64, platform, signature);
    defer native.deinit(allocator);
    const outgoing = std.mem.alignForward(usize, (CAbi.internalCount(signature, .arm64) -| 8) * 8, 16);
    const homes = outgoing + 64;
    const frame = std.mem.alignForward(usize, homes + CAbi.homeSize(signature), 16);
    if (frame > 4080) return error.FrameTooLarge;
    try words.appendSlice(allocator, &.{ I.saveFrame(), I.moveFramePointer(), I.addSubtractImmediate(.zero_or_sp, .zero_or_sp, @intCast(frame), false) });
    // Silex may use d9-d12 as scratch, while every native ARM64 ABI preserves
    // the low 64 bits of v8-v15 across a C callback.
    for (8..16) |lane| try words.append(allocator, I.storeFloat64Stack(@enumFromInt(lane), @intCast(outgoing / 8 + lane - 8)));
    var home = homes;
    for (signature.arguments, native.arguments, 0..) |kind, argument, index| {
        const leaves = CAbi.fields(signature, index);
        if (argument.indirect) {
            try loadIncoming(allocator, words, argument.locations[0], .read_address, platform, .x10);
            for (leaves, 0..) |_, leaf| {
                try words.append(allocator, I.load64(.x9, .x10, @intCast(leaf * 8)));
                try words.append(allocator, I.store64(.x9, .zero_or_sp, @intCast(home + leaf * 8)));
            }
        } else for (argument.locations, 0..) |location, leaf| {
            try loadIncoming(allocator, words, location, if (kind == .record) leaves[leaf] else kind, platform, .x9);
            try words.append(allocator, I.store64(.x9, .zero_or_sp, @intCast(home + leaf * 8)));
        }
        home += CAbi.width(signature, index) * 8;
    }
    const flattened = CAbi.internalFlattened(signature, .arm64);
    var internal: usize = 0;
    home = homes;
    for (signature.arguments, 0..) |kind, index| {
        const leaves = CAbi.fields(signature, index);
        const direct = kind != .record or (flattened and leaves.len <= 2);
        const count = if (direct) CAbi.width(signature, index) else 1;
        for (0..count) |leaf| {
            const destination: I.Register = if (internal < 8) @enumFromInt(internal) else .x9;
            if (direct) try words.append(allocator, I.load64(destination, .zero_or_sp, @intCast(home + leaf * 8))) else try words.append(allocator, I.addSubtractImmediate(destination, .zero_or_sp, @intCast(home), true));
            if (internal >= 8) try words.append(allocator, I.store64(destination, .zero_or_sp, @intCast((internal - 8) * 8)));
            internal += 1;
        }
        home += CAbi.width(signature, index) * 8;
    }
    const displacement: i64 = @as(i64, @intCast(target / 4)) - @as(i64, @intCast(words.items.len));
    if (displacement < -33554432 or displacement > 33554431) return error.InvalidMachineProgram;
    try words.append(allocator, 0x94000000 | @as(u32, @intCast(@as(u64, @bitCast(displacement)) & 0x03ffffff)));
    if (signature.result == .float32 or signature.result == .float64) try words.append(allocator, I.moveGeneralToFloat(.x0, .x0, signature.result == .float64));
    for (8..16) |lane| try words.append(allocator, I.loadFloat64Stack(@enumFromInt(lane), @intCast(outgoing / 8 + lane - 8)));
    try words.appendSlice(allocator, &.{ I.addSubtractImmediate(.zero_or_sp, .zero_or_sp, @intCast(frame), true), I.restoreFrame(), I.returnInstruction() });
}
