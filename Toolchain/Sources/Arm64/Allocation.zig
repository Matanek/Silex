const std = @import("std");
const A64 = @import("Instructions.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const System = @import("System.zig");

const Allocator = std.mem.Allocator;
pub const Platform = System.Platform;
pub const Error = Allocator.Error;

const protection_read_write = 3;
const linux_mmap = 222;
const linux_munmap = 215;
const linux_map_private_anonymous = 0x22;

pub fn emit(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
) Error!void {
    switch (platform) {
        .darwin, .windows => {
            try sites.append(allocator, .{
                .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
                .function = 0,
                .heap_operation = .allocate,
            });
            try words.append(allocator, A64.branchLink());
        },
        .linux => {
            try words.append(allocator, A64.moveWideZero32(.x0, 0));
            try words.append(allocator, A64.moveWideZero32(.x2, protection_read_write));
            try words.append(allocator, A64.moveWideZero32(.x3, linux_map_private_anonymous));
            try immediate(allocator, words, .x4, std.math.maxInt(u64));
            try words.append(allocator, A64.moveWideZero32(.x5, 0));
            try System.emitUnixCall(allocator, words, platform, linux_mmap);
            try words.append(allocator, A64.compareRegisters(.x0, .zero_or_sp));
        },
    }
}

pub fn failureBranch(platform: Platform) u32 {
    return switch (platform) {
        .darwin, .windows => A64.compareBranchZero64(.x0),
        .linux => A64.conditionalBranch(.less),
    };
}

pub fn emitFree(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
) Error!void {
    switch (platform) {
        .darwin, .windows => {
            try sites.append(allocator, .{
                .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
                .function = 0,
                .heap_operation = .release,
            });
            try words.append(allocator, A64.branchLink());
        },
        .linux => try System.emitUnixCall(allocator, words, platform, linux_munmap),
    }
}

fn immediate(allocator: Allocator, words: *std.ArrayList(u32), register: A64.Register, value: u64) Error!void {
    try words.append(allocator, A64.moveWideZero64(register, @truncate(value), 0));
    if (value >> 16 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 16), 1));
    if (value >> 32 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 32), 2));
    if (value >> 48 != 0) try words.append(allocator, A64.moveWideKeep64(register, @truncate(value >> 48), 3));
}
