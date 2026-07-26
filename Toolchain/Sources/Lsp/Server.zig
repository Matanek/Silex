const std = @import("std");
const Completion = @import("Completion.zig");
const Diagnostics = @import("Diagnostics.zig");
const Protocol = @import("Protocol.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Server = struct {
    allocator: Allocator,
    io: Io,
    documents: std.ArrayList(Types.Document) = .empty,
    position_encoding: Types.PositionEncoding = .utf16,
    exit_requested: bool = false,

    pub fn init(allocator: Allocator, io: Io) Server {
        return .{ .allocator = allocator, .io = io };
    }

    pub fn deinit(self: *Server) void {
        for (self.documents.items) |document| {
            self.allocator.free(document.uri);
            self.allocator.free(document.text);
        }
        self.documents.deinit(self.allocator);
    }

    pub fn run(self: *Server) !void {
        var input_buffer: [32 * 1024]u8 = undefined;
        var reader = Io.File.stdin().readerStreaming(self.io, &input_buffer);
        while (!self.exit_requested) {
            var arena = std.heap.ArenaAllocator.init(self.allocator);
            defer arena.deinit();
            const allocator = arena.allocator();
            const body = try Protocol.readMessage(allocator, &reader.interface) orelse return;
            const response = try self.handleBody(allocator, body) orelse continue;
            const framed = try Protocol.frameMessage(allocator, response);
            try Io.File.stdout().writeStreamingAll(self.io, framed);
        }
    }

    pub fn handleBody(self: *Server, allocator: Allocator, body: []const u8) !?[]const u8 {
        const request = std.json.parseFromSliceLeaky(Types.Request, allocator, body, .{
            .ignore_unknown_fields = true,
        }) catch return null;
        if (!std.mem.eql(u8, request.jsonrpc, Types.protocol_version)) return null;
        return self.handle(allocator, request);
    }

    fn handle(self: *Server, allocator: Allocator, request: Types.Request) !?[]const u8 {
        if (std.mem.eql(u8, request.method, "initialize")) {
            self.position_encoding = Protocol.negotiatedPositionEncoding(request.params);
            const id = request.id orelse return null;
            return try self.reply(allocator, id, .{
                .capabilities = .{
                    .positionEncoding = self.position_encoding.protocolName(),
                    .textDocumentSync = .{
                        .openClose = true,
                        .change = @as(u8, 1),
                    },
                    .completionProvider = Types.CompletionOptions{},
                },
                .serverInfo = .{ .name = "Silex" },
            });
        }

        if (std.mem.eql(u8, request.method, "initialized")) return null;
        if (std.mem.eql(u8, request.method, "shutdown")) {
            const id = request.id orelse return null;
            return try self.reply(allocator, id, @as(?u8, null));
        }
        if (std.mem.eql(u8, request.method, "exit")) {
            self.exit_requested = true;
            return null;
        }

        if (std.mem.eql(u8, request.method, "textDocument/didOpen")) {
            const params = request.params orelse return null;
            const document = Protocol.documentFromOpen(params) orelse return null;
            try self.setDocument(document);
            return try self.diagnosticsNotification(allocator, document.uri);
        }
        if (std.mem.eql(u8, request.method, "textDocument/didChange")) {
            const params = request.params orelse return null;
            const document = Protocol.documentFromChange(params) orelse return null;
            try self.setDocument(document);
            return try self.diagnosticsNotification(allocator, document.uri);
        }
        if (std.mem.eql(u8, request.method, "textDocument/didClose")) {
            const params = request.params orelse return null;
            const uri = Protocol.textDocumentUri(params) orelse return null;
            const response = try self.notification(allocator, "textDocument/publishDiagnostics", .{
                .uri = uri,
                .diagnostics = &[_]Types.Diagnostic{},
            });
            self.removeDocument(uri);
            return response;
        }
        if (std.mem.eql(u8, request.method, "textDocument/completion")) {
            const id = request.id orelse return null;
            const params = request.params orelse return try self.replyInvalidParams(allocator, id, "missing completion parameters");
            const uri = Protocol.textDocumentUri(params) orelse return try self.replyInvalidParams(allocator, id, "missing text document URI");
            const position = Protocol.requestPosition(params) orelse return try self.replyInvalidParams(allocator, id, "missing completion position");
            const source = self.documentText(uri) orelse return try self.reply(allocator, id, .{
                .isIncomplete = false,
                .items = &[_]Types.CompletionItem{},
            });
            const cursor = Protocol.byteOffsetAtPosition(source, position, self.position_encoding) orelse {
                return try self.replyInvalidParams(allocator, id, "invalid completion position");
            };
            const items = try Completion.itemsAt(allocator, source, cursor);
            return try self.reply(allocator, id, .{ .isIncomplete = false, .items = items });
        }

        if (request.id) |id| return try self.errorReply(allocator, id, -32601, "method not found");
        return null;
    }

    fn diagnosticsNotification(self: *Server, allocator: Allocator, uri: []const u8) ![]const u8 {
        const source = self.documentText(uri).?;
        const diagnostics = try Diagnostics.analyze(allocator, source, self.position_encoding);
        return self.notification(allocator, "textDocument/publishDiagnostics", .{
            .uri = uri,
            .diagnostics = diagnostics,
        });
    }

    fn reply(self: *Server, allocator: Allocator, id: std.json.Value, result: anytype) ![]const u8 {
        _ = self;
        return std.json.Stringify.valueAlloc(allocator, .{
            .jsonrpc = Types.protocol_version,
            .id = id,
            .result = result,
        }, .{ .emit_null_optional_fields = false });
    }

    fn replyInvalidParams(self: *Server, allocator: Allocator, id: std.json.Value, message: []const u8) ![]const u8 {
        return self.errorReply(allocator, id, -32602, message);
    }

    fn errorReply(
        self: *Server,
        allocator: Allocator,
        id: std.json.Value,
        code: i32,
        message: []const u8,
    ) ![]const u8 {
        _ = self;
        return std.json.Stringify.valueAlloc(allocator, .{
            .jsonrpc = Types.protocol_version,
            .id = id,
            .@"error" = .{ .code = code, .message = message },
        }, .{ .emit_null_optional_fields = false });
    }

    fn notification(self: *Server, allocator: Allocator, method: []const u8, params: anytype) ![]const u8 {
        _ = self;
        return std.json.Stringify.valueAlloc(allocator, .{
            .jsonrpc = Types.protocol_version,
            .method = method,
            .params = params,
        }, .{ .emit_null_optional_fields = false });
    }

    fn setDocument(self: *Server, document: Types.Document) !void {
        const text = try self.allocator.dupe(u8, document.text);
        errdefer self.allocator.free(text);
        for (self.documents.items) |*current| {
            if (!std.mem.eql(u8, current.uri, document.uri)) continue;
            self.allocator.free(current.text);
            current.text = text;
            current.version = document.version;
            return;
        }
        const uri = try self.allocator.dupe(u8, document.uri);
        errdefer self.allocator.free(uri);
        try self.documents.append(self.allocator, .{
            .uri = uri,
            .text = text,
            .version = document.version,
        });
    }

    fn removeDocument(self: *Server, uri: []const u8) void {
        for (self.documents.items, 0..) |document, index| {
            if (!std.mem.eql(u8, document.uri, uri)) continue;
            const removed = self.documents.orderedRemove(index);
            self.allocator.free(removed.uri);
            self.allocator.free(removed.text);
            return;
        }
    }

    fn documentText(self: *const Server, uri: []const u8) ?[]const u8 {
        for (self.documents.items) |document| {
            if (std.mem.eql(u8, document.uri, uri)) return document.text;
        }
        return null;
    }
};

test "initialize advertises only the current LSP foundation" {
    var server = Server.init(std.testing.allocator, undefined);
    defer server.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const response = (try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{"general":{"positionEncodings":["utf-8","utf-16"]}}}}
    )).?;
    try std.testing.expect(std.mem.indexOf(u8, response, "\"positionEncoding\":\"utf-8\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"completionProvider\":{\"resolveProvider\":false}") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "hoverProvider") == null);
}

test "document changes publish and clear current frontend diagnostics" {
    var server = Server.init(std.testing.allocator, undefined);
    defer server.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const invalid = (try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///Main.sx","version":1,"text":"func main() { let value:int = }"}}}
    )).?;
    try std.testing.expect(std.mem.indexOf(u8, invalid, "expected expression") != null);
    const valid = (try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","method":"textDocument/didChange","params":{"textDocument":{"uri":"file:///Main.sx","version":2},"contentChanges":[{"text":"func main() { let value:int = 42 }"}]}}
    )).?;
    try std.testing.expect(std.mem.indexOf(u8, valid, "\"diagnostics\":[]") != null);
}

test "completion exposes an interpolation binding without historical types" {
    var server = Server.init(std.testing.allocator, undefined);
    defer server.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///Main.sx","version":1,"text":"func main() { let value:int = 42 print(\"$(value)\") }"}}}
    );
    const response = (try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","id":2,"method":"textDocument/completion","params":{"textDocument":{"uri":"file:///Main.sx"},"position":{"line":0,"character":49}}}
    )).?;
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"value\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"class\"") == null);
}
