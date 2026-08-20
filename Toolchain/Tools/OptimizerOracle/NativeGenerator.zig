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
/// a reused short-circuit result, collection stores, and text output so one
/// native execution checks several optimizer/backend boundaries together.
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
        \\func scenario(a:bool, b:bool, c:bool, offset:int) {{
        \\    var values:int[] = [{d}, {d}, {d}]
        \\    let accepted = a && b && c
        \\    values[{d}] = {d} + offset
        \\    if accepted {{ print("accepted:", values[{d}]) }}
        \\    else {{ print("rejected:", values[{d}]) }}
        \\    if accepted {{ print("draw:text") }}
        \\    else {{ print("hide:text") }}
        \\    print(values[0], " ", values[1], " ", values[2])
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
    try std.testing.expect(std.mem.indexOf(u8, generated, "values[") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated, "draw:text") != null);
}
