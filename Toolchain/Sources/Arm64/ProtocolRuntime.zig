const std = @import("std");
const Machine = @import("Machine.zig");
const A64 = @import("Instructions.zig");
const Fixups = @import("Fixups.zig");

pub fn emitInit(allocator: std.mem.Allocator, words: *std.ArrayList(u32), value: Machine.Instruction.ProtocolInit) !void {
    if (value.class_operand) {
        try words.append(allocator, A64.loadStack(.x10, value.operand.start));
        try words.append(allocator, A64.load64(.x9, .x10, 0));
    } else try immediate(allocator, words, .x9, value.structure);
    try words.append(allocator, A64.storeStack(.x9, value.result.start));
    for (0..value.operand.width) |leaf| {
        try words.append(allocator, A64.loadStack(.x9, @intCast(@as(usize, value.operand.start) + leaf)));
        try words.append(allocator, A64.storeStack(.x9, @intCast(@as(usize, value.result.start) + 1 + leaf)));
    }
    try words.append(allocator, A64.moveWideZero64(.x9, 0, 0));
    for (value.operand.width + 1..value.result.width) |leaf| {
        try words.append(allocator, A64.storeStack(.x9, @intCast(@as(usize, value.result.start) + leaf)));
    }
}

pub fn emitTest(allocator: std.mem.Allocator, words: *std.ArrayList(u32), value: Machine.Instruction.ProtocolTest) !void {
    try words.append(allocator, A64.loadStack(.x9, value.operand));
    try immediate(allocator, words, .x10, value.structure);
    try words.append(allocator, A64.compareRegisters(.x9, .x10));
    const unequal = words.items.len;
    try words.append(allocator, A64.conditionalBranch(.not_equal));
    try words.append(allocator, A64.moveWideZero32(.x9, 1));
    try words.append(allocator, A64.storeStack(.x9, value.result));
    const done = words.items.len;
    try words.append(allocator, A64.branch());
    try Fixups.patch19(words.items, unequal, words.items.len);
    try words.append(allocator, A64.moveWideZero32(.x9, 0));
    try words.append(allocator, A64.storeStack(.x9, value.result));
    try Fixups.patch26(words.items, done, words.items.len);
}

pub fn emitExtract(allocator: std.mem.Allocator, words: *std.ArrayList(u32), value: Machine.Instruction.ProtocolExtract) !void {
    for (0..value.result.width) |leaf| {
        try words.append(allocator, A64.loadStack(.x9, @intCast(@as(usize, value.operand.start) + 1 + leaf)));
        try words.append(allocator, A64.storeStack(.x9, @intCast(@as(usize, value.result.start) + leaf)));
    }
}

fn immediate(allocator: std.mem.Allocator, words: *std.ArrayList(u32), register: A64.Register, value: u64) !void {
    try words.append(allocator, A64.moveWideZero64(register, @truncate(value), 0));
    try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 16), 1));
    try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 32), 2));
    try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 48), 3));
}
