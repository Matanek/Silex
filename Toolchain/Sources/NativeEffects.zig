const std = @import("std");
const builtin = @import("builtin");

const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Lower = @import("Arm64/Lower.zig");
const Runner = @import("Arm64/Runner.zig");
const MachO = @import("MacOS/MachO.zig");
const Project = @import("Project.zig");

fn compileAndRun(allocator: std.mem.Allocator, source: []const u8) !std.process.RunResult {
    var frontend = Frontend.Frontend.init(allocator);
    var compilation = try frontend.compile(source);
    compilation.ir.files = &.{"Main.sx"};
    const machine = try Lower.lower(allocator, compilation.ir);
    return runMachine(allocator, machine);
}

fn runMachine(allocator: std.mem.Allocator, machine: @import("Arm64/Machine.zig").Program) !std.process.RunResult {
    const bytes = try MachO.emit(allocator, machine);

    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const executable = try std.fs.path.join(allocator, &.{ base, "effects-app" });
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, executable, .{
        .permissions = .executable_file,
    });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, bytes);
    try file.setPermissions(std.testing.io, .executable_file);
    return std.process.run(allocator, std.testing.io, .{ .argv = &.{executable} });
}

fn exitCode(result: std.process.RunResult) u8 {
    return switch (result.term) {
        .exited => |code| code,
        else => 255,
    };
}

test "native recursive copy preserves detached graph topology" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\class Node {
        \\    private let secret:int
        \\    public var next:Node? = null
        \\    public init(secret:int) { self.secret = secret }
        \\    public func value() int { return self.secret }
        \\}
        \\class Special : Node {
        \\    public init(secret:int) : super(secret) {}
        \\    override public func value() int { return super.value() + 100 }
        \\}
        \\struct Graph { var first:Node; var again:Node; var values:Node[] }
        \\func main() {
        \\    var first:Node = Special(7)
        \\    var second = Node(8)
        \\    first.next = second
        \\    second.next = first
        \\    var graph = Graph(first:first, again:first, values:[first, second])
        \\    var detached = copy graph
        \\    if var next = detached.first.next { next.next = null }
        \\    print(detached.first == detached.again, " ", detached.first == detached.values[0])
        \\    print(detached.first != first, " ", detached.first.value(), " ", second.next != null)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native effects match the reference output" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func square(value:int) int { return value * value }
        \\func identity(value:str) str { return value }
        \\func main() {
        \\    print("Silex 🔥")
        \\    print(identity("A\0B"))
        \\    print("")
        \\    print(square(5))
        \\    print(-42)
        \\    print(-9223372036854775808)
        \\    print(9223372036854775807)
        \\    print(true)
        \\    print(false)
        \\    print(1 + 2 * 3 < 8 == true)
        \\    print(4 <= 4)
        \\    print(8 > 9)
        \\    print(8 >= 8)
        \\    print(1 != 2)
        \\    print(false == false)
        \\    assert(true, "must pass")
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native for iteration matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func main() {
        \\    let fixed:int[3] = [1, 2, 3]
        \\    for value in fixed { print(value) }
        \\    var values = [4, 5, 6]
        \\    for var value in values {
        \\        value += 10
        \\        if value == 15 { continue }
        \\    }
        \\    for value in values { print(value) }
        \\    for i in 2...-1 { print(i) }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native explicit moves match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func forward(value:int) int { return move value }
        \\func main() {
        \\    var source = 40
        \\    let first = move source
        \\    source = 2
        \\    print(first + forward(move source))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native read-reference parameters match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Box { let value:int; func get() int { return self.value } }
        \\func inspect(box:@Box, bonus:@int) int { return box.get() + bonus }
        \\func main() {
        \\    let box = Box(value:40)
        \\    let bonus = 2
        \\    print(inspect(box, bonus))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native mutable-reference parameters match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Box { var value:int }
        \\func update(first:&int, second:&int) { first += 1; second *= 2 }
        \\func main() {
        \\    var box = Box(value:20)
        \\    var values = [1, 2]
        \\    update(box.value, box.value)
        \\    update(values[1], values[0])
        \\    print(box.value, values[0], values[1])
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native borrowed returns match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct State { var value:int }
        \\struct Owner { var state:State }
        \\func inspect(owner:@Owner) @State { return owner.state }
        \\func edit(owner:&Owner) &State { return owner.state }
        \\func main() {
        \\    var owner = Owner(state:State(value:40))
        \\    if true { let view = inspect(owner); print(view.value) }
        \\    if true { var alias = edit(owner); alias.value += 2; print(alias.value) }
        \\    print(owner.state.value)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native owner drops match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct File { let descriptor:int; drop { print("drop ", self.descriptor) } }
        \\func main() {
        \\    var current = File(descriptor:1)
        \\    current = File(descriptor:2)
        \\    let source = File(descriptor:3)
        \\    let destination = move source
        \\    print("held")
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native generic function specializations match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func identity<T>(value:T) T { return value }
        \\func pair<Left, Right>(left:Left, right:Right) Right { return right }
        \\func main() {
        \\    print(identity(42))
        \\    print(identity<str>("Silex"))
        \\    print(pair(true, 7))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native generic structure specializations match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Pair<T> { let first:T; let second:T }
        \\func main() {
        \\    let numbers = Pair<int>(first:20, second:22)
        \\    let words = Pair<str>(first:"Si", second:"lex")
        \\    print(numbers.first + numbers.second)
        \\    print(words.first + words.second)
        \\    print(numbers == Pair<int>(first:20, second:22))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native generic enum specializations and match agree with the interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\enum Outcome<T, E> { success(T); failure(E) }
        \\func print_outcome(value:Outcome<int, str>) {
        \\    match value { success(number) => { print(number) }; failure(message) => { print(message) } }
        \\}
        \\func main() {
        \\    print_outcome(Outcome<int, str>.success(42))
        \\    print_outcome(Outcome<int, str>.failure("failed"))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native generic method specializations match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Counter {
        \\    var count:int
        \\    func keep<T>(value:T) T { self.count += 1; return value }
        \\}
        \\func main() {
        \\    var counter = Counter()
        \\    print(counter.keep(42))
        \\    print(counter.keep<str>("Silex"))
        \\    print(counter.count)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native intrinsic Result values match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func load(allowed:bool) Result<int, str> {
        \\    if allowed { return Result<int, str>.success(42) }
        \\    return Result<int, str>.failure("no")
        \\}
        \\func save() Result<void, str> { return Result<void, str>.success() }
        \\func main() {
        \\    match load(true) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match load(false) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match save() { success => { print("saved") }; failure(error) => { print(error) } }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native try propagation matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func read(allowed:bool) Result<int, str> {
        \\    if allowed { return Result<int, str>.success(40) }
        \\    return Result<int, str>.failure("denied")
        \\}
        \\func compute(allowed:bool) Result<int, str> {
        \\    let value = try read(allowed) + 2
        \\    return Result<int, str>.success(value)
        \\}
        \\func save(allowed:bool) Result<void, str> {
        \\    if allowed { return Result<void, str>.success() }
        \\    return Result<void, str>.failure("not saved")
        \\}
        \\func save_all(allowed:bool) Result<void, str> {
        \\    try save(allowed)
        \\    return Result<void, str>.success()
        \\}
        \\func main() {
        \\    match compute(true) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match compute(false) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match save_all(true) { success => { print("saved") }; failure(error) => { print(error) } }
        \\    match save_all(false) { success => { print("saved") }; failure(error) => { print(error) } }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native map_error transformation matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func convert(error:str) int { print("transform"); return error.count() }
        \\func load(allowed:bool) Result<int, str> {
        \\    if allowed { return Result<int, str>.success(42) }
        \\    return Result<int, str>.failure("bad")
        \\}
        \\func save(allowed:bool) Result<void, str> {
        \\    if allowed { return Result<void, str>.success() }
        \\    return Result<void, str>.failure("denied")
        \\}
        \\func main() {
        \\    match map_error(load(true), convert) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match map_error(load(false), convert) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match map_error(save(true), convert) { success => { print("saved") }; failure(error) => { print(error) } }
        \\    match map_error(save(false), convert) { success => { print("saved") }; failure(error) => { print(error) } }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native recoverable main matches the exact process boundary" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    const Case = struct { source: []const u8, exit_code: u8, stdout: []const u8 = "", stderr: []const u8 };
    const cases = [_]Case{
        .{ .source = "func main() Result<void,str> { return Result<void,str>.success() }", .exit_code = 0, .stderr = "" },
        .{ .source = "func main() Result<void,str> { print(\"before\"); return Result<void,str>.failure(\"configuration missing\") }", .exit_code = 1, .stdout = "before\n", .stderr = "error: configuration missing\n" },
        .{ .source = "func main() Result<void,str> { return Result<void,str>.failure(\"\") }", .exit_code = 1, .stderr = "error: \n" },
        .{ .source = "func main() Result<void,str> { return Result<void,str>.failure(\"échec 🔥\") }", .exit_code = 1, .stderr = "error: échec 🔥\n" },
        .{ .source = "func main() Result<void,str> { return Result<void,str>.failure(\"line\\n\") }", .exit_code = 1, .stderr = "error: line\n\n" },
    };
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const native = try compileAndRun(arena.allocator(), case.source);
        try std.testing.expectEqual(case.exit_code, exitCode(native));
        try std.testing.expectEqualSlices(u8, case.stdout, native.stdout);
        try std.testing.expectEqualSlices(u8, case.stderr, native.stderr);
    }
}

test "native fixed arrays match reference reads writes copies and bounds" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const sources = [_][]const u8{
        \\func changed(values:int[3]) int[3] { var duplicate = values; duplicate[0] = 9; return duplicate }
        \\func main() { var values:int[3] = [1, 2, 3]; let duplicate = changed(values); values[-1] += 4; print(values[0], values[-1], duplicate[0], duplicate[2]) }
        ,
        "func main() { let values:int[3] = [1, 2, 3]; print(values[-4]) }",
    };
    for (sources) |source| {
        var frontend = Frontend.Frontend.init(allocator);
        var compilation = try frontend.compile(source);
        compilation.ir.files = &.{"Main.sx"};
        const reference = try Interpreter.runCapture(allocator, compilation.ir);
        const native = try runMachine(allocator, try Lower.lower(allocator, compilation.ir));
        try std.testing.expectEqual(reference.exit_code, exitCode(native));
        try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
        try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
    }
}

test "native dynamic lists match reference construction copies and bounds" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const sources = [_][]const u8{
        "func changed(values:int[]) int[] { var duplicate = values; duplicate[0] = 9; return duplicate } func main() { let values = [1, 2, 3]; let duplicate = changed(values); print(values.count(), values[-1], duplicate[0]) }",
        "func main() { let values = [1, 2]; print(values[-3]) }",
    };
    for (sources) |source| {
        var frontend = Frontend.Frontend.init(allocator);
        var compilation = try frontend.compile(source);
        compilation.ir.files = &.{"Main.sx"};
        const reference = try Interpreter.runCapture(allocator, compilation.ir);
        const native = try runMachine(allocator, try Lower.lower(allocator, compilation.ir));
        try std.testing.expectEqual(reference.exit_code, exitCode(native));
        try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
        try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
    }
}

test "native collection mutations match the reference" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func main() {
        \\    var fixed:int[3] = [1, 2, 3]; fixed.replace(1, 8); fixed.swap(0, -1); fixed.reverse()
        \\    var values = [1, 2, 3]; let duplicate = values; values.replace(1, 8); values.swap(0, -1); values.reverse()
        \\    print(values[0], values[1], values[2])
        \\    values.append(4); values.append([5, 6]); values.prepend(0); values.insert(2, 7)
        \\    print(values[0], values[1], values[2], values[3], values[-1])
        \\    let removed = values.take(3); let first = values.take_first(); let last = values.take_last(); values.reverse()
        \\    print(fixed[0], fixed[1], fixed[2], " ", removed, first, last, " ", values.count(), values[0], values[-1], " ", duplicate[1])
        \\    values.clear(); print(values.count(), values.is_empty())
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    var compilation = try frontend.compile(source);
    compilation.ir.files = &.{"Main.sx"};
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const native = try runMachine(allocator, try Lower.lower(allocator, compilation.ir));
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native copied slices match the reference" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func main() {
        \\    let fixed:int[5] = [0, 1, 2, 3, 4]; let middle:int[] = fixed[1:4]
        \\    let values = [10, 20, 30, 40, 50]; let negative = values[-4:-1]; let clamped = values[-99:99]; let inverse = values[4:2]
        \\    print(middle.count(), middle[0], middle[-1], " ", negative[0], negative[-1], " ", clamped.count(), clamped[0], clamped[-1], " ", inverse.count())
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    var compilation = try frontend.compile(source);
    compilation.ir.files = &.{"Main.sx"};
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const native = try runMachine(allocator, try Lower.lower(allocator, compilation.ir));
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native optional transport matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Box { let value:int? }
        \\func accept(value:int?) int { return 42 }
        \\func make() int? { return 7 }
        \\func main() {
        \\    print(accept(null))
        \\    print(accept(make()))
        \\    print(accept(Box(value:9).value))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native optional equality and refinement match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Position { let x:int }
        \\func inspect(position:Position?) {
        \\    print(position == null)
        \\    if null != position { print(position.x) }
        \\}
        \\func main() {
        \\    let absent:int?
        \\    let present:int? = 7
        \\    let first:Position? = Position(x:42)
        \\    let second:Position? = Position(x:42)
        \\    print(absent == null)
        \\    print(present != null)
        \\    print(first == second)
        \\    inspect(Position(x:42))
        \\    inspect(null)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native conditional optional bindings match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func observed(value:int?) int? { print("source"); return value }
        \\func main() {
        \\    if value = observed(40) { print(value + 2) }
        \\    var next:int? = 7
        \\    while var item = observed(next) {
        \\        item += 1
        \\        print(item)
        \\        next = null
        \\        continue
        \\    }
        \\    next = 9
        \\    while item = observed(next) { print(item); break }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native safe optional access matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Position {
        \\    var x:int
        \\    func shifted(delta:int) int { return self.x + delta }
        \\    func translate(delta:int) { self.x += delta }
        \\}
        \\func argument() int { print("argument"); return 2 }
        \\func observed(value:Position?) Position? { print("receiver"); return value }
        \\func main() {
        \\    var position:Position? = Position(x:40)
        \\    let absent:Position?
        \\    if value = position?.shifted(argument()) { print(value) }
        \\    observed(absent)?.shifted(argument())
        \\    position?.translate(2)
        \\    if updated = position { print(updated.x) }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native associated enum transport matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\enum Message { empty; text(str); pair(int, bool) }
        \\struct Box { let message:Message }
        \\func accept(value:Message) int { return 42 }
        \\func relay(value:Message) Message { return value }
        \\func main() {
        \\    print(accept(Message.empty()))
        \\    print(accept(relay(Message.text("hello"))))
        \\    print(accept(Box(message:Message.pair(7, true)).message))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native exhaustive enum matches agree with the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\enum Message { empty; text(str); pair(int, bool) }
        \\func describe(value:Message) str {
        \\    return match value {
        \\        empty => "empty"
        \\        text(content) => content
        \\        pair(number, enabled) => "pair"
        \\    }
        \\}
        \\func compact(value:Message) str {
        \\    return match value { empty => "empty"; else => "other" }
        \\}
        \\func show(value:Message) {
        \\    match value { empty => { print("none") }; text(content) => { print(content) }; else => { print("pair") } }
        \\}
        \\func main() {
        \\    print(describe(Message.empty()))
        \\    print(describe(Message.text("hello")))
        \\    print(describe(Message.pair(42, true)))
        \\    print(compact(Message.text("hello")))
        \\    show(Message.empty())
        \\    show(Message.pair(1, false))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native raw enum values agree with the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\enum Status:int { ready = 42; failed = -7 }
        \\enum Label:str { ready = "ready"; failed = "failed\nagain" }
        \\func status(value:Status) int { return value.raw_value }
        \\func label(value:Label) str { return value.raw_value }
        \\func main() {
        \\    print(status(Status.ready()))
        \\    print(status(Status.failed()))
        \\    print(label(Label.ready()))
        \\    print(label(Label.failed()))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native branches and short-circuit match the reference output" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func observed() bool { print("evaluated"); return true }
        \\func classify(value:int) int {
        \\    if value < 0 { return -1 }
        \\    elif value == 0 { return 0 }
        \\    else { return 1 }
        \\}
        \\func main() {
        \\    if false && observed() { print("bad") }
        \\    else if true || observed() { print(classify(42)) }
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native mutable locals match every current reference value family" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func main() {
        \\    var narrow:int8
        \\    var wide:uint64
        \\    var decimal:float64
        \\    var enabled:bool
        \\    var message:str
        \\    narrow = -8
        \\    wide = 18446744073709551615
        \\    decimal = 2.5
        \\    enabled = true
        \\    message = "mutable 🔥"
        \\    if enabled { narrow = 42 }
        \\    print(narrow, " ", wide, " ", decimal, " ", enabled, " ", message)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native while backedges break and continue match the reference" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func main() {
        \\    var untouched = 7
        \\    while false { untouched = 0 }
        \\    var outer = 0
        \\    var score = 0
        \\    while outer < 3 {
        \\        outer = outer + 1
        \\        var inner = 0
        \\        while inner < 4 {
        \\            inner = inner + 1
        \\            if inner == 2 { continue }
        \\            if inner == 4 { break }
        \\            score = score + 1
        \\        }
        \\    }
        \\    print(untouched, " ", outer, " ", score)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native integer families preserve signedness widths and decimal output" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func preserve(value:uint16) uint16 { return value }
        \\func main() {
        \\    let minimum:int8 = -128
        \\    let maximum:uint = 18446744073709551615
        \\    let flags:uint8 = 0x81
        \\    print(minimum)
        \\    print(maximum)
        \\    print(maximum > 1)
        \\    print(preserve(65535))
        \\    print(flags >> 7)
        \\    print(flags & (0xf0 as uint8))
        \\    print(flags ^ (0xff as uint8))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native integer widening and checked conversions match the reference" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func sum(left:int8, right:int32) int32 { return left + right }
        \\func main() {
        \\    print(sum(-2, 44))
        \\    print(255 as uint8)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);

    const invalid_source = "func main() { print(256 as uint8) }";
    var invalid_frontend = Frontend.Frontend.init(allocator);
    var invalid_compilation = try invalid_frontend.compile(invalid_source);
    invalid_compilation.ir.files = &.{"Main.sx"};
    const invalid_reference = try Interpreter.runCapture(allocator, invalid_compilation.ir);
    const invalid_native = try compileAndRun(allocator, invalid_source);
    try std.testing.expectEqual(invalid_reference.exit_code, exitCode(invalid_native));
    try std.testing.expectEqualSlices(u8, invalid_reference.stderr, invalid_native.stderr);
}

test "native floating arithmetic preserves float64 bits" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func average(left:float64, right:float64) float64 { return (left + right) / 2.0 }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    const left_bits: u64 = @bitCast(@as(f64, 1.5));
    const right_bits: u64 = @bitCast(@as(f64, 2.5));
    const native = try Runner.invoke(allocator, machine, 0, &.{ @bitCast(left_bits), @bitCast(right_bits) });
    try std.testing.expectEqual(@import("Arm64/Machine.zig").Status.success, native.status);
    try std.testing.expectEqual(@as(f64, 2.0), @as(f64, @bitCast(@as(u64, @bitCast(native.value)))));
}

test "native float printing matches decimal reference for IEEE edge values" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func average(left:float64, right:float64) float64 { return (left + right) / 2.0 }
        \\func echo32(value:float32) float32 { return value }
        \\func main() {
        \\    let zero:float64 = 0.0
        \\    let tiny32:float32 = 1e-45
        \\    print(average(1.5, 2.5))
        \\    print(echo32(tiny32))
        \\    print(5e-324)
        \\    print(1.7976931348623157e308)
        \\    print(zero)
        \\    print(-zero)
        \\    print(1.0 / zero)
        \\    print(-1.0 / zero)
        \\    print(zero / zero)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native string operations match value semantics and Unicode scalar counts" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func observed(value:str) str { print(value); return value }
        \\func join(left:str, right:str) str { return left + right }
        \\func retain(value:str) str { return "[" + value + "]" }
        \\func main() {
        \\    let ordered = observed("left") + observed("right")
        \\    let nested = retain(join(ordered, "!"))
        \\    print(nested)
        \\    print("Aé🔥".count())
        \\    print("A\0B".count())
        \\    print("A\0B" == join("A\0", "B"))
        \\    print("é" == "é")
        \\    print("" + nested == nested + "")
        \\    print(join("0123456789012345678901234567890123456789", "abcdefghij"))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native interpolation and variadic print match the reference" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func observed(value:int) int { print("observed"); return value }
        \\func identity(value:str) str { return value }
        \\func main() {
        \\    let value = 21
        \\    let minimum:int = -9223372036854775808
        \\    let maximum:uint = 18446744073709551615
        \\    let zero:float64 = 0.0
        \\    print("Before ", observed(value), ": $(value * 2), $(true), $(1.5), $$(value)")
        \\    print("Edges: $(minimum), $(maximum), $(-zero), $(1.0 / zero), $(identity("ok"))")
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native concatenation owns large results across function returns" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const left = try allocator.alloc(u8, 4096);
    const right = try allocator.alloc(u8, 4096);
    @memset(left, 'a');
    @memset(right, 'b');
    const source = try std.fmt.allocPrint(
        allocator,
        "func join(left:str, right:str) str {{ return left + right }} " ++
            "func retain(value:str) str {{ return join(value, \"!\") }} " ++
            "func main() {{ let value = retain(join(\"{s}\", \"{s}\")); " ++
            "print(value.count()); print(value == join(join(\"{s}\", \"{s}\"), \"!\")) }}",
        .{ left, right, left, right },
    );
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native recursive resource destruction matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Leaf { let id:int; drop { print("leaf ", self.id) } }
        \\struct Pair { let first:Leaf; let second:Leaf; drop { print("pair") } }
        \\enum Choice { empty; filled(Leaf, Leaf) }
        \\func main() {
        \\    let pair = Pair(first:Leaf(id:1), second:Leaf(id:2))
        \\    let choice = Choice.filled(Leaf(id:3), Leaf(id:4))
        \\    if true { let branch = Leaf(id:5); print("branch") }
        \\    print("end")
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native explicit collection transfers match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct File { var id:int; drop { print("drop ", self.id) } }
        \\func main() {
        \\    var files:File[] = []
        \\    let file = File(id:1)
        \\    files.append(move file)
        \\    files.append(File(id:2))
        \\    for var current in files { current.id += 10 }
        \\    let removed = files.take_first()
        \\    print("removed ", removed.id)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native borrowed views match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func sum(values:@int[..]) int { return values[0] + values[-1] }
        \\func tail(values:&int[..]) &values:int[..] { return &values[1:values.count()] }
        \\func main() {
        \\    var fixed:int[5] = [0, 1, 2, 3, 4]
        \\    if true {
        \\        var middle = &fixed[1:4]
        \\        middle[0] = 8
        \\        middle.swap(1, -1)
        \\    }
        \\    var values = [10, 20, 30, 40]
        \\    let copied = values
        \\    print(sum(@values[1:4]))
        \\    if true {
        \\        var rest = tail(&values[0:4])
        \\        rest[1] = 99
        \\    }
        \\    print(fixed[1], fixed[2], fixed[3], " ", values[2], " ", copied[2])
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native class identity matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\class Counter {
        \\    private var value:int
        \\    public init(start:int = 0) { self.value = start }
        \\    public func increment() { self.value++ }
        \\    public func current() int { return self.value }
        \\}
        \\struct Holder { public var counter:Counter }
        \\func update(counter:Counter) Counter { counter.increment(); return counter }
        \\func main() {
        \\    var first = Counter()
        \\    var alias = first
        \\    alias.increment()
        \\    var returned = update(first)
        \\    var holder = Holder(counter:first)
        \\    holder.counter.increment()
        \\    var values:Counter[] = [first]
        \\    values[0].increment()
        \\    print(first.current(), " ", first == alias, " ", returned == holder.counter, " ", first != Counter())
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native class parameter modes match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\class Counter { public var value:int }
        \\func inspect(counter:@Counter) int { return counter.value }
        \\func modify(counter:Counter) { counter.value = 10 }
        \\func replace(counter:&Counter) { counter = Counter(value:20) }
        \\func main() {
        \\    var first = Counter(value:1)
        \\    var alias = first
        \\    modify(first)
        \\    replace(alias)
        \\    print(inspect(first), " ", inspect(alias), " ", first == alias)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native drop structures use ordinary compositional copies" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Item { var value:int; drop { print("drop ", self.value) } }
        \\func duplicate(value:Item) Item { return value }
        \\func main() {
        \\    var first = Item(value:1)
        \\    var second = first
        \\    second.value = 2
        \\    let returned = duplicate(first)
        \\    let values:Item[] = [first]
        \\    let copies = values
        \\    print(first.value, " ", second.value, " ", returned.value, " ", copies[0].value)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native class inheritance matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\class Entity {
        \\    protected var value:int
        \\    public init(value:int) { self.value = value }
        \\    public func current() int { return self.value }
        \\}
        \\class Counter : Entity {
        \\    public init(value:int) : super(value) {}
        \\    public func increment() { self.value++ }
        \\}
        \\func base(value:Counter) Entity { return value }
        \\func main() {
        \\    var counter = Counter(8)
        \\    var alias:Entity = counter
        \\    counter.increment()
        \\    print(alias.current(), " ", alias == base(counter))
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native class overrides match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\class Entity {
        \\    protected var count:int = 0
        \\    public func label() str { return "entity" }
        \\    public func bump() { self.count++ }
        \\    public func current() int { return self.count }
        \\}
        \\class Player : Entity {
        \\    override public func label() str { return "$(super.label()) player" }
        \\    override public func bump() { super.bump(); super.bump() }
        \\}
        \\class Captain : Player { override public func label() str { return "captain" } }
        \\func label(value:Entity) str { return value.label() }
        \\func bump(value:Entity) { value.bump() }
        \\func main() {
        \\    var player = Player()
        \\    var captain = Captain()
        \\    bump(player)
        \\    print(label(player), " ", label(captain))
        \\    print(player.current())
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native static storage matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\static class Counter {
        \\    public static var total:int = 4
        \\    public static func add(value:int) int { Counter.total += value; return Counter.total }
        \\}
        \\func main() { print(Counter.total, " ", Counter.add(3), " ", Counter.total) }
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native nested types match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Api { struct Entry { let value:int } }
        \\class Box { public class Item { public var value:int } }
        \\func main() {
        \\    let entry = Api.Entry(value:20)
        \\    var item = Box.Item(value:22)
        \\    print(entry.value + item.value)
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native class drop matches the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Resource { let name:str; drop { print("resource ", self.name) } }
        \\class Base { drop { print("base") } }
        \\class Owner : Base {
        \\    public let resource:Resource
        \\    public init(name:str) : super() { self.resource = Resource(name:name) }
        \\    drop { print("owner") }
        \\}
        \\class Tracer { drop { print("static") } }
        \\static class Roots { public static var current:Tracer? = null }
        \\func main() {
        \\    var owner = Owner("native")
        \\    if true { var alias = owner; print(alias.resource.name) }
        \\    var upcast:Base = Owner("upcast")
        \\    Roots.current = Tracer()
        \\    Roots.current = null
        \\    var values:Tracer[] = [Tracer(), Tracer()]
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native generic classes match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\class Base<T> {
        \\    public let value:T
        \\    public init(value:T) { self.value = value }
        \\    public func get() T { return self.value }
        \\    drop { print("base") }
        \\}
        \\class Child<T> : Base<T> {
        \\    public init(value:T) : super(value) {}
        \\    override public func get() T { return self.value }
        \\    drop { print("child") }
        \\}
        \\func read(value:Base<int>) int { return value.get() }
        \\func main() {
        \\    var integer:Base<int> = Child<int>(42)
        \\    var text = Base<str>("Silex")
        \\    print(read(integer), " ", text.get())
        \\}
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native constrained generics match the reference interpreter" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\protocol Named { func name() str }
        \\struct Item : Named { func name() str { return "native" } }
        \\class Entity : Named { public func name() str { return "class" } }
        \\func label<T : Named>(value:T) str { return value.name() }
        \\func main() { let item = Item(); var entity = Entity(); print(label(item), " ", label(entity)) }
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native checked float conversion returns an exact integer" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func whole(value:float64) int16 { return value as int16 }
        \\func main() { print(whole(12.0)) }
    ;
    var frontend = Frontend.Frontend.init(allocator);
    const reference = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    const native = try compileAndRun(allocator, source);
    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
}

test "native assert and panic preserve diagnostics and exit status" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const assertion =
        \\func main() {
        \\    print("before")
        \\    assert(false, "planned failure")
        \\    print("after")
        \\}
    ;
    const failed = try compileAndRun(allocator, assertion);
    try std.testing.expectEqual(@as(u8, 1), exitCode(failed));
    try std.testing.expectEqualStrings("before\n", failed.stdout);
    try std.testing.expectEqualStrings(
        "Main.sx:3:5: runtime error: assertion failed: planned failure\n",
        failed.stderr,
    );

    const panicked = try compileAndRun(allocator,
        \\func message() str { return "literal panic" }
        \\func value() int { panic(message()) }
        \\func main() { value() }
    );
    try std.testing.expectEqual(@as(u8, 1), exitCode(panicked));
    try std.testing.expectEqualStrings("", panicked.stdout);
    try std.testing.expectEqualStrings(
        "Main.sx:2:20: runtime error: literal panic\n",
        panicked.stderr,
    );
}

test "package effects keep their real source path in both execution paths" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();

    try temporary.dir.createDirPath(std.testing.io, "Fault/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Fault.Failure
        \\func main() {
        \\    print("before package")
        \\    Failure.fail()
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Fault/Package.json",
        .data = "{\"name\":\"Fault\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Fault/Module/Failure.sx",
        .data = "public func fail() { panic(\"package failure\") }",
    });

    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const native = try runMachine(allocator, try Lower.lower(allocator, compilation.ir));

    try std.testing.expectEqual(reference.exit_code, exitCode(native));
    try std.testing.expectEqualSlices(u8, reference.stdout, native.stdout);
    try std.testing.expectEqualSlices(u8, reference.stderr, native.stderr);
    try std.testing.expect(std.mem.indexOf(u8, native.stderr, "Fault/Module/Failure.sx:1:22") != null);
}
