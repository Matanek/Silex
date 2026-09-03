const std = @import("std");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Ir = @import("../Ir.zig");
const Release = @import("Release.zig");

test "narrow reconstructed reference and view stores preserve snapshots" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct State { var x:float; var y:float; var z:float; var w:float }
        \\func change(state:&State, values:&State[..], index:int, positive:bool) {
        \\    let snapshot = copy state
        \\    if positive { state.x += 2.0 } else { state.x -= 2.0 }
        \\    state.z = snapshot.x
        \\    values[index].x = state.x
        \\    values[index].y += snapshot.y
        \\}
        \\func main() {
        \\    var state = State(x:3.0, y:5.0, z:7.0, w:11.0)
        \\    let snapshot = state
        \\    var values:State[] = [State(x:13.0, y:17.0, z:19.0, w:23.0)]
        \\    change(state, &values[0:values.count()], -1, true)
        \\    assert(state.x == 5.0 && state.y == 5.0 && state.z == 3.0 && state.w == 11.0)
        \\    assert(snapshot.x == 3.0 && snapshot.z == 7.0)
        \\    assert(values[0].x == 5.0 && values[0].y == 22.0)
        \\    assert(values[0].z == 19.0 && values[0].w == 23.0)
        \\    print("narrow stores preserved snapshots")
        \\}
    );
    const optimized = try Release.optimize(allocator, compilation.ir);
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const result = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(@as(u8, 0), reference.exit_code);
    try std.testing.expectEqual(reference.exit_code, result.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, result.stdout);
    var found = false;
    for (optimized.functions) |function| {
        if (!std.mem.eql(u8, function.name, "change")) continue;
        found = true;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .structure_init, .collection_replace => return error.TestUnexpectedResult,
            .reference_store => |store| try std.testing.expect(function.value_types[store.operand].structureIndex() == null),
            else => {},
        };
    }
    try std.testing.expect(found);
}

test "narrow stores retain stale snapshots and owning collection copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct State { var x:int; var y:int }
        \\func restore(state:&State) {
        \\    let before = copy state
        \\    state.y = 90
        \\    state = State(x:state.x + 1, y:before.y)
        \\}
        \\func crossing(state:&State, change:bool) {
        \\    let before = copy state
        \\    if change { state.y = 80 }
        \\    state = State(x:state.x + 1, y:before.y)
        \\}
        \\func replace(values:State[]) State[] {
        \\    var result = values
        \\    result[0].x = 70
        \\    return result
        \\}
        \\func main() {
        \\    var state = State(x:3, y:5)
        \\    restore(state)
        \\    crossing(state, true)
        \\    assert(state.x == 5 && state.y == 5)
        \\    let values:State[] = [state]
        \\    let modified = replace(values)
        \\    assert(values[0].x == 5 && modified[0].x == 70)
        \\    assert(modified[0].y == 5)
        \\    print("stale snapshots and collection copies preserved")
        \\}
    );
    const optimized = try Release.optimize(allocator, compilation.ir);
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const result = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(@as(u8, 0), reference.exit_code);
    try std.testing.expectEqual(reference.exit_code, result.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, result.stdout);
    for (optimized.functions) |function| {
        var retained = false;
        if (std.mem.eql(u8, function.name, "restore") or std.mem.eql(u8, function.name, "crossing")) {
            for (function.blocks) |block| for (block.instructions) |instruction| {
                if (instruction == .reference_store and function.value_types[instruction.reference_store.operand].structureIndex() != null) retained = true;
            };
            try std.testing.expect(retained);
        } else if (std.mem.eql(u8, function.name, "replace")) {
            for (function.blocks) |block| for (block.instructions) |instruction| {
                if (instruction == .collection_replace) retained = true;
            };
            try std.testing.expect(retained);
        }
    }
}

test "narrow view stores retain invalid-index diagnostics" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct State { var x:int; var y:int }
        \\func change(values:&State[..], index:int) { values[index].x = 7 }
        \\func main() {
        \\    var values:State[] = [State(x:3, y:5)]
        \\    change(&values[0:values.count()], -2)
        \\    print("unreachable")
        \\}
    );
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const result = try Interpreter.runCapture(allocator, try Release.optimize(allocator, compilation.ir));
    try std.testing.expect(reference.exit_code != 0);
    try std.testing.expectEqual(reference.exit_code, result.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, result.stdout);
    try std.testing.expectEqualStrings(reference.stderr, result.stderr);
}

test "narrow aggregate reads capture scalars before alias writes and branches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct State { var x:float; var y:float }
        \\func capture(state:&State, values:&State[..], index:int, branch:bool) float {
        \\    let saved = copy state
        \\    let item = values[index]
        \\    state.x = 100.0
        \\    values[index].y = 200.0
        \\    if branch { return saved.x + item.y }
        \\    return saved.y + item.x
        \\}
        \\func project(values:@State[..], index:int) float { return values[index].x }
        \\func main() {
        \\    var state = State(x:3.0, y:5.0)
        \\    var values:State[] = [State(x:7.0, y:11.0)]
        \\    assert(capture(state, &values[0:1], -1, true) == 14.0)
        \\    assert(capture(state, &values[0:1], 0, false) == 12.0)
        \\    assert(state.x == 100.0 && values[0].y == 200.0)
        \\    assert(project(@values[0:1], -1) == 7.0)
        \\    print("snapshot projections preserved")
        \\}
    );
    const optimized = try Release.optimize(allocator, compilation.ir);
    const reference = try Interpreter.runCapture(allocator, compilation.ir);
    const result = try Interpreter.runCapture(allocator, optimized);
    try std.testing.expectEqual(@as(u8, 0), reference.exit_code);
    try std.testing.expectEqual(reference.exit_code, result.exit_code);
    try std.testing.expectEqualStrings(reference.stdout, result.stdout);
    var found = false;
    for (optimized.functions) |function| {
        if (!std.mem.eql(u8, function.name, "project")) continue;
        found = true;
        var scalar_reads: usize = 0;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .collection_load => return error.TestUnexpectedResult,
            .reference_load => |load| {
                try std.testing.expect(function.value_types[load.result].structureIndex() == null);
                scalar_reads += 1;
            },
            else => {},
        };
        try std.testing.expectEqual(@as(usize, 1), scalar_reads);
    }
    try std.testing.expect(found);
}

test "narrow aggregate reads retain bounds failures" {
    for ([_][]const u8{ "-2", "1" }) |index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var frontend = Frontend.Frontend.init(allocator);
        const source = try std.fmt.allocPrint(allocator,
            \\struct State {{ var x:int; var y:int }}
            \\func project(values:@State[..], index:int) int {{ return values[index].x }}
            \\func main() {{
            \\    let values:State[] = [State(x:3, y:5)]
            \\    print(project(@values[0:1], {s}))
            \\}}
        , .{index});
        const compilation = try frontend.compile(source);
        const reference = try Interpreter.runCapture(allocator, compilation.ir);
        const result = try Interpreter.runCapture(allocator, try Release.optimize(allocator, compilation.ir));
        try std.testing.expect(reference.exit_code != 0);
        try std.testing.expectEqual(reference.exit_code, result.exit_code);
        try std.testing.expectEqualStrings(reference.stdout, result.stdout);
        try std.testing.expectEqualStrings(reference.stderr, result.stderr);
    }
}

test "narrow aggregate memory preserves floating point payloads natively" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    const Lower = @import("../Arm64/Lower.zig");
    const Runner = @import("../Arm64/Runner.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct State { var x:float; var y:float; var z:float }
        \\func capture(value:&State, choose:bool) float {
        \\    let saved = copy value
        \\    if choose { value.z = 3.0 } else { value.z = 4.0 }
        \\    return saved.x
        \\}
        \\func main() {}
    );
    const optimized = try Release.optimize(allocator, compilation.ir);
    for ([_]Lower.Mode{ .debug, .release }) |mode| {
        const machine = try Lower.lowerWithMode(allocator, if (mode == .debug) compilation.ir else optimized, mode);
        for ([_]u32{ 0x80000000, 0x7fc12345, 0x7f812345 }) |bits| {
            var values = [_]u64{ bits, 0xffc54321, 0 };
            const result = try Runner.invoke(allocator, machine, 0, &.{ @intCast(@intFromPtr(&values)), 1 });
            try std.testing.expectEqual(@import("../Arm64/Machine.zig").Status.success, result.status);
            try std.testing.expectEqual(bits, @as(u32, @truncate(@as(u64, @bitCast(result.value)))));
            try std.testing.expectEqual(bits, @as(u32, @truncate(values[0])));
            try std.testing.expectEqual(@as(u32, 0xffc54321), @as(u32, @truncate(values[1])));
            try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 3))), @as(u32, @truncate(values[2])));
        }
    }
}
