const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");
const Debug = @import("Debug.zig");

fn compare(source: []const u8, expected_exit: u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const original = (try frontend.compile(source)).ir;
    const prepared = try Debug.prepare(allocator, original, 1);
    const expected = try Interpreter.runCapture(allocator, original);
    const actual = try Interpreter.runCapture(allocator, prepared);
    try std.testing.expectEqual(expected_exit, expected.exit_code);
    try std.testing.expectEqual(expected.exit_code, actual.exit_code);
    try std.testing.expectEqualStrings(expected.stdout, actual.stdout);
    try std.testing.expectEqualStrings(expected.stderr, actual.stderr);
}

fn compareFailure(source: []const u8, expected_error: anyerror) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const original = (try frontend.compile(source)).ir;
    const prepared = try Debug.prepare(allocator, original, 1);
    try std.testing.expectError(expected_error, Interpreter.runCapture(allocator, original));
    try std.testing.expectError(expected_error, Interpreter.runCapture(allocator, prepared));
}

test "Debug preparation simplifies value helpers and retains branching calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const original = (try frontend.compile(
        \\func tiny(value:int) int { return value + 1 }
        \\func branch(value:int) int { if value > 0 { return value * 2 } return -value }
        \\func answer(value:int) int { return tiny(value) + branch(value) }
        \\func main() { print(answer(5)); print(answer(-3)) }
    )).ir;
    const prepared = try Debug.prepare(allocator, original, 1);
    try std.testing.expectEqual(original.functions.len, prepared.functions.len);
    const expected = try Interpreter.runCapture(allocator, original);
    const actual = try Interpreter.runCapture(allocator, prepared);
    try std.testing.expectEqualStrings(expected.stdout, actual.stdout);
    var tiny_calls: usize = 0;
    var branch_calls: usize = 0;
    for (prepared.functions) |function| for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .call) {
            const name = prepared.functions[instruction.call.function].name;
            if (std.mem.eql(u8, name, "tiny")) tiny_calls += 1;
            if (std.mem.eql(u8, name, "branch")) branch_calls += 1;
        }
    };
    try std.testing.expectEqual(@as(usize, 0), tiny_calls);
    try std.testing.expect(branch_calls > 0);
    const parallel = try Debug.prepare(allocator, original, 4);
    try std.testing.expectEqualStrings(try Ir.writeText(allocator, prepared), try Ir.writeText(allocator, parallel));
}

test "Debug preparation preserves aggregate snapshots across reference writes" {
    try compare(
        \\struct Vector {
        \\    var x:float; var y:float; var z:float
        \\    func add(other:Vector) Vector { return Vector(x:self.x+other.x,y:self.y+other.y,z:self.z+other.z) }
        \\}
        \\func change(value:&Vector) { value.x=90.0;value.y=80.0 }
        \\func main() {
        \\    var current=Vector(x:1.0,y:2.0,z:3.0)
        \\    let snapshot=current
        \\    change(current)
        \\    let sum=snapshot.add(current)
        \\    print(snapshot.x," ",snapshot.y," ",sum.x," ",sum.y," ",sum.z)
        \\}
    , 0);
}

test "Debug preparation preserves integer failures" {
    try compareFailure(
        \\func increment(value:int) int { return value+1 }
        \\func main() { print("before");print(increment(9223372036854775807));print("after") }
    , error.IntegerOverflow);
    try compareFailure(
        \\func divide(a:int,b:int) int { return a/b }
        \\func main() { var zero=0;print("before");print(divide(42,zero));print("after") }
    , error.DivisionByZero);
}

test "Debug preparation preserves collection bounds failures" {
    try compare(
        \\func read(values:@int[..],index:int) int { return values[index] }
        \\func main() { var values:int[]=[4,5];print("before");print(read(@values[0:2],3));print("after") }
    , 1);
}
