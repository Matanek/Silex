const std = @import("std");

const Allocator = std.mem.Allocator;

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
