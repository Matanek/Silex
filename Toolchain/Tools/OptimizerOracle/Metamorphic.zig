const std = @import("std");

pub const Pair = struct {
    id: []const u8,
    axis: []const u8,
    left: []const u8,
    right: []const u8,
};

pub const pairs = [_]Pair{
    .{
        .id = "direct-or-helper",
        .axis = "direct-or-helper",
        .left =
        \\func main() {
        \\    let a = 12
        \\    let b = 5
        \\    print((a + b) * 3)
        \\}
        ,
        .right =
        \\func combine(a:int, b:int) int { return (a + b) * 3 }
        \\func main() { print(combine(12, 5)) }
        ,
    },
    .{
        .id = "declaration-order",
        .axis = "declaration-order",
        .left =
        \\func first(value:int) int { return value + 4 }
        \\func second(value:int) int { return value * 2 }
        \\func main() { print(second(first(17))) }
        ,
        .right =
        \\func second(value:int) int { return value * 2 }
        \\func first(value:int) int { return value + 4 }
        \\func main() { print(second(first(17))) }
        ,
    },
    .{
        .id = "inline-or-nested-helper",
        .axis = "direct-or-helper",
        .left =
        \\func advance(value:int) int { return (value + 3) * 2 }
        \\func main() {
        \\    var value = 1
        \\    var index = 0
        \\    while index < 20 { value = advance(value); index += 1 }
        \\    print(value)
        \\}
        ,
        .right =
        \\func add(value:int) int { return value + 3 }
        \\func double(value:int) int { return value * 2 }
        \\func advance(value:int) int { return double(add(value)) }
        \\func main() {
        \\    var value = 1
        \\    var index = 0
        \\    while index < 20 { value = advance(value); index += 1 }
        \\    print(value)
        \\}
        ,
    },
};

test "metamorphic sources and axes remain deterministic" {
    try std.testing.expect(pairs.len >= 3);
    for (pairs, 0..) |pair, index| {
        try std.testing.expect(pair.id.len != 0 and pair.axis.len != 0);
        try std.testing.expect(pair.left.len != 0 and pair.right.len != 0);
        for (pairs[0..index]) |previous| try std.testing.expect(!std.mem.eql(u8, previous.id, pair.id));
    }
}
