const std = @import("std");

const Allocator = std.mem.Allocator;

const mach_header_size = 32;
const segment_command_64 = 0x19;
const main_command = 0x80000028;
const segment_command_size = 72;
const section_size = 80;
const cpu_type_x86_64 = 0x01000007;
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

pub fn payload(allocator: Allocator, object_bytes: []const u8) Error!Payload {
    if (object_bytes.len < mach_header_size or read32(object_bytes, 0) != 0xfeedfacf or
        read32(object_bytes, 4) != cpu_type_x86_64)
    {
        return error.InvalidRuntimeImage;
    }
    const command_count = read32(object_bytes, 16);
    var command_offset: usize = mach_header_size;
    var text_file_offset: ?usize = null;
    var text_address: u64 = 0;
    var minimum: u64 = std.math.maxInt(u64);
    var maximum: u64 = 0;
    var entry_file_offset: ?usize = null;

    for (0..command_count) |_| {
        if (command_offset + 8 > object_bytes.len) return error.InvalidRuntimeImage;
        const command = read32(object_bytes, command_offset);
        const command_size = read32(object_bytes, command_offset + 4);
        if (command_size < 8 or command_offset + command_size > object_bytes.len) return error.InvalidRuntimeImage;
        if (command == segment_command_64) {
            if (command_size < segment_command_size) return error.InvalidRuntimeImage;
            const section_count = read32(object_bytes, command_offset + 64);
            if (segment_command_size + section_count * section_size > command_size) return error.InvalidRuntimeImage;
            var section_offset = command_offset + segment_command_size;
            for (0..section_count) |_| {
                const address = read64(object_bytes, section_offset + 32);
                const size = read64(object_bytes, section_offset + 40);
                const file_offset: usize = read32(object_bytes, section_offset + 48);
                if (std.mem.eql(u8, name(object_bytes, section_offset), "__text")) {
                    text_file_offset = file_offset;
                    text_address = address;
                }
                if (size != 0) {
                    minimum = @min(minimum, address);
                    maximum = @max(maximum, address + size);
                }
                section_offset += section_size;
            }
        } else if (command == main_command) {
            if (command_size < 24) return error.InvalidRuntimeImage;
            entry_file_offset = @intCast(read64(object_bytes, command_offset + 8));
        }
        command_offset += command_size;
    }

    const text_file = text_file_offset orelse return error.InvalidRuntimeImage;
    const entry_file = entry_file_offset orelse return error.InvalidRuntimeImage;
    if (minimum == std.math.maxInt(u64) or maximum <= minimum or maximum - minimum > 16 * 1024 * 1024 or entry_file < text_file) {
        return error.InvalidRuntimeImage;
    }
    const entry_address = text_address + entry_file - text_file;
    if (entry_address < minimum or entry_address >= maximum) return error.InvalidRuntimeImage;

    const bytes = try allocator.alloc(u8, @intCast(maximum - minimum));
    @memset(bytes, 0);
    errdefer allocator.free(bytes);
    command_offset = mach_header_size;
    for (0..command_count) |_| {
        const command = read32(object_bytes, command_offset);
        const command_size = read32(object_bytes, command_offset + 4);
        if (command == segment_command_64) {
            const section_count = read32(object_bytes, command_offset + 64);
            var section_offset = command_offset + segment_command_size;
            for (0..section_count) |_| {
                const address = read64(object_bytes, section_offset + 32);
                const size: usize = @intCast(read64(object_bytes, section_offset + 40));
                const file_offset: usize = read32(object_bytes, section_offset + 48);
                if (size != 0 and file_offset != 0) {
                    if (file_offset + size > object_bytes.len or address < minimum or address + size > maximum) {
                        return error.InvalidRuntimeImage;
                    }
                    const destination: usize = @intCast(address - minimum);
                    @memcpy(bytes[destination..][0..size], object_bytes[file_offset..][0..size]);
                }
                section_offset += section_size;
            }
        }
        command_offset += command_size;
    }
    return .{
        .bytes = bytes,
        .page_offset = @intCast(minimum % page_size),
        .entry_offset = @intCast(entry_address - minimum),
    };
}

fn read32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn read64(bytes: []const u8, offset: usize) u64 {
    return std.mem.readInt(u64, bytes[offset..][0..8], .little);
}

fn name(bytes: []const u8, offset: usize) []const u8 {
    const value = bytes[offset..][0..16];
    return value[0 .. std.mem.indexOfScalar(u8, value, 0) orelse value.len];
}
