const std = @import("std");
const Ir = @import("Ir.zig");
const Types = @import("Types.zig");
const Analyzer = @import("Semantic.zig").Analyzer;

fn expectSemanticError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator, source);
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(message, analyzer.diagnostic.?.message);
}

test "lower empty main to an explicit void return" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator, "func main() {}");
    var analyzer = Analyzer.init(allocator);
    const text = try Ir.writeText(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @main() -> void {
        \\entry:
        \\    return
        \\}
        \\
    , text);
}

test "lower conditional paths to explicit deterministic blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator,
        \\func choose(flag:bool) int {
        \\    if flag { return 1 }
        \\    else { return 2 }
        \\}
        \\func main() {}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 3), program.functions[0].blocks.len);
    try std.testing.expectEqual(@as(Ir.BlockId, 1), program.functions[0].blocks[0].terminator.branch.then_block);
    try std.testing.expectEqual(@as(Ir.BlockId, 2), program.functions[0].blocks[0].terminator.branch.else_block);
}

test "enforce boolean conditions lexical branches and path-complete returns" {
    try expectSemanticError(
        "func choose() int { if true { return 1 } } func main() {}",
        "function 'choose' must return 'int' on every path",
    );
    try expectSemanticError(
        "func main() { if 1 { print(1) } }",
        "if condition expects 'bool'",
    );
    try expectSemanticError(
        "func main() { if true { let local = 1 } print(local) }",
        "unknown variable 'local'",
    );
    try expectSemanticError(
        "func main() { let value = 1; if true { let value = 2 } }",
        "variable 'value' is already declared in this scope",
    );
}

test "resolve forward calls overloads locals and intrinsic values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator,
        \\func main() {
        \\    answer()
        \\    choose(true)
        \\}
        \\func choose(value:int) int { return value }
        \\func choose(value:bool) bool { return value }
        \\func answer() int {
        \\    let left:int = 40
        \\    let right:int = 2
        \\    let ready:bool
        \\    return left + right
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 4), program.functions.len);
    try std.testing.expectEqual(Types.Type.bool, program.functions[0].value_types[1]);
    try std.testing.expectEqual(@as(Ir.FunctionId, 3), program.functions[0].blocks[0].instructions[0].call.function);
    try std.testing.expectEqual(@as(u64, 2), program.functions[3].blocks[0].instructions[1].constant_int.bits);
    try std.testing.expect(!program.functions[3].blocks[0].instructions[2].constant_bool.value);
}

test "lower fundamental calculation to deterministic IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator,
        \\func add(left:int, right:int) int {
        \\    let result = left + right
        \\    return result
        \\}
        \\func answer() int { return add(40, 2) }
        \\func main() { answer() }
    );
    var analyzer = Analyzer.init(allocator);
    const text = try Ir.writeText(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @add(%0:int, %1:int) -> int {
        \\entry:
        \\    %2:int = add %0, %1
        \\    return %2
        \\}
        \\
        \\func @answer() -> int {
        \\entry:
        \\    %0:int = const 40
        \\    %1:int = const 2
        \\    %2:int = call @add(%0, %1)
        \\    return %2
        \\}
        \\
        \\func @main() -> void {
        \\entry:
        \\    %0:int = call @answer()
        \\    return
        \\}
        \\
    , text);
}

test "accept the minimum signed integer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(
        allocator,
        "func minimum() int { return -9223372036854775808 } func main() {}",
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(u64, @bitCast(@as(i64, std.math.minInt(i64)))), program.functions[0].blocks[0].instructions[0].constant_int.bits);
}

test "lower strings comparisons and effects to deterministic IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator,
        \\func main() {
        \\    let empty:str
        \\    print("A\0B")
        \\    assert(2 * 3 >= 6, "math")
        \\    panic(empty)
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const text = try Ir.writeText(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @main() -> void {
        \\entry:
        \\    %0:str = const ""
        \\    %1:str = const "A\0B"
        \\    print %1
        \\    %2:int = const 2
        \\    %3:int = const 3
        \\    %4:int = mul %2, %3
        \\    %5:int = const 6
        \\    %6:bool = ge %4, %5
        \\    %7:str = const "math"
        \\    assert %6, %7
        \\    panic %0
        \\}
        \\
    , text);
}

test "report declaration and resolution errors" {
    try expectSemanticError(
        "func value(input:int) int { return input } func value(other:int) bool { return true } func main() {}",
        "function 'value' with these parameter types is already declared",
    );
    try expectSemanticError(
        "func value(input:int, input:int) int { return input } func main() {}",
        "parameter 'input' is already declared",
    );
    try expectSemanticError(
        "func main() { let value = 1; let value = 2 }",
        "variable 'value' is already declared in this scope",
    );
    try expectSemanticError("func value() int { return missing } func main() {}", "unknown variable 'missing'");
    try expectSemanticError("func main() { missing() }", "unknown function 'missing'");
    try expectSemanticError(
        "func add(left:int, right:int) int { return left + right } func main() { add(1) }",
        "function 'add' expects 2 arguments, found 1",
    );
    try expectSemanticError(
        "func enabled(value:bool) bool { return value } func main() { enabled(1) }",
        "argument 1 of 'enabled' expects 'bool', found 'int'",
    );
    try expectSemanticError(
        "func choose(left:int, right:int) int { return left } func choose(left:bool, right:bool) bool { return left } func main() { choose(1, true) }",
        "no overload of function 'choose' matches the argument types",
    );
}

test "report fundamental type and return errors" {
    try expectSemanticError(
        "func value() int { return true + 1 } func main() {}",
        "operator '+' does not accept 'bool' and 'int'",
    );
    try expectSemanticError(
        "func main() { let ready:bool = 1 }",
        "variable 'ready' expects 'bool', found 'int'",
    );
    try expectSemanticError(
        "func value() int { return 9223372036854775808 } func main() {}",
        "integer literal is outside the range of 'int'",
    );
    try expectSemanticError(
        "func value() int {} func main() {}",
        "function 'value' must return 'int' on every path",
    );
    try expectSemanticError(
        "func value() int { return } func main() {}",
        "expected return value of type 'int'",
    );
    try expectSemanticError(
        "func value() int { return false } func main() {}",
        "return expects 'int', found 'bool'",
    );
    try expectSemanticError("func main() { return 1 }", "a void function cannot return a value");
    try expectSemanticError("func main() { assert(1, \"message\") }", "assert condition expects 'bool'");
    try expectSemanticError("func main() { assert(true, 1) }", "assert message expects 'str'");
    try expectSemanticError("func main() { panic(false) }", "panic message expects 'str'");
    try expectSemanticError("func main() { print(\"a\" < \"b\") }", "operator '<' does not accept 'str' and 'str'");
    try expectSemanticError("func main() { print(\"a\" + 1) }", "operator '+' does not accept 'str' and 'int'");
    try expectSemanticError(
        "func main() { let value:int = 1; print(value.count()) }",
        "count() expects 'str'",
    );
}

test "numeric aliases domains widening and overload ambiguity" {
    try expectSemanticError(
        "func main() { let value:uint8 = 256 }",
        "integer literal is outside the range of 'uint8'",
    );
    try expectSemanticError(
        "func main() { let signed:int8 = 1; let unsigned:uint8 = 1; print(signed + unsigned) }",
        "operator '+' does not accept 'int8' and 'uint8'",
    );
    try expectSemanticError(
        "func choose(value:int16) int { return 1 } func choose(value:int32) int { return 2 } func main() { let value:int8 = 1; choose(value) }",
        "call to 'choose' is ambiguous",
    );
    try expectSemanticError(
        "func same(value:int) int { return value } func same(value:int64) int { return value } func main() {}",
        "function 'same' with these parameter types is already declared",
    );
}
