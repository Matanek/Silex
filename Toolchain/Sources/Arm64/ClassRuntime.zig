const std = @import("std");
const Machine = @import("Machine.zig");
const A64 = @import("Instructions.zig");
const Fixups = @import("Fixups.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const Allocation = @import("Allocation.zig");
const WindowsImports = @import("../Windows/Imports.zig");

const Allocator = std.mem.Allocator;
pub const Error = Machine.Error || Allocator.Error || Fixups.Error;
pub const Platform = Allocation.Platform;

pub fn emitInit(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    epilogue: *std.ArrayList(Fixups.Local),
    external_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
    value: Machine.Instruction.ClassInit,
) Error!void {
    var width: usize = 0;
    for (value.fields) |field| width += field.width;
    try immediate(allocator, words, .x1, (width + 4) * Machine.slot_size);
    switch (platform) {
        .darwin, .linux => try Allocation.emit(allocator, words, external_sites, platform),
        .windows => {
            try immediate(allocator, words, .x0, 0);
            try immediate(allocator, words, .x1, (width + 4) * Machine.slot_size);
            try immediate(allocator, words, .x2, 0x3000);
            try immediate(allocator, words, .x3, 4);
            try external_sites.append(allocator, .{
                .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
                .function = 0,
                .windows_symbol = WindowsImports.Symbol.virtual_alloc,
            });
            try words.append(allocator, A64.addressPage(.x16));
            try words.append(allocator, A64.load64(.x16, .x16, 0));
            try words.append(allocator, A64.branchLinkRegister(.x16));
        },
    }
    const failed = words.items.len;
    try words.append(allocator, switch (platform) {
        .darwin, .linux => Allocation.failureBranch(platform),
        .windows => A64.compareBranchZero(.x0),
    });
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
    try words.append(allocator, A64.storeStack(.x15, value.result));
    const done = words.items.len;
    try words.append(allocator, A64.branch());
    try Fixups.patch19(words.items, failed, words.items.len);
    try fail(allocator, words, epilogue);
    try Fixups.patch26(words.items, done, words.items.len);
}

pub fn emitLoad(allocator: Allocator, words: *std.ArrayList(u32), value: Machine.Instruction.ClassLoad) Error!void {
    try words.append(allocator, A64.loadStack(.x10, value.base));
    try addOffset(allocator, words, .x10, 4 * Machine.slot_size);
    if (value.byte_offset != 0) try addOffset(allocator, words, .x10, value.byte_offset);
    for (0..value.result.width) |leaf| {
        try words.append(allocator, A64.load64(.x9, .x10, @intCast(leaf * Machine.slot_size)));
        try words.append(allocator, A64.storeStack(.x9, @intCast(@as(usize, value.result.start) + leaf)));
    }
}

pub fn emitStore(allocator: Allocator, words: *std.ArrayList(u32), value: Machine.Instruction.ClassStore) Error!void {
    try words.append(allocator, A64.loadStack(.x10, value.base));
    try words.append(allocator, A64.storeStack(.x10, value.result));
    try addOffset(allocator, words, .x10, 4 * Machine.slot_size);
    if (value.byte_offset != 0) try addOffset(allocator, words, .x10, value.byte_offset);
    for (0..value.replacement.width) |leaf| {
        try words.append(allocator, A64.loadStack(.x9, @intCast(@as(usize, value.replacement.start) + leaf)));
        try words.append(allocator, A64.store64(.x9, .x10, @intCast(leaf * Machine.slot_size)));
    }
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
