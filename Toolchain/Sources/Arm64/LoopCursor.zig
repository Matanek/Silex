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
    elided_collection_copy: ?usize,
    termination: ?Termination,
};

pub const Termination = struct {
    register: u5,
    increment_start: usize,
    increment_indices: [4]usize,
    backedge: usize,
    body: usize,

    pub fn elides(self: Termination, instruction: usize) bool {
        for (self.increment_indices) |candidate| if (candidate == instruction) return true;
        return false;
    }
};

const UnitIncrement = struct {
    source: ?usize,
    one: usize,
    addition: usize,
    update: usize,
};

const Induction = struct {
    state: Machine.Slot,
    index: Machine.Slot,
    header_copy: ?usize,
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
    const induction: Induction = switch (function.instructions[header]) {
        .copy => |copy| .{
            .state = copy.operand,
            .index = copy.result,
            .header_copy = header,
        },
        else => .{
            .state = load.index,
            .index = load.index,
            .header_copy = null,
        },
    };
    if (induction.index != load.index or backedge_index < 3) return null;
    const increment = unitIncrement(function.instructions, backedge_index, induction.state) orelse return null;
    if (!hasOnlySelectedBackedge(function.instructions, backedge_index, header, load_index)) return null;
    if (try reachesInstructionAvoiding(allocator, function.instructions, load_index, header - 1)) return null;
    if (try reachesInstructionAvoiding(allocator, function.instructions, backedge_index, load_index)) return null;

    const collection = immutableCollectionParameter(
        function,
        load_index - 1,
        collection_copy.operand,
    ) orelse return null;
    const elided_collection_copy = if (!spanUsedBetween(
        function.instructions,
        load_index + 1,
        backedge_index + 1,
        collection_copy.result,
    )) load_index - 1 else null;

    const register = freeCursorRegister(function, null, header - 1, backedge_index) orelse return null;
    const termination = if (freeCursorRegister(function, register, header - 1, backedge_index)) |end_register|
        pointerTermination(
            function,
            header,
            load_index,
            backedge_index,
            collection,
            induction,
            increment,
            end_register,
            if (elided_collection_copy != null) load_index else load_index - 1,
        )
    else
        null;
    return .{
        .entry_jump = header - 1,
        .load_index = load_index,
        .collection = collection,
        .initial_index = induction.state,
        .register = register,
        .stride = @intCast(load.element_stride),
        .elided_collection_copy = elided_collection_copy,
        .termination = termination,
    };
}

fn pointerTermination(
    function: Machine.Function,
    header: usize,
    load_index: usize,
    backedge: usize,
    collection: Machine.Span,
    induction: Induction,
    increment: UnitIncrement,
    register: u5,
    body: usize,
) ?Termination {
    if (collection.width != 2 or header + 3 >= load_index or backedge < 4 or
        !zeroInitializedBefore(function.instructions, header - 1, induction.state))
        return null;
    var count_index: ?usize = null;
    var count: Machine.Instruction.CollectionCount = undefined;
    for (function.instructions[header + 1 .. load_index], header + 1..) |instruction, index| {
        const candidate = switch (instruction) {
            .collection_count => |value| value,
            else => continue,
        };
        if (!candidate.view) continue;
        const origin = immutableCollectionParameter(function, index, candidate.collection) orelse continue;
        if (!sameSpan(origin, collection) or count_index != null) return null;
        count_index = index;
        count = candidate;
    }
    const count_at = count_index orelse return null;
    if (count_at + 2 >= load_index) return null;
    const comparison_index = count_at + 1;
    const comparison = switch (function.instructions[comparison_index]) {
        .binary => |value| value,
        else => return null,
    };
    if (comparison.operator != .less or comparison.type != .int or
        comparison.left != induction.index or comparison.right != count.result)
        return null;
    const branch_index = comparison_index + 1;
    const branch_value = switch (function.instructions[branch_index]) {
        .branch => |value| value,
        else => return null,
    };
    if (branch_value.condition != comparison.result or
        resolveJumpTarget(function.instructions, branch_value.then_instruction) != load_index - 1 or
        resolveJumpTarget(function.instructions, branch_value.else_instruction) != backedge + 1)
        return null;

    const one = function.instructions[increment.one].constant_int;
    const addition = function.instructions[increment.addition].binary;
    var state_uses: [3]usize = undefined;
    const state_use_count: usize = if (induction.header_copy != null) 2 else 3;
    if (induction.header_copy) |header_copy| {
        state_uses[0] = header_copy;
        state_uses[1] = increment.source orelse increment.addition;
    } else {
        state_uses[0] = comparison_index;
        state_uses[1] = load_index;
        state_uses[2] = increment.source orelse increment.addition;
    }
    if (!slotUsedOnlyAtIndices(function.instructions, induction.state, state_uses[0..state_use_count]) or
        (induction.index != induction.state and
            !slotUsedOnlyAtTwo(function.instructions, induction.index, comparison_index, load_index)) or
        !slotUsedOnlyAt(function.instructions, count.result, comparison_index) or
        !slotUsedOnlyAt(function.instructions, comparison.result, branch_index) or
        !slotUsedOnlyAt(function.instructions, one.result, increment.addition) or
        !slotUsedOnlyAt(function.instructions, addition.result, increment.update))
        return null;
    if (increment.source) |source| {
        const increment_source = function.instructions[source].copy;
        if (!slotUsedOnlyAt(function.instructions, increment_source.result, increment.addition)) return null;
    }

    return .{
        .register = register,
        .increment_start = increment.source orelse increment.one,
        .increment_indices = .{ increment.source orelse increment.one, increment.one, increment.addition, increment.update },
        .backedge = backedge,
        .body = body,
    };
}

fn zeroInitializedBefore(
    instructions: []const Machine.Instruction,
    before: usize,
    initial: Machine.Slot,
) bool {
    var current = initial;
    var limit = before;
    for (0..instructions.len) |_| {
        const definition = definingInstructionBefore(instructions, limit, current) orelse return false;
        switch (definition.instruction) {
            .constant_int => |constant| return constant.bits == 0,
            .copy => |copy| current = copy.operand,
            else => return false,
        }
        limit = definition.index;
    }
    return false;
}

const Definition = struct {
    index: usize,
    instruction: Machine.Instruction,
};

fn definingInstructionBefore(
    instructions: []const Machine.Instruction,
    before: usize,
    slot: Machine.Slot,
) ?Definition {
    var index = before;
    while (index != 0) {
        index -= 1;
        if (definesSlot(instructions[index], slot)) return .{
            .index = index,
            .instruction = instructions[index],
        };
    }
    return null;
}

fn slotUsedOnlyAt(
    instructions: []const Machine.Instruction,
    slot: Machine.Slot,
    allowed: usize,
) bool {
    for (instructions, 0..) |instruction, index| {
        if (instructionUsesSlot(instruction, slot) != (index == allowed)) return false;
    }
    return true;
}

fn slotUsedOnlyAtTwo(
    instructions: []const Machine.Instruction,
    slot: Machine.Slot,
    first: usize,
    second: usize,
) bool {
    for (instructions, 0..) |instruction, index| {
        if (instructionUsesSlot(instruction, slot) != (index == first or index == second)) return false;
    }
    return true;
}

fn slotUsedOnlyAtIndices(
    instructions: []const Machine.Instruction,
    slot: Machine.Slot,
    allowed: []const usize,
) bool {
    for (instructions, 0..) |instruction, index| {
        var expected = false;
        for (allowed) |candidate| if (candidate == index) {
            expected = true;
            break;
        };
        if (instructionUsesSlot(instruction, slot) != expected) return false;
    }
    return true;
}

fn spanUsedBetween(
    instructions: []const Machine.Instruction,
    start: usize,
    end: usize,
    span: Machine.Span,
) bool {
    for (instructions[start..end]) |instruction| {
        for (0..span.width) |offset| {
            const slot: Machine.Slot = @intCast(@as(usize, span.start) + offset);
            if (instructionUsesSlot(instruction, slot)) return true;
        }
    }
    return false;
}

fn unitIncrement(
    instructions: []const Machine.Instruction,
    backedge: usize,
    state: Machine.Slot,
) ?UnitIncrement {
    if (backedge < 4) return null;
    var update_index = backedge;
    var update: Machine.Instruction.Copy = undefined;
    while (update_index != 0) {
        update_index -= 1;
        const copy = switch (instructions[update_index]) {
            .copy => |value| value,
            else => return null,
        };
        if (copy.result == state) {
            update = copy;
            break;
        }
        if (copy.operand == state) return null;
    } else return null;
    for (instructions[update_index + 1 .. backedge]) |instruction| {
        const copy = instruction.copy;
        if (copy.result == state or copy.operand == state or
            copy.result == update.operand or copy.operand == update.operand) return null;
    }

    var addition_index = update_index;
    while (addition_index != 0) {
        addition_index -= 1;
        switch (instructions[addition_index]) {
            .copy => |copy| {
                if (copy.result == state or copy.operand == state or
                    copy.result == update.operand or copy.operand == update.operand) return null;
                continue;
            },
            else => {},
        }
        break;
    }
    if (addition_index < 1) return null;
    const addition = switch (instructions[addition_index]) {
        .binary => |binary| binary,
        else => return null,
    };
    if (addition.result != update.operand or addition.operator != .add or addition.type != .int) return null;
    const one_index = addition_index - 1;
    const one = switch (instructions[one_index]) {
        .constant_int => |constant| constant,
        else => return null,
    };
    if (one.bits != 1) return null;
    if ((addition.left == state and addition.right == one.result) or
        (addition.right == state and addition.left == one.result))
        return .{ .source = null, .one = one_index, .addition = addition_index, .update = update_index };
    if (addition_index < 2) return null;
    const source_index = addition_index - 2;
    const source = switch (instructions[source_index]) {
        .copy => |copy| copy,
        else => return null,
    };
    if (source.operand != state or
        !((addition.left == source.result and addition.right == one.result) or
            (addition.right == source.result and addition.left == one.result))) return null;
    return .{ .source = source_index, .one = one_index, .addition = addition_index, .update = update_index };
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
        .storage_init => |value| spansOverlap(span, value),
        .aggregate_init => |value| spansOverlap(span, value.result),
        .collection_count => |value| spanContainsSlot(span, value.result),
        .collection_load => |value| spansOverlap(span, value.result),
        .convert => |value| spanContainsSlot(span, value.result),
        .unary => |value| spanContainsSlot(span, value.result),
        .binary => |value| spanContainsSlot(span, value.result),
        else => false,
    };
}

fn definesSlot(instruction: Machine.Instruction, slot: Machine.Slot) bool {
    return switch (instruction) {
        .constant_int => |value| value.result == slot,
        .constant_bool => |value| value.result == slot,
        .constant_float32 => |value| value.result == slot,
        .constant_float64 => |value| value.result == slot,
        .copy => |value| value.result == slot,
        .copy_range => |value| spanContainsSlot(value.result, slot),
        .storage_init => |value| spanContainsSlot(value, slot),
        .aggregate_init => |value| spanContainsSlot(value.result, slot),
        .collection_count => |value| value.result == slot,
        .collection_load => |value| spanContainsSlot(value.result, slot),
        .convert => |value| value.result == slot,
        .unary => |value| value.result == slot,
        .binary => |value| value.result == slot,
        else => false,
    };
}

fn instructionUsesSlot(instruction: Machine.Instruction, slot: Machine.Slot) bool {
    return switch (instruction) {
        .copy => |value| value.operand == slot,
        .copy_range => |value| spanContainsSlot(value.operand, slot),
        .aggregate_init => |value| for (value.fields) |field| {
            if (spanContainsSlot(field, slot)) break true;
        } else false,
        .collection_count => |value| spanContainsSlot(value.collection, slot),
        .collection_load => |value| value.index == slot or spanContainsSlot(value.collection, slot),
        .convert => |value| value.operand == slot,
        .unary => |value| value.operand == slot,
        .binary => |value| value.left == slot or value.right == slot,
        .branch => |value| value.condition == slot,
        .return_value => |value| spanContainsSlot(value, slot),
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

fn freeCursorRegister(
    function: Machine.Function,
    excluded: ?u5,
    loop_start: usize,
    loop_end: usize,
) ?u5 {
    // Cursor-compatible functions contain no calls or runtime operations.
    // x15 has completed its only entry duty after the hidden result address is
    // saved, and these functions never use it again. Other volatile integer
    // colors can be borrowed when their allocated live ranges do not overlap
    // the cursor lifetime. The encoder owns x5...x7 for cached floating-point
    // literals, even though those values have no allocated machine slots.
    // The x16/x17 scalar cache is disabled for allocated functions. Register
    // allocation reserves x17 when the same structural proof identifies a
    // cursor before integer coloring.
    for ([_]u5{ 15, 0, 1, 2, 3, 4, 8, 16, 17 }) |candidate| {
        if (excluded != null and candidate == excluded.?) continue;
        var used = false;
        for (function.register_slots, 0..) |residence, slot| {
            if (residence == null or residence.? != candidate) continue;
            if (slotLiveAcrossRange(function, @intCast(slot), loop_start, loop_end)) {
                used = true;
                break;
            }
        }
        if (!used) return candidate;
    }
    return null;
}

fn slotLiveAcrossRange(
    function: Machine.Function,
    slot: Machine.Slot,
    range_start: usize,
    range_end: usize,
) bool {
    var first: usize = std.math.maxInt(usize);
    var last: usize = 0;
    for (function.parameters) |parameter| if (spanContainsSlot(parameter, slot)) {
        first = 0;
        break;
    };
    for (function.capture_parameters) |capture| if (spanContainsSlot(capture, slot)) {
        first = 0;
        break;
    };
    if (function.hidden_return_slot) |hidden| {
        if (hidden == slot) first = 0;
    }
    for (function.instructions, 0..) |instruction, index| {
        if (!definesSlot(instruction, slot) and !instructionUsesSlot(instruction, slot)) continue;
        first = @min(first, index);
        last = index;
    }
    return first != std.math.maxInt(usize) and first <= range_end and last >= range_start;
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

fn sameSpan(left: Machine.Span, right: Machine.Span) bool {
    return left.start == right.start and left.width == right.width;
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
    try std.testing.expectEqual(@as(u5, 15), cursor.register);
    const termination = cursor.termination orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u5, 0), termination.register);
    try std.testing.expectEqual(@as(usize, 9), termination.increment_start);
    try std.testing.expectEqual(@as(usize, 13), termination.backedge);
    try std.testing.expectEqual(@as(?usize, 7), cursor.elided_collection_copy);
    try std.testing.expectEqual(@as(usize, 8), termination.body);
}

test "reuse a volatile register whose value dies before the cursor loop" {
    const instructions = cursorInstructions(1);
    var function = cursorFunction(&instructions);
    var registers = [_]?u5{null} ** 16;
    registers[14] = 15;
    registers[4] = 0;
    registers[5] = 1;
    registers[15] = 2;
    function.register_slots = &registers;
    const cursor = (try find(std.testing.allocator, function)) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(u5, 2), cursor.register);
    try std.testing.expect(cursor.termination != null);
}

test "keep floating-point literal cache registers unavailable to cursors" {
    const instructions = [_]Machine.Instruction{
        .{ .copy = .{ .result = 6, .operand = 0 } },
        .{ .copy = .{ .result = 7, .operand = 1 } },
        .{ .copy = .{ .result = 8, .operand = 2 } },
        .{ .copy = .{ .result = 9, .operand = 3 } },
        .{ .copy = .{ .result = 10, .operand = 4 } },
        .{ .copy = .{ .result = 11, .operand = 5 } },
        .return_void,
    };
    const parameters = [_]Machine.Span{
        .{ .start = 0, .width = 1 },
        .{ .start = 1, .width = 1 },
        .{ .start = 2, .width = 1 },
        .{ .start = 3, .width = 1 },
        .{ .start = 4, .width = 1 },
        .{ .start = 5, .width = 1 },
    };
    const registers = [_]?u5{ 15, 0, 1, 2, 3, 4, null, null, null, null, null, null };
    const function: Machine.Function = .{
        .name = "literal_cache_reservation",
        .parameter_count = parameters.len,
        .parameters = &parameters,
        .return_type = .void,
        .slot_count = registers.len,
        .frame_size = try Machine.frameSize(registers.len),
        .register_slots = &registers,
        .instructions = &instructions,
    };

    try std.testing.expectEqual(@as(?u5, 8), freeCursorRegister(function, null, 0, 5));
}

test "recognize a coalesced induction without header or increment copies" {
    const instructions = cursorInstructionsWithCoalescedInduction();
    const function = cursorFunction(&instructions);
    const cursor = (try find(std.testing.allocator, function)) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(Machine.Slot, 2), cursor.initial_index);
    const termination = cursor.termination orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 9), termination.increment_start);
    try std.testing.expectEqual(@as(usize, 12), termination.backedge);
    try std.testing.expectEqual(@as(?usize, 7), cursor.elided_collection_copy);
    try std.testing.expectEqual(@as(usize, 8), termination.body);
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

test "retain index induction when the loop body observes it" {
    const instructions = cursorInstructionsWithVisibleIndex();
    const function = cursorFunction(&instructions);
    const cursor = (try find(std.testing.allocator, function)) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(?Termination, null), cursor.termination);
}

test "recognize pointer termination through a copied count view" {
    const instructions = cursorInstructionsWithCountCopy();
    const function = cursorFunction(&instructions);
    const cursor = (try find(std.testing.allocator, function)) orelse return error.TestUnexpectedResult;
    const termination = cursor.termination orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(@as(usize, 10), termination.increment_start);
    try std.testing.expectEqual(@as(usize, 14), termination.backedge);
    try std.testing.expectEqual(@as(?usize, 8), cursor.elided_collection_copy);
    try std.testing.expectEqual(@as(usize, 9), termination.body);
}

test "recognize pointer termination across an independent SSA edge copy" {
    const source = cursorInstructions(1);
    const instructions = [_]Machine.Instruction{
        source[0],
        source[1],
        source[2],
        source[3],
        source[4],
        source[5],
        .{ .branch = .{ .condition = 5, .then_instruction = 7, .else_instruction = 15 } },
        source[7],
        source[8],
        source[9],
        source[10],
        source[11],
        .{ .copy = .{ .result = 10, .operand = 11 } },
        source[12],
        source[13],
        source[14],
    };
    const function = cursorFunction(&instructions);
    const cursor = (try find(std.testing.allocator, function)) orelse return error.TestUnexpectedResult;
    const termination = cursor.termination orelse return error.TestUnexpectedResult;
    try std.testing.expect(termination.elides(9));
    try std.testing.expect(termination.elides(10));
    try std.testing.expect(termination.elides(11));
    try std.testing.expect(!termination.elides(12));
    try std.testing.expect(termination.elides(13));
    try std.testing.expectEqual(@as(usize, 14), termination.backedge);
}

test "recognize pointer termination before independent recurrence edge copies" {
    const source = cursorInstructions(1);
    const instructions = [_]Machine.Instruction{
        source[0],
        source[1],
        source[2],
        source[3],
        source[4],
        source[5],
        .{ .branch = .{ .condition = 5, .then_instruction = 7, .else_instruction = 15 } },
        source[7],
        source[8],
        source[9],
        source[10],
        source[11],
        source[12],
        .{ .copy = .{ .result = 10, .operand = 11 } },
        source[13],
        source[14],
    };
    const function = cursorFunction(&instructions);
    const cursor = (try find(std.testing.allocator, function)) orelse return error.TestUnexpectedResult;
    const termination = cursor.termination orelse return error.TestUnexpectedResult;
    try std.testing.expect(termination.elides(9));
    try std.testing.expect(termination.elides(10));
    try std.testing.expect(termination.elides(11));
    try std.testing.expect(termination.elides(12));
    try std.testing.expect(!termination.elides(13));
    try std.testing.expectEqual(@as(usize, 14), termination.backedge);
}

fn cursorInstructionsWithCountCopy() [16]Machine.Instruction {
    const source = cursorInstructions(1);
    return .{
        source[0],
        source[1],
        source[2],
        source[3],
        .{ .copy_range = .{
            .result = .{ .start = 6, .width = 2, .aggregate = true },
            .operand = .{ .start = 0, .width = 2, .aggregate = true },
        } },
        .{ .collection_count = .{
            .result = 4,
            .collection = .{ .start = 6, .width = 2, .aggregate = true },
            .view = true,
        } },
        source[5],
        .{ .branch = .{ .condition = 5, .then_instruction = 8, .else_instruction = 15 } },
        source[7],
        source[8],
        source[9],
        source[10],
        source[11],
        source[12],
        source[13],
        source[14],
    };
}

fn cursorInstructionsWithVisibleIndex() [16]Machine.Instruction {
    const source = cursorInstructions(1);
    return .{
        source[0],
        source[1],
        source[2],
        source[3],
        source[4],
        source[5],
        .{ .branch = .{ .condition = 5, .then_instruction = 7, .else_instruction = 15 } },
        source[7],
        source[8],
        .{ .copy = .{ .result = 15, .operand = 3 } },
        source[9],
        source[10],
        source[11],
        source[12],
        source[13],
        source[14],
    };
}

fn cursorInstructionsWithCoalescedInduction() [14]Machine.Instruction {
    return .{
        .{ .constant_int = .{ .result = 15, .bits = 0 } },
        .{ .copy = .{ .result = 2, .operand = 15 } },
        .{ .jump = 3 },
        .{ .copy_range = .{ .result = .{ .start = 6, .width = 2, .aggregate = true }, .operand = .{ .start = 0, .width = 2, .aggregate = true } } },
        .{ .collection_count = .{ .result = 4, .collection = .{ .start = 6, .width = 2, .aggregate = true }, .view = true } },
        .{ .binary = .{ .result = 5, .operator = .less, .left = 2, .right = 4, .type = .int } },
        .{ .branch = .{ .condition = 5, .then_instruction = 7, .else_instruction = 13 } },
        .{ .copy_range = .{ .result = .{ .start = 6, .width = 2, .aggregate = true }, .operand = .{ .start = 0, .width = 2, .aggregate = true } } },
        .{ .collection_load = .{
            .result = .{ .start = 8, .width = 4, .aggregate = true },
            .collection = .{ .start = 6, .width = 2, .aggregate = true },
            .index = 2,
            .count = 0,
            .dynamic = true,
            .view = true,
            .checked = false,
            .element_stride = 16,
            .header = 0,
            .tail = 0,
        } },
        .{ .constant_int = .{ .result = 13, .bits = 1 } },
        .{ .binary = .{ .result = 14, .operator = .add, .left = 2, .right = 13, .type = .int } },
        .{ .copy = .{ .result = 2, .operand = 14 } },
        .{ .jump = 3 },
        .return_void,
    };
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
