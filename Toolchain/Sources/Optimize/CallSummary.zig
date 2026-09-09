const std = @import("std");
const Ir = @import("../Ir.zig");

const Allocator = std.mem.Allocator;

pub const Effects = struct {
    reads_memory: bool = false,
    writes_memory: bool = false,
    manages_ownership: bool = false,
    crosses_boundary: bool = false,
    synchronizes: bool = false,
    observes_output: bool = false,

    fn merge(self: *Effects, other: Effects) bool {
        const before = self.*;
        self.reads_memory = self.reads_memory or other.reads_memory;
        self.writes_memory = self.writes_memory or other.writes_memory;
        self.manages_ownership = self.manages_ownership or other.manages_ownership;
        self.crosses_boundary = self.crosses_boundary or other.crosses_boundary;
        self.synchronizes = self.synchronizes or other.synchronizes;
        self.observes_output = self.observes_output or other.observes_output;
        return !std.meta.eql(before, self.*);
    }
};

pub const Summary = struct {
    instructions: usize = 0,
    blocks: usize = 0,
    returns: usize = 0,
    direct_calls: usize = 0,
    checked_operations: usize = 0,
    scalar_values: usize = 0,
    aggregate_values: usize = 0,
    effects: Effects = .{},
    may_fail: bool = false,
    recursive: bool = false,
};

/// Computes local costs and a fixed point for transitive effects and
/// infallibility over the closed direct-call graph. Costs remain local so a
/// recursive SCC cannot inflate them indefinitely; inliners combine the local
/// summary with their already-bounded expansion cost.
pub fn analyze(allocator: Allocator, program: Ir.Program) ![]Summary {
    const summaries = try allocator.alloc(Summary, program.functions.len);
    for (program.functions, 0..) |function, index| summaries[index] = try localSummary(allocator, program, function);

    var changed = true;
    while (changed) {
        changed = false;
        for (program.functions, 0..) |function, index| {
            for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
                .call => |call| {
                    if (call.function >= summaries.len) {
                        if (!summaries[index].may_fail) {
                            summaries[index].may_fail = true;
                            changed = true;
                        }
                        continue;
                    }
                    if (summaries[index].effects.merge(summaries[call.function].effects)) changed = true;
                    if (summaries[call.function].may_fail and !summaries[index].may_fail) {
                        summaries[index].may_fail = true;
                        changed = true;
                    }
                },
                else => {},
            };
        }
    }

    const seen = try allocator.alloc(bool, program.functions.len);
    defer allocator.free(seen);
    for (program.functions, 0..) |_, index| {
        @memset(seen, false);
        summaries[index].recursive = reaches(program, index, index, seen, true);
    }
    return summaries;
}

/// Models caller-wide cost instead of using callee size alone. Hot sites earn
/// a larger budget because removing a repeated call can expose range, alias,
/// and scalarization passes; register-pressure and effectful operations make
/// cloning more expensive. A callee already accepted by the previous inliner
/// remains accepted: compatibility is the conservative floor while the model
/// governs newly supported IR forms. Observable boundary, ownership, and
/// synchronization effects otherwise require a dedicated proof.
pub fn shouldInline(summary: Summary, expanded_cost: usize, hot_site: bool, previously_eligible: bool) bool {
    if (previously_eligible) return true;
    if (summary.recursive or summary.effects.crosses_boundary or summary.effects.synchronizes or
        summary.effects.observes_output or summary.effects.manages_ownership)
        return false;
    const pressure_penalty = summary.scalar_values -| 16;
    const effect_penalty = @as(usize, @intFromBool(summary.effects.reads_memory)) * 2 +
        @as(usize, @intFromBool(summary.effects.writes_memory)) * 4;
    const cost = expanded_cost + summary.blocks * 2 + summary.direct_calls * 4 +
        summary.checked_operations * 2 + pressure_penalty + summary.aggregate_values * 2 + effect_penalty;
    const budget: usize = if (hot_site) 192 else 128;
    return cost <= budget;
}

pub fn isHotBlock(function: Ir.Function, block_index: usize) bool {
    for (function.blocks, 0..) |block, source| switch (block.terminator) {
        .jump => |target| if (target <= source and block_index >= target and block_index <= source) return true,
        .branch => |branch| {
            if (branch.then_block <= source and block_index >= branch.then_block and block_index <= source) return true;
            if (branch.else_block <= source and block_index >= branch.else_block and block_index <= source) return true;
        },
        else => {},
    };
    return false;
}

fn localSummary(allocator: Allocator, program: Ir.Program, function: Ir.Function) !Summary {
    var result: Summary = .{ .blocks = function.blocks.len };
    const materialized = try allocator.alloc(bool, function.value_types.len);
    defer allocator.free(materialized);
    @memset(materialized, false);
    const input_count = @min(function.capture_types.len + function.parameter_types.len, materialized.len);
    @memset(materialized[0..input_count], true);
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instructionResult(instruction)) |value| {
            if (value < materialized.len) materialized[value] = true;
        }
    };
    for (function.value_types, materialized) |value_type, present| {
        if (!present) continue;
        if (value_type.isNumeric() or value_type == .bool or value_type == .address) {
            result.scalar_values += 1;
        } else result.aggregate_values += 1;
    }
    for (function.blocks) |block| {
        result.instructions += block.instructions.len;
        for (block.instructions) |instruction| classifyInstruction(program, &result, instruction);
        switch (block.terminator) {
            .return_value, .return_void => result.returns += 1,
            .panic => {
                result.may_fail = true;
                result.effects.observes_output = true;
            },
            else => {},
        }
    }
    return result;
}

fn instructionResult(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        .class_retain,
        .class_drop,
        .list_retain,
        .list_drop,
        .string_retain,
        .string_drop,
        .global_store,
        .local_store,
        .address_store,
        .reference_store,
        .print,
        .assert,
        .mutex_lock,
        .mutex_unlock,
        => null,
        .list_edit => |value| value.result,
        .call => |value| value.result,
        .indirect_call => |value| value.result,
        .boundary_call => |value| value.result,
        .boundary_indirect_call => |value| value.result,
        .dynamic_call => |value| value.result,
        inline else => |value| value.result,
    };
}

fn classifyInstruction(program: Ir.Program, summary: *Summary, instruction: Ir.Instruction) void {
    switch (instruction) {
        .call => summary.direct_calls += 1,
        .global_load, .field_load, .collection_count, .local_load, .reference_load, .address_load => summary.effects.reads_memory = true,
        .global_store, .field_store, .local_store, .reference_store, .address_store => summary.effects.writes_memory = true,
        .collection_load => |value| {
            summary.effects.reads_memory = true;
            if (value.checked) markChecked(summary);
        },
        .collection_reference => |value| {
            summary.effects.reads_memory = true;
            if (value.checked) markChecked(summary);
        },
        .collection_replace => |value| {
            summary.effects.writes_memory = true;
            if (value.checked) markChecked(summary);
        },
        .binary => |value| if (value.checked and switch (value.operator) {
            .add, .subtract, .multiply, .divide, .remainder, .shift_left, .shift_right => true,
            else => false,
        }) markChecked(summary),
        .convert => |value| if (value.checked) markChecked(summary),
        .optional_unwrap, .assert => markChecked(summary),
        .boundary_call => |call| {
            if (call.function < program.boundary_effects.len and program.boundary_effects[call.function] == .pure) return;
            summary.effects.crosses_boundary = true;
            summary.may_fail = true;
        },
        .boundary_indirect_call, .indirect_call, .dynamic_call => {
            summary.effects.crosses_boundary = true;
            summary.may_fail = true;
        },
        .mutex_lock, .mutex_unlock => {
            summary.effects.synchronizes = true;
            summary.may_fail = true;
        },
        .print => summary.effects.observes_output = true,
        .deep_copy,
        .class_retain,
        .class_drop,
        .list_retain,
        .list_drop,
        .string_retain,
        .string_drop,
        .list_init,
        .list_edit,
        .string_concat,
        .string_from_bytes,
        => {
            summary.effects.manages_ownership = true;
            summary.may_fail = true;
        },
        else => {},
    }
}

fn markChecked(summary: *Summary) void {
    summary.checked_operations += 1;
    summary.may_fail = true;
}

fn reaches(program: Ir.Program, current: usize, target: usize, seen: []bool, first: bool) bool {
    if (current >= program.functions.len) return false;
    if (!first and current == target) return true;
    if (seen[current]) return false;
    seen[current] = true;
    const function = program.functions[current];
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .call => |call| if (reaches(program, call.function, target, seen, false)) return true,
        else => {},
    };
    return false;
}

test "summaries propagate failure and effects through direct call cycles" {
    const functions = [_]Ir.Function{
        .{
            .name = "safe_cycle_left",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &.{},
            .blocks = &.{.{
                .instructions = &.{.{ .call = .{ .result = null, .function = 1, .arguments = &.{} } }},
                .terminator = .return_void,
            }},
        },
        .{
            .name = "safe_cycle_right",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &.{},
            .blocks = &.{.{
                .instructions = &.{.{ .call = .{ .result = null, .function = 0, .arguments = &.{} } }},
                .terminator = .return_void,
            }},
        },
        .{
            .name = "checked",
            .parameter_types = &.{ .int, .int },
            .return_type = .int,
            .value_types = &.{ .int, .int, .int },
            .blocks = &.{.{
                .instructions = &.{.{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } }},
                .terminator = .{ .return_value = 2 },
            }},
        },
        .{
            .name = "checked_caller",
            .parameter_types = &.{ .int, .int },
            .return_type = .int,
            .value_types = &.{ .int, .int, .int },
            .blocks = &.{.{
                .instructions = &.{.{ .call = .{ .result = 2, .function = 2, .arguments = &.{ 0, 1 } } }},
                .terminator = .{ .return_value = 2 },
            }},
        },
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const summaries = try analyze(arena.allocator(), .{ .functions = &functions });
    try std.testing.expect(summaries[0].recursive and summaries[1].recursive);
    try std.testing.expect(!summaries[0].may_fail and !summaries[1].may_fail);
    try std.testing.expect(summaries[2].may_fail and summaries[3].may_fail);
}

test "inlining cost accounts for effects pressure and hot call sites" {
    const small: Summary = .{
        .blocks = 1,
        .scalar_values = 8,
        .effects = .{ .reads_memory = true, .writes_memory = true },
    };
    try std.testing.expect(shouldInline(small, 32, false, false));

    const medium: Summary = .{
        .blocks = 4,
        .direct_calls = 1,
        .checked_operations = 2,
        .scalar_values = 24,
        .aggregate_values = 2,
        .effects = .{ .reads_memory = true, .writes_memory = true },
    };
    try std.testing.expect(!shouldInline(medium, 100, false, false));
    try std.testing.expect(shouldInline(medium, 100, true, false));

    try std.testing.expect(!shouldInline(.{ .recursive = true }, 1, true, false));
    try std.testing.expect(!shouldInline(.{ .effects = .{ .observes_output = true } }, 1, true, false));
    try std.testing.expect(!shouldInline(.{ .aggregate_values = 64 }, 96, true, false));
    try std.testing.expect(shouldInline(.{ .effects = .{ .observes_output = true } }, 1, false, true));
}

test "only proven pure direct boundaries are transparent to call summaries" {
    const mixed_calls = [_]Ir.Instruction{
        .{ .boundary_call = .{ .result = 0, .function = 0, .arguments = &.{} } },
        .{ .boundary_call = .{ .result = 1, .function = 1, .arguments = &.{} } },
    };
    const mixed_functions = [_]Ir.Function{.{
        .name = "boundaries",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{ .float32, .float32 },
        .blocks = &.{.{ .instructions = &mixed_calls, .terminator = .return_void }},
    }};
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const mixed = try analyze(arena.allocator(), .{
        .functions = &mixed_functions,
        .boundary_effects = &.{ .pure, .unknown },
    });
    try std.testing.expect(mixed[0].effects.crosses_boundary);
    try std.testing.expect(mixed[0].may_fail);

    const pure_calls = [_]Ir.Instruction{mixed_calls[0]};
    const pure_functions = [_]Ir.Function{.{
        .name = "pure_boundary",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{.float32},
        .blocks = &.{.{ .instructions = &pure_calls, .terminator = .return_void }},
    }};
    const pure = try analyze(arena.allocator(), .{
        .functions = &pure_functions,
        .boundary_effects = &.{.pure},
    });
    try std.testing.expect(!pure[0].effects.crosses_boundary);
    try std.testing.expect(!pure[0].may_fail);
}

test "call pressure excludes values removed by earlier optimizer passes" {
    const instructions = [_]Ir.Instruction{.{ .copy = .{ .result = 63, .operand = 0 } }};
    const value_types: [64]Ir.Type = @splat(.float32);
    const functions = [_]Ir.Function{.{
        .name = "sparse_values",
        .parameter_types = &.{.float32},
        .return_type = .float32,
        .value_types = &value_types,
        .blocks = &.{.{ .instructions = &instructions, .terminator = .{ .return_value = 63 } }},
    }};
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const summaries = try analyze(arena.allocator(), .{ .functions = &functions });
    try std.testing.expectEqual(@as(usize, 2), summaries[0].scalar_values);
}

test "backedges classify only their loop range as hot" {
    const function: Ir.Function = .{
        .name = "loop",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{},
        .blocks = &.{
            .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
            .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
            .{ .instructions = &.{}, .terminator = .return_void },
        },
    };
    try std.testing.expect(!isHotBlock(function, 0));
    try std.testing.expect(isHotBlock(function, 1));
    try std.testing.expect(!isHotBlock(function, 2));
}
