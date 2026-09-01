const std = @import("std");
const A64 = @import("Instructions.zig");

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
    platform: Platform,
) Allocator.Error!void {
    switch (platform) {
        .darwin => try emitUnixCall(allocator, words, platform, 4),
        .linux => try emitUnixCall(allocator, words, platform, 64),
        // Windows ARM64 still owns its imported output boundary in Part 02.
        // Preserve its existing structural image until that target substitutes
        // the import explicitly.
        .windows => {
            try words.append(allocator, A64.moveWideZero32(.x16, 4));
            try words.append(allocator, A64.serviceCall());
        },
    }
}

test "select distinct Darwin and Linux service-call conventions" {
    var words: std.ArrayList(u32) = .empty;
    defer words.deinit(std.testing.allocator);
    try emitWrite(std.testing.allocator, &words, .darwin);
    try emitWrite(std.testing.allocator, &words, .linux);
    try std.testing.expectEqual(A64.moveWideZero32(.x16, 4), words.items[0]);
    try std.testing.expectEqual(A64.serviceCall(), words.items[1]);
    try std.testing.expectEqual(A64.moveWideZero32(.x8, 64), words.items[2]);
    try std.testing.expectEqual(A64.linuxServiceCall(), words.items[3]);
    try std.testing.expectEqual(A64.moveWideZero32(.x8, 0), words.items[4]);
}
