const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Protocol = @import("Protocol.zig");
const Types = @import("Types.zig");

pub fn analyze(
    allocator: std.mem.Allocator,
    source: []const u8,
    encoding: Types.PositionEncoding,
    has_project_context: bool,
) ![]const Types.Diagnostic {
    var frontend = Frontend.Frontend.init(allocator);
    frontend.checkDocumentInProject(source, has_project_context) catch |err| switch (err) {
        error.InvalidSource => {
            return allocator.dupe(Types.Diagnostic, &.{
                Protocol.diagnosticFromSource(source, frontend.diagnostic.?, encoding),
            });
        },
        error.OutOfMemory => return error.OutOfMemory,
    };
    return allocator.alloc(Types.Diagnostic, 0);
}

test "surface the current frontend diagnostic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(arena.allocator(), "func main() { let value:int = }", .utf16, false);
    try std.testing.expectEqual(@as(usize, 1), diagnostics.len);
    try std.testing.expectEqualStrings("expected expression", diagnostics[0].message);
}

test "clear diagnostics for a valid current program" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(arena.allocator(), "func main() { let value:int = 42 }", .utf16, false);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.len);
}

test "diagnose transient unknown field types without terminating the server" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_][]const u8{ "s", "st" }) |partial_type| {
        const source = try std.fmt.allocPrint(allocator, "struct Error {{ let message:{s} }}", .{partial_type});
        const diagnostics = try analyze(allocator, source, .utf16, false);
        try std.testing.expectEqual(@as(usize, 1), diagnostics.len);
        const expected = try std.fmt.allocPrint(allocator, "unknown nominal type '{s}'", .{partial_type});
        try std.testing.expectEqualStrings(expected, diagnostics[0].message);
    }
}

test "clear diagnostics for valid cascades owned by the frontend" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(arena.allocator(),
        \\use GFX.Application
        \\func main() {
        \\    var app = Application()
        \\        ..install()
        \\        ..run()
        \\}
    , .utf16, true);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.len);
}

test "preserve parser diagnostics inside malformed cascades" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(arena.allocator(),
        \\use GFX.Application
        \\func main() {
        \\    var app = Application()
        \\        ..run(
        \\}
    , .utf16, true);
    try std.testing.expectEqual(@as(usize, 1), diagnostics.len);
}

test "do not invent semantic failures before imported overlays exist" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(arena.allocator(),
        \\use Math.Operations
        \\public func answer() int { return Operations.add(40, 2) }
    , .utf16, false);
    try std.testing.expectEqual(@as(usize, 0), diagnostics.len);
}

test "do not diagnose a contextual platform qualifier as a local variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(
        arena.allocator(),
        "public func seed() int { return Platform.system_seed() }",
        .utf16,
        true,
    );
    try std.testing.expectEqual(@as(usize, 0), diagnostics.len);
}

test "do not diagnose a directly qualified package as a local variable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const diagnostics = try analyze(
        arena.allocator(),
        "func main() { let value = STD.Math.Vec3() }",
        .utf16,
        true,
    );
    try std.testing.expectEqual(@as(usize, 0), diagnostics.len);
}
