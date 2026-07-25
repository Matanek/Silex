const std = @import("std");
const macho = std.macho;

const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;

const code_directory_size: usize = 88;
const super_blob_size: usize = 12;
const blob_index_size: usize = 8;
const hash_size: usize = 32;
const page_shift: u8 = 14;
const page_size: usize = 1 << page_shift;
const identifier = "silex\x00";

pub fn size(code_limit: usize) usize {
    const slots = std.math.divCeil(usize, code_limit, page_size) catch unreachable;
    const directory_size = code_directory_size + identifier.len + slots * hash_size;
    return std.mem.alignForward(usize, super_blob_size + blob_index_size + directory_size, @alignOf(u64));
}

pub fn emit(
    allocator: Allocator,
    signed_bytes: []const u8,
    executable_limit: u64,
) Allocator.Error![]u8 {
    const slots = std.math.divCeil(usize, signed_bytes.len, page_size) catch unreachable;
    const hash_offset = code_directory_size + identifier.len;
    const directory_size = hash_offset + slots * hash_size;
    const blob_size = super_blob_size + blob_index_size + directory_size;

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, size(signed_bytes.len));

    try appendInt(allocator, &result, u32, macho.CSMAGIC_EMBEDDED_SIGNATURE);
    try appendInt(allocator, &result, u32, @intCast(blob_size));
    try appendInt(allocator, &result, u32, 1);
    try appendInt(allocator, &result, u32, macho.CSSLOT_CODEDIRECTORY);
    try appendInt(allocator, &result, u32, super_blob_size + blob_index_size);

    try appendInt(allocator, &result, u32, macho.CSMAGIC_CODEDIRECTORY);
    try appendInt(allocator, &result, u32, @intCast(directory_size));
    try appendInt(allocator, &result, u32, macho.CS_SUPPORTSEXECSEG);
    try appendInt(allocator, &result, u32, macho.CS_ADHOC | macho.CS_LINKER_SIGNED);
    try appendInt(allocator, &result, u32, @intCast(hash_offset));
    try appendInt(allocator, &result, u32, code_directory_size);
    try appendInt(allocator, &result, u32, 0);
    try appendInt(allocator, &result, u32, @intCast(slots));
    try appendInt(allocator, &result, u32, @intCast(signed_bytes.len));
    try result.append(allocator, hash_size);
    try result.append(allocator, macho.CS_HASHTYPE_SHA256);
    try result.append(allocator, 0);
    try result.append(allocator, page_shift);
    try appendInt(allocator, &result, u32, 0);
    try appendInt(allocator, &result, u32, 0);
    try appendInt(allocator, &result, u32, 0);
    try appendInt(allocator, &result, u32, 0);
    try appendInt(allocator, &result, u64, 0);
    try appendInt(allocator, &result, u64, 0);
    try appendInt(allocator, &result, u64, executable_limit);
    try appendInt(allocator, &result, u64, macho.CS_EXECSEG_MAIN_BINARY);
    try result.appendSlice(allocator, identifier);

    var offset: usize = 0;
    while (offset < signed_bytes.len) : (offset += page_size) {
        const end = @min(offset + page_size, signed_bytes.len);
        var digest: [hash_size]u8 = undefined;
        Sha256.hash(signed_bytes[offset..end], &digest, .{});
        try result.appendSlice(allocator, &digest);
    }

    try result.appendNTimes(allocator, 0, size(signed_bytes.len) - result.items.len);
    return result.toOwnedSlice(allocator);
}

fn appendInt(
    allocator: Allocator,
    result: *std.ArrayList(u8),
    comptime T: type,
    value: T,
) Allocator.Error!void {
    var bytes: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &bytes, value, .big);
    try result.appendSlice(allocator, &bytes);
}

test "emit an aligned ad-hoc SHA-256 code signature" {
    const signed_bytes = [_]u8{0xa5} ** (page_size + 1);
    const signature = try emit(std.testing.allocator, &signed_bytes, signed_bytes.len);
    defer std.testing.allocator.free(signature);

    try std.testing.expectEqual(@as(usize, 0), signature.len % @alignOf(u64));
    try std.testing.expectEqual(macho.CSMAGIC_EMBEDDED_SIGNATURE, std.mem.readInt(u32, signature[0..4], .big));
    try std.testing.expectEqual(@as(u32, 2), std.mem.readInt(u32, signature[48..52], .big));
}
