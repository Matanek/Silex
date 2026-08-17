const std = @import("std");
const builtin = @import("builtin");

const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");
const Lower = @import("Lower.zig");
const Machine = @import("Machine.zig");
const Numeric = @import("../Numeric.zig");
const Runner = @import("Runner.zig");

const Allocator = std.mem.Allocator;

fn compare(
    allocator: Allocator,
    ir: Ir.Program,
    machine: Machine.Program,
    function_name: []const u8,
    arguments: []const Interpreter.Value,
) !void {
    const function = findFunction(ir, function_name) orelse return error.TestUnexpectedResult;

    var native_arguments = [_]i64{0} ** Machine.max_register_arguments;
    for (arguments, 0..) |argument, index| {
        native_arguments[index] = switch (argument) {
            .integer => |value| value,
            .typed_integer => |value| if (value.type.isSignedInteger()) value.signed() else @bitCast(value.bits),
            .float32 => |value| @bitCast(@as(u64, @as(u32, @bitCast(value)))),
            .float64 => |value| @bitCast(@as(u64, @bitCast(value))),
            .boolean => |value| @intFromBool(value),
            .string => return error.UnsupportedType,
            .structure => return error.UnsupportedType,
            .class => return error.UnsupportedType,
            .protocol => return error.UnsupportedType,
            .view => return error.UnsupportedType,
            .enumeration => return error.UnsupportedType,
            .optional => return error.UnsupportedType,
            .reference => return error.UnsupportedType,
            .function => return error.UnsupportedType,
            .void => return error.TestUnexpectedResult,
        };
    }
    const native = try Runner.invoke(allocator, machine, function, native_arguments[0..arguments.len]);

    const reference = Interpreter.invoke(allocator, ir, function, arguments) catch |err| {
        const expected: Machine.Status = switch (err) {
            error.IntegerOverflow => .integer_overflow,
            error.DivisionByZero => .division_by_zero,
            error.InvalidShift => .integer_overflow,
            else => return err,
        };
        try std.testing.expectEqual(expected, native.status);
        return;
    };

    try std.testing.expectEqual(Machine.Status.success, native.status);
    switch (reference) {
        .integer => |value| try std.testing.expectEqual(value, native.value),
        .typed_integer => |value| try std.testing.expectEqual(
            if (value.type.isSignedInteger()) value.signed() else @as(i64, @bitCast(value.bits)),
            native.value,
        ),
        .float32 => |value| try std.testing.expectEqual(
            @as(u32, @bitCast(value)),
            @as(u32, @truncate(@as(u64, @bitCast(native.value)))),
        ),
        .float64 => |value| try std.testing.expectEqual(
            @as(u64, @bitCast(value)),
            @as(u64, @bitCast(native.value)),
        ),
        .boolean => |value| try std.testing.expectEqual(@as(i64, @intFromBool(value)), native.value),
        .string => return error.UnsupportedType,
        .structure => return error.UnsupportedType,
        .class => return error.UnsupportedType,
        .protocol => return error.UnsupportedType,
        .view => return error.UnsupportedType,
        .enumeration => return error.UnsupportedType,
        .optional => return error.UnsupportedType,
        .reference => return error.UnsupportedType,
        .function => return error.UnsupportedType,
        .void => try std.testing.expectEqual(@as(i64, 0), native.value),
    }
}

fn findFunction(program: Ir.Program, name: []const u8) ?Ir.FunctionId {
    for (program.functions, 0..) |function, id| {
        if (std.mem.eql(u8, function.name, name)) return id;
    }
    return null;
}

test "native ARM64 agrees with the reference interpreter on fundamental values" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func constant() int { return 42 }
        \\func arithmetic(left:int, right:int) int {
        \\    return ((left + right) * 3 - 2) / 2 % 11
        \\}
        \\func nested() int { return arithmetic(7, 4) + constant() }
        \\func negate(value:int) int { return -value }
        \\func echo(flag:bool) bool { return flag }
        \\func exactRemainder() int { return -9223372036854775808 % -1 }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);

    try compare(allocator, compilation.ir, machine, "constant", &.{});
    try compare(allocator, compilation.ir, machine, "arithmetic", &.{
        .{ .integer = 7 },
        .{ .integer = 4 },
    });
    try compare(allocator, compilation.ir, machine, "nested", &.{});
    try compare(allocator, compilation.ir, machine, "negate", &.{.{ .integer = -7 }});
    try compare(allocator, compilation.ir, machine, "echo", &.{.{ .boolean = true }});
    try compare(allocator, compilation.ir, machine, "echo", &.{.{ .boolean = false }});
    try compare(allocator, compilation.ir, machine, "exactRemainder", &.{});
}

test "native ARM64 release preserves floats returned from list-contained aggregates" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\public struct Clip {
        \\    public let name:str
        \\    public let frames:int[]
        \\    public let rate:float
        \\    public init(name:str, frames:int[], rate:float) {
        \\        self.name = name
        \\        self.frames = frames
        \\        self.rate = rate
        \\    }
        \\    public func fps() float { return self.rate }
        \\}
        \\public struct Sheet {
        \\    public var clips:Clip[]
        \\    public init() { self.clips = [] }
        \\    public func clip(name:str, rate:float) {
        \\        self.clips.append(Clip(name, [0, 1, 2], rate))
        \\    }
        \\    public func require(name:str) Clip {
        \\        for clip in self.clips {
        \\            if clip.name == name { return clip }
        \\        }
        \\        panic("missing")
        \\    }
        \\}
        \\public class Entry {
        \\    public let sheet:Sheet
        \\    public init(sheet:Sheet) { self.sheet = sheet }
        \\}
        \\public class Store {
        \\    public var entries:Entry[]
        \\    public init() { self.entries = [] }
        \\    public func add(sheet:Sheet) { self.entries.append(Entry(sheet)) }
        \\    public func get() @Sheet { return self.entries[0].sheet }
        \\}
        \\func read_rate() float {
        \\    var store = Store()
        \\    store.add(Sheet()..clip("idle", 4.0)..clip("move", 10.0))
        \\    let sheet = store.get()
        \\    let clip = sheet.require("idle")
        \\    return clip.fps()
        \\}
        \\func main() {}
    );
    const machine = try Lower.lowerWithMode(allocator, compilation.ir, .release);
    try compare(allocator, compilation.ir, machine, "read_rate", &.{});
}

test "native ARM64 agrees with indexed array and list iteration" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func indexed_total() int {
        \\    let fixed:int[3] = [1, 2, 3]
        \\    let values = [4, 5]
        \\    var total = 0
        \\    for index, item in fixed.indexed() { total += index * 10 + item }
        \\    for index, item in values.indexed() { total += index * 10 + item }
        \\    return total
        \\}
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "indexed_total", &.{});
}

test "native ARM64 agrees with checked arithmetic failures" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func addOverflow() int { return 9223372036854775807 + 1 }
        \\func subtractOverflow() int { return -9223372036854775808 - 1 }
        \\func multiplyOverflow() int { return 9223372036854775807 * 2 }
        \\func divideByZero() int { return 42 / 0 }
        \\func remainderByZero() int { return 42 % 0 }
        \\func divideOverflow() int { return -9223372036854775808 / -1 }
        \\func negateOverflow() int {
        \\    let minimum = -9223372036854775808
        \\    return -minimum
        \\}
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);

    try compare(allocator, compilation.ir, machine, "addOverflow", &.{});
    try compare(allocator, compilation.ir, machine, "subtractOverflow", &.{});
    try compare(allocator, compilation.ir, machine, "multiplyOverflow", &.{});
    try compare(allocator, compilation.ir, machine, "divideByZero", &.{});
    try compare(allocator, compilation.ir, machine, "remainderByZero", &.{});
    try compare(allocator, compilation.ir, machine, "divideOverflow", &.{});
    try compare(allocator, compilation.ir, machine, "negateOverflow", &.{});
}

test "native ARM64 agrees on compound updates and their failures" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func update() int8 {
        \\    var value:int8 = 10
        \\    value += 2
        \\    value *= 3
        \\    value -= 6
        \\    value /= 3
        \\    value++
        \\    value--
        \\    return value
        \\}
        \\func overflow() int { var value = 9223372036854775807; value++; return value }
        \\func divideByZero() int { var value = 42; value /= 0; return value }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "update", &.{});
    try compare(allocator, compilation.ir, machine, "overflow", &.{});
    try compare(allocator, compilation.ir, machine, "divideByZero", &.{});
}

test "native ARM64 agrees on narrow and unsigned integer domains" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func add8(left:int8, right:int8) int8 { return left + right }
        \\func subtract8(left:uint8, right:uint8) uint8 { return left - right }
        \\func shift(value:uint8, count:int8) uint8 { return value << count }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "add8", &.{
        .{ .typed_integer = Numeric.fromMagnitude(120, false, .int8) },
        .{ .typed_integer = Numeric.fromMagnitude(7, false, .int8) },
    });
    try compare(allocator, compilation.ir, machine, "add8", &.{
        .{ .typed_integer = Numeric.fromMagnitude(120, false, .int8) },
        .{ .typed_integer = Numeric.fromMagnitude(8, false, .int8) },
    });
    try compare(allocator, compilation.ir, machine, "subtract8", &.{
        .{ .typed_integer = Numeric.fromMagnitude(0, false, .uint8) },
        .{ .typed_integer = Numeric.fromMagnitude(1, false, .uint8) },
    });
    try compare(allocator, compilation.ir, machine, "shift", &.{
        .{ .typed_integer = Numeric.fromMagnitude(1, false, .uint8) },
        .{ .typed_integer = Numeric.fromMagnitude(8, false, .int8) },
    });
}

test "native ARM64 preserves IEEE arithmetic comparisons arguments and returns" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func identity32(value:float32) float32 { return value }
        \\func identity64(value:float64) float64 { return value }
        \\func arithmetic32(left:float32, right:float32) float32 { return left * right + left / right }
        \\func arithmetic64(left:float64, right:float64) float64 { return left * right + left / right }
        \\func less32(left:float32, right:float32) bool { return left < right }
        \\func unequal64(left:float64, right:float64) bool { return left != right }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "arithmetic32", &.{
        .{ .float32 = 1.25 },
        .{ .float32 = 3.5 },
    });
    try compare(allocator, compilation.ir, machine, "arithmetic64", &.{
        .{ .float64 = 1.0e-300 },
        .{ .float64 = 2.0 },
    });
    try compare(allocator, compilation.ir, machine, "identity32", &.{.{ .float32 = @bitCast(@as(u32, 1)) }});
    try compare(allocator, compilation.ir, machine, "identity64", &.{.{ .float64 = -0.0 }});
    try compare(allocator, compilation.ir, machine, "identity64", &.{.{ .float64 = std.math.inf(f64) }});
    try compare(allocator, compilation.ir, machine, "identity64", &.{.{ .float64 = std.math.nan(f64) }});
    try compare(allocator, compilation.ir, machine, "less32", &.{
        .{ .float32 = std.math.nan(f32) },
        .{ .float32 = 1.0 },
    });
    try compare(allocator, compilation.ir, machine, "unequal64", &.{
        .{ .float64 = std.math.nan(f64) },
        .{ .float64 = 1.0 },
    });
}

test "native ARM64 release preserves branched float accumulator recurrences" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func accumulate(limit:int) float {
        \\    var center_x = 0.0
        \\    var center_y = 0.0
        \\    var heading_x = 0.0
        \\    var heading_y = 0.0
        \\    var separation_x = 0.0
        \\    var separation_y = 0.0
        \\    for index in 0...limit {
        \\        let sample_x = (index % 17) as float * 7.0
        \\        let sample_y = (index % 13) as float * 5.0
        \\        let offset_x = 40.0 - sample_x
        \\        let offset_y = 30.0 - sample_y
        \\        let distance_squared = offset_x * offset_x + offset_y * offset_y
        \\        if distance_squared > 0.0 && distance_squared < 5_184.0 {
        \\            center_x += sample_x
        \\            center_y += sample_y
        \\            heading_x += sample_x + 55.0
        \\            heading_y += sample_y - 8.0
        \\            if distance_squared < 784.0 {
        \\                var divisor = 1.0
        \\                if distance_squared > 1.0 { divisor = distance_squared }
        \\                separation_x += offset_x / divisor
        \\                separation_y += offset_y / divisor
        \\            }
        \\        }
        \\    }
        \\    return center_x + center_y + heading_x + heading_y + separation_x + separation_y
        \\}
        \\func main() {}
    );
    const machine = try Lower.lowerWithMode(allocator, compilation.ir, .release);
    for ([_]i64{ 0, 1, 32, 257 }) |limit| {
        try compare(allocator, compilation.ir, machine, "accumulate", &.{.{ .integer = limit }});
    }
}

test "native ARM64 release initializes resident float aggregate parameters" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Point { let x:float; let y:float }
        \\func distance_squared(current:Point, sample:Point) float {
        \\    let offset_x = current.x - sample.x
        \\    let offset_y = current.y - sample.y
        \\    return offset_x * offset_x + offset_y * offset_y
        \\}
        \\func paired_parameter() float {
        \\    return distance_squared(
        \\        Point(x:37.25, y:-12.5),
        \\        Point(x:-8.75, y:19.0)
        \\    )
        \\}
        \\func main() {}
    );
    const machine = try Lower.lowerWithMode(allocator, compilation.ir, .release);
    try compare(allocator, compilation.ir, machine, "paired_parameter", &.{});
}

test "native ARM64 transports and compares flattened structure values" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Empty {}
        \\struct Scalars {
        \\    var i8:int8
        \\    var i16:int16
        \\    var i32:int32
        \\    var i:int
        \\    var u8:uint8
        \\    var u16:uint16
        \\    var u32:uint32
        \\    var u:uint
        \\    var f:float
        \\    var f64:float64
        \\    var flag:bool
        \\    var text:str
        \\}
        \\struct Nested { var left:Scalars; var right:Scalars }
        \\func emptyIdentity(value:Empty) Empty { return value }
        \\func identity(value:Nested) Nested { return value }
        \\func sample() Scalars {
        \\    return Scalars(i8:-8, i16:-16, i32:-32, i:-64, u8:8, u16:16, u32:32, u:18446744073709551615, f:1.5, f64:2.5, flag:true, text:"A\0B")
        \\}
        \\func emptySame() bool { return emptyIdentity(Empty()) == Empty() }
        \\func roundTripSame() bool {
        \\    let value = Nested(left:sample(), right:sample())
        \\    return identity(value) == value
        \\}
        \\func nestedField() int {
        \\    let value = identity(Nested(left:sample(), right:sample()))
        \\    return value.right.i
        \\}
        \\func copiedDifferent() bool {
        \\    var value = Nested(left:sample(), right:sample())
        \\    let duplicate = value
        \\    value = Nested()
        \\    return value != duplicate
        \\}
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "emptySame", &.{});
    try compare(allocator, compilation.ir, machine, "roundTripSame", &.{});
    try compare(allocator, compilation.ir, machine, "nestedField", &.{});
    try compare(allocator, compilation.ir, machine, "copiedDifferent", &.{});
}

test "native ARM64 agrees on recursive enum equality" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\class Token { public let name:str }
        \\enum Inner { number(int); empty }
        \\enum Choice { empty; text(str); number(int); nested(Inner); token(Token) }
        \\enum Direction:int { north = 1; south = -2 }
        \\func sameText() bool { return Choice.text("value") == Choice.text("value") }
        \\func differentNumber() bool { return Choice.number(7) != Choice.number(8) }
        \\func differentVariant() bool { return Choice.text("7") != Choice.number(7) }
        \\func nestedSame() bool { return Choice.nested(Inner.number(3)) == Choice.nested(Inner.number(3)) }
        \\func nestedDifferent() bool { return Choice.nested(Inner.number(3)) != Choice.nested(Inner.empty()) }
        \\func sharedClass() bool {
        \\    var token = Token(name:"same")
        \\    var alias = token
        \\    return Choice.token(token) == Choice.token(alias)
        \\}
        \\func distinctClass() bool {
        \\    var first = Token(name:"same")
        \\    var second = Token(name:"same")
        \\    return Choice.token(first) != Choice.token(second)
        \\}
        \\func rawVariants() bool { return Direction.north() == Direction.north() && Direction.north() != Direction.south() }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "sameText", &.{});
    try compare(allocator, compilation.ir, machine, "differentNumber", &.{});
    try compare(allocator, compilation.ir, machine, "differentVariant", &.{});
    try compare(allocator, compilation.ir, machine, "nestedSame", &.{});
    try compare(allocator, compilation.ir, machine, "nestedDifferent", &.{});
    try compare(allocator, compilation.ir, machine, "sharedClass", &.{});
    try compare(allocator, compilation.ir, machine, "distinctClass", &.{});
    try compare(allocator, compilation.ir, machine, "rawVariants", &.{});
}

test "native ARM64 agrees on nested field mutation and value copies" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Score { var value:int; var other:int }
        \\struct Player { var score:Score; var reserve:int }
        \\func mutate() int {
        \\    var player = Player(score:Score(value:10, other:4), reserve:7)
        \\    player.score.value += 2
        \\    player.score.value *= 3
        \\    player.score.value -= 6
        \\    player.score.value /= 3
        \\    player.score.value++
        \\    player.score.value--
        \\    return player.score.value + player.score.other + player.reserve
        \\}
        \\func copyIndependent() bool {
        \\    var player = Player(score:Score(value:1, other:2), reserve:3)
        \\    let duplicate = player
        \\    player.score.value = 9
        \\    return duplicate == Player(score:Score(value:1, other:2), reserve:3)
        \\}
        \\struct Clock { var ticks:int; func tick() int { self.ticks++; return 1 } }
        \\struct Counter { var elapsed:int; var clock:Clock }
        \\func compoundPreservesSiblingMutation() int {
        \\    var counter = Counter(elapsed:0, clock:Clock(ticks:0))
        \\    counter.elapsed += counter.clock.tick()
        \\    return counter.elapsed * 10 + counter.clock.ticks
        \\}
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "mutate", &.{});
    try compare(allocator, compilation.ir, machine, "copyIndependent", &.{});
    try compare(allocator, compilation.ir, machine, "compoundPreservesSiblingMutation", &.{});
    const function = findFunction(compilation.ir, "compoundPreservesSiblingMutation") orelse return error.TestUnexpectedResult;
    const reference = try Interpreter.invoke(allocator, compilation.ir, function, &.{});
    try std.testing.expectEqual(@as(i64, 11), reference.integer);
    const native = try Runner.invoke(allocator, machine, function, &.{});
    try std.testing.expectEqual(Machine.Status.success, native.status);
    try std.testing.expectEqual(@as(i64, 11), native.value);
}

test "native ARM64 agrees on value constructors and branched self initialization" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Position {
        \\    let x:int
        \\    let y:int
        \\    init(x:int, positive:bool) {
        \\        if positive { self.x = x } else { self.x = -x }
        \\        self.y = 2
        \\    }
        \\}
        \\func positive() int { let value = Position(40, true); return value.x + value.y }
        \\func negative() int { let value = Position(40, false); return value.x + value.y }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "positive", &.{});
    try compare(allocator, compilation.ir, machine, "negative", &.{});
}

test "native ARM64 agrees on method receiver mutation returns and chaining" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Counter {
        \\    var value:int
        \\    func increment() { self.value++ }
        \\    func forward() { self.increment() }
        \\    func add(amount:int) int { self.value += amount; return self.value }
        \\    func current() int { return self.value }
        \\    func duplicate() Counter { return self }
        \\}
        \\func mutate() int {
        \\    var counter = Counter(value:1)
        \\    counter.forward()
        \\    let returned = counter.add(20)
        \\    return returned + counter.current()
        \\}
        \\func chained() int { return Counter(value:42).duplicate().current() }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "mutate", &.{});
    try compare(allocator, compilation.ir, machine, "chained", &.{});
}

test "native ARM64 agrees on dynamic protocol erasure and mutation" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\protocol Counter { func advance() int }
        \\struct Step : Counter { var value:int; func advance() int { self.value++; return self.value } }
        \\class Shared : Counter {
        \\    public var value:int = 10
        \\    public func advance() int { self.value++; return self.value }
        \\}
        \\func structural() int { var value:Counter = Step(value:4); return value.advance() }
        \\func shared() int {
        \\    var concrete = Shared()
        \\    var value:Counter = concrete
        \\    value.advance()
        \\    return concrete.value
        \\}
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "structural", &.{});
    try compare(allocator, compilation.ir, machine, "shared", &.{});
}

test "native ARM64 agrees on instance and static extension methods" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Counter { var value:int }
        \\extend Counter {
        \\    func add(amount:int) int { self.value += amount; return self.value }
        \\    static func seed() Counter { return Counter(value:40) }
        \\}
        \\func extended() int { var value = Counter.seed(); return value.add(2) }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "extended", &.{});
}

test "native ARM64 agrees on generic extension specializations" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Adapter {}
        \\extend Adapter {
        \\    func identity<T>(value:T) T { return value }
        \\    static func make<T>(value:T) T { return value }
        \\}
        \\func genericExtended() int { return Adapter().identity(40) + Adapter.make<int>(2) }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "genericExtended", &.{});
}

test "native ARM64 agrees on extension protocol conformances" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\protocol Readable { func read() int }
        \\struct Item { let value:int }
        \\extend Item : Readable { func read() int { return self.value } }
        \\func accept<T:Readable>(value:T) int { return value.read() }
        \\func extendedConformance() int {
        \\    let item = Item(value:21)
        \\    var erased:Readable = item
        \\    return accept(item) + erased.read()
        \\}
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "extendedConformance", &.{});
}

test "native ARM64 agrees on omitted function constructor and method arguments" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func seed() int { return 40 }
        \\func add(left:int = seed(), right:int = 2) int { return left + right }
        \\struct Box {
        \\    var value:int
        \\    init(value:int = 40) { self.value = value }
        \\    func plus(value:int = 2) int { return self.value + value }
        \\}
        \\func functionDefault() int { return add() }
        \\func constructorDefault() int { return Box().value }
        \\func methodDefault() int { return Box().plus() }
        \\func explicitArguments() int { return add(20, 22) }
        \\func main() {}
    );
    const machine = try Lower.lower(allocator, compilation.ir);
    try compare(allocator, compilation.ir, machine, "functionDefault", &.{});
    try compare(allocator, compilation.ir, machine, "constructorDefault", &.{});
    try compare(allocator, compilation.ir, machine, "methodDefault", &.{});
    try compare(allocator, compilation.ir, machine, "explicitArguments", &.{});
}
