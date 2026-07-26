const std = @import("std");
const A64 = @import("Instructions.zig");

pub const Error = error{BranchOutOfRange};

pub const Width = enum { imm19, imm26 };

pub const Local = struct {
    at: usize,
    width: Width,
};

pub const Control = struct {
    at: usize,
    target: usize,
    width: Width,
};

pub const Call = struct {
    at: usize,
    function: @import("Machine.zig").FunctionId,
};

pub const Data = struct {
    at: usize,
    string: usize,
    byte_offset: u8 = 0,
};

pub fn appendLocal(
    allocator: std.mem.Allocator,
    words: *std.ArrayList(u32),
    fixups: *std.ArrayList(Local),
    instruction: u32,
    width: Width,
) std.mem.Allocator.Error!void {
    try fixups.append(allocator, .{ .at = words.items.len, .width = width });
    try words.append(allocator, instruction);
}

pub fn patchLocal(words: []u32, fixup: Local, target: usize) Error!void {
    return switch (fixup.width) {
        .imm19 => patch19(words, fixup.at, target),
        .imm26 => patch26(words, fixup.at, target),
    };
}

pub fn patch19(words: []u32, at: usize, target: usize) Error!void {
    const delta: i64 = @as(i64, @intCast(target)) - @as(i64, @intCast(at));
    if (delta < -(1 << 18) or delta >= (1 << 18)) return error.BranchOutOfRange;
    const immediate: u32 = @bitCast(@as(i32, @intCast(delta)));
    words[at] |= (immediate & 0x7ffff) << 5;
}

pub fn patch26(words: []u32, at: usize, target: usize) Error!void {
    const delta: i64 = @as(i64, @intCast(target)) - @as(i64, @intCast(at));
    if (delta < -(1 << 25) or delta >= (1 << 25)) return error.BranchOutOfRange;
    const immediate: u32 = @bitCast(@as(i32, @intCast(delta)));
    words[at] |= immediate & 0x03ffffff;
}

pub fn patchAdr(words: []u32, at: usize, target_byte: usize) Error!void {
    const instruction_byte = at * 4;
    const delta = @as(i64, @intCast(target_byte)) - @as(i64, @intCast(instruction_byte));
    if (delta < -(1 << 20) or delta >= (1 << 20)) return error.BranchOutOfRange;
    const immediate: u32 = @bitCast(@as(i32, @intCast(delta)));
    words[at] |= ((immediate & 0x3) << 29) | (((immediate >> 2) & 0x7ffff) << 5);
}

test "patch local forward branches" {
    var words = [_]u32{ A64.conditionalBranch(.equal), A64.branch(), 0 };
    try patch19(&words, 0, 2);
    try patch26(&words, 1, 2);
    try std.testing.expectEqual(@as(u32, 0x54000040), words[0]);
    try std.testing.expectEqual(@as(u32, 0x14000001), words[1]);
}
