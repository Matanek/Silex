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
