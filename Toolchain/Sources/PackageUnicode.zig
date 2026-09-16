const std = @import("std");
const Data = @import("PackageUnicodeData.zig");

/// Match the registry's Unicode 16 NFC admission without depending on the
/// host operating system or an ICU installation.
pub fn isNfc(allocator: std.mem.Allocator, text: []const u8) !bool {
    const normalized = try nfc(allocator, text);
    defer allocator.free(normalized);
    return std.mem.eql(u8, text, normalized);
}

/// Match PHP `mb_strtolower(..., "UTF-8")`, including multi-scalar mappings
/// and the context-sensitive Greek final sigma used by collision admission.
pub fn lowercase(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    const input = try decode(allocator, text);
    defer allocator.free(input);
    var output: std.ArrayList(u21) = .empty;
    defer output.deinit(allocator);
    for (input, 0..) |scalar, index| {
        if (scalar == 0x03a3 and finalSigma(input, index)) {
            try output.append(allocator, 0x03c2);
        } else if (findKey(Data.lowercase_keys, scalar)) |record| {
            const offset = readU21(Data.lowercase_metadata, record * 5);
            const count = readDigit(Data.lowercase_metadata[record * 5 + 4]);
            for (0..count) |mapped| try output.append(allocator, readU21(Data.lowercase_values, (offset + mapped) * 4));
        } else {
            try output.append(allocator, scalar);
        }
    }
    return encode(allocator, output.items);
}

fn nfc(allocator: std.mem.Allocator, text: []const u8) ![]const u8 {
    const input = try decode(allocator, text);
    defer allocator.free(input);
    var decomposed: std.ArrayList(u21) = .empty;
    defer decomposed.deinit(allocator);
    for (input) |scalar| try appendDecomposed(allocator, &decomposed, scalar);
    const composed = try compose(allocator, decomposed.items);
    defer allocator.free(composed);
    return encode(allocator, composed);
}

fn decode(allocator: std.mem.Allocator, text: []const u8) ![]u21 {
    var result: std.ArrayList(u21) = .empty;
    errdefer result.deinit(allocator);
    var iterator = (try std.unicode.Utf8View.init(text)).iterator();
    while (iterator.nextCodepoint()) |scalar| try result.append(allocator, scalar);
    return result.toOwnedSlice(allocator);
}

fn encode(allocator: std.mem.Allocator, values: []const u21) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    for (values) |scalar| {
        var buffer: [4]u8 = undefined;
        const length = try std.unicode.utf8Encode(scalar, &buffer);
        try result.appendSlice(allocator, buffer[0..length]);
    }
    return result.toOwnedSlice(allocator);
}

fn appendDecomposed(allocator: std.mem.Allocator, output: *std.ArrayList(u21), scalar: u21) !void {
    if (scalar >= 0xac00 and scalar <= 0xd7a3) {
        const offset = scalar - 0xac00;
        try appendOrdered(allocator, output, 0x1100 + offset / 588);
        try appendOrdered(allocator, output, 0x1161 + (offset % 588) / 28);
        const trailing = offset % 28;
        if (trailing != 0) try appendOrdered(allocator, output, 0x11a7 + trailing);
        return;
    }
    if (findKey(Data.decomposition_keys, scalar)) |record| {
        const offset = readU21(Data.decomposition_metadata, record * 5);
        const count = readDigit(Data.decomposition_metadata[record * 5 + 4]);
        for (0..count) |index| try appendDecomposed(allocator, output, readU21(Data.decomposition_values, (offset + index) * 4));
        return;
    }
    try appendOrdered(allocator, output, scalar);
}

fn appendOrdered(allocator: std.mem.Allocator, output: *std.ArrayList(u21), scalar: u21) !void {
    try output.append(allocator, scalar);
    const current = combiningClass(scalar);
    if (current == 0) return;
    var index = output.items.len - 1;
    while (index > 0) : (index -= 1) {
        const previous = combiningClass(output.items[index - 1]);
        if (previous == 0 or previous <= current) return;
        std.mem.swap(u21, &output.items[index - 1], &output.items[index]);
    }
}

fn compose(allocator: std.mem.Allocator, values: []const u21) ![]u21 {
    if (values.len == 0) return allocator.alloc(u21, 0);
    var result: std.ArrayList(u21) = .empty;
    errdefer result.deinit(allocator);
    try result.append(allocator, values[0]);
    var starter_index: usize = 0;
    var starter = values[0];
    var previous_class: u21 = 0;
    for (values[1..]) |scalar| {
        const current_class = combiningClass(scalar);
        const candidate = composite(starter, scalar);
        if (candidate != 0 and (previous_class < current_class or previous_class == 0)) {
            result.items[starter_index] = candidate;
            starter = candidate;
        } else {
            if (current_class == 0) {
                starter_index = result.items.len;
                starter = scalar;
            }
            try result.append(allocator, scalar);
            previous_class = current_class;
        }
    }
    return result.toOwnedSlice(allocator);
}

fn composite(first: u21, second: u21) u21 {
    if (first >= 0x1100 and first <= 0x1112 and second >= 0x1161 and second <= 0x1175) {
        return 0xac00 + ((first - 0x1100) * 21 + (second - 0x1161)) * 28;
    }
    if (first >= 0xac00 and first <= 0xd7a3 and (first - 0xac00) % 28 == 0 and second >= 0x11a8 and second <= 0x11c2) {
        return first + second - 0x11a7;
    }
    const record = findPair(Data.composition_keys, first, second) orelse return 0;
    return readU21(Data.composition_values, record * 4);
}

fn combiningClass(scalar: u21) u21 {
    const record = findKey(Data.combining_keys, scalar) orelse return 0;
    return readU21(Data.combining_values, record * 4);
}

fn finalSigma(values: []const u21, index: usize) bool {
    var before = index;
    var preceded = false;
    while (before > 0) {
        before -= 1;
        const scalar = values[before];
        if (inRanges(Data.case_ignorable_ranges, scalar)) continue;
        preceded = inRanges(Data.cased_ranges, scalar);
        break;
    }
    if (!preceded) return false;
    var after = index + 1;
    while (after < values.len) : (after += 1) {
        const scalar = values[after];
        if (inRanges(Data.case_ignorable_ranges, scalar)) continue;
        return !inRanges(Data.cased_ranges, scalar);
    }
    return true;
}

fn findKey(data: []const u8, scalar: u21) ?usize {
    var first: usize = 0;
    var last = data.len / 4;
    while (first < last) {
        const middle = first + (last - first) / 2;
        if (readU21(data, middle * 4) < scalar) first = middle + 1 else last = middle;
    }
    if (first * 4 < data.len and readU21(data, first * 4) == scalar) return first;
    return null;
}

fn findPair(data: []const u8, first_scalar: u21, second_scalar: u21) ?usize {
    var first: usize = 0;
    var last = data.len / 8;
    while (first < last) {
        const middle = first + (last - first) / 2;
        const left = readU21(data, middle * 8);
        const right = readU21(data, middle * 8 + 4);
        if (left < first_scalar or (left == first_scalar and right < second_scalar)) first = middle + 1 else last = middle;
    }
    if (first * 8 < data.len and readU21(data, first * 8) == first_scalar and readU21(data, first * 8 + 4) == second_scalar) return first;
    return null;
}

fn inRanges(data: []const u8, scalar: u21) bool {
    var first: usize = 0;
    var last = data.len / 8;
    while (first < last) {
        const middle = first + (last - first) / 2;
        if (readU21(data, middle * 8 + 4) < scalar) first = middle + 1 else last = middle;
    }
    return first * 8 < data.len and readU21(data, first * 8) <= scalar;
}

fn readU21(data: []const u8, offset: usize) u21 {
    return @intCast((readDigit(data[offset]) << 18) + (readDigit(data[offset + 1]) << 12) +
        (readDigit(data[offset + 2]) << 6) + readDigit(data[offset + 3]));
}

fn readDigit(byte: u8) usize {
    if (byte >= 'A' and byte <= 'Z') return byte - 'A';
    if (byte >= 'a' and byte <= 'z') return byte - 'a' + 26;
    if (byte >= '0' and byte <= '9') return byte - '0' + 52;
    return if (byte == '+') 62 else 63;
}

test "match registry NFC and Unicode lowercase admission" {
    const allocator = std.testing.allocator;
    try std.testing.expectEqualStrings("16.0.0", Data.version);
    try std.testing.expect(try isNfc(allocator, "Résumé/École.sx"));
    try std.testing.expect(!try isNfc(allocator, "Re\u{301}sume\u{301}/E\u{301}cole.sx"));
    try std.testing.expect(try isNfc(allocator, "한글.sx"));

    const latin = try lowercase(allocator, "Résumé/École.sx");
    defer allocator.free(latin);
    try std.testing.expectEqualStrings("résumé/école.sx", latin);
    const greek = try lowercase(allocator, "ΟΣ/ΟΣΑ/Ο.Σ");
    defer allocator.free(greek);
    try std.testing.expectEqualStrings("ος/οσα/ο.ς", greek);
    const expanding = try lowercase(allocator, "İ/ẞ");
    defer allocator.free(expanding);
    try std.testing.expectEqualStrings("i\u{307}/ß", expanding);
}
