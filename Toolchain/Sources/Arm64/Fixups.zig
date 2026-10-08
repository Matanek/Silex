const std = @import("std");
const A64 = @import("Instructions.zig");

pub const Error = error{ BranchOutOfRange, InvalidMachineProgram };

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
    string: usize = 0,
    global: ?usize = null,
    byte_offset: u32 = 0,
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

/// Failure handlers can sit beyond an imm19 branch's one-MiB reach.
/// The normal path skips one imm26 branch without changing flags or registers.
pub fn appendFailureBranch(
    allocator: std.mem.Allocator,
    words: *std.ArrayList(u32),
    fixups: *std.ArrayList(Local),
    instruction: u32,
) (Error || std.mem.Allocator.Error)!void {
    const inverted = if (instruction & 0xff000010 == 0x54000000)
        instruction ^ 1
    else if (instruction & 0x7e000000 == 0x34000000)
        instruction ^ (1 << 24)
    else
        return error.InvalidMachineProgram;
    try words.append(allocator, (inverted & ~@as(u32, 0x7ffff << 5)) | (2 << 5));
    try appendLocal(allocator, words, fixups, A64.branch(), .imm26);
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

test "failure guards preserve predicates and reach handlers beyond one MiB" {
    const instructions = [_]u32{
        A64.conditionalBranch(.equal), A64.conditionalBranch(.overflow),
        A64.compareBranchZero(.x8),    A64.compareBranchNonZero(.x8),
        A64.compareBranchZero64(.x12), A64.compareBranchNonZero64(.x12),
    };
    for (instructions) |instruction| {
        var words: std.ArrayList(u32) = .empty;
        defer words.deinit(std.testing.allocator);
        var fixups: std.ArrayList(Local) = .empty;
        defer fixups.deinit(std.testing.allocator);
        var narrow = [_]u32{instruction};
        try std.testing.expectError(error.BranchOutOfRange, patch19(&narrow, 0, (1 << 18) + 1024));
        try appendFailureBranch(std.testing.allocator, &words, &fixups, instruction);
        try std.testing.expectEqual(@as(usize, 2), words.items.len);
        try std.testing.expectEqual(@as(usize, 1), fixups.items.len);
        try std.testing.expectEqual(Width.imm26, fixups.items[0].width);
        const inversion: u32 = if (instruction & 0xff000010 == 0x54000000) 1 else 1 << 24;
        try std.testing.expectEqual((instruction ^ inversion) | (2 << 5), words.items[0]);
        for ([_]usize{ 2, (1 << 18) + 1024 }) |target| {
            words.items[1] = A64.branch();
            try patchLocal(words.items, fixups.items[0], target);
            try std.testing.expectEqual(@as(u32, @intCast(target - 1)), words.items[1] & 0x03ffffff);
        }
    }
}
