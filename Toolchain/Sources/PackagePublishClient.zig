const std = @import("std");
const Publication = @import("PackagePublication.zig");

const Io = std.Io;

const ObjectStatus = struct {
    sha256: []const u8,
    size: usize,
    offset: usize,
    available: bool,
};

const Status = struct {
    id: []const u8,
    state: []const u8,
    publication_sha256: []const u8,
    objects: []const ObjectStatus,
};

const Response = struct {
    bytes: [262144]u8 = undefined,
    len: usize,
    status: std.http.Status,

    fn body(self: *const Response) []const u8 {
        return self.bytes[0..self.len];
    }
};

pub const Result = struct {
    id: []const u8,
    digest: []const u8,
    already_published: bool,
};

pub const Client = struct {
    allocator: std.mem.Allocator,
    network_allocator: std.mem.Allocator,
    io: Io,
    origin: []const u8,
    token: []const u8,
    diagnostic: ?[]const u8 = null,

    pub fn publish(self: *Client, prepared: Publication.Prepared) !Result {
        self.diagnostic = null;
        var status = try self.statusRequest(.POST, "/v2/publications", prepared.descriptor.json, null);
        try self.validateStatus(status, prepared);
        if (std.mem.eql(u8, status.state, "published")) return result(status, true);
        if (!std.mem.eql(u8, status.state, "receiving")) return self.fail("registry returned an invalid publication state");

        for (status.objects) |object| {
            if (object.available) continue;
            const bytes = objectBytes(prepared, object.sha256) orelse
                return self.fail("registry requested an object absent from the prepared publication");
            if (object.size != bytes.len or object.offset > bytes.len) return self.fail("registry returned invalid object progress");
            var offset = object.offset;
            while (offset < bytes.len) {
                const end = @min(offset + 64 * 1024, bytes.len);
                const path = try std.fmt.allocPrint(self.allocator, "/v2/publications/{s}/objects/{s}", .{ status.id, object.sha256 });
                const reply = try self.request(.PATCH, path, bytes[offset..end], offset);
                try self.expectSuccess(reply);
                const progress = parse(struct { offset: usize }, self.allocator, reply.body()) catch return self.fail("registry returned invalid upload progress");
                if (progress.offset != end) return self.fail("registry acknowledged an unexpected upload offset");
                offset = end;
            }
        }

        const finalize_path = try std.fmt.allocPrint(self.allocator, "/v2/publications/{s}/finalize", .{status.id});
        status = try self.statusRequest(.POST, finalize_path, "", null);
        try self.validateStatus(status, prepared);
        if (!std.mem.eql(u8, status.state, "published")) return self.fail("registry did not publish the complete package");
        return result(status, false);
    }

    fn validateStatus(self: *Client, status: Status, prepared: Publication.Prepared) !void {
        if (status.id.len != 32 or !hex(status.id) or !std.mem.eql(u8, status.publication_sha256, prepared.descriptor.digest)) {
            return self.fail("registry returned a publication that does not match the prepared content");
        }
    }

    fn statusRequest(self: *Client, method: std.http.Method, path: []const u8, payload: ?[]const u8, offset: ?usize) !Status {
        const response = try self.request(method, path, payload, offset);
        try self.expectSuccess(response);
        return parse(Status, self.allocator, response.body()) catch return self.fail("registry returned an invalid publication status");
    }

    fn request(self: *Client, method: std.http.Method, path: []const u8, payload: ?[]const u8, offset: ?usize) !Response {
        const url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.origin, path });
        const authorization = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.token});
        const offset_text = if (offset) |value| try std.fmt.allocPrint(self.allocator, "{d}", .{value}) else "";
        const headers: []const std.http.Header = if (offset != null) &.{
            .{ .name = "Authorization", .value = authorization },
            .{ .name = "Content-Type", .value = "application/octet-stream" },
            .{ .name = "Upload-Offset", .value = offset_text },
        } else &.{
            .{ .name = "Authorization", .value = authorization },
            .{ .name = "Content-Type", .value = "application/json" },
        };
        const Event = union(enum) { response: anyerror!Response, timeout: Io.Cancelable!void };
        var buffer: [2]Event = undefined;
        var select = Io.Select(Event).init(self.io, &buffer);
        defer select.cancelDiscard();
        try select.concurrent(.response, fetch, .{ self, method, url, payload, headers });
        try select.concurrent(.timeout, Io.sleep, .{ self.io, Io.Duration.fromSeconds(30), .boot });
        return switch (try select.await()) {
            .response => |response| response catch return self.fail("cannot contact the package registry"),
            .timeout => self.fail("package registry request timed out"),
        };
    }

    fn fetch(self: *Client, method: std.http.Method, url: []const u8, payload: ?[]const u8, headers: []const std.http.Header) !Response {
        var client: std.http.Client = .{ .allocator = self.network_allocator, .io = self.io };
        defer client.deinit();
        var response: Response = .{ .len = 0, .status = .ok };
        var writer = Io.Writer.fixed(&response.bytes);
        const fetched = try client.fetch(.{
            .location = .{ .url = url },
            .method = method,
            .payload = payload,
            .response_writer = &writer,
            .redirect_behavior = .unhandled,
            .headers = .{ .user_agent = .{ .override = "Silex package publisher" } },
            .extra_headers = headers,
        });
        response.status = fetched.status;
        response.len = writer.end;
        return response;
    }

    fn expectSuccess(self: *Client, response: Response) !void {
        if (response.status == .ok) return;
        const body = parse(struct { @"error": []const u8 = "registry_error", message: []const u8 = "registry rejected the publication", retryable: bool = false }, self.allocator, response.body()) catch {
            return self.fail("registry rejected the publication with an invalid response");
        };
        _ = body.@"error";
        _ = body.retryable;
        if (!safeMessage(body.message)) return self.fail("registry rejected the publication");
        return self.fail(body.message);
    }

    fn fail(self: *Client, message: []const u8) error{InvalidPackagePublication} {
        self.diagnostic = message;
        return error.InvalidPackagePublication;
    }
};

fn objectBytes(prepared: Publication.Prepared, digest: []const u8) ?[]const u8 {
    if (std.mem.eql(u8, digest, prepared.descriptor.source_digest)) return prepared.source;
    for (prepared.artifacts) |artifact| {
        var actual: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(artifact.bytes, &actual, .{});
        const encoded = std.fmt.bytesToHex(actual, .lower);
        if (std.mem.eql(u8, digest, encoded[0..])) return artifact.bytes;
    }
    return null;
}

fn result(status: Status, already_published: bool) Result {
    return .{ .id = status.id, .digest = status.publication_sha256, .already_published = already_published };
}

fn parse(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    const parsed = std.json.parseFromSlice(T, allocator, bytes, .{ .allocate = .alloc_always }) catch return error.InvalidRegistryResponse;
    return parsed.value;
}

fn hex(value: []const u8) bool {
    for (value) |byte| if (!std.ascii.isDigit(byte) and !(byte >= 'a' and byte <= 'f')) return false;
    return true;
}

fn safeMessage(value: []const u8) bool {
    if (value.len == 0 or value.len > 512 or !std.unicode.utf8ValidateSlice(value)) return false;
    for (value) |byte| if (byte < 0x20 or byte == 0x7f) return false;
    return true;
}

test "parse resumable publication status without exposing transfer details" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const value = try parse(Status, arena.allocator(),
        \\{"id":"0123456789abcdef0123456789abcdef","state":"receiving","publication_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","objects":[{"sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","size":42,"offset":13,"available":false}]}
    );
    try std.testing.expectEqualStrings("receiving", value.state);
    try std.testing.expectEqual(@as(usize, 13), value.objects[0].offset);
    try std.testing.expect(hex(value.id));
}
