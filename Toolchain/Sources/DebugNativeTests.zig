const std = @import("std");
const Frontend = @import("Frontend.zig");
const Debug = @import("Optimize/Debug.zig");
const DebugNative = @import("DebugNative.zig");
const Lower = @import("Arm64/Lower.zig");
const Machine = @import("Arm64/Machine.zig");
const Target = @import("Target.zig").Target;

test "Debug register placement preserves loops addressed locals calls and source metadata" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const original = (try frontend.compile(
        \\func change(value:&int) { value+=7 }
        \\func probe(seed:int) int {
        \\    var value=seed;let snapshot=value;change(value)
        \\    return snapshot*10+value
        \\}
        \\func floating() int {
        \\    var value=1.0;var index=0
        \\    while index<8 { value=value*2.0+1.0;index++ }
        \\    if value==511.0 { return 42 } return 0
        \\}
        \\func answer() int { return probe(3)+probe(5)+floating() }
        \\func main() { print(answer()) }
    )).ir;
    const prepared = try Debug.prepare(allocator, original, 1);
    const lowered = try Lower.simplifyDebugCopies(allocator, try Lower.lower(allocator, prepared));
    var answer: ?usize = null;
    for (prepared.functions, 0..) |function, index| {
        if (std.mem.eql(u8, function.name, "answer")) answer = index;
    }
    for ([_]Target{ .macos_arm64, .macos_x64, .linux_arm64, .linux_x64, .windows_arm64, .windows_x64 }) |target| {
        const allocated = try DebugNative.allocate(allocator, lowered, target);
        try std.testing.expect(allocated.debug);
        try std.testing.expectEqual(lowered.functions.len, allocated.functions.len);
        var residents: usize = 0;
        for (allocated.functions, lowered.functions) |function, before| {
            try std.testing.expectEqualDeep(before.source_position, function.source_position);
            try std.testing.expectEqual(function.instructions.len, function.instruction_positions.len);
            for (function.register_slots) |slot| if (slot != null) {
                residents += 1;
            };
            for (function.float_register_slots) |slot| if (slot != null) {
                residents += 1;
            };
        }
        try std.testing.expect(residents > 0);
        if (target.eql(.macos_arm64) and @import("builtin").os.tag == .macos and @import("builtin").cpu.arch == .aarch64) {
            const result = try @import("Arm64/Runner.zig").invoke(allocator, allocated, answer orelse return error.TestUnexpectedResult, &.{});
            try std.testing.expectEqual(Machine.Status.success, result.status);
            try std.testing.expectEqual(@as(i64, 144), result.value);
        }
    }
}
