const std = @import("std");

const Allocator = std.mem.Allocator;

const page_size: usize = 0x1000;
const image_base: u64 = 0x400000;

pub const Error = Allocator.Error || error{InvalidEntry};

pub const Architecture = enum {
    x64,
    arm64,

    fn machine(self: Architecture) u16 {
        return switch (self) {
            .x64 => 62,
            .arm64 => 183,
        };
    }
};

/// Wraps an already encoded Linux image in a deterministic ELF64
/// executable. Dynamic imports and writable data are added by later layers;
/// this base emitter deliberately owns only the executable container contract.
pub fn emit(allocator: Allocator, architecture: Architecture, code: []const u8, entry_offset: u32) Error![]u8 {
    if (entry_offset >= code.len) return error.InvalidEntry;
    const file_size = page_size + code.len;
    var bytes: std.ArrayList(u8) = .empty;
    errdefer bytes.deinit(allocator);
    try bytes.ensureTotalCapacity(allocator, file_size);

    try bytes.appendSlice(allocator, "\x7fELF");
    try bytes.appendSlice(allocator, &.{ 2, 1, 1, 0, 0 });
    try bytes.appendNTimes(allocator, 0, 7);
    try appendInt(allocator, &bytes, u16, 2);
    try appendInt(allocator, &bytes, u16, architecture.machine());
    try appendInt(allocator, &bytes, u32, 1);
    try appendInt(allocator, &bytes, u64, image_base + page_size + entry_offset);
    try appendInt(allocator, &bytes, u64, 64);
    try appendInt(allocator, &bytes, u64, 0);
    try appendInt(allocator, &bytes, u32, 0);
    try appendInt(allocator, &bytes, u16, 64);
    try appendInt(allocator, &bytes, u16, 56);
    try appendInt(allocator, &bytes, u16, 1);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u16, 0);
    try appendInt(allocator, &bytes, u16, 0);

    try appendInt(allocator, &bytes, u32, 1);
    // Mutable globals still live at the tail of the bootstrap image. Keep this
    // single segment writable until the emitter splits mutable data into its
    // own PT_LOAD segment.
    try appendInt(allocator, &bytes, u32, 7);
    try appendInt(allocator, &bytes, u64, 0);
    try appendInt(allocator, &bytes, u64, image_base);
    try appendInt(allocator, &bytes, u64, image_base);
    try appendInt(allocator, &bytes, u64, file_size);
    try appendInt(allocator, &bytes, u64, file_size);
    try appendInt(allocator, &bytes, u64, page_size);

    try bytes.appendNTimes(allocator, 0, page_size - bytes.items.len);
    try bytes.appendSlice(allocator, code);
    return bytes.toOwnedSlice(allocator);
}

fn appendInt(allocator: Allocator, bytes: *std.ArrayList(u8), comptime T: type, value: T) Allocator.Error!void {
    var encoded: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &encoded, value, .little);
    try bytes.appendSlice(allocator, &encoded);
}

test "emit a deterministic Linux X64 ELF64 container" {
    const code = [_]u8{ 0x31, 0xc0, 0xc3 };
    const bytes = try emit(std.testing.allocator, .x64, &code, 0);
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqualStrings("\x7fELF", bytes[0..4]);
    try std.testing.expectEqual(@as(u8, 2), bytes[4]);
    try std.testing.expectEqual(@as(u16, 0x3e), std.mem.readInt(u16, bytes[18..20], .little));
    try std.testing.expectEqual(image_base + page_size, std.mem.readInt(u64, bytes[24..32], .little));
    try std.testing.expectEqualSlices(u8, &code, bytes[page_size..]);

    const arm64 = try emit(std.testing.allocator, .arm64, &code, 0);
    defer std.testing.allocator.free(arm64);
    try std.testing.expectEqual(@as(u16, 183), std.mem.readInt(u16, arm64[18..20], .little));
}
