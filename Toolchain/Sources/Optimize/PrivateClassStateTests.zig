const std = @import("std");
const Ir = @import("../Ir.zig");
const Frontend = @import("../Frontend.zig");
const Interpreter = @import("../Interpreter.zig");
const Release = @import("Release.zig");
const State = @import("PrivateClassState.zig");
const Ssa = @import("SsaPromotion.zig");
const Verifier = @import("Verifier.zig");

fn count(function: Ir.Function, tag: std.meta.Tag(Ir.Instruction)) usize {
    var total: usize = 0;
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (std.meta.activeTag(instruction) == tag) total += 1;
    };
    return total;
}

const counter_source =
    \\class Counter {
    \\    var value:int
    \\    func add(amount:int) { self.value += amount }
    \\}
    \\func calculate(rounds:int) int {
    \\    var counter = Counter(value:2)
    \\    var observer = counter
    \\    var index = 0
    \\    while index < rounds {
    \\        if index % 2 == 0 { counter.add(3) } else { observer.add(-1) }
    \\        index++
    \\    }
    \\    return observer.value + counter.value
    \\}
    \\func main() { print(calculate(0)); print(calculate(4)); print(calculate(5)) }
;

test "private class state keeps stores and ownership while forwarding a shared loop recurrence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.Frontend.init(a);
    const compilation = try frontend.compile(counter_source);
    const before = try Release.optimizeWithOptions(a, compilation.ir, .{
        .disabled = .reference_memory_elision,
        .stop_after = .reference_memory_elision,
        .verify_each_pass = true,
    });
    var after = before;
    const functions = try a.dupe(Ir.Function, before.functions);
    for (functions) |*function| function.* = try State.optimize(a, before, function.*);
    after.functions = functions;
    try Verifier.verify(a, after);
    var checked = false;
    for (before.functions, after.functions) |old, new| {
        if (!std.mem.eql(u8, old.name, "calculate")) continue;
        checked = true;
        try std.testing.expect(count(old, .field_load) >= 2);
        try std.testing.expectEqual(@as(usize, 0), count(new, .field_load));
        for ([_]std.meta.Tag(Ir.Instruction){ .structure_init, .field_store, .class_retain, .class_drop }) |tag|
            try std.testing.expectEqual(count(old, tag), count(new, tag));
    }
    try std.testing.expect(checked);
    after = try Ssa.optimize(a, after);
    try Verifier.verify(a, after);
    const raw = try Interpreter.runCapture(a, compilation.ir);
    const cached = try Interpreter.runCapture(a, after);
    try std.testing.expectEqualStrings("4\n12\n18\n", raw.stdout);
    try std.testing.expectEqualStrings(raw.stdout, cached.stdout);
    try std.testing.expectEqualStrings(raw.stderr, cached.stderr);
    try std.testing.expectEqual(raw.exit_code, cached.exit_code);
    const full = try Release.optimizeWithOptions(a, compilation.ir, .{ .verify_each_pass = true });
    const released = try Interpreter.runCapture(a, full);
    try std.testing.expectEqualStrings(raw.stdout, released.stdout);
}

fn fixture() Ir.Program {
    const class_type = comptime Ir.Type.structure(0);
    return .{
        .structures = &.{.{ .name = "Counter", .is_class = true, .fields = &.{.{ .name = "value", .type = .int, .mutable = true }} }},
        .functions = &.{ .{
            .name = "calculate",
            .parameter_types = &.{},
            .return_type = .int,
            .local_types = &.{class_type},
            .value_types = &.{ .int, class_type, class_type, .int, .int, .int, class_type, .int, .address, class_type },
            .blocks = &.{
                .{ .instructions = &.{
                    .{ .constant_int = .{ .result = 0, .bits = 0 } },
                    .{ .structure_init = .{ .result = 1, .structure = 0, .fields = &.{0} } },
                    .{ .local_store = .{ .local = 0, .operand = 1 } },
                }, .terminator = .{ .jump = 1 } },
                .{ .instructions = &.{
                    .{ .local_load = .{ .result = 2, .local = 0 } },
                    .{ .field_load = .{ .result = 3, .base = 2, .field = 0 } },
                    .{ .constant_int = .{ .result = 4, .bits = 1 } },
                    .{ .binary = .{ .result = 5, .operator = .add, .left = 3, .right = 4 } },
                    .{ .field_store = .{ .result = 6, .base = 2, .field = 0, .replacement = 5 } },
                    .{ .field_load = .{ .result = 7, .base = 6, .field = 0 } },
                }, .terminator = .{ .return_value = 7 } },
            },
        }, .{
            .name = "escape",
            .parameter_types = &.{class_type},
            .return_type = .void,
            .value_types = &.{class_type},
            .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }},
        } },
    };
}

test "private class state rejects addresses escapes mixed homes and reused identities" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const program = fixture();
    try Verifier.verify(a, program);
    const accepted = try State.optimize(a, program, program.functions[0]);
    try std.testing.expectEqual(@as(usize, 0), count(accepted, .field_load));
    for (0..7) |variant| {
        var function = program.functions[0];
        const blocks = try a.dupe(Ir.Block, function.blocks);
        function.blocks = blocks;
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        try instructions.appendSlice(a, blocks[0].instructions);
        switch (variant) {
            0 => try instructions.append(a, .{ .local_address = .{ .result = 8, .local = 0 } }),
            1 => {
                function.return_type = Ir.Type.structure(0);
                blocks[1].terminator = .{ .return_value = 6 };
            },
            2 => {
                try instructions.append(a, .{ .structure_init = .{ .result = 9, .structure = 0, .fields = &.{0} } });
                try instructions.append(a, .{ .local_store = .{ .local = 0, .operand = 9 } });
            },
            3 => try instructions.append(a, .{ .copy = .{ .result = 1, .operand = 1 } }),
            4 => blocks[1].terminator = .{ .jump = 0 },
            5 => try instructions.append(a, .{ .call = .{ .result = null, .function = 1, .arguments = &.{1} } }),
            6 => {
                const with_drop = try a.alloc(Ir.Instruction, blocks[1].instructions.len + 1);
                with_drop[0] = .{ .class_drop = .{ .operand = 1, .static_type = 0, .plans = &.{} } };
                @memcpy(with_drop[1..], blocks[1].instructions);
                blocks[1].instructions = with_drop;
            },
            else => unreachable,
        }
        blocks[0].instructions = try instructions.toOwnedSlice(a);
        if (variant == 0 or variant == 1 or variant == 2 or variant == 5) {
            var checked = program;
            checked.functions = try a.dupe(Ir.Function, program.functions);
            @constCast(checked.functions)[0] = function;
            try Verifier.verify(a, checked);
        }
        const after = try State.optimize(a, program, function);
        try std.testing.expectEqual(count(function, .field_load), count(after, .field_load));
        try std.testing.expectEqual(function.local_types.len, after.local_types.len);
    }
}

test "private class state cost policy follows the requested target architecture" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const Target = @import("../Target.zig").Target;
    var frontend = Frontend.Frontend.init(a);
    const compilation = try frontend.compile(counter_source);
    for ([_]Target{ .macos_arm64, .linux_arm64, .windows_arm64, .macos_x64, .linux_x64, .windows_x64 }) |target| {
        var options = Release.Options.forTarget(target, 2);
        try std.testing.expectEqual(@as(u16, 2), options.worker_count);
        options.stop_after = .reference_memory_elision;
        options.verify_each_pass = true;
        const result = try Release.optimizeWithOptions(a, compilation.ir, options);
        var checked = false;
        for (result.functions) |function| {
            if (!std.mem.eql(u8, function.name, "calculate")) continue;
            checked = true;
            if (target.architecture == .arm64) {
                try std.testing.expectEqual(@as(usize, 0), count(function, .field_load));
            } else {
                try std.testing.expect(count(function, .field_load) > 0);
            }
        }
        try std.testing.expect(checked);
    }
}
