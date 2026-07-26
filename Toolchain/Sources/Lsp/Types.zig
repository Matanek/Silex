const std = @import("std");

pub const protocol_version = "2.0";
pub const max_message_size = 16 * 1024 * 1024;

pub const Document = struct {
    uri: []const u8,
    text: []const u8,
    version: i64,
};

pub const Position = struct {
    line: usize,
    character: usize,
};

pub const Range = struct {
    start: Position,
    end: Position,
};

pub const PositionEncoding = enum {
    utf8,
    utf16,
    utf32,

    pub fn protocolName(self: PositionEncoding) []const u8 {
        return switch (self) {
            .utf8 => "utf-8",
            .utf16 => "utf-16",
            .utf32 => "utf-32",
        };
    }
};

pub const Diagnostic = struct {
    range: Range,
    severity: u8 = 1,
    source: []const u8 = "silex",
    message: []const u8,
};

pub const CompletionItem = struct {
    label: []const u8,
    kind: u8,
    detail: []const u8,
};

pub const CompletionOptions = struct {
    resolveProvider: bool = false,
};

pub const Request = struct {
    jsonrpc: []const u8,
    id: ?std.json.Value = null,
    method: []const u8,
    params: ?std.json.Value = null,
};
