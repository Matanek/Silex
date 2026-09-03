const std = @import("std");
const Machine = @import("Machine.zig");
const MemoryResidence = @import("MemoryResidence.zig");
const FloatPairs = @import("FloatPairs.zig");
const ResidenceLiveness = @import("ResidenceLiveness.zig");
const successorLive = ResidenceLiveness.successorLive;
const instructionUses = ResidenceLiveness.instructionUses;
const instructionDefines = ResidenceLiveness.instructionDefines;
const spanContains = ResidenceLiveness.spanContains;

test {
    _ = @import("MemoryResidence.zig");
}

const Allocator = std.mem.Allocator;

const Interval = ResidenceLiveness.Interval;

pub const Result = struct {
    residences: []const ?u5,
    float_residences: []const ?u5,
    float_lane_residences: []const ?Machine.FloatLaneResidence,
    frame_size: u32,
};

/// Places target-independent SLP pairs in a caller-selected SIMD register
/// set. Backends remain free to pass an empty or baseline-only register set;
/// unsupported functions keep the scalar machine form.
pub fn allocateFloatLanePairsFor(
    allocator: Allocator,
    function: Machine.Function,
    registers: []const u5,
) Allocator.Error![]const ?Machine.FloatLaneResidence {
    if (!isCompatibleFunction(function, false, &.{}) or registers.len == 0) return try allocator.alloc(?Machine.FloatLaneResidence, 0);
    const residences = try allocator.alloc(?Machine.FloatLaneResidence, function.slot_count);
    @memset(residences, null);
    const float_slots = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(float_slots);
    @memset(float_slots, false);
    inferFloatSlots(function, float_slots);
    try FloatPairs.allocate(allocator, function, float_slots, residences, registers);
    return residences;
}

/// Keeps scalar values in the callee-saved ARM64 registers x19...x28. Large
/// frames reserve x28 as the base of their second directly addressed window.
/// The
/// accepted instruction subset is deliberately explicit: every operation
/// outside it keeps the entire function stack-resident until its encoder can
/// consume and produce registered values safely.
pub fn allocate(allocator: Allocator, function: Machine.Function) (Allocator.Error || Machine.Error)!Result {
    return allocateWithExternals(allocator, function, &.{});
}

pub fn allocateWithExternals(allocator: Allocator, function: Machine.Function, externals: []const Machine.ExternalFunction) (Allocator.Error || Machine.Error)!Result {
    if (!isCompatibleFunction(function, true, externals)) return spilled(allocator, function);
    // Actual C calls preserve x19...x28 and only the low 64 bits of v8...v15.
    // Keep the existing argument/result stack homes and use preserved colors
    // for the whole function. Scratch v9...v12 remain excluded as before.
    const has_calls = for (function.instructions) |instruction| {
        if (instruction == .external_call and
            MemoryResidence.copySignPrecision(externals[instruction.external_call.function]) == null) break true;
    } else false;

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
    const pair_registers = [_]u5{
        16, 17, 18, 19, 20, 21, 22, 23,
        24, 25, 26, 27, 28, 29, 30, 31,
        8,  13, 14, 15, 0,  1,  2,  3,
        4,  5,  6,  7,
    };
    const float_registers: []const u5 = if (has_calls) &.{ 8, 13, 14, 15 } else &pair_registers;
    try FloatPairs.allocate(allocator, function, float_slots, float_lane_residences, float_registers);
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
    const integer_registers: []const u5 = if (has_calls)
        (if (function.slot_count >= Machine.direct_stack_slots)
            &.{ 19, 20, 21, 22, 23, 24, 25, 26, 27 }
        else
            &.{ 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 })
    else if (function.slot_count >= Machine.direct_stack_slots)
        &[_]u5{ 19, 20, 21, 22, 23, 24, 25, 26, 27, 16, 17, 0, 1, 2, 3, 4, 5, 6, 7, 8 }
    else
        &[_]u5{ 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 16, 17, 0, 1, 2, 3, 4, 5, 6, 7, 8 };
    try allocateGraph(
        allocator,
        residences,
        integer_intervals.items,
        integer_registers,
        function.instructions,
        function.slot_count,
    );
    // Incoming arguments occupy x0...x7 until every parameter has been
    // captured by the prologue. Keep parameter residences out of that range;
    // Call-free functions may still reuse volatile registers for temporaries.
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
        float_registers,
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

    const alias_roots = try allocator.alloc(Machine.Slot, slot_count);
    defer allocator.free(alias_roots);
    try buildPureAliasRoots(allocator, alias_roots, instructions, live, slot_count);
    coalesceCopyAffinityRoots(alias_roots, instructions, live, slot_count);

    std.mem.sort(Interval, intervals, {}, heavierThan);
    for (intervals) |interval| {
        if (residences[interval.slot] != null) continue;
        const root = alias_roots[interval.slot];
        if (preferredComponentResidence(root, residences, alias_roots, instructions)) |preferred| {
            if (!componentColorConflicts(root, preferred, residences, alias_roots, live, instructions, slot_count, intervals)) {
                assignComponentResidence(root, preferred, residences, alias_roots, intervals);
                continue;
            }
        }
        for (registers) |register| {
            if (!componentColorConflicts(root, register, residences, alias_roots, live, instructions, slot_count, intervals)) {
                assignComponentResidence(root, register, residences, alias_roots, intervals);
                break;
            }
        }
    }
}

fn preferredComponentResidence(
    root: Machine.Slot,
    residences: []const ?u5,
    roots: []const Machine.Slot,
    instructions: []const Machine.Instruction,
) ?u5 {
    for (roots, 0..) |candidate_root, slot| {
        if (candidate_root != root) continue;
        if (preferredCopyResidence(@intCast(slot), residences, instructions)) |residence| return residence;
        if (copyPartner(@intCast(slot), instructions)) |partner| {
            if (residences[partner]) |residence| return residence;
        }
    }
    return null;
}

fn componentColorConflicts(
    root: Machine.Slot,
    register: u5,
    residences: []const ?u5,
    roots: []const Machine.Slot,
    live: []const bool,
    instructions: []const Machine.Instruction,
    slot_count: usize,
    intervals: []const Interval,
) bool {
    for (intervals) |interval| {
        if (roots[interval.slot] != root) continue;
        if (colorConflicts(interval.slot, register, residences, roots, live, instructions, slot_count)) return true;
    }
    return false;
}

fn assignComponentResidence(
    root: Machine.Slot,
    register: u5,
    residences: []?u5,
    roots: []const Machine.Slot,
    intervals: []const Interval,
) void {
    for (intervals) |interval| if (roots[interval.slot] == root) {
        residences[interval.slot] = register;
    };
}

fn preferredCopyResidence(
    slot: Machine.Slot,
    residences: []const ?u5,
    instructions: []const Machine.Instruction,
) ?u5 {
    for (instructions) |instruction| switch (instruction) {
        .copy => |copy| {
            const partner = if (copy.result == slot)
                copy.operand
            else if (copy.operand == slot)
                copy.result
            else
                continue;
            if (residences[partner]) |residence| return residence;
        },
        .copy_range => |copy| for (0..copy.result.width) |leaf| {
            const result: Machine.Slot = @intCast(@as(usize, copy.result.start) + leaf);
            const operand: Machine.Slot = @intCast(@as(usize, copy.operand.start) + leaf);
            const partner = if (result == slot)
                operand
            else if (operand == slot)
                result
            else
                continue;
            if (residences[partner]) |residence| return residence;
        },
        else => {},
    };
    return null;
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
    alias_roots: []const Machine.Slot,
    live: []const bool,
    instructions: []const Machine.Instruction,
    slot_count: usize,
) bool {
    for (residences, 0..) |residence, other| {
        if (residence == null or residence.? != register or other == slot) continue;
        if (alias_roots[slot] == alias_roots[other]) continue;
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

fn preferredAliasResidence(
    slot: Machine.Slot,
    residences: []const ?u5,
    alias_roots: []const Machine.Slot,
) ?u5 {
    for (residences, 0..) |residence, other| {
        if (residence != null and alias_roots[slot] == alias_roots[other]) return residence;
    }
    return null;
}

fn buildPureAliasRoots(
    allocator: Allocator,
    roots: []Machine.Slot,
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
) Allocator.Error!void {
    const operands = try allocator.alloc(?Machine.Slot, slot_count);
    defer allocator.free(operands);
    @memset(operands, null);
    for (0..slot_count) |slot| {
        operands[slot] = safePureAliasOperand(instructions, live, slot_count, @intCast(slot));
    }
    for (roots, 0..) |*root, slot| {
        root.* = @intCast(slot);
        var steps: usize = 0;
        while (operands[root.*]) |operand| {
            root.* = operand;
            steps += 1;
            if (steps == slot_count) break;
        }
    }
}

fn coalesceCopyAffinityRoots(
    roots: []Machine.Slot,
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
) void {
    for (instructions) |instruction| switch (instruction) {
        .copy => |copy| mergeNonInterferingRoots(roots, copy.result, copy.operand, instructions, live, slot_count),
        .copy_range => |copy| for (0..copy.result.width) |leaf| {
            mergeNonInterferingRoots(
                roots,
                @intCast(@as(usize, copy.result.start) + leaf),
                @intCast(@as(usize, copy.operand.start) + leaf),
                instructions,
                live,
                slot_count,
            );
        },
        else => {},
    };
}

fn mergeNonInterferingRoots(
    roots: []Machine.Slot,
    left: Machine.Slot,
    right: Machine.Slot,
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
) void {
    const left_root = roots[left];
    const right_root = roots[right];
    if (left_root == right_root or componentsInterfere(
        roots,
        left_root,
        right_root,
        instructions,
        live,
        slot_count,
    )) return;
    for (roots) |*root| if (root.* == right_root) {
        root.* = left_root;
    };
}

fn componentsInterfere(
    roots: []const Machine.Slot,
    left_root: Machine.Slot,
    right_root: Machine.Slot,
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
) bool {
    for (roots, 0..) |root, left| {
        if (root != left_root) continue;
        for (roots, 0..) |other_root, right| {
            if (other_root != right_root) continue;
            for (instructions, 0..) |_, instruction| {
                if (instructionCanShareResidence(instructions, live, slot_count, instruction, left, right)) continue;
                if (live[instruction * slot_count + left] and live[instruction * slot_count + right]) return true;
                if (instructionDefines(instructions[instruction], left) and live[instruction * slot_count + right]) return true;
                if (instructionDefines(instructions[instruction], right) and live[instruction * slot_count + left]) return true;
            }
        }
    }
    return false;
}

fn safePureAliasOperand(
    instructions: []const Machine.Instruction,
    live: []const bool,
    slot_count: usize,
    result: Machine.Slot,
) ?Machine.Slot {
    var definition_index: ?usize = null;
    var operand: ?Machine.Slot = null;
    for (instructions, 0..) |instruction, index| {
        if (!instructionDefines(instruction, result)) continue;
        if (definition_index != null) return null;
        definition_index = index;
        operand = switch (instruction) {
            .copy => |copy| copy.operand,
            .copy_range => |copy| @intCast(@as(usize, copy.operand.start) + result - copy.result.start),
            .collection_count => |count| if (count.view) count.collection.start + 1 else null,
            else => null,
        };
        if (operand == null) return null;
    }
    if (definition_index == null or operand == null) return null;
    for (instructions, 0..) |instruction, index| {
        if (instructionDefines(instruction, operand.?) and
            (live[index * slot_count + result] or successorLive(instructions, live, slot_count, index, result))) return null;
    }
    return operand;
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

const heavierThan = ResidenceLiveness.heavierThan;

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

fn propagateFloat(left: Machine.Slot, right: Machine.Slot, result: []bool, changed: *bool) void {
    if (result[left] == result[right]) return;
    result[left] = true;
    result[right] = true;
    changed.* = true;
}

fn isCompatibleFunction(function: Machine.Function, allow_stack_effects: bool, externals: []const Machine.ExternalFunction) bool {
    if (function.reuses_slots) return false;
    const memory_leaf = allow_stack_effects and MemoryResidence.required(function);
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
        .copy_range, .aggregate_init => if (!has_unchecked_collection_load and !memory_leaf) return false,
        .collection_load => |load| if (load.checked and !(allow_stack_effects and MemoryResidence.supports(instruction))) return false,
        .binary => |binary| if (binary.type == .str) return false,
        .external_call => |call| if (!allow_stack_effects or call.function >= externals.len or
            !MemoryResidence.scalarMathCall(externals[call.function])) return false,
        else => if (!allow_stack_effects or !MemoryResidence.supports(instruction)) return false,
    };
    return true;
}

pub fn supportsMemoryScheduling(function: Machine.Function, externals: []const Machine.ExternalFunction) bool {
    return MemoryResidence.required(function) and isCompatibleFunction(function, true, externals);
}

fn forceStackOperands(instruction: Machine.Instruction, forced: []bool) void {
    MemoryResidence.pin(instruction, forced);
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

test "transitive pure float copies share one scalar register" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 1, .bits = 1065353216 } },
        .{ .copy = .{ .result = 2, .operand = 0 } },
        .{ .copy = .{ .result = 3, .operand = 2 } },
        .{ .binary = .{ .result = 4, .operator = .add, .left = 3, .right = 1, .type = .float32 } },
        .{ .return_value = .{ .start = 4, .width = 1 } },
    };
    const function: Machine.Function = .{
        .name = "copy_chain",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 5,
        .frame_size = try Machine.frameSize(5),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);

    try std.testing.expectEqual(result.float_residences[0], result.float_residences[2]);
    try std.testing.expectEqual(result.float_residences[0], result.float_residences[3]);
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

test "hot loop recurrence chains use CFG-aware SIMD residences" {
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

    for (4..10) |slot| try std.testing.expect(result.float_lane_residences[slot] != null);
}

test "independent XYZ group keeps XY paired and Z scalar" {
    const instructions = [_]Machine.Instruction{
        .{ .binary = .{ .result = 2, .operator = .multiply, .left = 0, .right = 1, .type = .float32 } },
        .{ .binary = .{ .result = 3, .operator = .multiply, .left = 0, .right = 1, .type = .float32 } },
        .{ .binary = .{ .result = 4, .operator = .multiply, .left = 0, .right = 1, .type = .float32 } },
        .{ .binary = .{ .result = 5, .operator = .add, .left = 2, .right = 3, .type = .float32 } },
        .{ .binary = .{ .result = 6, .operator = .add, .left = 5, .right = 4, .type = .float32 } },
        .{ .return_value = .{ .start = 6, .width = 1 } },
    };
    const groups = [_]Machine.FloatLaneGroup{.{
        .slots = .{ 2, 3, 4, 0 },
        .width = 3,
        .priority = 8,
        .recurrence = false,
        .in_loop = false,
    }};
    const function: Machine.Function = .{
        .name = "xyz",
        .parameter_count = 2,
        .parameters = &.{ .{ .start = 0, .width = 1 }, .{ .start = 1, .width = 1 } },
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 7,
        .frame_size = try Machine.frameSize(7),
        .float_lane_groups = &groups,
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);

    const x = result.float_lane_residences[2] orelse return error.TestUnexpectedResult;
    const y = result.float_lane_residences[3] orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(x.register, y.register);
    try std.testing.expectEqual(@as(u1, 0), x.lane);
    try std.testing.expectEqual(@as(u1, 1), y.lane);
    try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), result.float_lane_residences[4]);
    try std.testing.expect(result.float_residences[4] != null);
}
