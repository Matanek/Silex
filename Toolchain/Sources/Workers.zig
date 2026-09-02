const std = @import("std");

pub const max_count: u16 = 4;
pub const minimum_items: usize = 256;
pub const stack_bytes: usize = 2 * 1024 * 1024;

pub fn recommendedCount(item_count: usize) u16 {
    if (item_count < minimum_items) return 1;
    const available = std.Thread.getCpuCount() catch return 1;
    return @intCast(@min(available, max_count));
}

pub fn selectedCount(item_count: usize, requested: ?u16) u16 {
    if (item_count < minimum_items) return 1;
    return @max(1, @min(requested orelse recommendedCount(item_count), max_count));
}

pub fn run(comptime Context: type, contexts: []Context, comptime entry: fn (*Context) void) void {
    std.debug.assert(contexts.len >= 1 and contexts.len <= max_count);
    var threads: [max_count - 1]std.Thread = undefined;
    var spawned: usize = 0;
    while (spawned + 1 < contexts.len) : (spawned += 1) {
        threads[spawned] = std.Thread.spawn(.{ .stack_size = stack_bytes }, entry, .{&contexts[spawned]}) catch break;
    }
    for (contexts[spawned..]) |*context| entry(context);
    for (threads[0..spawned]) |thread| thread.join();
}

test "worker selection bounds concurrency and keeps small ranges direct" {
    try std.testing.expectEqual(@as(u16, 1), selectedCount(minimum_items - 1, max_count));
    try std.testing.expectEqual(@as(u16, 2), selectedCount(minimum_items, 2));
    try std.testing.expectEqual(max_count, selectedCount(minimum_items, std.math.maxInt(u16)));
}
