const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Error = Allocator.Error || error{InvalidCache};

pub fn encode(allocator: Allocator, value: anytype) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    try writeValue(@TypeOf(value), allocator, &output, value);
    return output.toOwnedSlice(allocator);
}

pub fn decode(comptime T: type, allocator: Allocator, bytes: []const u8) Error!T {
    var cursor: usize = 0;
    const value = try readValue(T, allocator, bytes, &cursor);
    if (cursor != bytes.len) return error.InvalidCache;
    return value;
}

fn writeValue(comptime T: type, allocator: Allocator, output: *std.ArrayList(u8), value: T) Error!void {
    switch (@typeInfo(T)) {
        .void => {},
        .bool => try output.append(allocator, @intFromBool(value)),
        .int => |info| {
            if (info.bits % 8 != 0) @compileError("cache integers must occupy complete bytes");
            var buffer: [@sizeOf(T)]u8 = undefined;
            std.mem.writeInt(T, &buffer, value, .little);
            try output.appendSlice(allocator, &buffer);
        },
        .@"enum" => try writeValue(u32, allocator, output, @intCast(@intFromEnum(value))),
        .optional => |info| {
            if (value) |payload| {
                try output.append(allocator, 1);
                try writeValue(info.child, allocator, output, payload);
            } else try output.append(allocator, 0);
        },
        .pointer => |info| {
            if (info.size != .slice) @compileError("cache pointers must be slices");
            try writeLength(allocator, output, value.len);
            for (value) |item| try writeValue(info.child, allocator, output, item);
        },
        .@"struct" => |info| inline for (info.fields) |field| {
            try writeValue(field.type, allocator, output, @field(value, field.name));
        },
        .@"union" => |info| {
            const Tag = info.tag_type orelse @compileError("cache unions must be tagged");
            const tag = std.meta.activeTag(value);
            try writeValue(Tag, allocator, output, tag);
            inline for (info.fields) |field| if (tag == @field(Tag, field.name)) {
                try writeValue(field.type, allocator, output, @field(value, field.name));
                return;
            };
            return error.InvalidCache;
        },
        else => @compileError("unsupported cache type: " ++ @typeName(T)),
    }
}

fn readValue(comptime T: type, allocator: Allocator, bytes: []const u8, cursor: *usize) Error!T {
    return switch (@typeInfo(T)) {
        .void => {},
        .bool => switch (try readByte(bytes, cursor)) {
            0 => false,
            1 => true,
            else => error.InvalidCache,
        },
        .int => |info| value: {
            if (info.bits % 8 != 0) @compileError("cache integers must occupy complete bytes");
            const source = try take(bytes, cursor, @sizeOf(T));
            break :value std.mem.readInt(T, source[0..@sizeOf(T)], .little);
        },
        .@"enum" => |info| value: {
            const raw = try readValue(u32, allocator, bytes, cursor);
            if (!info.is_exhaustive) {
                if (raw > std.math.maxInt(info.tag_type)) return error.InvalidCache;
                break :value @enumFromInt(@as(info.tag_type, @intCast(raw)));
            }
            inline for (info.fields) |field| {
                if (raw == field.value) break :value @enumFromInt(raw);
            }
            return error.InvalidCache;
        },
        .optional => |info| switch (try readByte(bytes, cursor)) {
            0 => null,
            1 => try readValue(info.child, allocator, bytes, cursor),
            else => error.InvalidCache,
        },
        .pointer => |info| value: {
            if (info.size != .slice) @compileError("cache pointers must be slices");
            const length = try readLength(bytes, cursor);
            if (length > bytes.len - cursor.*) return error.InvalidCache;
            const result = try allocator.alloc(info.child, length);
            for (result) |*item| item.* = try readValue(info.child, allocator, bytes, cursor);
            break :value result;
        },
        .@"struct" => |info| value: {
            var result: T = undefined;
            inline for (info.fields) |field| {
                @field(result, field.name) = try readValue(field.type, allocator, bytes, cursor);
            }
            break :value result;
        },
        .@"union" => |info| value: {
            const Tag = info.tag_type orelse @compileError("cache unions must be tagged");
            const tag = try readValue(Tag, allocator, bytes, cursor);
            inline for (info.fields) |field| if (tag == @field(Tag, field.name)) {
                const payload = try readValue(field.type, allocator, bytes, cursor);
                break :value @unionInit(T, field.name, payload);
            };
            return error.InvalidCache;
        },
        else => @compileError("unsupported cache type: " ++ @typeName(T)),
    };
}

fn writeLength(allocator: Allocator, output: *std.ArrayList(u8), length: usize) Error!void {
    if (length > std.math.maxInt(u32)) return error.InvalidCache;
    try writeValue(u32, allocator, output, @intCast(length));
}

fn readLength(bytes: []const u8, cursor: *usize) Error!usize {
    return @intCast(try readValue(u32, undefined, bytes, cursor));
}

fn readByte(bytes: []const u8, cursor: *usize) Error!u8 {
    const result = try take(bytes, cursor, 1);
    return result[0];
}

fn take(bytes: []const u8, cursor: *usize, length: usize) Error![]const u8 {
    if (length > bytes.len -| cursor.*) return error.InvalidCache;
    const start = cursor.*;
    cursor.* += length;
    return bytes[start..cursor.*];
}

test "round-trip nested tagged data and reject corruption" {
    const Choice = union(enum) { nothing, values: []const ?u32 };
    const Sample = struct { enabled: bool, choice: Choice };
    const input: Sample = .{ .enabled = true, .choice = .{ .values = &.{ 3, null, 7 } } };
    const payload = try encode(std.testing.allocator, input);
    defer std.testing.allocator.free(payload);
    const decoded = try decode(Sample, std.testing.allocator, payload);
    defer std.testing.allocator.free(decoded.choice.values);
    try std.testing.expect(decoded.enabled);
    try std.testing.expectEqualSlices(?u32, input.choice.values, decoded.choice.values);
    var corrupted_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer corrupted_arena.deinit();
    try std.testing.expectError(error.InvalidCache, decode(Sample, corrupted_arena.allocator(), payload[0 .. payload.len - 1]));
}
