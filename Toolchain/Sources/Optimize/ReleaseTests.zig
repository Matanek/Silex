const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");

pub fn boundedCollectionLoops(optimize_program: anytype) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func sum(values:@int[..]) int {
        \\    var total = 0
        \\    var index = 0
        \\    while index < values.count() {
        \\        total += values[index]
        \\        index++
        \\    }
        \\    return total
        \\}
        \\func unproven(values:@int[..]) int {
        \\    var index = -4
        \\    while index < values.count() { return values[index] }
        \\    return 0
        \\}
        \\func advanced_before_access(values:@int[..]) int {
        \\    var index = 0
        \\    while index < values.count() {
        \\        index++
        \\        return values[index]
        \\    }
        \\    return 0
        \\}
        \\func nested(values:@int[..]) int {
        \\    var total = 0
        \\    var repetition = 0
        \\    while repetition < 2 {
        \\        var index = 0
        \\        while index < values.count() {
        \\            total += values[index]
        \\            index++
        \\        }
        \\        repetition++
        \\    }
        \\    return total
        \\}
        \\func main() {
        \\    let values = [3, 5, 8]
        \\    print(sum(@values[0:values.count()]))
        \\}
    );
    const optimized = try optimize_program(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    const sum_start = std.mem.indexOf(u8, text, "func @sum") orelse return error.TestUnexpectedResult;
    const unproven_start = std.mem.indexOf(u8, text, "func @unproven") orelse return error.TestUnexpectedResult;
    const advanced_start = std.mem.indexOf(u8, text, "func @advanced_before_access") orelse return error.TestUnexpectedResult;
    const nested_start = std.mem.indexOf(u8, text, "func @nested") orelse return error.TestUnexpectedResult;
    const main_start = std.mem.indexOf(u8, text, "func @main") orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, text[sum_start..unproven_start], "collection.load %0, %7 bounded") != null);
    try std.testing.expect(std.mem.indexOf(u8, text[unproven_start..advanced_start], " bounded") == null);
    try std.testing.expect(std.mem.indexOf(u8, text[advanced_start..nested_start], " bounded") == null);
    try std.testing.expect(std.mem.indexOf(u8, text[nested_start..main_start], " bounded") != null);
    const result = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("16\n", result.stdout);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
