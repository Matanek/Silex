const std = @import("std");
const Differential = @import("Differential.zig");

pub fn reduce(
    allocator: std.mem.Allocator,
    source: []const u8,
    expected_error: anyerror,
) ![]const u8 {
    var current = try allocator.dupe(u8, source);
    var changed = true;
    while (changed) {
        changed = false;
        var line_start: usize = 0;
        while (line_start < current.len) {
            const line_end = std.mem.indexOfScalarPos(u8, current, line_start, '\n') orelse current.len;
            const line = current[line_start..line_end];
            const next_line = @min(line_end + 1, current.len);
            if (!std.mem.startsWith(u8, line, "    value =")) {
                line_start = next_line;
                continue;
            }
            const candidate = try withoutRange(allocator, current, line_start, next_line);
            const still_fails = failed: {
                _ = Differential.verify(allocator, candidate) catch |err| {
                    break :failed err == expected_error;
                };
                break :failed false;
            };
            if (still_fails) {
                current = candidate;
                changed = true;
                break;
            }
            line_start = next_line;
        }
    }
    return current;
}

fn withoutRange(
    allocator: std.mem.Allocator,
    source: []const u8,
    start: usize,
    end: usize,
) ![]u8 {
    const result = try allocator.alloc(u8, source.len - (end - start));
    @memcpy(result[0..start], source[0..start]);
    @memcpy(result[start..], source[end..]);
    return result;
}

test "line removal preserves the surrounding generated program" {
    const source =
        \\func main() {
        \\    var value = 1
        \\    value = value + 2
        \\    print(value)
        \\}
    ;
    const start = std.mem.indexOf(u8, source, "    value =") orelse unreachable;
    const end = (std.mem.indexOfScalarPos(u8, source, start, '\n') orelse unreachable) + 1;
    const result = try withoutRange(std.testing.allocator, source, start, end);
    defer std.testing.allocator.free(result);
    try std.testing.expectEqualStrings(
        \\func main() {
        \\    var value = 1
        \\    print(value)
        \\}
    , result);
}
