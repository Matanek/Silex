const std = @import("std");
const macho = std.macho;

const ExternalCalls = @import("../Arm64/ExternalCalls.zig");
const Machine = @import("../Arm64/Machine.zig");

const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || error{InvalidExternalFixup};

pub const library_path = "/usr/lib/libSystem.B.dylib\x00";

pub fn symbolName(allocator: Allocator, function: Machine.ExternalFunction) Allocator.Error![]const u8 {
    return std.fmt.allocPrint(allocator, "_{s}", .{function.source_name});
}

pub fn bindInfo(
    allocator: Allocator,
    functions: []const Machine.ExternalFunction,
    got_segment: u4,
) Allocator.Error![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    for (functions, 0..) |function, index| {
        try bytes.append(allocator, macho.BIND_OPCODE_SET_DYLIB_ORDINAL_IMM | 1);
        try bytes.append(allocator, macho.BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM);
        const symbol = try symbolName(allocator, function);
        try bytes.appendSlice(allocator, symbol);
        try bytes.append(allocator, 0);
        try bytes.append(allocator, macho.BIND_OPCODE_SET_TYPE_IMM | macho.BIND_TYPE_POINTER);
        try bytes.append(allocator, macho.BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB | got_segment);
        try appendUleb(allocator, &bytes, index * @sizeOf(u64));
        try bytes.append(allocator, macho.BIND_OPCODE_DO_BIND);
    }
    try bytes.append(allocator, macho.BIND_OPCODE_DONE);
    return bytes.toOwnedSlice(allocator);
}

pub fn stringTable(
    allocator: Allocator,
    functions: []const Machine.ExternalFunction,
) Allocator.Error![]u8 {
    var bytes: std.ArrayList(u8) = .empty;
    try bytes.append(allocator, 0);
    for (functions) |function| {
        const symbol = try symbolName(allocator, function);
        try bytes.appendSlice(allocator, symbol);
        try bytes.append(allocator, 0);
    }
    return bytes.toOwnedSlice(allocator);
}

pub fn appendSymbols(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    functions: []const Machine.ExternalFunction,
) Allocator.Error!void {
    var string_offset: u32 = 1;
    for (functions) |function| {
        var symbol: macho.nlist_64 = .{
            .n_strx = string_offset,
            .n_type = .{ .bits = .{ .ext = true, .type = .undf, .pext = false, .is_stab = 0 } },
            .n_sect = 0,
            .n_desc = @bitCast(@as(u16, 1 << 8)),
            .n_value = 0,
        };
        try bytes.appendSlice(allocator, std.mem.asBytes(&symbol));
        string_offset += @intCast(1 + function.source_name.len + 1);
    }
}

pub fn patchCalls(
    code: []u8,
    sites: []const ExternalCalls.Site,
    function_count: usize,
    text_address: u64,
    got_address: u64,
) Error!void {
    for (sites) |site| {
        if (site.function >= function_count or site.instruction_offset + 3 * @sizeOf(u32) > code.len) {
            return error.InvalidExternalFixup;
        }
        const instruction_address = text_address + site.instruction_offset;
        const target_address = got_address + site.function * @sizeOf(u64);
        const page_delta = @as(i64, @intCast(target_address >> 12)) - @as(i64, @intCast(instruction_address >> 12));
        if (page_delta < -0x10_0000 or page_delta >= 0x10_0000) return error.InvalidExternalFixup;
        const immediate: u21 = @bitCast(@as(i21, @intCast(page_delta)));
        var instruction = std.mem.readInt(u32, code[site.instruction_offset..][0..4], .little);
        if ((instruction & 0x9f000000) != 0x90000000) return error.InvalidExternalFixup;
        instruction |= (@as(u32, immediate & 0x3) << 29) | (@as(u32, immediate >> 2) << 5);
        std.mem.writeInt(u32, code[site.instruction_offset..][0..4], instruction, .little);

        const page_offset = target_address & 0xfff;
        if (page_offset % 8 != 0 or page_offset / 8 > 0xfff) return error.InvalidExternalFixup;
        var load = std.mem.readInt(u32, code[site.instruction_offset + 4 ..][0..4], .little);
        if ((load & 0xffc003ff) != 0xf9400210) return error.InvalidExternalFixup;
        load |= @as(u32, @intCast(page_offset / 8)) << 10;
        std.mem.writeInt(u32, code[site.instruction_offset + 4 ..][0..4], load, .little);
    }
}

fn appendUleb(allocator: Allocator, bytes: *std.ArrayList(u8), input: usize) Allocator.Error!void {
    var value = input;
    while (true) {
        var byte: u8 = @truncate(value & 0x7f);
        value >>= 7;
        if (value != 0) byte |= 0x80;
        try bytes.append(allocator, byte);
        if (value == 0) return;
    }
}
