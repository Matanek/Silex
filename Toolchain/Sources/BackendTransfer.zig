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

pub fn transfer(allocator: std.mem.Allocator, temporary: std.mem.Allocator, input: Input) !Input {
    // The frontend's AST and semantic tables cannot be released while any IR
    // slice still borrows their arena. The established IR JSON representation
    // copies every nested descriptor into the backend arena before release.
    const encoded = try std.json.Stringify.valueAlloc(temporary, input, .{});
    defer temporary.free(encoded);
    return try std.json.parseFromSliceLeaky(Input, allocator, encoded, .{ .allocate = .alloc_always });
}

test "backend input survives release of frontend and transfer storage" {
    var frontend_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    var frontend_live = true;
    defer if (frontend_live) frontend_arena.deinit();
    const frontend_allocator = frontend_arena.allocator();
    var frontend = @import("Frontend.zig").Frontend.init(frontend_allocator);
    const compilation = try frontend.compile("func main() { print(42) }");
    const input: Input = .{
        .ir = compilation.ir,
        .boundaries = &.{},
        .providers = &.{.{
            .name = try frontend_allocator.dupe(u8, "SampleProvider"),
            .frameworks = &.{},
            .libraries = &.{},
        }},
        .files = &.{try frontend_allocator.dupe(u8, "Tests/Main.sx")},
    };
    var backend_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer backend_arena.deinit();
    const transferred = try transfer(backend_arena.allocator(), std.testing.allocator, input);
    frontend_arena.deinit();
    frontend_live = false;
    try std.testing.expectEqualStrings("SampleProvider", transferred.providers[0].name);
    try std.testing.expectEqualStrings("Tests/Main.sx", transferred.files[0]);
    const result = try @import("Interpreter.zig").runCapture(backend_arena.allocator(), transferred.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}
