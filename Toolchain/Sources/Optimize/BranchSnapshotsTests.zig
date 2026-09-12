const std = @import("std");
const Ir = @import("../Ir.zig");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Release = @import("Release.zig");
const Snapshots = @import("BranchSnapshots.zig");
const Verifier = @import("Verifier.zig");

test "branch snapshots keep alias observations before either arm writes" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { var x:float; var y:float }
        \\func observe(values:&Pair[..], flag:bool) float {
        \\    let snapshot = copy values[0]
        \\    if flag {
        \\        values[0].x = 100.0
        \\        print(snapshot.x)
        \\        return snapshot.x + snapshot.y
        \\    } else {
        \\        values[0].y = 200.0
        \\        return snapshot.x - snapshot.y
        \\    }
        \\}
        \\func main() {
        \\    var values:Pair[] = [Pair(x:7.0, y:4.0)]
        \\    print(observe(&values[0:1], true))
        \\    print(observe(&values[0:1], false))
        \\    print(values[0].x, " ", values[0].y)
        \\}
    );
    const before = try Release.optimizeWithOptions(allocator, compilation.ir, .{ .verify_each_pass = true, .disabled = .branch_snapshot_sinking });
    const after = try Snapshots.optimize(allocator, before);
    try Verifier.verify(allocator, after);
    const raw = try Interpreter.runCapture(allocator, compilation.ir);
    const optimized = try Interpreter.runCapture(allocator, after);
    try std.testing.expectEqualStrings("7.0\n11.0\n96.0\n100.0 200.0\n", raw.stdout);
    try std.testing.expectEqualStrings(raw.stdout, optimized.stdout);
    var changed = false;
    for (before.functions, after.functions) |left, right| {
        if (!std.mem.eql(u8, left.name, "observe")) continue;
        changed = right.value_types.len > left.value_types.len;
        for (left.blocks, right.blocks) |a, b| {
            if (a.terminator != .branch or a.instructions.len == b.instructions.len) continue;
            try std.testing.expect(a.instructions.len > b.instructions.len);
            // The checked collection address is evaluated before the branch.
            try std.testing.expect(b.instructions[b.instructions.len - 1] == .collection_reference);
            const branch = b.terminator.branch;
            for ([_]Ir.BlockId{ branch.then_block, branch.else_block }) |target| {
                try std.testing.expect(right.blocks[target].instructions[0] == .reference_field);
                try std.testing.expect(right.blocks[target].instructions[1] == .reference_load);
            }
        }
    }
    try std.testing.expect(changed);
}

fn witness() Ir.Program {
    return .{ .functions = &.{.{
        .name = "snapshot",
        .parameter_types = &.{ .address, .bool },
        .return_type = .bool,
        .value_types = &.{ .address, .bool, .bool },
        .blocks = &.{
            .{ .instructions = &.{.{ .reference_load = .{ .result = 2, .reference = 0 } }}, .terminator = .{ .branch = .{ .condition = 1, .then_block = 1, .else_block = 2 } } },
            .{ .instructions = &.{}, .terminator = .{ .return_value = 2 } },
            .{ .instructions = &.{}, .terminator = .{ .return_value = 2 } },
        },
    }} };
}

test "branch snapshots refuse conditions, joined uses, shared entries and redefinitions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const original = witness();
    const positive = try Snapshots.optimize(allocator, original);
    try Verifier.verify(allocator, positive);
    try std.testing.expectEqual(@as(usize, 0), positive.functions[0].blocks[0].instructions.len);
    try std.testing.expect(positive.functions[0].blocks[1].terminator.return_value != positive.functions[0].blocks[2].terminator.return_value);
    for (0..4) |scenario| {
        var function = original.functions[0];
        const blocks = try allocator.dupe(Ir.Block, function.blocks);
        function.blocks = blocks;
        switch (scenario) {
            0 => blocks[0].terminator.branch.condition = 2,
            1 => {
                blocks[1].terminator = .{ .jump = 2 };
            },
            2 => blocks[0].terminator.branch.else_block = 1,
            3 => blocks[1].instructions = &.{.{ .constant_bool = .{ .result = 2, .value = false } }},
            else => unreachable,
        }
        const after = try Snapshots.optimize(allocator, .{ .functions = &.{function} });
        try std.testing.expectEqual(@as(usize, 1), after.functions[0].blocks[0].instructions.len);
    }
}

test "branch snapshots never cross an effect after the read" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function = witness().functions[0];
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    function.blocks = blocks;
    blocks[0].instructions = &.{
        .{ .reference_load = .{ .result = 2, .reference = 0 } },
        .{ .reference_store = .{ .reference = 0, .operand = 1 } },
    };
    const after = try Snapshots.optimize(allocator, .{ .functions = &.{function} });
    try std.testing.expectEqual(@as(usize, 2), after.functions[0].blocks[0].instructions.len);
}
