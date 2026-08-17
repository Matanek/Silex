const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Project = @import("Project.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "construct and match intrinsic Result value and void successes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\func parse(allowed:bool) Result<int, str> {
        \\    if allowed { return Result<int, str>.success(42) }
        \\    return Result<int, str>.failure("bad")
        \\}
        \\func save(allowed:bool) Result<void, str> {
        \\    if allowed { return Result<void, str>.success }
        \\    return Result<void, str>.failure("denied")
        \\}
        \\func main() {
        \\    match parse(true) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match parse(false) { success(value) => { print(value) }; failure(error) => { print(error) } }
        \\    match save(true) { success => { print("saved") }; failure(error) => { print(error) } }
        \\    match save(false) { success => { print("saved") }; failure(error) => { print(error) } }
        \\}
    );
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\nbad\nsaved\ndenied\n", result.stdout);
}

test "compose Result identities and transparent aliases through modules" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Api
        \\use Result<int, Api.Failure> as ParseResult
        \\func forward(value:ParseResult) Result<int, Api.Failure> { return value }
        \\func main() {
        \\    match forward(Api.parse()) {
        \\        success(value) => { print(value) }
        \\        failure(error) => { print(error.message) }
        \\    }
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\public struct Failure { let message:str }
        \\public func parse() Result<int, Failure> {
        \\    return Result<int, Failure>.success(42)
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    var result_count: usize = 0;
    for (compilation.ast.enums) |enumeration| if (std.mem.startsWith(u8, enumeration.name, "Result<")) {
        result_count += 1;
    };
    try std.testing.expectEqual(@as(usize, 1), result_count);
    const result = try Interpreter.runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("42\n", result.stdout);
}

test "emit deterministic Result IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\enum Failure { bad }
        \\func value() Result<int, Failure> { return Result<int, Failure>.success(7) }
        \\func main() { match value() { success(number) => { print(number) }; failure(error) => { print("failure") } } }
    ;
    var first = Frontend.Frontend.init(allocator);
    var second = Frontend.Frontend.init(allocator);
    const first_text = try Ir.writeText(allocator, (try first.compile(source)).ir);
    const second_text = try Ir.writeText(allocator, (try second.compile(source)).ir);
    try std.testing.expectEqualStrings(first_text, second_text);
    try std.testing.expect(std.mem.indexOf(u8, first_text, "enum @Result<int,Failure>") != null);
}

test "reserve Result and reject invalid specializations" {
    try expectCompileError(
        "enum Result<T, E> { success(T); failure(E) } func main() {}",
        "'Result' is a reserved intrinsic type name",
    );
    try expectCompileError(
        "struct Result {} func main() {}",
        "'Result' is a reserved intrinsic type name",
    );
    try expectCompileError(
        "func Result() {} func main() {}",
        "'Result' is a reserved intrinsic type name",
    );
    try expectCompileError(
        "use int as Result\nfunc main() {}",
        "'Result' is a reserved intrinsic type name",
    );
    try expectCompileError(
        "enum Failure { bad } func main() { let value:Result<int> }",
        "generic enum 'Result' expects 2 type arguments, found 1",
    );
    try expectCompileError(
        "func main() { let value:Result<int, void> }",
        "the error type of 'Result' cannot be 'void'",
    );
    try expectCompileError(
        "func main() { let value:Result<void, void> }",
        "the error type of 'Result' cannot be 'void'",
    );
    try expectCompileError(
        "enum Box<T> { value(T) } func main() { Box<void>.value() }",
        "'void' is not a generic type argument",
    );
    try expectCompileError(
        "enum Failure { bad } func main() { let value:Result }",
        "generic enum 'Result' requires 2 type arguments",
    );
    try expectCompileError(
        "func main() { Result<int, str>.success() }",
        "variant 'Result<int,str>.success' expects 1 arguments, found 0",
    );
    try expectCompileError(
        "func main() { Result<void, str>.success(1) }",
        "variant 'Result<void,str>.success' expects 0 arguments, found 1",
    );
    try expectCompileError(
        "func main() { Result<int, str>.failure() }",
        "variant 'Result<int,str>.failure' expects 1 arguments, found 0",
    );
    try expectCompileError(
        "func compute() Result<int, str> { return 1 } func main() {}",
        "return expects 'Result<int,str>', found 'int'",
    );
    try expectCompileError(
        "func compute() Result<int, str> { return \"bad\" } func main() {}",
        "return expects 'Result<int,str>', found 'str'",
    );
    try expectCompileError(
        "func main() { let result = Result<int, str>.success(1); print(result.value) }",
        "enum 'Result<int,str>' has no property named 'value'",
    );
}

test "reject private Result error types in public contracts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data = "use Api.parse\nfunc main() {}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api.sx",
        .data =
        \\struct Failure {}
        \\public func parse() Result<int, Failure> { return Result<int, Failure>.failure(Failure()) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings("public function 'parse' exposes module structure 'Failure'", compiler.diagnostic.?.message);
}
