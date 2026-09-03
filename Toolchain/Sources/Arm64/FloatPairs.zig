const std = @import("std");
const Machine = @import("Machine.zig");
const MemoryResidence = @import("MemoryResidence.zig");
const ResidenceLiveness = @import("ResidenceLiveness.zig");
const Allocator = std.mem.Allocator;
const Interval = ResidenceLiveness.Interval;
const successorLive = ResidenceLiveness.successorLive;
const instructionUses = ResidenceLiveness.instructionUses;
const instructionDefines = ResidenceLiveness.instructionDefines;
const heavierThan = ResidenceLiveness.heavierThan;

pub fn allocate(
    allocator: Allocator,
    function: Machine.Function,
    float_slots: []const bool,
    residences: []?Machine.FloatLaneResidence,
    registers: []const u5,
) Allocator.Error!void {
    const partners = try allocator.alloc(?Machine.Slot, function.slot_count);
    defer allocator.free(partners);
    @memset(partners, null);
    const memory_slots = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(memory_slots);
    @memset(memory_slots, false);
    for (function.instructions) |instruction| MemoryResidence.pinFloatLanes(instruction, memory_slots);
    for (memory_slots, 0..) |pinned, slot| if (pinned) {
        partners[slot] = @intCast(slot);
    };
    const planned = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(planned);
    @memset(planned, false);

    const eligible_recurrence_slots = try allocator.alloc(bool, function.slot_count);
    defer allocator.free(eligible_recurrence_slots);
    @memset(eligible_recurrence_slots, false);
    for (function.float_lane_groups) |group| {
        if (!group.recurrence or !group.in_loop or group.priority < 8) continue;
        for (0..group.width) |lane| eligible_recurrence_slots[group.slots[lane]] = true;
    }

    // Keep control-flow recurrences scalar unless they are hot loop-local
    // chains. Those chains are colored with full CFG liveness below.
    for (function.float_lane_groups) |group| {
        if (!group.recurrence) continue;
        for (0..group.width) |lane| {
            const slot = group.slots[lane];
            if (!eligible_recurrence_slots[slot]) partners[slot] = slot;
        }
    }

    // Prefer affinity discovered while scalar values still have their IR
    // identity. ARM64 consumes pairs today; XYZ remains one portable group and
    // is lowered as XY plus a scalar Z until a profitable .4s realization is
    // selected by this backend.
    const rounds: usize = if (MemoryResidence.required(function)) 2 else 1;
    for (0..rounds) |round| {
        for (function.float_lane_groups) |group| {
            if (group.priority == 0 or
                (group.recurrence and (!group.in_loop or group.priority < 8))) continue;
            var lane: usize = 0;
            while (lane + 1 < group.width) : (lane += 2) {
                const first = group.slots[lane];
                const second = group.slots[lane + 1];
                if (float_slots[first] and float_slots[second] and
                    ((partners[first] == null and partners[second] == null) or
                        (rounds == 2 and partners[first] == second and partners[second] == first)))
                {
                    const first_instruction = definingInstruction(function.instructions, first) orelse continue;
                    const second_instruction = definingInstruction(function.instructions, second) orelse continue;
                    // In a memory kernel, establish arithmetic dependencies before
                    // copy-only affinities can reserve their operands differently.
                    if (rounds == 2 and round == 0 and
                        (first_instruction != .binary or second_instruction != .binary or
                            first_instruction.binary.type != .float32 or second_instruction.binary.type != .float32 or
                            first_instruction.binary.operator != second_instruction.binary.operator)) continue;
                    pairSlots(partners, first, second);
                    if (group.in_loop and group.priority >= 8) {
                        planned[first] = true;
                        planned[second] = true;
                    }
                    pairDefinitionOperands(
                        function.instructions,
                        partners,
                        first,
                        second,
                        first_instruction,
                        second_instruction,
                    );
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

    // Operand-tree affinity may reopen a recurrence exclusion. Memory
    // exclusions are mandatory, including when reached through such a tree.
    // Remove both halves before coloring; never let a memory emitter silently
    // read a stack home while the current value exists only in a SIMD lane.
    for (memory_slots, 0..) |pinned, slot| if (pinned) {
        if (partners[slot]) |partner| partners[partner] = null;
        partners[slot] = null;
    };
    if (MemoryResidence.required(function)) {
        pruneEarlyMemoryUses(function.instructions, partners);
        // Memory exclusions can break a planned arithmetic chain. Require
        // every surviving pair to have resident operands, even in hot loops.
        @memset(planned, false);
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
    const leaders = try allocator.alloc(?u5, function.slot_count);
    defer allocator.free(leaders);
    @memset(leaders, null);
    try allocatePairGraph(
        allocator,
        leaders,
        intervals.items,
        registers,
        partners,
        function.instructions,
        function.slot_count,
    );
    for (intervals.items) |interval| if (leaders[interval.slot]) |register| {
        const partner = partners[interval.slot].?;
        residences[interval.slot] = .{ .register = register, .lane = 0, .partner = partner };
        residences[partner] = .{ .register = register, .lane = 1, .partner = interval.slot };
    };
    try pruneUnprofitableFloatPairs(allocator, function.instructions, residences, planned, MemoryResidence.required(function));
}

fn pruneEarlyMemoryUses(instructions: []const Machine.Instruction, partners: []?Machine.Slot) void {
    for (partners, 0..) |maybe_partner, slot| {
        const partner = maybe_partner orelse continue;
        if (partner <= slot) continue;
        var first: ?usize = null;
        var second: ?usize = null;
        var multiple = false;
        for (instructions, 0..) |instruction, index| {
            if (instructionDefines(instruction, slot)) {
                if (first != null) multiple = true;
                first = index;
            }
            if (instructionDefines(instruction, partner)) {
                if (second != null) multiple = true;
                second = index;
            }
        }
        if (multiple or first == null or second == null) continue;
        const definition = instructions[first.?];
        if (definition != .binary and definition != .copy) continue;
        // The encoder delays the leader until the follower. A checked load,
        // store or scalar use in between must not observe that uncomputed
        // result. Portable affinity alone does not prove this ordering.
        if (first.? >= second.? or !instructionsCanPair(instructions, first.?, second.?, definition)) {
            partners[slot] = null;
            partners[partner] = null;
        }
    }
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
    const live = try allocator.alloc(bool, instructions.len * slot_count);
    defer allocator.free(live);
    @memset(live, false);
    var live_changed = true;
    while (live_changed) {
        live_changed = false;
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
                    live_changed = true;
                }
            }
        }
    }

    const component_colors = try allocator.alloc(?u5, slot_count);
    defer allocator.free(component_colors);
    @memset(component_colors, null);
    std.mem.sort(Interval, component_intervals.items, {}, heavierThan);
    for (component_intervals.items) |interval| {
        for (registers) |register| {
            if (pairComponentColorConflicts(
                interval.slot,
                register,
                component_colors,
                components,
                partners,
                live,
                instructions,
                slot_count,
            )) continue;
            component_colors[interval.slot] = register;
            break;
        }
    }
    for (intervals) |interval| leaders[interval.slot] = component_colors[findPairComponent(components, interval.slot)];
}

fn pairComponentColorConflicts(
    component: Machine.Slot,
    register: u5,
    colors: []const ?u5,
    components: []const Machine.Slot,
    partners: []const ?Machine.Slot,
    live: []const bool,
    instructions: []const Machine.Instruction,
    slot_count: usize,
) bool {
    for (colors, 0..) |color, other| {
        if (color == null or color.? != register or other == component) continue;
        for (instructions, 0..) |instruction, index| {
            const left_live = pairComponentLiveAt(components, partners, live, slot_count, component, index);
            const right_live = pairComponentLiveAt(components, partners, live, slot_count, @intCast(other), index);
            if (left_live and right_live) return true;
            if (pairComponentDefinedBy(components, partners, component, instruction) and right_live) return true;
            if (pairComponentDefinedBy(components, partners, @intCast(other), instruction) and left_live) return true;
        }
    }
    return false;
}

fn pairComponentLiveAt(
    components: []const Machine.Slot,
    partners: []const ?Machine.Slot,
    live: []const bool,
    slot_count: usize,
    component: Machine.Slot,
    instruction: usize,
) bool {
    for (0..slot_count) |slot| {
        if (!slotBelongsToPairComponent(components, partners, @intCast(slot), component)) continue;
        if (live[instruction * slot_count + slot]) return true;
    }
    return false;
}

fn pairComponentDefinedBy(
    components: []const Machine.Slot,
    partners: []const ?Machine.Slot,
    component: Machine.Slot,
    instruction: Machine.Instruction,
) bool {
    for (components, 0..) |_, slot| {
        if (slotBelongsToPairComponent(components, partners, @intCast(slot), component) and
            instructionDefines(instruction, slot)) return true;
    }
    return false;
}

fn slotBelongsToPairComponent(
    components: []const Machine.Slot,
    partners: []const ?Machine.Slot,
    slot: Machine.Slot,
    component: Machine.Slot,
) bool {
    if (findPairComponent(components, slot) == component) return true;
    const partner = partners[slot] orelse return false;
    return findPairComponent(components, partner) == component;
}

fn buildPairComponents(
    components: []Machine.Slot,
    partners: []const ?Machine.Slot,
    instructions: []const Machine.Instruction,
) void {
    for (instructions) |instruction| switch (instruction) {
        .copy => |copy| unionPairedTransfer(components, partners, copy.result, copy.operand),
        .copy_range => |copy| for (0..copy.result.width) |leaf| {
            unionPairedTransfer(
                components,
                partners,
                @intCast(@as(usize, copy.result.start) + leaf),
                @intCast(@as(usize, copy.operand.start) + leaf),
            );
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
    scalar_copies: bool,
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
            if (pairDefinitionReady(instructions, residences, @intCast(slot), residence.?.partner, scalar_copies)) continue;
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
    scalar_copies: bool,
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
            .copy => |right| scalar_copies or slotsResidentInOrderOrEqual(residences, left.operand, right.operand),
            else => false,
        },
        .copy_range => |left| switch (second.?) {
            .copy_range => |right| scalar_copies or slotsResidentInOrderOrEqual(
                residences,
                left.operand.start + first_slot - left.result.start,
                right.operand.start + second_slot - right.result.start,
            ),
            else => false,
        },
        // Aggregate construction copies each leaf immediately, just like a
        // scalar copy. Memory kernels may seed lanes from those snapshots;
        // their original operands need not already form a SIMD pair.
        .aggregate_init => scalar_copies and second.? == .aggregate_init,
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
        .copy_range => |left| switch (second) {
            .copy_range => |right| markOperandDependency(
                instructions,
                residences,
                required,
                left.operand.start + first_slot - left.result.start,
                right.operand.start + second_slot - right.result.start,
            ),
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

fn pairDefinitionOperands(
    instructions: []const Machine.Instruction,
    partners: []?Machine.Slot,
    first_slot: Machine.Slot,
    second_slot: Machine.Slot,
    first: Machine.Instruction,
    second: Machine.Instruction,
) void {
    switch (first) {
        .binary => switch (second) {
            .binary => pairBinaryOperands(instructions, partners, first, second),
            else => {},
        },
        .copy => |left| switch (second) {
            .copy => |right| if (left.operand != right.operand) {
                pairResidentOperandTree(instructions, partners, left.operand, right.operand);
            },
            else => {},
        },
        .copy_range => |left| switch (second) {
            .copy_range => |right| {
                const left_offset = first_slot - left.result.start;
                const right_offset = second_slot - right.result.start;
                pairResidentOperandTree(
                    instructions,
                    partners,
                    left.operand.start + left_offset,
                    right.operand.start + right_offset,
                );
            },
            else => {},
        },
        else => {},
    }
}

fn pairResidentOperandTree(
    instructions: []const Machine.Instruction,
    partners: []?Machine.Slot,
    first: Machine.Slot,
    second: Machine.Slot,
) void {
    if (partners[first] == first) partners[first] = null;
    if (partners[second] == second) partners[second] = null;
    pairSlots(partners, first, second);
    if (partners[first] != second or partners[second] != first) return;
    const first_definition = definingInstruction(instructions, first) orelse return;
    const second_definition = definingInstruction(instructions, second) orelse return;
    switch (first_definition) {
        .copy => |left| switch (second_definition) {
            .copy => |right| if (operandPairCanBecomeResident(instructions, left.operand, right.operand, partners)) {
                pairResidentOperandTree(instructions, partners, left.operand, right.operand);
            },
            else => {},
        },
        .copy_range => |left| switch (second_definition) {
            .copy_range => |right| {
                const left_operand = left.operand.start + first - left.result.start;
                const right_operand = right.operand.start + second - right.result.start;
                if (operandPairCanBecomeResident(instructions, left_operand, right_operand, partners)) {
                    pairResidentOperandTree(instructions, partners, left_operand, right_operand);
                }
            },
            else => {},
        },
        else => {},
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
        .copy_range => |left| switch (second_definition.?) {
            .copy_range => |right| blk: {
                const left_operand = left.operand.start + first - left.result.start;
                const right_operand = right.operand.start + second - right.result.start;
                break :blk first + 1 == second and left_operand + 1 == right_operand;
            },
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
