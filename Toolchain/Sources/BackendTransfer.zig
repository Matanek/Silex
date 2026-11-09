//! Moves the portable backend input out of the frontend compilation arena.
const std = @import("std");
const Boundary = @import("Boundary.zig");
const Ir = @import("Ir.zig");
const Packages = @import("Packages.zig");

pub const Input = struct {
    ir: Ir.Program,
    boundaries: []const Boundary.Function,
    providers: []const Packages.BoundaryProvider,
    files: []const []const u8,
};

pub fn transfer(allocator: std.mem.Allocator, input: Input) std.mem.Allocator.Error!Input {
    // Preserve every typed descriptor while giving nested slices backend
    // ownership. Text conversion and parsing contribute no information here.
    return clone(Input, allocator, input);
}

fn clone(comptime T: type, allocator: std.mem.Allocator, value: T) std.mem.Allocator.Error!T {
    return switch (@typeInfo(T)) {
        .void, .bool, .int, .float, .@"enum" => value,
        .optional => |info| if (value) |payload| try clone(info.child, allocator, payload) else null,
        .pointer => |info| result: {
            if (info.size != .slice or info.sentinel_ptr != null)
                @compileError("backend transfer requires ordinary owned slices: " ++ @typeName(T));
            const items = try allocator.alloc(info.child, value.len);
            for (items, value) |*item, source| item.* = try clone(info.child, allocator, source);
            break :result items;
        },
        .array => |info| result: {
            var items: T = value;
            for (&items, value) |*item, source| item.* = try clone(info.child, allocator, source);
            break :result items;
        },
        .@"struct" => |info| result: {
            var result: T = undefined;
            inline for (info.fields) |field| @field(result, field.name) = try clone(field.type, allocator, @field(value, field.name));
            break :result result;
        },
        .@"union" => |info| result: {
            const Tag = info.tag_type orelse @compileError("backend transfer requires tagged unions");
            const tag = std.meta.activeTag(value);
            inline for (info.fields) |field| if (tag == @field(Tag, field.name))
                break :result @unionInit(T, field.name, try clone(field.type, allocator, @field(value, field.name)));
            unreachable;
        },
        else => @compileError("unsupported backend descriptor: " ++ @typeName(T)),
    };
}

test "backend input matches the JSON oracle after release of frontend storage" {
    var frontend_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    var frontend_live = true;
    defer if (frontend_live) frontend_arena.deinit();
    const frontend_allocator = frontend_arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(frontend_allocator);
    const compilation = try frontend.compile("func main() { print(42) }");
    const input: Input = .{
        .ir = compilation.ir,
        .boundaries = &.{.{
            .name = try frontend_allocator.dupe(u8, "sample"),
            .provider = try frontend_allocator.dupe(u8, "SampleProvider"),
            .source_name = try frontend_allocator.dupe(u8, "sample_external"),
            .parameters = try frontend_allocator.dupe(Ir.Type, &.{ .float32, .int }),
            .return_type = .bool,
            .owner = 7,
            .package_private = true,
        }},
        .providers = &.{.{
            .name = try frontend_allocator.dupe(u8, "SampleProvider"),
            .archive = try frontend_allocator.dupe(u8, "Local/archive.a"),
            .artifact_sha256 = try frontend_allocator.dupe(u8, "sample-digest"),
            .frameworks = &.{try frontend_allocator.dupe(u8, "Foundation")},
            .libraries = &.{try frontend_allocator.dupe(u8, "m")},
            .requires = &.{.{
                .package = try frontend_allocator.dupe(u8, "Dependency"),
                .provider = try frontend_allocator.dupe(u8, "DependencyProvider"),
            }},
        }},
        .files = &.{try frontend_allocator.dupe(u8, "Tests/Main.sx")},
    };
    var backend_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer backend_arena.deinit();
    const expected = try std.json.Stringify.valueAlloc(std.testing.allocator, input, .{});
    defer std.testing.allocator.free(expected);
    const transferred = try transfer(backend_arena.allocator(), input);
    frontend_arena.deinit();
    frontend_live = false;
    const actual = try std.json.Stringify.valueAlloc(std.testing.allocator, transferred, .{});
    defer std.testing.allocator.free(actual);
    try std.testing.expectEqualStrings(expected, actual);
    try std.testing.expectEqualStrings("SampleProvider", transferred.providers[0].name);
    try std.testing.expectEqualStrings("Tests/Main.sx", transferred.files[0]);
    const result = try @import("Interpreter.zig").runCapture(backend_arena.allocator(), transferred.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "backend input clone preserves array sentinels and owns nested array slices" {
    const Sample = struct { terminated: [3:0]u8, names: [2][]const u8 };
    var source = std.heap.ArenaAllocator.init(std.testing.allocator);
    var live = true;
    defer if (live) source.deinit();
    const value: Sample = .{ .terminated = .{ 'a', 'b', 'c' }, .names = .{
        try source.allocator().dupe(u8, "first"),
        try source.allocator().dupe(u8, "second"),
    } };
    var destination = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer destination.deinit();
    const copied = try clone(Sample, destination.allocator(), value);
    source.deinit();
    live = false;
    try std.testing.expectEqual(@as(u8, 0), copied.terminated[3]);
    try std.testing.expectEqualStrings("abc", &copied.terminated);
    try std.testing.expectEqualStrings("first", copied.names[0]);
    try std.testing.expectEqualStrings("second", copied.names[1]);
}
