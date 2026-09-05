const std = @import("std");

pub const object_bytes = @import("float_runtime_object").object_bytes;
pub const linux_object_bytes = @import("float_runtime_linux_arm64_object").object_bytes;
const ElfRuntime = @import("ElfRuntime.zig");

const mach_header_size = 32;
const segment_command_64 = 0x19;
const main_command = 0x80000028;
const segment_command_size = 72;
const section_size = 80;
const page_size = 4096;

pub const Error = error{InvalidRuntimeImage};

pub const Payload = struct {
    bytes: []const u8,
    text_size: usize,
    page_offset: u12,
    entry_offset: usize,
};

pub fn payload() Error!Payload {
    if (object_bytes.len < mach_header_size or read32(0) != 0xfeedfacf) return error.InvalidRuntimeImage;
    const command_count = read32(16);
    var command_offset: usize = mach_header_size;
    var text_offset: ?usize = null;
    var text_size: usize = 0;
    var text_address: u64 = 0;
    var payload_end: usize = 0;
    var entry_file_offset: ?usize = null;

    for (0..command_count) |_| {
        if (command_offset + 8 > object_bytes.len) return error.InvalidRuntimeImage;
        const command = read32(command_offset);
        const command_size = read32(command_offset + 4);
        if (command_size < 8 or command_offset + command_size > object_bytes.len) return error.InvalidRuntimeImage;
        if (command == segment_command_64) {
            if (command_size < segment_command_size) return error.InvalidRuntimeImage;
            const section_count = read32(command_offset + 64);
            if (segment_command_size + section_count * section_size > command_size) return error.InvalidRuntimeImage;
            var section_offset = command_offset + segment_command_size;
            for (0..section_count) |_| {
                const section_name = name(section_offset);
                const segment_name = name(section_offset + 16);
                if (std.mem.eql(u8, segment_name, "__TEXT")) {
                    const address = read64(section_offset + 32);
                    const size: usize = @intCast(read64(section_offset + 40));
                    const file_offset: usize = read32(section_offset + 48);
                    if (file_offset + size > object_bytes.len) return error.InvalidRuntimeImage;
                    if (std.mem.eql(u8, section_name, "__text")) {
                        text_offset = file_offset;
                        text_size = size;
                        text_address = address;
                    }
                    if (std.mem.eql(u8, section_name, "__text") or
                        std.mem.eql(u8, section_name, "__const") or
                        std.mem.eql(u8, section_name, "__cstring"))
                    {
                        payload_end = @max(payload_end, file_offset + size);
                    }
                }
                section_offset += section_size;
            }
        } else if (command == main_command) {
            if (command_size < 24) return error.InvalidRuntimeImage;
            entry_file_offset = @intCast(read64(command_offset + 8));
        }
        command_offset += command_size;
    }

    const start = text_offset orelse return error.InvalidRuntimeImage;
    const entry = entry_file_offset orelse return error.InvalidRuntimeImage;
    if (payload_end <= start or entry < start or entry >= payload_end) return error.InvalidRuntimeImage;
    return .{
        .bytes = object_bytes[start..payload_end],
        .text_size = text_size,
        .page_offset = @intCast(text_address % page_size),
        .entry_offset = entry - start,
    };
}

pub fn linuxPayload(allocator: std.mem.Allocator) ElfRuntime.Error!ElfRuntime.Payload {
    return ElfRuntime.payload(allocator, linux_object_bytes);
}

fn read32(offset: usize) u32 {
    return std.mem.readInt(u32, object_bytes[offset..][0..4], .little);
}

fn read64(offset: usize) u64 {
    return std.mem.readInt(u64, object_bytes[offset..][0..8], .little);
}

fn name(offset: usize) []const u8 {
    const bytes = object_bytes[offset..][0..16];
    return bytes[0 .. std.mem.indexOfScalar(u8, bytes, 0) orelse bytes.len];
}

test "bundled float formatter is an ARM64 Mach-O image" {
    try std.testing.expect(object_bytes.len > 4);
    try std.testing.expectEqual(@as(u32, 0xfeedfacf), std.mem.readInt(u32, object_bytes[0..4], .little));
    const runtime = try payload();
    try std.testing.expect(runtime.bytes.len > 4096);
    try std.testing.expect(runtime.entry_offset < runtime.bytes.len);
    try std.testing.expectEqual(@as(u12, 0), runtime.page_offset % 4);
}

test "bundled Linux ARM64 float formatter is an AArch64 ELF image" {
    var runtime = try linuxPayload(std.testing.allocator);
    defer runtime.deinit(std.testing.allocator);
    try std.testing.expectEqualStrings("\x7fELF", linux_object_bytes[0..4]);
    try std.testing.expect(runtime.entry_offset < runtime.bytes.len);
}
