const std = @import("std");

const Allocator = std.mem.Allocator;

pub const BlockLayout = struct {
    content: []const u8,
    indentation: []const u8,
};

pub const BlockDecoder = struct {
    indentation: []const u8,
    at_line_start: bool = true,

    pub fn init(indentation: []const u8) BlockDecoder {
        return .{ .indentation = indentation };
    }

    pub fn decodeChunk(self: *BlockDecoder, allocator: Allocator, source: []const u8) Allocator.Error![]const u8 {
        var normalized: std.ArrayList(u8) = .empty;
        defer normalized.deinit(allocator);
        var index: usize = 0;
        while (index < source.len) {
            if (self.at_line_start) {
                const line_end = lineEnd(source, index);
                const prefix = source[index..line_end];
                if (line_end < source.len and whitespaceOnly(prefix)) {
                    index = line_end;
                } else if (std.mem.startsWith(u8, prefix, self.indentation)) {
                    index += self.indentation.len;
                }
                if (index == source.len) break;
            }

            if (source[index] == '\r' or source[index] == '\n') {
                if (source[index] == '\r' and index + 1 < source.len and source[index + 1] == '\n') index += 1;
                index += 1;
                try normalized.append(allocator, '\n');
                self.at_line_start = true;
                continue;
            }

            try normalized.append(allocator, source[index]);
            index += 1;
            self.at_line_start = false;
        }
        return decode(allocator, normalized.items);
    }

    pub fn expression(self: *BlockDecoder) void {
        self.at_line_start = false;
    }
};

pub fn blockLayout(source: []const u8) BlockLayout {
    var line_start = source.len;
    while (line_start != 0) {
        line_start -= 1;
        if (source[line_start] == '\n' or source[line_start] == '\r') {
            const indentation_start = line_start + 1;
            const content_end = if (source[line_start] == '\n' and line_start != 0 and source[line_start - 1] == '\r')
                line_start - 1
            else
                line_start;
            return .{ .content = source[0..content_end], .indentation = source[indentation_start..] };
        }
    }
    return .{ .content = source[0..0], .indentation = source };
}

pub fn hasValidBlockIndentation(source: []const u8) bool {
    const layout = blockLayout(source);
    if (!whitespaceOnly(layout.indentation)) return false;
    var index: usize = 0;
    while (index < layout.content.len) {
        const end = lineEnd(layout.content, index);
        const line = layout.content[index..end];
        if (!whitespaceOnly(line) and !std.mem.startsWith(u8, line, layout.indentation)) return false;
        if (end == layout.content.len) break;
        index = end + 1;
        if (layout.content[end] == '\r' and index < layout.content.len and layout.content[index] == '\n') index += 1;
    }
    return true;
}

pub fn decodeBlock(allocator: Allocator, source: []const u8) Allocator.Error![]const u8 {
    const layout = blockLayout(source);
    var decoder = BlockDecoder.init(layout.indentation);
    return decoder.decodeChunk(allocator, layout.content);
}

pub fn decode(allocator: Allocator, source: []const u8) Allocator.Error![]const u8 {
    var result: std.ArrayList(u8) = .empty;
    var index: usize = 0;
    while (index < source.len) {
        if (source[index] == '$' and index + 1 < source.len and source[index + 1] == '$') {
            try result.append(allocator, '$');
            index += 2;
            continue;
        }
        if (source[index] != '\\') {
            try result.append(allocator, source[index]);
            index += 1;
            continue;
        }
        index += 1;
        switch (source[index]) {
            '\\' => try result.append(allocator, '\\'),
            '"' => try result.append(allocator, '"'),
            'n' => try result.append(allocator, '\n'),
            'r' => try result.append(allocator, '\r'),
            't' => try result.append(allocator, '\t'),
            '0' => try result.append(allocator, 0),
            'u' => {
                index += 2;
                var scalar: u21 = 0;
                while (source[index] != '}') : (index += 1) {
                    scalar = scalar * 16 + digit(source[index]);
                }
                var bytes: [4]u8 = undefined;
                const length = std.unicode.utf8Encode(scalar, &bytes) catch unreachable;
                try result.appendSlice(allocator, bytes[0..length]);
            },
            else => unreachable,
        }
        index += 1;
    }
    return result.toOwnedSlice(allocator);
}

pub fn appendQuoted(output: *std.ArrayList(u8), allocator: Allocator, value: []const u8) Allocator.Error!void {
    try output.append(allocator, '"');
    for (value) |byte| switch (byte) {
        '\\' => try output.appendSlice(allocator, "\\\\"),
        '"' => try output.appendSlice(allocator, "\\\""),
        '\n' => try output.appendSlice(allocator, "\\n"),
        '\r' => try output.appendSlice(allocator, "\\r"),
        '\t' => try output.appendSlice(allocator, "\\t"),
        0 => try output.appendSlice(allocator, "\\0"),
        0x01...0x08, 0x0b, 0x0c, 0x0e...0x1f, 0x7f => {
            var buffer: [6]u8 = undefined;
            const escaped = std.fmt.bufPrint(&buffer, "\\u{{{x}}}", .{byte}) catch unreachable;
            try output.appendSlice(allocator, escaped);
        },
        else => try output.append(allocator, byte),
    };
    try output.append(allocator, '"');
}

fn digit(byte: u8) u21 {
    return switch (byte) {
        '0'...'9' => byte - '0',
        'a'...'f' => byte - 'a' + 10,
        'A'...'F' => byte - 'A' + 10,
        else => unreachable,
    };
}

fn lineEnd(source: []const u8, start: usize) usize {
    var index = start;
    while (index < source.len and source[index] != '\r' and source[index] != '\n') index += 1;
    return index;
}

fn whitespaceOnly(source: []const u8) bool {
    for (source) |byte| if (byte != ' ' and byte != '\t') return false;
    return true;
}

test "decode UTF-8 and escaped bytes" {
    const value = try decode(std.testing.allocator, "Silex\\n\\u{1f525}\\0");
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualSlices(u8, "Silex\n🔥\x00", value);
}

test "decode every supported escape exactly once" {
    const value = try decode(std.testing.allocator, "\\\\\"\\n\\r\\t\\0\\u{e9}");
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualSlices(u8, "\\\"\n\r\t\x00é", value);
}

test "decode doubled dollars as one literal dollar" {
    const value = try decode(std.testing.allocator, "$$value $$(value)");
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualSlices(u8, "$value $(value)", value);
}

test "decode a block string with structural indentation" {
    const value = try decodeBlock(std.testing.allocator, "    first\n      second\n\n    last\n    ");
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualSlices(u8, "first\n  second\n\nlast", value);
}

test "decode an empty block string" {
    const value = try decodeBlock(std.testing.allocator, "    ");
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualSlices(u8, "", value);
}

test "normalize block string source line endings" {
    const value = try decodeBlock(std.testing.allocator, "    first\r\n    second\r\n    ");
    defer std.testing.allocator.free(value);
    try std.testing.expectEqualSlices(u8, "first\nsecond", value);
}
