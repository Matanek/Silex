const std = @import("std");
const Imports = @import("../Windows/Imports.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const Allocator = std.mem.Allocator;

// Heap operations are private leaf boundaries, not normal Silex call barriers.
// Preserve scratch values and every SSE lane as well as Windows nonvolatiles.
const registers = [_]u4{ 0, 1, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 };
const vector_offset = registers.len * 8;
const frame_size = vector_offset + 16 * 16;

pub fn allocate(allocator: Allocator, bytes: *std.ArrayList(u8), sites: *std.ArrayList(Imports.X64Site), size: anytype) Allocator.Error!void {
    try emit(allocator, bytes, sites, @intFromEnum(size), true);
}

pub fn release(allocator: Allocator, bytes: *std.ArrayList(u8), sites: *std.ArrayList(Imports.X64Site), pointer: anytype) Allocator.Error!void {
    try emit(allocator, bytes, sites, @intFromEnum(pointer), false);
}

fn emit(allocator: Allocator, bytes: *std.ArrayList(u8), sites: *std.ArrayList(Imports.X64Site), operand: u4, allocates: bool) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x81, 0xec });
    try append32(allocator, bytes, frame_size);
    for (registers, 0..) |register, index| try stackRegister(allocator, bytes, register, @intCast(index * 8), false);
    for (0..16) |register| try stackVector(allocator, bytes, @intCast(register), @intCast(vector_offset + register * 16), false);

    // The operand is read only after saving the complete incoming state.
    const destination: u4 = if (allocates) 2 else 1;
    try bytes.appendSlice(allocator, &.{
        0x48 | (if (operand >= 8) @as(u8, 4) else 0),
        0x89,
        0xc0 | ((@as(u8, operand) & 7) << 3) | destination,
    });
    if (allocates) try bytes.appendSlice(allocator, &.{ 0xb9, 1, 0, 0, 0 }); // calloc(1, bytes)
    try ExternalCalls.emitWindowsImportCall(allocator, bytes, sites, if (allocates) .crt_calloc else .crt_free);

    for (0..16) |register| try stackVector(allocator, bytes, @intCast(register), @intCast(vector_offset + register * 16), true);
    for (registers, 0..) |register, index| {
        if (allocates and register == 0) continue; // RAX is the allocation result.
        try stackRegister(allocator, bytes, register, @intCast(index * 8), true);
    }
    try bytes.appendSlice(allocator, &.{ 0x48, 0x81, 0xc4 });
    try append32(allocator, bytes, frame_size);
}

fn stackRegister(allocator: Allocator, bytes: *std.ArrayList(u8), register: u4, offset: u32, load: bool) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{
        0x48 | (if (register >= 8) @as(u8, 4) else 0),
        if (load) @as(u8, 0x8b) else 0x89,
        0x84 | ((@as(u8, register) & 7) << 3),
        0x24,
    });
    try append32(allocator, bytes, offset);
}

fn stackVector(allocator: Allocator, bytes: *std.ArrayList(u8), register: u4, offset: u32, load: bool) Allocator.Error!void {
    try bytes.append(allocator, 0xf3); // movdqu preserves full 128-bit lanes.
    if (register >= 8) try bytes.append(allocator, 0x44);
    try bytes.appendSlice(allocator, &.{ 0x0f, if (load) @as(u8, 0x6f) else 0x7f, 0x84 | ((@as(u8, register) & 7) << 3), 0x24 });
    try append32(allocator, bytes, offset);
}

fn append32(allocator: Allocator, bytes: *std.ArrayList(u8), value: u32) Allocator.Error!void {
    var encoded: [4]u8 = undefined;
    std.mem.writeInt(u32, &encoded, value, .little);
    try bytes.appendSlice(allocator, &encoded);
}

test "Windows heap preserves every scratch register and vector around CRT imports" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    var sites: std.ArrayList(Imports.X64Site) = .empty;
    defer sites.deinit(std.testing.allocator);
    try emit(std.testing.allocator, &bytes, &sites, 6, true);
    try emit(std.testing.allocator, &bytes, &sites, 10, false);
    try std.testing.expectEqual(@as(usize, 2), sites.items.len);
    try std.testing.expectEqual(Imports.Symbol.crt_calloc, sites.items[0].symbol);
    try std.testing.expectEqual(Imports.Symbol.crt_free, sites.items[1].symbol);
    try std.testing.expectEqualStrings("ucrtbase.dll", sites.items[0].symbol.libraryName());
    // Independent opcode anchors: MOVDQU XMM15,[RSP+352] and its store.
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, bytes.items, &.{ 0xf3, 0x44, 0x0f, 0x7f, 0xbc, 0x24, 0x60, 0x01, 0, 0 }));
    try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, bytes.items, &.{ 0xf3, 0x44, 0x0f, 0x6f, 0xbc, 0x24, 0x60, 0x01, 0, 0 }));
    var instruction: std.ArrayList(u8) = .empty;
    defer instruction.deinit(std.testing.allocator);
    for (registers, 0..) |register, index| {
        inline for (.{ false, true }) |load| {
            instruction.clearRetainingCapacity();
            try stackRegister(std.testing.allocator, &instruction, register, @intCast(index * 8), load);
            try std.testing.expectEqual(@as(usize, if (load and register == 0) 1 else 2), std.mem.count(u8, bytes.items, instruction.items));
        }
    }
    for (0..16) |register| {
        inline for (.{ false, true }) |load| {
            instruction.clearRetainingCapacity();
            try stackVector(std.testing.allocator, &instruction, @intCast(register), @intCast(vector_offset + register * 16), load);
            try std.testing.expectEqual(@as(usize, 2), std.mem.count(u8, bytes.items, instruction.items));
        }
    }
}
