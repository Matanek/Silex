const std = @import("std");
const Compiler = @import("../Project.zig").Compiler;
const Interpreter = @import("../Interpreter.zig");
const Verifier = @import("../Optimize/Verifier.zig");

test "unused abstract protocol helpers retain typed IR without concrete conformers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data =
        \\struct Payload {var values:int[]}
        \\protocol Operation {func number() int; func value() Payload; func values() Payload[]; func action()}
        \\func number(operation:Operation) int {var active=operation;return active.number()+1}
        \\func value(operation:Operation) Payload {var active=operation;return active.value()}
        \\func values(operation:Operation) Payload[] {var active=operation;return active.values()}
        \\func action(operation:Operation) {var active=operation;active.action()}
        \\func main() {print("Unused abstract helpers: pass")}
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try Verifier.verify(allocator, compilation.ir);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("Unused abstract helpers: pass\n", result.stdout);
    var guards: usize = 0;
    for (compilation.ir.functions) |function| {
        if (function.blocks[0].terminator == .panic) guards += 1;
    }
    try std.testing.expectEqual(@as(usize, 4), guards);
}

test "unused abstract protocol helpers still reject incompatible return types" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "protocol Operation {func number() int}\nfunc wrong(operation:Operation) bool {var active=operation;return active.number()}\nfunc main() {}" });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "bool") != null);
}
