const std = @import("std");

pub const object_bytes = @import("cycle_runtime_x64_object").object_bytes;
pub const macos_object_bytes = @import("cycle_runtime_macos_x64_object").object_bytes;
const MachORuntime = @import("MachORuntime.zig");

const Allocator = std.mem.Allocator;
const load_segment = 1;
const page_size = 4096;

pub const Error = Allocator.Error || error{InvalidRuntimeImage};

pub const Payload = struct {
    bytes: []u8,
    page_offset: usize,
    entry_offset: usize,

    pub fn deinit(self: Payload, allocator: Allocator) void {
        allocator.free(self.bytes);
    }
};

pub fn payload(allocator: Allocator) Error!Payload {
    if (object_bytes.len < 64 or !std.mem.eql(u8, object_bytes[0..4], "\x7fELF") or
        object_bytes[4] != 2 or object_bytes[5] != 1 or read16(18) != 62)
    {
        return error.InvalidRuntimeImage;
    }
    const entry = read64(24);
    const program_offset: usize = @intCast(read64(32));
    const entry_size: usize = read16(54);
    const entry_count: usize = read16(56);
    if (entry_size < 56 or program_offset + entry_size * entry_count > object_bytes.len) {
        return error.InvalidRuntimeImage;
    }

    var minimum: u64 = std.math.maxInt(u64);
    var maximum: u64 = 0;
    for (0..entry_count) |index| {
        const header = program_offset + index * entry_size;
        if (read32(header) != load_segment) continue;
        const address = read64(header + 16);
        const memory_size = read64(header + 40);
        minimum = @min(minimum, address);
        maximum = @max(maximum, address + memory_size);
    }
    if (minimum == std.math.maxInt(u64) or maximum <= minimum or entry < minimum or entry >= maximum or
        maximum - minimum > 16 * 1024 * 1024)
    {
        return error.InvalidRuntimeImage;
    }

    const bytes = try allocator.alloc(u8, @intCast(maximum - minimum));
    @memset(bytes, 0);
    errdefer allocator.free(bytes);
    for (0..entry_count) |index| {
        const header = program_offset + index * entry_size;
        if (read32(header) != load_segment) continue;
        const file_offset: usize = @intCast(read64(header + 8));
        const address = read64(header + 16);
        const file_size: usize = @intCast(read64(header + 32));
        if (file_offset + file_size > object_bytes.len or address < minimum or address + file_size > maximum) {
            return error.InvalidRuntimeImage;
        }
        const destination: usize = @intCast(address - minimum);
        @memcpy(bytes[destination..][0..file_size], object_bytes[file_offset..][0..file_size]);
    }
    return .{
        .bytes = bytes,
        .page_offset = @intCast(minimum % page_size),
        .entry_offset = @intCast(entry - minimum),
    };
}

pub fn payloadForPlatform(allocator: Allocator, darwin: bool) (Error || MachORuntime.Error)!Payload {
    if (!darwin) return payload(allocator);
    const image = try MachORuntime.payload(allocator, macos_object_bytes);
    return .{ .bytes = image.bytes, .page_offset = image.page_offset, .entry_offset = image.entry_offset };
}

fn read16(offset: usize) u16 {
    return std.mem.readInt(u16, object_bytes[offset..][0..2], .little);
}

fn read32(offset: usize) u32 {
    return std.mem.readInt(u32, object_bytes[offset..][0..4], .little);
}

fn read64(offset: usize) u64 {
    return std.mem.readInt(u64, object_bytes[offset..][0..8], .little);
}

test "bundled X64 cycle runtime is an ELF image" {
    var runtime = try payload(std.testing.allocator);
    defer runtime.deinit(std.testing.allocator);
    try std.testing.expect(runtime.bytes.len > 4096);
    try std.testing.expect(runtime.entry_offset < runtime.bytes.len);
}

test "bundled macOS X64 cycle runtime is a Mach-O image" {
    var runtime = try payloadForPlatform(std.testing.allocator, true);
    defer runtime.deinit(std.testing.allocator);
    try std.testing.expect(runtime.bytes.len > 0);
    try std.testing.expect(runtime.entry_offset < runtime.bytes.len);
}
