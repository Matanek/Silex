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
        \\func changed(values:int[3]) int[3] { var copy = values; copy[0] = 9; return copy }
        \\func main() { var values:int[3] = [1, 2, 3]; let copy = changed(values); values[-1] += 4; print(values[0], values[-1], copy[0], copy[2]) }
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
        "func changed(values:int[]) int[] { var copy = values; copy[0] = 9; return copy } func main() { let values = [1, 2, 3]; let copy = changed(values); print(values.count(), values[-1], copy[0]) }",
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
        \\    var values = [1, 2, 3]; let copy = values; values.replace(1, 8); values.swap(0, -1); values.reverse()
        \\    print(values[0], values[1], values[2])
        \\    values.append(4); values.append([5, 6]); values.prepend(0); values.insert(2, 7)
        \\    print(values[0], values[1], values[2], values[3], values[-1])
        \\    let removed = values.take(3); let first = values.take_first(); let last = values.take_last(); values.reverse()
        \\    print(fixed[0], fixed[1], fixed[2], " ", removed, first, last, " ", values.count(), values[0], values[-1], " ", copy[1])
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
