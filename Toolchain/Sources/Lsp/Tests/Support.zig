const std = @import("std");
const Completion = @import("../Completion.zig");
const Protocol = @import("../Protocol.zig");
const ServerModule = @import("../Server.zig");
const Types = @import("../Types.zig");

const marker = "<|>";

pub const MarkedSource = struct {
    text: []const u8,
    cursor: usize,
};

pub const ExpectedItem = struct {
    label: []const u8,
    kind: u8,
    detail: []const u8,
    insert_text: []const u8,
    insert_text_format: ?u8 = null,
};

const CompletionResponse = struct {
    result: struct {
        isIncomplete: bool,
        items: []const Types.CompletionItem,
    },
};

pub fn removeMarker(allocator: std.mem.Allocator, source: []const u8) !MarkedSource {
    const cursor = std.mem.indexOf(u8, source, marker) orelse return error.MissingCompletionMarker;
    if (std.mem.indexOf(u8, source[cursor + marker.len ..], marker) != null) {
        return error.MultipleCompletionMarkers;
    }
    const text = try allocator.alloc(u8, source.len - marker.len);
    @memcpy(text[0..cursor], source[0..cursor]);
    @memcpy(text[cursor..], source[cursor + marker.len ..]);
    return .{ .text = text, .cursor = cursor };
}

pub fn complete(
    allocator: std.mem.Allocator,
    source: []const u8,
) ![]const Types.CompletionItem {
    const marked = try removeMarker(allocator, source);
    return Completion.itemsAt(allocator, marked.text, marked.cursor, .invoked);
}

pub fn initializeServer(
    server: *ServerModule.Server,
    allocator: std.mem.Allocator,
    root_uri: []const u8,
) !void {
    const request = try std.json.Stringify.valueAlloc(allocator, .{
        .jsonrpc = Types.protocol_version,
        .id = 1,
        .method = "initialize",
        .params = .{
            .rootUri = root_uri,
            .capabilities = .{},
        },
    }, .{});
    _ = (try server.handleBody(allocator, request)) orelse return error.MissingLspResponse;
}

pub fn openDocument(
    server: *ServerModule.Server,
    allocator: std.mem.Allocator,
    uri: []const u8,
    version: i64,
    source: []const u8,
) !void {
    const request = try std.json.Stringify.valueAlloc(allocator, .{
        .jsonrpc = Types.protocol_version,
        .method = "textDocument/didOpen",
        .params = .{
            .textDocument = .{
                .uri = uri,
                .version = version,
                .text = source,
            },
        },
    }, .{});
    _ = try server.handleBody(allocator, request);
}

pub fn changeDocument(
    server: *ServerModule.Server,
    allocator: std.mem.Allocator,
    uri: []const u8,
    version: i64,
    source: []const u8,
) !void {
    const request = try std.json.Stringify.valueAlloc(allocator, .{
        .jsonrpc = Types.protocol_version,
        .method = "textDocument/didChange",
        .params = .{
            .textDocument = .{ .uri = uri, .version = version },
            .contentChanges = &.{.{ .text = source }},
        },
    }, .{});
    _ = try server.handleBody(allocator, request);
}

pub fn serverCompletion(
    server: *ServerModule.Server,
    allocator: std.mem.Allocator,
    uri: []const u8,
    marked_source: []const u8,
) ![]const Types.CompletionItem {
    const source = try removeMarker(allocator, marked_source);
    try openDocument(server, allocator, uri, 1, source.text);
    return serverCompletionInOpenDocument(server, allocator, uri, source);
}

pub fn serverCompletionInOpenDocument(
    server: *ServerModule.Server,
    allocator: std.mem.Allocator,
    uri: []const u8,
    source: MarkedSource,
) ![]const Types.CompletionItem {
    const position = Protocol.positionAtByteOffset(source.text, source.cursor, .utf16) orelse
        return error.InvalidCompletionPosition;
    const request = try std.json.Stringify.valueAlloc(allocator, .{
        .jsonrpc = Types.protocol_version,
        .id = 2,
        .method = "textDocument/completion",
        .params = .{
            .textDocument = .{ .uri = uri },
            .position = position,
            .context = .{ .triggerKind = 1 },
        },
    }, .{});
    const response = (try server.handleBody(allocator, request)) orelse return error.MissingLspResponse;
    const parsed = try std.json.parseFromSliceLeaky(CompletionResponse, allocator, response, .{
        .ignore_unknown_fields = true,
    });
    try std.testing.expect(!parsed.result.isIncomplete);
    return parsed.result.items;
}

pub fn expectExactLabels(
    expected: []const []const u8,
    actual: []const Types.CompletionItem,
) !void {
    if (expected.len != actual.len) printLabels(actual);
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |expected_label, actual_item| {
        try std.testing.expectEqualStrings(expected_label, actual_item.label);
    }
}

pub fn expectFirst(label: []const u8, items: []const Types.CompletionItem) !void {
    if (items.len == 0) return error.MissingCompletionItem;
    try std.testing.expectEqualStrings(label, items[0].label);
}

pub fn expectPresent(label: []const u8, items: []const Types.CompletionItem) !void {
    _ = itemWithLabel(items, label) orelse {
        printLabels(items);
        return error.MissingCompletionItem;
    };
}

pub fn expectAbsent(label: []const u8, items: []const Types.CompletionItem) !void {
    if (itemWithLabel(items, label) != null) {
        printLabels(items);
        return error.UnexpectedCompletionItem;
    }
}

pub fn expectItem(expected: ExpectedItem, items: []const Types.CompletionItem) !void {
    const actual = itemWithLabel(items, expected.label) orelse {
        printLabels(items);
        return error.MissingCompletionItem;
    };
    try std.testing.expectEqual(expected.kind, actual.kind);
    try std.testing.expectEqualStrings(expected.detail, actual.detail);
    try std.testing.expectEqualStrings(expected.label, actual.filterText.?);
    try std.testing.expectEqualStrings(expected.insert_text, actual.insertText.?);
    try std.testing.expectEqual(expected.insert_text_format, actual.insertTextFormat);
}

pub fn expectNoDuplicates(items: []const Types.CompletionItem) !void {
    for (items, 0..) |item, index| {
        for (items[index + 1 ..]) |other| {
            if (std.mem.eql(u8, item.label, other.label) and
                std.mem.eql(u8, item.detail, other.detail))
            {
                return error.DuplicateCompletionItem;
            }
        }
    }
}

pub fn expectEqualItems(
    expected: []const Types.CompletionItem,
    actual: []const Types.CompletionItem,
) !void {
    try std.testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |left, right| {
        try std.testing.expectEqualStrings(left.label, right.label);
        try std.testing.expectEqual(left.kind, right.kind);
        try std.testing.expectEqualStrings(left.detail, right.detail);
        try std.testing.expectEqualStrings(left.sortText.?, right.sortText.?);
        try std.testing.expectEqualStrings(left.filterText.?, right.filterText.?);
        try std.testing.expectEqualStrings(left.insertText.?, right.insertText.?);
        try std.testing.expectEqual(left.insertTextFormat, right.insertTextFormat);
    }
}

fn itemWithLabel(items: []const Types.CompletionItem, label: []const u8) ?Types.CompletionItem {
    for (items) |item| {
        if (std.mem.eql(u8, item.label, label) or
            (item.filterText != null and std.mem.eql(u8, item.filterText.?, label))) return item;
    }
    return null;
}

fn printLabels(items: []const Types.CompletionItem) void {
    std.debug.print("actual completion labels ({d}):\n", .{items.len});
    for (items) |item| std.debug.print("  {s}\n", .{item.label});
}
