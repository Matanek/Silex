const std = @import("std");
const Frontend = @import("Frontend.zig");
const Ir = @import("Ir.zig");
const CacheBinary = @import("CacheBinary.zig");
const Provenance = @import("Semantic/CallbackProvenance.zig");
const Project = @import("Project.zig");
const Interpreter = @import("Interpreter.zig");
const Flow = @import("Semantic/CallbackFlow/Model.zig");
const Trace = @import("CompilationTrace.zig");

fn factReporter() Trace.Reporter {
    return .{ .io = std.testing.io, .output_path = "unused-trace.json", .started = .zero, .cache_result = .disabled, .metadata = .{
        .command = .compile,
        .backend = "native",
        .source_path = "Facts.sx",
        .target = "macos-arm64",
        .mode = "debug",
        .cache_enabled = false,
        .compiler_version = "test",
    } };
}

fn factEngine(a: std.mem.Allocator, trace: *Trace.Reporter) !Provenance.Engine {
    const program: Ir.Program = .{
        .functions = &.{},
        .globals = &.{ .{ .name = "mutable", .type = .bool, .mutable = true }, .{ .name = "immutable", .type = .bool, .mutable = false } },
        .structures = &.{.{ .name = "Flags", .is_class = true, .fields = &.{ .{ .name = "mutable", .type = .bool, .mutable = true }, .{ .name = "immutable", .type = .bool, .mutable = false } } }},
    };
    var e: Provenance.Engine = .{ .a = a, .storage = a, .program = program, .trace = trace, .capable = .{ .structures = &.{}, .functions = &.{} }, .relevant = &.{}, .borrowed = &.{}, .generators = &.{} };
    e.globals = try e.object(0, .local, Flow.wildcard, null, false);
    _ = try e.object(0, .object, 1, .structure(0), false);
    _ = try e.node(.{ .frame = 0, .category = .callable, .value = 2 }, .{ .callable = .{ .function = 0, .loans = &.{}, .many = false } });
    return e;
}

// Keep the former unconditional traversal independent of the reuse property.
fn invalidateFactsOracle(e: *Provenance.Engine, memory: *Flow.Memory) !void {
    var it = memory.iterator();
    while (it.next()) |entry| {
        if ((entry.value_ptr.scalar == .bottom or entry.value_ptr.scalar == .unknown) and entry.value_ptr.presence != .absent and entry.value_ptr.presence != .present) continue;
        const owner = e.nodes.items[entry.key_ptr.object];
        if (owner == .callable) continue;
        if (owner == .object) {
            if (owner.object.type) |t| if (t.structureIndex()) |index| {
                const fields = e.program.structures[index].fields;
                if (e.program.structures[index].collection == null and entry.key_ptr.field < fields.len and !fields[entry.key_ptr.field].mutable) continue;
            };
        }
        if (entry.key_ptr.object == e.globals and entry.key_ptr.field < e.program.globals.len and !e.program.globals[entry.key_ptr.field].mutable) continue;
        var value = entry.value_ptr.*;
        if (value.scalar != .bottom) value.scalar = .unknown;
        if (value.presence != .bottom) value.presence = .unknown;
        try memory.put(e.a, entry.key_ptr.*, value);
    }
}

fn expectSameFacts(expected: Flow.Memory, actual: Flow.Memory) !void {
    var first = expected.iterator();
    var second = actual.iterator();
    while (first.next()) |entry| {
        const other = second.next() orelse return error.TestUnexpectedResult;
        try std.testing.expectEqualDeep(entry.key_ptr.*, other.key_ptr.*);
        try std.testing.expect(Flow.Value.eql(entry.value_ptr.*, other.value_ptr.*));
    }
    try std.testing.expect(second.next() == null);
    var owners = expected.owners.iterator();
    var other_owners = actual.owners.iterator();
    while (owners.next()) |entry| {
        const other = other_owners.next() orelse return error.TestUnexpectedResult;
        try std.testing.expectEqual(entry.key_ptr.*, other.key_ptr.*);
        try std.testing.expectEqualDeep(entry.value_ptr.*, other.value_ptr.*);
    }
    try std.testing.expect(other_owners.next() == null);
}

test "callback mutable facts reuse invalidation until a known write" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var trace = factReporter();
    var e = try factEngine(a, &trace);
    var memory: Flow.Memory = .empty;
    const facts = [_]Flow.Value{
        .{},                                                                        .{ .scalar = .unknown },           .{ .scalar = .{ .boolean = true } },
        .{ .scalar = .{ .zero = .int } },                                           .{ .scalar = .{ .protocol = 0 } }, .{ .scalar = .{ .variant = .{ .enumeration = 0, .variant = 1 } } },
        .{ .scalar = .{ .choices = .{ .enumeration = 0, .values = &.{ 1, 2 } } } }, .{ .presence = .absent },          .{ .presence = .present },
        .{ .presence = .unknown },
    };
    for (facts, 0..) |value, i| try memory.put(a, .{ .object = 1, .field = i + 2 }, value);
    for ([_]usize{ 0, 1, 2 }) |object| for (0..2) |field| {
        try memory.put(a, .{ .object = object, .field = field }, .{ .scalar = .{ .boolean = true } });
    };
    try memory.owners.put(a, 1, .{ .roots = .{ .low = 1, .high = 1 } });
    var expected = memory;
    try invalidateFactsOracle(&e, &expected);
    try e.invalidateMutableFacts(&memory);
    try expectSameFacts(expected, memory);
    const scanned = trace.metrics.callback_fact_cells_scanned;
    try std.testing.expect(scanned > 0);
    for (0..16) |_| {
        try invalidateFactsOracle(&e, &expected);
        try e.invalidateMutableFacts(&memory);
    }
    try expectSameFacts(expected, memory);
    try std.testing.expectEqual(scanned, trace.metrics.callback_fact_cells_scanned);
    const unknown_cell: Flow.Cell = .{ .object = 1, .field = 99 };
    try memory.put(a, unknown_cell, .{ .scalar = .unknown });
    try expected.put(a, unknown_cell, .{ .scalar = .unknown });
    try invalidateFactsOracle(&e, &expected);
    try e.invalidateMutableFacts(&memory);
    try expectSameFacts(expected, memory);
    try std.testing.expectEqual(scanned, trace.metrics.callback_fact_cells_scanned);
    try memory.put(a, unknown_cell, .{ .presence = .present });
    try expected.put(a, unknown_cell, .{ .presence = .present });
    try invalidateFactsOracle(&e, &expected);
    try e.invalidateMutableFacts(&memory);
    try expectSameFacts(expected, memory);
    try std.testing.expect(trace.metrics.callback_fact_cells_scanned > scanned);
}

test "callback mutable facts preserve independent branches and promoted arenas" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var trace = factReporter();
    var e = try factEngine(a, &trace);
    var base: Flow.Memory = .empty;
    const cell: Flow.Cell = .{ .object = 1, .field = 0 };
    try base.put(a, cell, .{ .scalar = .{ .boolean = false } });
    try e.invalidateMutableFacts(&base);
    var branch = try Flow.cloneMemory(a, base);
    try branch.put(a, cell, .{ .scalar = .{ .boolean = true } });
    var expected = branch;
    try invalidateFactsOracle(&e, &expected);
    try e.invalidateMutableFacts(&branch);
    try expectSameFacts(expected, branch);
    const scanned = trace.metrics.callback_fact_cells_scanned;
    try e.invalidateMutableFacts(&base);
    try std.testing.expectEqual(scanned, trace.metrics.callback_fact_cells_scanned);
    var promoted: Flow.Memory = undefined;
    {
        var scratch = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer scratch.deinit();
        const temporary = scratch.allocator();
        e.a = temporary;
        defer e.a = a;
        var local: Flow.Memory = .empty;
        try local.put(temporary, cell, .{ .scalar = .{ .zero = .int } });
        try e.invalidateMutableFacts(&local);
        promoted = try local.promote(temporary, a);
    }
    const before = trace.metrics.callback_fact_cells_scanned;
    try e.invalidateMutableFacts(&promoted);
    try std.testing.expectEqual(before, trace.metrics.callback_fact_cells_scanned);
    try std.testing.expect(promoted.get(cell).?.scalar == .unknown);
}

test "callback mutable facts invalidate known entries introduced by memory joins" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var trace = factReporter();
    var e = try factEngine(a, &trace);
    for ([_]bool{ false, true }) |owned| for ([_]bool{ false, true }) |nonempty| {
        var target: Flow.Memory = .empty;
        if (nonempty) try target.put(a, .{ .object = 1, .field = 2 }, .{ .scalar = .unknown });
        try e.invalidateMutableFacts(&target);
        var source: Flow.Memory = .empty;
        const cell: Flow.Cell = .{ .object = 1, .field = 0 };
        try source.put(a, cell, .{ .scalar = .{ .boolean = true } });
        if (owned) {
            _ = try Flow.joinMemoryOwned(a, &target, source);
        } else {
            _ = try Flow.joinMemory(a, &target, source);
        }
        var expected = target;
        try invalidateFactsOracle(&e, &expected);
        try e.invalidateMutableFacts(&target);
        try expectSameFacts(expected, target);
        try std.testing.expect(target.get(cell).?.scalar == .unknown);
    };
}

test "callback provenance preserves lexical regions through binary IR restoration" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.Frontend.init(a);
    const compiled = try frontend.compile(
        \\func invoke(callback:func()) { callback() }
        \\func main() { var value = 0; invoke(func() { value++ }); assert(value == 1) }
    );
    const bytes = try CacheBinary.encode(a, compiled.ir);
    const restored = try CacheBinary.decode(Ir.Program, a, bytes);
    var origins: usize = 0;
    var ends: usize = 0;
    for (compiled.ir.functions, restored.functions) |before, after| {
        try std.testing.expectEqualDeep(before.borrow_origins, after.borrow_origins);
        try std.testing.expectEqualDeep(before.borrow_ends, after.borrow_ends);
        origins += after.borrow_origins.len;
        ends += after.borrow_ends.len;
    }
    try std.testing.expect(origins != 0 and ends != 0);
    try std.testing.expectEqual(@as(?@import("Source.zig").Diagnostic, null), try Provenance.check(a, restored));
    const result = try Interpreter.runCapture(a, restored);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback provenance rejects retention through restored package helpers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Application/Sources");
    try temporary.dir.createDirPath(std.testing.io, "DependencySources/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Package.json",
        .data = "{\"sources\":\"Sources\",\"dependencies\":{\"Effects\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "DependencySources/Package.json",
        .data = "{\"name\":\"Effects\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "DependencySources/Module/Slots.sx",
        .data =
        \\public class Slot {
        \\    private var callback:(func())? = null
        \\    init() {}
        \\    func set(callback:func()) { self.callback = callback }
        \\    func invoke() { if let callback = self.callback { callback() } }
        \\    func clear() { self.callback = null }
        \\}
        \\public func retain(slot:Slot, callback:func()) { slot.set(callback) }
        \\public func run(slot:Slot) int { var value = 0; retain(slot,func() { value++ }); slot.invoke(); slot.clear(); return value }
        ,
    });
    const valid =
        \\use Effects.Slots.Slot
        \\use Effects.Slots.retain
        \\use Effects.Slots.run
        \\func empty() {}
        \\func main() { var slot = Slot(); assert(run(slot) == 1); retain(slot,empty); slot.invoke(); slot.clear() }
    ;
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Application/Sources/Main.sx", .data = valid });
    const entry = try std.fs.path.join(a, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Application", "Sources", "Main.sx" });
    var cold = Project.Compiler.initWithPackagesAndCache(a, std.testing.io, null, true);
    const first = try cold.compile(entry);
    try std.testing.expect(first.metrics.package_functions_stored != 0);
    var warm = Project.Compiler.initWithPackagesAndCache(a, std.testing.io, null, true);
    const second = try warm.compile(entry);
    try std.testing.expect(second.metrics.package_functions_reused != 0);
    const result = try Interpreter.runCapture(a, second.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Application/Sources/Main.sx",
        .data =
        \\use Effects.Slots.Slot
        \\use Effects.Slots.retain
        \\func setup(slot:Slot) { let value = 7; retain(slot,func() { print(value) }) }
        \\func main() { var slot = Slot(); setup(slot) }
        ,
    });
    var invalid = Project.Compiler.initWithPackagesAndCache(a, std.testing.io, null, true);
    try std.testing.expectError(error.InvalidSource, invalid.compile(entry));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", invalid.diagnostic.?.message);
}

test "callback provenance executes the owning corpus with the reference interpreter" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "../Tests/Functions/Callbacks/BorrowedEffects.sx", a, .unlimited);
    var frontend = Frontend.Frontend.init(a);
    const compilation = try frontend.compileTests(source);
    var entries: usize = 0;
    for (compilation.ir.functions, 0..) |function, id| {
        if (!function.is_test_entry) continue;
        const result = try Interpreter.runFunctionCaptureWithBoundaries(a, null, compilation.ir, id, &.{});
        if (result.exit_code != 0) std.debug.print("{s}: {s}\n", .{ function.name, result.stderr });
        try std.testing.expectEqual(@as(u8, 0), result.exit_code);
        entries += 1;
    }
    try std.testing.expectEqual(@as(usize, 9), entries);
}

test "callback provenance ignores callback free protocol cycles beside a synchronous loan" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "Benchmarks/Optimizer/LlvmEvaluation/CycleValueEdges.sx", a, .unlimited);
    const with_loan = try std.mem.replaceOwned(u8, a, source, "func main() {", "func call(callback:func()) { callback() } func main() { var seen = 0; call(func() { seen++ }); assert(seen == 1)");
    var frontend = Frontend.Frontend.init(a);
    const compiled = try frontend.compile(with_loan);
    const result = try Interpreter.runCapture(a, compiled.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqualStrings("cycle value edges passed\n", result.stdout);
}

test "callback provenance named generic calls preserve labels defaults and evaluation order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const source =
        \\class Trace { var value:int = 0 }
        \\func step(trace:Trace, digit:int) int { trace.value = trace.value * 10 + digit; return digit }
        \\func first<T>(left:T, right:T) T { return left }
        \\func encode<T>(value:T, first:int = 1, last:int = 3) int { return first * 10 + last }
        \\func choose<T>(value:T) int { return 1 }
        \\func choose(value:int) int { return 2 }
        \\func main() {
        \\    var trace = Trace()
        \\    let result = first(right:step(trace,2), left:step(trace,1))
        \\    assert(result == 1 && trace.value == 12)
        \\    assert(encode(last:9,value:"ok") == 19)
        \\    assert(encode<int>(last:8,value:1,first:2) == 28)
        \\    assert(choose(value:3) == 2 && choose(value:"ok") == 1)
        \\}
    ;
    var frontend = Frontend.Frontend.init(a);
    const result = try Interpreter.runCapture(a, (try frontend.compile(source)).ir);
    if (result.exit_code != 0) std.debug.print("NAMED stdout={s} stderr={s}\n", .{ result.stdout, result.stderr });
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    for ([_][]const u8{
        "func select<T>(value:T) T { return value } func main() { select(missing:1) }",
        "func select<T>(value:T) T { return value } func main() { select(value:1,value:2) }",
    }) |invalid| {
        var rejected = Frontend.Frontend.init(a);
        try std.testing.expectError(error.InvalidSource, rejected.compile(invalid));
    }
}

test "callback provenance snapshots isolate cells and ownership across branches" {
    const M = @import("Semantic/CallbackFlow/Model.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var base: M.Memory = .empty;
    for (0..257) |i| {
        try base.put(a, .{ .object = i, .field = 0 }, try M.Value.one(a, i));
        try base.owners.put(a, i, .{ .roots = .{ .low = 1, .high = 1 } });
    }
    var left = try M.cloneMemory(a, base);
    var right = try M.cloneMemory(a, base);
    for (0..257) |i| {
        try left.put(a, .{ .object = i, .field = 0 }, try M.Value.one(a, i + 1000));
        try right.put(a, .{ .object = i, .field = 1 }, try M.Value.one(a, i + 2000));
        try right.owners.put(a, i, .{ .lifetime = .finalized });
    }
    var merged = try M.cloneMemory(a, left);
    try std.testing.expect(try M.joinMemory(a, &merged, right));
    const before_cells = merged.cells.root;
    const before_owners = merged.owners.root;
    try std.testing.expect(!try M.joinMemory(a, &merged, right));
    try std.testing.expectEqual(before_cells, merged.cells.root);
    try std.testing.expectEqual(before_owners, merged.owners.root);
    for (0..257) |i| {
        const cell: M.Cell = .{ .object = i, .field = 0 };
        try std.testing.expectEqualSlices(usize, &.{i}, base.get(cell).?.nodes);
        try std.testing.expectEqualSlices(usize, &.{i + 1000}, left.get(cell).?.nodes);
        try std.testing.expectEqualSlices(usize, &.{i}, right.get(cell).?.nodes);
        try std.testing.expectEqualSlices(usize, &.{ i, i + 1000 }, merged.get(cell).?.nodes);
        try std.testing.expect(base.get(.{ .object = i, .field = 1 }) == null);
        try std.testing.expectEqual(M.Lifetime.live, base.owners.get(i).?.lifetime);
        try std.testing.expectEqual(M.Lifetime.finalized, right.owners.get(i).?.lifetime);
        try std.testing.expectEqual(M.Lifetime.maybe, merged.owners.get(i).?.lifetime);
    }
    var iterator = merged.iterator();
    var count: usize = 0;
    while (iterator.next()) |_| count += 1;
    try std.testing.expectEqual(@as(usize, 514), count);
}

test "callback provenance distinguishes absent concrete cells from unknown external fields" {
    const M = @import("Semantic/CallbackFlow/Model.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.Frontend.init(a);
    const program = (try frontend.compile("class Slot { var callback:(func())? = null } func main() { var slots:Slot[] = [] }")).ir;
    const slot = for (program.structures, 0..) |s, i| {
        if (std.mem.eql(u8, s.name, "Slot")) break i;
    } else return error.TestUnexpectedResult;
    const collection = for (program.structures, 0..) |s, i| {
        if (s.collection) |c| {
            if (c.element == Ir.Type.structure(slot)) break i;
        }
    } else return error.TestUnexpectedResult;
    const flags = try M.capableTypes(a, program);
    var e: Provenance.Engine = .{ .a = a, .storage = a, .program = program, .capable = flags, .relevant = &.{}, .borrowed = &.{}, .generators = &.{} };
    e.globals = try e.object(0, .local, M.wildcard, null, false);
    var memory: M.Memory = .empty;
    const list = try e.object(0, .object, 1, .structure(collection), false);
    const base = try M.Value.one(a, list);
    try std.testing.expectEqual(@as(usize, 0), (try e.field(&memory, base, 0, .structure(slot))).nodes.len);
    const stored = try e.object(0, .object, 2, .structure(slot), false);
    try memory.put(a, .{ .object = list, .field = M.wildcard }, try M.Value.one(a, stored));
    try std.testing.expectEqualSlices(usize, &.{stored}, (try e.field(&memory, base, 1, .structure(slot))).nodes);
    const external = try e.unknown(&memory, .{ .object = e.globals, .field = 0 }, .structure(collection));
    const child = try e.field(&memory, external, 0, .structure(slot));
    try std.testing.expect(child.nodes.len != 0);
    try std.testing.expect(e.nodes.items[child.nodes[0]].object.unknown_parent != null);
}

test "callback provenance promotes live snapshots before releasing callee scratch" {
    const M = @import("Semantic/CallbackFlow/Model.zig");
    var parent = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer parent.deinit();
    const a = parent.allocator();
    var base: M.Memory = .empty;
    for (0..128) |i| try base.put(a, .{ .object = i, .field = 0 }, try M.Value.one(a, i));
    var promoted: M.Memory = undefined;
    var recursive: M.Memory = .empty;
    {
        var scratch = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer scratch.deinit();
        const temporary = scratch.allocator();
        var branch = try M.cloneMemory(temporary, base);
        const value = try M.Value.join(base.get(.{ .object = 0, .field = 0 }).?, try M.Value.one(temporary, 999), temporary);
        try branch.put(temporary, .{ .object = 0, .field = 0 }, value);
        try branch.put(temporary, .{ .object = 128, .field = 0 }, try M.Value.one(temporary, 128));
        try branch.owners.put(temporary, 128, .{ .roots = .{ .low = 1, .high = 1 } });
        promoted = try branch.promote(temporary, a);
        try std.testing.expect(try M.joinMemoryOwned(a, &recursive, branch));
    }
    for ([_]M.Memory{ promoted, recursive }) |memory| {
        try std.testing.expectEqualSlices(usize, &.{ 0, 999 }, memory.get(.{ .object = 0, .field = 0 }).?.nodes);
        for (1..129) |i| try std.testing.expectEqualSlices(usize, &.{i}, memory.get(.{ .object = i, .field = 0 }).?.nodes);
        try std.testing.expectEqual(@as(usize, 1), memory.owners.get(128).?.roots.low);
    }
    try std.testing.expectEqualSlices(usize, &.{0}, base.get(.{ .object = 0, .field = 0 }).?.nodes);
}

test "callback provenance preserves nominal borrowed signatures across composed package caches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Application/Sources");
    try temporary.dir.createDirPath(std.testing.io, "Dependency/Module");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Application/Package.json", .data = "{\"sources\":\"Sources\",\"dependencies\":{\"NominalCallbacks\":\"=1.0.0\"}}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Dependency/Package.json", .data = "{\"name\":\"NominalCallbacks\",\"version\":\"1.0.0\"}" });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Dependency/Module/Slots.sx",
        .data =
        \\public class IntegerSlot {
        \\    var callback:(func(&int))? = null
        \\    func set(callback:func(&int)) { self.callback = callback }
        \\    func clear() { self.callback = null }
        \\    func invoke(value:&int) { if let callback = self.callback { callback(value) } }
        \\}
        \\public class TextSlot {
        \\    var callback:(func(&str))? = null
        \\    func set(callback:func(&str)) { self.callback = callback }
        \\    func clear() { self.callback = null }
        \\    func invoke(value:&str) { if let callback = self.callback { callback(value) } }
        \\}
        \\public func identity(value:int) int { return value }
        ,
    });
    const valid =
        \\use NominalCallbacks.Slots.IntegerSlot
        \\use NominalCallbacks.Slots.TextSlot
        \\use NominalCallbacks.Slots.identity
        \\func integers(slot:IntegerSlot) { var offset = 7; slot.set(func(value:&int) { value += offset }); var value = 1; slot.invoke(value); slot.clear(); assert(value == 8) }
        \\func texts(slot:TextSlot) { var suffix = "safe"; slot.set(func(value:&str) { value = value + suffix }); var value = "typed-"; slot.invoke(value); slot.clear(); assert(value == "typed-safe") }
        \\func main() { var integer = IntegerSlot(); var text = TextSlot(); integers(integer); texts(text); assert(identity(2) == 2) }
    ;
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Application/Sources/Main.sx", .data = valid });
    const entry = try std.fs.path.join(a, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Application", "Sources", "Main.sx" });
    var cold = Project.Compiler.initWithPackagesAndCache(a, std.testing.io, null, true);
    _ = try cold.compile(entry);
    var warm = Project.Compiler.initWithPackagesAndCache(a, std.testing.io, null, true);
    const restored = try warm.compile(entry);
    // Ambiguous lowered signatures may safely rebuild the package. The warm
    // path must preserve nominal types rather than reuse an ambiguous mapping.
    try std.testing.expect(restored.metrics.package_functions_reused != 0 or restored.metrics.package_functions_stored != 0);
    const result = try Interpreter.runCapture(a, restored.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    const invalid = try std.mem.replaceOwned(u8, a, valid, "slot.invoke(value); slot.clear(); assert(value == 8)", "slot.invoke(value); assert(value == 8)");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Application/Sources/Main.sx", .data = invalid });
    var rejected = Project.Compiler.initWithPackagesAndCache(a, std.testing.io, null, true);
    try std.testing.expectError(error.InvalidSource, rejected.compile(entry));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", rejected.diagnostic.?.message);
}
