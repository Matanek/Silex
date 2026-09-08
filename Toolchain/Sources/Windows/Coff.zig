const std = @import("std");

pub const extended_relocations_flag: u32 = 0x01000000;

pub const RelocationLayout = struct {
    header_count: u16,
    table_entry_count: usize,
    overflow_count: ?u32,
};

pub fn relocationLayout(count: usize) error{InvalidImage}!RelocationLayout {
    if (count < std.math.maxInt(u16)) return .{
        .header_count = @intCast(count),
        .table_entry_count = count,
        .overflow_count = null,
    };
    if (count >= std.math.maxInt(u32)) return error.InvalidImage;
    return .{
        .header_count = std.math.maxInt(u16),
        .table_entry_count = count + 1,
        .overflow_count = @intCast(count + 1),
    };
}

test "COFF relocation layout reserves the extended count record" {
    const direct = try relocationLayout(std.math.maxInt(u16) - 1);
    try std.testing.expectEqual(@as(u16, std.math.maxInt(u16) - 1), direct.header_count);
    try std.testing.expectEqual(@as(usize, std.math.maxInt(u16) - 1), direct.table_entry_count);
    try std.testing.expectEqual(@as(?u32, null), direct.overflow_count);

    const extended = try relocationLayout(std.math.maxInt(u16));
    try std.testing.expectEqual(@as(u16, std.math.maxInt(u16)), extended.header_count);
    try std.testing.expectEqual(@as(usize, std.math.maxInt(u16)) + 1, extended.table_entry_count);
    try std.testing.expectEqual(@as(?u32, std.math.maxInt(u16) + 1), extended.overflow_count);

    try std.testing.expectError(error.InvalidImage, relocationLayout(std.math.maxInt(u32)));
}
