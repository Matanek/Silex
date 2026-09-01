const std = @import("std");
const macho = std.macho;

const CodeSignature = @import("CodeSignature.zig");
const Encoder = @import("../X64/Encoder.zig");

const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || error{InvalidImage};

const page_size: usize = 0x1000;
const image_base: u64 = 0x1_0000_0000;
const text_offset: usize = page_size;
const minimum_macos_version: u32 = 13 << 16;

pub fn emit(allocator: Allocator, image: Encoder.Image) Error![]u8 {
    if (image.entry_offset >= image.data_offset or image.data_offset > image.code.len or image.data_offset % page_size != 0) {
        return error.InvalidImage;
    }
    const has_data = image.data_offset < image.code.len;
    const dylinker_path = "/usr/lib/dyld\x00";
    const dylinker_size = std.mem.alignForward(
        usize,
        @sizeOf(macho.dylinker_command) + dylinker_path.len,
        @alignOf(u64),
    );
    const text_command_size = @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64);
    const data_command_size: usize = if (has_data) @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64) else 0;
    const load_commands_size = @sizeOf(macho.segment_command_64) + text_command_size + data_command_size +
        @sizeOf(macho.segment_command_64) + dylinker_size + @sizeOf(macho.build_version_command) +
        @sizeOf(macho.entry_point_command) + @sizeOf(macho.linkedit_data_command);
    const text_size = text_offset + image.data_offset;
    const data_content_size = image.code.len - image.data_offset;
    const data_size = if (has_data) std.mem.alignForward(usize, data_content_size, page_size) else 0;
    const data_file_offset = text_size;
    const linkedit_offset = data_file_offset + data_size;
    const signature_offset = linkedit_offset;
    const signature_size = CodeSignature.size(signature_offset);
    const file_size = signature_offset + signature_size;

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.ensureTotalCapacity(allocator, file_size);

    var header: macho.mach_header_64 = .{
        .magic = macho.MH_MAGIC_64,
        .cputype = macho.CPU_TYPE_X86_64,
        .cpusubtype = 3,
        .filetype = macho.MH_EXECUTE,
        .ncmds = @intCast(7 + @as(usize, @intFromBool(has_data))),
        .sizeofcmds = @intCast(load_commands_size),
        .flags = macho.MH_NOUNDEFS | macho.MH_DYLDLINK | macho.MH_TWOLEVEL | macho.MH_PIE,
        .reserved = 0,
    };
    try appendStruct(allocator, &bytes, &header);

    var pagezero: macho.segment_command_64 = .{
        .cmd = .SEGMENT_64,
        .cmdsize = @sizeOf(macho.segment_command_64),
        .segname = name("__PAGEZERO"),
        .vmaddr = 0,
        .vmsize = image_base,
        .fileoff = 0,
        .filesize = 0,
        .maxprot = .{},
        .initprot = .{},
        .nsects = 0,
        .flags = 0,
    };
    try appendStruct(allocator, &bytes, &pagezero);

    var text: macho.segment_command_64 = .{
        .cmd = .SEGMENT_64,
        .cmdsize = @intCast(text_command_size),
        .segname = name("__TEXT"),
        .vmaddr = image_base,
        .vmsize = text_size,
        .fileoff = 0,
        .filesize = text_size,
        .maxprot = .{ .READ = true, .EXEC = true },
        .initprot = .{ .READ = true, .EXEC = true },
        .nsects = 1,
        .flags = 0,
    };
    try appendStruct(allocator, &bytes, &text);
    var text_section: macho.section_64 = .{
        .sectname = name("__text"),
        .segname = name("__TEXT"),
        .addr = image_base + text_offset,
        .size = image.data_offset,
        .offset = text_offset,
        .@"align" = 4,
        .reloff = 0,
        .nreloc = 0,
        .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        .reserved1 = 0,
        .reserved2 = 0,
        .reserved3 = 0,
    };
    try appendStruct(allocator, &bytes, &text_section);

    if (has_data) {
        var data: macho.segment_command_64 = .{
            .cmd = .SEGMENT_64,
            .cmdsize = @intCast(data_command_size),
            .segname = name("__DATA"),
            .vmaddr = image_base + data_file_offset,
            .vmsize = data_size,
            .fileoff = data_file_offset,
            .filesize = data_size,
            .maxprot = .{ .READ = true, .WRITE = true },
            .initprot = .{ .READ = true, .WRITE = true },
            .nsects = 1,
            .flags = 0,
        };
        try appendStruct(allocator, &bytes, &data);
        var data_section: macho.section_64 = .{
            .sectname = name("__data"),
            .segname = name("__DATA"),
            .addr = image_base + data_file_offset,
            .size = data_content_size,
            .offset = @intCast(data_file_offset),
            .@"align" = 3,
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_REGULAR,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        };
        try appendStruct(allocator, &bytes, &data_section);
    }

    var linkedit: macho.segment_command_64 = .{
        .cmd = .SEGMENT_64,
        .cmdsize = @sizeOf(macho.segment_command_64),
        .segname = name("__LINKEDIT"),
        .vmaddr = image_base + linkedit_offset,
        .vmsize = std.mem.alignForward(usize, signature_size, page_size),
        .fileoff = linkedit_offset,
        .filesize = signature_size,
        .maxprot = .{ .READ = true },
        .initprot = .{ .READ = true },
        .nsects = 0,
        .flags = 0,
    };
    try appendStruct(allocator, &bytes, &linkedit);

    var dylinker: macho.dylinker_command = .{
        .cmd = .LOAD_DYLINKER,
        .cmdsize = @intCast(dylinker_size),
        .name = @sizeOf(macho.dylinker_command),
    };
    try appendStruct(allocator, &bytes, &dylinker);
    try bytes.appendSlice(allocator, dylinker_path);
    try appendZeroes(allocator, &bytes, dylinker_size - @sizeOf(macho.dylinker_command) - dylinker_path.len);

    var build_version: macho.build_version_command = .{
        .cmd = .BUILD_VERSION,
        .cmdsize = @sizeOf(macho.build_version_command),
        .platform = .MACOS,
        .minos = minimum_macos_version,
        .sdk = minimum_macos_version,
        .ntools = 0,
    };
    try appendStruct(allocator, &bytes, &build_version);
    var entry: macho.entry_point_command = .{
        .cmd = .MAIN,
        .cmdsize = @sizeOf(macho.entry_point_command),
        .entryoff = text_offset + image.entry_offset,
        .stacksize = 0,
    };
    try appendStruct(allocator, &bytes, &entry);
    var signature_command: macho.linkedit_data_command = .{
        .cmd = .CODE_SIGNATURE,
        .cmdsize = @sizeOf(macho.linkedit_data_command),
        .dataoff = @intCast(signature_offset),
        .datasize = @intCast(signature_size),
    };
    try appendStruct(allocator, &bytes, &signature_command);

    if (bytes.items.len > text_offset) return error.InvalidImage;
    try appendZeroes(allocator, &bytes, text_offset - bytes.items.len);
    try bytes.appendSlice(allocator, image.code[0..image.data_offset]);
    if (has_data) {
        try bytes.appendSlice(allocator, image.code[image.data_offset..]);
        try appendZeroes(allocator, &bytes, linkedit_offset - bytes.items.len);
    }
    const signature = try CodeSignature.emit(allocator, bytes.items, signature_offset);
    defer allocator.free(signature);
    try bytes.appendSlice(allocator, signature);
    return bytes.toOwnedSlice(allocator);
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

test "emit builds a signed X64 Mach-O executable" {
    var code = [_]u8{0xcc} ** 4096;
    const image: Encoder.Image = .{
        .code = &code,
        .entry_offset = 0,
        .data_offset = code.len,
    };
    const bytes = try emit(std.testing.allocator, image);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqual(@as(u32, macho.MH_MAGIC_64), std.mem.readInt(u32, bytes[0..4], .little));
    try std.testing.expectEqual(@as(u32, @bitCast(macho.CPU_TYPE_X86_64)), std.mem.readInt(u32, bytes[4..8], .little));
    try std.testing.expectEqual(@as(u32, macho.MH_EXECUTE), std.mem.readInt(u32, bytes[12..16], .little));
    try std.testing.expect(std.mem.indexOf(u8, bytes, "__LINKEDIT") != null);
}
