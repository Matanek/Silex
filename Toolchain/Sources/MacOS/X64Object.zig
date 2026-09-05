const std = @import("std");
const macho = std.macho;

const Encoder = @import("../X64/Encoder.zig");
const Machine = @import("../Arm64/Machine.zig");

const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || error{InvalidImage};

const minimum_macos_version: u32 = 13 << 16;

pub fn emit(allocator: Allocator, program: Machine.Program, image: *Encoder.Image) Error![]u8 {
    if (image.entry_offset >= image.data_offset or image.data_offset > image.code.len) return error.InvalidImage;
    const text_size: usize = image.data_offset;
    const data_size = image.code.len - text_size;
    const section_count: usize = 1 + @as(usize, @intFromBool(data_size != 0));
    const segment_size = @sizeOf(macho.segment_command_64) + section_count * @sizeOf(macho.section_64);
    const load_commands_size = segment_size + @sizeOf(macho.build_version_command) +
        @sizeOf(macho.symtab_command) + @sizeOf(macho.dysymtab_command);
    const content_offset = std.mem.alignForward(usize, @sizeOf(macho.mach_header_64) + load_commands_size, 16);

    const used_external = try allocator.alloc(bool, program.external_functions.len);
    defer allocator.free(used_external);
    @memset(used_external, false);
    for (image.external_call_sites) |site| {
        if (site.function >= program.external_functions.len or @as(usize, site.displacement_offset) + 4 > text_size) {
            return error.InvalidImage;
        }
        used_external[site.function] = true;
    }
    const external_symbol = try allocator.alloc(u32, program.external_functions.len);
    defer allocator.free(external_symbol);
    @memset(external_symbol, 0);

    const first_defined = image.address_sites.len;
    const first_undefined = first_defined + 1;
    var symbol_count: usize = first_undefined;
    for (used_external, 0..) |used, index| if (used) {
        external_symbol[index] = @intCast(symbol_count);
        symbol_count += 1;
    };

    var strings: std.ArrayList(u8) = .empty;
    defer strings.deinit(allocator);
    try strings.append(allocator, 0);
    const address_names = try allocator.alloc(u32, image.address_sites.len);
    defer allocator.free(address_names);
    for (address_names, 0..) |*offset, index| {
        offset.* = @intCast(strings.items.len);
        try strings.print(allocator, "l_silex_address_{d}\x00", .{index});
    }
    const main_name: u32 = @intCast(strings.items.len);
    try strings.appendSlice(allocator, "_main\x00");
    const external_names = try allocator.alloc(u32, program.external_functions.len);
    defer allocator.free(external_names);
    @memset(external_names, 0);
    for (program.external_functions, 0..) |function, index| if (used_external[index]) {
        external_names[index] = @intCast(strings.items.len);
        try strings.append(allocator, '_');
        try strings.appendSlice(allocator, function.source_name);
        try strings.append(allocator, 0);
    };

    var relocations: std.ArrayList(macho.relocation_info) = .empty;
    defer relocations.deinit(allocator);
    for (image.address_sites, 0..) |site, symbol| {
        if (@as(usize, site.displacement_offset) + 4 > text_size or site.target_offset >= image.code.len) {
            return error.InvalidImage;
        }
        std.mem.writeInt(i32, image.code[site.displacement_offset..][0..4], 0, .little);
        try relocations.append(allocator, relocation(site.displacement_offset, @intCast(symbol), .X86_64_RELOC_SIGNED));
    }
    for (image.external_call_sites) |site| {
        std.mem.writeInt(i32, image.code[site.displacement_offset..][0..4], 0, .little);
        try relocations.append(allocator, relocation(
            site.displacement_offset,
            @intCast(external_symbol[site.function]),
            .X86_64_RELOC_BRANCH,
        ));
    }
    std.mem.sort(macho.relocation_info, relocations.items, {}, relocationBefore);

    const relocation_offset = std.mem.alignForward(usize, content_offset + image.code.len, 8);
    const symbol_offset = relocation_offset + relocations.items.len * @sizeOf(macho.relocation_info);
    const string_offset = symbol_offset + symbol_count * @sizeOf(macho.nlist_64);

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.ensureTotalCapacity(allocator, string_offset + strings.items.len);
    var header: macho.mach_header_64 = .{
        .magic = macho.MH_MAGIC_64,
        .cputype = macho.CPU_TYPE_X86_64,
        .cpusubtype = 3,
        .filetype = macho.MH_OBJECT,
        .ncmds = 4,
        .sizeofcmds = @intCast(load_commands_size),
        .flags = 0,
        .reserved = 0,
    };
    try appendStruct(allocator, &bytes, &header);
    var segment: macho.segment_command_64 = .{
        .cmd = .SEGMENT_64,
        .cmdsize = @intCast(segment_size),
        .segname = [_]u8{0} ** 16,
        .vmaddr = 0,
        .vmsize = image.code.len,
        .fileoff = content_offset,
        .filesize = image.code.len,
        .maxprot = .{ .READ = true, .WRITE = true, .EXEC = true },
        .initprot = .{ .READ = true, .WRITE = true, .EXEC = true },
        .nsects = @intCast(section_count),
        .flags = 0,
    };
    try appendStruct(allocator, &bytes, &segment);
    var text: macho.section_64 = .{
        .sectname = name("__text"),
        .segname = name("__TEXT"),
        .addr = 0,
        .size = text_size,
        .offset = @intCast(content_offset),
        .@"align" = 4,
        .reloff = @intCast(relocation_offset),
        .nreloc = @intCast(relocations.items.len),
        .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        .reserved1 = 0,
        .reserved2 = 0,
        .reserved3 = 0,
    };
    try appendStruct(allocator, &bytes, &text);
    if (data_size != 0) {
        var data: macho.section_64 = .{
            .sectname = name("__data"),
            .segname = name("__DATA"),
            .addr = text_size,
            .size = data_size,
            .offset = @intCast(content_offset + text_size),
            .@"align" = 3,
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_REGULAR,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        };
        try appendStruct(allocator, &bytes, &data);
    }
    var build_version: macho.build_version_command = .{
        .cmd = .BUILD_VERSION,
        .cmdsize = @sizeOf(macho.build_version_command),
        .platform = .MACOS,
        .minos = minimum_macos_version,
        .sdk = minimum_macos_version,
        .ntools = 0,
    };
    try appendStruct(allocator, &bytes, &build_version);
    var symtab: macho.symtab_command = .{
        .symoff = @intCast(symbol_offset),
        .nsyms = @intCast(symbol_count),
        .stroff = @intCast(string_offset),
        .strsize = @intCast(strings.items.len),
    };
    try appendStruct(allocator, &bytes, &symtab);
    var dysymtab: macho.dysymtab_command = .{
        .ilocalsym = 0,
        .nlocalsym = @intCast(image.address_sites.len),
        .iextdefsym = @intCast(first_defined),
        .nextdefsym = 1,
        .iundefsym = @intCast(first_undefined),
        .nundefsym = @intCast(symbol_count - first_undefined),
    };
    try appendStruct(allocator, &bytes, &dysymtab);

    try appendZeroes(allocator, &bytes, content_offset - bytes.items.len);
    try bytes.appendSlice(allocator, image.code);
    try appendZeroes(allocator, &bytes, relocation_offset - bytes.items.len);
    for (relocations.items) |entry| try appendStruct(allocator, &bytes, &entry);
    for (image.address_sites, 0..) |site, index| {
        var symbol: macho.nlist_64 = .{
            .n_strx = address_names[index],
            .n_type = .{ .bits = .{ .ext = false, .type = .sect, .pext = false, .is_stab = 0 } },
            .n_sect = if (site.target_offset >= text_size) 2 else 1,
            .n_desc = @bitCast(@as(u16, 0)),
            .n_value = site.target_offset,
        };
        try appendStruct(allocator, &bytes, &symbol);
    }
    var main_symbol: macho.nlist_64 = .{
        .n_strx = main_name,
        .n_type = .{ .bits = .{ .ext = true, .type = .sect, .pext = false, .is_stab = 0 } },
        .n_sect = 1,
        .n_desc = @bitCast(@as(u16, 0)),
        .n_value = image.entry_offset,
    };
    try appendStruct(allocator, &bytes, &main_symbol);
    for (program.external_functions, 0..) |_, index| if (used_external[index]) {
        var symbol: macho.nlist_64 = .{
            .n_strx = external_names[index],
            .n_type = .{ .bits = .{ .ext = true, .type = .undf, .pext = false, .is_stab = 0 } },
            .n_sect = 0,
            .n_desc = @bitCast(@as(u16, 0)),
            .n_value = 0,
        };
        try appendStruct(allocator, &bytes, &symbol);
    };
    try bytes.appendSlice(allocator, strings.items);
    return bytes.toOwnedSlice(allocator);
}

fn relocation(address: u32, symbol: u24, kind: macho.reloc_type_x86_64) macho.relocation_info {
    return .{
        .r_address = @intCast(address),
        .r_symbolnum = symbol,
        .r_pcrel = 1,
        .r_length = 2,
        .r_extern = 1,
        .r_type = @intFromEnum(kind),
    };
}

fn relocationBefore(_: void, left: macho.relocation_info, right: macho.relocation_info) bool {
    return left.r_address > right.r_address;
}

fn appendStruct(allocator: Allocator, bytes: *std.ArrayList(u8), value: anytype) Allocator.Error!void {
    try bytes.appendSlice(allocator, std.mem.asBytes(value));
}

fn appendZeroes(allocator: Allocator, bytes: *std.ArrayList(u8), count: usize) Allocator.Error!void {
    try bytes.appendNTimes(allocator, 0, count);
}

fn name(comptime value: []const u8) [16]u8 {
    if (value.len > 16) @compileError("Mach-O names are limited to 16 bytes");
    var result = [_]u8{0} ** 16;
    @memcpy(result[0..value.len], value);
    return result;
}

test "emit builds an X64 relocatable Mach-O object" {
    var code = [_]u8{0xcc} ** 4096;
    var image: Encoder.Image = .{
        .code = &code,
        .entry_offset = 0,
        .data_offset = code.len,
    };
    const bytes = try emit(std.testing.allocator, .{ .functions = &.{} }, &image);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqual(@as(u32, macho.MH_MAGIC_64), std.mem.readInt(u32, bytes[0..4], .little));
    try std.testing.expectEqual(@as(u32, @bitCast(macho.CPU_TYPE_X86_64)), std.mem.readInt(u32, bytes[4..8], .little));
    try std.testing.expectEqual(@as(u32, macho.MH_OBJECT), std.mem.readInt(u32, bytes[12..16], .little));
}

test "external branch relocations keep a zero addend" {
    var code = [_]u8{0} ** 4096;
    code[0] = 0xe8;
    var image: Encoder.Image = .{
        .code = &code,
        .entry_offset = 0,
        .data_offset = code.len,
        .external_call_sites = &.{.{ .displacement_offset = 1, .function = 0 }},
    };
    const program: Machine.Program = .{
        .functions = &.{},
        .external_functions = &.{.{
            .provider = "Boundary.Native",
            .source_name = "answer",
            .signature = .{ .arguments = &.{}, .result = .int32 },
            .package_private = true,
        }},
    };
    const bytes = try emit(std.testing.allocator, program, &image);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqual(@as(i32, 0), std.mem.readInt(i32, code[1..5], .little));
}

test "RIP-relative address relocations keep a zero addend" {
    var code = [_]u8{0} ** 4096;
    var image: Encoder.Image = .{
        .code = &code,
        .entry_offset = 0,
        .data_offset = code.len,
        .address_sites = &.{.{ .displacement_offset = 3, .target_offset = 2048 }},
    };
    const bytes = try emit(std.testing.allocator, .{ .functions = &.{} }, &image);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqual(@as(i32, 0), std.mem.readInt(i32, code[3..7], .little));
}
