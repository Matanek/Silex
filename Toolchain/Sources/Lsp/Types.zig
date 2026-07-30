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

pub const Color = struct {
    red: f64,
    green: f64,
    blue: f64,
    alpha: f64,
};

pub const ColorInformation = struct {
    range: Range,
    color: Color,
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
    sortText: ?[]const u8 = null,
    filterText: ?[]const u8 = null,
    insertText: ?[]const u8 = null,
    insertTextFormat: ?u8 = null,
};

pub const CompletionOptions = struct {
    resolveProvider: bool = false,
    triggerCharacters: []const []const u8 = &.{"."},
};

pub const CompletionTriggerKind = enum(u8) {
    invoked = 1,
    trigger_character = 2,
    trigger_for_incomplete = 3,
};

pub const Request = struct {
    jsonrpc: []const u8,
    id: ?std.json.Value = null,
    method: []const u8,
    params: ?std.json.Value = null,
};
