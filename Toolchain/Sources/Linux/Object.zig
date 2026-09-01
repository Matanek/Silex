const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Architecture = enum {
    x64,
    arm64,

    fn machine(self: Architecture) u16 {
        return switch (self) {
            .x64 => 62,
            .arm64 => 183,
        };
    }
};

pub const RelocationKind = enum {
    x64_pc32,
    arm64_call26,
    arm64_page21,
    arm64_pageoff12_add,
    arm64_pageoff12_load64,

    fn number(self: RelocationKind) u32 {
        return switch (self) {
            .x64_pc32 => 4,
            .arm64_call26 => 283,
            .arm64_page21 => 275,
            .arm64_pageoff12_add => 277,
            .arm64_pageoff12_load64 => 286,
        };
    }

    fn belongsTo(self: RelocationKind, architecture: Architecture) bool {
        return switch (architecture) {
            .x64 => self == .x64_pc32,
            .arm64 => self != .x64_pc32,
        };
    }
};

pub const Target = union(enum) {
    text,
    external: []const u8,
};

pub const Relocation = struct {
    offset: u32,
    kind: RelocationKind,
    target: Target,
    addend: i64 = 0,
};

pub const Error = Allocator.Error || error{InvalidImage};

pub fn emit(
    allocator: Allocator,
    architecture: Architecture,
    code: []const u8,
    entry_offset: u32,
    relocations: []const Relocation,
) Error![]u8 {
    if (entry_offset >= code.len) return error.InvalidImage;
    var external_names: std.ArrayList([]const u8) = .empty;
    defer external_names.deinit(allocator);
    for (relocations) |relocation| {
        if (!relocation.kind.belongsTo(architecture) or relocation.offset >= code.len) return error.InvalidImage;
        const name = switch (relocation.target) {
            .text => continue,
            .external => |value| value,
        };
        var found = false;
        for (external_names.items) |existing| if (std.mem.eql(u8, existing, name)) {
            found = true;
            break;
        };
        if (!found) try external_names.append(allocator, name);
    }

    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    try strings.append(allocator, 0);
    const main_name = try addString(allocator, &strings, "main");
    const external_name_offsets = try allocator.alloc(u32, external_names.items.len);
    defer allocator.free(external_name_offsets);
    for (external_names.items, 0..) |name, index| external_name_offsets[index] = try addString(allocator, &strings, name);

    const section_names = "\x00.text\x00.rela.text\x00.symtab\x00.strtab\x00.shstrtab\x00.note.GNU-stack\x00";
    const header_size: usize = 64;
    const text_offset = std.mem.alignForward(usize, header_size, 16);
    const relocation_offset = std.mem.alignForward(usize, text_offset + code.len, 8);
    const relocation_size = relocations.len * 24;
    const symbol_offset = std.mem.alignForward(usize, relocation_offset + relocation_size, 8);
    const symbol_count = 3 + external_names.items.len;
    const symbol_size = symbol_count * 24;
    const string_offset = symbol_offset + symbol_size;
    const section_string_offset = string_offset + strings.items.len;
    const section_offset = std.mem.alignForward(usize, section_string_offset + section_names.len, 8);
    const section_count: u16 = 7;

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.ensureTotalCapacity(allocator, section_offset + @as(usize, section_count) * 64);
    try bytes.appendSlice(allocator, "\x7fELF");
    try bytes.appendSlice(allocator, &.{ 2, 1, 1, 0, 0 });
    try bytes.appendNTimes(allocator, 0, 7);
    try appendInt(allocator, &bytes, u16, 1);
    try appendInt(allocator, &bytes, u16, architecture.machine());
    try appendInt(allocator, &bytes, u32, 1);
    try appendInt(allocator, &bytes, u64, 0);
    try appendInt(allocator, &bytes, u64, 0);
    try appendInt(allocator, &bytes, u64, section_offset);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u16, header_size);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u16, 64);
    try appendInt(allocator, &bytes, u16, section_count);
    try appendInt(allocator, &bytes, u16, 5);
    try padTo(allocator, &bytes, text_offset);
    try bytes.appendSlice(allocator, code);
    try padTo(allocator, &bytes, relocation_offset);
    for (relocations) |relocation| {
        const symbol: u32 = switch (relocation.target) {
            .text => 1,
            .external => |name| symbol: {
                for (external_names.items, 0..) |external, index| {
                    if (std.mem.eql(u8, external, name)) break :symbol @intCast(3 + index);
                }
                return error.InvalidImage;
            },
        };
        try appendInt(allocator, &bytes, u64, relocation.offset);
        try appendInt(allocator, &bytes, u64, (@as(u64, symbol) << 32) | relocation.kind.number());
        try appendInt(allocator, &bytes, i64, relocation.addend);
    }
    try padTo(allocator, &bytes, symbol_offset);
    try bytes.appendNTimes(allocator, 0, 24);
    try appendSymbol(allocator, &bytes, 0, 0x03, 1, 0, 0);
    try appendSymbol(allocator, &bytes, main_name, 0x12, 1, entry_offset, code.len - entry_offset);
    for (external_name_offsets) |name| try appendSymbol(allocator, &bytes, name, 0x10, 0, 0, 0);
    try padTo(allocator, &bytes, string_offset);
    try bytes.appendSlice(allocator, strings.items);
    try bytes.appendSlice(allocator, section_names);
    try padTo(allocator, &bytes, section_offset);
    try bytes.appendNTimes(allocator, 0, 64);
    try appendSection(allocator, &bytes, 1, 1, 0x7, text_offset, code.len, 0, 0, 16, 0);
    try appendSection(allocator, &bytes, 7, 4, 0, relocation_offset, relocation_size, 3, 1, 8, 24);
    try appendSection(allocator, &bytes, 18, 2, 0, symbol_offset, symbol_size, 4, 2, 8, 24);
    try appendSection(allocator, &bytes, 26, 3, 0, string_offset, strings.items.len, 0, 0, 1, 0);
    try appendSection(allocator, &bytes, 34, 3, 0, section_string_offset, section_names.len, 0, 0, 1, 0);
    try appendSection(allocator, &bytes, 44, 1, 0, section_string_offset + section_names.len, 0, 0, 0, 1, 0);
    return bytes.toOwnedSlice(allocator);
}

fn appendSymbol(allocator: Allocator, bytes: *std.ArrayList(u8), name: u32, info: u8, section: u16, value: usize, size: usize) !void {
    try appendInt(allocator, bytes, u32, name);
    try bytes.appendSlice(allocator, &.{ info, 0 });
    try appendInt(allocator, bytes, u16, section);
    try appendInt(allocator, bytes, u64, value);
    try appendInt(allocator, bytes, u64, size);
}

fn appendSection(allocator: Allocator, bytes: *std.ArrayList(u8), name: u32, kind: u32, flags: u64, offset: usize, size: usize, link: u32, info: u32, alignment: u64, entry_size: u64) !void {
    try appendInt(allocator, bytes, u32, name);
    try appendInt(allocator, bytes, u32, kind);
    try appendInt(allocator, bytes, u64, flags);
    try appendInt(allocator, bytes, u64, 0);
    try appendInt(allocator, bytes, u64, offset);
    try appendInt(allocator, bytes, u64, size);
    try appendInt(allocator, bytes, u32, link);
    try appendInt(allocator, bytes, u32, info);
    try appendInt(allocator, bytes, u64, alignment);
    try appendInt(allocator, bytes, u64, entry_size);
}

fn addString(allocator: Allocator, strings: *std.ArrayList(u8), value: []const u8) !u32 {
    const offset: u32 = @intCast(strings.items.len);
    try strings.appendSlice(allocator, value);
    try strings.append(allocator, 0);
    return offset;
}

fn padTo(allocator: Allocator, bytes: *std.ArrayList(u8), offset: usize) !void {
    if (bytes.items.len > offset) return error.InvalidImage;
    try bytes.appendNTimes(allocator, 0, offset - bytes.items.len);
}

fn appendInt(allocator: Allocator, bytes: *std.ArrayList(u8), comptime T: type, value: anytype) !void {
    var storage: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &storage, @as(T, @intCast(value)), .little);
    try bytes.appendSlice(allocator, &storage);
}

test "emit architecture-specific ELF relocatable objects" {
    const code = [_]u8{ 0, 0, 0, 0 };
    const x64 = try emit(std.testing.allocator, .x64, &code, 0, &.{.{
        .offset = 0,
        .kind = .x64_pc32,
        .target = .{ .external = "answer" },
        .addend = -4,
    }});
    defer std.testing.allocator.free(x64);
    try std.testing.expectEqual(@as(u16, 62), std.mem.readInt(u16, x64[18..20], .little));
    const arm64 = try emit(std.testing.allocator, .arm64, &code, 0, &.{.{
        .offset = 0,
        .kind = .arm64_call26,
        .target = .{ .external = "answer" },
    }});
    defer std.testing.allocator.free(arm64);
    try std.testing.expectEqual(@as(u16, 183), std.mem.readInt(u16, arm64[18..20], .little));
}
