const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Protocol = @import("Protocol.zig");
const Types = @import("Types.zig");

pub fn analyze(
    allocator: std.mem.Allocator,
    source: []const u8,
    encoding: Types.PositionEncoding,
) ![]const Types.Diagnostic {
    var frontend = Frontend.Frontend.init(allocator);
    frontend.checkDocument(source) catch |err| switch (err) {
        error.InvalidSource => return allocator.dupe(Types.Diagnostic, &.{
            Protocol.diagnosticFromSource(source, frontend.diagnostic.?, encoding),
        }),
        error.OutOfMemory => return error.OutOfMemory,
    };
    return allocator.alloc(Types.Diagnostic, 0);
}

test "surface the current frontend diagnostic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(arena.allocator(), "func main() { let value:int = }", .utf16);
    try std.testing.expectEqual(@as(usize, 1), diagnostics.len);
    try std.testing.expectEqualStrings("expected expression", diagnostics[0].message);
}

test "clear diagnostics for a valid current program" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(arena.allocator(), "func main() { let value:int = 42 }", .utf16);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.len);
}

test "do not invent semantic failures before imported overlays exist" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(arena.allocator(),
        \\use Math.Operations
        \\public func answer() int { return Operations.add(40, 2) }
    , .utf16);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.len);
}
