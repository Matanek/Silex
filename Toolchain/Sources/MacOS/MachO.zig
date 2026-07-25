const std = @import("std");
const macho = std.macho;

const Encoder = @import("../Arm64/Encoder.zig");
const Machine = @import("../Arm64/Machine.zig");
const CodeSignature = @import("CodeSignature.zig");

pub const Error = Encoder.Error || std.mem.Allocator.Error || error{
    InvalidMain,
};

const page_size: usize = 0x4000;
const image_base: u64 = 0x1_0000_0000;
const text_offset: usize = page_size;
const minimum_macos_version: u32 = 13 << 16;

pub fn emit(allocator: std.mem.Allocator, program: Machine.Program) Error![]u8 {
    const main_id = try findMain(program);

    var encoded = try Encoder.encode(allocator, program, .{ .executable_main = main_id });
    defer encoded.deinit(allocator);

    const dylinker_path = "/usr/lib/dyld\x00";
    const dylinker_command_size = std.mem.alignForward(
        usize,
        @sizeOf(macho.dylinker_command) + dylinker_path.len,
        @alignOf(u64),
    );

    const pagezero_command_size = @sizeOf(macho.segment_command_64);
    const text_command_size = @sizeOf(macho.segment_command_64) + @sizeOf(macho.section_64);
    const linkedit_command_size = @sizeOf(macho.segment_command_64);
    const build_version_command_size = @sizeOf(macho.build_version_command);
    const entry_command_size = @sizeOf(macho.entry_point_command);
    const signature_command_size = @sizeOf(macho.linkedit_data_command);
    const load_commands_size = pagezero_command_size + text_command_size + linkedit_command_size +
        dylinker_command_size + build_version_command_size + entry_command_size + signature_command_size;

    const unaligned_text_size = text_offset + encoded.code.len;
    const text_size = std.mem.alignForward(usize, unaligned_text_size, page_size);
    const signature_size = CodeSignature.size(text_size);
    const file_size = text_size + signature_size;

    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.ensureTotalCapacity(allocator, file_size);

    var header: macho.mach_header_64 = .{
        .magic = macho.MH_MAGIC_64,
        .cputype = macho.CPU_TYPE_ARM64,
        .cpusubtype = 0,
        .filetype = macho.MH_EXECUTE,
        .ncmds = 7,
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
        .size = encoded.code.len,
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

    var linkedit: macho.segment_command_64 = .{
        .cmd = .SEGMENT_64,
        .cmdsize = @sizeOf(macho.segment_command_64),
        .segname = name("__LINKEDIT"),
        .vmaddr = image_base + text_size,
        .vmsize = @intCast(std.mem.alignForward(usize, signature_size, page_size)),
        .fileoff = text_size,
        .filesize = signature_size,
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
        .dataoff = @intCast(text_size),
        .datasize = @intCast(signature_size),
    };
    try appendStruct(allocator, &bytes, &code_signature);

    if (bytes.items.len > text_offset) return error.InvalidMain;
    try appendZeroes(allocator, &bytes, text_offset - bytes.items.len);
    try bytes.appendSlice(allocator, encoded.code);
    try appendZeroes(allocator, &bytes, text_size - bytes.items.len);

    const signature = try CodeSignature.emit(allocator, bytes.items, text_size);
    defer allocator.free(signature);
    try bytes.appendSlice(allocator, signature);

    return bytes.toOwnedSlice(allocator);
}

fn findMain(program: Machine.Program) Error!Machine.FunctionId {
    var found: ?Machine.FunctionId = null;
    for (program.functions, 0..) |function, id| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        if (found != null or function.parameter_count != 0 or function.return_type != .void) {
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
    try std.testing.expectEqual(@as(u32, 7), std.mem.readInt(u32, bytes[16..20], .little));

    const main_command_offset = @sizeOf(macho.mach_header_64) +
        @sizeOf(macho.segment_command_64) +
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
