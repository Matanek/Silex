const std = @import("std");
const Machine = @import("Machine.zig");
const A64 = @import("Instructions.zig");
const Fixups = @import("Fixups.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const Allocation = @import("Allocation.zig");

const Allocator = std.mem.Allocator;
pub const Error = Machine.Error || Allocator.Error || Fixups.Error;
pub const Platform = Allocation.Platform;

pub fn emitInit(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue: *std.ArrayList(Fixups.Local),
    external_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
    function: Machine.Function,
    value: Machine.Instruction.ClassInit,
) Error!void {
    var width: usize = 0;
    for (value.fields) |field| width += field.width;
    try immediate(allocator, words, .x1, (width + 4) * Machine.slot_size);
    try Allocation.emitAbi(allocator, words, external_sites, platform);
    const failed = words.items.len;
    try words.append(allocator, Allocation.failureBranch(platform));
    try words.append(allocator, A64.moveRegister(.x15, .x0));
    try immediate(allocator, words, .x9, value.structure);
    try words.append(allocator, A64.store64(.x9, .x15, 0));
    try words.append(allocator, A64.store64(.zero_or_sp, .x15, Machine.slot_size));
    try words.append(allocator, A64.store64(.zero_or_sp, .x15, 2 * Machine.slot_size));
    try words.append(allocator, A64.store64(.zero_or_sp, .x15, 3 * Machine.slot_size));
    var offset: usize = 4;
    for (value.fields) |field| for (0..field.width) |leaf| {
        try words.append(allocator, A64.loadStack(.x9, @intCast(@as(usize, field.start) + leaf)));
        try words.append(allocator, A64.store64(.x9, .x15, @intCast(offset * Machine.slot_size)));
        offset += 1;
    };
    if (residence(function.register_slots, value.result)) |register| {
        try words.append(allocator, A64.moveRegister(register, .x15));
    } else try words.append(allocator, A64.storeStack(.x15, value.result));
    const done = words.items.len;
    try words.append(allocator, A64.branch());
    try Fixups.patch19(words.items, failed, words.items.len);
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, done, words.items.len);
}

// Class payload slots are always 64 bits, including mixed integer/pointer/FP
// aggregates. Scalar FP residences preserve all bits on these transfers;
// packed f32 lanes remain excluded by MemoryResidence.pinClassLanes.
pub fn emitLoad(allocator: Allocator, words: *std.ArrayList(u32), function: Machine.Function, value: Machine.Instruction.ClassLoad) Error!void {
    try loadSlot(allocator, words, function, .x10, value.base);
    try addOffset(allocator, words, .x10, 4 * Machine.slot_size + value.byte_offset);
    for (0..value.result.width) |leaf| {
        const slot: Machine.Slot = @intCast(@as(usize, value.result.start) + leaf);
        const offset: u32 = @intCast(leaf * Machine.slot_size);
        if (residence(function.float_register_slots, slot)) |register| {
            try words.append(allocator, A64.loadVector64(register, .x10, @intCast(offset)));
        } else {
            const destination = residence(function.register_slots, slot) orelse .x9;
            try words.append(allocator, A64.load64(destination, .x10, @intCast(offset)));
            if (destination == .x9) try words.append(allocator, A64.storeStack(.x9, slot));
        }
    }
}

pub fn emitStore(allocator: Allocator, words: *std.ArrayList(u32), function: Machine.Function, value: Machine.Instruction.ClassStore) Error!void {
    try loadSlot(allocator, words, function, .x10, value.base);
    try words.append(allocator, A64.moveRegister(.x12, .x10));
    try addOffset(allocator, words, .x10, 4 * Machine.slot_size + value.byte_offset);
    for (0..value.replacement.width) |leaf| {
        const slot: Machine.Slot = @intCast(@as(usize, value.replacement.start) + leaf);
        const offset: u32 = @intCast(leaf * Machine.slot_size);
        if (residence(function.float_register_slots, slot)) |register| {
            try words.append(allocator, A64.storeVector64(register, .x10, @intCast(offset)));
        } else {
            const source = residence(function.register_slots, slot) orelse .x9;
            if (source == .x9) try words.append(allocator, A64.loadStack(.x9, slot));
            try words.append(allocator, A64.store64(source, .x10, @intCast(offset)));
        }
    }
    // The allocator may reuse a replacement register for the result. Publish
    // the class handle only after every replacement leaf has been consumed.
    if (residence(function.register_slots, value.result)) |register| {
        try words.append(allocator, A64.moveRegister(register, .x12));
    } else try words.append(allocator, A64.storeStack(.x12, value.result));
}

fn residence(slots: []const ?u5, slot: Machine.Slot) ?A64.Register {
    if (slots.len == 0) return null;
    const register = slots[slot] orelse return null;
    return @enumFromInt(register);
}

fn loadSlot(allocator: Allocator, words: *std.ArrayList(u32), function: Machine.Function, destination: A64.Register, slot: Machine.Slot) Error!void {
    if (residence(function.register_slots, slot)) |source| {
        try words.append(allocator, A64.moveRegister(destination, source));
    } else try words.append(allocator, A64.loadStack(destination, slot));
}

fn fail(allocator: Allocator, words: *std.ArrayList(u32), epilogue: *std.ArrayList(Fixups.Local)) Error!void {
    try words.append(allocator, A64.moveWideZero32(.x8, @intFromEnum(Machine.Status.runtime_failure)));
    try Fixups.appendLocal(allocator, words, epilogue, A64.branch(), .imm26);
}

fn addOffset(allocator: Allocator, words: *std.ArrayList(u32), register: A64.Register, offset: u32) Error!void {
    if (offset <= std.math.maxInt(u12)) return words.append(allocator, A64.addSubtractImmediate(register, register, @intCast(offset), true));
    try immediate(allocator, words, .x11, offset);
    try words.append(allocator, A64.addRegisters(register, register, .x11));
}

fn immediate(allocator: Allocator, words: *std.ArrayList(u32), register: A64.Register, value: u64) Error!void {
    try words.append(allocator, A64.moveWideZero64(register, @truncate(value), 0));
    if (value >> 16 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 16), 1));
    if (value >> 32 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 32), 2));
    if (value >> 48 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 48), 3));
}

test "class store consumes replacement before a coalesced result register" {
    if (@import("builtin").os.tag != .macos or @import("builtin").cpu.arch != .aarch64) return;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const function: Machine.Function = .{
        .name = "coalesced_class_store",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .int,
        .return_width = 1,
        .slot_count = 4,
        .frame_size = try Machine.frameSize(4),
        .register_slots = &.{ 0, 1, 1, 2 },
        .instructions = &.{
            .{ .class_store = .{ .base = 0, .result = 2, .byte_offset = 0, .replacement = .{ .start = 1, .width = 1 } } },
            .{ .class_load = .{ .base = 2, .result = .{ .start = 3, .width = 1 }, .byte_offset = 0 } },
            .{ .return_value = .{ .start = 3, .width = 1 } },
        },
    };
    var object = [_]u64{ 0, 1, 0, 0, 7 };
    const result = try @import("Runner.zig").invoke(arena.allocator(), .{ .functions = &.{function} }, 0, &.{ @intCast(@intFromPtr(&object)), 43 });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(@as(i64, 43), result.value);
    try std.testing.expectEqual(@as(u64, 43), object[4]);
}
