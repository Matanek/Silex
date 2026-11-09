const std = @import("std");

// Requesting a C++ standard runtime also requests Zig's CRT startup. Mixing
// that startup with the standalone UCRT payload defines atexit/TLS twice.
// This is a declared runtime requirement, independent of archive filenames.
pub fn requiresRuntime(libraries: []const []const u8) bool {
    for (libraries) |library| {
        if (std.mem.eql(u8, library, "stdc++") or std.mem.eql(u8, library, "c++")) return true;
    }
    return false;
}

test "explicit C++ runtimes retain their CRT startup" {
    try std.testing.expect(!requiresRuntime(&.{ "ucrtbase", "kernel32" }));
    try std.testing.expect(!requiresRuntime(&.{}));
    try std.testing.expect(requiresRuntime(&.{ "kernel32", "stdc++" }));
    try std.testing.expect(requiresRuntime(&.{ "c++", "kernel32" }));
}

// Inspect the linker's actual requirements, not archive names or compiler
// guesses. Read at most the PE headers, our marker and two table prefixes;
// large executables do not require another complete file read.
pub fn requiresCompatibility(file: std.Io.File, io: std.Io) !bool {
    var dos: [64]u8 = undefined;
    try read(file, io, &dos, 0);
    if (!std.mem.eql(u8, dos[0..2], "MZ")) return error.InvalidStartupImage;
    const pe = integer(u32, &dos, 60);
    var header: [264]u8 = undefined;
    try read(file, io, &header, pe);
    if (!std.mem.eql(u8, header[0..4], "PE\x00\x00") or integer(u16, &header, 4) != 0xaa64 or
        integer(u16, &header, 20) != 240 or integer(u16, &header, 24) != 0x20b)
        return error.InvalidStartupImage;
    const count = integer(u16, &header, 6);
    var storage: [96][40]u8 = undefined;
    if (count > storage.len) return error.InvalidStartupImage;
    const sections = storage[0..count];
    try read(file, io, std.mem.sliceAsBytes(sections), @as(u64, pe) + header.len);
    const base = integer(u64, &header, 48);
    // Dynamic TLS callbacks can require the CRT's primary-thread handshake.
    // Plain TLS data is handled by the loader; callback-bearing providers keep
    // their existing CRT rather than silently losing that handshake.
    const tls_rva = integer(u32, &header, 208);
    if (tls_rva != 0) {
        if (integer(u32, &header, 212) < 40) return error.InvalidStartupImage;
        const address = std.math.add(u64, base, tls_rva) catch return error.InvalidStartupImage;
        var tls: [40]u8 = undefined;
        try read(file, io, &tls, try filePosition(sections, base, address, tls.len));
        const callbacks = integer(u64, &tls, 24);
        if (callbacks != 0) {
            var first: [8]u8 = undefined;
            try read(file, io, &first, try filePosition(sections, base, callbacks, first.len));
            if (integer(u64, &first, 0) != 0) return true;
        }
    }
    for (sections) |section| {
        if (!std.mem.eql(u8, section[0..8], ".sxlink\x00")) continue;
        if (integer(u32, &section, 16) < 32) return error.InvalidStartupImage;
        var marker: [32]u8 = undefined;
        try read(file, io, &marker, integer(u32, &section, 20));
        if (integer(u64, &marker, 16) != integer(u64, &marker, 24)) return true;
        for ([_]usize{ 0, 8 }) |offset| {
            const address = integer(u64, &marker, offset);
            const position = try filePosition(sections, base, address, 16);
            var table: [16]u8 = undefined;
            try read(file, io, &table, position);
            if (integer(u64, &table, 8) != 0) return true;
        }
        return false;
    }
    return error.InvalidStartupImage;
}

fn filePosition(sections: []const [40]u8, base: u64, address: u64, size: u64) !u64 {
    const rva = std.math.sub(u64, address, base) catch return error.InvalidStartupImage;
    for (sections) |section| {
        const start = integer(u32, &section, 12);
        const available = integer(u32, &section, 16);
        if (rva < start or rva - start > available or size > available - (rva - start)) continue;
        return @as(u64, integer(u32, &section, 20)) + rva - start;
    }
    return error.InvalidStartupImage;
}

fn read(file: std.Io.File, io: std.Io, bytes: []u8, position: u64) !void {
    if (try file.readPositionalAll(io, bytes, position) != bytes.len) return error.InvalidStartupImage;
}

fn integer(comptime T: type, bytes: []const u8, offset: usize) T {
    return std.mem.readInt(T, bytes[offset..][0..@sizeOf(T)], .little);
}

test "Windows startup distinguishes actual GNU tables and rejects incomplete images" {
    const io = std.testing.io;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const file = try temporary.dir.createFile(io, "linked.exe", .{ .read = true });
    defer file.close(io);
    var image: [640]u8 = @splat(0);
    @memcpy(image[0..2], "MZ");
    std.mem.writeInt(u32, image[60..64], 64, .little);
    @memcpy(image[64..68], "PE\x00\x00");
    std.mem.writeInt(u16, image[68..70], 0xaa64, .little);
    std.mem.writeInt(u16, image[70..72], 1, .little);
    std.mem.writeInt(u16, image[84..86], 240, .little);
    std.mem.writeInt(u16, image[88..90], 0x20b, .little);
    const base: u64 = 0x140000000;
    std.mem.writeInt(u64, image[112..120], base, .little);
    const section = 328;
    @memcpy(image[section..][0..8], ".sxlink\x00");
    std.mem.writeInt(u32, image[section + 12 ..][0..4], 0x1000, .little);
    std.mem.writeInt(u32, image[section + 16 ..][0..4], 256, .little);
    std.mem.writeInt(u32, image[section + 20 ..][0..4], 384, .little);
    for (0..4) |index| std.mem.writeInt(u64, image[384 + index * 8 ..][0..8], base + 0x1040, .little);
    // Both empty tables have a -1 sentinel followed by zero, as emitted by LLD.
    std.mem.writeInt(u64, image[448..456], std.math.maxInt(u64), .little);
    try file.writePositionalAll(io, &image, 0);
    try std.testing.expect(!try requiresCompatibility(file, io));
    std.mem.writeInt(u32, image[272..276], 0x1080, .little);
    std.mem.writeInt(u32, image[276..280], 40, .little);
    std.mem.writeInt(u64, image[536..544], base + 0x10b0, .little);
    try file.writePositionalAll(io, &image, 0);
    try std.testing.expect(!try requiresCompatibility(file, io));
    std.mem.writeInt(u64, image[560..568], base + 0x1234, .little);
    try file.writePositionalAll(io, &image, 0);
    try std.testing.expect(try requiresCompatibility(file, io));
    std.mem.writeInt(u64, image[560..568], 0, .little);
    // A real GNU constructor or destructor requires the compatibility startup.
    for ([_]usize{ 0, 8 }) |offset| {
        std.mem.writeInt(u64, image[384 + offset ..][0..8], base + 0x1050, .little);
        std.mem.writeInt(u64, image[472..480], base + 0x1234, .little);
        try file.writePositionalAll(io, &image, 0);
        try std.testing.expect(try requiresCompatibility(file, io));
        std.mem.writeInt(u64, image[384 + offset ..][0..8], base + 0x1040, .little);
    }
    std.mem.writeInt(u64, image[408..416], base + 0x1050, .little);
    try file.writePositionalAll(io, &image, 0);
    try std.testing.expect(try requiresCompatibility(file, io));
    // Truncated headers and out-of-image table addresses must not select fast.
    std.mem.writeInt(u64, image[408..416], base + 0x1040, .little);
    std.mem.writeInt(u64, image[384..392], base - 1, .little);
    try file.writePositionalAll(io, &image, 0);
    try std.testing.expectError(error.InvalidStartupImage, requiresCompatibility(file, io));
    try file.setLength(io, 100);
    try std.testing.expectError(error.InvalidStartupImage, requiresCompatibility(file, io));
}
