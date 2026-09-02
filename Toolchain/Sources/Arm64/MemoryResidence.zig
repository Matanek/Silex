const Machine = @import("Machine.zig");
const std = @import("std");

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

// These leaf memory operations use stack homes and scratch x9...x15. Their
// error paths terminate the function; their successful paths call no runtime.
// Keep addresses, indices and composite operands in memory; scalar loads and
// reference stores can transfer directly to registers. No local_address is
// admitted: indirect writes therefore
// cannot modify a register-resident local behind the allocator's back.
pub fn supports(instruction: Machine.Instruction) bool {
    return switch (instruction) {
        .reference_load,
        .reference_store,
        .reference_offset,
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
            forced[value.reference] = true;
            if (value.result.width != 1) pinSpan(value.result, forced);
        },
        .reference_store => |value| {
            forced[value.reference] = true;
            if (value.operand.width != 1) pinSpan(value.operand, forced);
        },
        .reference_offset => |value| {
            forced[value.reference] = true;
            forced[value.result] = true;
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
            pinSpan(value.collection, forced);
            forced[value.index] = true;
            forced[value.result] = true;
            if (value.reference) |reference| forced[reference] = true;
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
    for ([_]usize{ 0, 1, 2, 3 }) |slot| {
        try std.testing.expectEqual(null, result.residences[slot]);
        try std.testing.expectEqual(null, result.float_residences[slot]);
        try std.testing.expectEqual(null, result.float_lane_residences[slot]);
    }
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
