const std = @import("std");
const A64 = @import("Instructions.zig");
const ExternalCalls = @import("ExternalCalls.zig");

const Allocator = std.mem.Allocator;

pub const Platform = enum { darwin, linux, windows };

pub fn emitUnixCall(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    platform: Platform,
    number: u16,
) Allocator.Error!void {
    switch (platform) {
        .darwin => {
            try words.append(allocator, A64.moveWideZero32(.x16, number));
            try words.append(allocator, A64.serviceCall());
        },
        .linux => {
            try words.append(allocator, A64.moveWideZero32(.x8, number));
            try words.append(allocator, A64.linuxServiceCall());
            try words.append(allocator, A64.moveWideZero32(.x8, 0));
        },
        .windows => unreachable,
    }
}

pub fn emitWrite(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    external_call_sites: *std.ArrayList(ExternalCalls.Site),
    platform: Platform,
) Allocator.Error!void {
    switch (platform) {
        .darwin => try emitUnixCall(allocator, words, platform, 4),
        .linux => try emitUnixCall(allocator, words, platform, 64),
        .windows => {
            try external_call_sites.append(allocator, .{
                .instruction_offset = @intCast(words.items.len * @sizeOf(u32)),
                .function = 0,
                .windows_symbol = .crt_write,
            });
            try words.append(allocator, A64.addressPage(.x16));
            try words.append(allocator, A64.load64(.x16, .x16, 0));
            try words.append(allocator, A64.branchLinkRegister(.x16));
        },
    }
}

test "select distinct Darwin and Linux service-call conventions" {
    var words: std.ArrayList(u32) = .empty;
    defer words.deinit(std.testing.allocator);
    var sites: std.ArrayList(ExternalCalls.Site) = .empty;
    defer sites.deinit(std.testing.allocator);
    try emitWrite(std.testing.allocator, &words, &sites, .darwin);
    try emitWrite(std.testing.allocator, &words, &sites, .linux);
    try std.testing.expectEqual(A64.moveWideZero32(.x16, 4), words.items[0]);
    try std.testing.expectEqual(A64.serviceCall(), words.items[1]);
    try std.testing.expectEqual(A64.moveWideZero32(.x8, 64), words.items[2]);
    try std.testing.expectEqual(A64.linuxServiceCall(), words.items[3]);
    try std.testing.expectEqual(A64.moveWideZero32(.x8, 0), words.items[4]);
    try std.testing.expectEqual(@as(usize, 0), sites.items.len);
}
