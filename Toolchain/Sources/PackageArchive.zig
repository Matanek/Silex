const std = @import("std");

const Io = std.Io;
const flate = std.compress.flate;

pub const File = struct {
    path: []const u8,
    bytes: []const u8,
};

const maximum_source_size = 16 * 1024 * 1024;
const maximum_expanded_size = 64 * 1024 * 1024;
const maximum_files = 10_000;

/// Encodes already-copied, validated bytes. No source path is read after this call.
/// The server accepts only USTAR regular files and two terminating zero blocks.
/// Unicode normalization and case collisions belong to snapshot admission,
/// not to this archive-format preflight.
pub fn encode(allocator: std.mem.Allocator, files: []const File) ![]u8 {
    if (files.len == 0 or files.len > maximum_files) return error.SourceLimit;

    var expanded: usize = 0;
    for (files, 0..) |file, index| {
        if (!safeArchivePath(file.path)) return error.InvalidPath;
        var header: std.tar.Writer.Header = .{};
        header.setPath("", file.path) catch return error.InvalidPath;
        for (files[0..index]) |previous| {
            if (std.mem.eql(u8, previous.path, file.path)) return error.DuplicatePath;
        }
        expanded = std.math.add(usize, expanded, file.bytes.len) catch return error.SourceLimit;
        if (expanded > maximum_expanded_size) return error.SourceLimit;
    }

    var tar_output = try Io.Writer.Allocating.initCapacity(allocator, 4096);
    defer tar_output.deinit();
    var tar_writer: std.tar.Writer = .{ .underlying_writer = &tar_output.writer };
    for (files) |file| try tar_writer.writeFileBytes(file.path, file.bytes, .{ .mode = 0o644, .mtime = 0 });
    try tar_writer.finishPedantically();
    const tar_bytes = try tar_output.toOwnedSlice();
    defer allocator.free(tar_bytes);

    var gzip_output = try Io.Writer.Allocating.initCapacity(allocator, 4096);
    defer gzip_output.deinit();
    var scratch: [flate.max_window_len]u8 = undefined;
    var compressor = try flate.Compress.init(&gzip_output.writer, &scratch, .gzip, .default);
    try compressor.writer.writeAll(tar_bytes);
    try compressor.finish();
    const gzip_bytes = try gzip_output.toOwnedSlice();
    errdefer allocator.free(gzip_bytes);
    if (gzip_bytes.len > maximum_source_size) return error.SourceLimit;
    return gzip_bytes;
}

pub fn safeArchivePath(path: []const u8) bool {
    if (path.len == 0 or path.len > 240 or !std.unicode.utf8ValidateSlice(path)) return false;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..")) return false;
        if (part[part.len - 1] == '.' or part[part.len - 1] == ' ') return false;
        if (std.ascii.eqlIgnoreCase(part, ".git") or std.ascii.eqlIgnoreCase(part, ".silex")) return false;
        const stem = part[0 .. std.mem.indexOfScalar(u8, part, '.') orelse part.len];
        if (std.ascii.eqlIgnoreCase(stem, "CON") or std.ascii.eqlIgnoreCase(stem, "PRN") or
            std.ascii.eqlIgnoreCase(stem, "AUX") or std.ascii.eqlIgnoreCase(stem, "NUL")) return false;
        if (stem.len == 4 and (std.ascii.eqlIgnoreCase(stem[0..3], "COM") or
            std.ascii.eqlIgnoreCase(stem[0..3], "LPT")) and stem[3] >= '1' and stem[3] <= '9') return false;
        for (part) |byte| {
            if (byte < 0x20 or byte == 0x7f or std.mem.indexOfScalar(u8, "\\:<>\"|?*", byte) != null) return false;
        }
    }
    return true;
}

test "deterministic source archive contains USTAR files and end markers" {
    const allocator = std.testing.allocator;
    const files: []const File = &.{
        .{ .path = "Package.json", .bytes = "{\"name\":\"LocalDemo\"}\n" },
        .{ .path = "Module/Content.sx", .bytes = "public func answer() int { return 42 }\n" },
    };
    const first = try encode(allocator, files);
    defer allocator.free(first);
    const second = try encode(allocator, files);
    defer allocator.free(second);
    try std.testing.expectEqualSlices(u8, first, second);
    try std.testing.expectEqualSlices(u8, &.{ 0x1f, 0x8b, 0x08 }, first[0..3]);

    var source_reader: Io.Reader = .fixed(first);
    var buffer: [flate.max_window_len]u8 = undefined;
    var decoder: flate.Decompress = .init(&source_reader, .gzip, &buffer);
    var tar = try Io.Writer.Allocating.initCapacity(allocator, 4096);
    defer tar.deinit();
    while (decoder.reader.peekGreedy(1)) |bytes| {
        try tar.writer.writeAll(bytes);
        decoder.reader.toss(bytes.len);
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => return decoder.err orelse err,
    }
    const contents = tar.written();
    try std.testing.expectEqualStrings("Package.json", std.mem.sliceTo(contents[0..100], 0));
    try std.testing.expectEqualStrings("ustar", std.mem.sliceTo(contents[257..263], 0));
    try std.testing.expectEqualStrings(files[0].bytes, contents[512 .. 512 + files[0].bytes.len]);
    const second_header = contents[1024..];
    try std.testing.expectEqualStrings("Module/Content.sx", std.mem.sliceTo(second_header[0..100], 0));
    try std.testing.expectEqualStrings(files[1].bytes, second_header[512 .. 512 + files[1].bytes.len]);
    try std.testing.expectEqualSlices(u8, &([_]u8{0} ** 1024), contents[contents.len - 1024 ..]);
}

test "reject unsafe, duplicate and unrepresentable source paths" {
    const allocator = std.testing.allocator;
    for ([_][]const u8{ "../escape", "a//b", "a\\b", "C:/secret", "file.", "", ".git/config", "Module/.silex/data", "CON.txt", "Assets/lpt9" }) |path| {
        try std.testing.expectError(error.InvalidPath, encode(allocator, &.{.{ .path = path, .bytes = "x" }}));
    }
    try std.testing.expectError(error.DuplicatePath, encode(allocator, &.{
        .{ .path = "Package.json", .bytes = "a" },
        .{ .path = "Package.json", .bytes = "b" },
    }));
    const long_name = "a" ** 101;
    try std.testing.expectError(error.InvalidPath, encode(allocator, &.{.{ .path = long_name, .bytes = "x" }}));
}
