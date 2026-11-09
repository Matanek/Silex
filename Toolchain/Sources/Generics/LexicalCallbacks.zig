const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

const Key = struct { file: ?usize, offset: usize, arity: usize };
pub const Index = struct {
    buckets: std.AutoHashMapUnmanaged(Key, std.ArrayList(usize)) = .empty,

    pub fn build(allocator: std.mem.Allocator, functions: anytype) !Index {
        var index: Index = .{};
        errdefer index.deinit(allocator);
        for (functions, 0..) |function, ordinal| {
            if (!function.is_anonymous) continue;
            const entry = try index.buckets.getOrPut(allocator, .{
                .file = function.position.file,
                .offset = function.position.offset,
                .arity = function.type_parameters.len,
            });
            if (!entry.found_existing) entry.value_ptr.* = .empty;
            try entry.value_ptr.append(allocator, ordinal);
        }
        return index;
    }

    pub fn deinit(self: *Index, allocator: std.mem.Allocator) void {
        var values = self.buckets.valueIterator();
        while (values.next()) |value| value.deinit(allocator);
        self.buckets.deinit(allocator);
        self.* = .{};
    }

    fn candidates(self: Index, position: Source.Position, arity: usize) []const usize {
        const bucket = self.buckets.get(.{ .file = position.file, .offset = position.offset, .arity = arity }) orelse return &.{};
        return bucket.items;
    }
};

// Anonymous bodies are lifted by the parser, but their generic calls must be
// specialized where the callback is defined, with the lexical binding types.
// This is type information only: semantic analysis still owns capture discovery
// and the lifetime of borrowed environments.
pub fn specialize(
    self: anytype,
    name: []const u8,
    arguments: []const Ast.Type,
    position: Source.Position,
    locals: anytype,
) (Source.Error || std.mem.Allocator.Error)!?[]const u8 {
    for (self.lexical_callbacks.candidates(position, arguments.len)) |ordinal| {
        const function = self.source.functions[ordinal];
        if (!nameMatches(function.name, name)) continue;
        return try self.instantiate(function, arguments, position, locals);
    }
    return null;
}

fn nameMatches(candidate: []const u8, name: []const u8) bool {
    return std.mem.eql(u8, candidate, name) or
        (candidate.len > name.len and std.mem.endsWith(u8, candidate, name) and candidate[candidate.len - name.len - 1] == '.');
}

const Counters = struct { name_checks: usize = 0 };

fn specializeConfigured(self: anytype, name: []const u8, arguments: []const Ast.Type, position: Source.Position, locals: anytype, filter_first: bool, counters: ?*Counters) (Source.Error || std.mem.Allocator.Error)!?[]const u8 {
    for (self.source.functions) |function| {
        const eligible = function.is_anonymous and
            function.position.file == position.file and function.position.offset == position.offset and
            function.type_parameters.len == arguments.len;
        if (filter_first and !eligible) continue;
        if (counters) |c| c.name_checks += 1;
        const matches = nameMatches(function.name, name);
        if (!eligible or !matches) continue;
        return try self.instantiate(function, arguments, position, locals);
    }
    return null;
}

const Candidate = struct {
    name: []const u8,
    is_anonymous: bool,
    position: Source.Position,
    type_parameters: []const u8 = &.{},
};
const Probe = struct {
    source: struct { functions: []const Candidate },
    lexical_callbacks: Index = .{},
    calls: usize = 0,
    arguments: []const Ast.Type = &.{},
    locals: usize = 0,
    fn instantiate(self: *Probe, candidate: Candidate, arguments: []const Ast.Type, position: Source.Position, locals: []const bool) ![]const u8 {
        _ = position;
        self.calls += 1;
        self.arguments = arguments;
        self.locals = locals.len;
        return candidate.name;
    }
};
test "lexical callback filtering keeps selection and capture context while skipping impossible names" {
    const position: Source.Position = .{ .offset = 42, .line = 2, .column = 5, .file = 7 };
    const other: Source.Position = .{ .offset = 42, .line = 2, .column = 5, .file = 8 };
    var candidates: [1024]Candidate = undefined;
    @memset(&candidates, .{ .name = "Module.nested.callback", .is_anonymous = false, .position = position });
    candidates[1020] = .{ .name = "callback", .is_anonymous = true, .position = other, .type_parameters = &.{0} };
    candidates[1021] = .{ .name = "callback", .is_anonymous = true, .position = position };
    candidates[1022] = .{ .name = "other_callback", .is_anonymous = true, .position = position, .type_parameters = &.{0} };
    candidates[1023] = .{ .name = "Module.nested.callback", .is_anonymous = true, .position = position, .type_parameters = &.{0} };
    var old: Probe = .{ .source = .{ .functions = &candidates } };
    var new: Probe = old;
    new.lexical_callbacks = try Index.build(std.testing.allocator, &candidates);
    defer new.lexical_callbacks.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(usize, &.{ 1022, 1023 }, new.lexical_callbacks.candidates(position, 1));
    var filtered: Probe = old;
    var before: Counters = .{};
    var after: Counters = .{};
    const expected = try specializeConfigured(&old, "callback", &.{.int}, position, @as([]const bool, &.{ true, false }), false, &before);
    const filtered_result = try specializeConfigured(&filtered, "callback", &.{.int}, position, @as([]const bool, &.{ true, false }), true, &after);
    const actual = try specialize(&new, "callback", &.{.int}, position, @as([]const bool, &.{ true, false }));
    try std.testing.expectEqualStrings(filtered_result.?, actual.?);
    try std.testing.expectEqualStrings(expected.?, actual.?);
    try std.testing.expectEqualStrings("Module.nested.callback", actual.?);
    try std.testing.expectEqual(@as(usize, 1), new.calls);
    try std.testing.expectEqual(@as(usize, 2), new.locals);
    try std.testing.expectEqualSlices(Ast.Type, old.arguments, new.arguments);
    try std.testing.expectEqual(@as(usize, 1024), before.name_checks);
    try std.testing.expectEqual(@as(usize, 2), after.name_checks);
}
test "lexical callback filters retain position arity and exact suffix boundaries" {
    const position: Source.Position = .{ .offset = 4, .line = 1, .column = 5 };
    const candidates = [_]Candidate{
        .{ .name = "notcallback", .is_anonymous = true, .position = position },
        .{ .name = "callback", .is_anonymous = true, .position = .{ .offset = 4, .line = 1, .column = 5, .file = 0 } },
        .{ .name = "Root.callback", .is_anonymous = true, .position = .{ .offset = 5, .line = 1, .column = 6 } },
        .{ .name = "Root.callback", .is_anonymous = true, .position = position },
        .{ .name = "callback", .is_anonymous = true, .position = position },
    };
    for ([_][]const Ast.Type{ &.{}, &.{.float32} }) |args| {
        var old: Probe = .{ .source = .{ .functions = &candidates } };
        var new: Probe = old;
        new.lexical_callbacks = try Index.build(std.testing.allocator, &candidates);
        defer new.lexical_callbacks.deinit(std.testing.allocator);
        const expected = try specializeConfigured(&old, "callback", args, position, @as([]const bool, &.{}), false, null);
        const actual = try specialize(&new, "callback", args, position, @as([]const bool, &.{}));
        if (expected) |name| try std.testing.expectEqualStrings(name, actual.?) else try std.testing.expect(actual == null);
        try std.testing.expectEqual(old.calls, new.calls);
    }
}
