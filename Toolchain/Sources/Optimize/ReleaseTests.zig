const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");
const Lower = @import("../Arm64/Lower.zig");
const Machine = @import("../Arm64/Machine.zig");
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
        \\struct Cell { var value:int }
        \\func increment(cell:&Cell) { cell.value += 1 }
        \\func mutate(values:&Cell[..]) {
        \\    var index = 0
        \\    while index < values.count() {
        \\        increment(values[index])
        \\        index++
        \\    }
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
    const mutate_start = std.mem.indexOf(u8, text, "func @mutate") orelse return error.TestUnexpectedResult;
    const main_start = std.mem.indexOf(u8, text, "func @main") orelse return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, text[sum_start..unproven_start], "collection.load %0, %7 bounded") != null);
    try std.testing.expect(std.mem.indexOf(u8, text[unproven_start..advanced_start], " bounded") == null);
    try std.testing.expect(std.mem.indexOf(u8, text[advanced_start..nested_start], " bounded") == null);
    try std.testing.expect(std.mem.indexOf(u8, text[nested_start..mutate_start], " bounded") != null);
    const mutate = text[mutate_start..main_start];
    try std.testing.expect(std.mem.indexOf(u8, mutate, "collection.reference") != null);
    try std.testing.expect(std.mem.indexOf(u8, mutate, " bounded") != null);
    try std.testing.expect(std.mem.indexOf(u8, mutate, "collection.load") == null);
    try std.testing.expect(std.mem.indexOf(u8, mutate, "collection.replace") == null);
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

test "release removes a redundant aggregate read before indexed replacement" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Sample {
        \\    var first:float
        \\    var second:float
        \\    var third:float
        \\}
        \\func make(index:int) Sample {
        \\    return Sample(first:index as float, second:2.0, third:3.0)
        \\}
        \\func overwrite(values:&Sample[..]) {
        \\    var index = 0
        \\    while index < values.count() {
        \\        values[index] = make(index)
        \\        index++
        \\    }
        \\}
        \\func main() {
        \\    var values:Sample[] = [Sample(), Sample()]
        \\    overwrite(&values[0:values.count()])
        \\    print(values[1].first, " ", values[1].second, " ", values[1].third)
        \\}
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    const overwrite_start = std.mem.indexOf(u8, text, "func @overwrite") orelse return error.TestUnexpectedResult;
    const main_start = std.mem.indexOf(u8, text, "func @main") orelse return error.TestUnexpectedResult;
    const overwrite = text[overwrite_start..main_start];
    try std.testing.expect(std.mem.indexOf(u8, overwrite, "collection.load") == null);
    try std.testing.expect(std.mem.indexOf(u8, overwrite, "collection.replace") != null);
    const result = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("1.0 2.0 3.0\n", result.stdout);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
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

test "release scalarizes immutable aggregates across control flow" {
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
    try std.testing.expect(!std.mem.containsAtLeast(u8, body, 1, "struct.init @Pair"));
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
}

test "release splits flat mutable aggregate locals across control flow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct State { var a:float; var b:float; var c:float; var d:float }
        \\func prepare(seed:float, alternate:bool) State {
        \\    var state = State()
        \\    state.a = seed + 1.0
        \\    if alternate { state.b = seed * 2.0 }
        \\    state.c = state.a + 3.0
        \\    state.d = seed - 4.0
        \\    return state
        \\}
        \\func main() {
        \\    let first = prepare(5.0, true)
        \\    let second = prepare(5.0, false)
        \\    print(first.a); print(first.b); print(first.c); print(first.d)
        \\    print(second.a); print(second.b); print(second.c); print(second.d)
        \\}
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("6.0\n10.0\n9.0\n1.0\n6.0\n0.0\n9.0\n1.0\n", reference.stdout);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @prepare") orelse return error.TestUnexpectedResult;
    const tail = text[start..];
    const end = std.mem.indexOf(u8, tail, "\n}\n") orelse tail.len;
    const body = tail[0..end];
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, body, "struct.init @State"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, body, 1, "store $0:structure"));
}

test "release borrows direct aggregate collection arguments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { var x:float; var y:float }
        \\func sum(value:@Pair) float { return value.x + value.y }
        \\func total(values:@Pair[..]) float {
        \\    var result = 0.0
        \\    var index = 0
        \\    while index < values.count() {
        \\        result += sum(values[index])
        \\        index++
        \\    }
        \\    return result
        \\}
        \\func main() {
        \\    let values:Pair[] = [Pair(x:1.0, y:2.0), Pair(x:3.0, y:4.0)]
        \\    print(total(@values[0:values.count()]))
        \\}
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("10.0\n", reference.stdout);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
    const text = try Ir.writeText(allocator, optimized);
    const sum_start = std.mem.indexOf(u8, text, "func @sum") orelse return error.TestUnexpectedResult;
    const total_start = std.mem.indexOf(u8, text, "func @total") orelse return error.TestUnexpectedResult;
    const main_start = std.mem.indexOf(u8, text, "func @main") orelse return error.TestUnexpectedResult;
    const sum_body = text[sum_start..total_start];
    const total_body = text[total_start..main_start];
    try std.testing.expect(std.mem.containsAtLeast(u8, sum_body, 1, "%0:internal address"));
    try std.testing.expect(std.mem.count(u8, sum_body, "reference.load") >= 2);
    try std.testing.expect(std.mem.containsAtLeast(u8, total_body, 1, "collection.reference"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, total_body, 1, "collection.load"));
}

test "release removes scalar deep copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func copiedFloat(value:float) float { return copy value }
        \\func copiedBool(value:bool) bool { return copy value }
        \\func main() { print(copiedFloat(3.0)); print(copiedBool(true)) }
    );
    const original_text = try Ir.writeText(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(std.mem.count(u8, text, "deep_copy") < std.mem.count(u8, original_text, "deep_copy"));
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("3.0\ntrue\n", reference.stdout);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
}

test "release removes only collection bounds proven by zero-origin loops" {
    try boundedCollectionLoops(optimize);
}

test "release reuses checked mutable view references across sibling field writes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct State { var x:int; var y:int; var z:int }
        \\func rewrite(values:&State[..], first:int, second:int) {
        \\    values[first].x = 11
        \\    values[first].y = 13
        \\    values[first].z = 17
        \\    values[second].x = 19
        \\    values[second].y = 23
        \\    values[second].z = 29
        \\}
        \\func answer() int {
        \\    var values:State[] = [State(x:1, y:2, z:3), State(x:4, y:5, z:6)]
        \\    rewrite(&values[0:values.count()], 0, -1)
        \\    return values[0].x + values[0].y + values[0].z + values[1].x + values[1].y + values[1].z
        \\}
        \\func main() { print(answer()) }
    );
    const optimized = try optimize(allocator, compilation.ir);
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("112\n", reference.stdout);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);

    var references: usize = 0;
    var checked_loads: usize = 0;
    for (optimized.functions) |function| {
        if (!std.mem.eql(u8, function.name, "rewrite")) continue;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .collection_reference => references += 1,
            .collection_load => |load| if (load.checked) {
                checked_loads += 1;
            },
            else => {},
        };
    }
    try std.testing.expectEqual(@as(usize, 2), references);
    try std.testing.expectEqual(@as(usize, 0), checked_loads);

    const machine = try Lower.lowerWithMode(allocator, optimized, .release);
    var answer: ?usize = null;
    var rewrite: ?usize = null;
    for (optimized.functions, 0..) |function, index| {
        if (std.mem.eql(u8, function.name, "answer")) answer = index;
        if (std.mem.eql(u8, function.name, "rewrite")) rewrite = index;
    }
    const native = try Runner.invoke(allocator, machine, answer orelse return error.TestUnexpectedResult, &.{});
    try std.testing.expectEqual(@as(i64, 112), native.value);
    var values = [_]i64{ 1, 2, 3, 4, 5, 6 };
    const pointer: i64 = @intCast(@intFromPtr(&values));
    var invoked = machine.functions[rewrite orelse return error.TestUnexpectedResult];
    invoked.parameter_count = 4;
    invoked.parameters = &.{
        .{ .start = 0, .width = 1 },
        .{ .start = 1, .width = 1 },
        .{ .start = 2, .width = 1 },
        .{ .start = 3, .width = 1 },
    };
    const direct: Machine.Program = .{ .functions = &.{invoked}, .strings = machine.strings };
    const valid = try Runner.invoke(allocator, direct, 0, &.{ pointer, 2, 0, -1 });
    try std.testing.expectEqual(Machine.Status.success, valid.status);
    try std.testing.expectEqualSlices(i64, &.{ 11, 13, 17, 19, 23, 29 }, &values);
    const invalid = try Runner.invoke(allocator, direct, 0, &.{ pointer, 2, 0, -3 });
    try std.testing.expectEqual(Machine.Status.runtime_failure, invalid.status);
}

test "release proves later view references from invariant local and field loads" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct State { var x:int; var y:int }
        \\struct Index { let value:int }
        \\func rewrite(values:&State[..], index:Index, condition:bool) {
        \\    let snapshot = values[index.value]
        \\    if condition {
        \\        values[index.value].x = snapshot.x + 10
        \\    } else {
        \\        values[index.value].y = snapshot.y + 20
        \\    }
        \\}
        \\func main() {}
    );
    const optimized = try optimize(allocator, compilation.ir);
    var rewrite: ?usize = null;
    var references: usize = 0;
    var checked: usize = 0;
    for (optimized.functions, 0..) |function, index| {
        if (!std.mem.eql(u8, function.name, "rewrite")) continue;
        rewrite = index;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .collection_reference => |reference| {
                references += 1;
                checked += @intFromBool(reference.checked);
            },
            else => {},
        };
    }
    try std.testing.expectEqual(@as(usize, 3), references);
    try std.testing.expectEqual(@as(usize, 1), checked);

    const machine = try Lower.lowerWithMode(allocator, optimized, .release);
    const rewrite_index = rewrite orelse return error.TestUnexpectedResult;
    var machine_references: usize = 0;
    var machine_checked: usize = 0;
    for (machine.functions[rewrite_index].instructions) |instruction| switch (instruction) {
        .collection_reference => |reference| {
            machine_references += 1;
            machine_checked += @intFromBool(reference.checked);
        },
        else => {},
    };
    try std.testing.expectEqual(@as(usize, 3), machine_references);
    try std.testing.expectEqual(@as(usize, 1), machine_checked);
    var values = [_]i64{ 1, 2, 3, 4 };
    const pointer: i64 = @intCast(@intFromPtr(&values));
    var invoked = machine.functions[rewrite_index];
    invoked.parameter_count = 4;
    invoked.parameters = &.{
        .{ .start = 0, .width = 1 },
        .{ .start = 1, .width = 1 },
        .{ .start = 2, .width = 1 },
        .{ .start = 3, .width = 1 },
    };
    const direct: Machine.Program = .{ .functions = &.{invoked}, .strings = machine.strings };
    const first = try Runner.invoke(allocator, direct, 0, &.{ pointer, 2, 0, 1 });
    try std.testing.expectEqual(Machine.Status.success, first.status);
    try std.testing.expectEqualSlices(i64, &.{ 11, 2, 3, 4 }, &values);
    const last = try Runner.invoke(allocator, direct, 0, &.{ pointer, 2, -1, 0 });
    try std.testing.expectEqual(Machine.Status.success, last.status);
    try std.testing.expectEqualSlices(i64, &.{ 11, 2, 3, 24 }, &values);
    const invalid = try Runner.invoke(allocator, direct, 0, &.{ pointer, 2, 2, 1 });
    try std.testing.expectEqual(Machine.Status.runtime_failure, invalid.status);
}

test "release materializes a scalar constructor only once after dead local stores" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { let x:float; let y:float }
        \\struct Contact {
        \\    let first:int; let second:int; let normal:Pair; let mass:float
        \\    init(first:int, second:int, normal:Pair, mass:float) {
        \\        self.first = first
        \\        self.second = second
        \\        self.normal = normal
        \\        self.mass = mass
        \\    }
        \\}
        \\func main() {
        \\    let contact = Contact(3, 5, Pair(x:0.5, y:1.0), 2.0)
        \\    print(contact.first + contact.second)
        \\    print(contact.normal.x * contact.mass + contact.normal.y)
        \\}
    );
    const optimized = try optimize(allocator, compilation.ir);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @Contact.init") orelse return error.TestUnexpectedResult;
    const tail = text[start..];
    const end = std.mem.indexOf(u8, tail, "\n}\n") orelse tail.len;
    try std.testing.expectEqual(@as(usize, 1), std.mem.count(u8, tail[0..end], "struct.init @Contact"));
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
}

test "release aggregate aliases preserve joined returns and loop snapshots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { var x:int; var y:int }
        \\func choose(value:int, condition:bool) Pair {
        \\    if condition { return Pair(x:value, y:value + 1) }
        \\    return Pair(x:-value, y:value - 1)
        \\}
        \\func sum(condition:bool) int {
        \\    let scale = Pair(x:2, y:3)
        \\    var total = 0
        \\    var index = 0
        \\    while index < 8 {
        \\        var value = choose(index, condition)
        \\        let snapshot = Pair(x:value.x * scale.x, y:value.y * scale.y)
        \\        if index % 2 == 0 { value.x = 100 }
        \\        if condition { total += snapshot.x } else { total -= snapshot.x }
        \\        total += snapshot.y
        \\        index++
        \\    }
        \\    return total
        \\}
        \\func main() { print(sum(true)); print(sum(false)) }
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("164\n116\n", reference.stdout);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
}

test "release scalarizes block local aggregate field updates after a branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { var x:int; var y:int }
        \\func transform(seed:int, positive:bool) int {
        \\    var total = seed
        \\    if positive { total += 1 }
        \\    var point = Pair(x:seed, y:seed + 1)
        \\    let snapshot = point
        \\    point.x += total
        \\    point.y *= 2
        \\    return point.x + point.y + snapshot.x
        \\}
        \\func main() { print(transform(3, true)); print(transform(3, false)) }
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("18\n17\n", reference.stdout);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @transform") orelse return error.TestUnexpectedResult;
    const tail = text[start..];
    const end = std.mem.indexOf(u8, tail, "\n}\n") orelse tail.len;
    try std.testing.expect(!std.mem.containsAtLeast(u8, tail[0..end], 1, "struct.init @Pair"));
}

test "release drops overwritten aggregate stores but retains branch snapshots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { var x:int; var y:int }
        \\func rewrite(input:Pair, flip:bool) Pair {
        \\    var value = input
        \\    value.x += 1
        \\    if flip { value.y = -value.y }
        \\    value.x += 2
        \\    value.y += value.x
        \\    value.x *= 2
        \\    return value
        \\}
        \\func main() {
        \\    let first = rewrite(Pair(x:3, y:4), true)
        \\    let second = rewrite(Pair(x:3, y:4), false)
        \\    print(first.x); print(first.y); print(second.x); print(second.y)
        \\}
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try optimize(allocator, compilation.ir);
    const release = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqualStrings("12\n2\n12\n10\n", reference.stdout);
    try std.testing.expectEqual(reference.exit_code, release.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, release.stdout);
    try std.testing.expectEqualStrings(reference.stderr, release.stderr);
    const text = try Ir.writeText(allocator, optimized);
    const start = std.mem.indexOf(u8, text, "func @rewrite") orelse return error.TestUnexpectedResult;
    const tail = text[start..];
    const end = std.mem.indexOf(u8, tail, "\n}\n") orelse tail.len;
    try std.testing.expect(std.mem.count(u8, tail[0..end], "struct.init @Pair") <= 3);
}
