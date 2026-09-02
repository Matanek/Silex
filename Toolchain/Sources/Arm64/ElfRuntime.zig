const std = @import("std");

const Allocator = std.mem.Allocator;
const load_segment = 1;
const executable_flag = 1;
const page_size = 4096;

pub const Error = Allocator.Error || error{InvalidRuntimeImage};

pub const Payload = struct {
    bytes: []u8,
    text_size: usize,
    page_offset: u12,
    entry_offset: usize,
    preserves_page_layout: bool = true,

    pub fn deinit(self: Payload, allocator: Allocator) void {
        allocator.free(self.bytes);
    }
};

pub fn payload(allocator: Allocator, object: []const u8) Error!Payload {
    if (object.len < 64 or !std.mem.eql(u8, object[0..4], "\x7fELF") or
        object[4] != 2 or object[5] != 1 or read16(object, 18) != 183)
    {
        return error.InvalidRuntimeImage;
    }
    const entry = read64(object, 24);
    const program_offset: usize = @intCast(read64(object, 32));
    const program_entry_size: usize = read16(object, 54);
    const program_entry_count: usize = read16(object, 56);
    if (program_entry_size < 56 or program_offset + program_entry_size * program_entry_count > object.len) {
        return error.InvalidRuntimeImage;
    }

    var minimum: u64 = std.math.maxInt(u64);
    var maximum: u64 = 0;
    var executable_end: u64 = 0;
    for (0..program_entry_count) |index| {
        const header = program_offset + index * program_entry_size;
        if (read32(object, header) != load_segment) continue;
        const address = read64(object, header + 16);
        const memory_size = read64(object, header + 40);
        minimum = @min(minimum, address);
        maximum = @max(maximum, address + memory_size);
        if (read32(object, header + 4) & executable_flag != 0) {
            executable_end = @max(executable_end, address + memory_size);
        }
    }
    if (minimum == std.math.maxInt(u64) or maximum <= minimum or executable_end <= minimum or
        entry < minimum or entry >= maximum or maximum - minimum > 16 * 1024 * 1024)
    {
        return error.InvalidRuntimeImage;
    }

    const bytes = try allocator.alloc(u8, @intCast(maximum - minimum));
    @memset(bytes, 0);
    errdefer allocator.free(bytes);
    for (0..program_entry_count) |index| {
        const header = program_offset + index * program_entry_size;
        if (read32(object, header) != load_segment) continue;
        const file_offset: usize = @intCast(read64(object, header + 8));
        const address = read64(object, header + 16);
        const file_size: usize = @intCast(read64(object, header + 32));
        if (file_offset + file_size > object.len or address < minimum or address + file_size > maximum) {
            return error.InvalidRuntimeImage;
        }
        const destination: usize = @intCast(address - minimum);
        @memcpy(bytes[destination..][0..file_size], object[file_offset..][0..file_size]);
    }
    return .{
        .bytes = bytes,
        .text_size = @intCast(executable_end - minimum),
        .page_offset = @intCast(minimum % page_size),
        .entry_offset = @intCast(entry - minimum),
    };
}

fn read16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn read32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn read64(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}
