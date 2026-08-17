const std = @import("std");
const Machine = @import("Machine.zig");
const Allocator = std.mem.Allocator;

pub const Cursor = struct {
    entry_jump: usize,
    load_index: usize,
    collection: Machine.Span,
    initial_index: Machine.Slot,
    register: u5,
    stride: u8,
};

/// Recognizes one simple ascending collection loop whose element address can
/// live in a private volatile register. The cursor advances at the load, so
/// every path that reaches the loop backedge observes exactly one increment.
pub fn find(allocator: Allocator, function: Machine.Function) Allocator.Error!?Cursor {
    if (!cursorCompatibleFunction(function)) return null;
    var result: ?Cursor = null;
    for (function.instructions, 0..) |instruction, load_index| {
        const load = switch (instruction) {
            .collection_load => |value| value,
            else => continue,
        };
        const candidate = (try recognize(allocator, function, load_index, load)) orelse continue;
        if (result != null) return null;
        result = candidate;
    }
    return result;
}

fn recognize(
    allocator: Allocator,
    function: Machine.Function,
    load_index: usize,
    load: Machine.Instruction.CollectionLoad,
) Allocator.Error!?Cursor {
    if (load.checked or !load.dynamic or !load.view or load.result.width != 4 or
        load.element_stride == 0 or load.element_stride > 255 or load_index == 0) return null;
    const first_lane = floatLaneResidence(function, load.result.start) orelse return null;
    const second_lane = floatLaneResidence(function, load.result.start + 1) orelse return null;
    if (first_lane.register != second_lane.register or first_lane.lane != 0 or second_lane.lane != 1) return null;

    const collection_copy = switch (function.instructions[load_index - 1]) {
        .copy_range => |copy| copy,
        else => return null,
    };
    if (collection_copy.result.start != load.collection.start or
        collection_copy.result.width != load.collection.width) return null;

    var backedge: ?usize = null;
    var header: usize = 0;
    for (function.instructions[load_index + 1 ..], load_index + 1..) |instruction, index| {
        const target = switch (instruction) {
            .jump => |value| resolveJumpTarget(function.instructions, value),
            else => continue,
        };
        if (target > load_index) continue;
        if (backedge != null) return null;
        backedge = index;
        header = target;
    }
    const backedge_index = backedge orelse return null;
    if (header == 0 or header >= load_index or function.instructions[header - 1] != .jump or
        resolveJumpTarget(function.instructions, function.instructions[header - 1].jump) != header) return null;
    const induction = switch (function.instructions[header]) {
        .copy => |copy| copy,
        else => return null,
    };
    if (induction.result != load.index or backedge_index < 4) return null;
    if (!hasUnitIncrement(function.instructions, backedge_index, induction.operand)) return null;
    if (!hasOnlySelectedBackedge(function.instructions, backedge_index, header, load_index)) return null;
    if (try reachesInstructionAvoiding(allocator, function.instructions, load_index, header - 1)) return null;
    if (try reachesInstructionAvoiding(allocator, function.instructions, backedge_index, load_index)) return null;

    const collection = immutableCollectionParameter(
        function,
        load_index - 1,
        collection_copy.operand,
    ) orelse return null;

    const register = freeCursorRegister(function) orelse return null;
    return .{
        .entry_jump = header - 1,
        .load_index = load_index,
        .collection = collection,
        .initial_index = induction.operand,
        .register = register,
        .stride = @intCast(load.element_stride),
    };
}

fn hasUnitIncrement(
    instructions: []const Machine.Instruction,
    backedge: usize,
    state: Machine.Slot,
) bool {
    const source = switch (instructions[backedge - 4]) {
        .copy => |copy| copy,
        else => return false,
    };
    if (source.operand != state) return false;
    const one = switch (instructions[backedge - 3]) {
        .constant_int => |constant| constant,
        else => return false,
    };
    if (one.bits != 1) return false;
    const addition = switch (instructions[backedge - 2]) {
        .binary => |binary| binary,
        else => return false,
    };
    if (addition.operator != .add or addition.type != .int or
        !((addition.left == source.result and addition.right == one.result) or
            (addition.right == source.result and addition.left == one.result))) return false;
    const update = switch (instructions[backedge - 1]) {
        .copy => |copy| copy,
        else => return false,
    };
    return update.result == state and update.operand == addition.result;
}

fn cursorCompatibleFunction(function: Machine.Function) bool {
    for (function.capture_parameters) |_| return false;
    for (function.instructions) |instruction| switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .copy_range,
        .aggregate_init,
        .collection_count,
        .collection_load,
        .convert,
        .unary,
        .binary,
        .jump,
        .branch,
        .return_value,
        .return_void,
        => {},
        else => return false,
    };
    return true;
}

fn immutableCollectionParameter(
    function: Machine.Function,
    initial_before: usize,
    initial: Machine.Span,
) ?Machine.Span {
    var before = initial_before;
    var current = initial;
    for (0..function.instructions.len) |_| {
        const definition = definingCopyRangeBefore(function.instructions, before, current) orelse break;
        current = definition.copy.operand;
        before = definition.index;
    }
    var parameter = false;
    for (function.parameters) |candidate| {
        if (candidate.start == current.start and candidate.width == current.width) {
            parameter = true;
            break;
        }
    }
    if (!parameter) return null;
    for (function.instructions) |instruction| {
        if (definesSpan(instruction, current)) return null;
    }
    return current;
}

const CopyRangeDefinition = struct {
    index: usize,
    copy: Machine.Instruction.CopyRange,
};

fn definingCopyRangeBefore(
    instructions: []const Machine.Instruction,
    before: usize,
    span: Machine.Span,
) ?CopyRangeDefinition {
    var index = before;
    while (index != 0) {
        index -= 1;
        switch (instructions[index]) {
            .copy_range => |copy| if (copy.result.start == span.start and
                copy.result.width == span.width) return .{ .index = index, .copy = copy },
            else => {},
        }
    }
    return null;
}

fn definesSpan(instruction: Machine.Instruction, span: Machine.Span) bool {
    return switch (instruction) {
        .constant_int => |value| spanContainsSlot(span, value.result),
        .constant_bool => |value| spanContainsSlot(span, value.result),
        .constant_float32 => |value| spanContainsSlot(span, value.result),
        .constant_float64 => |value| spanContainsSlot(span, value.result),
        .copy => |value| spanContainsSlot(span, value.result),
        .copy_range => |value| spansOverlap(span, value.result),
        .aggregate_init => |value| spansOverlap(span, value.result),
        .collection_count => |value| spanContainsSlot(span, value.result),
        .collection_load => |value| spansOverlap(span, value.result),
        .convert => |value| spanContainsSlot(span, value.result),
        .unary => |value| spanContainsSlot(span, value.result),
        .binary => |value| spanContainsSlot(span, value.result),
        else => false,
    };
}

fn hasOnlySelectedBackedge(
    instructions: []const Machine.Instruction,
    selected_source: usize,
    selected_target: usize,
    load_index: usize,
) bool {
    for (instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= source) {
            const resolved = resolveJumpTarget(instructions, target);
            if (source == selected_source and resolved == selected_target) continue;
            if (resolved <= load_index) return false;
        },
        .branch => |branch_value| {
            if (branch_value.then_instruction <= source and
                resolveJumpTarget(instructions, branch_value.then_instruction) <= load_index) return false;
            if (branch_value.else_instruction <= source and
                resolveJumpTarget(instructions, branch_value.else_instruction) <= load_index) return false;
        },
        else => {},
    };
    return true;
}

fn reachesInstructionAvoiding(
    allocator: Allocator,
    instructions: []const Machine.Instruction,
    target: usize,
    blocked: usize,
) Allocator.Error!bool {
    const visited = try allocator.alloc(bool, instructions.len);
    defer allocator.free(visited);
    @memset(visited, false);
    var pending: std.ArrayList(usize) = .empty;
    defer pending.deinit(allocator);
    try pending.append(allocator, 0);
    while (pending.pop()) |index| {
        if (index >= instructions.len or index == blocked or visited[index]) continue;
        if (index == target) return true;
        visited[index] = true;
        switch (instructions[index]) {
            .jump => |next| try pending.append(allocator, next),
            .branch => |branch_value| {
                try pending.append(allocator, branch_value.then_instruction);
                try pending.append(allocator, branch_value.else_instruction);
            },
            .return_value, .return_void => {},
            else => try pending.append(allocator, index + 1),
        }
    }
    return false;
}

fn freeCursorRegister(function: Machine.Function) ?u5 {
    for ([_]u5{ 2, 3, 4, 5, 6, 7 }) |candidate| {
        var used = false;
        for (function.register_slots) |residence| {
            if (residence != null and residence.? == candidate) {
                used = true;
                break;
            }
        }
        if (!used) return candidate;
    }
    return null;
}

fn floatLaneResidence(function: Machine.Function, slot: Machine.Slot) ?Machine.FloatLaneResidence {
    if (function.float_lane_slots.len == 0) return null;
    return function.float_lane_slots[slot];
}

fn resolveJumpTarget(instructions: []const Machine.Instruction, initial: usize) usize {
    var target = initial;
    var remaining = instructions.len;
    while (remaining != 0) : (remaining -= 1) {
        target = switch (instructions[target]) {
            .jump => |next| next,
            else => return target,
        };
        if (target >= instructions.len) return initial;
    }
    return initial;
}

fn spansOverlap(left: Machine.Span, right: Machine.Span) bool {
    return left.start < @as(usize, right.start) + right.width and
        right.start < @as(usize, left.start) + left.width;
}

fn spanContainsSlot(span: Machine.Span, slot: Machine.Slot) bool {
    return slot >= span.start and @as(usize, slot) < @as(usize, span.start) + span.width;
}

test "recognize a unit-stride float32 collection cursor" {
    const instructions = cursorInstructions(1);
    const function = cursorFunction(&instructions);
    const cursor = (try find(std.testing.allocator, function)) orelse return error.TestUnexpectedResult;

    try std.testing.expectEqual(@as(usize, 2), cursor.entry_jump);
    try std.testing.expectEqual(@as(usize, 8), cursor.load_index);
    try std.testing.expectEqual(@as(Machine.Slot, 2), cursor.initial_index);
    try std.testing.expectEqual(@as(u8, 16), cursor.stride);
    try std.testing.expectEqual(@as(u5, 2), cursor.register);
}

test "reject a collection cursor whose index does not advance by one" {
    const instructions = cursorInstructions(2);
    const function = cursorFunction(&instructions);
    try std.testing.expectEqual(@as(?Cursor, null), try find(std.testing.allocator, function));
}

test "reject a collection cursor whose initialization does not dominate the load" {
    var instructions = cursorInstructions(1);
    instructions[0] = .{ .jump = 3 };
    const function = cursorFunction(&instructions);
    try std.testing.expectEqual(@as(?Cursor, null), try find(std.testing.allocator, function));
}

fn cursorInstructions(step: u64) [15]Machine.Instruction {
    return .{
        .{ .constant_int = .{ .result = 15, .bits = 0 } },
        .{ .copy = .{ .result = 2, .operand = 15 } },
        .{ .jump = 3 },
        .{ .copy = .{ .result = 3, .operand = 2 } },
        .{ .collection_count = .{ .result = 4, .collection = .{ .start = 0, .width = 2, .aggregate = true }, .view = true } },
        .{ .binary = .{ .result = 5, .operator = .less, .left = 3, .right = 4, .type = .int } },
        .{ .branch = .{ .condition = 5, .then_instruction = 7, .else_instruction = 14 } },
        .{ .copy_range = .{ .result = .{ .start = 6, .width = 2, .aggregate = true }, .operand = .{ .start = 0, .width = 2, .aggregate = true } } },
        .{ .collection_load = .{
            .result = .{ .start = 8, .width = 4, .aggregate = true },
            .collection = .{ .start = 6, .width = 2, .aggregate = true },
            .index = 3,
            .count = 0,
            .dynamic = true,
            .view = true,
            .checked = false,
            .element_stride = 16,
            .header = 0,
            .tail = 0,
        } },
        .{ .copy = .{ .result = 12, .operand = 2 } },
        .{ .constant_int = .{ .result = 13, .bits = step } },
        .{ .binary = .{ .result = 14, .operator = .add, .left = 12, .right = 13, .type = .int } },
        .{ .copy = .{ .result = 2, .operand = 14 } },
        .{ .jump = 3 },
        .return_void,
    };
}

fn cursorFunction(instructions: []const Machine.Instruction) Machine.Function {
    const parameters = &[_]Machine.Span{
        .{ .start = 0, .width = 2, .aggregate = true },
    };
    const lanes = &[_]?Machine.FloatLaneResidence{
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        null,
        .{ .register = 16, .lane = 0, .partner = 9 },
        .{ .register = 16, .lane = 1, .partner = 8 },
        null,
        null,
        null,
        null,
        null,
        null,
    };
    return .{
        .name = "cursor",
        .parameter_count = parameters.len,
        .parameters = parameters,
        .return_type = .void,
        .slot_count = lanes.len,
        .frame_size = Machine.frameSize(lanes.len) catch unreachable,
        .float_lane_slots = lanes,
        .instructions = instructions,
    };
}
