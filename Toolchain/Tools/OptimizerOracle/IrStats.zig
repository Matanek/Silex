const std = @import("std");
const Silex = @import("silex_optimizer_api");

pub const Counts = struct {
    functions: usize = 0,
    blocks: usize = 0,
    instructions: usize = 0,
    values: usize = 0,
    locals: usize = 0,
};

pub const Profile = struct {
    counts: Counts = .{},
    constants: usize = 0,
    copies: usize = 0,
    local_loads: usize = 0,
    local_stores: usize = 0,
    reference_loads: usize = 0,
    reference_stores: usize = 0,
    other_loads: usize = 0,
    other_stores: usize = 0,
    arithmetic: usize = 0,
    multiplies: usize = 0,
    divisions: usize = 0,
    remainders: usize = 0,
    signed_remainders: usize = 0,
    unsigned_remainders: usize = 0,
    shifts: usize = 0,
    comparisons: usize = 0,
    conversions: usize = 0,
    calls: usize = 0,
    internal_calls: usize = 0,
    aggregates: usize = 0,
    value_aggregate_operations: usize = 0,
    collections: usize = 0,
    strings: usize = 0,
    checked_operations: usize = 0,
    safety_guards: usize = 0,
    branches: usize = 0,
    jumps: usize = 0,
    returns: usize = 0,
    panics: usize = 0,
    prints: usize = 0,
    constant_prints: usize = 0,
    loop_back_edges: usize = 0,
};

pub const MatchedDeltas = struct {
    local_memory_removed: usize = 0,
    safety_removed: usize = 0,
    compute_removed: usize = 0,
    blocks_removed: usize = 0,
    conversions_removed: usize = 0,
};

pub const Comparison = struct {
    raw: Profile,
    optimized: Profile,
    matched: MatchedDeltas,
};

pub fn count(program: Silex.Ir.Program) Counts {
    var result: Counts = .{ .functions = program.functions.len };
    for (program.functions) |function| {
        result.blocks += function.blocks.len;
        result.values += function.value_types.len;
        result.locals += function.local_types.len;
        for (function.blocks) |block| result.instructions += block.instructions.len;
    }
    return result;
}

pub fn profile(program: Silex.Ir.Program) Profile {
    var result: Profile = .{};
    result.counts.functions = program.functions.len;
    for (program.functions) |function| {
        profileFunction(&result, function);
    }
    return result;
}

/// Profiles the closed execution surface rooted at `main`. Inlining leaves
/// the original callee definitions in portable IR, while native emission and
/// LLVM both discard functions that are no longer reachable. Comparing the
/// full table would therefore charge an inlined body twice instead of
/// measuring the final caller.
pub fn profileReachable(allocator: @import("std").mem.Allocator, program: Silex.Ir.Program) !Profile {
    const reachable = try reachableFunctions(allocator, program);
    defer allocator.free(reachable);

    var result: Profile = .{};
    for (program.functions, 0..) |function, index| if (reachable[index]) {
        result.counts.functions += 1;
        profileFunction(&result, function);
    };
    return result;
}

/// Returns the closed execution surface rooted at `main`. The caller owns the
/// returned mask. A library-shaped program without `main` keeps every function.
pub fn reachableFunctions(allocator: @import("std").mem.Allocator, program: Silex.Ir.Program) ![]bool {
    var main_index: ?usize = null;
    for (program.functions, 0..) |function, index| if (@import("std").mem.eql(u8, function.name, "main")) {
        main_index = index;
        break;
    };
    const reachable = try allocator.alloc(bool, program.functions.len);
    @memset(reachable, main_index == null);
    if (main_index == null) return reachable;
    reachable[main_index.?] = true;
    var changed = true;
    while (changed) {
        changed = false;
        for (program.functions, 0..) |function, index| {
            if (!reachable[index]) continue;
            for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
                .call => |call| markReachable(reachable, call.function, &changed),
                .function_reference => |reference| markReachable(reachable, reference.function, &changed),
                .dynamic_call => |call| {
                    markReachable(reachable, call.function, &changed);
                    for (call.implementations) |implementation| {
                        markReachable(reachable, implementation.function, &changed);
                    }
                },
                .class_drop => |drop| for (drop.plans) |plan| for (plan.functions) |finalizer| {
                    markReachable(reachable, finalizer.function, &changed);
                },
                else => {},
            };
        }
    }

    return reachable;
}

fn markReachable(reachable: []bool, function: usize, changed: *bool) void {
    if (function >= reachable.len or reachable[function]) return;
    reachable[function] = true;
    changed.* = true;
}

fn profileFunction(result: *Profile, function: Silex.Ir.Function) void {
    result.counts.blocks += function.blocks.len;
    result.counts.values += function.value_types.len;
    result.counts.locals += function.local_types.len;
    for (function.blocks, 0..) |block, block_index| {
        result.counts.instructions += block.instructions.len;
        for (block.instructions) |instruction| {
            profileInstruction(result, instruction, function.value_types);
            if (instruction == .print and valueIsDirectConstant(function, instruction.print.value))
                result.constant_prints += 1;
        }
        switch (block.terminator) {
            .jump => |target| {
                result.jumps += 1;
                if (target <= block_index) result.loop_back_edges += 1;
            },
            .branch => |branch_value| {
                result.branches += 1;
                if (branch_value.then_block <= block_index or branch_value.else_block <= block_index)
                    result.loop_back_edges += 1;
            },
            .return_value, .return_void => result.returns += 1,
            .panic => result.panics += 1,
        }
    }
}

pub fn compare(allocator: @import("std").mem.Allocator, raw: Silex.Ir.Program, optimized: Silex.Ir.Program) !Comparison {
    var result: Comparison = .{
        .raw = try profileReachable(allocator, raw),
        .optimized = try profileReachable(allocator, optimized),
        .matched = .{},
    };
    for (raw.functions, 0..) |raw_function, function_index| {
        if (function_index >= optimized.functions.len) continue;
        const optimized_function = optimized.functions[function_index];
        if (!@import("std").mem.eql(u8, raw_function.name, optimized_function.name)) continue;
        const raw_function_profile = profile(.{ .functions = &.{raw_function} });
        const optimized_function_profile = profile(.{ .functions = &.{optimized_function} });
        result.matched.local_memory_removed += removed(
            raw_function_profile.local_loads + raw_function_profile.local_stores,
            optimized_function_profile.local_loads + optimized_function_profile.local_stores,
        );
        result.matched.safety_removed += removed(
            raw_function_profile.safety_guards,
            optimized_function_profile.safety_guards,
        );
        result.matched.compute_removed += removed(
            computationCount(raw_function_profile),
            computationCount(optimized_function_profile),
        );
        result.matched.blocks_removed += removed(
            raw_function_profile.counts.blocks,
            optimized_function_profile.counts.blocks,
        );
        result.matched.conversions_removed += removed(
            raw_function_profile.conversions,
            optimized_function_profile.conversions,
        );
    }
    return result;
}

fn computationCount(value: Profile) usize {
    return value.arithmetic + value.comparisons + value.conversions;
}

fn removed(before: usize, after: usize) usize {
    return before -| after;
}

fn profileInstruction(result: *Profile, instruction: Silex.Ir.Instruction, value_types: []const Silex.Ir.Type) void {
    switch (instruction) {
        .constant_int, .constant_bool, .constant_bytes, .constant_float32, .constant_float64, .optional_null => result.constants += 1,
        .copy, .deep_copy => |copy| {
            result.copies += 1;
            if (value_types[copy.operand].structureIndex() != null) result.value_aggregate_operations += 1;
        },
        .class_cast => result.copies += 1,
        .local_load => result.local_loads += 1,
        .local_store => result.local_stores += 1,
        .reference_load => {
            result.reference_loads += 1;
            result.other_loads += 1;
        },
        .global_load, .address_load => result.other_loads += 1,
        .field_load => {
            result.other_loads += 1;
            result.value_aggregate_operations += 1;
        },
        .collection_load => |load| {
            result.other_loads += 1;
            if (load.checked) {
                result.checked_operations += 1;
                result.safety_guards += 1;
            }
        },
        .reference_store => {
            result.reference_stores += 1;
            result.other_stores += 1;
        },
        .collection_replace => |replacement| {
            result.other_stores += 1;
            if (replacement.checked) {
                result.checked_operations += 1;
                result.safety_guards += 1;
            }
        },
        .global_store, .address_store => result.other_stores += 1,
        .field_store => {
            result.other_stores += 1;
            result.value_aggregate_operations += 1;
        },
        .binary => |binary| {
            if (binary.checked) result.checked_operations += 1;
            if (binaryHasSafetyGuard(binary, value_types)) result.safety_guards += 1;
            switch (binary.operator) {
                .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => result.comparisons += 1,
                .multiply => {
                    result.arithmetic += 1;
                    result.multiplies += 1;
                },
                .divide => {
                    result.arithmetic += 1;
                    result.divisions += 1;
                },
                .remainder => {
                    result.arithmetic += 1;
                    result.remainders += 1;
                    if (value_types[binary.left].isSignedInteger())
                        result.signed_remainders += 1
                    else
                        result.unsigned_remainders += 1;
                },
                .shift_left, .shift_right => {
                    result.arithmetic += 1;
                    result.shifts += 1;
                },
                else => result.arithmetic += 1,
            }
        },
        .unary => |unary| {
            result.arithmetic += 1;
            if (value_types[unary.operand].isInteger()) result.safety_guards += 1;
        },
        .convert => |conversion| {
            result.conversions += 1;
            if (conversion.checked) {
                result.checked_operations += 1;
                result.safety_guards += 1;
            }
        },
        .call => {
            result.calls += 1;
            result.internal_calls += 1;
        },
        .indirect_call, .boundary_call, .dynamic_call => result.calls += 1,
        .structure_init => {
            result.aggregates += 1;
            result.value_aggregate_operations += 1;
        },
        .protocol_init, .protocol_test, .protocol_extract, .enum_init, .enum_test, .enum_payload, .enum_raw => result.aggregates += 1,
        .collection_reference => |reference| {
            result.collections += 1;
            if (reference.checked) {
                result.checked_operations += 1;
                result.safety_guards += 1;
            }
        },
        .list_init, .collection_count, .list_edit, .collection_slice, .collection_view => result.collections += 1,
        .constant_str, .string_address, .string_byte_count, .string_byte_at, .string_from_bytes, .format_value, .string_concat, .string_count => result.strings += 1,
        .print => result.prints += 1,
        .assert => result.panics += 1,
        else => {},
    }
}

fn valueIsDirectConstant(function: Silex.Ir.Function, value: Silex.Ir.ValueId) bool {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .constant_int => |constant| if (constant.result == value) return true,
        .constant_bool => |constant| if (constant.result == value) return true,
        .constant_str => |constant| if (constant.result == value) return true,
        .constant_bytes => |constant| if (constant.result == value) return true,
        .constant_float32 => |constant| if (constant.result == value) return true,
        .constant_float64 => |constant| if (constant.result == value) return true,
        else => {},
    };
    return false;
}

fn binaryHasSafetyGuard(binary: Silex.Ir.Instruction.Binary, value_types: []const Silex.Ir.Type) bool {
    if (!value_types[binary.left].isInteger()) return false;
    return switch (binary.operator) {
        .add, .subtract, .multiply => binary.checked,
        .divide, .remainder => binary.checked,
        .shift_left, .shift_right => binary.checked,
        else => false,
    };
}

pub fn countFunction(program: Silex.Ir.Program, name: []const u8) ?Counts {
    var matched: ?Silex.Ir.Function = null;
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, name)) return functionCounts(function);
        if (!qualifiedNameMatches(function.name, name)) continue;
        if (matched != null) return null;
        matched = function;
    }
    return if (matched) |function| functionCounts(function) else null;
}

fn functionCounts(function: Silex.Ir.Function) Counts {
    var result: Counts = .{
        .functions = 1,
        .blocks = function.blocks.len,
        .values = function.value_types.len,
        .locals = function.local_types.len,
    };
    for (function.blocks) |block| result.instructions += block.instructions.len;
    return result;
}

fn qualifiedNameMatches(candidate: []const u8, leaf: []const u8) bool {
    if (candidate.len <= leaf.len or candidate[candidate.len - leaf.len - 1] != '.') return false;
    return std.mem.endsWith(u8, candidate, leaf);
}

test "IR counts aggregate all functions and blocks" {
    const program: Silex.Ir.Program = .{ .functions = &.{.{
        .name = "main",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{.int},
        .local_types = &.{.int},
        .blocks = &.{.{
            .instructions = &.{.{ .constant_int = .{ .result = 0, .bits = 1 } }},
            .terminator = .return_void,
        }},
    }} };
    const result = count(program);
    try @import("std").testing.expectEqual(@as(usize, 1), result.functions);
    try @import("std").testing.expectEqual(@as(usize, 1), result.blocks);
    try @import("std").testing.expectEqual(@as(usize, 1), result.instructions);
    try @import("std").testing.expectEqual(@as(usize, 1), result.values);
    try @import("std").testing.expectEqual(@as(usize, 1), result.locals);
    const function = countFunction(program, "main").?;
    try @import("std").testing.expectEqual(@as(usize, 1), function.blocks);
    try @import("std").testing.expect(countFunction(program, "missing") == null);
}

test "IR safety guards exclude comparisons and floating arithmetic" {
    const program: Silex.Ir.Program = .{ .functions = &.{.{
        .name = "main",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{ .int, .int, .bool, .float64, .float64, .int, .int },
        .local_types = &.{},
        .blocks = &.{.{
            .instructions = &.{
                .{ .binary = .{ .result = 2, .operator = .less, .left = 0, .right = 1 } },
                .{ .binary = .{ .result = 4, .operator = .add, .left = 3, .right = 3 } },
                .{ .binary = .{ .result = 5, .operator = .add, .left = 0, .right = 1, .checked = false } },
                .{ .binary = .{ .result = 6, .operator = .multiply, .left = 0, .right = 1 } },
                .{ .unary = .{ .result = 5, .operator = .negate, .operand = 0 } },
            },
            .terminator = .return_void,
        }},
    }} };
    const result = profile(program);
    try @import("std").testing.expectEqual(@as(usize, 2), result.safety_guards);
}

test "IR profiles reference traffic separately from other memory" {
    const program: Silex.Ir.Program = .{ .functions = &.{.{
        .name = "touch",
        .parameter_types = &.{.address},
        .return_type = .void,
        .value_types = &.{ .address, .int },
        .local_types = &.{},
        .blocks = &.{.{
            .instructions = &.{
                .{ .reference_load = .{ .result = 1, .reference = 0 } },
                .{ .reference_store = .{ .reference = 0, .operand = 1 } },
            },
            .terminator = .return_void,
        }},
    }} };
    const result = profile(program);
    try @import("std").testing.expectEqual(@as(usize, 1), result.reference_loads);
    try @import("std").testing.expectEqual(@as(usize, 1), result.reference_stores);
    try @import("std").testing.expectEqual(@as(usize, 1), result.other_loads);
    try @import("std").testing.expectEqual(@as(usize, 1), result.other_stores);
}

test "IR counts checked collection mutations and references as safety guards" {
    const collection = Silex.Ir.Type.structure(0);
    const program: Silex.Ir.Program = .{ .functions = &.{.{
        .name = "mutate",
        .parameter_types = &.{ collection, .int, .int },
        .return_type = .void,
        .value_types = &.{ collection, .int, .int, collection, .address },
        .blocks = &.{.{
            .instructions = &.{
                .{ .collection_replace = .{ .result = 3, .collection = 0, .index = 1, .replacement = 2, .position = .{ .offset = 0, .line = 1, .column = 1 } } },
                .{ .collection_reference = .{ .result = 4, .collection = 3, .reference = null, .index = 1, .position = .{ .offset = 0, .line = 1, .column = 1 } } },
            },
            .terminator = .return_void,
        }},
    }} };
    const result = profile(program);
    try @import("std").testing.expectEqual(@as(usize, 2), result.checked_operations);
    try @import("std").testing.expectEqual(@as(usize, 2), result.safety_guards);
}

test "matched safety deltas ignore checks duplicated into a caller" {
    const raw: Silex.Ir.Program = .{ .functions = &.{
        .{
            .name = "worker",
            .parameter_types = &.{ .int, .int },
            .return_type = .int,
            .value_types = &.{ .int, .int, .int },
            .local_types = &.{},
            .blocks = &.{.{
                .instructions = &.{.{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } }},
                .terminator = .{ .return_value = 2 },
            }},
        },
        .{
            .name = "caller",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &.{},
            .local_types = &.{},
            .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }},
        },
    } };
    const optimized: Silex.Ir.Program = .{ .functions = &.{
        .{
            .name = "worker",
            .parameter_types = &.{ .int, .int },
            .return_type = .int,
            .value_types = &.{ .int, .int, .int },
            .local_types = &.{},
            .blocks = &.{.{
                .instructions = &.{.{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1, .checked = false } }},
                .terminator = .{ .return_value = 2 },
            }},
        },
        .{
            .name = "caller",
            .parameter_types = &.{ .int, .int },
            .return_type = .int,
            .value_types = &.{ .int, .int, .int },
            .local_types = &.{},
            .blocks = &.{.{
                .instructions = &.{.{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1 } }},
                .terminator = .{ .return_value = 2 },
            }},
        },
    } };
    const result = try compare(@import("std").testing.allocator, raw, optimized);
    try @import("std").testing.expectEqual(@as(usize, 1), result.raw.safety_guards);
    try @import("std").testing.expectEqual(@as(usize, 1), result.optimized.safety_guards);
    try @import("std").testing.expectEqual(@as(usize, 1), result.matched.safety_removed);
}

test "reachable profiles charge an inlined body only to its final caller" {
    const program: Silex.Ir.Program = .{ .functions = &.{
        .{
            .name = "helper",
            .parameter_types = &.{.int},
            .return_type = .int,
            .value_types = &.{ .int, .int },
            .blocks = &.{.{
                .instructions = &.{.{ .copy = .{ .result = 1, .operand = 0 } }},
                .terminator = .{ .return_value = 1 },
            }},
        },
        .{
            .name = "main",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &.{ .int, .int },
            .blocks = &.{.{
                .instructions = &.{
                    .{ .constant_int = .{ .result = 0, .bits = 7 } },
                    .{ .call = .{ .result = 1, .function = 0, .arguments = &.{0} } },
                    .{ .print = .{ .value = 1, .newline = true } },
                },
                .terminator = .return_void,
            }},
        },
    } };
    const complete = profile(program);
    const reachable = try profileReachable(@import("std").testing.allocator, program);
    try @import("std").testing.expectEqual(@as(usize, 2), complete.counts.functions);
    try @import("std").testing.expectEqual(@as(usize, 2), reachable.counts.functions);
    try @import("std").testing.expectEqual(@as(usize, 1), reachable.internal_calls);

    const optimized: Silex.Ir.Program = .{ .functions = &.{
        program.functions[0],
        .{
            .name = "main",
            .parameter_types = &.{},
            .return_type = .void,
            .value_types = &.{.int},
            .blocks = &.{.{
                .instructions = &.{
                    .{ .constant_int = .{ .result = 0, .bits = 7 } },
                    .{ .print = .{ .value = 0, .newline = true } },
                },
                .terminator = .return_void,
            }},
        },
    } };
    const optimized_reachable = try profileReachable(@import("std").testing.allocator, optimized);
    try @import("std").testing.expectEqual(@as(usize, 1), optimized_reachable.counts.functions);
    try @import("std").testing.expectEqual(@as(usize, 0), optimized_reachable.internal_calls);
}
