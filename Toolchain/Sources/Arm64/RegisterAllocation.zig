const std = @import("std");
const Machine = @import("Machine.zig");
const MemoryResidence = @import("MemoryResidence.zig");
const FloatPairs = @import("FloatPairs.zig");
const LoopCursor = @import("LoopCursor.zig");
const ResidenceLiveness = @import("ResidenceLiveness.zig");
const InternalAbi = @import("InternalAbi.zig");
const VectorCost = @import("../Optimize/VectorCost.zig");
const successorLive = ResidenceLiveness.successorLive;
const instructionUses = ResidenceLiveness.instructionUses;
const instructionDefines = ResidenceLiveness.instructionDefines;
const spanContains = ResidenceLiveness.spanContains;

test {
    _ = @import("MemoryResidence.zig");
    _ = @import("LoopExitResidenceTests.zig");
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
    target: VectorCost.Target,
    registers: []const u5,
) Allocator.Error![]const ?Machine.FloatLaneResidence {
    if (!isCompatibleFunction(function, false, &.{}) or registers.len == 0) return try allocator.alloc(?Machine.FloatLaneResidence, 0);
    const residences = try allocator.alloc(?Machine.FloatLaneResidence, function.slot_count);
    @memset(residences, null);
    const float_slots = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(float_slots);
    @memset(float_slots, false);
    inferFloatSlots(function, float_slots);
    try FloatPairs.allocate(allocator, function, target, float_slots, residences, registers);
    return residences;
}

/// Allocates scalar FP regions for a backend with an explicit encoder subset.
/// Unsupported operations retain complete stack intervals; address-taken spans
/// stay pinned even when their address is consumed outside the scalar region.
pub fn allocateFloatScalarsFor(
    allocator: Allocator,
    function: Machine.Function,
    registers: []const u5,
    comptime supported: fn (Machine.Instruction) bool,
) Allocator.Error![]const ?u5 {
    if (function.reuses_slots or function.capture_parameters.len != 0 or registers.len == 0) return &.{};
    const residences = try allocator.alloc(?u5, function.slot_count);
    @memset(residences, null);
    const floats = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(floats);
    @memset(floats, false);
    inferFloatSlots(function, floats);
    const forced = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(forced);
    @memset(forced, false);
    // The caller supplies a bank disjoint from its packed lanes. Packed
    // emitters consume stack operands and materialize both results in memory.
    for (function.float_lane_slots, 0..) |lane, slot| if (lane != null) {
        forced[slot] = true;
    };
    for (function.instructions) |instruction| if (instruction == .binary) {
        const binary = instruction.binary;
        if (function.float_lane_slots.len != 0 and function.float_lane_slots[binary.result] != null) {
            forced[binary.left] = true;
            forced[binary.right] = true;
        }
    };
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
        if (parameter.aggregate or parameter.width != 1) forceSpan(parameter, forced) else touch(parameter.start, 0, first, last, weights, 1);
    }
    for (function.instructions, 0..) |instruction, index| {
        visitBarrier(instruction, index, first, last, weights, instruction_weights[index]);
        MemoryResidence.pin(instruction, forced);
    }
    extendLoopCarriedIntervals(function.instructions, first, last);
    for (function.instructions, 0..) |instruction, index| {
        if (!supported(instruction)) {
            for (first, last, 0..) |start, end, slot| {
                if (start <= index and end >= index) forced[slot] = true;
            }
        }
    }
    var intervals: std.ArrayList(Interval) = .empty;
    defer intervals.deinit(allocator);
    for (first, 0..) |start, slot| {
        if (start == std.math.maxInt(usize) or forced[slot] or !floats[slot]) continue;
        try intervals.append(allocator, .{ .slot = @intCast(slot), .first = start, .last = last[slot], .weight = weights[slot] });
    }
    try allocateGraph(allocator, residences, intervals.items, registers, function.instructions, function.slot_count, forced, &.{}, &.{}, false);
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
    const fully_compatible = isFullyResidenceCompatible(function, externals);
    if (!fully_compatible and !(try hasProfitableScalarRegion(allocator, function.instructions, externals))) return spilled(allocator, function);
    if (!fully_compatible and hasLoopAggregateCall(function.instructions)) return spilled(allocator, function);
    // Actual C calls preserve x19...x28 and only the low 64 bits of v8...v15.
    // Keep argument/result stack homes. Scalar regions may borrow volatile
    // floating colors only when their live values do not meet a call.
    const has_calls = for (function.instructions) |instruction| {
        if (instruction == .call) break true;
        if (instruction == .external_call) {
            const call = instruction.external_call;
            if (call.function >= externals.len or call.result == null or
                (MemoryResidence.copySignPrecision(externals[call.function]) == null and
                    MemoryResidence.squareRootPrecision(externals[call.function]) == null)) break true;
        }
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
    inferExternalFloatSlots(function, externals, float_slots);
    if (!fully_compatible and hasMixedAggregateLoad(function, float_slots)) return spilled(allocator, function);
    // A call-free function pays the ABI save/restore cost for v8...v15 but
    // may freely clobber v0...v7 and v16...v31. Exhaust the available
    // volatile colors before borrowing the preserved scalar subset.
    const pair_registers = [_]u5{
        16, 17, 18, 19, 20, 21, 22, 23,
        24, 25, 26, 27, 28, 29, 30, 31,
        0,  1,  2,  3,  4,  5,  8,  13,
        14, 15,
    };
    const lane_registers: []const u5 = if (has_calls) &.{ 8, 13, 14, 15 } else &pair_registers;
    if (fully_compatible) try FloatPairs.allocate(allocator, function, .arm64, float_slots, float_lane_residences, lane_registers);
    var cursor_probe = function;
    cursor_probe.float_lane_slots = float_lane_residences;
    const reserve_cursor_end = !has_calls and (try LoopCursor.find(allocator, cursor_probe)) != null;
    const reference_cursors = try LoopCursor.findReferenceCursors(allocator, function, false);
    defer allocator.free(reference_cursors);
    const checked_reference_cursors = try LoopCursor.findReferenceCursors(allocator, function, true);
    defer allocator.free(checked_reference_cursors);
    const reference_reuses = try LoopCursor.findReferenceReuses(allocator, function);
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
        } else if (parameter.aggregate and !has_calls) {
            // Capture each proven floating leaf independently. A passthrough
            // or resource field must not pin unrelated numeric fields; their
            // address uses are still pinned below before graph allocation.
            for (0..parameter.width) |leaf| {
                const slot: Machine.Slot = @intCast(@as(usize, parameter.start) + leaf);
                if (float_slots[slot]) {
                    touch(slot, 0, first, last, weights, 1);
                } else forced[slot] = true;
            }
        } else if (parameter.aggregate or parameter.width != 1) {
            forceSpan(parameter, forced);
        } else touch(parameter.start, 0, first, last, weights, 1);
    }
    for (function.instructions, 0..) |instruction, index| {
        visit(instruction, index, first, last, weights, instruction_weights[index]);
        if (!isResidenceCompatibleInstruction(instruction, externals)) {
            visitBarrier(instruction, index, first, last, weights, instruction_weights[index]);
        }
        forceStackOperands(function, instruction, forced, externals);
    }
    extendLoopCarriedIntervals(function.instructions, first, last);
    for (reference_cursors) |cursor| {
        touch(cursor.result, cursor.initialize, first, last, weights, instruction_weights[cursor.initialize]);
        touch(cursor.result, cursor.increment, first, last, weights, instruction_weights[cursor.increment]);
    }
    for (checked_reference_cursors) |cursor| {
        touch(cursor.result, cursor.initialize, first, last, weights, instruction_weights[cursor.initialize]);
        touch(cursor.result, cursor.increment, first, last, weights, instruction_weights[cursor.increment]);
    }
    if (!fully_compatible) {
        const live = try ResidenceLiveness.compute(allocator, function.instructions, function.slot_count);
        defer allocator.free(live);
        for (function.instructions, 0..) |instruction, index| {
            if (!isResidenceCompatibleInstruction(instruction, externals)) {
                pinLiveAt(function.instructions, index, live, function.slot_count, forced);
            }
        }
    }

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
    if (!has_calls) precolorCallFreeParameters(function, residences, forced, float_slots);
    const integer_registers: []const u5 = if (has_calls)
        (if (function.slot_count >= Machine.direct_stack_slots)
            &.{ 19, 20, 21, 22, 23, 24, 25, 26, 27 }
        else
            &.{ 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 })
    else if (reference_reuses.count != 0)
        if (function.slot_count >= Machine.direct_stack_slots)
            if (reserve_cursor_end)
                &[_]u5{ 0, 1, 2, 3, 4, 5, 8, 16, 19, 20, 21, 22, 23, 24, 25, 26, 27 }
            else
                &[_]u5{ 0, 1, 2, 3, 4, 5, 8, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27 }
        else if (reserve_cursor_end)
            &[_]u5{ 0, 1, 2, 3, 4, 5, 8, 16, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 }
        else
            &[_]u5{ 0, 1, 2, 3, 4, 5, 8, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 }
    else if (function.slot_count >= Machine.direct_stack_slots)
        if (reserve_cursor_end)
            &[_]u5{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 16, 19, 20, 21, 22, 23, 24, 25, 26, 27 }
        else
            &[_]u5{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27 }
    else if (reserve_cursor_end)
        &[_]u5{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 16, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 }
    else
        &[_]u5{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 16, 17, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28 };
    try allocateGraph(
        allocator,
        residences,
        integer_intervals.items,
        integer_registers,
        function.instructions,
        function.slot_count,
        forced,
        reference_cursors,
        checked_reference_cursors,
        false,
    );
    // Incoming arguments occupy x0 up to the last register parameter until
    // the prologue captures them. Lower volatile registers beyond that point
    // are already free and can retain call-free parameters.
    const flattened_parameters = InternalAbi.flattensSmallAggregates(function.parameters);
    const incoming_register_count = if (flattened_parameters)
        InternalAbi.registerArgumentCount(function.parameters)
    else
        @min(function.parameter_count, Machine.max_register_arguments);
    var incoming_parameter_index: usize = 0;
    for (function.parameters) |parameter| {
        for (0..parameter.width) |leaf| {
            const slot: Machine.Slot = @intCast(@as(usize, parameter.start) + leaf);
            if (residences[slot]) |register| {
                const matching_flattened_register = flattened_parameters and
                    (InternalAbi.isDirectAggregate(parameter, true) or !parameter.aggregate) and
                    @as(usize, register) == incoming_parameter_index + leaf;
                if (@as(usize, register) < incoming_register_count and !matching_flattened_register) {
                    residences[slot] = null;
                }
            }
        }
        incoming_parameter_index += InternalAbi.registerWidth(parameter, flattened_parameters);
    }
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
        &pair_registers,
        function.instructions,
        function.slot_count,
        forced,
        reference_cursors,
        checked_reference_cursors,
        has_calls,
    );
    for (float_lane_residences, 0..) |lane, slot| if (lane != null) {
        float_residences[slot] = null;
    };
    const frame_size = if (fully_compatible and !has_calls)
        try residentFrameSize(function, residences, float_residences, float_lane_residences)
    else
        function.frame_size;
    return .{
        .residences = residences,
        .float_residences = float_residences,
        .float_lane_residences = float_lane_residences,
        .frame_size = frame_size,
    };
}

/// A call-free function needs stack storage only through its highest
/// participating spill. Trailing virtual slots backed by a general,
/// scalar-float, or lane residence do not need physical frame space.
fn residentFrameSize(
    function: Machine.Function,
    residences: []const ?u5,
    float_residences: []const ?u5,
    float_lane_residences: []const ?Machine.FloatLaneResidence,
) Machine.Error!u32 {
    if (function.parameters.len > Machine.max_register_arguments) return function.frame_size;
    var required_slots: usize = 0;
    for (0..function.slot_count) |slot| {
        if (residences[slot] != null or float_residences[slot] != null or
            float_lane_residences[slot] != null) continue;
        if (!slotParticipates(function, slot)) continue;
        required_slots = slot + 1;
    }
    return Machine.frameSize(required_slots);
}

fn slotParticipates(function: Machine.Function, slot: usize) bool {
    if (function.hidden_return_slot) |hidden| if (hidden == slot) return true;
    for (function.parameters) |parameter| if (spanContains(parameter, slot)) return true;
    for (function.capture_parameters) |capture| if (spanContains(capture, slot)) return true;
    for (function.instructions) |instruction| if (instructionUses(instruction, slot)) return true;
    for (function.instructions) |instruction| {
        if (!instructionDefines(instruction, slot)) continue;
        switch (instruction) {
            // The encoder omits individually unused leaves of borrowed
            // aggregate loads. Their virtual definitions need no stack home.
            .reference_load => |load| if (load.result.width > 1) continue,
            else => {},
        }
        return true;
    }
    return false;
}

fn precolorCallFreeParameters(
    function: Machine.Function,
    residences: []?u5,
    forced: []const bool,
    float_slots: []const bool,
) void {
    const flattened = InternalAbi.flattensSmallAggregates(function.parameters);
    if (flattened) {
        var incoming_index: usize = 0;
        for (function.parameters) |parameter| {
            if (InternalAbi.isDirectAggregate(parameter, true)) {
                for (0..parameter.width) |leaf| {
                    const slot: Machine.Slot = @intCast(@as(usize, parameter.start) + leaf);
                    if (incoming_index <= 5 and !forced[slot] and !float_slots[slot]) {
                        residences[slot] = @intCast(incoming_index);
                    }
                    incoming_index += 1;
                }
                continue;
            }
            if (incoming_index <= 5 and !parameter.aggregate and parameter.width == 1 and
                !forced[parameter.start] and !float_slots[parameter.start])
            {
                residences[parameter.start] = @intCast(incoming_index);
            }
            incoming_index += 1;
        }
        return;
    }
    var candidates: [21]u5 = undefined;
    var candidate_count: usize = 0;
    for ([_]u5{ 16, 17, 8 }) |register| {
        candidates[candidate_count] = register;
        candidate_count += 1;
    }
    var free_argument_register = @min(function.parameter_count, Machine.max_register_arguments);
    while (free_argument_register < Machine.max_register_arguments) : (free_argument_register += 1) {
        candidates[candidate_count] = @intCast(free_argument_register);
        candidate_count += 1;
    }
    const saved_end: u5 = if (function.slot_count >= Machine.direct_stack_slots) 28 else 29;
    var saved: u5 = 19;
    while (saved < saved_end) : (saved += 1) {
        candidates[candidate_count] = saved;
        candidate_count += 1;
    }
    const registers = candidates[0..candidate_count];
    var register_index: usize = 0;
    for (function.parameters) |parameter| {
        if (isCollectionParameter(function, parameter)) {
            for (0..parameter.width) |leaf| {
                const slot: Machine.Slot = @intCast(@as(usize, parameter.start) + leaf);
                if (forced[slot] or float_slots[slot] or register_index >= registers.len) continue;
                residences[slot] = registers[register_index];
                register_index += 1;
            }
        } else if (!parameter.aggregate and parameter.width == 1 and !forced[parameter.start] and
            !float_slots[parameter.start] and register_index < registers.len)
        {
            residences[parameter.start] = registers[register_index];
            register_index += 1;
        }
    }
}

fn isCollectionParameter(function: Machine.Function, parameter: Machine.Span) bool {
    if (parameter.width != 2) return false;
    for (function.instructions) |instruction| switch (instruction) {
        .collection_load => |load| if (load.collection.start == parameter.start and
            load.collection.width == parameter.width) return true,
        .collection_reference => |reference| if (reference.collection.start == parameter.start and
            reference.collection.width == parameter.width) return true,
        .collection_replace => |replacement| if (replacement.collection.start == parameter.start and
            replacement.collection.width == parameter.width) return true,
        .collection_count => |count| if (count.collection.start == parameter.start and
            count.collection.width == parameter.width) return true,
        else => {},
    };
    return false;
}

fn hasMixedAggregateLoad(function: Machine.Function, float_slots: []const bool) bool {
    for (function.instructions) |instruction| if (instruction == .collection_load) {
        const result = instruction.collection_load.result;
        if (result.width < 2) continue;
        var floats: usize = 0;
        for (0..result.width) |leaf| floats += @intFromBool(float_slots[@as(usize, result.start) + leaf]);
        if (floats != 0 and floats != result.width) return true;
    };
    return false;
}

fn hasLoopAggregateCall(instructions: []const Machine.Instruction) bool {
    for (instructions, 0..) |instruction, index| if (instruction == .call) {
        var aggregate = false;
        for (instruction.call.arguments) |argument| aggregate = aggregate or argument.aggregate;
        if (!aggregate) continue;
        for (instructions, 0..) |control, source| switch (control) {
            .jump => |target| if (target <= index and index <= source) return true,
            .branch => |value| if ((value.then_instruction <= index and index <= source) or
                (value.else_instruction <= index and index <= source)) return true,
            else => {},
        };
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
    forced: []const bool,
    reference_cursors: []const LoopCursor.ReferenceCursor,
    checked_reference_cursors: []const LoopCursor.ReferenceCursor,
    regional_float_colors: bool,
) Allocator.Error!void {
    const live = try ResidenceLiveness.compute(allocator, instructions, slot_count);
    defer allocator.free(live);
    for (reference_cursors) |cursor| markReferenceCursorLive(live, slot_count, cursor);
    for (checked_reference_cursors) |cursor| markReferenceCursorLive(live, slot_count, cursor);

    const alias_roots = try allocator.alloc(Machine.Slot, slot_count);
    defer allocator.free(alias_roots);
    try buildPureAliasRoots(allocator, alias_roots, instructions, live, slot_count, forced);
    coalesceCopyAffinityRoots(alias_roots, instructions, live, slot_count, forced);

    // Constrain the whole coalesced component, including call operands and
    // results. CFG liveness keeps a call on another path from extending an
    // unrelated region; values genuinely crossing it use preserved colors.
    const preserved = try allocator.alloc(bool, slot_count);
    defer allocator.free(preserved);
    @memset(preserved, false);
    if (regional_float_colors) {
        for (instructions, 0..) |instruction, index| {
            if (instruction != .call and instruction != .external_call) continue;
            for (0..slot_count) |slot| {
                if (live[index * slot_count + slot] or successorLive(instructions, live, slot_count, index, slot))
                    preserved[alias_roots[slot]] = true;
            }
        }
    }

    std.mem.sort(Interval, intervals, {}, heavierThan);
    for (intervals) |interval| {
        const root = alias_roots[interval.slot];
        if (componentResidence(root, residences, alias_roots)) |precolored| {
            if ((!preserved[root] or (precolored >= 8 and precolored < 16)) and
                !componentColorConflicts(root, precolored, residences, alias_roots, live, instructions, slot_count, intervals))
            {
                assignComponentResidence(root, precolored, residences, alias_roots, intervals);
            }
            continue;
        }
        if (preferredComponentResidence(root, residences, alias_roots, instructions)) |preferred| {
            if ((!preserved[root] or (preferred >= 8 and preferred < 16)) and
                !componentColorConflicts(root, preferred, residences, alias_roots, live, instructions, slot_count, intervals))
            {
                assignComponentResidence(root, preferred, residences, alias_roots, intervals);
                continue;
            }
        }
        for (registers) |register| {
            if ((!preserved[root] or (register >= 8 and register < 16)) and
                !componentColorConflicts(root, register, residences, alias_roots, live, instructions, slot_count, intervals))
            {
                assignComponentResidence(root, register, residences, alias_roots, intervals);
                break;
            }
        }
    }
}

fn markReferenceCursorLive(
    live: []bool,
    slot_count: usize,
    cursor: LoopCursor.ReferenceCursor,
) void {
    for (cursor.initialize..cursor.increment + 1) |instruction| {
        live[instruction * slot_count + cursor.result] = true;
    }
}

fn componentResidence(root: Machine.Slot, residences: []const ?u5, roots: []const Machine.Slot) ?u5 {
    for (roots, residences) |candidate_root, residence| {
        if (candidate_root == root and residence != null) return residence;
    }
    return null;
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
    forced: []const bool,
) Allocator.Error!void {
    const operands = try allocator.alloc(?Machine.Slot, slot_count);
    defer allocator.free(operands);
    @memset(operands, null);
    for (0..slot_count) |slot| {
        operands[slot] = safePureAliasOperand(instructions, live, slot_count, forced, @intCast(slot));
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
    forced: []const bool,
) void {
    for (instructions) |instruction| switch (instruction) {
        .copy => |copy| if (!forced[copy.result] and !forced[copy.operand])
            mergeNonInterferingRoots(roots, copy.result, copy.operand, instructions, live, slot_count),
        .copy_range => |copy| for (0..copy.result.width) |leaf| {
            const result: Machine.Slot = @intCast(@as(usize, copy.result.start) + leaf);
            const operand: Machine.Slot = @intCast(@as(usize, copy.operand.start) + leaf);
            if (!forced[result] and !forced[operand]) {
                mergeNonInterferingRoots(roots, result, operand, instructions, live, slot_count);
            }
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
    forced: []const bool,
    result: Machine.Slot,
) ?Machine.Slot {
    if (forced[result]) return null;
    var definition_index: ?usize = null;
    var operand: ?Machine.Slot = null;
    for (instructions, 0..) |instruction, index| {
        if (!instructionDefines(instruction, result)) continue;
        if (definition_index != null) return null;
        definition_index = index;
        operand = switch (instruction) {
            .copy => |copy| copy.operand,
            .copy_range => |copy| @intCast(@as(usize, copy.operand.start) + result - copy.result.start),
            .aggregate_init => |initialization| if (aggregateResultsAllUsed(instructions, initialization))
                aggregateOperandForResult(initialization, result)
            else
                null,
            .collection_count => |count| if (count.view) count.collection.start + 1 else null,
            else => null,
        };
        if (operand == null) return null;
        if (forced[operand.?]) return null;
    }
    if (definition_index == null or operand == null) return null;
    for (instructions, 0..) |instruction, index| {
        if (instructionDefines(instruction, operand.?) and
            (live[index * slot_count + result] or successorLive(instructions, live, slot_count, index, result))) return null;
    }
    return operand;
}

fn slotIsUsed(instructions: []const Machine.Instruction, slot: Machine.Slot) bool {
    for (instructions) |instruction| if (instructionUses(instruction, slot)) return true;
    return false;
}

fn aggregateResultsAllUsed(
    instructions: []const Machine.Instruction,
    initialization: Machine.Instruction.AggregateInit,
) bool {
    for (0..initialization.result.width) |leaf| {
        const slot: Machine.Slot = @intCast(@as(usize, initialization.result.start) + leaf);
        if (!slotIsUsed(instructions, slot)) return false;
    }
    return true;
}

fn aggregateOperandForResult(
    initialization: Machine.Instruction.AggregateInit,
    result: Machine.Slot,
) ?Machine.Slot {
    if (!ResidenceLiveness.spanContains(initialization.result, result)) return null;
    var remaining: usize = result - initialization.result.start;
    for (initialization.fields) |field| {
        if (remaining < field.width) return @intCast(@as(usize, field.start) + remaining);
        remaining -= field.width;
    }
    return null;
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
                .add, .subtract, .multiply, .divide, .minimum, .maximum => result[value.result] = true,
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

fn inferExternalFloatSlots(function: Machine.Function, externals: []const Machine.ExternalFunction, result: []bool) void {
    for (function.instructions) |instruction| switch (instruction) {
        .external_call => |call| {
            if (call.function >= externals.len) continue;
            const signature = externals[call.function].signature;
            for (call.arguments, signature.arguments) |argument, kind| {
                if (kind == .float32 or kind == .float64) result[argument] = true;
            }
            if (call.result) |slot| if (signature.result == .float32 or signature.result == .float64) {
                result[slot] = true;
            };
        },
        else => {},
    };
}

fn propagateFloat(left: Machine.Slot, right: Machine.Slot, result: []bool, changed: *bool) void {
    if (result[left] == result[right]) return;
    result[left] = true;
    result[right] = true;
    changed.* = true;
}

fn isCompatibleFunction(function: Machine.Function, allow_stack_effects: bool, externals: []const Machine.ExternalFunction) bool {
    if (function.reuses_slots) return false;
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
        .call,
        => {},
        // ARM64's aggregate emitters already consume registered scalar leaves.
        // Pure constructors need no unrelated memory operation to qualify.
        // The shared lane-only path retains its previous, narrower contract.
        .copy_range, .aggregate_init => if (!has_unchecked_collection_load and !allow_stack_effects) return false,
        .collection_load => |load| if (load.checked and !(allow_stack_effects and MemoryResidence.supports(instruction))) {
            if (!allow_stack_effects) return false;
        },
        .binary => |binary| if (binary.type == .str and !allow_stack_effects) return false,
        .external_call => |call| if (call.function >= externals.len or
            !MemoryResidence.scalarMathCall(externals[call.function]))
        {
            if (!allow_stack_effects) return false;
        },
        else => if (!allow_stack_effects and !MemoryResidence.supports(instruction)) return false,
    };
    return true;
}

pub fn supportsMemoryScheduling(function: Machine.Function, externals: []const Machine.ExternalFunction) bool {
    // Pure read-only loops need the same lane-tree adjacency as mutable memory
    // kernels; scheduling safety comes from full residence compatibility.
    return isCompatibleFunction(function, true, externals) and
        isFullyResidenceCompatible(function, externals);
}

fn isFullyResidenceCompatible(function: Machine.Function, externals: []const Machine.ExternalFunction) bool {
    for (function.instructions) |instruction| if (!isResidenceCompatibleInstruction(instruction, externals)) return false;
    return true;
}

fn hasProfitableScalarRegion(allocator: Allocator, instructions: []const Machine.Instruction, externals: []const Machine.ExternalFunction) Allocator.Error!bool {
    if (try hasProfitableLoopRegion(allocator, instructions, externals)) return true;

    const has_wide_float_candidate = for (instructions) |instruction| {
        if (instruction == .collection_load and instruction.collection_load.result.width >= 16) break true;
    } else false;
    if (!has_wide_float_candidate) return false;

    var arithmetic: usize = 0;
    for (instructions) |instruction| {
        if (!isResidenceCompatibleInstruction(instruction, externals)) {
            arithmetic = 0;
            continue;
        }
        arithmetic += switch (instruction) {
            .binary => |value| @intFromBool(value.type.isFloat()),
            .unary => |value| @intFromBool(value.type.isFloat()),
            .convert => |value| @intFromBool(value.source.isFloat() or value.target.isFloat()),
            else => 0,
        };
        if (arithmetic >= 32) return true;
    }
    return false;
}

fn hasProfitableLoopRegion(allocator: Allocator, instructions: []const Machine.Instruction, externals: []const Machine.ExternalFunction) Allocator.Error!bool {
    const reaches_latch = try allocator.alloc(bool, instructions.len);
    defer allocator.free(reaches_latch);
    for (instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= source and profitableLoopRange(instructions, target, source, reaches_latch, externals)) return true,
        .branch => |branch| {
            if (branch.then_instruction <= source and
                profitableLoopRange(instructions, branch.then_instruction, source, reaches_latch, externals)) return true;
            if (branch.else_instruction <= source and
                profitableLoopRange(instructions, branch.else_instruction, source, reaches_latch, externals)) return true;
        },
        else => {},
    };
    return false;
}

// The linear span of a back edge can contain an exit block laid out before
// the loop body. Only paths that can reach its latch contribute to this cost
// estimate. Actual safety still comes from CFG liveness and pinned operands.
fn profitableLoopRange(instructions: []const Machine.Instruction, header: usize, latch: usize, reaches_latch: []bool, externals: []const Machine.ExternalFunction) bool {
    @memset(reaches_latch, false);
    reaches_latch[latch] = true;
    var changed = true;
    while (changed) {
        changed = false;
        var index = latch;
        while (index > header) {
            index -= 1;
            if (reaches_latch[index]) continue;
            const reaches = switch (instructions[index]) {
                .jump => |target| reaches_latch[target],
                .branch => |value| reaches_latch[value.then_instruction] or reaches_latch[value.else_instruction],
                .return_value, .return_void, .panic => false,
                else => reaches_latch[index + 1],
            };
            if (reaches) {
                reaches_latch[index] = true;
                changed = true;
            }
        }
    }
    if (!reaches_latch[header]) return false;
    var arithmetic: usize = 0;
    for (instructions[header .. latch + 1], header..) |instruction, index| {
        if (!reaches_latch[index]) continue;
        if (!isResidenceCompatibleInstruction(instruction, externals)) return false;
        arithmetic += switch (instruction) {
            .binary => |value| @intFromBool(value.type != .str),
            .unary => 1,
            .convert => 1,
            else => 0,
        };
    }
    return arithmetic >= 4;
}

fn isResidenceCompatibleInstruction(instruction: Machine.Instruction, externals: []const Machine.ExternalFunction) bool {
    return switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_float32,
        .constant_float64,
        .copy,
        .copy_range,
        .aggregate_init,
        .collection_count,
        .convert,
        .unary,
        .return_value,
        .return_void,
        .jump,
        .branch,
        .call,
        => true,
        .collection_load => |load| !load.checked or MemoryResidence.supports(instruction),
        .binary => |binary| binary.type != .str,
        .external_call => |call| call.function < externals.len and MemoryResidence.scalarMathCall(externals[call.function]),
        else => MemoryResidence.supports(instruction),
    };
}

fn pinLiveAt(
    instructions: []const Machine.Instruction,
    index: usize,
    live: []const bool,
    slot_count: usize,
    forced: []bool,
) void {
    const instruction = instructions[index];
    const terminal_operand: ?Machine.Slot = switch (instruction) {
        .print => |value| switch (value.kind) {
            .signed_integer, .unsigned_integer, .boolean => value.value,
            .float32, .float64, .string => null,
        },
        else => null,
    };
    for (forced, 0..) |*pinned, slot| {
        const live_out = successorLive(instructions, live, slot_count, index, slot);
        if (terminal_operand != null and terminal_operand.? == slot and !live_out) continue;
        // Unsupported emitters still read and write stack homes. A value on
        // another CFG path need not be spilled merely because its numeric
        // interval surrounds this instruction in the emitted layout.
        if (live[index * slot_count + slot] or live_out or instructionDefines(instruction, slot)) pinned.* = true;
    }
}

fn forceStackOperands(function: Machine.Function, instruction: Machine.Instruction, forced: []bool, externals: []const Machine.ExternalFunction) void {
    const inline_float_intrinsic = if (instruction == .external_call) root: {
        const call = instruction.external_call;
        break :root call.result != null and call.function < externals.len and
            (MemoryResidence.squareRootPrecision(externals[call.function]) != null or
                MemoryResidence.copySignPrecision(externals[call.function]) != null);
    } else false;
    if (!inline_float_intrinsic) {
        if (instruction == .local_address and addressOnlyAnnotatesViewReferences(function, instruction.local_address.result)) {
            forced[instruction.local_address.result] = true;
        } else MemoryResidence.pin(instruction, forced);
    }
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

fn addressOnlyAnnotatesViewReferences(function: Machine.Function, address: Machine.Slot) bool {
    var annotated = false;
    for (function.instructions) |instruction| {
        if (instruction == .collection_reference) {
            const reference = instruction.collection_reference;
            if (reference.view and reference.reference == address) {
                annotated = true;
                continue;
            }
        }
        if (instructionUses(instruction, address)) return false;
    }
    return annotated;
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
        .reference_load,
        .reference_store,
        .reference_offset,
        .reference_indirect_offset,
        .local_address,
        .address_load,
        .address_store,
        .collection_reference,
        .collection_replace,
        => for (0..first.len) |slot| {
            if (instructionUses(instruction, slot) or instructionDefines(instruction, slot)) {
                touch(@intCast(slot), index, first, last, weights, weight);
            }
        },
        .call => |call| {
            for (call.arguments) |argument| if (!argument.aggregate) touch(argument.start, index, first, last, weights, weight);
            if (call.result) |result| if (!result.aggregate) touch(result.start, index, first, last, weights, weight);
        },
        .external_call => |call| {
            for (call.arguments) |argument| touch(argument, index, first, last, weights, weight);
            if (call.result) |result| touch(result, index, first, last, weights, weight);
        },
        .return_value => |value| if (!value.aggregate) touch(value.start, index, first, last, weights, weight),
        .branch => |value| touch(value.condition, index, first, last, weights, weight),
        else => {},
    }
}

fn visitBarrier(
    instruction: Machine.Instruction,
    index: usize,
    first: []usize,
    last: []usize,
    weights: []u64,
    weight: u64,
) void {
    for (0..first.len) |slot| {
        if (instructionUses(instruction, slot) or instructionDefines(instruction, slot)) {
            touch(@intCast(slot), index, first, last, weights, weight);
        }
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

test "call-free graph allocation uses volatile registers and coalesces a dead arithmetic operand" {
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
    try std.testing.expectEqual(@as(?u5, 0), result.residences[0]);
    try std.testing.expectEqual(@as(?u5, 1), result.residences[1]);
    try std.testing.expectEqual(result.residences[0], result.residences[2]);
    try std.testing.expectEqual(@as(u32, 0), result.frame_size);
}

test "resident frame keeps the complete frame when one participant spills" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 20 } },
        .{ .constant_int = .{ .result = 1, .bits = 22 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const function: Machine.Function = .{
        .name = "spilled_answer",
        .parameter_count = 0,
        .return_type = .int,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .instructions = &instructions,
    };
    try std.testing.expectEqual(
        try Machine.frameSize(3),
        try residentFrameSize(
            function,
            &.{ 0, 1, null },
            &.{ null, null, null },
            &.{ null, null, null },
        ),
    );
}

test "resident frame omits a registered suffix after the final spill" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 20 } },
        .{ .constant_int = .{ .result = 1, .bits = 22 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } },
        .{ .return_value = .{ .start = 2, .width = 1 } },
    };
    const function: Machine.Function = .{
        .name = "prefix_spill",
        .parameter_count = 0,
        .return_type = .int,
        .slot_count = 3,
        .frame_size = try Machine.frameSize(3),
        .instructions = &instructions,
    };
    try std.testing.expectEqual(
        try Machine.frameSize(1),
        try residentFrameSize(
            function,
            &.{ null, 1, 0 },
            &.{ null, null, null },
            &.{ null, null, null },
        ),
    );
}

test "unused borrowed aggregate leaves need no frame home" {
    const function: Machine.Function = .{
        .name = "borrowed_fields",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .void,
        .slot_count = 4,
        .frame_size = try Machine.frameSize(4),
        .instructions = &.{
            .{ .reference_load = .{
                .result = .{ .start = 1, .width = 3, .aggregate = true },
                .reference = 0,
            } },
            .return_void,
        },
    };
    try std.testing.expectEqual(
        @as(u32, 0),
        try residentFrameSize(
            function,
            &.{ 16, null, null, null },
            &.{ null, null, null, null },
            &.{ null, null, null, null },
        ),
    );
}

test "aggregate construction exposes leaf copy affinity" {
    const initialization: Machine.Instruction.AggregateInit = .{
        .result = .{ .start = 6, .width = 4, .aggregate = true },
        .fields = &.{
            .{ .start = 1, .width = 1 },
            .{ .start = 3, .width = 2, .aggregate = true },
            .{ .start = 0, .width = 1 },
        },
    };
    try std.testing.expectEqual(@as(?Machine.Slot, 1), aggregateOperandForResult(initialization, 6));
    try std.testing.expectEqual(@as(?Machine.Slot, 3), aggregateOperandForResult(initialization, 7));
    try std.testing.expectEqual(@as(?Machine.Slot, 4), aggregateOperandForResult(initialization, 8));
    try std.testing.expectEqual(@as(?Machine.Slot, 0), aggregateOperandForResult(initialization, 9));
    try std.testing.expectEqual(@as(?Machine.Slot, null), aggregateOperandForResult(initialization, 5));
    try std.testing.expectEqual(@as(?Machine.Slot, null), aggregateOperandForResult(initialization, 10));
}

test "repeated memory uses keep a call-free reference parameter in a volatile register" {
    var instructions: std.ArrayList(Machine.Instruction) = .empty;
    defer instructions.deinit(std.testing.allocator);

    for (0..13) |offset| try instructions.append(std.testing.allocator, .{ .constant_int = .{
        .result = @intCast(1 + offset),
        .bits = offset + 1,
    } });
    for (0..13) |offset| try instructions.append(std.testing.allocator, .{ .reference_load = .{
        .result = .{ .start = @intCast(14 + offset), .width = 1 },
        .reference = 0,
    } });
    var accumulator: Machine.Slot = 1;
    for (2..14) |operand| {
        const result: Machine.Slot = @intCast(26 + operand);
        try instructions.append(std.testing.allocator, .{ .binary = .{
            .result = result,
            .operator = .add,
            .left = accumulator,
            .right = @intCast(operand),
        } });
        accumulator = result;
    }
    try instructions.append(std.testing.allocator, .{ .return_value = .{ .start = accumulator, .width = 1 } });

    const function: Machine.Function = .{
        .name = "memory_parameter",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 1 }},
        .return_type = .int,
        .return_width = 1,
        .slot_count = 40,
        .frame_size = try Machine.frameSize(40),
        .instructions = instructions.items,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);

    try std.testing.expectEqual(@as(?u5, 16), result.residences[0]);
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
    try std.testing.expectEqual(@as(?u5, 0), result.residences[0]);
    try std.testing.expectEqual(@as(?u5, 1), result.residences[1]);
    try std.testing.expect(result.residences[2] != null);
    try std.testing.expect(result.residences[3] != null);
    try std.testing.expect(result.residences[4] != null);
    try std.testing.expect(result.float_residences[5] != null);
    try std.testing.expect(result.float_residences[6] != null);
}

test "unaddressed aggregate parameter leaves use scalar float registers" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 4, .bits = 0x3f800000 } },
        .{ .binary = .{ .result = 5, .operator = .add, .left = 0, .right = 4, .type = .float32 } },
        .{ .binary = .{ .result = 6, .operator = .add, .left = 1, .right = 4, .type = .float32 } },
        .{ .binary = .{ .result = 7, .operator = .add, .left = 2, .right = 4, .type = .float32 } },
        .{ .binary = .{ .result = 8, .operator = .add, .left = 3, .right = 4, .type = .float32 } },
        .return_void,
    };
    const function: Machine.Function = .{
        .name = "aggregate_parameter_leaves",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 4, .aggregate = true }},
        .return_type = .void,
        .slot_count = 9,
        .frame_size = try Machine.frameSize(9),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);
    for (0..4) |slot| try std.testing.expect(result.float_residences[slot] != null or
        result.float_lane_residences[slot] != null);
}

test "mixed aggregate parameters retain only unaddressed proven float leaves" {
    for ([_]bool{ false, true }) |addressed| {
        var instructions: std.ArrayList(Machine.Instruction) = .empty;
        defer instructions.deinit(std.testing.allocator);
        try instructions.appendSlice(std.testing.allocator, &.{
            .{ .constant_float32 = .{ .result = 3, .bits = 0x3f800000 } },
            .{ .binary = .{ .result = 4, .operator = .add, .left = 0, .right = 3, .type = .float32 } },
            .{ .constant_int = .{ .result = 5, .bits = 7 } },
            .{ .binary = .{ .result = 6, .operator = .add, .left = 1, .right = 5, .type = .int } },
            .{ .binary = .{ .result = 7, .operator = .add, .left = 2, .right = 3, .type = .float32 } },
        });
        if (addressed) try instructions.append(std.testing.allocator, .{ .local_address = .{ .result = 8, .local = 0, .width = 3 } });
        try instructions.append(std.testing.allocator, .return_void);
        const function: Machine.Function = .{
            .name = "mixed_parameter",
            .parameter_count = 1,
            .parameters = &.{.{ .start = 0, .width = 3, .aggregate = true }},
            .return_type = .void,
            .slot_count = 9,
            .frame_size = try Machine.frameSize(9),
            .instructions = instructions.items,
        };
        const result = try allocate(std.testing.allocator, function);
        defer std.testing.allocator.free(result.residences);
        defer std.testing.allocator.free(result.float_residences);
        defer std.testing.allocator.free(result.float_lane_residences);
        try std.testing.expectEqual(@as(?u5, null), result.residences[1]);
        try std.testing.expectEqual(@as(?u5, null), result.float_residences[1]);
        for ([_]usize{ 0, 2 }) |slot| try std.testing.expectEqual(!addressed, result.float_residences[slot] != null or result.float_lane_residences[slot] != null);
    }
}

test "addressed aggregate parameter leaves remain stack resident" {
    const instructions = [_]Machine.Instruction{
        .{ .local_address = .{ .result = 4, .local = 0, .width = 4 } },
        .return_void,
    };
    const function: Machine.Function = .{
        .name = "addressed_aggregate_parameter",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 4, .aggregate = true }},
        .return_type = .void,
        .slot_count = 5,
        .frame_size = try Machine.frameSize(5),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);
    for (0..4) |slot| {
        try std.testing.expectEqual(@as(?u5, null), result.residences[slot]);
        try std.testing.expectEqual(@as(?u5, null), result.float_residences[slot]);
        try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), result.float_lane_residences[slot]);
    }
}

test "pointer-backed non-float aggregate parameter leaves remain stack resident" {
    const instructions = [_]Machine.Instruction{
        .{ .binary = .{ .result = 3, .operator = .add, .left = 0, .right = 1, .type = .int } },
        .{ .binary = .{ .result = 4, .operator = .add, .left = 3, .right = 2, .type = .int } },
        .{ .return_value = .{ .start = 4, .width = 1 } },
    };
    const function: Machine.Function = .{
        .name = "resource_like_aggregate_parameter",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 3, .aggregate = true }},
        .return_type = .int,
        .slot_count = 5,
        .frame_size = try Machine.frameSize(5),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);
    for (0..3) |slot| {
        try std.testing.expectEqual(@as(?u5, null), result.residences[slot]);
        try std.testing.expectEqual(@as(?u5, null), result.float_residences[slot]);
        try std.testing.expectEqual(@as(?Machine.FloatLaneResidence, null), result.float_lane_residences[slot]);
    }
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

test "mutable float32 xy recurrences remain resident across loop transfers" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 0, .bits = 0 } },
        .{ .constant_float32 = .{ .result = 1, .bits = 0 } },
        .{ .copy = .{ .result = 4, .operand = 0 } },
        .{ .copy = .{ .result = 5, .operand = 1 } },
        .{ .branch = .{ .condition = 2, .then_instruction = 5, .else_instruction = 10 } },
        .{ .binary = .{ .result = 6, .operator = .add, .left = 4, .right = 0, .type = .float32 } },
        .{ .binary = .{ .result = 7, .operator = .add, .left = 5, .right = 1, .type = .float32 } },
        .{ .copy = .{ .result = 4, .operand = 6 } },
        .{ .copy = .{ .result = 5, .operand = 7 } },
        .{ .jump = 4 },
        .{ .return_value = .{ .start = 4, .width = 2, .aggregate = true } },
    };
    const groups = [_]Machine.FloatLaneGroup{
        .{ .slots = .{ 4, 5, 0, 0 }, .width = 2, .priority = 16, .recurrence = true, .in_loop = true },
        .{ .slots = .{ 6, 7, 0, 0 }, .width = 2, .priority = 16, .recurrence = true, .in_loop = true },
    };
    const function: Machine.Function = .{
        .name = "mutable_xy_recurrence",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 2, .width = 1 }},
        .return_type = .float32,
        .return_width = 2,
        .return_aggregate = true,
        .slot_count = 8,
        .frame_size = try Machine.frameSize(8),
        .float_lane_groups = &groups,
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);

    for (4..8) |slot| {
        try std.testing.expect(result.float_lane_residences[slot] != null);
    }
    try std.testing.expectEqual(
        result.float_lane_residences[4].?.register,
        result.float_lane_residences[5].?.register,
    );
}

test "paired snapshots stay resident when their first lane feeds a deferred pair" {
    const fields = [_]Machine.Span{
        .{ .start = 6, .width = 1 },
        .{ .start = 7, .width = 1 },
    };
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 0, .bits = 0 } },
        .{ .constant_float32 = .{ .result = 1, .bits = 0 } },
        .{ .constant_float32 = .{ .result = 2, .bits = 1065353216 } },
        .{ .constant_float32 = .{ .result = 3, .bits = 1065353216 } },
        .{ .copy = .{ .result = 4, .operand = 0 } },
        .{ .binary = .{ .result = 6, .operator = .add, .left = 4, .right = 2, .type = .float32 } },
        .{ .copy = .{ .result = 5, .operand = 1 } },
        .{ .binary = .{ .result = 7, .operator = .add, .left = 5, .right = 3, .type = .float32 } },
        .{ .aggregate_init = .{ .result = .{ .start = 8, .width = 2, .aggregate = true }, .fields = &fields } },
        .{ .return_value = .{ .start = 8, .width = 2, .aggregate = true } },
    };
    const groups = [_]Machine.FloatLaneGroup{
        .{ .slots = .{ 6, 7, 0, 0 }, .width = 2, .priority = 16, .recurrence = false, .in_loop = true },
    };
    const function: Machine.Function = .{
        .name = "deferred_snapshot_pair",
        .parameter_count = 0,
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

    for (4..8) |slot| try std.testing.expect(result.float_lane_residences[slot] != null);
    try std.testing.expectEqual(
        result.float_lane_residences[4].?.register,
        result.float_lane_residences[5].?.register,
    );
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

test "profitable wide float regions stop at unsupported instructions" {
    var instructions: std.ArrayList(Machine.Instruction) = .empty;
    defer instructions.deinit(std.testing.allocator);
    try instructions.append(std.testing.allocator, .{ .constant_int = .{ .result = 2, .bits = 0 } });
    try instructions.append(std.testing.allocator, .{ .collection_load = .{
        .result = .{ .start = 3, .width = 16, .aggregate = true },
        .collection = .{ .start = 0, .width = 2, .aggregate = true },
        .index = 2,
        .count = 0,
        .dynamic = true,
        .checked = false,
        .header = 0,
        .tail = 0,
    } });
    try instructions.append(std.testing.allocator, .{ .constant_float32 = .{ .result = 19, .bits = 0x3f800000 } });
    for (0..16) |leaf| try instructions.append(std.testing.allocator, .{ .binary = .{
        .result = @intCast(20 + leaf),
        .operator = .multiply,
        .left = @intCast(3 + leaf),
        .right = 19,
        .type = .float32,
    } });
    for (0..16) |leaf| try instructions.append(std.testing.allocator, .{ .binary = .{
        .result = @intCast(36 + leaf),
        .operator = .add,
        .left = @intCast(20 + leaf),
        .right = 19,
        .type = .float32,
    } });
    try instructions.append(std.testing.allocator, .{ .constant_str = .{ .result = 52, .string = 0 } });
    try instructions.append(std.testing.allocator, .{ .print = .{ .value = 52, .kind = .string, .newline = false } });
    try instructions.append(std.testing.allocator, .{ .binary = .{
        .result = 53,
        .operator = .add,
        .left = 51,
        .right = 19,
        .type = .float32,
    } });
    try instructions.append(std.testing.allocator, .{ .return_value = .{ .start = 53, .width = 1 } });

    const function: Machine.Function = .{
        .name = "regional_reduction",
        .parameter_count = 1,
        .parameters = &.{.{ .start = 0, .width = 2, .aggregate = true }},
        .return_type = .float32,
        .return_width = 1,
        .slot_count = 54,
        .frame_size = try Machine.frameSize(54),
        .instructions = instructions.items,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);

    try std.testing.expect(result.float_residences[20] != null);
    try std.testing.expectEqual(@as(?u5, null), result.float_residences[51]);
    try std.testing.expect(result.float_residences[53] != null);
    try std.testing.expectEqual(@as(?u5, null), result.residences[52]);
}

test "hot scalar loops retain registers across a terminal print barrier" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 12345 } },
        .{ .constant_int = .{ .result = 1, .bits = 5_000_000 } },
        .{ .constant_int = .{ .result = 2, .bits = 0 } },
        .{ .copy = .{ .result = 11, .operand = 0 } },
        .{ .copy = .{ .result = 12, .operand = 2 } },
        .{ .jump = 6 },
        .{ .binary = .{ .result = 3, .operator = .less, .left = 12, .right = 1 } },
        .{ .branch = .{ .condition = 3, .then_instruction = 8, .else_instruction = 18 } },
        .{ .constant_int = .{ .result = 4, .bits = 17 } },
        .{ .binary = .{ .result = 5, .operator = .multiply, .left = 11, .right = 4, .checked = false } },
        .{ .binary = .{ .result = 6, .operator = .add, .left = 5, .right = 12 } },
        .{ .constant_int = .{ .result = 7, .bits = 1_000_003 } },
        .{ .binary = .{ .result = 8, .operator = .remainder, .left = 6, .right = 7, .checked = false } },
        .{ .constant_int = .{ .result = 9, .bits = 1 } },
        .{ .binary = .{ .result = 10, .operator = .add, .left = 12, .right = 9, .checked = false } },
        .{ .copy = .{ .result = 11, .operand = 8 } },
        .{ .copy = .{ .result = 12, .operand = 10 } },
        .{ .jump = 6 },
        .{ .print = .{ .value = 11, .kind = .signed_integer, .newline = true } },
        .return_void,
    };
    const function: Machine.Function = .{
        .name = "integer_loop_with_print",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 13,
        .frame_size = try Machine.frameSize(13),
        .instructions = &instructions,
    };
    const result = try allocate(std.testing.allocator, function);
    defer std.testing.allocator.free(result.residences);
    defer std.testing.allocator.free(result.float_residences);
    defer std.testing.allocator.free(result.float_lane_residences);

    try std.testing.expectEqual(@as(usize, 13), result.residences.len);
    try std.testing.expect(result.residences[12] != null);
    try std.testing.expect(result.residences[5] != null);
    try std.testing.expect(result.residences[6] != null);
    try std.testing.expect(result.residences[8] != null);
    try std.testing.expect(result.residences[10] != null);
    try std.testing.expect(result.residences[11] != null);
}

test "floating regions borrow volatile colors without carrying them across calls" {
    const instructions = [_]Machine.Instruction{
        .{ .constant_float32 = .{ .result = 0, .bits = 0x3f800000 } },
        .{ .constant_float32 = .{ .result = 1, .bits = 0x40000000 } },
        .{ .binary = .{ .result = 2, .operator = .multiply, .left = 0, .right = 1, .type = .float32 } },
        .{ .binary = .{ .result = 3, .operator = .multiply, .left = 2, .right = 1, .type = .float32 } },
        .{ .call = .{ .function = 0, .arguments = &.{.{ .start = 3, .width = 1 }}, .result = null } },
        .{ .binary = .{ .result = 4, .operator = .add, .left = 0, .right = 1, .type = .float32 } },
        .{ .return_value = .{ .start = 4, .width = 1 } },
    };
    const function: Machine.Function = .{
        .name = "regions",
        .parameter_count = 0,
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
    const temporary = result.float_residences[2] orelse return error.ExpectedVolatileResidence;
    try std.testing.expect(temporary < 8 or temporary >= 16);
    for ([_]usize{ 0, 1, 3 }) |slot| {
        const register = result.float_residences[slot] orelse return error.ExpectedPreservedResidence;
        try std.testing.expect(register >= 8 and register < 16);
    }
}
