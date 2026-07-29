const std = @import("std");
const A64 = @import("Instructions.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const WindowsImports = @import("../Windows/Imports.zig");

const Allocator = std.mem.Allocator;
pub const Platform = enum { darwin, windows };
pub const Error = Allocator.Error;

const macos_mmap = 197;
const protection_read_write = 3;
const map_private_anonymous = 0x1002;

pub fn emit(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
) Error!void {
    switch (platform) {
        .darwin => {
            try words.append(allocator, A64.moveWideZero32(.x0, 0));
            try words.append(allocator, A64.moveWideZero32(.x2, protection_read_write));
            try words.append(allocator, A64.moveWideZero32(.x3, map_private_anonymous));
            try immediate(allocator, words, .x4, std.math.maxInt(u64));
            try words.append(allocator, A64.moveWideZero32(.x5, 0));
            try words.append(allocator, A64.moveWideZero32(.x16, macos_mmap));
            try words.append(allocator, A64.serviceCall());
        },
        .windows => {
            try words.append(allocator, A64.moveWideZero32(.x0, 0));
            try words.append(allocator, A64.moveWideZero32(.x2, 0x3000));
            try words.append(allocator, A64.moveWideZero32(.x3, 4));
            try sites.append(allocator, .{
                .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
                .function = 0,
                .windows_symbol = WindowsImports.Symbol.virtual_alloc,
            });
            try words.append(allocator, A64.addressPage(.x16));
            try words.append(allocator, A64.load64(.x16, .x16, 0));
            try words.append(allocator, A64.branchLinkRegister(.x16));
        },
    }
}

pub fn failureBranch(platform: Platform) u32 {
    return switch (platform) {
        .darwin => A64.conditionalBranch(.carry_set),
        .windows => A64.compareBranchZero(.x0),
    };
}

fn immediate(allocator: Allocator, words: *std.ArrayList(u32), register: A64.Register, value: u64) Error!void {
    try words.append(allocator, A64.moveWideZero64(register, @truncate(value), 0));
    if (value >> 16 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 16), 1));
    if (value >> 32 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 32), 2));
    if (value >> 48 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 48), 3));
}
