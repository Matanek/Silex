const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    return std.testing.allocator.dupe(u8, result.stdout);
}

test "callbacks pass as values and remain distinct from shadowed functions" {
    const output = try run(
        \\func predicate(value:@int) bool { return false }
        \\func positive(value:@int) bool { return value > 0 }
        \\struct Tester {
        \\    private var predicate:func(@int) bool
        \\    init(predicate:func(@int) bool) { self.predicate = predicate }
        \\    func test(value:@int) bool { return self.predicate(value) }
        \\}
        \\func apply(value:@int, callback:func(@int) bool) bool { return callback(value) }
        \\func main() {
        \\    let tester = Tester(positive)
        \\    print(tester.test(1), apply(-1, positive))
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("truefalse\n", output);
}

test "void callback types omit an explicit return type" {
    const output = try run(
        \\func consume(value:int) { print(value) }
        \\func apply(callback:func(int)) { callback(42) }
        \\func main() { apply(consume) }
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n", output);
}

test "anonymous functions execute as callbacks" {
    const output = try run(
        \\func transform(value:int, callback:func(int) int) int { return callback(value) }
        \\func consume(value:int, callback:func(int)) { callback(value) }
        \\func main() {
        \\    print(transform(40, func(value:int) int { return value + 2 }))
        \\    consume(7, func(value:int) { print(value) })
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("42\n7\n", output);
}

test "capturing anonymous functions report their unsupported environment" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\func apply(callback:func() int) int { return callback() }
        \\func main() {
        \\    let value = 42
        \\    print(apply(func() int { return value }))
        \\}
    ));
    try std.testing.expectEqualStrings(
        "anonymous functions cannot capture surrounding value 'value' yet",
        frontend.diagnostic.?.message,
    );
}

test "anonymous callbacks survive generic handle specialization" {
    const output = try run(
        \\protocol Task { func execute() }
        \\class Handle<T:Task> {
        \\    var task:T
        \\    public init(task:T) { self.task = task }
        \\    public func complete() T { return self.task }
        \\}
        \\func submit<T:Task>(task:T, callback:func(T)) Handle<T> {
        \\    callback(task)
        \\    return Handle<T>(task)
        \\}
        \\struct CheckTask:Task {
        \\    var name:str
        \\    func execute() {}
        \\}
        \\func main() {
        \\    var handle = submit(CheckTask(name:"callback-ran"), func(task:CheckTask) { print(task.name) })
        \\    handle.complete()
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("callback-ran\n", output);
}
