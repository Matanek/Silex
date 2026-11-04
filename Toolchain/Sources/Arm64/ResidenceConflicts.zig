const std = @import("std");
const Machine = @import("Machine.zig");
const Liveness = @import("ResidenceLiveness.zig");
const successorLive = Liveness.successorLive;
const instructionDefines = Liveness.instructionDefines;

test {
    _ = @import("ResidenceConflictsTests.zig");
}

// Immutable facts only; colors and alias components stay in the allocator.
pub const Facts = struct {
    storage: []u64,
    words: usize,
    slots: usize,

    pub fn init(allocator: std.mem.Allocator, instructions: []const Machine.Instruction, live: []const bool, slots: usize) std.mem.Allocator.Error!Facts {
        std.debug.assert(live.len == instructions.len * slots);
        const words = std.math.divCeil(usize, instructions.len, 64) catch unreachable;
        const storage = try allocator.alloc(u64, (2 * slots + 1) * words);
        @memset(storage, 0);
        const self: Facts = .{ .storage = storage, .words = words, .slots = slots };
        for (instructions, 0..) |instruction, index| {
            const word = index / 64;
            const mask = @as(u64, 1) << @intCast(index % 64);
            if (instruction == .class_load) self.classLoads()[word] |= mask;
            for (0..slots) |slot| {
                if (live[index * slots + slot]) self.liveRow(slot)[word] |= mask;
                if (Liveness.instructionDefines(instruction, slot)) self.definitions(slot)[word] |= mask;
            }
        }
        return self;
    }

    pub fn deinit(self: Facts, allocator: std.mem.Allocator) void {
        allocator.free(self.storage);
    }

    fn liveRow(self: Facts, slot: usize) []u64 {
        return self.storage[slot * self.words ..][0..self.words];
    }

    fn definitions(self: Facts, slot: usize) []u64 {
        return self.storage[(self.slots + slot) * self.words ..][0..self.words];
    }

    fn classLoads(self: Facts) []u64 {
        return self.storage[2 * self.slots * self.words ..];
    }

    pub fn interferes(self: Facts, left: usize, right: usize, instructions: []const Machine.Instruction, live: []const bool) bool {
        const result = self.packedInterferes(left, right, instructions, live);
        // Exercise every actual allocator query against the former scan in unit builds.
        if (@import("builtin").is_test and result != scalarInterferes(instructions, live, self.slots, left, right))
            @panic("compact residence conflict differs from scalar oracle");
        return result;
    }

    fn packedInterferes(self: Facts, left: usize, right: usize, instructions: []const Machine.Instruction, live: []const bool) bool {
        const left_live = self.liveRow(left);
        const right_live = self.liveRow(right);
        const left_defs = self.definitions(left);
        const right_defs = self.definitions(right);
        for (left_live, right_live, left_defs, right_defs, self.classLoads(), 0..) |ll, rl, ld, rd, classes, word| {
            // Simultaneous class outputs conflict even when both results are dead.
            if (ld & rd & classes != 0) return true;
            var candidates = (ll & (rl | rd)) | (ld & rl);
            while (candidates != 0) {
                const index = word * 64 + @ctz(candidates);
                candidates &= candidates - 1;
                if (!instructionCanShareResidence(instructions, live, self.slots, index, left, right)) return true;
            }
        }
        return false;
    }
};

// Retained for small one-off queries and as the scalar differential oracle.
pub fn scalarInterferes(instructions: []const Machine.Instruction, live: []const bool, slot_count: usize, slot: usize, other: usize) bool {
    for (0..live.len / slot_count) |instruction| {
        // Class loads emit every result leaf, including unused ones.
        // Their simultaneous definitions must not share a register: a
        // dead trailing leaf would overwrite an earlier live result.
        if (instructions[instruction] == .class_load) {
            const result = instructions[instruction].class_load.result;
            if (slot >= result.start and slot < @as(usize, result.start) + result.width and
                other >= result.start and other < @as(usize, result.start) + result.width) return true;
        }
        // Every interference case below needs at least one live input.
        // Skip dead instruction points before inspecting their emitters.
        if (!live[instruction * slot_count + slot] and !live[instruction * slot_count + other]) continue;
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
    return false;
}

pub fn instructionCanShareResidence(
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

pub fn binaryCanShareOperand(binary: Machine.Instruction.Binary) bool {
    if (binary.type.isFloat()) return switch (binary.operator) {
        .add, .subtract, .multiply, .divide => true,
        else => false,
    };
    return switch (binary.operator) {
        .add, .subtract, .divide, .remainder, .bit_and, .bit_xor, .shift_left, .shift_right => true,
        else => false,
    };
}
