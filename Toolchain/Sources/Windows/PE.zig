const std = @import("std");
const Architecture = @import("../Target.zig").Architecture;
const Imports = @import("Imports.zig");

const Allocator = std.mem.Allocator;
const dos_header_size: usize = 0x80;
const file_alignment: usize = 0x200;
const section_alignment: usize = 0x1000;
const text_rva: u32 = 0x1000;
const image_base: u64 = 0x1_4000_0000;
const optional_header_size: u16 = 0xf0;
const import_directory_size: u32 = 100;

pub const Error = Allocator.Error || error{ InvalidEntry, InvalidImportSite };

pub fn emit(allocator: Allocator, architecture: Architecture, code: []const u8, entry_offset: u32) Error![]u8 {
    return emitX64(allocator, architecture, code, entry_offset, &.{});
}

/// Builds PE32+ and its import directory directly. X64 call sites are RIP
/// relative references to IAT cells and are patched only after section RVAs
/// have been fixed.
pub fn emitX64(
    allocator: Allocator,
    architecture: Architecture,
    code: []const u8,
    entry_offset: u32,
    sites: []const Imports.X64Site,
) Error![]u8 {
    return emitWithSites(allocator, architecture, code, entry_offset, sites, &.{});
}

pub fn emitArm64(
    allocator: Allocator,
    code: []const u8,
    entry_offset: u32,
    sites: []const Imports.Arm64Site,
) Error![]u8 {
    return emitWithSites(allocator, .arm64, code, entry_offset, &.{}, sites);
}

fn emitWithSites(
    allocator: Allocator,
    architecture: Architecture,
    code: []const u8,
    entry_offset: u32,
    x64_sites: []const Imports.X64Site,
    arm64_sites: []const Imports.Arm64Site,
) Error![]u8 {
    if (entry_offset >= code.len) return error.InvalidEntry;
    const has_imports = x64_sites.len != 0 or arm64_sites.len != 0;
    const section_count: u16 = if (has_imports) 2 else 1;
    const headers_unaligned = dos_header_size + 4 + 20 + optional_header_size + @as(usize, section_count) * 40;
    const headers_size = std.mem.alignForward(usize, headers_unaligned, file_alignment);
    const raw_code_size = std.mem.alignForward(usize, code.len, file_alignment);
    const idata_rva: u32 = @intCast(std.mem.alignForward(usize, text_rva + code.len, section_alignment));
    const import_image = if (has_imports) try buildImportsGeneric(allocator, idata_rva) else ImportImage{};
    defer import_image.deinit(allocator);
    const raw_import_size = if (has_imports) std.mem.alignForward(usize, import_image.bytes.len, file_alignment) else 0;
    const image_size = if (has_imports)
        std.mem.alignForward(usize, idata_rva + import_image.bytes.len, section_alignment)
    else
        std.mem.alignForward(usize, text_rva + code.len, section_alignment);

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.ensureTotalCapacity(allocator, headers_size + raw_code_size + raw_import_size);
    try bytes.appendSlice(allocator, "MZ");
    try bytes.appendNTimes(allocator, 0, 0x3a);
    try appendInt(allocator, &bytes, u32, dos_header_size);
    try bytes.appendNTimes(allocator, 0, dos_header_size - bytes.items.len);
    try bytes.appendSlice(allocator, "PE\x00\x00");

    const machine: u16 = switch (architecture) {
        .x64 => 0x8664,
        .arm64 => 0xaa64,
    };
    try appendInt(allocator, &bytes, u16, machine);
    try appendInt(allocator, &bytes, u16, section_count);
    try bytes.appendNTimes(allocator, 0, 12);
    try appendInt(allocator, &bytes, u16, optional_header_size);
    try appendInt(allocator, &bytes, u16, 0x23);

    try appendInt(allocator, &bytes, u16, 0x20b);
    try bytes.appendSlice(allocator, &.{ 0, 1 });
    try appendInt(allocator, &bytes, u32, raw_code_size);
    try appendInt(allocator, &bytes, u32, raw_import_size);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u32, text_rva + entry_offset);
    try appendInt(allocator, &bytes, u32, text_rva);
    try appendInt(allocator, &bytes, u64, image_base);
    try appendInt(allocator, &bytes, u32, section_alignment);
    try appendInt(allocator, &bytes, u32, file_alignment);
    try appendInt(allocator, &bytes, u16, 6);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u16, 6);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u32, image_size);
    try appendInt(allocator, &bytes, u32, headers_size);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u16, 3);
    try appendInt(allocator, &bytes, u16, 0x100);
    try appendInt(allocator, &bytes, u64, 0x10_0000);
    try appendInt(allocator, &bytes, u64, 0x1000);
    try appendInt(allocator, &bytes, u64, 0x10_0000);
    try appendInt(allocator, &bytes, u64, 0x1000);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u32, 16);
    for (0..16) |directory| {
        if (has_imports and directory == 1) {
            try appendInt(allocator, &bytes, u32, idata_rva);
            try appendInt(allocator, &bytes, u32, import_directory_size);
        } else if (has_imports and directory == 12) {
            try appendInt(allocator, &bytes, u32, idata_rva + import_image.iat_offset);
            try appendInt(allocator, &bytes, u32, import_image.iat_size);
        } else try bytes.appendNTimes(allocator, 0, 8);
    }

    // The bootstrap X64 image currently appends mutable globals after code.
    // Split them into a dedicated writable section before restoring RX-only
    // characteristics here.
    const text_flags: u32 = if (architecture == .x64) 0xE000_0020 else 0x6000_0020;
    try appendSection(allocator, &bytes, ".text", code.len, text_rva, raw_code_size, headers_size, text_flags);
    if (has_imports) try appendSection(
        allocator,
        &bytes,
        ".idata",
        import_image.bytes.len,
        idata_rva,
        raw_import_size,
        headers_size + raw_code_size,
        0xc000_0040,
    );

    try bytes.appendNTimes(allocator, 0, headers_size - bytes.items.len);
    const code_file_offset = bytes.items.len;
    try bytes.appendSlice(allocator, code);
    try bytes.appendNTimes(allocator, 0, raw_code_size - code.len);
    if (has_imports) {
        try bytes.appendSlice(allocator, import_image.bytes);
        try bytes.appendNTimes(allocator, 0, raw_import_size - import_image.bytes.len);
        for (x64_sites) |site| {
            if (@as(usize, site.displacement_offset) + 4 > code.len) return error.InvalidImportSite;
            const iat_rva = idata_rva + import_image.iat[@intFromEnum(site.symbol)];
            const next_rva: i64 = text_rva + @as(i64, site.displacement_offset) + 4;
            const displacement = std.math.cast(i32, @as(i64, iat_rva) - next_rva) orelse return error.InvalidImportSite;
            std.mem.writeInt(i32, bytes.items[code_file_offset + site.displacement_offset ..][0..4], displacement, .little);
        }
        for (arm64_sites) |site| try patchArm64Import(
            bytes.items[code_file_offset .. code_file_offset + code.len],
            site,
            idata_rva + import_image.iat[@intFromEnum(site.symbol)],
        );
    }
    return bytes.toOwnedSlice(allocator);
}

fn patchArm64Import(code: []u8, site: Imports.Arm64Site, target_rva: u32) error{InvalidImportSite}!void {
    if (@as(usize, site.instruction_offset) + 8 > code.len) return error.InvalidImportSite;
    const instruction_address = image_base + text_rva + site.instruction_offset;
    const target_address = image_base + target_rva;
    const page_delta = @as(i64, @intCast(target_address >> 12)) - @as(i64, @intCast(instruction_address >> 12));
    if (page_delta < -0x10_0000 or page_delta >= 0x10_0000) return error.InvalidImportSite;
    const immediate: u21 = @bitCast(@as(i21, @intCast(page_delta)));
    var address = std.mem.readInt(u32, code[site.instruction_offset..][0..4], .little);
    if ((address & 0x9f000000) != 0x90000000) return error.InvalidImportSite;
    address |= (@as(u32, immediate & 0x3) << 29) | (@as(u32, immediate >> 2) << 5);
    std.mem.writeInt(u32, code[site.instruction_offset..][0..4], address, .little);
    const page_offset = target_address & 0xfff;
    var load = std.mem.readInt(u32, code[site.instruction_offset + 4 ..][0..4], .little);
    if ((load & 0xffc003ff) != 0xf9400210 or page_offset % 8 != 0) return error.InvalidImportSite;
    load |= @as(u32, @intCast(page_offset / 8)) << 10;
    std.mem.writeInt(u32, code[site.instruction_offset + 4 ..][0..4], load, .little);
}

const ImportImage = struct {
    const symbol_count = @typeInfo(Imports.Symbol).@"enum".fields.len;
    bytes: []const u8 = &.{},
    iat_offset: u32 = 0,
    iat_size: u32 = 0,
    iat: [symbol_count]u32 = @splat(0),
    virtual_alloc_iat: u32 = 0,
    process_prng_iat: u32 = 0,
    query_performance_counter_iat: u32 = 0,
    query_performance_frequency_iat: u32 = 0,
    crt_write_iat: u32 = 0,
    crt_read_iat: u32 = 0,
    crt_isatty_iat: u32 = 0,
    crt_wopen_iat: u32 = 0,
    crt_close_iat: u32 = 0,
    crt_commit_iat: u32 = 0,
    crt_lseeki64_iat: u32 = 0,
    crt_chsize_s_iat: u32 = 0,
    crt_p_argc_iat: u32 = 0,
    crt_p_wargv_iat: u32 = 0,
    get_std_handle_iat: u32 = 0,
    get_console_screen_buffer_info_iat: u32 = 0,
    get_console_mode_iat: u32 = 0,
    set_console_mode_iat: u32 = 0,
    get_console_cp_iat: u32 = 0,
    set_console_cp_iat: u32 = 0,
    wait_for_single_object_iat: u32 = 0,
    get_current_directory_w_iat: u32 = 0,
    set_current_directory_w_iat: u32 = 0,
    get_module_file_name_w_iat: u32 = 0,
    get_current_process_id_iat: u32 = 0,
    get_environment_variable_w_iat: u32 = 0,
    set_environment_variable_w_iat: u32 = 0,
    get_environment_strings_w_iat: u32 = 0,
    free_environment_strings_w_iat: u32 = 0,

    fn deinit(self: ImportImage, allocator: Allocator) void {
        allocator.free(self.bytes);
    }
};

fn buildImports(allocator: Allocator, rva: u32) Allocator.Error!ImportImage {
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.appendNTimes(allocator, 0, 80);
    while (bytes.items.len % 8 != 0) try bytes.append(allocator, 0);
    const ilt_virtual = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 152);
    const ilt_prng = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 16);
    const ilt_crt = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 88);
    const iat_virtual = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 152);
    const iat_prng = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 16);
    const iat_crt = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 88);
    const hint_virtual = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "VirtualAlloc\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_prng = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "ProcessPrng\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_counter = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "QueryPerformanceCounter\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_frequency = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "QueryPerformanceFrequency\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_get_std_handle = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetStdHandle\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_console_info = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetConsoleScreenBufferInfo\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_get_console_mode = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetConsoleMode\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_set_console_mode = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "SetConsoleMode\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_get_console_cp = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetConsoleCP\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_set_console_cp = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "SetConsoleCP\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_wait = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "WaitForSingleObject\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_get_current_directory = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetCurrentDirectoryW\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_set_current_directory = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "SetCurrentDirectoryW\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_get_module_file_name = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetModuleFileNameW\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_get_current_process_id = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetCurrentProcessId\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_get_environment_variable = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetEnvironmentVariableW\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_set_environment_variable = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "SetEnvironmentVariableW\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_get_environment_strings = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "GetEnvironmentStringsW\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_free_environment_strings = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "FreeEnvironmentStringsW\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_write = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "_write\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_read = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "_read\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_isatty = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "_isatty\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_wopen = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "_wopen\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_close = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "_close\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_commit = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "_commit\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_lseeki64 = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "_lseeki64\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_chsize_s = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "_chsize_s\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_p_argc = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "__p___argc\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const hint_crt_p_wargv = bytes.items.len;
    try appendInt(allocator, &bytes, u16, 0);
    try bytes.appendSlice(allocator, "__p___wargv\x00");
    while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    const name_kernel = bytes.items.len;
    try bytes.appendSlice(allocator, "KERNEL32.dll\x00");
    const name_prng = bytes.items.len;
    try bytes.appendSlice(allocator, "bcryptprimitives.dll\x00");
    const name_crt = bytes.items.len;
    try bytes.appendSlice(allocator, "ucrtbase.dll\x00");

    writeInt(u64, bytes.items, ilt_virtual, rva + @as(u32, @intCast(hint_virtual)));
    writeInt(u64, bytes.items, iat_virtual, rva + @as(u32, @intCast(hint_virtual)));
    writeInt(u64, bytes.items, ilt_virtual + 8, rva + @as(u32, @intCast(hint_counter)));
    writeInt(u64, bytes.items, iat_virtual + 8, rva + @as(u32, @intCast(hint_counter)));
    writeInt(u64, bytes.items, ilt_virtual + 16, rva + @as(u32, @intCast(hint_frequency)));
    writeInt(u64, bytes.items, iat_virtual + 16, rva + @as(u32, @intCast(hint_frequency)));
    writeInt(u64, bytes.items, ilt_virtual + 24, rva + @as(u32, @intCast(hint_get_std_handle)));
    writeInt(u64, bytes.items, iat_virtual + 24, rva + @as(u32, @intCast(hint_get_std_handle)));
    writeInt(u64, bytes.items, ilt_virtual + 32, rva + @as(u32, @intCast(hint_console_info)));
    writeInt(u64, bytes.items, iat_virtual + 32, rva + @as(u32, @intCast(hint_console_info)));
    writeInt(u64, bytes.items, ilt_virtual + 40, rva + @as(u32, @intCast(hint_get_console_mode)));
    writeInt(u64, bytes.items, iat_virtual + 40, rva + @as(u32, @intCast(hint_get_console_mode)));
    writeInt(u64, bytes.items, ilt_virtual + 48, rva + @as(u32, @intCast(hint_set_console_mode)));
    writeInt(u64, bytes.items, iat_virtual + 48, rva + @as(u32, @intCast(hint_set_console_mode)));
    writeInt(u64, bytes.items, ilt_virtual + 56, rva + @as(u32, @intCast(hint_get_console_cp)));
    writeInt(u64, bytes.items, iat_virtual + 56, rva + @as(u32, @intCast(hint_get_console_cp)));
    writeInt(u64, bytes.items, ilt_virtual + 64, rva + @as(u32, @intCast(hint_set_console_cp)));
    writeInt(u64, bytes.items, iat_virtual + 64, rva + @as(u32, @intCast(hint_set_console_cp)));
    writeInt(u64, bytes.items, ilt_virtual + 72, rva + @as(u32, @intCast(hint_wait)));
    writeInt(u64, bytes.items, iat_virtual + 72, rva + @as(u32, @intCast(hint_wait)));
    writeInt(u64, bytes.items, ilt_virtual + 80, rva + @as(u32, @intCast(hint_get_current_directory)));
    writeInt(u64, bytes.items, iat_virtual + 80, rva + @as(u32, @intCast(hint_get_current_directory)));
    writeInt(u64, bytes.items, ilt_virtual + 88, rva + @as(u32, @intCast(hint_set_current_directory)));
    writeInt(u64, bytes.items, iat_virtual + 88, rva + @as(u32, @intCast(hint_set_current_directory)));
    writeInt(u64, bytes.items, ilt_virtual + 96, rva + @as(u32, @intCast(hint_get_module_file_name)));
    writeInt(u64, bytes.items, iat_virtual + 96, rva + @as(u32, @intCast(hint_get_module_file_name)));
    writeInt(u64, bytes.items, ilt_virtual + 104, rva + @as(u32, @intCast(hint_get_current_process_id)));
    writeInt(u64, bytes.items, iat_virtual + 104, rva + @as(u32, @intCast(hint_get_current_process_id)));
    writeInt(u64, bytes.items, ilt_virtual + 112, rva + @as(u32, @intCast(hint_get_environment_variable)));
    writeInt(u64, bytes.items, iat_virtual + 112, rva + @as(u32, @intCast(hint_get_environment_variable)));
    writeInt(u64, bytes.items, ilt_virtual + 120, rva + @as(u32, @intCast(hint_set_environment_variable)));
    writeInt(u64, bytes.items, iat_virtual + 120, rva + @as(u32, @intCast(hint_set_environment_variable)));
    writeInt(u64, bytes.items, ilt_virtual + 128, rva + @as(u32, @intCast(hint_get_environment_strings)));
    writeInt(u64, bytes.items, iat_virtual + 128, rva + @as(u32, @intCast(hint_get_environment_strings)));
    writeInt(u64, bytes.items, ilt_virtual + 136, rva + @as(u32, @intCast(hint_free_environment_strings)));
    writeInt(u64, bytes.items, iat_virtual + 136, rva + @as(u32, @intCast(hint_free_environment_strings)));
    writeInt(u64, bytes.items, ilt_prng, rva + @as(u32, @intCast(hint_prng)));
    writeInt(u64, bytes.items, iat_prng, rva + @as(u32, @intCast(hint_prng)));
    writeInt(u64, bytes.items, ilt_crt, rva + @as(u32, @intCast(hint_crt_write)));
    writeInt(u64, bytes.items, iat_crt, rva + @as(u32, @intCast(hint_crt_write)));
    writeInt(u64, bytes.items, ilt_crt + 8, rva + @as(u32, @intCast(hint_crt_read)));
    writeInt(u64, bytes.items, iat_crt + 8, rva + @as(u32, @intCast(hint_crt_read)));
    writeInt(u64, bytes.items, ilt_crt + 16, rva + @as(u32, @intCast(hint_crt_isatty)));
    writeInt(u64, bytes.items, iat_crt + 16, rva + @as(u32, @intCast(hint_crt_isatty)));
    writeInt(u64, bytes.items, ilt_crt + 24, rva + @as(u32, @intCast(hint_crt_wopen)));
    writeInt(u64, bytes.items, iat_crt + 24, rva + @as(u32, @intCast(hint_crt_wopen)));
    writeInt(u64, bytes.items, ilt_crt + 32, rva + @as(u32, @intCast(hint_crt_close)));
    writeInt(u64, bytes.items, iat_crt + 32, rva + @as(u32, @intCast(hint_crt_close)));
    writeInt(u64, bytes.items, ilt_crt + 40, rva + @as(u32, @intCast(hint_crt_commit)));
    writeInt(u64, bytes.items, iat_crt + 40, rva + @as(u32, @intCast(hint_crt_commit)));
    writeInt(u64, bytes.items, ilt_crt + 48, rva + @as(u32, @intCast(hint_crt_lseeki64)));
    writeInt(u64, bytes.items, iat_crt + 48, rva + @as(u32, @intCast(hint_crt_lseeki64)));
    writeInt(u64, bytes.items, ilt_crt + 56, rva + @as(u32, @intCast(hint_crt_chsize_s)));
    writeInt(u64, bytes.items, iat_crt + 56, rva + @as(u32, @intCast(hint_crt_chsize_s)));
    writeInt(u64, bytes.items, ilt_crt + 64, rva + @as(u32, @intCast(hint_crt_p_argc)));
    writeInt(u64, bytes.items, iat_crt + 64, rva + @as(u32, @intCast(hint_crt_p_argc)));
    writeInt(u64, bytes.items, ilt_crt + 72, rva + @as(u32, @intCast(hint_crt_p_wargv)));
    writeInt(u64, bytes.items, iat_crt + 72, rva + @as(u32, @intCast(hint_crt_p_wargv)));
    writeDescriptor(bytes.items, 0, rva + @as(u32, @intCast(ilt_virtual)), rva + @as(u32, @intCast(name_kernel)), rva + @as(u32, @intCast(iat_virtual)));
    writeDescriptor(bytes.items, 20, rva + @as(u32, @intCast(ilt_prng)), rva + @as(u32, @intCast(name_prng)), rva + @as(u32, @intCast(iat_prng)));
    writeDescriptor(bytes.items, 40, rva + @as(u32, @intCast(ilt_crt)), rva + @as(u32, @intCast(name_crt)), rva + @as(u32, @intCast(iat_crt)));
    return .{
        .bytes = try bytes.toOwnedSlice(allocator),
        .iat_offset = @intCast(iat_virtual),
        .iat_size = @intCast((iat_crt + 88) - iat_virtual),
        .virtual_alloc_iat = @intCast(iat_virtual),
        .process_prng_iat = @intCast(iat_prng),
        .query_performance_counter_iat = @intCast(iat_virtual + 8),
        .query_performance_frequency_iat = @intCast(iat_virtual + 16),
        .get_std_handle_iat = @intCast(iat_virtual + 24),
        .get_console_screen_buffer_info_iat = @intCast(iat_virtual + 32),
        .get_console_mode_iat = @intCast(iat_virtual + 40),
        .set_console_mode_iat = @intCast(iat_virtual + 48),
        .get_console_cp_iat = @intCast(iat_virtual + 56),
        .set_console_cp_iat = @intCast(iat_virtual + 64),
        .wait_for_single_object_iat = @intCast(iat_virtual + 72),
        .get_current_directory_w_iat = @intCast(iat_virtual + 80),
        .set_current_directory_w_iat = @intCast(iat_virtual + 88),
        .get_module_file_name_w_iat = @intCast(iat_virtual + 96),
        .get_current_process_id_iat = @intCast(iat_virtual + 104),
        .get_environment_variable_w_iat = @intCast(iat_virtual + 112),
        .set_environment_variable_w_iat = @intCast(iat_virtual + 120),
        .get_environment_strings_w_iat = @intCast(iat_virtual + 128),
        .free_environment_strings_w_iat = @intCast(iat_virtual + 136),
        .crt_write_iat = @intCast(iat_crt),
        .crt_read_iat = @intCast(iat_crt + 8),
        .crt_isatty_iat = @intCast(iat_crt + 16),
        .crt_wopen_iat = @intCast(iat_crt + 24),
        .crt_close_iat = @intCast(iat_crt + 32),
        .crt_commit_iat = @intCast(iat_crt + 40),
        .crt_lseeki64_iat = @intCast(iat_crt + 48),
        .crt_chsize_s_iat = @intCast(iat_crt + 56),
        .crt_p_argc_iat = @intCast(iat_crt + 64),
        .crt_p_wargv_iat = @intCast(iat_crt + 72),
    };
}

fn buildImportsGeneric(allocator: Allocator, rva: u32) Allocator.Error!ImportImage {
    const libraries = [_][]const u8{ "KERNEL32.dll", "bcryptprimitives.dll", "ucrtbase.dll", "ws2_32.dll" };
    const symbols = std.enums.values(Imports.Symbol);
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.appendNTimes(allocator, 0, (libraries.len + 1) * 20);
    while (bytes.items.len % 8 != 0) try bytes.append(allocator, 0);

    var ilt_offsets: [libraries.len]usize = undefined;
    var iat_offsets: [libraries.len]usize = undefined;
    for (libraries, 0..) |library, library_index| {
        ilt_offsets[library_index] = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, (countLibrarySymbols(symbols, library) + 1) * 8);
    }
    const iat_start = bytes.items.len;
    for (libraries, 0..) |library, library_index| {
        iat_offsets[library_index] = bytes.items.len;
        try bytes.appendNTimes(allocator, 0, (countLibrarySymbols(symbols, library) + 1) * 8);
    }
    const iat_end = bytes.items.len;

    var hint_offsets: [ImportImage.symbol_count]usize = undefined;
    for (symbols) |symbol| {
        hint_offsets[@intFromEnum(symbol)] = bytes.items.len;
        try appendInt(allocator, &bytes, u16, 0);
        try bytes.appendSlice(allocator, symbol.sourceName());
        try bytes.append(allocator, 0);
        while (bytes.items.len % 2 != 0) try bytes.append(allocator, 0);
    }
    var name_offsets: [libraries.len]usize = undefined;
    for (libraries, 0..) |library, library_index| {
        name_offsets[library_index] = bytes.items.len;
        try bytes.appendSlice(allocator, library);
        try bytes.append(allocator, 0);
    }

    var image = ImportImage{
        .bytes = &.{},
        .iat_offset = @intCast(iat_start),
        .iat_size = @intCast(iat_end - iat_start),
    };
    for (libraries, 0..) |library, library_index| {
        var position: usize = 0;
        for (symbols) |symbol| {
            if (!std.mem.eql(u8, symbol.libraryName(), library)) continue;
            const hint_rva = rva + @as(u32, @intCast(hint_offsets[@intFromEnum(symbol)]));
            writeInt(u64, bytes.items, ilt_offsets[library_index] + position * 8, hint_rva);
            writeInt(u64, bytes.items, iat_offsets[library_index] + position * 8, hint_rva);
            image.iat[@intFromEnum(symbol)] = @intCast(iat_offsets[library_index] + position * 8);
            position += 1;
        }
        writeDescriptor(
            bytes.items,
            library_index * 20,
            rva + @as(u32, @intCast(ilt_offsets[library_index])),
            rva + @as(u32, @intCast(name_offsets[library_index])),
            rva + @as(u32, @intCast(iat_offsets[library_index])),
        );
    }
    image.bytes = try bytes.toOwnedSlice(allocator);
    return image;
}

fn countLibrarySymbols(symbols: []const Imports.Symbol, library: []const u8) usize {
    var count: usize = 0;
    for (symbols) |symbol| if (std.mem.eql(u8, symbol.libraryName(), library)) {
        count += 1;
    };
    return count;
}

fn writeDescriptor(bytes: []u8, offset: usize, original_thunk: u32, name: u32, first_thunk: u32) void {
    writeInt(u32, bytes, offset, original_thunk);
    writeInt(u32, bytes, offset + 12, name);
    writeInt(u32, bytes, offset + 16, first_thunk);
}

fn appendSection(allocator: Allocator, bytes: *std.ArrayList(u8), section_name: []const u8, virtual_size: usize, rva: u32, raw_size: usize, raw_offset: usize, flags: u32) Allocator.Error!void {
    var name: [8]u8 = @splat(0);
    @memcpy(name[0..section_name.len], section_name);
    try bytes.appendSlice(allocator, &name);
    try appendInt(allocator, bytes, u32, virtual_size);
    try appendInt(allocator, bytes, u32, rva);
    try appendInt(allocator, bytes, u32, raw_size);
    try appendInt(allocator, bytes, u32, raw_offset);
    try bytes.appendNTimes(allocator, 0, 12);
    try appendInt(allocator, bytes, u32, flags);
}

fn writeInt(comptime T: type, bytes: []u8, offset: usize, value: anytype) void {
    std.mem.writeInt(T, bytes[offset..][0..@sizeOf(T)], @intCast(value), .little);
}

fn appendInt(allocator: Allocator, bytes: *std.ArrayList(u8), comptime T: type, value: anytype) Allocator.Error!void {
    var encoded: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &encoded, @intCast(value), .little);
    try bytes.appendSlice(allocator, &encoded);
}

test "emit PE32+ containers for both Windows architectures" {
    const code = [_]u8{0xc3};
    for ([_]Architecture{ .x64, .arm64 }) |architecture| {
        const bytes = try emit(std.testing.allocator, architecture, &code, 0);
        defer std.testing.allocator.free(bytes);
        try std.testing.expectEqualStrings("MZ", bytes[0..2]);
        try std.testing.expectEqualStrings("PE\x00\x00", bytes[dos_header_size .. dos_header_size + 4]);
        const expected_machine: u16 = if (architecture == .x64) 0x8664 else 0xaa64;
        try std.testing.expectEqual(expected_machine, std.mem.readInt(u16, bytes[dos_header_size + 4 .. dos_header_size + 6], .little));
    }
}

test "emit deterministic Windows system imports and patch X64 IAT calls" {
    var code = [_]u8{ 0xff, 0x15, 0, 0, 0, 0, 0xc3 };
    const sites = [_]Imports.X64Site{.{ .displacement_offset = 2, .symbol = .process_prng }};
    const bytes = try emitX64(std.testing.allocator, .x64, &code, 6, &sites);
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "bcryptprimitives.dll\x00") != null);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "ProcessPrng\x00") != null);
    try std.testing.expect(std.mem.readInt(i32, bytes[file_alignment + 2 .. file_alignment + 6], .little) != 0);
}

test "patch an ARM64 import page and IAT load" {
    var code: [12]u8 = undefined;
    std.mem.writeInt(u32, code[0..4], 0x90000010, .little);
    std.mem.writeInt(u32, code[4..8], 0xf9400210, .little);
    std.mem.writeInt(u32, code[8..12], 0xd63f0200, .little);
    const sites = [_]Imports.Arm64Site{.{ .instruction_offset = 0, .symbol = .process_prng }};
    const bytes = try emitArm64(std.testing.allocator, &code, 8, &sites);
    defer std.testing.allocator.free(bytes);
    try std.testing.expect(std.mem.indexOf(u8, bytes, "bcryptprimitives.dll\x00") != null);
    try std.testing.expect(std.mem.readInt(u32, bytes[file_alignment..][0..4], .little) != 0x90000010);
}
