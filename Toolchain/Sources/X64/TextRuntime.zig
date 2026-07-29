const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const WindowsImports = @import("../Windows/Imports.zig");
const ExternalCalls = @import("ExternalCalls.zig");

const Allocator = std.mem.Allocator;
const Platform = ExternalCalls.Platform;
const Register = enum(u4) { rax = 0, rcx = 1, rdx = 2, rbx = 3, rsp = 4, rbp = 5, rsi = 6, rdi = 7, r8 = 8, r9 = 9, r10 = 10, r11 = 11, r12 = 12, r13 = 13, r14 = 14, r15 = 15 };

const integer_scratch_size: u32 = 64;
const float_scratch_size: u32 = 384;

pub fn emit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    float_calls: *std.ArrayList(usize),
    data_fixups: anytype,
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: anytype,
    value: Machine.Instruction.FormatValue,
) !void {
    switch (value.kind) {
        .signed_integer => try emitInteger(allocator, bytes, import_sites, platform, epilogue, value, true),
        .unsigned_integer => try emitInteger(allocator, bytes, import_sites, platform, epilogue, value, false),
        .float32, .float64 => try emitFloat(allocator, bytes, float_calls, import_sites, platform, epilogue, value),
        .boolean => try emitBoolean(allocator, bytes, data_fixups, value),
        .string => {
            try emitLoadStack(allocator, bytes, .rax, value.operand);
            try emitStoreStack(allocator, bytes, .rax, value.result);
        },
    }
}

fn emitBoolean(allocator: Allocator, bytes: *std.ArrayList(u8), data_fixups: anytype, value: Machine.Instruction.FormatValue) !void {
    try emitLoadStack(allocator, bytes, .rax, value.operand);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x84 });
    const use_false = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitStringAddress(allocator, bytes, data_fixups, 1, value.result);
    try bytes.append(allocator, 0xe9);
    const finished = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, use_false, bytes.items.len);
    try emitStringAddress(allocator, bytes, data_fixups, 2, value.result);
    try patchRelative(bytes.items, finished, bytes.items.len);
}

fn emitInteger(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: anytype,
    value: Machine.Instruction.FormatValue,
    signed: bool,
) !void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xec, integer_scratch_size });
    try emitLoadStack(allocator, bytes, .rax, value.operand);
    try bytes.appendSlice(allocator, &.{ 0x4c, 0x8d, 0x5c, 0x24, integer_scratch_size });
    try emitImmediate(allocator, bytes, .r12, 0);
    try emitImmediate(allocator, bytes, .r13, 0);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x85 });
    const nonzero = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x49, 0xff, 0xcb, 0x41, 0xc6, 0x03, '0', 0x49, 0xff, 0xc4, 0xe9 });
    const digits_finished = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    try patchRelative(bytes.items, nonzero, bytes.items.len);
    if (signed) {
        try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x89 });
        const positive = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try emitImmediate(allocator, bytes, .r13, 1);
        try bytes.appendSlice(allocator, &.{ 0x48, 0xf7, 0xd8 });
        try patchRelative(bytes.items, positive, bytes.items.len);
    }
    const digit_loop = bytes.items.len;
    try emitImmediate(allocator, bytes, .rcx, 10);
    try bytes.appendSlice(allocator, &.{ 0x31, 0xd2, 0x48, 0xf7, 0xf1, 0x80, 0xc2, '0', 0x49, 0xff, 0xcb, 0x41, 0x88, 0x13, 0x49, 0xff, 0xc4, 0x48, 0x85, 0xc0, 0x0f, 0x85 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, digit_loop);
    if (signed) {
        try bytes.appendSlice(allocator, &.{ 0x4d, 0x85, 0xed, 0x0f, 0x84 });
        const unsigned = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, 4);
        try bytes.appendSlice(allocator, &.{ 0x49, 0xff, 0xcb, 0x41, 0xc6, 0x03, '-', 0x49, 0xff, 0xc4 });
        try patchRelative(bytes.items, unsigned, bytes.items.len);
    }
    try patchRelative(bytes.items, digits_finished, bytes.items.len);

    try bytes.appendSlice(allocator, &.{ 0x4c, 0x89, 0x1c, 0x24, 0x4c, 0x89, 0x64, 0x24, 0x08 });
    try emitMoveRegister(allocator, bytes, .rsi, .r12);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc6, 8 });
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r10, .rax);
    try bytes.appendSlice(allocator, &.{ 0x4c, 0x8b, 0x64, 0x24, 0x08 });
    try emitStoreMemory(allocator, bytes, .r10, 0, .r12);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8b, 0x34, 0x24, 0x49, 0x8d, 0x7a, 0x08, 0x4c, 0x89, 0xe1, 0xf3, 0xa4, 0x48, 0x83, 0xc4, integer_scratch_size });
    try emitStoreStack(allocator, bytes, .r10, value.result);
}

fn emitFloat(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    float_calls: *std.ArrayList(usize),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    platform: Platform,
    epilogue: anytype,
    value: Machine.Instruction.FormatValue,
) !void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x81, 0xec });
    try appendInt(allocator, bytes, u32, float_scratch_size);
    try emitLoadStack(allocator, bytes, .rdi, value.operand);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8d, 0x74, 0x24, 0x10, 0x48, 0x89, 0x34, 0x24 });
    try emitImmediate(allocator, bytes, .rdx, @intFromBool(value.kind == .float64));
    try bytes.append(allocator, 0xe8);
    try float_calls.append(allocator, bytes.items.len);
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x44, 0x24, 0x08, 0x48, 0x89, 0xc6, 0x48, 0x83, 0xc6, 8 });
    try emitAllocation(allocator, bytes, import_sites, platform, epilogue);
    try emitMoveRegister(allocator, bytes, .r10, .rax);
    try bytes.appendSlice(allocator, &.{ 0x4c, 0x8b, 0x64, 0x24, 0x08 });
    try emitStoreMemory(allocator, bytes, .r10, 0, .r12);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8b, 0x34, 0x24, 0x49, 0x8d, 0x7a, 0x08, 0x4c, 0x89, 0xe1, 0xf3, 0xa4, 0x48, 0x81, 0xc4 });
    try appendInt(allocator, bytes, u32, float_scratch_size);
    try emitStoreStack(allocator, bytes, .r10, value.result);
}

fn emitAllocation(allocator: Allocator, bytes: *std.ArrayList(u8), import_sites: *std.ArrayList(WindowsImports.X64Site), platform: Platform, epilogue: anytype) !void {
    switch (platform) {
        .linux => {
            try emitImmediate(allocator, bytes, .rdi, 0);
            try emitImmediate(allocator, bytes, .rdx, 3);
            try emitImmediate(allocator, bytes, .r10, 0x22);
            try emitImmediate(allocator, bytes, .r8, std.math.maxInt(u64));
            try emitImmediate(allocator, bytes, .r9, 0);
            try emitImmediate(allocator, bytes, .rax, 9);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0x48, 0x3d });
            try appendInt(allocator, bytes, i32, -4095);
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x82 });
        },
        .windows => {
            try emitImmediate(allocator, bytes, .rcx, 0);
            try emitMoveRegister(allocator, bytes, .rdx, .rsi);
            try emitImmediate(allocator, bytes, .r8, 0x3000);
            try emitImmediate(allocator, bytes, .r9, 4);
            try ExternalCalls.emitWindowsImportCall(allocator, bytes, import_sites, .virtual_alloc);
            try bytes.appendSlice(allocator, &.{ 0x48, 0x85, 0xc0, 0x0f, 0x85 });
        },
    }
    const succeeded = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .rdx, @intFromEnum(Machine.Status.runtime_failure));
    try bytes.append(allocator, 0xe9);
    try epilogue.append(allocator, .{ .displacement_at = bytes.items.len });
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, succeeded, bytes.items.len);
}

fn emitStringAddress(allocator: Allocator, bytes: *std.ArrayList(u8), data_fixups: anytype, string: usize, result: Machine.Slot) !void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x8d, 0x05 });
    const displacement_at = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try data_fixups.append(allocator, .{ .displacement_at = displacement_at, .string = string });
    try emitStoreStack(allocator, bytes, .rax, result);
}

fn emitLoadStack(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, slot: Machine.Slot) !void {
    try emitRex(allocator, bytes, true, register);
    try bytes.append(allocator, 0x8b);
    try bytes.append(allocator, 0x85 | (@as(u8, @intFromEnum(register) & 7) << 3));
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitStoreStack(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, slot: Machine.Slot) !void {
    try emitRex(allocator, bytes, true, register);
    try bytes.append(allocator, 0x89);
    try bytes.append(allocator, 0x85 | (@as(u8, @intFromEnum(register) & 7) << 3));
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitStoreMemory(allocator: Allocator, bytes: *std.ArrayList(u8), base: Register, displacement: i32, source: Register) !void {
    const rex: u8 = 0x48 | (if (@intFromEnum(source) >= 8) @as(u8, 4) else 0) | (if (@intFromEnum(base) >= 8) @as(u8, 1) else 0);
    try bytes.appendSlice(allocator, &.{ rex, 0x89, 0x80 | ((@as(u8, @intFromEnum(source)) & 7) << 3) | (@as(u8, @intFromEnum(base)) & 7) });
    try appendInt(allocator, bytes, i32, displacement);
}

fn emitImmediate(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, value: u64) !void {
    try emitRex(allocator, bytes, true, register);
    try bytes.append(allocator, 0xb8 + (@as(u8, @intFromEnum(register)) & 7));
    try appendInt(allocator, bytes, u64, value);
}

fn emitMoveRegister(allocator: Allocator, bytes: *std.ArrayList(u8), destination: Register, source: Register) !void {
    const rex: u8 = 0x48 | (if (@intFromEnum(source) >= 8) @as(u8, 4) else 0) | (if (@intFromEnum(destination) >= 8) @as(u8, 1) else 0);
    try bytes.appendSlice(allocator, &.{ rex, 0x89, 0xc0 | ((@as(u8, @intFromEnum(source)) & 7) << 3) | (@as(u8, @intFromEnum(destination)) & 7) });
}

fn emitRex(allocator: Allocator, bytes: *std.ArrayList(u8), wide: bool, register: Register) !void {
    try bytes.append(allocator, 0x40 | (if (wide) @as(u8, 8) else 0) | (if (@intFromEnum(register) >= 8) @as(u8, 4) else 0));
}

fn slotDisplacement(slot: Machine.Slot) i32 {
    return -@as(i32, @intCast((@as(usize, slot) + 1) * Machine.slot_size));
}

fn patchRelative(bytes: []u8, displacement_at: usize, target: anytype) error{InvalidMachineProgram}!void {
    if (displacement_at + 4 > bytes.len) return error.InvalidMachineProgram;
    const origin: i64 = @intCast(displacement_at + 4);
    const destination: i64 = @intCast(target);
    std.mem.writeInt(i32, bytes[displacement_at..][0..4], @intCast(destination - origin), .little);
}

fn appendInt(allocator: Allocator, bytes: *std.ArrayList(u8), comptime T: type, value: anytype) !void {
    var storage: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &storage, @as(T, @intCast(value)), .little);
    try bytes.appendSlice(allocator, &storage);
}
