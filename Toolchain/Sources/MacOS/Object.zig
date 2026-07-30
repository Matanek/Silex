const std = @import("std");
const macho = std.macho;

const Encoder = @import("../Arm64/Encoder.zig");
const Instructions = @import("../Arm64/Instructions.zig");
const Machine = @import("../Arm64/Machine.zig");

const Allocator = std.mem.Allocator;

pub const Error = Encoder.Error || Allocator.Error || error{InvalidMain};

const minimum_macos_version: u32 = 13 << 16;
const no_operation: u32 = 0xd503201f;

pub fn emit(allocator: Allocator, program: Machine.Program) Error![]u8 {
    const main = try findMain(program);
    var encoded = try Encoder.encode(allocator, program, .{ .executable_main = main });
    defer encoded.deinit(allocator);
    return emitEncoded(allocator, program, &encoded);
}

fn emitEncoded(allocator: Allocator, program: Machine.Program, encoded: *Encoder.Image) Error![]u8 {
    const text_size: usize = encoded.data_offset orelse @intCast(encoded.code.len);
    const data_size = encoded.code.len - text_size;
    const section_count: usize = 1 + @as(usize, @intFromBool(data_size != 0));
    const segment_command_size = @sizeOf(macho.segment_command_64) + section_count * @sizeOf(macho.section_64);
    const load_commands_size = segment_command_size + @sizeOf(macho.build_version_command) +
        @sizeOf(macho.symtab_command) + @sizeOf(macho.dysymtab_command);
    const content_offset = std.mem.alignForward(usize, @sizeOf(macho.mach_header_64) + load_commands_size, 8);

    for (encoded.external_call_sites) |site| {
        if (site.function >= program.external_functions.len or site.instruction_offset + 12 > text_size) return error.InvalidMain;
        std.mem.writeInt(u32, encoded.code[site.instruction_offset..][0..4], Instructions.branchLink(), .little);
        std.mem.writeInt(u32, encoded.code[site.instruction_offset + 4 ..][0..4], no_operation, .little);
        std.mem.writeInt(u32, encoded.code[site.instruction_offset + 8 ..][0..4], no_operation, .little);
    }
    for (encoded.address_sites) |site| {
        if (site.instruction_offset + 8 > text_size or site.target_offset >= encoded.code.len) return error.InvalidMain;
        var page = std.mem.readInt(u32, encoded.code[site.instruction_offset..][0..4], .little);
        page &= 0x9f00001f;
        std.mem.writeInt(u32, encoded.code[site.instruction_offset..][0..4], page, .little);
        var offset = std.mem.readInt(u32, encoded.code[site.instruction_offset + 4 ..][0..4], .little);
        offset &= ~@as(u32, 0x003ffc00);
        std.mem.writeInt(u32, encoded.code[site.instruction_offset + 4 ..][0..4], offset, .little);
    }

    var relocations: std.ArrayList(macho.relocation_info) = .empty;
    defer relocations.deinit(allocator);
    for (encoded.address_sites, 0..) |site, symbol| {
        try relocations.append(allocator, relocation(
            site.instruction_offset + 4,
            @intCast(symbol),
            false,
            .ARM64_RELOC_PAGEOFF12,
        ));
        try relocations.append(allocator, relocation(
            site.instruction_offset,
            @intCast(symbol),
            true,
            .ARM64_RELOC_PAGE21,
        ));
    }
    const first_undefined = encoded.address_sites.len + 1;
    for (encoded.external_call_sites) |site| try relocations.append(allocator, relocation(
        site.instruction_offset,
        @intCast(first_undefined + site.function),
        true,
        .ARM64_RELOC_BRANCH26,
    ));
    std.mem.sort(macho.relocation_info, relocations.items, {}, relocationBefore);

    const relocation_offset = std.mem.alignForward(usize, content_offset + encoded.code.len, 8);
    const symbol_offset = relocation_offset + relocations.items.len * @sizeOf(macho.relocation_info);
    const symbol_count = encoded.address_sites.len + 1 + program.external_functions.len;
    const string_offset = symbol_offset + symbol_count * @sizeOf(macho.nlist_64);

    var string_table: std.ArrayList(u8) = .empty;
    defer string_table.deinit(allocator);
    try string_table.append(allocator, 0);
    const address_names = try allocator.alloc(u32, encoded.address_sites.len);
    defer allocator.free(address_names);
    for (address_names, 0..) |*offset, index| {
        offset.* = @intCast(string_table.items.len);
        try string_table.print(allocator, "l_silex_address_{d}\x00", .{index});
    }
    const main_name: u32 = @intCast(string_table.items.len);
    try string_table.appendSlice(allocator, "_main\x00");
    const external_names = try allocator.alloc(u32, program.external_functions.len);
    defer allocator.free(external_names);
    for (program.external_functions, 0..) |function, index| {
        external_names[index] = @intCast(string_table.items.len);
        try string_table.append(allocator, '_');
        try string_table.appendSlice(allocator, function.source_name);
        try string_table.append(allocator, 0);
    }

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.ensureTotalCapacity(allocator, string_offset + string_table.items.len);
    var header: macho.mach_header_64 = .{
        .magic = macho.MH_MAGIC_64,
        .cputype = macho.CPU_TYPE_ARM64,
        .cpusubtype = 0,
        .filetype = macho.MH_OBJECT,
        .ncmds = 4,
        .sizeofcmds = @intCast(load_commands_size),
        .flags = 0,
        .reserved = 0,
    };
    try appendStruct(allocator, &bytes, &header);
    var segment: macho.segment_command_64 = .{
        .cmd = .SEGMENT_64,
        .cmdsize = @intCast(segment_command_size),
        .segname = [_]u8{0} ** 16,
        .vmaddr = 0,
        .vmsize = encoded.code.len,
        .fileoff = content_offset,
        .filesize = encoded.code.len,
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
        .@"align" = 2,
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
        .strsize = @intCast(string_table.items.len),
    };
    try appendStruct(allocator, &bytes, &symtab);
    var dysymtab: macho.dysymtab_command = .{
        .ilocalsym = 0,
        .nlocalsym = @intCast(encoded.address_sites.len),
        .iextdefsym = @intCast(encoded.address_sites.len),
        .nextdefsym = 1,
        .iundefsym = @intCast(first_undefined),
        .nundefsym = @intCast(program.external_functions.len),
    };
    try appendStruct(allocator, &bytes, &dysymtab);

    try appendZeroes(allocator, &bytes, content_offset - bytes.items.len);
    try bytes.appendSlice(allocator, encoded.code);
    try appendZeroes(allocator, &bytes, relocation_offset - bytes.items.len);
    for (relocations.items) |entry| try appendStruct(allocator, &bytes, &entry);
    for (encoded.address_sites, 0..) |site, index| {
        var symbol: macho.nlist_64 = .{
            .n_strx = address_names[index],
            .n_type = .{ .bits = .{ .ext = false, .type = .sect, .pext = false, .is_stab = 0 } },
            .n_sect = if (data_size != 0 and site.target_offset >= text_size) 2 else 1,
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
        .n_value = encoded.entry_offset.?,
    };
    try appendStruct(allocator, &bytes, &main_symbol);
    for (external_names) |external_name| {
        var symbol: macho.nlist_64 = .{
            .n_strx = external_name,
            .n_type = .{ .bits = .{ .ext = true, .type = .undf, .pext = false, .is_stab = 0 } },
            .n_sect = 0,
            .n_desc = @bitCast(@as(u16, 0)),
            .n_value = 0,
        };
        try appendStruct(allocator, &bytes, &symbol);
    }
    try bytes.appendSlice(allocator, string_table.items);
    return bytes.toOwnedSlice(allocator);
}

fn relocation(
    address: u32,
    symbol: u24,
    pc_relative: bool,
    kind: macho.reloc_type_arm64,
) macho.relocation_info {
    return .{
        .r_address = @intCast(address),
        .r_symbolnum = symbol,
        .r_pcrel = @intFromBool(pc_relative),
        .r_length = 2,
        .r_extern = 1,
        .r_type = @intFromEnum(kind),
    };
}

fn relocationBefore(_: void, left: macho.relocation_info, right: macho.relocation_info) bool {
    return left.r_address > right.r_address;
}

fn findMain(program: Machine.Program) Error!Machine.FunctionId {
    var found: ?Machine.FunctionId = null;
    for (program.functions, 0..) |function, id| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        if (found != null or function.parameter_count != 0 or
            (function.return_type != .void and !function.recoverable_entry_result)) return error.InvalidMain;
        found = id;
    }
    return found orelse error.InvalidMain;
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

test "emit builds an ARM64 relocatable Mach-O object" {
    const builtin = @import("builtin");
    const Frontend = @import("../Frontend.zig");
    const Lower = @import("../Arm64/Lower.zig");

    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile("func main() { print(\"object\") }");
    const machine = try Lower.lower(allocator, compilation.ir);
    const bytes = try emit(allocator, machine);

    try std.testing.expectEqual(@as(u32, macho.MH_MAGIC_64), std.mem.readInt(u32, bytes[0..4], .little));
    try std.testing.expectEqual(@as(u32, @bitCast(macho.CPU_TYPE_ARM64)), std.mem.readInt(u32, bytes[4..8], .little));
    try std.testing.expectEqual(@as(u32, macho.MH_OBJECT), std.mem.readInt(u32, bytes[12..16], .little));

    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "program.o", .data = bytes });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const object_path = try std.fs.path.join(allocator, &.{ base, "program.o" });
    const executable_path = try std.fs.path.join(allocator, &.{ base, "program" });
    const linked = try std.process.run(allocator, std.testing.io, .{
        .argv = &.{ "zig", "cc", "-target", "aarch64-macos", object_path, "-o", executable_path },
    });
    try std.testing.expectEqual(@as(u8, 0), exitCode(linked.term));
    const executed = try std.process.run(allocator, std.testing.io, .{ .argv = &.{executable_path} });
    try std.testing.expectEqual(@as(u8, 0), exitCode(executed.term));
    try std.testing.expectEqualStrings("object\n", executed.stdout);
}

fn exitCode(termination: std.process.Child.Term) u8 {
    return switch (termination) {
        .exited => |code| code,
        else => 255,
    };
}
