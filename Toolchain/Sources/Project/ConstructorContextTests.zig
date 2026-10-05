const std = @import("std");
const Compiler = @import("../Project.zig").Compiler;
const Interpreter = @import("../Interpreter.zig");
const Verifier = @import("../Optimize/Verifier.zig");

test "overloaded constructors share argument context without selecting an overload" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data =
        \\struct Grid {
        \\ var shape:int[]
        \\ init(values:float[],shape:int[],enabled:bool=true) {self.shape=shape}
        \\ init(values:int32[],shape:int[],enabled:bool=true) {self.shape=shape}
        \\}
        \\struct Holder {var grid:Grid;init(grid:Grid) {self.grid=grid}}
        \\func main() {
        \\ var values:float[]=[1.0,2.0]
        \\ let rows=1;let columns=2
        \\ let grid=Grid(values,[rows,columns])
        \\ let holder=Holder(Grid(values:values,shape:[rows,columns]))
        \\ let empty=Grid(values:values,shape:[])
        \\ assert(grid.shape[1]==2 && holder.grid.shape[0]==1 && empty.shape.is_empty())
        \\ print("Shared constructor context: pass")
        \\}
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try Verifier.verify(allocator, compilation.ir);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("Shared constructor context: pass\n", result.stdout);
}

test "conflicting constructor argument contexts never choose an arbitrary list type" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "struct Choice {init(value:int,items:int[]) {} init(value:int,items:bool[]) {}}\nfunc main(){Choice(1,[])}" });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expect(std.mem.indexOf(u8, compiler.diagnostic.?.message, "expected collection type") != null);
}
