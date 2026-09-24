const std = @import("std");
const A64 = @import("Instructions.zig");
const ExternalCalls = @import("ExternalCalls.zig");
const Fixups = @import("Fixups.zig");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;

// Allocation is a private leaf boundary, not a normal Silex/C call barrier.
// Its callers can keep scratch values (including x8 status and SIMD lanes)
// alive across it. Adapt libc here instead of changing every caller's ABI.
const vector_offset = 160;
const frame_size = vector_offset + 32 * 16;

pub fn append(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    externals: []const Machine.ExternalFunction,
) (Allocator.Error || Fixups.Error)![]const Machine.ExternalFunction {
    var needed = false;
    for (sites.items) |site| if (site.heap_operation != null) {
        needed = true;
        break;
    };
    if (!needed) return allocator.dupe(Machine.ExternalFunction, externals);

    const allocate_at = words.items.len;
    try emitAdapter(allocator, words, sites, externals.len, true);
    const release_at = words.items.len;
    try emitAdapter(allocator, words, sites, externals.len + 1, false);
    var retained: usize = 0;
    for (sites.items) |site| {
        if (site.heap_operation) |operation| {
            try Fixups.patch26(words.items, site.instruction_offset / 4, switch (operation) {
                .allocate => allocate_at,
                .release => release_at,
            });
        } else {
            sites.items[retained] = site;
            retained += 1;
        }
    }
    sites.shrinkRetainingCapacity(retained);
    const result = try allocator.alloc(Machine.ExternalFunction, externals.len + 2);
    @memcpy(result[0..externals.len], externals);
    result[externals.len] = .{
        .provider = "Darwin.lib_system",
        .source_name = "calloc",
        .signature = .{ .arguments = &.{ .uint64, .uint64 }, .result = .read_address },
    };
    result[externals.len + 1] = .{
        .provider = "Darwin.lib_system",
        .source_name = "free",
        .signature = .{ .arguments = &.{.read_address}, .result = null },
    };
    return result;
}

fn emitAdapter(
    allocator: Allocator,
    words: *std.ArrayList(u32),
    sites: *std.ArrayList(ExternalCalls.Site),
    function: usize,
    allocate: bool,
) Allocator.Error!void {
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, frame_size, false));
    for (0..18) |index| try words.append(allocator, A64.store64(@enumFromInt(index), .zero_or_sp, @intCast(index * 8)));
    try words.append(allocator, A64.store64(.x30, .zero_or_sp, 144));
    // Preserve full 128-bit vectors, not just AAPCS64's low halves of d8-d15.
    for (0..32) |index| try words.append(allocator, vectorStack(@intCast(index), @intCast(vector_offset + index * 16), false));
    if (allocate) try words.append(allocator, A64.moveWideZero32(.x0, 1));
    try sites.append(allocator, .{ .instruction_offset = @intCast(words.items.len * 4), .function = function });
    try words.append(allocator, A64.addressPage(.x16));
    try words.append(allocator, A64.load64(.x16, .x16, 0));
    try words.append(allocator, A64.branchLinkRegister(.x16));
    for (0..32) |index| try words.append(allocator, vectorStack(@intCast(index), @intCast(vector_offset + index * 16), true));
    for (@as(usize, if (allocate) 1 else 0)..18) |index| try words.append(allocator, A64.load64(@enumFromInt(index), .zero_or_sp, @intCast(index * 8)));
    try words.append(allocator, A64.load64(.x30, .zero_or_sp, 144));
    try words.append(allocator, A64.addSubtractImmediate(.zero_or_sp, .zero_or_sp, frame_size, true));
    try words.append(allocator, A64.returnInstruction());
}

fn vectorStack(register: u5, offset: u12, load: bool) u32 {
    std.debug.assert(offset % 16 == 0);
    return (if (load) @as(u32, 0x3dc00000) else 0x3d800000) |
        (@as(u32, offset / 16) << 10) | (31 << 5) | register;
}

test "heap adapters preserve scratch state and resolve only their own calls" {
    var words: std.ArrayList(u32) = .empty;
    defer words.deinit(std.testing.allocator);
    var sites: std.ArrayList(ExternalCalls.Site) = .empty;
    defer sites.deinit(std.testing.allocator);
    try @import("Allocation.zig").emit(std.testing.allocator, &words, &sites, .darwin);
    try @import("Allocation.zig").emitFree(std.testing.allocator, &words, &sites, .darwin);
    const functions = try append(std.testing.allocator, &words, &sites, &.{});
    defer std.testing.allocator.free(functions);
    try std.testing.expectEqual(@as(usize, 2), functions.len);
    try std.testing.expectEqualStrings("calloc", functions[0].source_name);
    try std.testing.expectEqualStrings("free", functions[1].source_name);
    try std.testing.expectEqual(@as(usize, 2), sites.items.len);
    try std.testing.expectEqual(@as(usize, 0), sites.items[0].function);
    try std.testing.expectEqual(@as(usize, 1), sites.items[1].function);
    try std.testing.expectEqual(@as(u32, 0x94000002), words.items[0]);
    try std.testing.expectEqual(@as(u32, 0x3d8027e0), vectorStack(0, 144, false));
    try std.testing.expectEqual(@as(u32, 0x3dc027e0), vectorStack(0, 144, true));
    for (0..18) |index| {
        const register: A64.Register = @enumFromInt(index);
        const offset: u12 = @intCast(index * 8);
        try std.testing.expectEqual(@as(usize, 2), std.mem.count(u32, words.items, &.{A64.store64(register, .zero_or_sp, offset)}));
        try std.testing.expectEqual(@as(usize, if (index == 0) 1 else 2), std.mem.count(u32, words.items, &.{A64.load64(register, .zero_or_sp, offset)}));
    }
    for (0..32) |index| {
        const offset: u12 = @intCast(vector_offset + index * 16);
        try std.testing.expectEqual(@as(usize, 2), std.mem.count(u32, words.items, &.{vectorStack(@intCast(index), offset, false)}));
        try std.testing.expectEqual(@as(usize, 2), std.mem.count(u32, words.items, &.{vectorStack(@intCast(index), offset, true)}));
    }
    for (words.items) |word| try std.testing.expect(word != A64.serviceCall());
}

test "images without heap operations retain their original imports" {
    var words: std.ArrayList(u32) = .empty;
    defer words.deinit(std.testing.allocator);
    var sites: std.ArrayList(ExternalCalls.Site) = .empty;
    defer sites.deinit(std.testing.allocator);
    const functions = try append(std.testing.allocator, &words, &sites, &.{.{
        .provider = "Darwin.lib_system",
        .source_name = "getpid",
        .signature = .{ .arguments = &.{}, .result = .int32 },
    }});
    defer std.testing.allocator.free(functions);
    try std.testing.expectEqual(@as(usize, 1), functions.len);
    try std.testing.expectEqualStrings("getpid", functions[0].source_name);
    try std.testing.expectEqual(@as(usize, 0), words.items.len);
    try std.testing.expectEqual(@as(usize, 0), sites.items.len);
}
