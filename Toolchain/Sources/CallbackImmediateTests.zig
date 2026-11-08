const std = @import("std");
const Frontend = @import("Frontend.zig");
const Ir = @import("Ir.zig");
const Immediate = @import("Semantic/CallbackFlow/Immediate.zig");
const Provenance = @import("Semantic/CallbackProvenance.zig");
const CompilationTrace = @import("CompilationTrace.zig");
const Interpreter = @import("Interpreter.zig");

const slot = "class Slot { var callback:(func())? = null; func set(callback:func()) { self.callback = callback } func clear() { self.callback = null } } ";
fn classify(source: []const u8, expected: bool) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.Frontend.init(a);
    const program = (try frontend.compile(source)).ir;
    const origins = try Immediate.origins(a, program);
    const main_id = for (program.functions, 0..) |f, i| {
        if (std.mem.eql(u8, f.name, "main")) break i;
    } else return error.TestUnexpectedResult;
    try std.testing.expectEqual(expected, origins[main_id]);
    const result = try Interpreter.runCapture(a, program);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
fn rejected(source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}

test "callback provenance proves direct synchronous forwarding without interpreting setup" {
    try classify(
        \\func invoke(callback:func()) { callback(); callback() }
        \\func relay(callback:func()) { invoke(callback) }
        \\func main() { var count = 0; relay(func() { count++ }); assert(count == 2) }
    , true);
}

test "callback provenance falls back for storage even when it is cleared before return" {
    try classify(slot ++
        \\func main() { var count = 0; var slot = Slot(); slot.set(func() { count++ }); slot.clear(); assert(count == 0) }
    , false);
}

test "callback provenance accounts for every occurrence of a duplicated callback argument" {
    try rejected(slot ++
        \\func consume(first:func(), second:func(), target:Slot) { first(); target.set(second) }
        \\func relay(callback:func(), target:Slot) { consume(callback,callback,target) }
        \\func setup(target:Slot) { let value = 7; relay(func() { print(value) },target) }
        \\func main() {}
    );
}

test "callback provenance keeps unknown higher order forwarding outside the immediate proof" {
    try classify(
        \\func invoke(callback:func()) { callback() }
        \\func dispatch(writer:func(func()), callback:func()) { writer(callback) }
        \\func main() { var count = 0; dispatch(invoke,func() { count++ }); assert(count == 1) }
    , false);
}

test "callback provenance checks nested loans created inside an immediate callback" {
    try rejected(slot ++
        \\func invoke(callback:func()) { callback() }
        \\func setup(target:Slot) { invoke(func() { let value = 7; target.set(func() { print(value) }) }) }
        \\func main() {}
    );
}

test "callback provenance checks another environment exposed by an immediate callback" {
    try rejected(slot ++
        \\func invoke(callback:func()) { callback() }
        \\func setup(target:Slot) {
        \\    let value = 7
        \\    var callback:(func())? = func() { print(value) }
        \\    invoke(func() { if let current = callback { target.set(current) } })
        \\}
        \\func main() {}
    );
}

test "callback provenance keeps scope end liveness in the full ownership proof" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.Frontend.init(a);
    var program = (try frontend.compile("func invoke(callback:func()) { callback() } func main() { let value = 7; invoke(func() { print(value) }) }")).ir;
    const main_id = for (program.functions, 0..) |f, i| {
        if (std.mem.eql(u8, f.name, "main")) break i;
    } else return error.TestUnexpectedResult;
    try std.testing.expect((try Immediate.origins(a, program))[main_id]);
    const functions = try a.dupe(Ir.Function, program.functions);
    program.functions = functions;
    var main = &functions[main_id];
    for (main.blocks, 0..) |b, block| for (b.instructions, 0..) |op, index| if (op == .function_reference and op.function_reference.captures.len != 0) {
        const live = try a.dupe(Ir.LiveBinding, &.{.{ .value = op.function_reference.result }});
        const lifetimes = try a.dupe(usize, &.{main.borrow_origins[0].lifetime});
        main.borrow_ends = try a.dupe(Ir.BorrowEnd, &.{.{ .block = block, .instruction = index + 1, .live = live, .lifetimes = lifetimes, .position = main.source_position }});
        try std.testing.expect(!(try Immediate.origins(a, program))[main_id]);
        try std.testing.expect((try Provenance.check(a, program)) != null);
        return;
    };
    return error.TestUnexpectedResult;
}

test "callback provenance does not certify a callback parameter without its body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.Frontend.init(a);
    var program = (try frontend.compile("func invoke(callback:func()) { callback() } func main() { let value = 7; invoke(func() { print(value) }) }")).ir;
    const functions = try a.dupe(Ir.Function, program.functions);
    program.functions = functions;
    var main_id: ?usize = null;
    for (functions, 0..) |*f, i| {
        if (std.mem.eql(u8, f.name, "main")) main_id = i;
        if (std.mem.eql(u8, f.name, "invoke")) f.blocks = &.{};
    }
    try std.testing.expect(!(try Immediate.origins(a, program))[main_id orelse return error.TestUnexpectedResult]);
}

test "callback provenance trace preserves IR and counts only enabled analysis" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.Frontend.init(a);
    const program = (try frontend.compile(slot ++
        \\func setup(target:Slot) { let value=7; target.set(func() { print(value) }); target.clear() }
        \\func main() {}
    )).ir;
    const before = try Ir.writeText(a, program);
    var environment = std.process.Environ.Map.init(a);
    defer environment.deinit();
    const metadata: CompilationTrace.Metadata = .{
        .command = .compile,
        .backend = "native",
        .source_path = "Trace.sx",
        .target = "macos-arm64",
        .mode = "debug",
        .cache_enabled = false,
        .compiler_version = "test",
    };
    var disabled = CompilationTrace.Reporter.init(std.testing.io, &environment, metadata);
    try std.testing.expect((try Provenance.checkWithTrace(a, program, &disabled)) == null);
    try std.testing.expectEqual(@as(usize, 0), disabled.metrics.callback_origins);
    try std.testing.expectEqual(@as(usize, 0), disabled.metrics.callback_evaluations);
    try environment.put(CompilationTrace.environment_name, "unused-trace.json");
    var enabled = CompilationTrace.Reporter.init(std.testing.io, &environment, metadata);
    try std.testing.expect((try Provenance.checkWithTrace(a, program, &enabled)) == null);
    try std.testing.expect(enabled.metrics.callback_origins > 0);
    try std.testing.expect(enabled.metrics.callback_frames > 0);
    try std.testing.expect(enabled.metrics.callback_evaluations >= enabled.metrics.callback_frames);
    try std.testing.expectEqualStrings(before, try Ir.writeText(a, program));
}
