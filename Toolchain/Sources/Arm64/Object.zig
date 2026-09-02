const std = @import("std");
const Encoder = @import("Encoder.zig");
const Instructions = @import("Instructions.zig");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;

pub const Error = Encoder.Error || Allocator.Error || error{ InvalidImage, InvalidMain };

const no_operation: u32 = 0xd503201f;
const image_file_machine_arm64: u16 = 0xaa64;
const image_rel_arm64_branch26: u16 = 0x0003;
const image_rel_arm64_pagebase_rel21: u16 = 0x0004;
const image_rel_arm64_pageoffset_12a: u16 = 0x0006;
const image_rel_arm64_pageoffset_12l: u16 = 0x0007;

pub fn emitWindows(allocator: Allocator, program: Machine.Program) Error![]u8 {
    var image = try Encoder.encodeWindows(allocator, program, .{ .executable_main = try findMain(program) });
    defer image.deinit(allocator);
    return emitWindowsImage(allocator, program, &image);
}

pub fn emitWindowsFunction(
    allocator: Allocator,
    program: Machine.Program,
    function: Machine.FunctionId,
) Error![]u8 {
    var image = try Encoder.encodeWindows(allocator, program, .{ .test_function = function });
    defer image.deinit(allocator);
    return emitWindowsImage(allocator, program, &image);
}

fn emitWindowsImage(allocator: Allocator, program: Machine.Program, image: *Encoder.Image) Error![]u8 {
    const entry_offset = image.entry_offset orelse return error.InvalidImage;
    var external_names: std.ArrayList([]const u8) = .empty;
    defer external_names.deinit(allocator);
    const external_symbol_for_site = try allocator.alloc(u32, image.external_call_sites.len);
    defer allocator.free(external_symbol_for_site);

    const first_external_symbol: u32 = @intCast(1 + image.address_sites.len);
    for (image.external_call_sites, 0..) |site, site_index| {
        if (@as(usize, site.instruction_offset) + 12 > image.code.len) return error.InvalidImage;
        const external_name = if (site.windows_symbol) |symbol|
            symbol.sourceName()
        else name: {
            if (site.function >= program.external_functions.len) return error.InvalidImage;
            break :name program.external_functions[site.function].source_name;
        };
        var name_index: ?usize = null;
        for (external_names.items, 0..) |existing, index| if (std.mem.eql(u8, existing, external_name)) {
            name_index = index;
            break;
        };
        if (name_index == null) {
            name_index = external_names.items.len;
            try external_names.append(allocator, external_name);
        }
        external_symbol_for_site[site_index] = first_external_symbol + @as(u32, @intCast(name_index.?));
        std.mem.writeInt(u32, image.code[site.instruction_offset..][0..4], Instructions.branchLink(), .little);
        std.mem.writeInt(u32, image.code[site.instruction_offset + 4 ..][0..4], no_operation, .little);
        std.mem.writeInt(u32, image.code[site.instruction_offset + 8 ..][0..4], no_operation, .little);
    }
    for (image.address_sites) |site| {
        if (@as(usize, site.instruction_offset) + 8 > image.code.len or site.target_offset >= image.code.len) return error.InvalidImage;
        var page = std.mem.readInt(u32, image.code[site.instruction_offset..][0..4], .little);
        page &= 0x9f00001f;
        std.mem.writeInt(u32, image.code[site.instruction_offset..][0..4], page, .little);
        var offset = std.mem.readInt(u32, image.code[site.instruction_offset + 4 ..][0..4], .little);
        offset &= ~@as(u32, 0x003ffc00);
        std.mem.writeInt(u32, image.code[site.instruction_offset + 4 ..][0..4], offset, .little);
    }

    const relocation_count = image.external_call_sites.len + image.address_sites.len * 2;
    if (relocation_count > std.math.maxInt(u16)) return error.InvalidImage;
    const symbol_count: u32 = @intCast(1 + image.address_sites.len + external_names.items.len);
    const header_size: usize = 20 + 40;
    const text_offset = header_size;
    const relocation_offset = text_offset + image.code.len;
    const symbol_offset = relocation_offset + relocation_count * 10;

    var string_table: std.ArrayList(u8) = .empty;
    defer string_table.deinit(allocator);
    try string_table.appendNTimes(allocator, 0, 4);
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try appendInt(allocator, &bytes, u16, image_file_machine_arm64);
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
    for (image.address_sites, 0..) |site, index| {
        const symbol: u32 = @intCast(1 + index);
        try appendRelocation(allocator, &bytes, site.instruction_offset, symbol, image_rel_arm64_pagebase_rel21);
        try appendRelocation(
            allocator,
            &bytes,
            site.instruction_offset + 4,
            symbol,
            try pageOffsetRelocation(image.code, site.instruction_offset + 4),
        );
    }
    for (image.external_call_sites, 0..) |site, index| {
        try appendRelocation(allocator, &bytes, site.instruction_offset, external_symbol_for_site[index], image_rel_arm64_branch26);
    }

    try appendSymbol(allocator, &bytes, &string_table, "main", entry_offset, 1, 0x20, 2);
    for (image.address_sites, 0..) |site, index| {
        const name = try std.fmt.allocPrint(allocator, "$silex_address_{d}", .{index});
        try appendSymbol(allocator, &bytes, &string_table, name, site.target_offset, 1, 0, 3);
    }
    for (external_names.items) |name| try appendSymbol(allocator, &bytes, &string_table, name, 0, 0, 0, 2);
    std.mem.writeInt(u32, string_table.items[0..4], @intCast(string_table.items.len), .little);
    try bytes.appendSlice(allocator, string_table.items);
    return bytes.toOwnedSlice(allocator);
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

fn appendRelocation(allocator: Allocator, bytes: *std.ArrayList(u8), offset: u32, symbol: u32, kind: u16) !void {
    try appendInt(allocator, bytes, u32, offset);
    try appendInt(allocator, bytes, u32, symbol);
    try appendInt(allocator, bytes, u16, kind);
}

fn pageOffsetRelocation(code: []const u8, instruction_offset: u32) Error!u16 {
    if (@as(usize, instruction_offset) + 4 > code.len) return error.InvalidImage;
    const instruction = std.mem.readInt(u32, code[instruction_offset..][0..4], .little);
    if (instruction & 0x1f000000 == 0x11000000) return image_rel_arm64_pageoffset_12a;
    if (instruction & 0x3b000000 == 0x39000000) return image_rel_arm64_pageoffset_12l;
    return error.InvalidImage;
}

fn appendSymbol(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    strings: *std.ArrayList(u8),
    name: []const u8,
    value: u32,
    section: i16,
    kind: u16,
    storage_class: u8,
) !void {
    try appendName(allocator, bytes, strings, name);
    try appendInt(allocator, bytes, u32, value);
    try appendInt(allocator, bytes, i16, section);
    try appendInt(allocator, bytes, u16, kind);
    try bytes.appendSlice(allocator, &.{ storage_class, 0 });
}

fn appendName(allocator: Allocator, bytes: *std.ArrayList(u8), strings: *std.ArrayList(u8), name: []const u8) !void {
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

test "emit builds an ARM64 COFF object" {
    const Frontend = @import("../Frontend.zig");
    const Lower = @import("Lower.zig");

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile("func main() {}");
    const machine = try Lower.lower(allocator, compilation.ir);
    const bytes = try emitWindows(allocator, machine);

    try std.testing.expectEqual(image_file_machine_arm64, std.mem.readInt(u16, bytes[0..2], .little));
    try std.testing.expectEqual(@as(u16, 1), std.mem.readInt(u16, bytes[2..4], .little));
}

test "emit exposes an ARM64 test entry as a COFF main symbol" {
    const Frontend = @import("../Frontend.zig");
    const Lower = @import("Lower.zig");

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compileTests("test \"answer\" { assert(40 + 2 == 42) }");
    const machine = try Lower.lower(allocator, compilation.ir);
    const bytes = try emitWindowsFunction(allocator, machine, 0);

    try std.testing.expectEqual(image_file_machine_arm64, std.mem.readInt(u16, bytes[0..2], .little));
    const symbol_offset = std.mem.readInt(u32, bytes[8..12], .little);
    try std.testing.expectEqualStrings("main", std.mem.sliceTo(bytes[symbol_offset..][0..8], 0));
}

test "emit uses the COFF page-offset relocation matching the low instruction" {
    var add_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &add_bytes, 0x91000000, .little);
    try std.testing.expectEqual(image_rel_arm64_pageoffset_12a, try pageOffsetRelocation(&add_bytes, 0));

    var load_bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &load_bytes, 0x3dc00000, .little);
    try std.testing.expectEqual(image_rel_arm64_pageoffset_12l, try pageOffsetRelocation(&load_bytes, 0));
}
