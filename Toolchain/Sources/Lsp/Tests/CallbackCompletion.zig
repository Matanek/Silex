const std = @import("std");
const Completion = @import("../Completion.zig");

test "nested callback completion keeps every lexical level visible" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func apply(value:int, callback:func(int) int) int { return callback(value) }
        \\func main() {
        \\    let base = 30
        \\    apply(5, func(outer:int) int {
        \\        let offset = 2
        \\        return apply(outer, func(inner:int) int {
        \\            return ba
        \\        })
        \\    })
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "return ba").? + "return ba".len;
    const items = try Completion.itemsAt(allocator, source, cursor, .invoked);
    try std.testing.expect(hasLabel(items, "base"));
    try std.testing.expect(!hasLabel(items, "__silex_anonymous_0"));
}

fn hasLabel(items: anytype, label: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return true;
    return false;
}
