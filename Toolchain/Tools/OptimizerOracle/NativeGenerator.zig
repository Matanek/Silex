const std = @import("std");

const Generator = struct {
    state: u64,

    fn next(self: *Generator) u64 {
        self.state = self.state *% 6364136223846793005 +% 1442695040888963407;
        return self.state;
    }

    fn value(self: *Generator) i64 {
        return @as(i64, @intCast(self.next() % 101)) - 50;
    }
};

/// Generate a deterministic cross-feature scenario. It deliberately combines
/// a reused short-circuit result, aggregate snapshots, owning copy-on-write,
/// mutable views, a direct call, a loop, and text output so one native
/// execution checks several optimizer/backend boundaries together.
pub fn source(allocator: std.mem.Allocator, seed: u64) ![]u8 {
    var generator: Generator = .{ .state = seed };
    const first = generator.value();
    const second = generator.value();
    const third = generator.value();
    const replacement = generator.value();
    const index = generator.next() % 3;
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.print(
        \\struct Pair {{ var x:int; var y:int }}
        \\func adjust(values:&Pair[..], index:int, replacement:int) int {{
        \\    let snapshot = copy values[index]
        \\    values[index].x = replacement
        \\    return snapshot.x + values[index].x + snapshot.y
        \\}}
        \\func scenario(a:bool, b:bool, c:bool, offset:int) {{
        \\    var values:Pair[] = [
        \\        Pair(x:{d}, y:1), Pair(x:{d}, y:2), Pair(x:{d}, y:3)
        \\    ]
        \\    let original = values
        \\    let accepted = a && b && c
        \\    let score = adjust(&values[0:values.count()], {d}, {d} + offset)
        \\    var total = 0
        \\    var item = 0
        \\    while item < values.count() {{ total += values[item].y; item++ }}
        \\    if accepted {{ print("accepted:", score) }}
        \\    else {{ print("rejected:", score) }}
        \\    if accepted {{ print("draw:text") }}
        \\    else {{ print("hide:text") }}
        \\    print(original[{d}].x, "->", values[{d}].x, " total=", total)
        \\}}
        \\func main() {{
        \\    scenario(true, true, true, {d})
        \\    scenario(true, false, true, {d})
        \\    scenario(false, true, true, {d})
        \\}}
        \\
    , .{
        first,
        second,
        third,
        index,
        replacement,
        index,
        index,
        generator.value(),
        generator.value(),
        generator.value(),
    });
    return output.toOwnedSlice();
}

test "native scenarios are deterministic and combine regression families" {
    const generated = try source(std.testing.allocator, 17);
    defer std.testing.allocator.free(generated);
    const repeated = try source(std.testing.allocator, 17);
    defer std.testing.allocator.free(repeated);
    try std.testing.expectEqualStrings(generated, repeated);
    try std.testing.expect(std.mem.indexOf(u8, generated, "a && b && c") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "struct Pair") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "let original = values") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "adjust(&values[0:values.count()]") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "while item < values.count()") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "draw:text") != null);
}
