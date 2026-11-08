const std = @import("std");
const M = @import("Semantic/CallbackFlow/Model.zig");

fn sameKnownFacts(memory: M.Memory) !void {
    var full = memory.cells.iterator();
    var sparse = memory.knownControls();
    while (full.next()) |entry| {
        if (!entry.value_ptr.hasKnownControl()) continue;
        const actual = sparse.next() orelse return error.MissingKnownFact;
        try std.testing.expect(std.meta.eql(entry.key_ptr.*, actual.key_ptr.*));
        try std.testing.expect(M.Value.eql(entry.value_ptr.*, actual.value_ptr.*));
    }
    try std.testing.expect(sparse.next() == null);
}

test "callback known controls match full traversal after rotations writes snapshots and promotion" {
    var outer = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer outer.deinit();
    var scratch = std.heap.ArenaAllocator.init(std.testing.allocator);
    const a = scratch.allocator();
    var memory: M.Memory = .empty;
    for (0..700) |i| {
        const snapshot = memory;
        const value: M.Value = switch (i % 7) {
            0 => .{ .scalar = .{ .boolean = true } },
            1 => .{ .presence = .absent },
            2 => .{ .scalar = .unknown },
            3 => .{ .unknown_callable = true },
            4 => .{ .scalar = .{ .zero = .int } },
            5 => .{ .presence = .unknown },
            else => .{},
        };
        try memory.put(a, .{ .object = (i * 17) % 37, .field = (i * 13) % 19 }, value);
        try sameKnownFacts(snapshot);
        try sameKnownFacts(memory);
    }
    const promoted = try memory.promote(a, outer.allocator());
    scratch.deinit();
    try sameKnownFacts(promoted);
}
