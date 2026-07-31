const std = @import("std");
const Encoder = @import("Encoder.zig");
const Machine = @import("../Arm64/Machine.zig");
const WindowsImports = @import("../Windows/Imports.zig");

const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || error{InvalidImage};

pub fn emitElf(
    allocator: Allocator,
    program: Machine.Program,
    image: Encoder.Image,
) Error![]u8 {
    var symbol_for_function = try allocator.alloc(u32, program.external_functions.len);
    defer allocator.free(symbol_for_function);
    @memset(symbol_for_function, 0);
    var used_function = try allocator.alloc(bool, program.external_functions.len);
    defer allocator.free(used_function);
    @memset(used_function, false);
    var name_for_function = try allocator.alloc(u32, program.external_functions.len);
    defer allocator.free(name_for_function);

    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    try strings.append(allocator, 0);
    const main_name = try addString(allocator, &strings, "main");
    for (image.external_call_sites) |site| {
        if (site.function >= program.external_functions.len) return error.InvalidImage;
        used_function[site.function] = true;
    }
    var symbol_count: u32 = 2;
    for (program.external_functions, 0..) |external, index| {
        if (!used_function[index]) continue;
        symbol_for_function[index] = symbol_count;
        symbol_count += 1;
        name_for_function[index] = try addString(allocator, &strings, external.source_name);
    }

    const section_names = "\x00.text\x00.rela.text\x00.symtab\x00.strtab\x00.shstrtab\x00.note.GNU-stack\x00";
    const text_name: u32 = 1;
    const rela_name: u32 = 7;
    const symtab_name: u32 = 18;
    const strtab_name: u32 = 26;
    const shstrtab_name: u32 = 34;
    const stack_name: u32 = 44;

    const header_size: usize = 64;
    const text_offset = std.mem.alignForward(usize, header_size, 16);
    const rela_offset = std.mem.alignForward(usize, text_offset + image.code.len, 8);
    const rela_size = image.external_call_sites.len * 24;
    const symbol_offset = std.mem.alignForward(usize, rela_offset + rela_size, 8);
    const symbol_size = @as(usize, symbol_count) * 24;
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
    try appendInt(allocator, &bytes, u16, 62);
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
    try bytes.appendSlice(allocator, image.code);
    try padTo(allocator, &bytes, rela_offset);
    for (image.external_call_sites) |site| {
        if (@as(usize, site.displacement_offset) + 4 > image.code.len) return error.InvalidImage;
        try appendInt(allocator, &bytes, u64, site.displacement_offset);
        try appendInt(allocator, &bytes, u64, (@as(u64, symbol_for_function[site.function]) << 32) | 4);
        try appendInt(allocator, &bytes, i64, -4);
    }
    try padTo(allocator, &bytes, symbol_offset);
    try bytes.appendNTimes(allocator, 0, 24);
    try appendElfSymbol(allocator, &bytes, main_name, 0x12, 1, image.entry_offset, image.code.len - image.entry_offset);
    var function_index: usize = 0;
    while (function_index < symbol_for_function.len) : (function_index += 1) {
        if (symbol_for_function[function_index] == 0) continue;
        try appendElfSymbol(allocator, &bytes, name_for_function[function_index], 0x10, 0, 0, 0);
    }
    try padTo(allocator, &bytes, string_offset);
    try bytes.appendSlice(allocator, strings.items);
    try bytes.appendSlice(allocator, section_names);
    try padTo(allocator, &bytes, section_offset);
    try bytes.appendNTimes(allocator, 0, 64);
    try appendElfSection(allocator, &bytes, text_name, 1, 0x7, text_offset, image.code.len, 0, 0, 16, 0);
    try appendElfSection(allocator, &bytes, rela_name, 4, 0, rela_offset, rela_size, 3, 1, 8, 24);
    try appendElfSection(allocator, &bytes, symtab_name, 2, 0, symbol_offset, symbol_size, 4, 1, 8, 24);
    try appendElfSection(allocator, &bytes, strtab_name, 3, 0, string_offset, strings.items.len, 0, 0, 1, 0);
    try appendElfSection(allocator, &bytes, shstrtab_name, 3, 0, section_string_offset, section_names.len, 0, 0, 1, 0);
    try appendElfSection(allocator, &bytes, stack_name, 1, 0, section_string_offset + section_names.len, 0, 0, 0, 1, 0);
    return bytes.toOwnedSlice(allocator);
}

pub fn emitCoff(
    allocator: Allocator,
    program: Machine.Program,
    image: Encoder.Image,
) Error![]u8 {
    var symbol_for_function = try allocator.alloc(u32, program.external_functions.len);
    defer allocator.free(symbol_for_function);
    @memset(symbol_for_function, std.math.maxInt(u32));
    var symbol_for_import = [_]u32{std.math.maxInt(u32)} ** @typeInfo(WindowsImports.Symbol).@"enum".fields.len;
    var symbol_names: std.ArrayList([]const u8) = .empty;
    defer symbol_names.deinit(allocator);
    try symbol_names.append(allocator, "main");
    for (image.external_call_sites) |site| {
        if (site.function >= program.external_functions.len) return error.InvalidImage;
        if (symbol_for_function[site.function] != std.math.maxInt(u32)) continue;
        symbol_for_function[site.function] = @intCast(symbol_names.items.len);
        try symbol_names.append(allocator, program.external_functions[site.function].source_name);
    }
    for (image.windows_import_sites) |site| {
        const index: usize = @intFromEnum(site.symbol);
        if (symbol_for_import[index] != std.math.maxInt(u32)) continue;
        symbol_for_import[index] = @intCast(symbol_names.items.len);
        try symbol_names.append(allocator, try std.fmt.allocPrint(allocator, "__imp_{s}", .{site.symbol.sourceName()}));
    }
    const relocation_count = image.external_call_sites.len + image.windows_import_sites.len;
    if (relocation_count > std.math.maxInt(u16)) return error.InvalidImage;
    const header_size: usize = 20 + 40;
    const text_offset = header_size;
    const relocation_offset = text_offset + image.code.len;
    const symbol_offset = relocation_offset + relocation_count * 10;
    const symbol_count: u32 = @intCast(symbol_names.items.len);

    var string_table: std.ArrayList(u8) = .empty;
    defer string_table.deinit(allocator);
    try string_table.appendNTimes(allocator, 0, 4);
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try appendInt(allocator, &bytes, u16, 0x8664);
    try appendInt(allocator, &bytes, u16, 1);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u32, symbol_offset);
    try appendInt(allocator, &bytes, u32, symbol_count);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u16, 0);
    try appendFixedName(allocator, &bytes, ".text");
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u32, image.code.len);
    try appendInt(allocator, &bytes, u32, text_offset);
    try appendInt(allocator, &bytes, u32, relocation_offset);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u16, relocation_count);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u32, 0xe0000060);
    try bytes.appendSlice(allocator, image.code);
    for (image.external_call_sites) |site| try appendCoffRelocation(allocator, &bytes, site.displacement_offset, symbol_for_function[site.function]);
    for (image.windows_import_sites) |site| try appendCoffRelocation(allocator, &bytes, site.displacement_offset, symbol_for_import[@intFromEnum(site.symbol)]);
    for (symbol_names.items, 0..) |name, index| {
        try appendCoffName(allocator, &bytes, &string_table, name);
        try appendInt(allocator, &bytes, u32, if (index == 0) image.entry_offset else 0);
        try appendInt(allocator, &bytes, i16, @as(i16, if (index == 0) 1 else 0));
        try appendInt(allocator, &bytes, u16, @as(u16, if (index == 0) 0x20 else 0));
        try bytes.appendSlice(allocator, &.{ 2, 0 });
    }
    std.mem.writeInt(u32, string_table.items[0..4], @intCast(string_table.items.len), .little);
    try bytes.appendSlice(allocator, string_table.items);
    return bytes.toOwnedSlice(allocator);
}

fn appendElfSymbol(allocator: Allocator, bytes: *std.ArrayList(u8), name: u32, info: u8, section: u16, value: usize, size: usize) !void {
    try appendInt(allocator, bytes, u32, name);
    try bytes.appendSlice(allocator, &.{ info, 0 });
    try appendInt(allocator, bytes, u16, section);
    try appendInt(allocator, bytes, u64, value);
    try appendInt(allocator, bytes, u64, size);
}

fn appendElfSection(allocator: Allocator, bytes: *std.ArrayList(u8), name: u32, kind: u32, flags: u64, offset: usize, size: usize, link: u32, info: u32, alignment: u64, entry_size: u64) !void {
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

fn appendCoffRelocation(allocator: Allocator, bytes: *std.ArrayList(u8), offset: u32, symbol: u32) !void {
    try appendInt(allocator, bytes, u32, offset);
    try appendInt(allocator, bytes, u32, symbol);
    try appendInt(allocator, bytes, u16, 4);
}

fn appendCoffName(allocator: Allocator, bytes: *std.ArrayList(u8), strings: *std.ArrayList(u8), name: []const u8) !void {
    if (name.len <= 8) return appendFixedName(allocator, bytes, name);
    try appendInt(allocator, bytes, u32, 0);
    try appendInt(allocator, bytes, u32, strings.items.len);
    try strings.appendSlice(allocator, name);
    try strings.append(allocator, 0);
}

fn appendFixedName(allocator: Allocator, bytes: *std.ArrayList(u8), name: []const u8) !void {
    try bytes.appendSlice(allocator, name);
    try bytes.appendNTimes(allocator, 0, 8 - name.len);
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

test "emit ELF and COFF x64 relocatable objects" {
    const Frontend = @import("../Frontend.zig");
    const Lower = @import("../Arm64/Lower.zig");

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile("func main() {}");
    const machine = try Lower.lower(allocator, compilation.ir);

    var linux = try Encoder.encodeLinuxObject(allocator, machine);
    defer linux.deinit(allocator);
    const elf = try emitElf(allocator, machine, linux);
    try std.testing.expectEqualStrings("\x7fELF", elf[0..4]);
    try std.testing.expectEqual(@as(u16, 62), std.mem.readInt(u16, elf[18..20], .little));

    var windows = try Encoder.encodeWindowsObject(allocator, machine);
    defer windows.deinit(allocator);
    const coff = try emitCoff(allocator, machine, windows);
    try std.testing.expectEqual(@as(u16, 0x8664), std.mem.readInt(u16, coff[0..2], .little));
    try std.testing.expectEqual(@as(u16, 1), std.mem.readInt(u16, coff[2..4], .little));
}
