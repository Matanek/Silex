const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");
const Lower = @import("../Arm64/Lower.zig");
const Release = @import("Release.zig");
const Runner = @import("../Arm64/Runner.zig");

const optimize = Release.optimize;

test "parallel release optimization preserves canonical portable IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function_count = @import("../Workers.zig").minimum_items + 17;
    const functions = try allocator.alloc(Ir.Function, function_count);
    for (functions, 0..) |*function, index| {
        const instructions = try allocator.alloc(Ir.Instruction, 1);
        instructions[0] = .{ .constant_int = .{ .result = 0, .bits = index } };
        const blocks = try allocator.alloc(Ir.Block, 1);
        blocks[0] = .{ .instructions = instructions, .terminator = .{ .return_value = 0 } };
        function.* = .{
            .name = try std.fmt.allocPrint(allocator, "optimized_{d}", .{index}),
            .parameter_types = &.{},
            .return_type = .int,
            .value_types = &.{.int},
            .blocks = blocks,
        };
    }
    const program: Ir.Program = .{ .functions = functions };
    const single = try Release.optimizeWithWorkers(allocator, program, 1);
    const pair = try Release.optimizeWithWorkers(allocator, program, 2);
    const maximum = try Release.optimizeWithWorkers(allocator, program, @import("../Workers.zig").max_count);
    try std.testing.expectEqualStrings(try Ir.writeText(allocator, single), try Ir.writeText(allocator, pair));
    try std.testing.expectEqualStrings(try Ir.writeText(allocator, single), try Ir.writeText(allocator, maximum));
}

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
test "release preserves effects and observable execution" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Resource {
        \\    let value:int
        \\    drop { print("drop ", self.value) }
        \\}
        \\func calculate(limit:int) int {
        \\    var total = 0
        \\    var index = 0
        \\    while index < limit {
        \\        total += index
        \\        index += 1
        \\    }
        \\    return total
        \\}
        \\func main() {
        \\    let resource = Resource(value:3)
        \\    let answer = calculate(10)
        \\    assert(answer == 45, "wrong answer")
        \\    print(answer)
        \\}
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
}

test "release preserves floating branches and loops" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func root(value:float) float {
        \\    if value < 0.0 { return invalid(value) }
        \\    if value == 0.0 || value + value == value { return value }
        \\    var estimate = 1.0
        \\    if value > 1.0 { estimate = value }
        \\    var previous = 0.0
        \\    var iteration = 0
        \\    while iteration < 128 {
        \\        let next = (estimate + value / estimate) * 0.5
        \\        if next == estimate || next == previous { return next }
        \\        previous = estimate
        \\        estimate = next
        \\        iteration += 1
        \\    }
        \\    return estimate
        \\}
        \\func invalid(value:float) float {
        \\    let zero = value - value
        \\    return zero / zero
        \\}
        \\func main() { assert(root(0.0) == 0.0, "root zero") }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(@as(u8, 0), release.exit_code);
    try std.testing.expectEqualStrings("", release.stderr);
    const machine = try Lower.lowerWithMode(allocator, optimized, .release);
    const native = try Runner.invoke(allocator, machine, 0, &.{0});
    try std.testing.expectEqual(@as(i64, 0), native.value);
}

test "release preserves helper mutations of class-owned list elements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Store {
        \\    var active:bool[]
        \\    var weights:float[]
        \\    var values:float[]
        \\    init() {
        \\        self.active = [false, true]
        \\        self.weights = [0.0, 1.0]
        \\        self.values = [0.0, 0.197275]
        \\    }
        \\}
        \\func translate(store:Store, index:int, offset:float) {
        \\    if !store.active[index] || store.weights[index] <= 0.0 { return }
        \\    store.values[index] += offset
        \\}
        \\func resolve(store:Store) {
        \\    translate(store, 0, 0.0)
        \\    translate(store, 1, 0.0025871352)
        \\}
        \\func answer() float { var store = Store(); resolve(store); return store.values[1] }
        \\func main() {
        \\    var store = Store()
        \\    let snapshot = store.values
        \\    resolve(store)
        \\    print(snapshot[1], " ", store.values[1])
        \\}
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    var answer: ?usize = null;
    for (optimized.functions, 0..) |function, index| {
        if (std.mem.eql(u8, function.name, "answer")) answer = index;
    }
    const function = answer orelse return error.TestUnexpectedResult;
    const debug_machine = try Lower.lowerWithMode(allocator, optimized, .debug);
    const debug_native = try Runner.invoke(allocator, debug_machine, function, &.{});
    const machine = try Lower.lowerWithMode(allocator, optimized, .release);
    const native = try Runner.invoke(allocator, machine, function, &.{});
    try std.testing.expectEqualStrings("0.197275 0.19986214\n", reference.stdout);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqual(
        @as(u32, @bitCast(@as(f32, 0.19986214))),
        @as(u32, @truncate(@as(u64, @bitCast(debug_native.value)))),
    );
    try std.testing.expectEqual(
        @as(u32, @bitCast(@as(f32, 0.19986214))),
        @as(u32, @truncate(@as(u64, @bitCast(native.value)))),
    );
}

test "release removes calls to proven constant functions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func answer() int { return 42 }
        \\func main() { print(answer()) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @answer"));
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "const 42"));
}

test "release inlines proven identity and scalar binary functions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func identity(value:int) int { return value }
        \\func add(left:int, right:int) int { return left + right }
        \\func main() { print(add(identity(20), 22)) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @identity"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @add"));
}

test "release inlines small value calculations and structure construction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { let x:float; let y:float }
        \\func pair(x:float, y:float) Pair { return Pair(x:x, y:y) }
        \\func squared(value:Pair) float { return value.x * value.x + value.y * value.y }
        \\func calculate(x:float, y:float) float { return squared(pair(x, y)) }
        \\func main() { print(calculate(3.0, 4.0)) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @pair"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @squared"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "call @calculate"));
}

test "release scalarizes non escaping value structures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { let x:float; let y:float }
        \\func add(left:Pair, right:Pair) Pair { return Pair(x:left.x + right.x, y:left.y + right.y) }
        \\func sum(value:Pair) float {
        \\    let combined = add(value, Pair(x:1.0, y:2.0))
        \\    return combined.x + combined.y
        \\}
        \\func main() { print(sum(Pair(x:3.0, y:4.0))) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @sum") orelse return error.TestUnexpectedResult;
    const tail = text[start..];
    const end = std.mem.indexOf(u8, tail, "\n}\n") orelse tail.len;
    const body = tail[0..end];
    try std.testing.expect(!std.mem.containsAtLeast(u8, body, 1, "call @add"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, body, 1, "struct.init @Pair"));
}

test "release keeps scalar aggregates materialized across control flow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { let x:float; let y:float }
        \\func component(value:Pair, condition:bool) float {
        \\    let scaled = Pair(x:value.x * 0.5, y:value.y * 0.5)
        \\    var offset = 0.0
        \\    if condition { offset = 1.0 }
        \\    return scaled.x + offset
        \\}
        \\func main() { print(component(Pair(x:8.0, y:4.0), true)) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @component") orelse return error.TestUnexpectedResult;
    const tail = text[start..];
    const end = std.mem.indexOf(u8, tail, "\n}\n") orelse tail.len;
    const body = tail[0..end];
    try std.testing.expect(std.mem.containsAtLeast(u8, body, 1, "struct.init @Pair"));
}

test "release removes only collection bounds proven by zero-origin loops" {
    try boundedCollectionLoops(optimize);
}
