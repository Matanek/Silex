const std = @import("std");
const Encoder = @import("Encoder.zig");
const LinuxObject = @import("../Linux/Object.zig");
const Machine = @import("../Arm64/Machine.zig");
const WindowsImports = @import("../Windows/Imports.zig");

const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || error{InvalidImage};

pub fn emitElf(
    allocator: Allocator,
    program: Machine.Program,
    image: Encoder.Image,
) Error![]u8 {
    var relocations: std.ArrayList(LinuxObject.Relocation) = .empty;
    defer relocations.deinit(allocator);
    for (image.external_call_sites) |site| {
        if (site.function >= program.external_functions.len or
            @as(usize, site.displacement_offset) + 4 > image.code.len) return error.InvalidImage;
        try relocations.append(allocator, .{
            .offset = site.displacement_offset,
            .kind = .x64_pc32,
            .target = .{ .external = program.external_functions[site.function].source_name },
            .addend = -4,
        });
    }
    return LinuxObject.emit(allocator, .x64, image.code, image.entry_offset, relocations.items);
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
