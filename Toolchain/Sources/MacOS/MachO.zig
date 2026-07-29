const std = @import("std");
const macho = std.macho;

const Encoder = @import("../Arm64/Encoder.zig");
const Machine = @import("../Arm64/Machine.zig");
const CodeSignature = @import("CodeSignature.zig");
const DynamicLink = @import("DynamicLink.zig");

pub const Error = Encoder.Error || DynamicLink.Error || std.mem.Allocator.Error || error{
    InvalidMain,
};

const page_size: usize = 0x4000;
const image_base: u64 = 0x1_0000_0000;
const text_offset: usize = page_size;
const minimum_macos_version: u32 = 13 << 16;

pub fn emit(allocator: std.mem.Allocator, program: Machine.Program) Error![]u8 {
    const main_id = try findMain(program);
    return emitFunction(allocator, program, main_id);
}

pub fn emitFunction(
    allocator: std.mem.Allocator,
    program: Machine.Program,
    function: Machine.FunctionId,
) Error![]u8 {
    var encoded = try Encoder.encode(allocator, program, .{ .executable_main = function });
    defer encoded.deinit(allocator);
    return emitEncoded(allocator, program, &encoded);
}

fn emitEncoded(
    allocator: std.mem.Allocator,
    program: Machine.Program,
    encoded: *Encoder.Image,
) Error![]u8 {
    const dynamic = program.external_functions.len != 0;

    const dylinker_path = "/usr/lib/dyld\x00";
    const dylinker_command_size = std.mem.alignForward(
        usize,
        @sizeOf(macho.dylinker_command) + dylinker_path.len,
        @alignOf(u64),
    );

    const pagezero_command_size = @sizeOf(macho.segment_command_64);
    const text_command_size = @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64);
    const data_command_size: usize = if (encoded.data_offset != null) @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64) else 0;
    const linkedit_command_size = @sizeOf(macho.segment_command_64);
    const build_version_command_size = @sizeOf(macho.build_version_command);
    const entry_command_size = @sizeOf(macho.entry_point_command);
    const signature_command_size = @sizeOf(macho.linkedit_data_command);
    const got_command_size: usize = if (dynamic) @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64) else 0;
    const dyld_info_command_size: usize = if (dynamic) @sizeOf(macho.dyld_info_command) else 0;
    const symtab_command_size: usize = if (dynamic) @sizeOf(macho.symtab_command) else 0;
    const dysymtab_command_size: usize = if (dynamic) @sizeOf(macho.dysymtab_command) else 0;
    const dylib_command_size = if (dynamic)
        std.mem.alignForward(usize, @sizeOf(macho.dylib_command) + DynamicLink.library_path.len, @alignOf(u64))
    else
        0;
    const load_commands_size = pagezero_command_size + text_command_size + data_command_size + linkedit_command_size +
        got_command_size + dylinker_command_size + build_version_command_size + entry_command_size +
        dyld_info_command_size + symtab_command_size + dysymtab_command_size + dylib_command_size + signature_command_size;

    const encoded_text_size = if (encoded.data_offset) |offset| offset else encoded.code.len;
    const unaligned_text_size = text_offset + encoded_text_size;
    const text_size = std.mem.alignForward(usize, unaligned_text_size, page_size);
    const data_content_size = if (encoded.data_offset) |offset| encoded.code.len - offset else 0;
    const data_size = if (encoded.data_offset != null) std.mem.alignForward(usize, data_content_size, page_size) else 0;
    const got_offset = text_size + data_size;
    const got_size: usize = if (dynamic) page_size else 0;
    const linkedit_offset = got_offset + got_size;
    const got_segment_index: u4 = 2 + @as(u4, @intFromBool(encoded.data_offset != null));
    const bind_info = if (dynamic) try DynamicLink.bindInfo(allocator, program.external_functions, got_segment_index) else &.{};
    const string_table = if (dynamic) try DynamicLink.stringTable(allocator, program.external_functions) else &.{};
    const bind_offset = linkedit_offset;
    const symbol_offset = std.mem.alignForward(usize, bind_offset + bind_info.len, @alignOf(macho.nlist_64));
    const string_offset = symbol_offset + program.external_functions.len * @sizeOf(macho.nlist_64);
    const signature_offset = if (dynamic)
        std.mem.alignForward(usize, string_offset + string_table.len, 16)
    else
        linkedit_offset;
    const signature_size = CodeSignature.size(signature_offset);
    const file_size = signature_offset + signature_size;

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.ensureTotalCapacity(allocator, file_size);

    var header: macho.mach_header_64 = .{
        .magic = macho.MH_MAGIC_64,
        .cputype = macho.CPU_TYPE_ARM64,
        .cpusubtype = 0,
        .filetype = macho.MH_EXECUTE,
        .ncmds = @intCast((if (encoded.data_offset != null) @as(usize, 8) else 7) + (if (dynamic) @as(usize, 5) else 0)),
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
        .vmsize = @intCast(text_size),
        .fileoff = 0,
        .filesize = @intCast(text_size),
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
        .size = encoded_text_size,
        .offset = text_offset,
        .@"align" = 2,
        .reloff = 0,
        .nreloc = 0,
        .flags = macho.S_REGULAR | macho.S_ATTR_PURE_INSTRUCTIONS | macho.S_ATTR_SOME_INSTRUCTIONS,
        .reserved1 = 0,
        .reserved2 = 0,
        .reserved3 = 0,
    };
    try appendStruct(allocator, &bytes, &text_section);

    if (encoded.data_offset != null) {
        var data: macho.segment_command_64 = .{
            .cmd = .SEGMENT_64,
            .cmdsize = @intCast(data_command_size),
            .segname = name("__DATA"),
            .vmaddr = image_base + text_size,
            .vmsize = @intCast(data_size),
            .fileoff = text_size,
            .filesize = @intCast(data_size),
            .maxprot = .{ .READ = true, .WRITE = true },
            .initprot = .{ .READ = true, .WRITE = true },
            .nsects = 1,
            .flags = 0,
        };
        try appendStruct(allocator, &bytes, &data);
        var data_section: macho.section_64 = .{
            .sectname = name("__data"),
            .segname = name("__DATA"),
            .addr = image_base + text_size,
            .size = data_content_size,
            .offset = @intCast(text_size),
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

    if (dynamic) {
        var got: macho.segment_command_64 = .{
            .cmd = .SEGMENT_64,
            .cmdsize = @intCast(got_command_size),
            .segname = name("__DATA_CONST"),
            .vmaddr = image_base + got_offset,
            .vmsize = got_size,
            .fileoff = got_offset,
            .filesize = got_size,
            .maxprot = .{ .READ = true, .WRITE = true },
            .initprot = .{ .READ = true, .WRITE = true },
            .nsects = 1,
            .flags = 0,
        };
        try appendStruct(allocator, &bytes, &got);
        var got_section: macho.section_64 = .{
            .sectname = name("__got"),
            .segname = name("__DATA_CONST"),
            .addr = image_base + got_offset,
            .size = program.external_functions.len * @sizeOf(u64),
            .offset = @intCast(got_offset),
            .@"align" = 3,
            .reloff = 0,
            .nreloc = 0,
            .flags = macho.S_REGULAR,
            .reserved1 = 0,
            .reserved2 = 0,
            .reserved3 = 0,
        };
        try appendStruct(allocator, &bytes, &got_section);
    }

    var linkedit: macho.segment_command_64 = .{
        .cmd = .SEGMENT_64,
        .cmdsize = @sizeOf(macho.segment_command_64),
        .segname = name("__LINKEDIT"),
        .vmaddr = image_base + linkedit_offset,
        .vmsize = @intCast(std.mem.alignForward(usize, file_size - linkedit_offset, page_size)),
        .fileoff = linkedit_offset,
        .filesize = file_size - linkedit_offset,
        .maxprot = .{ .READ = true },
        .initprot = .{ .READ = true },
        .nsects = 0,
        .flags = 0,
    };
    try appendStruct(allocator, &bytes, &linkedit);

    var dylinker: macho.dylinker_command = .{
        .cmd = .LOAD_DYLINKER,
        .cmdsize = @intCast(dylinker_command_size),
        .name = @sizeOf(macho.dylinker_command),
    };
    try appendStruct(allocator, &bytes, &dylinker);
    try bytes.appendSlice(allocator, dylinker_path);
    try appendZeroes(allocator, &bytes, dylinker_command_size - @sizeOf(macho.dylinker_command) - dylinker_path.len);

    var build_version: macho.build_version_command = .{
        .cmd = .BUILD_VERSION,
        .cmdsize = @sizeOf(macho.build_version_command),
        .platform = .MACOS,
        .minos = minimum_macos_version,
        .sdk = minimum_macos_version,
        .ntools = 0,
    };
    try appendStruct(allocator, &bytes, &build_version);

    if (dynamic) {
        var dyld_info: macho.dyld_info_command = .{
            .bind_off = @intCast(bind_offset),
            .bind_size = @intCast(bind_info.len),
        };
        try appendStruct(allocator, &bytes, &dyld_info);
        var symtab: macho.symtab_command = .{
            .symoff = @intCast(symbol_offset),
            .nsyms = @intCast(program.external_functions.len),
            .stroff = @intCast(string_offset),
            .strsize = @intCast(string_table.len),
        };
        try appendStruct(allocator, &bytes, &symtab);
        var dysymtab: macho.dysymtab_command = .{
            .iundefsym = 0,
            .nundefsym = @intCast(program.external_functions.len),
        };
        try appendStruct(allocator, &bytes, &dysymtab);
        var dylib: macho.dylib_command = .{
            .cmd = .LOAD_DYLIB,
            .cmdsize = @intCast(dylib_command_size),
            .dylib = .{
                .name = @sizeOf(macho.dylib_command),
                .timestamp = 2,
                .current_version = 0,
                .compatibility_version = 0x10000,
            },
        };
        try appendStruct(allocator, &bytes, &dylib);
        try bytes.appendSlice(allocator, DynamicLink.library_path);
        try appendZeroes(allocator, &bytes, dylib_command_size - @sizeOf(macho.dylib_command) - DynamicLink.library_path.len);
    }

    var entry: macho.entry_point_command = .{
        .cmd = .MAIN,
        .cmdsize = @sizeOf(macho.entry_point_command),
        .entryoff = text_offset + encoded.entry_offset.?,
        .stacksize = 0,
    };
    try appendStruct(allocator, &bytes, &entry);

    var code_signature: macho.linkedit_data_command = .{
        .cmd = .CODE_SIGNATURE,
        .cmdsize = @sizeOf(macho.linkedit_data_command),
        .dataoff = @intCast(signature_offset),
        .datasize = @intCast(signature_size),
    };
    try appendStruct(allocator, &bytes, &code_signature);

    if (bytes.items.len > text_offset) return error.InvalidMain;
    try appendZeroes(allocator, &bytes, text_offset - bytes.items.len);
    if (dynamic) try DynamicLink.patchCalls(
        encoded.code,
        encoded.external_call_sites,
        program.external_functions.len,
        image_base + text_offset,
        image_base + got_offset,
    );
    try bytes.appendSlice(allocator, encoded.code);
    try appendZeroes(allocator, &bytes, linkedit_offset - bytes.items.len);
    if (dynamic) {
        try bytes.appendSlice(allocator, bind_info);
        try appendZeroes(allocator, &bytes, symbol_offset - bytes.items.len);
        try DynamicLink.appendSymbols(allocator, &bytes, program.external_functions);
        try bytes.appendSlice(allocator, string_table);
        try appendZeroes(allocator, &bytes, signature_offset - bytes.items.len);
    }

    const signature = try CodeSignature.emit(allocator, bytes.items, signature_offset);
    defer allocator.free(signature);
    try bytes.appendSlice(allocator, signature);

    return bytes.toOwnedSlice(allocator);
}

fn findMain(program: Machine.Program) Error!Machine.FunctionId {
    var found: ?Machine.FunctionId = null;
    for (program.functions, 0..) |function, id| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        if (found != null or function.parameter_count != 0 or
            (function.return_type != .void and !function.recoverable_entry_result))
        {
            return error.InvalidMain;
        }
        found = id;
    }
    return found orelse error.InvalidMain;
}

fn appendStruct(
    allocator: std.mem.Allocator,
    bytes: *std.ArrayList(u8),
    value: anytype,
) std.mem.Allocator.Error!void {
    try bytes.appendSlice(allocator, std.mem.asBytes(value));
}

fn appendZeroes(
    allocator: std.mem.Allocator,
    bytes: *std.ArrayList(u8),
    count: usize,
) std.mem.Allocator.Error!void {
    try bytes.appendNTimes(allocator, 0, count);
}

fn name(comptime value: []const u8) [16]u8 {
    if (value.len > 16) @compileError("Mach-O names are limited to 16 bytes");
    var result = [_]u8{0} ** 16;
    @memcpy(result[0..value.len], value);
    return result;
}

test "emit builds an arm64 Mach-O executable with an LC_MAIN entry" {
    const Frontend = @import("../Frontend.zig");
    const Lower = @import("../Arm64/Lower.zig");

    const source =
        \\func answer() int { return 40 + 2 }
        \\func main() { answer() }
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(source);
    const machine = try Lower.lower(allocator, compilation.ir);
    const bytes = try emit(allocator, machine);

    try std.testing.expectEqual(@as(u32, macho.MH_MAGIC_64), std.mem.readInt(u32, bytes[0..4], .little));
    try std.testing.expectEqual(@as(u32, @bitCast(macho.CPU_TYPE_ARM64)), std.mem.readInt(u32, bytes[4..8], .little));
    try std.testing.expectEqual(@as(u32, 8), std.mem.readInt(u32, bytes[16..20], .little));

    const main_command_offset = @sizeOf(macho.mach_header_64) +
        @sizeOf(macho.segment_command_64) +
        @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64) +
        @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64) +
        @sizeOf(macho.segment_command_64) +
        std.mem.alignForward(usize, @sizeOf(macho.dylinker_command) + "/usr/lib/dyld\x00".len, @alignOf(u64)) +
        @sizeOf(macho.build_version_command);
    try std.testing.expectEqual(
        @as(u32, @intFromEnum(macho.LC.MAIN)),
        std.mem.readInt(u32, bytes[main_command_offset..][0..4], .little),
    );
    try std.testing.expect(std.mem.readInt(u64, bytes[main_command_offset + 8 ..][0..8], .little) >= text_offset);

    const signature_command_offset = main_command_offset + @sizeOf(macho.entry_point_command);
    try std.testing.expectEqual(
        @as(u32, @intFromEnum(macho.LC.CODE_SIGNATURE)),
        std.mem.readInt(u32, bytes[signature_command_offset..][0..4], .little),
    );
    const signature_offset = std.mem.readInt(u32, bytes[signature_command_offset + 8 ..][0..4], .little);
    try std.testing.expectEqual(
        macho.CSMAGIC_EMBEDDED_SIGNATURE,
        std.mem.readInt(u32, bytes[signature_offset..][0..4], .big),
    );
}
