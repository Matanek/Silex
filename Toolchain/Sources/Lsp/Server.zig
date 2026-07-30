const std = @import("std");
const Completion = @import("Completion.zig");
const Diagnostics = @import("Diagnostics.zig");
const DocumentColors = @import("DocumentColors.zig");
const Protocol = @import("Protocol.zig");
const Types = @import("Types.zig");
const Workspace = @import("Workspace.zig");
const TargetModule = @import("../Target.zig");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const Server = struct {
    allocator: Allocator,
    io: Io,
    global_packages_root: ?[]const u8 = null,
    target: TargetModule.Target,
    documents: std.ArrayList(Types.Document) = .empty,
    workspace_root_uri: ?[]const u8 = null,
    position_encoding: Types.PositionEncoding = .utf16,
    exit_requested: bool = false,

    pub fn init(allocator: Allocator, io: Io) Server {
        return .{ .allocator = allocator, .io = io, .target = TargetModule.Target.host() orelse .macos_arm64 };
    }

    pub fn initWithPackages(allocator: Allocator, io: Io, global_packages_root: ?[]const u8) Server {
        return .{
            .allocator = allocator,
            .io = io,
            .global_packages_root = global_packages_root,
            .target = TargetModule.Target.host() orelse .macos_arm64,
        };
    }

    pub fn deinit(self: *Server) void {
        for (self.documents.items) |document| {
            self.allocator.free(document.uri);
            self.allocator.free(document.text);
        }
        self.documents.deinit(self.allocator);
        if (self.workspace_root_uri) |uri| self.allocator.free(uri);
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
            if (Protocol.workspaceRootUri(request.params)) |uri| {
                if (self.workspace_root_uri) |previous| self.allocator.free(previous);
                self.workspace_root_uri = try self.allocator.dupe(u8, uri);
            }
            const id = request.id orelse return null;
            return try self.reply(allocator, id, .{
                .capabilities = .{
                    .positionEncoding = self.position_encoding.protocolName(),
                    .textDocumentSync = .{
                        .openClose = true,
                        .change = @as(u8, 1),
                    },
                    .completionProvider = Types.CompletionOptions{},
                    .colorProvider = true,
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
            const trigger_kind = Protocol.completionTriggerKind(params);
            const needs_workspace = needsWorkspaceCompletion(source, cursor);
            if (needs_workspace) {
                const project_items = Workspace.itemsAtForTarget(
                    allocator,
                    self.io,
                    self.global_packages_root,
                    self.target,
                    self.workspace_root_uri,
                    uri,
                    self.documents.items,
                    source,
                    cursor,
                ) catch null;
                if (project_items) |items| {
                    return try self.reply(allocator, id, .{ .isIncomplete = false, .items = items });
                }
            }
            const items = try Completion.itemsAt(allocator, source, cursor, trigger_kind);
            if (needs_workspace) {
                const imported = Workspace.scopeItemsAtForTarget(
                    allocator,
                    self.io,
                    self.global_packages_root,
                    self.target,
                    self.workspace_root_uri,
                    uri,
                    self.documents.items,
                    source,
                    cursor,
                ) catch &.{};
                const merged = try mergeCompletionItems(allocator, items, imported);
                return try self.reply(allocator, id, .{ .isIncomplete = false, .items = merged });
            }
            return try self.reply(allocator, id, .{ .isIncomplete = false, .items = items });
        }
        if (std.mem.eql(u8, request.method, "textDocument/documentColor")) {
            const id = request.id orelse return null;
            const params = request.params orelse return try self.replyInvalidParams(allocator, id, "missing document color parameters");
            const uri = Protocol.textDocumentUri(params) orelse return try self.replyInvalidParams(allocator, id, "missing text document URI");
            const source = self.documentText(uri) orelse return try self.reply(allocator, id, &[_]Types.ColorInformation{});
            const colors = try DocumentColors.inSource(allocator, source, self.position_encoding);
            return try self.reply(allocator, id, colors);
        }

        if (request.id) |id| return try self.errorReply(allocator, id, -32601, "method not found");
        return null;
    }

    fn diagnosticsNotification(self: *Server, allocator: Allocator, uri: []const u8) ![]const u8 {
        const source = self.documentText(uri).?;
        const has_project_context = Workspace.hasContextualReferenceForTarget(
            allocator,
            self.io,
            self.global_packages_root,
            self.target,
            self.workspace_root_uri,
            uri,
            source,
        ) catch false;
        const diagnostics = try Diagnostics.analyze(
            allocator,
            source,
            self.position_encoding,
            has_project_context,
        );
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

fn mergeCompletionItems(
    allocator: Allocator,
    local: []const Types.CompletionItem,
    imported: []const Types.CompletionItem,
) ![]const Types.CompletionItem {
    var result: std.ArrayList(Types.CompletionItem) = .empty;
    try result.appendSlice(allocator, local);
    for (imported) |candidate| {
        var duplicate = false;
        for (result.items) |item| {
            if (std.mem.eql(u8, item.label, candidate.label) and std.mem.eql(u8, item.detail, candidate.detail)) {
                duplicate = true;
                break;
            }
        }
        if (!duplicate) try result.append(allocator, candidate);
    }
    std.mem.sort(Types.CompletionItem, result.items, {}, completionItemLessThan);
    return result.toOwnedSlice(allocator);
}

fn completionItemLessThan(_: void, left: Types.CompletionItem, right: Types.CompletionItem) bool {
    const left_sort = left.sortText orelse "999";
    const right_sort = right.sortText orelse "999";
    const order = std.mem.order(u8, left_sort, right_sort);
    if (order != .eq) return order == .lt;
    return std.mem.lessThan(u8, left.label, right.label);
}

fn needsWorkspaceCompletion(source: []const u8, cursor: usize) bool {
    if (std.mem.indexOf(u8, source, "use ") != null) return true;
    if (cursor > source.len) return false;
    var prefix_start = cursor;
    while (prefix_start != 0 and
        (std.ascii.isAlphanumeric(source[prefix_start - 1]) or source[prefix_start - 1] == '_'))
    {
        prefix_start -= 1;
    }
    const prefix = source[prefix_start..cursor];
    if (prefix.len != 0 and
        (std.mem.startsWith(u8, "Platform", prefix) or std.mem.startsWith(u8, "Target", prefix)))
    {
        return true;
    }
    const before = source[0..prefix_start];
    return std.mem.endsWith(u8, before, "Platform.") or std.mem.endsWith(u8, before, "Target.");
}

test "contextual qualifiers request workspace completion without an import" {
    try std.testing.expect(needsWorkspaceCompletion("func seed() { Pla }", 17));
    try std.testing.expect(needsWorkspaceCompletion("func seed() { Platform. }", 23));
    try std.testing.expect(needsWorkspaceCompletion("func seed() { Target. }", 21));
    try std.testing.expect(!needsWorkspaceCompletion("func seed() { local }", 19));
}

test "initialize advertises completion and document colors" {
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const response = (try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"capabilities":{"general":{"positionEncodings":["utf-8","utf-16"]}}}}
    )).?;
    try std.testing.expect(std.mem.indexOf(u8, response, "\"positionEncoding\":\"utf-8\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"completionProvider\":{\"resolveProvider\":false,\"triggerCharacters\":[\".\"]}") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"colorProvider\":true") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "hoverProvider") == null);
}

test "document colors expose literal and named GFX colors" {
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///Main.sx","version":1,"text":"let warm = Color.bytes(255, 32, 86)\nlet cool = Color.blue_500()"}}}
    );
    const response = (try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","id":2,"method":"textDocument/documentColor","params":{"textDocument":{"uri":"file:///Main.sx"}}}
    )).?;
    try std.testing.expect(std.mem.indexOf(u8, response, "\"red\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"green\":0.12549019607843137") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"line\":1") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"id\":2") != null);
}

test "document changes publish and clear current frontend diagnostics" {
    var server = Server.init(std.testing.allocator, std.testing.io);
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
    var server = Server.init(std.testing.allocator, std.testing.io);
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
    try std.testing.expect(std.mem.indexOf(u8, response, "\"sortText\":") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"filterText\":\"value\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"insertText\":\"value\"") != null);
}

test "member completion never leaks the global language catalogue" {
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    _ = try server.handleBody(arena.allocator(),
        \\{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///Main.sx","version":1,"text":"struct Vec {\nvar x:float\nfunc to_str() str { return \"vec\" }\n}\nfunc main() {\nlet pos = Vec()\npos.\nprint(pos.to_str())\n}"}}}
    );
    const byte_cursor = "pos.".len;
    const response = (try server.handleBody(arena.allocator(), try std.fmt.allocPrint(
        arena.allocator(),
        "{{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"textDocument/completion\",\"params\":{{\"textDocument\":{{\"uri\":\"file:///Main.sx\"}},\"position\":{{\"line\":6,\"character\":{d}}},\"context\":{{\"triggerKind\":2,\"triggerCharacter\":\".\"}}}}}}",
        .{byte_cursor},
    ))).?;
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"to_str\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"x\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"true\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"float\"") == null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"if\"") == null);
}

test "project completion exposes module children before accessible declarations" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Module1\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Module1.sx",
        .data = "func inside() int { return 1 }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Module1.SubModule.Foo.sx",
        .data = "func value() int { return 2 }",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});

    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    server.workspace_root_uri = try std.testing.allocator.dupe(u8, root_uri);
    const source = "use Module1.";
    try server.setDocument(.{ .uri = main_uri, .text = source, .version = 1 });
    const request = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"textDocument/completion\",\"params\":{{\"textDocument\":{{\"uri\":\"{s}\"}},\"position\":{{\"line\":0,\"character\":{d}}},\"context\":{{\"triggerKind\":2,\"triggerCharacter\":\".\"}}}}}}",
        .{ main_uri, source.len },
    );
    const response = (try server.handleBody(allocator, request)).?;
    const child = std.mem.indexOf(u8, response, "\"label\":\"SubModule\"") orelse return error.TestUnexpectedResult;
    const declaration = std.mem.indexOf(u8, response, "\"label\":\"inside\"") orelse return error.TestUnexpectedResult;
    try std.testing.expect(child < declaration);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"if\"") == null);
}

test "inheritance completion merges local imported types and module aliases" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Threading.sx",
        .data = "public protocol Task { func run() }",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    const source =
        \\use Threading
        \\use Threading.Task
        \\protocol Local { func run() }
        \\struct MyTask :
    ;

    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    server.workspace_root_uri = try std.testing.allocator.dupe(u8, root_uri);
    try server.setDocument(.{ .uri = main_uri, .text = source, .version = 1 });
    const request = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"id\":8,\"method\":\"textDocument/completion\",\"params\":{{\"textDocument\":{{\"uri\":\"{s}\"}},\"position\":{{\"line\":3,\"character\":{d}}}}}}}",
        .{ main_uri, "struct MyTask :".len },
    );
    const response = (try server.handleBody(allocator, request)).?;
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"Local\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"Task\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"Threading\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"return\"") == null);
}

test "use completion is strictly limited to accessible modules and packages" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Sandbox/Math");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Main.sx",
        .data = "func main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Sandbox/Math/Vec3.sx",
        .data = "public struct Vec3 {}",
    });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Sandbox", "Main.sx" });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});

    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    server.workspace_root_uri = try std.testing.allocator.dupe(u8, root_uri);

    for ([_][]const u8{ "use ", "use M" }, 0..) |source, index| {
        try server.setDocument(.{ .uri = main_uri, .text = source, .version = @intCast(index + 1) });
        const request = try std.fmt.allocPrint(
            allocator,
            "{{\"jsonrpc\":\"2.0\",\"id\":{d},\"method\":\"textDocument/completion\",\"params\":{{\"textDocument\":{{\"uri\":\"{s}\"}},\"position\":{{\"line\":0,\"character\":{d}}}}}}}",
            .{ index + 10, main_uri, source.len },
        );
        const response = (try server.handleBody(allocator, request)).?;
        try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"Math\"") != null);
        try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"main\"") == null);
        try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"match\"") == null);
        try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"move\"") == null);
    }

    const qualified_source = "use Math\nfunc main() {\n    var value = Math.\n}";
    try server.setDocument(.{ .uri = main_uri, .text = qualified_source, .version = 3 });
    const request = try std.fmt.allocPrint(
        allocator,
        "{{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"textDocument/completion\",\"params\":{{\"textDocument\":{{\"uri\":\"{s}\"}},\"position\":{{\"line\":2,\"character\":{d}}},\"context\":{{\"triggerKind\":2,\"triggerCharacter\":\".\"}}}}}}",
        .{ main_uri, "    var value = Math.".len },
    );
    const response = (try server.handleBody(allocator, request)).?;
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"Vec3\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, response, "\"label\":\"if\"") == null);
}
