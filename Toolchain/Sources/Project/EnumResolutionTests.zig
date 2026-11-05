const std = @import("std");
const Project = @import("../Project.zig");

test "prefer enum variants to homonymous module function references" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Easing.sx",
        .data =
        \\public enum Easing { quadratic_in; idle }
        \\func quadratic_in(amount:int) int { return amount * amount }
        \\public func sample(easing:Easing, amount:int) int {
        \\    if easing == Easing.quadratic_in { return quadratic_in(amount) }
        \\    return amount
        \\}
        \\public func identity(amount:int) int { return amount }
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Facade.sx",
        .data = "public use Easing",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Easing as Curve
        \\use Facade
        \\func main() {
        \\    let inferred = Curve.quadratic_in
        \\    let typed:Curve = Curve.quadratic_in
        \\    assert(inferred == typed)
        \\    assert(Curve.quadratic_in() == typed)
        \\    assert(Facade.Easing.quadratic_in == typed)
        \\    assert(Curve.sample(inferred, 3) == 9)
        \\    assert(Curve.sample(Curve.idle, 3) == 3)
        \\    let callback:func(int) int = Curve.identity
        \\    print(callback(42))
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}
