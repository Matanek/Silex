const std = @import("std");
const Machine = @import("Machine.zig");

const Allocator = std.mem.Allocator;

const Interval = struct {
    slot: Machine.Slot,
    first: usize,
    last: usize,
    weight: u64,
};

pub const Result = struct {
    residences: []const ?u5,
    float_residences: []const ?u5,
    float_lane_residences: []const ?Machine.FloatLaneResidence,
    frame_size: u16,
};

/// Keeps scalar values in the callee-saved ARM64 registers x19...x28. The
/// accepted instruction subset is deliberately explicit: every operation
/// outside it keeps the entire function stack-resident until its encoder can
/// consume and produce registered values safely.
pub fn allocate(allocator: Allocator, function: Machine.Function) (Allocator.Error || Machine.Error)!Result {
    if (!isCompatibleFunction(function)) return spilled(allocator, function);

    const residences = try allocator.alloc(?u5, function.slot_count);
    @memset(residences, null);
    const float_residences = try allocator.alloc(?u5, function.slot_count);
    @memset(float_residences, null);
    const float_lane_residences = try allocator.alloc(?Machine.FloatLaneResidence, function.slot_count);
    @memset(float_lane_residences, null);
    const float_slots = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(float_slots);
    @memset(float_slots, false);
    inferFloatSlots(function, float_slots);
    try allocateFloatPairs(allocator, function, float_slots, float_lane_residences);
    const forced = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(forced);
    @memset(forced, false);
    const first = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(first);
    const last = try allocator.alloc(usize, function.slot_count);
    defer allocator.free(last);
    const weights = try allocator.alloc(u64, function.slot_count);
    defer allocator.free(weights);
    const instruction_weights = try allocator.alloc(u64, function.instructions.len);
    defer allocator.free(instruction_weights);
    @memset(first, std.math.maxInt(usize));
    @memset(last, 0);
    @memset(weights, 0);
    @memset(instruction_weights, 1);
    weightLoops(function.instructions, instruction_weights);

    for (function.parameters) |parameter| {
        if (isCollectionParameter(function, parameter)) {
            for (0..parameter.width) |leaf| {
                touch(@intCast(@as(usize, parameter.start) + leaf), 0, first, last, weights, 1);
            }
        } else if (parameter.aggregate or parameter.width != 1) {
            forceSpan(parameter, forced);
        } else touch(parameter.start, 0, first, last, weights, 1);
    }
    for (function.instructions, 0..) |instruction, index| {
        visit(instruction, index, first, last, weights, instruction_weights[index]);
        forceStackOperands(instruction, forced);
    }
    extendLoopCarriedIntervals(function.instructions, first, last);

    var integer_intervals: std.ArrayList(Interval) = .empty;
    defer integer_intervals.deinit(allocator);
    var float_intervals: std.ArrayList(Interval) = .empty;
    defer float_intervals.deinit(allocator);
    for (first, 0..) |start, slot| {
        if (start == std.math.maxInt(usize) or forced[slot]) continue;
        const interval: Interval = .{
            .slot = @intCast(slot),
            .first = start,
            .last = last[slot],
            .weight = weights[slot],
        };
        if (float_slots[slot] and float_lane_residences[slot] == null) {
            try float_intervals.append(allocator, interval);
        } else try integer_intervals.append(allocator, interval);
    }
    try allocateGraph(
        allocator,
        residences,
        integer_intervals.items,
        &.{ 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 16, 17, 0, 1, 2, 3, 4, 5, 6, 7, 8 },
        function.instructions,
        function.slot_count,
    );
    // Incoming arguments occupy x0...x7 until every parameter has been
    // captured by the prologue. Keep parameter residences out of that range;
    // later temporaries may freely reuse those volatile registers because
    // compatible functions contain no calls.
    for (function.parameters) |parameter| for (0..parameter.width) |leaf| {
        const slot: Machine.Slot = @intCast(@as(usize, parameter.start) + leaf);
        if (residences[slot]) |register| {
            if (register <= 7) residences[slot] = null;
        }
    };
    // Float scalars and SLP groups occupy one physical register class. Keep
    // the proven group placement stable, but let scalar colors borrow v0...v7
    // whenever their live ranges do not interfere with a resident group.
    for (float_lane_residences, 0..) |lane, slot| if (lane) |residence| {
        float_residences[slot] = residence.register;
    };
    try allocateGraph(
        allocator,
        float_residences,
        float_intervals.items,
        &.{ 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 8, 13, 14, 15, 0, 1, 2, 3, 4, 5, 6, 7 },
        function.instructions,
        function.slot_count,
    );
    for (float_lane_residences, 0..) |lane, slot| if (lane != null) {
        float_residences[slot] = null;
    };
    return .{
        .residences = residences,
        .float_residences = float_residences,
        .float_lane_residences = float_lane_residences,
        .frame_size = function.frame_size,
    };
}

fn isCollectionParameter(function: Machine.Function, parameter: Machine.Span) bool {
    if (parameter.width != 2) return false;
    for (function.instructions) |instruction| switch (instruction) {
        .collection_load => |load| if (load.collection.start == parameter.start and
            load.collection.width == parameter.width) return true,
        .collection_count => |count| if (count.collection.start == parameter.start and
            count.collection.width == parameter.width) return true,
        else => {},
    };
    return false;
}

fn allocateGraph(
    allocator: Allocator,
    residences: []?u5,
    intervals: []Interval,
    registers: []const u5,
    instructions: []const Machine.Instruction,
    slot_count: usize,
) Allocator.Error!void {
    const live = try allocator.alloc(bool, instructions.len * slot_count);
    defer allocator.free(live);
    @memset(live, false);

    var changed = true;
    while (changed) {
        changed = false;
        var reverse = instructions.len;
        while (reverse != 0) {
            reverse -= 1;
            for (0..slot_count) |slot| {
                const out = successorLive(instructions, live, slot_count, reverse, slot);
                const value = instructionUses(instructions[reverse], slot) or
                    (out and !instructionDefines(instructions[reverse], slot));
                const at = reverse * slot_count + slot;
                if (live[at] != value) {
                    live[at] = value;
                    changed = true;
                }
            }
        }
    }

    std.mem.sort(Interval, intervals, {}, heavierThan);
    for (intervals) |interval| {
        if (copyPartner(interval.slot, instructions)) |partner| {
            if (residences[partner]) |preferred| {
                if (!colorConflicts(interval.slot, preferred, residences, live, instructions, slot_count)) {
                    residences[interval.slot] = preferred;
                    continue;
                }
            }
        }
        for (registers) |register| {
            if (!colorConflicts(interval.slot, register, residences, live, instructions, slot_count)) {
                residences[interval.slot] = register;
                break;
            }
        }
    }
}

fn successorLive(
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
    index: usize,
    slot: usize,
) bool {
    return switch (instructions[index]) {
        .jump => |target| live[target * slot_count + slot],
        .branch => |branch_value| live[branch_value.then_instruction * slot_count + slot] or
            live[branch_value.else_instruction * slot_count + slot],
        .return_value, .return_void => false,
        else => if (index + 1 < instructions.len) live[(index + 1) * slot_count + slot] else false,
    };
}

fn instructionUses(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .copy => |value| value.operand == slot,
        .copy_range => |value| spanContains(value.operand, slot),
        .aggregate_init => |value| for (value.fields) |field| {
            if (spanContains(field, slot)) break true;
        } else false,
        .unary => |value| value.operand == slot,
        .binary => |value| value.left == slot or value.right == slot,
        .convert => |value| value.operand == slot,
        .collection_load => |value| value.index == slot or spanContains(value.collection, slot),
        .collection_count => |value| spanContains(value.collection, slot),
        .call => |call| for (call.arguments) |argument| {
            if (spanContains(argument, slot)) break true;
        } else false,
        .return_value => |value| spanContains(value, slot),
        .branch => |value| value.condition == slot,
        else => false,
    };
}

fn instructionDefines(instruction: Machine.Instruction, slot: usize) bool {
    return switch (instruction) {
        .constant_int => |value| value.result == slot,
        .constant_bool => |value| value.result == slot,
        .constant_float32 => |value| value.result == slot,
        .constant_float64 => |value| value.result == slot,
        .copy => |value| value.result == slot,
        .copy_range => |value| spanContains(value.result, slot),
        .aggregate_init => |value| spanContains(value.result, slot),
        .unary => |value| value.result == slot,
        .binary => |value| value.result == slot,
        .convert => |value| value.result == slot,
        .collection_load => |value| spanContains(value.result, slot),
        .collection_count => |value| value.result == slot,
        .call => |call| if (call.result) |result| spanContains(result, slot) else false,
        else => false,
    };
}

fn spanContains(span: Machine.Span, slot: usize) bool {
    return slot >= span.start and slot < @as(usize, span.start) + span.width;
}

fn copyPartner(slot: Machine.Slot, instructions: []const Machine.Instruction) ?Machine.Slot {
    // Prefer the instruction that defines the slot. A loop value often also
    // appears as an operand of an earlier copy; choosing that unrelated edge
    // first prevents the actual defining copy from being coalesced.
    for (instructions) |instruction| switch (instruction) {
        .copy => |copy| if (copy.result == slot) return copy.operand,
        .copy_range => |copy| for (0..copy.result.width) |leaf| {
            const result: Machine.Slot = @intCast(@as(usize, copy.result.start) + leaf);
            if (result == slot) return @intCast(@as(usize, copy.operand.start) + leaf);
        },
        .collection_count => |count| if (count.view and count.result == slot) return count.collection.start + 1,
        .unary => |unary| if (unary.result == slot) return unary.operand,
        .binary => |binary| if (binaryCanShareOperand(binary) and binary.result == slot) return binary.left,
        else => {},
    };
    for (instructions) |instruction| switch (instruction) {
        .copy => |copy| {
            if (copy.result == slot) return copy.operand;
            if (copy.operand == slot) return copy.result;
        },
        .copy_range => |copy| for (0..copy.result.width) |leaf| {
            const result: Machine.Slot = @intCast(@as(usize, copy.result.start) + leaf);
            const operand: Machine.Slot = @intCast(@as(usize, copy.operand.start) + leaf);
            if (result == slot) return operand;
            if (operand == slot) return result;
        },
        .collection_count => |count| if (count.view) {
            const operand = count.collection.start + 1;
            if (count.result == slot) return operand;
            if (operand == slot) return count.result;
        },
        .unary => |unary| {
            if (unary.result == slot) return unary.operand;
            if (unary.operand == slot) return unary.result;
        },
        .binary => |binary| if (binaryCanShareOperand(binary)) {
            if (binary.result == slot) return binary.left;
            if (binary.left == slot) return binary.result;
        },
        else => {},
    };
    return null;
}

fn colorConflicts(
    slot: Machine.Slot,
    register: u5,
    residences: []const ?u5,
    live: []const bool,
    instructions: []const Machine.Instruction,
    slot_count: usize,
) bool {
    for (residences, 0..) |residence, other| {
        if (residence == null or residence.? != register or other == slot) continue;
        if (slotsArePureAliases(instructions, live, slot_count, slot, @intCast(other))) continue;
        for (0..live.len / slot_count) |instruction| {
            if (instructionCanShareResidence(
                instructions,
                live,
                slot_count,
                instruction,
                slot,
                other,
            )) continue;
            if (live[instruction * slot_count + slot] and live[instruction * slot_count + other]) return true;
            if (instructionDefines(instructions[instruction], slot) and live[instruction * slot_count + other]) return true;
            if (instructionDefines(instructions[instruction], other) and live[instruction * slot_count + slot]) return true;
        }
    }
    return false;
}

fn slotsArePureAliases(
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
    left: Machine.Slot,
    right: Machine.Slot,
) bool {
    const pair = for (instructions, 0..) |instruction, index| {
        if (pureAliasPair(instruction, left, right)) |alias| break .{ .alias = alias, .index = index };
    } else return false;
    var result_definitions: usize = 0;
    for (instructions, 0..) |instruction, index| {
        if (instructionDefines(instruction, pair.alias.result)) {
            result_definitions += 1;
            if (index != pair.index) return false;
        }
        if (instructionDefines(instruction, pair.alias.operand) and
            (live[index * slot_count + pair.alias.result] or
                successorLive(instructions, live, slot_count, index, pair.alias.result))) return false;
    }
    return result_definitions == 1;
}

const PureAlias = struct { result: Machine.Slot, operand: Machine.Slot };

fn pureAliasPair(instruction: Machine.Instruction, left: Machine.Slot, right: Machine.Slot) ?PureAlias {
    return switch (instruction) {
        .copy => |copy| if ((copy.result == left and copy.operand == right) or
            (copy.result == right and copy.operand == left))
            .{ .result = copy.result, .operand = copy.operand }
        else
            null,
        .copy_range => |copy| for (0..copy.result.width) |leaf| {
            const result: Machine.Slot = @intCast(@as(usize, copy.result.start) + leaf);
            const operand: Machine.Slot = @intCast(@as(usize, copy.operand.start) + leaf);
            if ((result == left and operand == right) or (result == right and operand == left)) {
                break .{ .result = result, .operand = operand };
            }
        } else null,
        .collection_count => |count| if (count.view and
            ((count.result == left and count.collection.start + 1 == right) or
                (count.result == right and count.collection.start + 1 == left)))
            .{ .result = count.result, .operand = count.collection.start + 1 }
        else
            null,
        else => null,
    };
}

fn instructionCanShareResidence(
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
    instruction_index: usize,
    left: usize,
    right: usize,
) bool {
    const source = destructiveSourceForPair(instructions[instruction_index], left, right) orelse return false;
    return !successorLive(instructions, live, slot_count, instruction_index, source);
}

fn destructiveSourceForPair(instruction: Machine.Instruction, left: usize, right: usize) ?Machine.Slot {
    return switch (instruction) {
        .copy => |copy| if ((copy.result == left and copy.operand == right) or
            (copy.result == right and copy.operand == left)) copy.operand else null,
        .copy_range => |copy| for (0..copy.result.width) |leaf| {
            const result: Machine.Slot = @intCast(@as(usize, copy.result.start) + leaf);
            const operand: Machine.Slot = @intCast(@as(usize, copy.operand.start) + leaf);
            if ((result == left and operand == right) or (result == right and operand == left)) break operand;
        } else null,
        .unary => |unary| if ((unary.result == left and unary.operand == right) or
            (unary.result == right and unary.operand == left)) unary.operand else null,
        .binary => |binary| if (binaryCanShareOperand(binary) and
            ((binary.result == left and binary.left == right) or
                (binary.result == right and binary.left == left))) binary.left else null,
        else => null,
    };
}

fn binaryCanShareOperand(binary: Machine.Instruction.Binary) bool {
    if (binary.type.isFloat()) return switch (binary.operator) {
        .add, .subtract, .multiply, .divide => true,
        else => false,
    };
    return switch (binary.operator) {
        .add, .subtract, .divide, .remainder, .bit_and, .bit_xor, .shift_left, .shift_right => true,
        else => false,
    };
}

fn heavierThan(_: void, left: Interval, right: Interval) bool {
    return left.weight > right.weight or (left.weight == right.weight and left.slot < right.slot);
}

fn allocateIntervals(residences: []?u5, intervals: []Interval, registers: []const u5) !void {
    std.mem.sort(Interval, intervals, {}, lessThan);
    var active_last = [_]?usize{null} ** 32;
    var active_slot = [_]?Machine.Slot{null} ** 32;
    var active_weight = [_]u64{0} ** 32;
    for (intervals) |interval| {
        var allocated = false;
        for (active_last[0..registers.len], registers, 0..) |*end, register, register_index| {
            if (end.* == null or end.*.? < interval.first) {
                residences[interval.slot] = register;
                end.* = interval.last;
                active_slot[register_index] = interval.slot;
                active_weight[register_index] = interval.weight;
                allocated = true;
                break;
            }
        }
        if (allocated) continue;

        var victim: usize = 0;
        for (1..registers.len) |register_index| {
            if (active_weight[register_index] < active_weight[victim]) victim = register_index;
        }
        if (interval.weight <= active_weight[victim]) continue;
        residences[active_slot[victim].?] = null;
        residences[interval.slot] = registers[victim];
        active_last[victim] = interval.last;
        active_slot[victim] = interval.slot;
        active_weight[victim] = interval.weight;
    }
}

fn spilled(allocator: Allocator, function: Machine.Function) Allocator.Error!Result {
    return .{
        .residences = try allocator.alloc(?u5, 0),
        .float_residences = try allocator.alloc(?u5, 0),
        .float_lane_residences = try allocator.alloc(?Machine.FloatLaneResidence, 0),
        .frame_size = function.frame_size,
    };
}

fn inferFloatSlots(function: Machine.Function, result: []bool) void {
    if (function.return_type.isFloat()) {
        for (function.instructions) |instruction| switch (instruction) {
            .return_value => |value| if (!value.aggregate and value.width == 1) {
                result[value.start] = true;
            },
            else => {},
        };
    }
    for (function.instructions) |instruction| switch (instruction) {
        .constant_float32 => |value| result[value.result] = true,
        .constant_float64 => |value| result[value.result] = true,
        .unary => |value| if (value.type.isFloat()) {
            result[value.operand] = true;
            result[value.result] = true;
        },
        .binary => |value| if (value.type.isFloat()) {
            result[value.left] = true;
            result[value.right] = true;
            switch (value.operator) {
                .add, .subtract, .multiply, .divide => result[value.result] = true,
                else => {},
            }
        },
        .convert => |value| {
            if (value.source.isFloat()) result[value.operand] = true;
            if (value.target.isFloat()) result[value.result] = true;
        },
        else => {},
    };
    var changed = true;
    while (changed) {
        changed = false;
        for (function.instructions) |instruction| switch (instruction) {
            .copy => |copy| propagateFloat(copy.result, copy.operand, result, &changed),
            .copy_range => |copy| for (0..copy.result.width) |leaf| {
                propagateFloat(
                    @intCast(@as(usize, copy.result.start) + leaf),
                    @intCast(@as(usize, copy.operand.start) + leaf),
                    result,
                    &changed,
                );
            },
            .aggregate_init => |value| {
                var destination_offset: usize = 0;
                for (value.fields) |field| {
                    for (0..field.width) |leaf| {
                        propagateFloat(
                            @intCast(@as(usize, value.result.start) + destination_offset + leaf),
                            @intCast(@as(usize, field.start) + leaf),
                            result,
                            &changed,
                        );
                    }
                    destination_offset += field.width;
                }
            },
            else => {},
        };
    }
}

fn allocateFloatPairs(
    allocator: Allocator,
    function: Machine.Function,
    float_slots: []const bool,
    residences: []?Machine.FloatLaneResidence,
) Allocator.Error!void {
    const partners = try allocator.alloc(?Machine.Slot, function.slot_count);
    defer allocator.free(partners);
    @memset(partners, null);
    const planned = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(planned);
    @memset(planned, false);

    // Prefer affinity discovered while scalar values still have their IR
    // identity. ARM64 consumes pairs today; XYZ remains one portable group and
    // is lowered as XY plus a scalar Z until a profitable .4s realization is
    // selected by this backend.
    for (function.float_lane_groups) |group| {
        if (group.priority == 0) continue;
        var lane: usize = 0;
        while (lane + 1 < group.width) : (lane += 2) {
            const first = group.slots[lane];
            const second = group.slots[lane + 1];
            if (float_slots[first] and float_slots[second] and
                partners[first] == null and partners[second] == null)
            {
                pairSlots(partners, first, second);
                if (group.in_loop and group.recurrence and group.priority >= 8) {
                    planned[first] = true;
                    planned[second] = true;
                }
            }
        }
    }

    var changed = true;
    while (changed) {
        changed = false;
        for (function.instructions) |instruction| switch (instruction) {
            .copy_range => |copy| {
                var leaf: usize = 0;
                while (leaf + 1 < copy.result.width) : (leaf += 2) {
                    const first_result: Machine.Slot = @intCast(@as(usize, copy.result.start) + leaf);
                    const second_result = first_result + 1;
                    const first_operand: Machine.Slot = @intCast(@as(usize, copy.operand.start) + leaf);
                    const second_operand = first_operand + 1;
                    if (partners[first_result] == null and partners[second_result] == null and
                        partners[first_operand] == second_operand)
                    {
                        pairSlots(partners, first_result, second_result);
                        changed = true;
                    }
                }
            },
            .aggregate_init => |initialization| {
                var result_offset: usize = 0;
                for (initialization.fields) |field| {
                    var leaf: usize = 0;
                    while (leaf + 1 < field.width) : (leaf += 2) {
                        const first_result: Machine.Slot = @intCast(@as(usize, initialization.result.start) + result_offset + leaf);
                        const second_result = first_result + 1;
                        const first_operand: Machine.Slot = @intCast(@as(usize, field.start) + leaf);
                        const second_operand = first_operand + 1;
                        if (partners[first_result] == null and partners[second_result] == null and
                            partners[first_operand] == second_operand)
                        {
                            pairSlots(partners, first_result, second_result);
                            changed = true;
                        }
                    }
                    result_offset += field.width;
                }
            },
            else => {},
        };
        for (function.instructions, 0..) |first_instruction, first_index| {
            const first_result = pairableResult(first_instruction) orelse continue;
            if (!float_slots[first_result] or partners[first_result] != null or
                definingInstruction(function.instructions, first_result) == null) continue;
            const end = @min(function.instructions.len, first_index + 17);
            for (function.instructions[first_index + 1 .. end], first_index + 1..) |second_instruction, second_index| {
                const second_result = pairableResult(second_instruction) orelse continue;
                if (!float_slots[second_result] or partners[second_result] != null or first_result == second_result or
                    definingInstruction(function.instructions, second_result) == null) continue;
                if (!instructionsCanPair(function.instructions, first_index, second_index, first_instruction)) continue;
                if (!definitionsFormFloatPair(first_instruction, second_instruction, partners)) continue;
                if (!binaryOperandsCanBecomeResident(function.instructions, first_instruction, second_instruction, partners)) continue;
                pairSlots(partners, first_result, second_result);
                pairBinaryOperands(function.instructions, partners, first_instruction, second_instruction);
                changed = true;
                break;
            }
        }
    }

    var intervals: std.ArrayList(Interval) = .empty;
    defer intervals.deinit(allocator);
    for (partners, 0..) |partner, slot| {
        if (partner == null or partner.? <= slot) continue;
        var first: usize = std.math.maxInt(usize);
        var last: usize = 0;
        var weight: u64 = 0;
        for (function.instructions, 0..) |instruction, index| {
            if (instructionUses(instruction, slot) or instructionDefines(instruction, slot) or
                instructionUses(instruction, partner.?) or instructionDefines(instruction, partner.?))
            {
                first = @min(first, index);
                last = @max(last, index);
                weight += 1;
            }
        }
        if (first != std.math.maxInt(usize)) try intervals.append(allocator, .{
            .slot = @intCast(slot),
            .first = first,
            .last = last,
            .weight = weight,
        });
    }
    const pair_registers = [_]u5{ 0, 1, 2, 3, 4, 5, 6, 7 };
    const leaders = try allocator.alloc(?u5, function.slot_count);
    defer allocator.free(leaders);
    @memset(leaders, null);
    try allocatePairGraph(
        allocator,
        leaders,
        intervals.items,
        &pair_registers,
        partners,
        function.instructions,
        function.slot_count,
    );
    for (intervals.items) |interval| if (leaders[interval.slot]) |register| {
        const partner = partners[interval.slot].?;
        residences[interval.slot] = .{ .register = register, .lane = 0, .partner = partner };
        residences[partner] = .{ .register = register, .lane = 1, .partner = interval.slot };
    };
    try pruneUnprofitableFloatPairs(allocator, function.instructions, residences, planned);
}

fn allocatePairGraph(
    allocator: Allocator,
    leaders: []?u5,
    intervals: []Interval,
    registers: []const u5,
    partners: []const ?Machine.Slot,
    instructions: []const Machine.Instruction,
    slot_count: usize,
) Allocator.Error!void {
    const components = try allocator.alloc(Machine.Slot, slot_count);
    defer allocator.free(components);
    for (components, 0..) |*component, slot| component.* = @intCast(slot);
    buildPairComponents(components, partners, instructions);

    var component_intervals: std.ArrayList(Interval) = .empty;
    defer component_intervals.deinit(allocator);
    for (intervals) |interval| {
        const component = findPairComponent(components, interval.slot);
        var found = false;
        for (component_intervals.items) |*existing| {
            if (existing.slot != component) continue;
            existing.first = @min(existing.first, interval.first);
            existing.last = @max(existing.last, interval.last);
            existing.weight += interval.weight;
            found = true;
            break;
        }
        if (!found) {
            try component_intervals.append(allocator, .{
                .slot = component,
                .first = interval.first,
                .last = interval.last,
                .weight = interval.weight,
            });
        }
    }
    const component_colors = try allocator.alloc(?u5, slot_count);
    defer allocator.free(component_colors);
    @memset(component_colors, null);
    try allocateIntervals(component_colors, component_intervals.items, registers);
    for (intervals) |interval| leaders[interval.slot] = component_colors[findPairComponent(components, interval.slot)];
}

fn buildPairComponents(
    components: []Machine.Slot,
    partners: []const ?Machine.Slot,
    instructions: []const Machine.Instruction,
) void {
    for (instructions) |instruction| switch (instruction) {
        .copy => |copy| unionPairedTransfer(components, partners, copy.result, copy.operand),
        .binary => |binary| if (binaryCanShareOperand(binary)) {
            unionPairedTransfer(components, partners, binary.result, binary.left);
        },
        else => {},
    };
}

fn unionPairedTransfer(
    components: []Machine.Slot,
    partners: []const ?Machine.Slot,
    result: Machine.Slot,
    operand: Machine.Slot,
) void {
    const result_partner = partners[result] orelse return;
    const operand_partner = partners[operand] orelse return;
    if (result_partner <= result or operand_partner <= operand) return;
    const left = findPairComponent(components, result);
    const right = findPairComponent(components, operand);
    if (left != right) components[@max(left, right)] = @min(left, right);
    const left_partner = findPairComponent(components, result_partner);
    const right_partner = findPairComponent(components, operand_partner);
    if (left_partner != right_partner) components[@max(left_partner, right_partner)] = @min(left_partner, right_partner);
}

fn findPairComponent(components: []const Machine.Slot, slot: Machine.Slot) Machine.Slot {
    var result = slot;
    while (components[result] != result) result = components[result];
    return result;
}

fn preferredPairSource(
    leader: Machine.Slot,
    follower: Machine.Slot,
    partners: []const ?Machine.Slot,
    instructions: []const Machine.Instruction,
) ?Machine.Slot {
    const first = definingInstruction(instructions, leader) orelse return null;
    const second = definingInstruction(instructions, follower) orelse return null;
    const sources = switch (first) {
        .copy => |left| switch (second) {
            .copy => |right| .{ left.operand, right.operand },
            else => return null,
        },
        .binary => |left| switch (second) {
            .binary => |right| .{ left.left, right.left },
            else => return null,
        },
        else => return null,
    };
    if (sources[0] == sources[1]) return null;
    if (partners[sources[0]] != sources[1]) return null;
    return @min(sources[0], sources[1]);
}

fn pruneUnprofitableFloatPairs(
    allocator: Allocator,
    instructions: []const Machine.Instruction,
    residences: []?Machine.FloatLaneResidence,
    planned: []const bool,
) Allocator.Error!void {
    const required = try allocator.alloc(bool, residences.len);
    defer allocator.free(required);
    @memset(required, false);
    for (planned, 0..) |keep, slot| if (keep and residences[slot] != null) {
        const residence = residences[slot].?;
        if (residence.lane == 0) markPairDependencies(
            instructions,
            residences,
            required,
            @intCast(slot),
            residence.partner,
        );
    };

    var changed = true;
    while (changed) {
        changed = false;
        for (residences, 0..) |residence, slot| {
            if (residence == null or residence.?.lane != 0) continue;
            if (required[slot] and required[residence.?.partner]) continue;
            if (pairDefinitionReady(instructions, residences, @intCast(slot), residence.?.partner)) continue;
            residences[slot] = null;
            residences[residence.?.partner] = null;
            changed = true;
        }
    }

    for (residences, 0..) |residence, slot| {
        if (residence == null or residence.?.lane != 0) continue;
        const first = definingInstruction(instructions, @intCast(slot)) orelse continue;
        const second = definingInstruction(instructions, residence.?.partner) orelse continue;
        if (first == .binary and second == .binary) {
            markPairDependencies(instructions, residences, required, @intCast(slot), residence.?.partner);
        }
    }
    for (residences, 0..) |residence, slot| if (residence != null and !required[slot]) {
        residences[slot] = null;
    };
}

fn pairDefinitionReady(
    instructions: []const Machine.Instruction,
    residences: []const ?Machine.FloatLaneResidence,
    first_slot: Machine.Slot,
    second_slot: Machine.Slot,
) bool {
    const first = definingInstruction(instructions, first_slot);
    const second = definingInstruction(instructions, second_slot);
    if (first == null or second == null) return first == null and second == null;
    return switch (first.?) {
        .binary => |left| switch (second.?) {
            .binary => |right| slotsResidentInOrderOrEqual(residences, left.left, right.left) and
                slotsResidentInOrderOrEqual(residences, left.right, right.right),
            else => false,
        },
        .copy => |left| switch (second.?) {
            .copy => |right| slotsResidentInOrderOrEqual(residences, left.operand, right.operand),
            else => false,
        },
        .collection_load => |left| switch (second.?) {
            .collection_load => |right| left.result.start == right.result.start and left.result.width == right.result.width,
            else => false,
        },
        .constant_float32 => |left| switch (second.?) {
            .constant_float32 => |right| left.bits == right.bits,
            else => false,
        },
        else => false,
    };
}

fn slotsResidentInOrderOrEqual(
    residences: []const ?Machine.FloatLaneResidence,
    first: Machine.Slot,
    second: Machine.Slot,
) bool {
    if (first == second) return true;
    const left = residences[first] orelse return false;
    const right = residences[second] orelse return false;
    return left.register == right.register and left.lane == 0 and right.lane == 1;
}

fn markPairDependencies(
    instructions: []const Machine.Instruction,
    residences: []const ?Machine.FloatLaneResidence,
    required: []bool,
    first_slot: Machine.Slot,
    second_slot: Machine.Slot,
) void {
    if (required[first_slot] and required[second_slot]) return;
    required[first_slot] = true;
    required[second_slot] = true;
    const first = definingInstruction(instructions, first_slot) orelse return;
    const second = definingInstruction(instructions, second_slot) orelse return;
    switch (first) {
        .binary => |left| switch (second) {
            .binary => |right| {
                markOperandDependency(instructions, residences, required, left.left, right.left);
                markOperandDependency(instructions, residences, required, left.right, right.right);
            },
            else => {},
        },
        .copy => |left| switch (second) {
            .copy => |right| markOperandDependency(instructions, residences, required, left.operand, right.operand),
            else => {},
        },
        else => {},
    }
}

fn markOperandDependency(
    instructions: []const Machine.Instruction,
    residences: []const ?Machine.FloatLaneResidence,
    required: []bool,
    first: Machine.Slot,
    second: Machine.Slot,
) void {
    if (first == second) return;
    const left = residences[first] orelse return;
    const right = residences[second] orelse return;
    if (left.register != right.register or left.lane != 0 or right.lane != 1) return;
    markPairDependencies(instructions, residences, required, first, second);
}

fn instructionsCanPair(
    instructions: []const Machine.Instruction,
    first_index: usize,
    second_index: usize,
    first: Machine.Instruction,
) bool {
    const values = switch (first) {
        .copy => |value| [_]Machine.Slot{ value.operand, value.result, value.result },
        .binary => |value| [_]Machine.Slot{ value.left, value.right, value.result },
        else => return false,
    };
    for (instructions[first_index + 1 .. second_index]) |instruction| {
        switch (instruction) {
            .jump, .branch, .return_value, .return_void => return false,
            else => {},
        }
        if (instructionUses(instruction, values[2])) return false;
        if (instructionDefines(instruction, values[0]) or instructionDefines(instruction, values[1])) return false;
    }
    return true;
}

fn pairableResult(instruction: Machine.Instruction) ?Machine.Slot {
    return switch (instruction) {
        .binary => |value| if (value.type == .float32 and switch (value.operator) {
            .add, .subtract, .multiply, .divide => true,
            else => false,
        }) value.result else null,
        else => null,
    };
}

fn pairBinaryOperands(
    instructions: []const Machine.Instruction,
    partners: []?Machine.Slot,
    first: Machine.Instruction,
    second: Machine.Instruction,
) void {
    const left = switch (first) {
        .binary => |value| value,
        else => return,
    };
    const right = switch (second) {
        .binary => |value| value,
        else => return,
    };
    if (left.left != right.left) pairResidentOperandTree(instructions, partners, left.left, right.left);
    if (left.right != right.right) pairResidentOperandTree(instructions, partners, left.right, right.right);
}

fn pairResidentOperandTree(
    instructions: []const Machine.Instruction,
    partners: []?Machine.Slot,
    first: Machine.Slot,
    second: Machine.Slot,
) void {
    pairSlots(partners, first, second);
    const first_definition = definingInstruction(instructions, first) orelse return;
    const second_definition = definingInstruction(instructions, second) orelse return;
    const first_copy = switch (first_definition) {
        .copy => |value| value,
        else => return,
    };
    const second_copy = switch (second_definition) {
        .copy => |value| value,
        else => return,
    };
    if (operandPairCanBecomeResident(instructions, first_copy.operand, second_copy.operand, partners)) {
        pairResidentOperandTree(instructions, partners, first_copy.operand, second_copy.operand);
    }
}

fn binaryOperandsCanBecomeResident(
    instructions: []const Machine.Instruction,
    first: Machine.Instruction,
    second: Machine.Instruction,
    partners: []const ?Machine.Slot,
) bool {
    const left = switch (first) {
        .binary => |value| value,
        else => return true,
    };
    const right = switch (second) {
        .binary => |value| value,
        else => return true,
    };
    return operandPairCanBecomeResident(instructions, left.left, right.left, partners) and
        operandPairCanBecomeResident(instructions, left.right, right.right, partners);
}

fn operandPairCanBecomeResident(
    instructions: []const Machine.Instruction,
    first: Machine.Slot,
    second: Machine.Slot,
    partners: []const ?Machine.Slot,
) bool {
    if (slotsPairedInOrderOrEqual(partners, first, second)) return true;
    if (first == second or partners[first] != null or partners[second] != null) return false;
    const first_definition = definingInstruction(instructions, first);
    const second_definition = definingInstruction(instructions, second);
    if (first_definition == null or second_definition == null) {
        return first_definition == null and second_definition == null and first + 1 == second;
    }
    return switch (first_definition.?) {
        .copy => switch (second_definition.?) {
            .copy => true,
            else => false,
        },
        .collection_load => |left| switch (second_definition.?) {
            .collection_load => |right| first + 1 == second and
                left.result.start == right.result.start and left.result.width == right.result.width,
            else => false,
        },
        .constant_float32 => |left| switch (second_definition.?) {
            .constant_float32 => |right| left.bits == right.bits,
            else => false,
        },
        else => false,
    };
}

fn pairSlots(partners: []?Machine.Slot, first: Machine.Slot, second: Machine.Slot) void {
    if (partners[first] != null or partners[second] != null) return;
    partners[first] = second;
    partners[second] = first;
}

fn definingInstruction(instructions: []const Machine.Instruction, slot: Machine.Slot) ?Machine.Instruction {
    var result: ?Machine.Instruction = null;
    for (instructions) |instruction| if (instructionDefines(instruction, slot)) {
        if (result != null) return null;
        result = instruction;
    };
    return result;
}

fn definitionsFormFloatPair(
    first: Machine.Instruction,
    second: Machine.Instruction,
    partners: []const ?Machine.Slot,
) bool {
    return switch (first) {
        .constant_float32 => |left| switch (second) {
            .constant_float32 => |right| left.bits == right.bits,
            else => false,
        },
        .copy => |left| switch (second) {
            .copy => |right| slotsPairedInOrderOrEqual(partners, left.operand, right.operand),
            else => false,
        },
        .binary => |left| switch (second) {
            .binary => |right| left.type == .float32 and right.type == .float32 and
                left.operator == right.operator and
                slotsCompatibleForSlp(partners, left.left, right.left) and
                slotsCompatibleForSlp(partners, left.right, right.right),
            else => false,
        },
        else => false,
    };
}

fn slotsCompatibleForSlp(partners: []const ?Machine.Slot, first: Machine.Slot, second: Machine.Slot) bool {
    return slotsPairedInOrderOrEqual(partners, first, second) or
        (first != second and partners[first] == null and partners[second] == null);
}

fn slotsPairedInOrderOrEqual(partners: []const ?Machine.Slot, first: Machine.Slot, second: Machine.Slot) bool {
    return first == second or (first < second and partners[first] == second);
}

fn propagateFloat(left: Machine.Slot, right: Machine.Slot, result: []bool, changed: *bool) void {
    if (result[left] == result[right]) return;
    result[left] = true;
    result[right] = true;
    changed.* = true;
}

fn isCompatibleFunction(function: Machine.Function) bool {
    var has_unchecked_collection_load = false;
    for (function.instructions) |instruction| switch (instruction) {
        .collection_load => |load| has_unchecked_collection_load = has_unchecked_collection_load or !load.checked,
        else => {},
    };
    for (function.capture_parameters) |_| return false;
    for (function.instructions) |instruction| switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .collection_count,
        .convert,
        .unary,
        .return_value,
        .return_void,
        .jump,
        .branch,
        => {},
        .copy_range, .aggregate_init => if (!has_unchecked_collection_load) return false,
        .collection_load => |load| if (load.checked) return false,
        .binary => |binary| if (binary.type == .str) return false,
        else => return false,
    };
    return true;
}

fn forceStackOperands(instruction: Machine.Instruction, forced: []bool) void {
    switch (instruction) {
        .collection_load => |load| {
            _ = load;
        },
        .collection_count => |count| {
            _ = count;
        },
        .call => |call| {
            for (call.arguments) |argument| if (argument.aggregate) forceSpan(argument, forced);
            if (call.result) |result| if (result.aggregate) forceSpan(result, forced);
        },
        .return_value => |value| if (value.aggregate) forceSpan(value, forced),
        else => {},
    }
}

fn forceSpan(span: Machine.Span, forced: []bool) void {
    for (0..span.width) |leaf| forced[@as(usize, span.start) + leaf] = true;
}

fn visit(
    instruction: Machine.Instruction,
    index: usize,
    first: []usize,
    last: []usize,
    weights: []u64,
    weight: u64,
) void {
    switch (instruction) {
        .constant_int => |value| touch(value.result, index, first, last, weights, weight),
        .constant_bool => |value| touch(value.result, index, first, last, weights, weight),
        .constant_float32 => |value| touch(value.result, index, first, last, weights, weight),
        .constant_float64 => |value| touch(value.result, index, first, last, weights, weight),
        .copy => |value| {
            touch(value.operand, index, first, last, weights, weight);
            touch(value.result, index, first, last, weights, weight);
        },
        .copy_range => |value| for (0..value.result.width) |leaf| {
            touch(@intCast(@as(usize, value.operand.start) + leaf), index, first, last, weights, weight);
            touch(@intCast(@as(usize, value.result.start) + leaf), index, first, last, weights, weight);
        },
        .aggregate_init => |value| {
            var destination_offset: usize = 0;
            for (value.fields) |field| {
                for (0..field.width) |leaf| {
                    touch(@intCast(@as(usize, field.start) + leaf), index, first, last, weights, weight);
                    touch(@intCast(@as(usize, value.result.start) + destination_offset + leaf), index, first, last, weights, weight);
                }
                destination_offset += field.width;
            }
        },
        .unary => |value| {
            touch(value.operand, index, first, last, weights, weight);
            touch(value.result, index, first, last, weights, weight);
        },
        .binary => |value| {
            touch(value.left, index, first, last, weights, weight);
            touch(value.right, index, first, last, weights, weight);
            touch(value.result, index, first, last, weights, weight);
        },
        .convert => |value| {
            touch(value.operand, index, first, last, weights, weight);
            touch(value.result, index, first, last, weights, weight);
        },
        .collection_load => |value| {
            touch(value.index, index, first, last, weights, weight);
            for (0..value.result.width) |leaf| {
                touch(@intCast(@as(usize, value.result.start) + leaf), index, first, last, weights, weight);
            }
        },
        .collection_count => |value| touch(value.result, index, first, last, weights, weight),
        .call => |call| {
            for (call.arguments) |argument| if (!argument.aggregate) touch(argument.start, index, first, last, weights, weight);
            if (call.result) |result| if (!result.aggregate) touch(result.start, index, first, last, weights, weight);
        },
        .return_value => |value| if (!value.aggregate) touch(value.start, index, first, last, weights, weight),
        .branch => |value| touch(value.condition, index, first, last, weights, weight),
        else => {},
    }
}

fn weightLoops(instructions: []const Machine.Instruction, weights: []u64) void {
    for (instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= source) weightRange(target, source, weights),
        .branch => |value| {
            if (value.then_instruction <= source) weightRange(value.then_instruction, source, weights);
            if (value.else_instruction <= source) weightRange(value.else_instruction, source, weights);
        },
        else => {},
    };
}

fn weightRange(first: usize, last: usize, weights: []u64) void {
    for (weights[first .. last + 1]) |*weight| weight.* = std.math.mul(u64, weight.*, 32) catch std.math.maxInt(u64);
}

fn extendLoopCarriedIntervals(instructions: []const Machine.Instruction, first: []const usize, last: []usize) void {
    for (instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= source) extendBackEdge(target, source, first, last),
        .branch => |value| {
            if (value.then_instruction <= source) extendBackEdge(value.then_instruction, source, first, last);
            if (value.else_instruction <= source) extendBackEdge(value.else_instruction, source, first, last);
        },
        else => {},
    };
}

fn extendBackEdge(target: usize, source: usize, first: []const usize, last: []usize) void {
    for (first, last) |start, *end| {
        if (start < target and end.* >= target and end.* < source) end.* = source;
    }
}

fn touch(slot: Machine.Slot, index: usize, first: []usize, last: []usize, weights: []u64, weight: u64) void {
    first[slot] = @min(first[slot], index);
    last[slot] = @max(last[slot], index);
    weights[slot] = std.math.add(u64, weights[slot], weight) catch std.math.maxInt(u64);
}

fn lessThan(_: void, left: Interval, right: Interval) bool {
    return left.first < right.first or (left.first == right.first and left.slot < right.slot);
}

test "graph allocation coalesces a dead arithmetic operand with its result" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 20 } },
        .{ .constant_int = .{ .result = 1, .bits = 22 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const function: Machine.Function = .{
        .name = "answer",
        .parameter_count = 0,
        .return_type = .int,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);
    try std.testing.expectEqual(@as(?u5, 19), result.residences[0]);
    try std.testing.expectEqual(@as(?u5, 20), result.residences[1]);
    try std.testing.expectEqual(result.residences[0], result.residences[2]);
    try std.testing.expectEqual(function.frame_size, result.frame_size);
}

test "linear scan keeps operands distinct at their shared instruction" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 1, .bits = 0 } },
        .{ .binary = .{ .result = 2, .operator = .less, .left = 0, .right = 1, .type = .float32 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const parameters = [_]Machine.Span{.{ .start = 0, .width = 1 }};
    const function: Machine.Function = .{
        .name = "compare",
        .parameter_count = 1,
        .parameters = &parameters,
        .return_type = .bool,
        .return_width = 1,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);
    try std.testing.expect(result.float_residences[0] != result.float_residences[1]);
}

test "loop-carried scalar coalesces with its next value across a back edge" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 0 } },
        .{ .constant_int = .{ .result = 1, .bits = 1 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .copy = .{ .result = 0, .operand = 2 } },
        .{ .jump = 2 },
    };
    const function: Machine.Function = .{
        .name = "loop",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);
    try std.testing.expectEqual(result.residences[0], result.residences[2]);
}

test "collection view parameters and scalar accumulators use registers" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 2, .bits = 0 } },
        .{ .collection_load = .{
            .result = .{ .start = 3, .width = 2, .aggregate = true },
            .collection = .{ .start = 0, .width = 2, .aggregate = true },
            .index = 2,
            .count = 0,
            .dynamic = true,
            .checked = false,
            .header = 0,
            .tail = 0,
        } },
        .{ .constant_float32 = .{ .result = 5, .bits = 0 } },
        .{ .copy = .{ .result = 6, .operand = 5 } },
        .return_void,
    };
    const parameters = [_]Machine.Span{.{ .start = 0, .width = 2, .aggregate = true }};
    const function: Machine.Function = .{
        .name = "accumulate",
        .parameter_count = 1,
        .parameters = &parameters,
        .return_type = .void,
        .slot_count = 7,
        .frame_size = try Machine.frameSize(7),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);
    for (0..2) |slot| try std.testing.expect(result.residences[slot] != null);
    try std.testing.expect(result.residences[2] != null);
    try std.testing.expect(result.residences[3] != null);
    try std.testing.expect(result.residences[4] != null);
    try std.testing.expect(result.float_residences[5] != null);
    try std.testing.expect(result.float_residences[6] != null);
}

test "numeric conversion operands and results stay in their register banks" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 7 } },
        .{ .convert = .{
            .result = 1,
            .operand = 0,
            .source = .int,
            .target = .float32,
            .checked = true,
            .header = 0,
        } },
        .{ .return_value = .{ .start = 1, .width = 1 } },
    };
    const function: Machine.Function = .{
        .name = "converted",
        .parameter_count = 0,
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 2,
        .frame_size = try Machine.frameSize(2),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);
    try std.testing.expect(result.residences[0] != null);
    try std.testing.expect(result.float_residences[1] != null);
}

test "profitable float32 xy arithmetic remains resident in neon lanes" {
    const instructions = [_]Machine.Instruction{
        .{ .binary = .{ .result = 4, .operator = .add, .left = 0, .right = 2, .type = .float32 } },
        .{ .binary = .{ .result = 5, .operator = .add, .left = 1, .right = 3, .type = .float32 } },
        .{ .return_value = .{ .start = 4, .width = 2, .aggregate = true } },
    };
    const parameters = [_]Machine.Span{
        .{ .start = 0, .width = 1 },
        .{ .start = 1, .width = 1 },
        .{ .start = 2, .width = 1 },
        .{ .start = 3, .width = 1 },
    };
    const function: Machine.Function = .{
        .name = "add_xy",
        .parameter_count = parameters.len,
        .parameters = &parameters,
        .return_type = .float32,
        .return_width = 2,
        .slot_count = 6,
        .frame_size = try Machine.frameSize(6),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);

    const x = result.float_lane_residences[4] orelse return error.TestUnexpectedResult;
    const y = result.float_lane_residences[5] orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(x.register, y.register);
    try std.testing.expectEqual(@as(u1, 0), x.lane);
    try std.testing.expectEqual(@as(u1, 1), y.lane);
    try std.testing.expectEqual(@as(Machine.Slot, 5), x.partner);
    try std.testing.expectEqual(@as(Machine.Slot, 4), y.partner);
}

test "SLP copies and destructive arithmetic keep one physical register" {
    const instructions = [_]Machine.Instruction{
        .{ .binary = .{ .result = 4, .operator = .add, .left = 0, .right = 2, .type = .float32 } },
        .{ .binary = .{ .result = 5, .operator = .add, .left = 1, .right = 3, .type = .float32 } },
        .{ .copy = .{ .result = 6, .operand = 4 } },
        .{ .copy = .{ .result = 7, .operand = 5 } },
        .{ .binary = .{ .result = 8, .operator = .multiply, .left = 6, .right = 2, .type = .float32 } },
        .{ .binary = .{ .result = 9, .operator = .multiply, .left = 7, .right = 3, .type = .float32 } },
        .{ .return_value = .{ .start = 8, .width = 2, .aggregate = true } },
    };
    const groups = [_]Machine.FloatLaneGroup{
        .{ .slots = .{ 4, 5, 0, 0 }, .width = 2, .priority = 8, .recurrence = true, .in_loop = true },
        .{ .slots = .{ 6, 7, 0, 0 }, .width = 2, .priority = 8, .recurrence = true, .in_loop = true },
        .{ .slots = .{ 8, 9, 0, 0 }, .width = 2, .priority = 16, .recurrence = true, .in_loop = true },
    };
    const function: Machine.Function = .{
        .name = "resident_chain",
        .parameter_count = 4,
        .parameters = &.{
            .{ .start = 0, .width = 1 },
            .{ .start = 1, .width = 1 },
            .{ .start = 2, .width = 1 },
            .{ .start = 3, .width = 1 },
        },
        .return_type = .float32,
        .return_width = 2,
        .return_aggregate = true,
        .slot_count = 10,
        .frame_size = try Machine.frameSize(10),
        .float_lane_groups = &groups,
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);

    const register = (result.float_lane_residences[4] orelse return error.TestUnexpectedResult).register;
    for (4..10) |slot| try std.testing.expectEqual(
        register,
        (result.float_lane_residences[slot] orelse return error.TestUnexpectedResult).register,
    );
}
