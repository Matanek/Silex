const std = @import("std");
const Source = @import("../Source.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub fn readMessage(allocator: Allocator, reader: *Io.Reader) !?[]const u8 {
    var content_length: ?usize = null;
    while (true) {
        const line = try reader.takeDelimiter('\n') orelse return null;
        const trimmed = std.mem.trimEnd(u8, line, "\r");
        if (trimmed.len == 0) break;
        const separator = std.mem.indexOfScalar(u8, trimmed, ':') orelse continue;
        const name = std.mem.trim(u8, trimmed[0..separator], " \t");
        const value = std.mem.trim(u8, trimmed[separator + 1 ..], " \t");
        if (std.ascii.eqlIgnoreCase(name, "Content-Length")) {
            content_length = std.fmt.parseInt(usize, value, 10) catch return error.InvalidRequest;
        }
    }
    const length = content_length orelse return error.InvalidRequest;
    if (length > Types.max_message_size) return error.MessageTooLarge;
    return try reader.readAlloc(allocator, length);
}

pub fn frameMessage(allocator: Allocator, body: []const u8) ![]const u8 {
    if (body.len > Types.max_message_size) return error.MessageTooLarge;
    return std.fmt.allocPrint(allocator, "Content-Length: {d}\r\n\r\n{s}", .{ body.len, body });
}

pub fn objectMember(value: std.json.Value, name: []const u8) ?std.json.Value {
    if (value != .object) return null;
    return value.object.get(name);
}

pub fn stringMember(value: std.json.Value, name: []const u8) ?[]const u8 {
    const member = objectMember(value, name) orelse return null;
    return switch (member) {
        .string => |string| string,
        else => null,
    };
}

pub fn integerMember(value: std.json.Value, name: []const u8) ?i64 {
    const member = objectMember(value, name) orelse return null;
    return switch (member) {
        .integer => |integer| integer,
        else => null,
    };
}

pub fn unsignedMember(value: std.json.Value, name: []const u8) ?usize {
    const integer = integerMember(value, name) orelse return null;
    if (integer < 0) return null;
    return std.math.cast(usize, integer);
}

pub fn documentFromOpen(params: std.json.Value) ?Types.Document {
    const text_document = objectMember(params, "textDocument") orelse return null;
    return .{
        .uri = stringMember(text_document, "uri") orelse return null,
        .text = stringMember(text_document, "text") orelse return null,
        .version = integerMember(text_document, "version") orelse 0,
    };
}

pub fn documentFromChange(params: std.json.Value) ?Types.Document {
    const text_document = objectMember(params, "textDocument") orelse return null;
    const changes = objectMember(params, "contentChanges") orelse return null;
    if (changes != .array or changes.array.items.len == 0) return null;
    const latest = changes.array.items[changes.array.items.len - 1];
    return .{
        .uri = stringMember(text_document, "uri") orelse return null,
        .text = stringMember(latest, "text") orelse return null,
        .version = integerMember(text_document, "version") orelse 0,
    };
}

pub fn textDocumentUri(params: std.json.Value) ?[]const u8 {
    const text_document = objectMember(params, "textDocument") orelse return null;
    return stringMember(text_document, "uri");
}

pub fn workspaceRootUri(params: ?std.json.Value) ?[]const u8 {
    const value = params orelse return null;
    return stringMember(value, "rootUri");
}

pub fn requestPosition(params: std.json.Value) ?Types.Position {
    const position = objectMember(params, "position") orelse return null;
    return .{
        .line = unsignedMember(position, "line") orelse return null,
        .character = unsignedMember(position, "character") orelse return null,
    };
}

pub fn completionTriggerKind(params: std.json.Value) Types.CompletionTriggerKind {
    const context = objectMember(params, "context") orelse return .invoked;
    const raw = integerMember(context, "triggerKind") orelse return .invoked;
    return switch (raw) {
        2 => .trigger_character,
        3 => .trigger_for_incomplete,
        else => .invoked,
    };
}

pub fn completionTriggerCharacter(params: std.json.Value) ?[]const u8 {
    const context = objectMember(params, "context") orelse return null;
    return stringMember(context, "triggerCharacter");
}

pub fn negotiatedPositionEncoding(params: ?std.json.Value) Types.PositionEncoding {
    const capabilities = objectMember(params orelse return .utf16, "capabilities") orelse return .utf16;
    const general = objectMember(capabilities, "general") orelse return .utf16;
    const encodings = objectMember(general, "positionEncodings") orelse return .utf16;
    if (encodings != .array) return .utf16;
    for (encodings.array.items) |encoding| {
        if (encoding != .string) continue;
        if (std.mem.eql(u8, encoding.string, "utf-8")) return .utf8;
        if (std.mem.eql(u8, encoding.string, "utf-16")) return .utf16;
        if (std.mem.eql(u8, encoding.string, "utf-32")) return .utf32;
    }
    return .utf16;
}

pub fn byteOffsetAtPosition(
    source: []const u8,
    position: Types.Position,
    encoding: Types.PositionEncoding,
) ?usize {
    var offset: usize = 0;
    var line: usize = 0;
    while (line < position.line) : (line += 1) {
        const newline = std.mem.indexOfScalarPos(u8, source, offset, '\n') orelse return null;
        offset = newline + 1;
    }

    var units: usize = 0;
    while (offset < source.len and source[offset] != '\n' and units < position.character) {
        const sequence_length = utf8SequenceLength(source[offset]);
        if (offset + sequence_length > source.len) return null;
        units += encodedLength(sequence_length, encoding);
        offset += sequence_length;
    }
    return if (units == position.character) offset else null;
}

pub fn positionAtByteOffset(
    source: []const u8,
    requested_offset: usize,
    encoding: Types.PositionEncoding,
) ?Types.Position {
    if (requested_offset > source.len) return null;
    var position: Types.Position = .{ .line = 0, .character = 0 };
    var offset: usize = 0;
    while (offset < requested_offset) {
        if (source[offset] == '\n') {
            position.line += 1;
            position.character = 0;
            offset += 1;
            continue;
        }
        const sequence_length = utf8SequenceLength(source[offset]);
        if (offset + sequence_length > requested_offset) return null;
        position.character += encodedLength(sequence_length, encoding);
        offset += sequence_length;
    }
    return position;
}

pub fn uriFromPath(allocator: Allocator, path: []const u8) ![]const u8 {
    var uri: std.ArrayList(u8) = .empty;
    try uri.appendSlice(allocator, "file://");
    for (path) |character| {
        if (std.ascii.isAlphanumeric(character) or std.mem.indexOfScalar(u8, "-._~/:", character) != null) {
            try uri.append(allocator, character);
        } else {
            const digits = "0123456789ABCDEF";
            try uri.appendSlice(allocator, &.{ '%', digits[character >> 4], digits[character & 0x0f] });
        }
    }
    return uri.toOwnedSlice(allocator);
}

pub fn diagnosticFromSource(
    source: []const u8,
    diagnostic: Source.Diagnostic,
    encoding: Types.PositionEncoding,
) Types.Diagnostic {
    const start_offset = @min(diagnostic.position.offset, source.len);
    const start: Types.Position = positionAtByteOffset(source, start_offset, encoding) orelse .{
        .line = diagnostic.position.line -| 1,
        .character = diagnostic.position.column -| 1,
    };
    const sequence_length = if (start_offset < source.len) utf8SequenceLength(source[start_offset]) else 0;
    const end_offset = @min(source.len, start_offset + sequence_length);
    const end = positionAtByteOffset(source, end_offset, encoding) orelse start;
    return .{
        .range = .{ .start = start, .end = end },
        .message = diagnostic.message,
    };
}

fn encodedLength(sequence_length: usize, encoding: Types.PositionEncoding) usize {
    return switch (encoding) {
        .utf8 => sequence_length,
        .utf16 => if (sequence_length == 4) 2 else 1,
        .utf32 => 1,
    };
}

fn utf8SequenceLength(first_byte: u8) usize {
    if (first_byte & 0x80 == 0) return 1;
    if (first_byte & 0xe0 == 0xc0) return 2;
    if (first_byte & 0xf0 == 0xe0) return 3;
    if (first_byte & 0xf8 == 0xf0) return 4;
    return 1;
}

test "frame a JSON-RPC message with its byte length" {
    const body = "{\"jsonrpc\":\"2.0\"}";
    const framed = try frameMessage(std.testing.allocator, body);
    defer std.testing.allocator.free(framed);
    try std.testing.expectEqualStrings("Content-Length: 17\r\n\r\n{\"jsonrpc\":\"2.0\"}", framed);
}

test "convert Unicode positions according to the negotiated encoding" {
    const source = "é😀x";
    try std.testing.expectEqual(@as(?usize, 6), byteOffsetAtPosition(source, .{ .line = 0, .character = 3 }, .utf16));
    try std.testing.expectEqual(Types.Position{ .line = 0, .character = 6 }, positionAtByteOffset(source, 6, .utf8).?);
    try std.testing.expectEqual(Types.Position{ .line = 0, .character = 2 }, positionAtByteOffset(source, 6, .utf32).?);
}

test "encode source paths as file URIs" {
    const uri = try uriFromPath(std.testing.allocator, "/tmp/Silex Package/Color#Tone.sx");
    defer std.testing.allocator.free(uri);
    try std.testing.expectEqualStrings("file:///tmp/Silex%20Package/Color%23Tone.sx", uri);
}

test "read completion trigger kinds without trusting unknown values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const parsed = try std.json.parseFromSliceLeaky(std.json.Value, arena.allocator(),
        \\{"context":{"triggerKind":2}}
    , .{});
    try std.testing.expectEqual(Types.CompletionTriggerKind.trigger_character, completionTriggerKind(parsed));
    const with_character = try std.json.parseFromSliceLeaky(std.json.Value, arena.allocator(),
        \\{"context":{"triggerKind":2,"triggerCharacter":" "}}
    , .{});
    try std.testing.expectEqualStrings(" ", completionTriggerCharacter(with_character).?);
}
