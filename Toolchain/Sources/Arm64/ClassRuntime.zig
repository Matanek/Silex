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

test "class aggregate loads keep unused leaves from clobbering live results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_]@import("../Types.zig").Type{ .int, .float32 }) |kind| {
        var function: Machine.Function = .{
            .name = "partial_class_load",
            .parameter_count = 1,
            .parameters = &.{.{ .start = 0, .width = 1 }},
            .return_type = kind,
            .return_width = 1,
            .slot_count = 4,
            .frame_size = try Machine.frameSize(4),
            .instructions = &.{
                .{ .class_load = .{ .base = 0, .byte_offset = 0, .result = .{ .start = 1, .width = 3, .aggregate = true } } },
                .{ .return_value = .{ .start = 1, .width = 1 } },
            },
        };
        const allocation = try @import("RegisterAllocation.zig").allocate(allocator, function);
        function.register_slots = allocation.residences;
        function.float_register_slots = allocation.float_residences;
        function.float_lane_slots = allocation.float_lane_residences;
        for ([_][]const ?u5{ function.register_slots, function.float_register_slots }) |registers| {
            if (registers[1]) |first| {
                try std.testing.expect(registers[2] == null or registers[2].? != first);
                try std.testing.expect(registers[3] == null or registers[3].? != first);
            }
        }
        if (@import("builtin").os.tag != .macos or @import("builtin").cpu.arch != .aarch64) continue;
        const expected: u64 = if (kind == .int) 17 else @as(u32, @bitCast(@as(f32, 17.0)));
        var storage = [_]u64{ 0, 0, 0, 0, expected, 29, 43 };
        const actual = try @import("Runner.zig").invoke(allocator, .{ .functions = &.{function} }, 0, &.{@bitCast(@intFromPtr(&storage))});
        try std.testing.expectEqual(Machine.Status.success, actual.status);
        try std.testing.expectEqual(@as(i64, @bitCast(expected)), actual.value);
    }
}
