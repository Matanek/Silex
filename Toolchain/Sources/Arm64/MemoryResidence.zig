const Machine = @import("Machine.zig");
const std = @import("std");

test {
    _ = @import("AggregateCopyTests.zig");
    _ = @import("FloatMemoryTests.zig");
    _ = @import("DeadCollectionLoadTests.zig");
    _ = @import("MathCallResidenceTests.zig");
    _ = @import("CallResidenceTests.zig");
}

pub fn scalarMathCall(external: Machine.ExternalFunction) bool {
    const built_in = !external.package_private and
        (std.mem.eql(u8, external.provider, "Darwin.lib_system") or
            std.mem.eql(u8, external.provider, "Windows.ucrtbase"));
    if (!built_in and !external.system_math) return false;
    const math = @import("../Math/Boundary.zig").identify(external.source_name) orelse return false;
    const kind: Machine.AbiValue = if (math.precision == .float64) .float64 else .float32;
    const arity: usize = if (math.arity == .unary) 1 else 2;
    if (external.signature.result != kind or external.signature.arguments.len != arity) return false;
    for (external.signature.arguments) |argument| if (argument != kind) return false;
    return true;
}

pub fn copySignPrecision(external: Machine.ExternalFunction) ?bool {
    const built_in = !external.package_private and
        (std.mem.eql(u8, external.provider, "Darwin.lib_system") or
            std.mem.eql(u8, external.provider, "Windows.ucrtbase"));
    if (!built_in and !external.system_math) return null;
    const double = if (std.mem.eql(u8, external.source_name, "copysign")) true else if (std.mem.eql(u8, external.source_name, "copysignf")) false else return null;
    const kind: Machine.AbiValue = if (double) .float64 else .float32;
    if (external.signature.result != kind or external.signature.arguments.len != 2) return null;
    for (external.signature.arguments) |argument| if (argument != kind) return null;
    return double;
}

pub fn squareRootPrecision(external: Machine.ExternalFunction) ?bool {
    const built_in = !external.package_private and
        (std.mem.eql(u8, external.provider, "Darwin.lib_system") or
            std.mem.eql(u8, external.provider, "Windows.ucrtbase"));
    if (!built_in and !external.system_math) return null;
    const double = if (std.mem.eql(u8, external.source_name, "sqrt")) true else if (std.mem.eql(u8, external.source_name, "sqrtf")) false else return null;
    const kind: Machine.AbiValue = if (double) .float64 else .float32;
    if (external.signature.result != kind or external.signature.arguments.len != 1 or
        external.signature.arguments[0] != kind) return null;
    return double;
}

test "constructed memory arithmetic retains SIMD seeds" {
    const RegisterAllocation = @import("RegisterAllocation.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function: Machine.Function = .{
        .name = "constructed_pair",
        .parameter_count = 4,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 } },
        .return_type = .void,
        .slot_count = 12,
        .frame_size = 96,
        .float_lane_groups = &.{
            .{ .slots = .{ 4, 5, 0, 0 }, .width = 2, .priority = 1, .recurrence = false, .in_loop = false },
            .{ .slots = .{ 6, 7, 0, 0 }, .width = 2, .priority = 1, .recurrence = false, .in_loop = false },
            .{ .slots = .{ 8, 9, 0, 0 }, .width = 2, .priority = 1, .recurrence = false, .in_loop = false },
        },
        .instructions = &.{
            .{ .aggregate_init = .{ .result = .{ .start = 4, .width = 2, .aggregate = true }, .fields = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } } } },
            .{ .binary = .{ .result = 6, .left = 4, .right = 2, .operator = .multiply, .type = .float32 } },
            .{ .binary = .{ .result = 7, .left = 5, .right = 2, .operator = .multiply, .type = .float32 } },
            .{ .binary = .{ .result = 8, .left = 6, .right = 2, .operator = .add, .type = .float32 } },
            .{ .binary = .{ .result = 9, .left = 7, .right = 2, .operator = .add, .type = .float32 } },
            .{ .copy_range = .{ .result = .{ .start = 10, .width = 2 }, .operand = .{ .start = 8, .width = 2 } } },
            .{ .reference_store = .{ .reference = 3, .operand = .{ .start = 10, .width = 2 } } },
            .return_void,
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    try std.testing.expect(function.float_lane_slots[4] != null);
    try std.testing.expect(function.float_lane_slots[6] != null);
    try std.testing.expect(function.float_lane_slots[8] != null);
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const Runner = @import("Runner.zig");
    var values = [_]u64{ 0, 0 };
    const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{
        @as(u32, @bitCast(@as(f32, 3))), @as(u32, @bitCast(@as(f32, -4))),
        @as(u32, @bitCast(@as(f32, 2))), @intCast(@intFromPtr(&values)),
    });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 8))), @as(u32, @truncate(values[0])));
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, -6))), @as(u32, @truncate(values[1])));
}

test "memory kernels keep isolated arithmetic scalar when lane setup costs more" {
    const RegisterAllocation = @import("RegisterAllocation.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function: Machine.Function = .{
        .name = "isolated_memory_pair",
        .parameter_count = 6,
        .parameters = &.{
            .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 },
            .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 },
            .{ .start = 4, .width = 1 }, .{ .start = 5, .width = 1 },
        },
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 9,
        .frame_size = try Machine.frameSize(9),
        .float_lane_groups = &.{.{
            .slots = .{ 6, 7, 0, 0 },
            .width = 2,
            .priority = 9,
            .recurrence = false,
            .in_loop = false,
        }},
        .instructions = &.{
            .{ .binary = .{ .result = 6, .operator = .multiply, .left = 0, .right = 2, .type = .float32 } },
            .{ .binary = .{ .result = 7, .operator = .multiply, .left = 1, .right = 3, .type = .float32 } },
            .{ .reference_store = .{ .reference = 4, .operand = .{ .start = 5, .width = 1 } } },
            .{ .binary = .{ .result = 8, .operator = .add, .left = 6, .right = 7, .type = .float32 } },
            .{ .return_value = .{ .start = 8, .width = 1 } },
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), allocation.float_lane_residences[6]);
    try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), allocation.float_lane_residences[7]);
    try std.testing.expect(allocation.float_residences[6] != null);
    try std.testing.expect(allocation.float_residences[7] != null);
}

test "memory arithmetic affinity wins over conflicting copy groups" {
    try checkArithmeticAffinity(false);
    try checkArithmeticAffinity(true);
}

fn checkArithmeticAffinity(reverse_arithmetic: bool) !void {
    const RegisterAllocation = @import("RegisterAllocation.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function: Machine.Function = .{
        .name = "conflicting_copy_groups",
        .parameter_count = 6,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 }, .{ .start = 4, .width = 1 }, .{ .start = 5, .width = 1 } },
        .return_type = .void,
        .slot_count = 22,
        .frame_size = 176,
        .float_lane_groups = &.{
            .{ .slots = .{ 6, 8, 0, 0 }, .width = 2, .priority = 1, .recurrence = false, .in_loop = false },
            .{ .slots = .{ 7, 9, 0, 0 }, .width = 2, .priority = 1, .recurrence = false, .in_loop = false },
            .{ .slots = .{ 10, 11, 12, 13 }, .width = 4, .priority = 1, .recurrence = false, .in_loop = false },
            .{ .slots = .{ 14, 15, 16, 17 }, .width = 4, .priority = 1, .recurrence = false, .in_loop = false },
        },
        .instructions = &.{
            .{ .copy = .{ .result = 6, .operand = 0 } },
            .{ .copy = .{ .result = 7, .operand = 1 } },
            .{ .copy = .{ .result = 8, .operand = 2 } },
            .{ .copy = .{ .result = 9, .operand = 3 } },
            .{ .binary = .{ .result = 10, .left = 6, .right = 4, .operator = .multiply, .type = .float32 } },
            .{ .binary = .{ .result = 11, .left = 7, .right = 4, .operator = .multiply, .type = .float32 } },
            .{ .binary = .{ .result = 12, .left = 8, .right = 4, .operator = .multiply, .type = .float32 } },
            .{ .binary = .{ .result = 13, .left = 9, .right = 4, .operator = .multiply, .type = .float32 } },
            .{ .binary = .{ .result = 14, .left = 10, .right = 4, .operator = .add, .type = .float32 } },
            .{ .binary = .{ .result = 15, .left = 11, .right = 4, .operator = .add, .type = .float32 } },
            .{ .binary = .{ .result = 16, .left = 12, .right = 4, .operator = .add, .type = .float32 } },
            .{ .binary = .{ .result = 17, .left = 13, .right = 4, .operator = .add, .type = .float32 } },
            .{ .copy_range = .{ .result = .{ .start = 18, .width = 4 }, .operand = .{ .start = 14, .width = 4 } } },
            .{ .reference_store = .{ .reference = 5, .operand = .{ .start = 18, .width = 4 } } },
            .return_void,
        },
    };
    if (reverse_arithmetic) {
        const groups = try allocator.dupe(Machine.FloatLaneGroup, function.float_lane_groups);
        std.mem.swap(Machine.FloatLaneGroup, &groups[2], &groups[3]);
        function.float_lane_groups = groups;
    }
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    for (6..18) |slot| try std.testing.expect(function.float_lane_slots[slot] != null);
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    const Runner = @import("Runner.zig");
    var values = [_]u64{0} ** 4;
    const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{
        @as(u32, @bitCast(@as(f32, 3))), @as(u32, @bitCast(@as(f32, -4))),
        @as(u32, @bitCast(@as(f32, 5))), @as(u32, @bitCast(@as(f32, -6))),
        @as(u32, @bitCast(@as(f32, 2))), @intCast(@intFromPtr(&values)),
    });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    for ([_]f32{ 8, -6, 12, -10 }, values) |expected, actual| {
        try std.testing.expectEqual(@as(u32, @bitCast(expected)), @as(u32, @truncate(actual)));
    }
}

test "memory lane recurrence preserves source-level borrowed updates" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    const Frontend = @import("../Frontend.zig").Frontend;
    const Release = @import("../Optimize/Release.zig");
    const Lower = @import("Lower.zig");
    const Runner = @import("Runner.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.init(allocator);
    const compilation = try frontend.compile(
        \\struct Pair { var x:float; var y:float }
        \\func transform(values:@Pair[..], output:&Pair, index:int, scale:float, invert:bool) {
        \\    let input = values[index]
        \\    var x = input.x
        \\    var y = input.y
        \\    var step = 0
        \\    while step < 3 {
        \\        x = x * scale + 1.0
        \\        y = y * scale + 1.0
        \\        step++
        \\    }
        \\    if invert { x = -x; y = -y }
        \\    output.x = x
        \\    output.y = y
        \\    output.x += output.y
        \\}
        \\func main() {}
    );
    const optimized = try Release.optimizeWithoutInlining(allocator, compilation.ir);
    const program = try Lower.lowerWithMode(allocator, optimized, .release);
    var values = [_]u32{ @bitCast(@as(f32, 3)), @bitCast(@as(f32, -4)) };
    var view = [_]u64{ @intFromPtr(&values), 1 };
    var stored = [_]u64{ 0, 0 };
    for ([_]bool{ false, true }) |invert| {
        const result = try Runner.invoke(allocator, program, 0, &.{
            @intCast(@intFromPtr(&view)),    @intCast(@intFromPtr(&stored)), -1,
            @as(u32, @bitCast(@as(f32, 2))), @intFromBool(invert),
        });
        try std.testing.expectEqual(Machine.Status.success, result.status);
        const expected_x: f32 = if (invert) -6 else 6;
        const expected_y: f32 = if (invert) 25 else -25;
        try std.testing.expectEqual(@as(u32, @bitCast(expected_x)), @as(u32, @truncate(stored[0])));
        try std.testing.expectEqual(@as(u32, @bitCast(expected_y)), @as(u32, @truncate(stored[1])));
    }
}

// These leaf memory operations use scratch x9...x15. Their error paths
// terminate the function; their successful paths call no runtime. Addressed
// local spans stay pinned, while view descriptors and indices may remain in
// registers because view references never mutate the descriptor itself.
pub fn supports(instruction: Machine.Instruction) bool {
    return switch (instruction) {
        .reference_load,
        .reference_store,
        .reference_offset,
        .local_address,
        .address_load,
        .address_store,
        => true,
        .collection_load => |value| value.checked and value.dynamic,
        .collection_reference => |value| value.dynamic and value.view,
        .collection_replace => |value| value.dynamic and value.view,
        else => false,
    };
}

pub fn required(function: Machine.Function) bool {
    for (function.instructions) |instruction| if (supports(instruction) or instruction == .external_call) return true;
    return false;
}

pub fn pin(instruction: Machine.Instruction, forced: []bool) void {
    switch (instruction) {
        .reference_load => |value| {
            if (value.result.width != 1) pinSpan(value.result, forced);
        },
        .reference_store => |value| {
            if (value.operand.width != 1) pinSpan(value.operand, forced);
        },
        .reference_offset => {},
        .local_address => |value| {
            forced[value.result] = true;
            for (0..value.width) |leaf| forced[@as(usize, value.local) + leaf] = true;
        },
        .address_load => |value| {
            forced[value.address] = true;
            forced[value.byte_offset] = true;
            forced[value.result] = true;
        },
        .address_store => |value| {
            forced[value.address] = true;
            forced[value.byte_offset] = true;
            forced[value.operand] = true;
        },
        .collection_load => |value| if (value.checked) {
            pinSpan(value.collection, forced);
            if (value.result.width != 1) pinSpan(value.result, forced);
            forced[value.index] = true;
        },
        .collection_reference => |value| {
            if (!value.view) {
                pinSpan(value.collection, forced);
                forced[value.index] = true;
                forced[value.result] = true;
                if (value.reference) |reference| forced[reference] = true;
            }
        },
        .collection_replace => |value| {
            pinSpan(value.collection, forced);
            pinSpan(value.result, forced);
            pinSpan(value.replacement, forced);
            forced[value.index] = true;
        },
        .external_call => |value| {
            for (value.arguments) |argument| forced[argument] = true;
            if (value.result) |result| forced[result] = true;
        },
        else => {},
    }
}

fn pinSpan(span: Machine.Span, forced: []bool) void {
    for (0..span.width) |leaf| forced[@as(usize, span.start) + leaf] = true;
}

/// Memory emitters accept scalar float registers, but not packed float lanes.
/// Keep this exclusion separate from stack pinning so scalar residency survives.
pub fn pinFloatLanes(instruction: Machine.Instruction, forced: []bool) void {
    pin(instruction, forced);
    switch (instruction) {
        .reference_load => |value| pinSpan(value.result, forced),
        .reference_store => |value| pinSpan(value.operand, forced),
        .collection_load => |value| if (value.checked) {
            pinSpan(value.result, forced);
        },
        else => {},
    }
}

pub fn uses(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .reference_load => |value| value.reference == slot,
        .reference_store => |value| value.reference == slot or contains(value.operand, slot),
        .reference_offset => |value| value.reference == slot,
        .address_load => |value| value.address == slot or value.byte_offset == slot,
        .address_store => |value| value.address == slot or value.byte_offset == slot or value.operand == slot,
        .collection_reference => |value| contains(value.collection, slot) or value.index == slot or
            (if (value.reference) |reference| reference == slot else false),
        .collection_replace => |value| contains(value.collection, slot) or contains(value.replacement, slot) or value.index == slot,
        .external_call => |value| for (value.arguments) |argument| {
            if (argument == slot) break true;
        } else false,
        else => false,
    };
}

pub fn defines(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .reference_load => |value| contains(value.result, slot),
        .reference_offset => |value| value.result == slot,
        .address_load => |value| value.result == slot,
        .collection_reference => |value| value.result == slot,
        .collection_replace => |value| contains(value.result, slot),
        .external_call => |value| if (value.result) |result| result == slot else false,
        else => false,
    };
}

fn contains(span: Machine.Span, slot: usize) bool {
    return slot >= span.start and slot < @as(usize, span.start) + span.width;
}

test "checked leaf loads pin memory operands but retain arithmetic registers" {
    const RegisterAllocation = @import("RegisterAllocation.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const instructions = [_]Machine.Instruction{
        .{ .collection_load = .{
            .result = .{ .start = 4, .width = 1 },
            .collection = .{ .start = 0, .width = 2, .aggregate = true },
            .index = 2,
            .count = 0,
            .dynamic = true,
            .view = true,
            .header = 0,
            .tail = 0,
        } },
        .{ .constant_float32 = .{ .result = 5, .bits = @bitCast(@as(f32, 0.5)) } },
        .{ .binary = .{ .result = 6, .operator = .multiply, .left = 4, .right = 5, .type = .float32 } },
        .{ .binary = .{ .result = 7, .operator = .add, .left = 6, .right = 5, .type = .float32 } },
        .{ .reference_store = .{ .reference = 3, .operand = .{ .start = 7, .width = 1 } } },
        .return_void,
    };
    const function: Machine.Function = .{
        .name = "memory_leaf",
        .parameter_count = 3,
        .parameters = &.{ .{ .start = 0, .width = 2, .aggregate = true }, .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 } },
        .return_type = .void,
        .slot_count = 8,
        .frame_size = try Machine.frameSize(8),
        .instructions = &instructions,
    };
    const result = try RegisterAllocation.allocate(arena.allocator(), function);
    for ([_]usize{ 0, 1, 2 }) |slot| {
        try std.testing.expectEqual(null, result.residences[slot]);
        try std.testing.expectEqual(null, result.float_residences[slot]);
        try std.testing.expectEqual(null, result.float_lane_residences[slot]);
    }
    try std.testing.expect(result.residences[3] != null);
    try std.testing.expect(result.float_residences[6] != null);
    try std.testing.expect(result.float_residences[4] != null);
    try std.testing.expect(result.float_residences[7] != null);
    const shared_pairs = try RegisterAllocation.allocateFloatLanePairsFor(arena.allocator(), function, &.{ 0, 1 });
    try std.testing.expectEqual(@as(usize, 0), shared_pairs.len);
}

test "dead aggregate leaves do not overwrite a live sibling register" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    const RegisterAllocation = @import("RegisterAllocation.zig");
    const Runner = @import("Runner.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 1, .bits = @bitCast(@as(f32, 1)) } },
        .{ .constant_float32 = .{ .result = 2, .bits = @bitCast(@as(f32, 2)) } },
        .{ .reference_store = .{ .reference = 0, .operand = .{ .start = 1, .width = 1 } } },
        .{ .aggregate_init = .{
            .result = .{ .start = 3, .width = 2, .aggregate = true },
            .fields = &.{ .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 } },
        } },
        .{ .binary = .{ .result = 5, .operator = .multiply, .left = 3, .right = 2, .type = .float32 } },
        .{ .binary = .{ .result = 6, .operator = .equal, .left = 5, .right = 2, .type = .float32 } },
        .{ .return_value = .{ .start = 6, .width = 1 } },
    };
    var function: Machine.Function = .{
        .name = "aggregate_siblings",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .bool,
        .return_width = 1,
        .slot_count = 7,
        .frame_size = try Machine.frameSize(7),
        .instructions = &instructions,
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    try std.testing.expect(allocation.float_residences[3] != null);
    try std.testing.expectEqual(allocation.float_residences[3], allocation.float_residences[4]);
    var stored: u64 = 0;
    const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{@intCast(@intFromPtr(&stored))});
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(@as(i64, 1), result.value);
    try std.testing.expectEqual(@as(u64, @as(u32, @bitCast(@as(f32, 1)))), stored);
}

test "checked memory kernels retain arithmetic lanes without vectorizing memory operands" {
    const RegisterAllocation = @import("RegisterAllocation.zig");
    const Runner = @import("Runner.zig");
    const builtin = @import("builtin");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const instructions = [_]Machine.Instruction{
        .{ .collection_load = .{
            .result = .{ .start = 4, .width = 2, .aggregate = true },
            .collection = .{ .start = 0, .width = 2, .aggregate = true },
            .index = 2,
            .count = 0,
            .dynamic = true,
            .view = true,
            .header = 0,
            .tail = 0,
        } },
        .{ .copy = .{ .result = 6, .operand = 4 } },
        .{ .copy = .{ .result = 7, .operand = 5 } },
        .{ .constant_float32 = .{ .result = 8, .bits = @bitCast(@as(f32, 2)) } },
        .{ .binary = .{ .result = 9, .operator = .multiply, .left = 6, .right = 8, .type = .float32 } },
        .{ .binary = .{ .result = 10, .operator = .multiply, .left = 7, .right = 8, .type = .float32 } },
        .{ .binary = .{ .result = 11, .operator = .add, .left = 9, .right = 8, .type = .float32 } },
        .{ .binary = .{ .result = 12, .operator = .add, .left = 10, .right = 8, .type = .float32 } },
        .{ .copy = .{ .result = 13, .operand = 11 } },
        .{ .copy = .{ .result = 14, .operand = 12 } },
        .{ .reference_store = .{ .reference = 3, .operand = .{ .start = 13, .width = 2, .aggregate = true } } },
        .{ .return_value = .{ .start = 11, .width = 1 } },
    };
    const groups = [_]Machine.FloatLaneGroup{
        .{ .slots = .{ 4, 5, 0, 0 }, .width = 2, .priority = 8, .recurrence = false, .in_loop = true },
        .{ .slots = .{ 6, 7, 0, 0 }, .width = 2, .priority = 8, .recurrence = false, .in_loop = true },
        .{ .slots = .{ 9, 10, 0, 0 }, .width = 2, .priority = 8, .recurrence = false, .in_loop = true },
        .{ .slots = .{ 11, 12, 0, 0 }, .width = 2, .priority = 8, .recurrence = false, .in_loop = true },
        .{ .slots = .{ 13, 14, 0, 0 }, .width = 2, .priority = 8, .recurrence = false, .in_loop = true },
    };
    var function: Machine.Function = .{
        .name = "checked_memory_lanes",
        .parameter_count = 3,
        .parameters = &.{ .{ .start = 0, .width = 2, .aggregate = true }, .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 } },
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 15,
        .frame_size = try Machine.frameSize(15),
        .instructions = &instructions,
        .float_lane_groups = &groups,
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    for ([_]usize{ 0, 1, 2, 3, 4, 5, 13, 14 }) |slot| {
        try std.testing.expectEqual(null, allocation.float_lane_residences[slot]);
    }
    for ([_]usize{ 6, 7, 9, 10, 11, 12 }) |slot| {
        try std.testing.expect(allocation.float_lane_residences[slot] != null);
    }
    // The shared allocator used by X64 retains its prior eligibility contract.
    const shared = try RegisterAllocation.allocateFloatLanePairsFor(allocator, function, &.{ 0, 1 });
    try std.testing.expectEqual(@as(usize, 0), shared.len);
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    var values = [_]u64{ @as(u32, @bitCast(@as(f32, 3))), @as(u32, @bitCast(@as(f32, -4))) };
    var stored = [_]u64{ 0, 0 };
    var view = [_]u64{ @intFromPtr(&values), 1 };
    const result = try Runner.invoke(allocator, .{ .functions = &.{function}, .strings = &.{""} }, 0, &.{
        @intCast(@intFromPtr(&view)), 0, @intCast(@intFromPtr(&stored)),
    });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    // float32 occupies the low word of a machine slot; upper bits are padding.
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 8))), @as(u32, @truncate(stored[0])));
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, -6))), @as(u32, @truncate(stored[1])));
}

test "memory kernel returns aggregate values held in SIMD lanes" {
    const builtin = @import("builtin");
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    const RegisterAllocation = @import("RegisterAllocation.zig");
    const Runner = @import("Runner.zig");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var callee: Machine.Function = .{
        .name = "paired_return",
        .parameter_count = 3,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 }, .{ .start = 2, .width = 1 } },
        .return_type = .float32,
        .return_width = 2,
        .return_aggregate = true,
        .hidden_return_slot = 7,
        .slot_count = 8,
        .frame_size = try Machine.frameSize(8),
        .instructions = &.{
            .{ .reference_load = .{ .result = .{ .start = 3, .width = 1 }, .reference = 0 } },
            .{ .binary = .{ .result = 5, .operator = .add, .left = 1, .right = 3, .type = .float32 } },
            .{ .binary = .{ .result = 6, .operator = .add, .left = 2, .right = 3, .type = .float32 } },
            .{ .return_value = .{ .start = 5, .width = 2, .aggregate = true } },
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, callee);
    callee.register_slots = allocation.residences;
    callee.float_register_slots = allocation.float_residences;
    callee.float_lane_slots = allocation.float_lane_residences;
    try std.testing.expect(callee.float_lane_slots[5] != null);
    const caller: Machine.Function = .{
        .name = "consume_return",
        .parameter_count = 3,
        .parameters = callee.parameters,
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 6,
        .frame_size = try Machine.frameSize(6),
        .instructions = &.{
            .{ .call = .{ .function = 0, .arguments = callee.parameters, .result = .{ .start = 3, .width = 2, .aggregate = true } } },
            .{ .binary = .{ .result = 5, .operator = .add, .left = 3, .right = 4, .type = .float32 } },
            .{ .return_value = .{ .start = 5, .width = 1 } },
        },
    };
    var offset: u64 = @as(u32, @bitCast(@as(f32, 3)));
    const result = try Runner.invoke(allocator, .{ .functions = &.{ callee, caller } }, 1, &.{
        @intCast(@intFromPtr(&offset)), @as(u32, @bitCast(@as(f32, 2))), @as(u32, @bitCast(@as(f32, 4))),
    });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 12))), @as(u32, @truncate(@as(u64, @bitCast(result.value)))));
}

test "memory stores consume arithmetic before a later SIMD partner" {
    const RegisterAllocation = @import("RegisterAllocation.zig");
    const Runner = @import("Runner.zig");
    const builtin = @import("builtin");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var function: Machine.Function = .{
        .name = "ordered_stores",
        .parameter_count = 5,
        .parameters = &.{
            .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 },
            .{ .start = 2, .width = 1 }, .{ .start = 3, .width = 1 },
            .{ .start = 4, .width = 1 },
        },
        .return_type = .void,
        .slot_count = 9,
        .frame_size = try Machine.frameSize(9),
        .float_lane_groups = &.{
            .{ .slots = .{ 5, 7, 0, 0 }, .width = 2, .priority = 16, .recurrence = false, .in_loop = true },
        },
        .instructions = &.{
            .{ .binary = .{ .result = 5, .operator = .multiply, .left = 2, .right = 4, .type = .float32 } },
            .{ .binary = .{ .result = 6, .operator = .add, .left = 5, .right = 4, .type = .float32 } },
            .{ .reference_store = .{ .reference = 0, .operand = .{ .start = 6, .width = 1 } } },
            .{ .binary = .{ .result = 7, .operator = .multiply, .left = 3, .right = 4, .type = .float32 } },
            .{ .binary = .{ .result = 8, .operator = .add, .left = 7, .right = 4, .type = .float32 } },
            .{ .reference_store = .{ .reference = 1, .operand = .{ .start = 8, .width = 1 } } },
            .return_void,
        },
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    try std.testing.expectEqual(null, function.float_lane_slots[5]);
    try std.testing.expectEqual(null, function.float_lane_slots[7]);
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    var first: u64 = 0;
    var second: u64 = 0;
    const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{
        @intCast(@intFromPtr(&first)),   @intCast(@intFromPtr(&second)),
        @as(u32, @bitCast(@as(f32, 3))), @as(u32, @bitCast(@as(f32, -4))),
        @as(u32, @bitCast(@as(f32, 2))),
    });
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, 8))), @as(u32, @truncate(first)));
    try std.testing.expectEqual(@as(u32, @bitCast(@as(f32, -6))), @as(u32, @truncate(second)));
}

test "aggregate reference reads materialize only used leaves at the original read" {
    const RegisterAllocation = @import("RegisterAllocation.zig");
    const Encoder = @import("Encoder.zig");
    const Runner = @import("Runner.zig");
    const builtin = @import("builtin");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const instructions = [_]Machine.Instruction{
        .{ .reference_load = .{ .reference = 0, .result = .{ .start = 1, .width = 64, .aggregate = true } } },
        .{ .constant_int = .{ .result = 65, .bits = 99 } },
        .{ .reference_store = .{ .reference = 0, .operand = .{ .start = 65, .width = 1 } } },
        .{ .return_value = .{ .start = 1, .width = 1 } },
    };
    var function: Machine.Function = .{
        .name = "projected_snapshot",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .int,
        .return_width = 1,
        .slot_count = 66,
        .frame_size = try Machine.frameSize(66),
        .instructions = &instructions,
    };
    const allocation = try RegisterAllocation.allocate(allocator, function);
    function.register_slots = allocation.residences;
    function.float_register_slots = allocation.float_residences;
    function.float_lane_slots = allocation.float_lane_residences;
    const wide = try Encoder.encode(allocator, .{ .functions = &.{function} }, .{ .test_function = 0 });
    var narrow_instructions = instructions;
    narrow_instructions[0].reference_load.result.width = 1;
    var narrow_function = function;
    narrow_function.instructions = &narrow_instructions;
    const narrow = try Encoder.encode(allocator, .{ .functions = &.{narrow_function} }, .{ .test_function = 0 });
    try std.testing.expectEqualSlices(u8, narrow.code, wide.code);
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return;
    var values = [_]u64{7} ** 64;
    const result = try Runner.invoke(allocator, .{ .functions = &.{function} }, 0, &.{@intCast(@intFromPtr(&values))});
    try std.testing.expectEqual(Machine.Status.success, result.status);
    try std.testing.expectEqual(@as(i64, 7), result.value);
    try std.testing.expectEqual(@as(u64, 99), values[0]);
    try std.testing.expectEqual(@as(u64, 7), values[63]);
}
