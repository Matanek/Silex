const std = @import("std");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");
const Bounds = @import("Bounds.zig");
const DenseBlocks = @import("DenseBlocks.zig");
const InlineControlFlow = @import("InlineControlFlow.zig");
const InlineValues = @import("InlineValues.zig");
const ReferenceMemory = @import("ReferenceMemory.zig");
const SsaPromotion = @import("SsaPromotion.zig");
const ValueRanges = @import("ValueRanges.zig");
const Workers = @import("../Workers.zig");
const UnusedLocals = @import("UnusedLocals.zig");
const AggregateStores = @import("AggregateStores.zig");
const AggregateLoads = @import("AggregateLoads.zig");
const Verifier = @import("Verifier.zig");

const Allocator = std.mem.Allocator;

pub const PassId = enum {
    local_simplification_pre,
    ssa_promotion_pre,
    aggregate_argument_borrow,
    aggregate_scalarization_pre,
    scalar_math_intrinsics,
    value_inlining,
    control_flow_inlining,
    aggregate_scalarization_post,
    local_simplification_post,
    reference_memory_elision,
    ssa_promotion_post,
    value_range_analysis,
    ssa_value_simplification,

    pub fn parse(name: []const u8) ?PassId {
        inline for (@typeInfo(PassId).@"enum".fields) |field| {
            if (std.mem.eql(u8, name, field.name)) return @enumFromInt(field.value);
        }
        return null;
    }
};

pub const PassDescriptor = struct {
    id: PassId,
    precondition: []const u8,
    postcondition: []const u8,
    preserves: []const u8,
};

pub const pass_descriptors = [_]PassDescriptor{
    .{ .id = .local_simplification_pre, .precondition = "typed closed portable IR", .postcondition = "per-function constants, dense blocks, checks and dead values simplified", .preserves = "types, effects, ownership, diagnostics and control targets" },
    .{ .id = .ssa_promotion_pre, .precondition = "simplified typed portable IR", .postcondition = "profitable integer and boolean locals promoted with complete edge transfers", .preserves = "dominance, incoming values, types and observable storage" },
    .{ .id = .aggregate_argument_borrow, .precondition = "direct single-use aggregate arguments with stable addresses", .postcondition = "eligible aggregate values borrowed at their original checked load", .preserves = "bounds diagnostics, observation order, alias and value semantics" },
    .{ .id = .aggregate_scalarization_pre, .precondition = "typed aggregates before cloning", .postcondition = "eligible scalar fields exposed before inlining", .preserves = "field values, ownership, aliases and aggregate layout" },
    .{ .id = .scalar_math_intrinsics, .precondition = "exact STD.Math min or max scalar signature", .postcondition = "eligible calls represented by portable scalar operations", .preserves = "NaN, signed zero, infinity and provider identity rules" },
    .{ .id = .value_inlining, .precondition = "closed direct call graph", .postcondition = "bounded straight-line and constant-result callees specialized", .preserves = "call effects, argument order, return values and diagnostics" },
    .{ .id = .control_flow_inlining, .precondition = "closed direct call graph with typed CFG", .postcondition = "eligible branching and loop callees cloned into callers", .preserves = "CFG validity, returns, effects, ownership and diagnostics" },
    .{ .id = .aggregate_scalarization_post, .precondition = "combined caller and callee graphs", .postcondition = "newly exposed aggregate copies and snapshots simplified", .preserves = "field values, ownership, aliases and aggregate layout" },
    .{ .id = .local_simplification_post, .precondition = "inlined typed portable IR", .postcondition = "combined per-function constants, blocks, checks and dead values simplified", .preserves = "types, effects, ownership, diagnostics and control targets" },
    .{ .id = .reference_memory_elision, .precondition = "dead pure reads removed and explicit same-block reference, scalar-view or collection-lineage derivations available", .postcondition = "exact memory residues and proven collection-lineage reads or checks removed", .preserves = "possible alias observations, calls, block boundaries, ownership and unproved diagnostics" },
    .{ .id = .ssa_promotion_post, .precondition = "final simplified typed portable IR", .postcondition = "remaining profitable scalar locals promoted with complete edge transfers", .preserves = "dominance, incoming values, types and observable storage" },
    .{ .id = .value_range_analysis, .precondition = "verified typed CFG with final SSA edge definitions", .postcondition = "dominating integer intervals simplify proven comparisons, conversions and overflow checks", .preserves = "integer failures, signedness, widths, dominance, effects and control targets" },
    .{ .id = .ssa_value_simplification, .precondition = "verified SSA edge definitions and typed control flow", .postcondition = "inter-block copies, constants, branches and unreachable blocks simplified to a fixed point", .preserves = "dominance, overflow and floating-point semantics, effects and diagnostics" },
};

pub const Options = struct {
    worker_count: u16 = 1,
    verify_each_pass: bool = false,
    stop_after: ?PassId = null,
    disabled: ?PassId = null,
};

const Constant = union(enum) {
    unknown,
    integer: u64,
    boolean: bool,
    float32: u32,
    float64: u64,
};

const GlobalSummary = union(enum) {
    none,
    identity: usize,
    binary: BinarySummary,
    integer: u64,
    boolean: bool,
    string: []const u8,
    float32: u32,
    float64: u64,
};

const BinarySummary = struct {
    operator: Ir.BinaryOperator,
    left_parameter: usize,
    right_parameter: usize,
};

pub fn optimize(allocator: Allocator, program: Ir.Program) !Ir.Program {
    return optimizeWithOptions(allocator, program, .{});
}

pub fn optimizeWithWorkers(allocator: Allocator, program: Ir.Program, worker_count: u16) !Ir.Program {
    return optimizeWithOptions(allocator, program, .{ .worker_count = worker_count });
}

/// Oracle-only controls make pass attribution and prefix bisection
/// reproducible without exposing optimizer switches through the Silex CLI.
pub fn optimizeWithOptions(allocator: Allocator, program: Ir.Program, options: Options) !Ir.Program {
    var current = program;
    if (options.verify_each_pass) try Verifier.verify(allocator, current);

    if (options.disabled != .local_simplification_pre) {
        current = try optimizeFunctionsWithWorkers(allocator, current, options.worker_count);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .local_simplification_pre) return current;

    if (options.disabled != .ssa_promotion_pre) {
        current = try SsaPromotion.optimizeIntegerAndBooleanLocals(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .ssa_promotion_pre) return current;

    if (options.disabled != .aggregate_argument_borrow) {
        current = try borrowDirectAggregateArguments(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .aggregate_argument_borrow) return current;

    // Simplify constructors before cloning them into branching callers:
    // otherwise each field assignment carries its whole aggregate along.
    if (options.disabled != .aggregate_scalarization_pre) {
        current = try replaceScalarAggregatesWithWorkers(allocator, current, options.worker_count);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .aggregate_scalarization_pre) return current;

    if (options.disabled != .scalar_math_intrinsics) {
        current = try replaceScalarMathCalls(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .scalar_math_intrinsics) return current;

    if (options.disabled != .value_inlining) {
        current = try InlineValues.optimize(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .value_inlining) return current;

    if (options.disabled != .control_flow_inlining) {
        current = try InlineControlFlow.optimize(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .control_flow_inlining) return current;

    if (options.disabled != .aggregate_scalarization_post) {
        current = try replaceScalarAggregatesWithWorkers(allocator, current, options.worker_count);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .aggregate_scalarization_post) return current;

    if (options.disabled != .local_simplification_post) {
        current = try optimizeFunctionsWithWorkers(allocator, current, options.worker_count);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .local_simplification_post) return current;

    if (options.disabled != .reference_memory_elision) {
        current = try ReferenceMemory.optimize(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .reference_memory_elision) return current;

    if (options.disabled != .ssa_promotion_post) {
        current = try SsaPromotion.optimize(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .ssa_promotion_post) return current;

    if (options.disabled != .value_range_analysis) {
        current = try ValueRanges.optimize(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    if (options.stop_after == .value_range_analysis) return current;

    if (options.disabled != .ssa_value_simplification) {
        current = try simplifySsaValues(allocator, current);
        try verifyAfterPass(allocator, current, options);
    }
    const validated = try Ir.writeText(allocator, current);
    allocator.free(validated);
    return current;
}

fn verifyAfterPass(allocator: Allocator, program: Ir.Program, options: Options) !void {
    if (options.verify_each_pass) try Verifier.verify(allocator, program);
}

// Direct calls may borrow a checked collection element when the callee only
// projects fields from that aggregate parameter. The checked load and the
// call are kept at the same program point, with no intervening mutation, so
// value semantics and diagnostics are unchanged while the caller and callee
// avoid two full aggregate copies.
fn borrowDirectAggregateArguments(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const eligible = try allocator.alloc([]?usize, program.functions.len);
    const call_counts = try allocator.alloc([]usize, program.functions.len);
    for (program.functions, 0..) |function, function_index| {
        eligible[function_index] = try allocator.alloc(?usize, function.parameter_types.len);
        @memset(eligible[function_index], null);
        call_counts[function_index] = try allocator.alloc(usize, function.parameter_types.len);
        @memset(call_counts[function_index], 0);
        if (function.capture_types.len != 0 or !referencesStableAcrossBlocks(function)) continue;
        const uses = try allocator.alloc(usize, function.value_types.len);
        @memset(uses, 0);
        for (function.blocks) |block| {
            for (block.instructions) |instruction| countUses(instruction, uses);
            countTerminatorUses(block.terminator, uses);
        }
        const projections = try allocator.alloc(usize, function.parameter_types.len);
        @memset(projections, 0);
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .field_load => |load| if (load.base < function.parameter_types.len) {
                projections[load.base] += 1;
            },
            else => {},
        };
        for (function.parameter_types, 0..) |parameter_type, parameter| {
            const structure_index = parameter_type.structureIndex() orelse continue;
            if (!flatScalarStructure(program, structure_index)) continue;
            if (projections[parameter] != 0 and uses[parameter] == projections[parameter]) {
                eligible[function_index][parameter] = structure_index;
            }
        }
    }

    for (program.functions) |caller| for (caller.blocks, 0..) |block, block_index| for (block.instructions, 0..) |instruction, instruction_index| switch (instruction) {
        .function_reference => |reference| if (reference.function < eligible.len) {
            @memset(eligible[reference.function], null);
        },
        .call => |call| if (call.function < eligible.len) {
            for (eligible[call.function], 0..) |structure, parameter| if (structure != null) {
                if (parameter >= call.arguments.len or !directAggregateLoadAtCall(
                    allocator,
                    caller,
                    call.arguments[parameter],
                    block_index,
                    instruction_index,
                )) {
                    eligible[call.function][parameter] = null;
                } else call_counts[call.function][parameter] += 1;
            };
        },
        else => {},
    };
    for (eligible, 0..) |parameters, function_index| for (parameters, 0..) |*structure, parameter| {
        if (call_counts[function_index][parameter] == 0) structure.* = null;
    };

    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, function_index| {
        var value_types: std.ArrayList(Ir.Type) = .empty;
        try value_types.appendSlice(allocator, function.value_types);
        const parameter_types = try allocator.dupe(Ir.Type, function.parameter_types);
        for (eligible[function_index], 0..) |structure, parameter| if (structure != null) {
            parameter_types[parameter] = .address;
            value_types.items[parameter] = .address;
        };
        const borrowed_values = try allocator.alloc(bool, function.value_types.len);
        @memset(borrowed_values, false);
        for (function.blocks) |block| for (block.instructions) |instruction| if (instruction == .call) {
            const call = instruction.call;
            if (call.function >= eligible.len) continue;
            for (eligible[call.function], 0..) |structure, parameter| if (structure != null and parameter < call.arguments.len) {
                borrowed_values[call.arguments[parameter]] = true;
                value_types.items[call.arguments[parameter]] = .address;
            };
        };
        const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
        for (function.blocks, 0..) |block, block_index| {
            var instructions: std.ArrayList(Ir.Instruction) = .empty;
            for (block.instructions) |instruction| switch (instruction) {
                .collection_load => |load| if (borrowed_values[load.result]) {
                    try instructions.append(allocator, .{ .collection_reference = .{
                        .result = load.result,
                        .collection = load.collection,
                        .reference = null,
                        .index = load.index,
                        .checked = load.checked,
                        .position = load.position,
                    } });
                } else try instructions.append(allocator, instruction),
                .field_load => |load| if (load.base < eligible[function_index].len and eligible[function_index][load.base] != null) {
                    const reference = value_types.items.len;
                    try value_types.append(allocator, .address);
                    try instructions.append(allocator, .{ .reference_field = .{
                        .result = reference,
                        .reference = load.base,
                        .structure = eligible[function_index][load.base].?,
                        .field = load.field,
                    } });
                    try instructions.append(allocator, .{ .reference_load = .{
                        .result = load.result,
                        .reference = reference,
                    } });
                } else try instructions.append(allocator, instruction),
                else => try instructions.append(allocator, instruction),
            };
            blocks[block_index] = .{ .instructions = try instructions.toOwnedSlice(allocator), .terminator = block.terminator };
        }
        functions[function_index] = function;
        functions[function_index].parameter_types = parameter_types;
        functions[function_index].value_types = try value_types.toOwnedSlice(allocator);
        functions[function_index].blocks = blocks;
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn flatScalarStructure(program: Ir.Program, structure_index: usize) bool {
    if (structure_index >= program.structures.len) return false;
    if (isEnumerationStructure(program, structure_index)) return false;
    const structure = program.structures[structure_index];
    if (structure.is_class or structure.is_static or structure.is_protocol or structure.collection != null) return false;
    for (structure.fields) |field| if (!field.type.isNumeric() and field.type != .bool) return false;
    return true;
}

fn isEnumerationStructure(program: Ir.Program, structure_index: usize) bool {
    for (program.enums) |enumeration| {
        if (enumeration.type_index == structure_index) return true;
    }
    return false;
}

fn directAggregateLoadAtCall(
    allocator: Allocator,
    function: Ir.Function,
    argument: Ir.ValueId,
    call_block: usize,
    call_index: usize,
) bool {
    var definition_block: ?usize = null;
    var definition_index: ?usize = null;
    var definitions: usize = 0;
    const uses = allocator.alloc(usize, function.value_types.len) catch return false;
    defer allocator.free(uses);
    @memset(uses, 0);
    for (function.blocks, 0..) |block, block_index| {
        for (block.instructions, 0..) |instruction, instruction_index| {
            if (instructionResult(instruction)) |result| if (result == argument) {
                definitions += 1;
                if (instruction == .collection_load) {
                    definition_block = block_index;
                    definition_index = instruction_index;
                }
            };
            countUses(instruction, uses);
        }
        countTerminatorUses(block.terminator, uses);
    }
    if (definitions != 1 or uses[argument] != 1 or definition_block != call_block) return false;
    const start = definition_index orelse return false;
    if (start >= call_index) return false;
    return collectionAddressStable(function.blocks[call_block].instructions[start + 1 .. call_index]);
}

fn replaceScalarMathCalls(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, function_index| {
        const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
        for (function.blocks, 0..) |block, block_index| {
            const instructions = try allocator.alloc(Ir.Instruction, block.instructions.len);
            for (block.instructions, 0..) |instruction, instruction_index| {
                instructions[instruction_index] = scalarMathCall(program, function, instruction) orelse instruction;
            }
            blocks[block_index] = .{ .instructions = instructions, .terminator = block.terminator };
        }
        functions[function_index] = function;
        functions[function_index].blocks = blocks;
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn scalarMathCall(program: Ir.Program, caller: Ir.Function, instruction: Ir.Instruction) ?Ir.Instruction {
    const call = switch (instruction) {
        .call => |value| value,
        else => return null,
    };
    const result = call.result orelse return null;
    if (call.function >= program.functions.len or call.arguments.len != 2 or result >= caller.value_types.len) return null;
    const callee = program.functions[call.function];
    if (callee.parameter_types.len != 2 or callee.return_type != caller.value_types[result]) return null;
    const value_type = caller.value_types[result];
    if (value_type != .float32 and value_type != .float64) return null;
    if (callee.parameter_types[0] != value_type or callee.parameter_types[1] != value_type) return null;
    const operator: Ir.BinaryOperator = if (std.mem.eql(u8, callee.name, "STD.Math.min"))
        .minimum
    else if (std.mem.eql(u8, callee.name, "STD.Math.max"))
        .maximum
    else
        return null;
    return .{ .binary = .{
        .result = result,
        .operator = operator,
        .left = call.arguments[0],
        .right = call.arguments[1],
        .checked = false,
    } };
}

pub fn optimizeWithoutInlining(allocator: Allocator, program: Ir.Program) !Ir.Program {
    var result = try optimizeFunctionsWithWorkers(allocator, program, 1);
    result = try SsaPromotion.optimize(allocator, result);
    result = try ValueRanges.optimize(allocator, result);
    result = try simplifySsaValues(allocator, result);
    const validated = try Ir.writeText(allocator, result);
    allocator.free(validated);
    return result;
}

fn optimizeFunctionsWithWorkers(
    allocator: Allocator,
    program: Ir.Program,
    requested_worker_count: u16,
) !Ir.Program {
    const summaries = try allocator.alloc(GlobalSummary, program.functions.len);
    for (program.functions, 0..) |function, index| summaries[index] = summarize(function);
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    const worker_count = Workers.selectedCount(program.functions.len, requested_worker_count);
    if (worker_count == 1) {
        try optimizeFunctionRange(allocator, program, program.functions, functions, summaries, 0, program.functions.len);
    } else {
        var workers: [Workers.max_count]OptimizeWorker = undefined;
        const count: usize = worker_count;
        const chunk = std.math.divCeil(usize, program.functions.len, count) catch unreachable;
        for (workers[0..count], 0..) |*worker, index| worker.* = .{
            .allocator = allocator,
            .program = program,
            .source = program.functions,
            .destination = functions,
            .summaries = summaries,
            .start = index * chunk,
            .end = @min((index + 1) * chunk, program.functions.len),
        };
        Workers.run(OptimizeWorker, workers[0..count], OptimizeWorker.run);
        for (workers[0..count]) |worker| if (worker.failure) |err| return err;
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn optimizeFunctionRange(
    allocator: Allocator,
    program: Ir.Program,
    source: []const Ir.Function,
    destination: []Ir.Function,
    summaries: []const GlobalSummary,
    start: usize,
    end: usize,
) !void {
    for (start..end) |index| {
        const folded = try foldBlockConstants(allocator, source[index]);
        const localized = try optimizeDenseBlocks(allocator, program, folded);
        const optimized = try optimizeFunction(allocator, localized, summaries);
        const simplified = try simplifyBooleanDiamonds(allocator, optimized);
        const bounded = try Bounds.optimize(allocator, simplified);
        var cleaned = try removeRedundantCollectionChecks(allocator, bounded);
        cleaned.blocks = try removeDeadConstants(allocator, cleaned);
        destination[index] = cleaned;
    }
}

const OptimizeWorker = struct {
    allocator: Allocator,
    program: Ir.Program,
    source: []const Ir.Function,
    destination: []Ir.Function,
    summaries: []const GlobalSummary,
    start: usize,
    end: usize,
    failure: ?anyerror = null,

    fn run(self: *OptimizeWorker) void {
        optimizeFunctionRange(self.allocator, self.program, self.source, self.destination, self.summaries, self.start, self.end) catch |err| {
            self.failure = err;
        };
    }
};

fn simplifyBooleanDiamonds(allocator: Allocator, function: Ir.Function) !Ir.Function {
    if (function.blocks.len < 4) return function;
    const blocks = try allocator.dupe(Ir.Block, function.blocks);
    const uses = try allocator.alloc(usize, function.value_types.len);
    @memset(uses, 0);
    for (blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    var changed = false;
    for (blocks, 0..) |block, block_index| {
        const outer = switch (block.terminator) {
            .branch => |value| value,
            else => continue,
        };
        if (outer.then_block >= blocks.len or outer.else_block >= blocks.len) continue;
        const evaluation = blocks[outer.then_block];
        const short_circuit = blocks[outer.else_block];
        if (short_circuit.instructions.len != 1) continue;
        const false_value = switch (short_circuit.instructions[0]) {
            .constant_bool => |value| value,
            else => continue,
        };
        if (false_value.value) continue;
        const join_id = switch (short_circuit.terminator) {
            .jump => |target| target,
            else => continue,
        };
        if (join_id >= blocks.len or evaluation.instructions.len == 0) continue;
        if (evaluation.terminator != .jump or evaluation.terminator.jump != join_id) continue;
        const join = blocks[join_id];
        if (join.instructions.len != 0) continue;
        const final_branch = switch (join.terminator) {
            .branch => |value| value,
            else => continue,
        };
        if (final_branch.condition != false_value.result) continue;
        const copy = switch (evaluation.instructions[evaluation.instructions.len - 1]) {
            .copy => |value| value,
            else => continue,
        };
        if (copy.result != false_value.result) continue;
        if (uses[false_value.result] != 1) continue;

        blocks[block_index].terminator = .{ .branch = .{
            .condition = outer.condition,
            .then_block = outer.then_block,
            .else_block = final_branch.else_block,
        } };
        blocks[outer.then_block] = .{
            .instructions = evaluation.instructions[0 .. evaluation.instructions.len - 1],
            .terminator = .{ .branch = .{
                .condition = copy.operand,
                .then_block = final_branch.then_block,
                .else_block = final_branch.else_block,
            } },
        };
        changed = true;
    }
    if (!changed) return function;
    var result = function;
    result.blocks = try removeUnreachableBlocks(allocator, blocks);
    result.blocks = try removeDeadConstants(allocator, result);
    return result;
}

pub fn optimizeCached(allocator: Allocator, io: std.Io, program: Ir.Program) !Ir.Program {
    _ = io;
    return optimize(allocator, program);
}

pub fn optimizeCachedWithWorkers(allocator: Allocator, io: std.Io, program: Ir.Program, worker_count: u16) !Ir.Program {
    _ = io;
    return optimizeWithWorkers(allocator, program, worker_count);
}

fn replaceScalarAggregates(allocator: Allocator, program: Ir.Program) !Ir.Program {
    return replaceScalarAggregatesWithWorkers(allocator, program, 1);
}

fn replaceScalarAggregatesWithWorkers(allocator: Allocator, program: Ir.Program, requested_worker_count: u16) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    const worker_count = Workers.selectedCount(program.functions.len, requested_worker_count);
    if (worker_count == 1) {
        try replaceScalarAggregateRange(allocator, program, functions, 0, program.functions.len);
    } else {
        var workers: [Workers.max_count]ScalarWorker = undefined;
        const count: usize = worker_count;
        const chunk = std.math.divCeil(usize, program.functions.len, count) catch unreachable;
        for (workers[0..count], 0..) |*worker, index| worker.* = .{
            .allocator = allocator,
            .program = program,
            .destination = functions,
            .start = index * chunk,
            .end = @min((index + 1) * chunk, program.functions.len),
        };
        Workers.run(ScalarWorker, workers[0..count], ScalarWorker.run);
        for (workers[0..count]) |worker| if (worker.failure) |err| return err;
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn replaceScalarAggregateRange(allocator: Allocator, program: Ir.Program, destination: []Ir.Function, start: usize, end: usize) !void {
    for (start..end) |index| destination[index] = try replaceFunctionScalarAggregates(allocator, program, program.functions[index]);
}

const ScalarWorker = struct {
    allocator: Allocator,
    program: Ir.Program,
    destination: []Ir.Function,
    start: usize,
    end: usize,
    failure: ?anyerror = null,

    fn run(self: *ScalarWorker) void {
        replaceScalarAggregateRange(self.allocator, self.program, self.destination, self.start, self.end) catch |err| {
            self.failure = err;
        };
    }
};

fn replaceFunctionScalarAggregates(allocator: Allocator, program: Ir.Program, input: Ir.Function) !Ir.Function {
    const split_locals = try splitFlatAggregateLocals(allocator, program, input);
    const input_function = try AggregateStores.optimize(allocator, program, split_locals);
    const definitions = try allocator.alloc(usize, input_function.value_types.len);
    @memset(definitions, 0);
    for (0..input_function.capture_types.len + input_function.parameter_types.len) |parameter| definitions[parameter] = 1;
    for (input_function.blocks) |block| for (block.instructions) |instruction| countDefinitions(instruction, definitions);
    const eligible = try allocator.alloc(bool, input_function.local_types.len);
    defer allocator.free(eligible);
    for (input_function.local_types, 0..) |local_type, local| eligible[local] = if (local_type.structureIndex()) |structure|
        scalarStructure(program, structure, 0)
    else
        false;
    const forwarded = try UnusedLocals.forwardLoads(allocator, input_function, eligible, definitions);
    const pruned = try UnusedLocals.removeOverwrittenStores(allocator, forwarded, eligible);
    const function = try UnusedLocals.removeStores(allocator, pruned);
    const roots = try allocator.alloc(?Ir.ValueId, function.value_types.len);
    @memset(roots, null);
    const fields = try allocator.alloc(?[]const Ir.ValueId, function.value_types.len);
    @memset(fields, null);
    // Lowered joins can define the same value on several predecessor edges.
    // Only immutable, single-definition values may become global aliases.
    for (function.blocks) |block| {
        for (block.instructions) |instruction| switch (instruction) {
            .structure_init => |value| if (definitions[value.result] == 1 and scalarStructure(program, value.structure, 0)) {
                roots[value.result] = value.result;
                fields[value.result] = value.fields;
            },
            else => {},
        };
    }
    var changed = true;
    while (changed) {
        changed = false;
        for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
            .copy => |value| if (definitions[value.result] == 1 and roots[value.result] == null and roots[value.operand] != null and
                function.value_types[value.result] == function.value_types[value.operand])
            {
                roots[value.result] = roots[value.operand];
                changed = true;
            },
            .field_load => |value| if (definitions[value.result] == 1 and roots[value.result] == null) {
                const parent = roots[value.base] orelse continue;
                const parent_fields = fields[parent] orelse continue;
                if (value.field >= parent_fields.len) return error.InvalidProgram;
                const projected = parent_fields[value.field];
                if (roots[projected]) |child| {
                    if (function.value_types[value.result] == function.value_types[projected]) {
                        roots[value.result] = child;
                        changed = true;
                    }
                }
            },
            else => {},
        };
    }

    const uses = try allocator.alloc(usize, function.value_types.len);
    @memset(uses, 0);
    for (function.blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    const allowed = try allocator.alloc(usize, function.value_types.len);
    @memset(allowed, 0);
    const AggregateDependency = struct { child: Ir.ValueId, parent: Ir.ValueId };
    var aggregate_dependencies: std.ArrayList(AggregateDependency) = .empty;
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .copy => |value| if (roots[value.operand] != null and roots[value.result] == roots[value.operand]) {
            allowed[value.operand] += 1;
        },
        .field_load => |value| if (roots[value.base] != null and definitions[value.result] == 1) {
            allowed[value.base] += 1;
        },
        .structure_init => |value| if (roots[value.result]) |parent| {
            for (value.fields) |field| if (roots[field]) |child| {
                allowed[field] += 1;
                try aggregate_dependencies.append(allocator, .{ .child = child, .parent = parent });
            };
        },
        else => {},
    };
    const escaped = try allocator.alloc(bool, function.value_types.len);
    @memset(escaped, false);
    for (roots, 0..) |root, value| if (root) |resolved| {
        if (uses[value] != allowed[value]) escaped[resolved] = true;
    };
    for (fields, 0..) |aggregate, root| if (aggregate) |values| {
        for (values) |value| if (definitions[value] != 1) {
            escaped[root] = true;
        };
    };
    changed = true;
    while (changed) {
        changed = false;
        for (aggregate_dependencies.items) |dependency| {
            if (escaped[dependency.parent] and !escaped[dependency.child]) {
                escaped[dependency.child] = true;
                changed = true;
            }
        }
    }

    const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
    for (aliases, 0..) |*alias, value| alias.* = value;
    // Compute all projections before rewriting any block: block order need
    // not be dominance order, and a projection can feed a later aggregate.
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .copy => |value| if (roots[value.operand]) |root| {
            if (!escaped[root] and roots[value.result] == root) aliases[value.result] = value.operand;
        },
        .field_load => |value| if (roots[value.base]) |root| {
            if (!escaped[root] and definitions[value.result] == 1) {
                const aggregate_fields = fields[root] orelse return error.InvalidProgram;
                if (value.field >= aggregate_fields.len) return error.InvalidProgram;
                aliases[value.result] = aggregate_fields[value.field];
            }
        },
        else => {},
    };

    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    const constants = try allocator.alloc(Constant, function.value_types.len);
    @memset(constants, .unknown);
    for (function.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            switch (original) {
                .copy => |value| if (aliases[value.result] != value.result) {
                    continue;
                },
                .field_load => |value| if (aliases[value.result] != value.result) {
                    continue;
                },
                else => {},
            }
            const instruction = try rewriteInstruction(allocator, original, aliases);
            switch (instruction) {
                .structure_init => |value| if (roots[value.result]) |root| {
                    if (!escaped[root]) continue;
                },
                else => {},
            }
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = rewriteTerminator(block.terminator, aliases, constants),
        };
    }
    var result = function;
    result.blocks = blocks;
    @memset(uses, 0);
    for (blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    return AggregateLoads.optimize(allocator, program, result, definitions, uses);
}

// Mutable value-structure fields are represented by functional aggregate
// reconstruction in portable IR. Split an unaddressed flat scalar local into
// scalar field locals before alias propagation. A reconstructed store then
// writes only the fields that differ from the current local snapshot, while a
// load materializes the aggregate at the original observation point.
fn splitFlatAggregateLocals(allocator: Allocator, program: Ir.Program, function: Ir.Function) !Ir.Function {
    if (function.local_types.len == 0) return function;
    const structures = try allocator.alloc(?usize, function.local_types.len);
    @memset(structures, null);
    for (function.local_types, 0..) |local_type, local| {
        const structure_index = local_type.structureIndex() orelse continue;
        if (structure_index >= program.structures.len) continue;
        if (isEnumerationStructure(program, structure_index)) continue;
        const structure = program.structures[structure_index];
        if (structure.is_class or structure.is_static or structure.is_protocol or structure.collection != null) continue;
        for (structure.fields) |field| {
            if (!field.type.isNumeric() and field.type != .bool) break;
        } else structures[local] = structure_index;
    }
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .local_address => |address| structures[address.local] = null,
        else => {},
    };
    var any = false;
    for (structures) |structure| if (structure != null) {
        any = true;
        break;
    };
    if (!any) return function;

    const local_remap = try allocator.alloc(?Ir.LocalId, function.local_types.len);
    const field_locals = try allocator.alloc(?[]const Ir.LocalId, function.local_types.len);
    @memset(field_locals, null);
    var local_types: std.ArrayList(Ir.Type) = .empty;
    for (function.local_types, 0..) |local_type, local| if (structures[local]) |structure_index| {
        local_remap[local] = null;
        const structure = program.structures[structure_index];
        const fields = try allocator.alloc(Ir.LocalId, structure.fields.len);
        for (structure.fields, 0..) |field, field_index| {
            fields[field_index] = local_types.items.len;
            try local_types.append(allocator, field.type);
        }
        field_locals[local] = fields;
    } else {
        local_remap[local] = local_types.items.len;
        try local_types.append(allocator, local_type);
    };

    var value_types: std.ArrayList(Ir.Type) = .empty;
    try value_types.appendSlice(allocator, function.value_types);
    var maximum_value_count = function.value_types.len;
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .local_load => |load| if (structures[load.local]) |structure_index| {
            maximum_value_count += program.structures[structure_index].fields.len;
        },
        .local_store => |store| if (structures[store.local]) |structure_index| {
            maximum_value_count += program.structures[structure_index].fields.len;
        },
        else => {},
    };
    const definitions = try allocator.alloc(?Ir.Instruction, maximum_value_count);
    const loaded_local = try allocator.alloc(?Ir.LocalId, maximum_value_count);
    const loaded_epoch = try allocator.alloc(usize, maximum_value_count);
    const local_epochs = try allocator.alloc(usize, function.local_types.len);
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        @memset(definitions, null);
        @memset(loaded_local, null);
        @memset(loaded_epoch, 0);
        @memset(local_epochs, 0);
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            switch (original) {
                .local_load => |load| if (structures[load.local]) |structure_index| {
                    const structure = program.structures[structure_index];
                    const values = try allocator.alloc(Ir.ValueId, structure.fields.len);
                    for (structure.fields, 0..) |field, field_index| {
                        values[field_index] = value_types.items.len;
                        try value_types.append(allocator, field.type);
                        try instructions.append(allocator, .{ .local_load = .{
                            .result = values[field_index],
                            .local = field_locals[load.local].?[field_index],
                        } });
                    }
                    const initialization: Ir.Instruction = .{ .structure_init = .{
                        .result = load.result,
                        .structure = structure_index,
                        .fields = values,
                    } };
                    try instructions.append(allocator, initialization);
                    definitions[load.result] = initialization;
                    loaded_local[load.result] = load.local;
                    loaded_epoch[load.result] = local_epochs[load.local];
                    continue;
                } else {
                    const rewritten: Ir.Instruction = .{ .local_load = .{
                        .result = load.result,
                        .local = local_remap[load.local].?,
                    } };
                    try instructions.append(allocator, rewritten);
                    definitions[load.result] = rewritten;
                    continue;
                },
                .local_store => |store| if (structures[store.local]) |structure_index| {
                    const structure = program.structures[structure_index];
                    const initialization = if (definitions[store.operand]) |definition|
                        if (definition == .structure_init and definition.structure_init.structure == structure_index)
                            definition.structure_init
                        else
                            null
                    else
                        null;
                    if (initialization) |value| {
                        for (value.fields, 0..) |field, field_index| {
                            if (unchangedLocalField(
                                definitions,
                                loaded_local,
                                loaded_epoch,
                                field,
                                store.local,
                                local_epochs[store.local],
                                field_index,
                            )) continue;
                            try instructions.append(allocator, .{ .local_store = .{
                                .local = field_locals[store.local].?[field_index],
                                .operand = field,
                            } });
                        }
                    } else {
                        for (structure.fields, 0..) |field, field_index| {
                            const extracted = value_types.items.len;
                            try value_types.append(allocator, field.type);
                            const load: Ir.Instruction = .{ .field_load = .{
                                .result = extracted,
                                .base = store.operand,
                                .field = field_index,
                            } };
                            try instructions.append(allocator, load);
                            definitions[extracted] = load;
                            try instructions.append(allocator, .{ .local_store = .{
                                .local = field_locals[store.local].?[field_index],
                                .operand = extracted,
                            } });
                        }
                    }
                    local_epochs[store.local] += 1;
                    continue;
                } else {
                    try instructions.append(allocator, .{ .local_store = .{
                        .local = local_remap[store.local].?,
                        .operand = store.operand,
                    } });
                    continue;
                },
                .local_address => |address| {
                    try instructions.append(allocator, .{ .local_address = .{
                        .result = address.result,
                        .local = local_remap[address.local].?,
                    } });
                    definitions[address.result] = instructions.items[instructions.items.len - 1];
                    continue;
                },
                else => {},
            }
            try instructions.append(allocator, original);
            if (instructionResult(original)) |result| definitions[result] = original;
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    var result = function;
    result.value_types = try value_types.toOwnedSlice(allocator);
    result.local_types = try local_types.toOwnedSlice(allocator);
    result.blocks = blocks;
    return result;
}

fn unchangedLocalField(
    definitions: []const ?Ir.Instruction,
    loaded_local: []const ?Ir.LocalId,
    loaded_epoch: []const usize,
    value: Ir.ValueId,
    local: Ir.LocalId,
    epoch: usize,
    field_index: usize,
) bool {
    const definition = definitions[value] orelse return false;
    if (definition != .field_load or definition.field_load.field != field_index) return false;
    const base = definition.field_load.base;
    return loaded_local[base] == local and loaded_epoch[base] == epoch;
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

fn scalarStructure(program: Ir.Program, structure_index: usize, depth: usize) bool {
    if (depth > 8 or structure_index >= program.structures.len) return false;
    const structure = program.structures[structure_index];
    if (structure.is_class or structure.is_static or structure.collection != null) return false;
    for (structure.fields) |field| {
        if (field.type.isNumeric() or field.type == .bool) continue;
        const child = field.type.structureIndex() orelse return false;
        if (!scalarStructure(program, child, depth + 1)) return false;
    }
    return true;
}

fn foldBlockConstants(allocator: Allocator, function: Ir.Function) !Ir.Function {
    const constants = try allocator.alloc(Constant, function.value_types.len);
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        @memset(constants, .unknown);
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            const instruction = foldInstruction(function, original, constants);
            recordConstant(instruction, constants);
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    var result = function;
    result.blocks = blocks;
    return result;
}

fn optimizeFunction(allocator: Allocator, function: Ir.Function, summaries: []const GlobalSummary) !Ir.Function {
    // Global alias and local-value propagation stays restricted to a single
    // block until the optimizer models dominance and control-flow joins.
    if (function.blocks.len != 1) return function;

    const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
    for (aliases, 0..) |*alias, index| alias.* = index;
    const constants = try allocator.alloc(Constant, function.value_types.len);
    @memset(constants, .unknown);

    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        const local_values = try allocator.alloc(?Ir.ValueId, function.local_types.len);
        @memset(local_values, null);
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            var instruction = try rewriteInstruction(allocator, original, aliases);
            if (instruction == .call) instruction = inlineConstantCall(instruction.call, summaries) orelse instruction;
            switch (instruction) {
                .copy => |copy| {
                    if (function.value_types[copy.result] == function.value_types[copy.operand]) {
                        aliases[copy.result] = canonical(aliases, copy.operand);
                        continue;
                    }
                },
                .deep_copy => |copy| {
                    const value_type = function.value_types[copy.result];
                    if ((value_type.isNumeric() or value_type == .bool) and
                        value_type == function.value_types[copy.operand])
                    {
                        aliases[copy.result] = canonical(aliases, copy.operand);
                        continue;
                    }
                },
                .local_load => |load| if (local_values[load.local]) |stored| {
                    aliases[load.result] = canonical(aliases, stored);
                    continue;
                },
                .local_store => |store| local_values[store.local] = canonical(aliases, store.operand),
                .reference_store, .call, .indirect_call, .dynamic_call => @memset(local_values, null),
                else => {},
            }
            instruction = foldInstruction(function, instruction, constants);
            recordConstant(instruction, constants);
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = rewriteTerminator(block.terminator, aliases, constants),
        };
    }

    var result = function;
    result.blocks = try removeUnreachableBlocks(allocator, blocks);
    result.blocks = try removeDeadConstants(allocator, result);
    return result;
}

/// Propagates facts exposed by SSA promotion across basic-block boundaries.
/// Values produced on several predecessor edges are treated as phi values: a
/// fact is usable only when every reachable definition proves the exact same
/// bit pattern. This keeps the analysis independent from block serialization
/// order and makes branch pruning feed another analysis iteration.
fn simplifySsaValues(allocator: Allocator, program: Ir.Program) !Ir.Program {
    const functions = try allocator.alloc(Ir.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        functions[index] = try simplifySsaFunction(allocator, function);
    }
    var result = program;
    result.functions = functions;
    return result;
}

fn simplifySsaFunction(allocator: Allocator, original: Ir.Function) !Ir.Function {
    var current = original;
    var iteration: usize = 0;
    while (iteration <= original.blocks.len) : (iteration += 1) {
        const previous_blocks = current.blocks.len;
        const previous_instructions = instructionCount(current.blocks);
        const next = try simplifySsaFunctionOnce(allocator, current);
        const changed = next.blocks.len != previous_blocks or
            instructionCount(next.blocks) != previous_instructions or
            !terminatorsEqual(current.blocks, next.blocks);
        current = next;
        if (!changed) break;
    }
    return current;
}

fn simplifySsaFunctionOnce(allocator: Allocator, function: Ir.Function) !Ir.Function {
    if (function.blocks.len == 0 or function.value_types.len == 0) return function;

    const definitions = try allocator.alloc(usize, function.value_types.len);
    @memset(definitions, 0);
    for (function.blocks) |block| for (block.instructions) |instruction| {
        countDefinitions(instruction, definitions);
    };

    const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
    for (aliases, 0..) |*alias, value| alias.* = value;
    var aliases_changed = true;
    while (aliases_changed) {
        aliases_changed = false;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            const copy = switch (instruction) {
                .copy => |value| value,
                .deep_copy => |value| value,
                else => continue,
            };
            if (definitions[copy.result] != 1 or
                function.value_types[copy.result] != function.value_types[copy.operand]) continue;
            const value_type = function.value_types[copy.result];
            // Dynamic floating copies still carry lane provenance consumed by
            // the SLP planner. Constant facts may cross them, but removing the
            // copies here would shrink already-qualified vector groups.
            if (!value_type.isInteger() and value_type != .bool) continue;
            const source = canonical(aliases, copy.operand);
            if (aliases[copy.result] != source) {
                aliases[copy.result] = source;
                aliases_changed = true;
            }
        };
    }

    const facts = try allocator.alloc(Constant, function.value_types.len);
    @memset(facts, .unknown);
    var facts_changed = true;
    while (facts_changed) {
        facts_changed = false;
        const candidates = try allocator.alloc(Constant, function.value_types.len);
        const seen = try allocator.alloc(usize, function.value_types.len);
        const compatible = try allocator.alloc(bool, function.value_types.len);
        @memset(candidates, .unknown);
        @memset(seen, 0);
        @memset(compatible, true);
        for (function.blocks) |block| for (block.instructions) |instruction| {
            const result = instructionResult(instruction) orelse continue;
            seen[result] += 1;
            const fact = definitionConstant(function, instruction, aliases, facts) orelse {
                compatible[result] = false;
                continue;
            };
            if (candidates[result] == .unknown) {
                candidates[result] = fact;
            } else if (!constantEqual(candidates[result], fact)) {
                compatible[result] = false;
            }
        };
        for (facts, 0..) |*fact, value| {
            if (fact.* != .unknown or !compatible[value] or seen[value] != definitions[value] or seen[value] == 0) continue;
            if (candidates[value] == .unknown) continue;
            fact.* = candidates[value];
            facts_changed = true;
        }
    }

    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            if (instructionResult(original)) |result| {
                if (aliases[result] != result) continue;
            }
            var instruction = try rewriteInstruction(allocator, original, aliases);
            if (instructionResult(instruction)) |result| {
                if (constantInstruction(result, facts[result])) |constant| instruction = constant;
            }
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = rewriteTerminator(block.terminator, aliases, facts),
        };
    }

    var result = function;
    result.blocks = try removeUnreachableBlocks(allocator, blocks);
    result.blocks = try removeDeadConstants(allocator, result);
    result.blocks = try bypassEmptyJumps(allocator, result.blocks);
    result.blocks = try removeUnreachableBlocks(allocator, result.blocks);
    result.blocks = try mergeLinearBlocks(allocator, result.blocks);
    return result;
}

fn definitionConstant(
    function: Ir.Function,
    instruction: Ir.Instruction,
    aliases: []const Ir.ValueId,
    facts: []const Constant,
) ?Constant {
    return switch (instruction) {
        .constant_int => |value| .{ .integer = value.bits },
        .constant_bool => |value| .{ .boolean = value.value },
        .constant_float32 => |value| .{ .float32 = value.bits },
        .constant_float64 => |value| .{ .float64 = value.bits },
        .copy, .deep_copy => |value| copy: {
            if (function.value_types[value.result] != function.value_types[value.operand]) break :copy null;
            const value_type = function.value_types[value.result];
            if (instruction == .deep_copy and !value_type.isNumeric() and value_type != .bool) break :copy null;
            const fact = facts[canonical(aliases, value.operand)];
            break :copy if (fact == .unknown) null else fact;
        },
        .unary => |value| unary: {
            var rewritten = value;
            rewritten.operand = canonical(aliases, value.operand);
            const folded = foldUnary(function, rewritten, facts) orelse break :unary null;
            break :unary instructionConstant(folded);
        },
        .binary => |value| binary: {
            var rewritten = value;
            rewritten.left = canonical(aliases, value.left);
            rewritten.right = canonical(aliases, value.right);
            const folded = foldBinary(function, rewritten, facts) orelse break :binary null;
            break :binary instructionConstant(folded);
        },
        .convert => |value| conversion: {
            var rewritten = value;
            rewritten.operand = canonical(aliases, value.operand);
            const folded = foldConvert(rewritten, facts) orelse break :conversion null;
            break :conversion instructionConstant(folded);
        },
        else => null,
    };
}

fn instructionConstant(instruction: Ir.Instruction) ?Constant {
    return switch (instruction) {
        .constant_int => |value| .{ .integer = value.bits },
        .constant_bool => |value| .{ .boolean = value.value },
        .constant_float32 => |value| .{ .float32 = value.bits },
        .constant_float64 => |value| .{ .float64 = value.bits },
        else => null,
    };
}

fn constantInstruction(result: Ir.ValueId, fact: Constant) ?Ir.Instruction {
    return switch (fact) {
        .unknown => null,
        .integer => |bits| .{ .constant_int = .{ .result = result, .bits = bits } },
        .boolean => |value| .{ .constant_bool = .{ .result = result, .value = value } },
        .float32 => |bits| .{ .constant_float32 = .{ .result = result, .bits = bits } },
        .float64 => |bits| .{ .constant_float64 = .{ .result = result, .bits = bits } },
    };
}

fn constantEqual(left: Constant, right: Constant) bool {
    return std.meta.eql(left, right);
}

fn bypassEmptyJumps(allocator: Allocator, blocks: []const Ir.Block) ![]const Ir.Block {
    const result = try allocator.dupe(Ir.Block, blocks);
    for (result) |*block| block.terminator = switch (block.terminator) {
        .jump => |target| .{ .jump = resolveEmptyJump(blocks, target) },
        .branch => |branch| .{ .branch = .{
            .condition = branch.condition,
            .then_block = resolveEmptyJump(blocks, branch.then_block),
            .else_block = resolveEmptyJump(blocks, branch.else_block),
        } },
        else => block.terminator,
    };
    return result;
}

fn mergeLinearBlocks(allocator: Allocator, initial: []const Ir.Block) ![]const Ir.Block {
    var current = initial;
    while (current.len > 1) {
        const predecessors = try allocator.alloc(usize, current.len);
        @memset(predecessors, 0);
        for (current) |block| switch (block.terminator) {
            .jump => |target| predecessors[target] += 1,
            .branch => |branch| {
                predecessors[branch.then_block] += 1;
                if (branch.else_block != branch.then_block) predecessors[branch.else_block] += 1;
            },
            else => {},
        };

        var source_id: ?Ir.BlockId = null;
        var target_id: Ir.BlockId = undefined;
        for (current, 0..) |block, block_id| {
            const target = switch (block.terminator) {
                .jump => |value| value,
                else => continue,
            };
            if (target == block_id or target == 0 or predecessors[target] != 1) continue;
            if (terminatorTargets(current[target].terminator, block_id)) continue;
            if (definitionsOverlap(block.instructions, current[target].instructions)) continue;
            source_id = block_id;
            target_id = target;
            break;
        }
        const source = source_id orelse return current;

        const remap = try allocator.alloc(Ir.BlockId, current.len);
        var next_id: Ir.BlockId = 0;
        for (0..current.len) |old| {
            if (old == target_id) continue;
            remap[old] = next_id;
            next_id += 1;
        }
        remap[target_id] = remap[source];

        const merged = try allocator.alloc(Ir.Block, current.len - 1);
        var next: usize = 0;
        for (current, 0..) |block, old| {
            if (old == target_id) continue;
            if (old == source) {
                var instructions: std.ArrayList(Ir.Instruction) = .empty;
                try instructions.appendSlice(allocator, block.instructions);
                try instructions.appendSlice(allocator, current[target_id].instructions);
                merged[next] = .{
                    .instructions = try instructions.toOwnedSlice(allocator),
                    .terminator = remapTerminator(current[target_id].terminator, remap),
                };
            } else {
                merged[next] = .{
                    .instructions = block.instructions,
                    .terminator = remapTerminator(block.terminator, remap),
                };
            }
            next += 1;
        }
        current = merged;
    }
    return current;
}

fn terminatorTargets(terminator: Ir.Terminator, target: Ir.BlockId) bool {
    return switch (terminator) {
        .jump => |destination| destination == target,
        .branch => |branch| branch.then_block == target or branch.else_block == target,
        else => false,
    };
}

fn definitionsOverlap(left: []const Ir.Instruction, right: []const Ir.Instruction) bool {
    for (left) |left_instruction| {
        const left_result = instructionResult(left_instruction) orelse continue;
        for (right) |right_instruction| {
            const right_result = instructionResult(right_instruction) orelse continue;
            if (left_result == right_result) return true;
        }
    }
    return false;
}

fn resolveEmptyJump(blocks: []const Ir.Block, initial: Ir.BlockId) Ir.BlockId {
    var current = initial;
    var traversed: usize = 0;
    while (current < blocks.len and blocks[current].instructions.len == 0 and traversed < blocks.len) : (traversed += 1) {
        current = switch (blocks[current].terminator) {
            .jump => |target| target,
            else => break,
        };
        if (current == initial) return initial;
    }
    return current;
}

fn instructionCount(blocks: []const Ir.Block) usize {
    var count: usize = 0;
    for (blocks) |block| count += block.instructions.len;
    return count;
}

fn terminatorsEqual(left: []const Ir.Block, right: []const Ir.Block) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_block, right_block| {
        if (!std.meta.eql(left_block.terminator, right_block.terminator)) return false;
    }
    return true;
}

fn optimizeDenseBlocks(allocator: Allocator, program: Ir.Program, function: Ir.Function) !Ir.Function {
    if (!DenseBlocks.isEligible(function)) return function;
    const locals_cannot_alias = !hasLocalAddress(function);
    const references_stable_across_blocks = referencesStableAcrossBlocks(function);
    const definitions = try allocator.alloc(usize, function.value_types.len);
    @memset(definitions, 0);
    for (function.blocks) |block| for (block.instructions) |instruction| countDefinitions(instruction, definitions);
    const uses = try allocator.alloc(usize, function.value_types.len);
    @memset(uses, 0);
    for (function.blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    const constants = try allocator.alloc(Constant, function.value_types.len);
    @memset(constants, .unknown);
    var entry_references: std.ArrayList(Ir.Instruction.CollectionReference) = .empty;
    const stable_local_origins = try stableLocalOrigins(
        allocator,
        program,
        function,
        definitions,
        references_stable_across_blocks and locals_cannot_alias,
    );
    for (function.blocks, 0..) |block, block_index| {
        const block_uses = try allocator.alloc(usize, function.value_types.len);
        @memset(block_uses, 0);
        for (block.instructions) |instruction| countUses(instruction, block_uses);
        countTerminatorUses(block.terminator, block_uses);
        const aliases = try allocator.alloc(Ir.ValueId, function.value_types.len);
        for (aliases, 0..) |*alias, value| alias.* = value;
        const local_values = try allocator.alloc(?Ir.ValueId, function.local_types.len);
        @memset(local_values, null);
        var field_loads: std.ArrayList(Ir.Instruction.FieldLoad) = .empty;
        var collection_loads: std.ArrayList(Ir.Instruction.CollectionLoad) = .empty;
        var collection_references: std.ArrayList(Ir.Instruction.CollectionReference) = .empty;
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |original| {
            var instruction = try rewriteInstruction(allocator, original, aliases);
            switch (instruction) {
                .copy => |copy| {
                    if (definitions[copy.result] == 1 and
                        uses[copy.result] == block_uses[copy.result] and
                        function.value_types[copy.result] == function.value_types[copy.operand])
                    {
                        aliases[copy.result] = canonical(aliases, copy.operand);
                        continue;
                    }
                },
                .deep_copy => |copy| {
                    const value_type = function.value_types[copy.result];
                    if (definitions[copy.result] == 1 and
                        uses[copy.result] == block_uses[copy.result] and
                        (value_type.isNumeric() or value_type == .bool) and
                        value_type == function.value_types[copy.operand])
                    {
                        aliases[copy.result] = canonical(aliases, copy.operand);
                        continue;
                    }
                },
                .local_load => |load| {
                    const local_type = function.local_types[load.local];
                    if (local_type.isNumeric() or local_type == .bool or isViewType(program, local_type)) {
                        if (local_values[load.local]) |previous| {
                            aliases[load.result] = canonical(aliases, previous);
                            continue;
                        }
                        local_values[load.local] = load.result;
                    }
                },
                .local_store => |store| {
                    const local_type = function.local_types[store.local];
                    local_values[store.local] = if (local_type.isNumeric() or local_type == .bool or isViewType(program, local_type))
                        canonical(aliases, store.operand)
                    else
                        null;
                },
                .field_load => |load| {
                    if (matchingFieldLoad(field_loads.items, load)) |previous| {
                        aliases[load.result] = canonical(aliases, previous);
                        continue;
                    }
                    try field_loads.append(allocator, load);
                },
                .collection_load => |load| {
                    const result_type = function.value_types[load.result];
                    if (result_type.isNumeric() or result_type == .bool) {
                        if (matchingCollectionLoad(collection_loads.items, load)) |previous| {
                            aliases[load.result] = canonical(aliases, previous);
                            continue;
                        }
                        try collection_loads.append(allocator, load);
                    }
                },
                .collection_reference => |reference| {
                    if (block_index != 0 and matchingDominatingCollectionReference(
                        program,
                        function,
                        definitions,
                        stable_local_origins,
                        entry_references.items,
                        reference,
                    )) {
                        instruction.collection_reference.checked = false;
                    }
                    if (matchingCollectionReference(collection_references.items, reference)) |previous| {
                        aliases[reference.result] = canonical(aliases, previous);
                        continue;
                    }
                    try collection_references.append(allocator, reference);
                },
                .global_store,
                .field_store,
                .collection_replace,
                .list_edit,
                .reference_store,
                .address_store,
                .call,
                .indirect_call,
                .boundary_call,
                .dynamic_call,
                .mutex_lock,
                .mutex_unlock,
                => {
                    if (instruction == .reference_store and locals_cannot_alias) {
                        retainStableFieldLoads(&field_loads, program, function);
                    } else field_loads.clearRetainingCapacity();
                    collection_loads.clearRetainingCapacity();
                    if (instruction != .reference_store) collection_references.clearRetainingCapacity();
                    switch (instruction) {
                        .reference_store,
                        .address_store,
                        .call,
                        .indirect_call,
                        .boundary_call,
                        .dynamic_call,
                        .mutex_lock,
                        .mutex_unlock,
                        => if (instruction != .reference_store or !locals_cannot_alias) @memset(local_values, null),
                        else => {},
                    }
                },
                else => {},
            }
            try instructions.append(allocator, instruction);
        }
        if (block_index == 0 and references_stable_across_blocks) {
            for (collection_references.items) |reference| {
                if (reference.checked and reference.reference == null and isViewType(program, function.value_types[reference.collection])) {
                    try entry_references.append(allocator, reference);
                }
            }
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = rewriteTerminator(block.terminator, aliases, constants),
        };
    }
    var result = function;
    result.blocks = blocks;
    return removeRedundantCollectionChecks(allocator, result);
}

fn referencesStableAcrossBlocks(function: Ir.Function) bool {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .global_store,
        .field_store,
        .collection_replace,
        .list_edit,
        .address_store,
        .call,
        .indirect_call,
        .boundary_call,
        .boundary_indirect_call,
        .dynamic_call,
        .mutex_lock,
        .mutex_unlock,
        => return false,
        else => {},
    };
    return true;
}

fn stableLocalOrigins(
    allocator: Allocator,
    program: Ir.Program,
    function: Ir.Function,
    definitions: []const usize,
    enabled: bool,
) ![]?Ir.ValueId {
    const origins = try allocator.alloc(?Ir.ValueId, function.local_types.len);
    @memset(origins, null);
    if (!enabled) return origins;
    for (function.local_types, 0..) |local_type, local| {
        if (!isStableReferenceSourceType(program, local_type)) continue;
        var seed: ?Ir.ValueId = null;
        var valid = true;
        for (function.blocks, 0..) |block, block_index| for (block.instructions) |instruction| switch (instruction) {
            .local_store => |store| if (store.local == local) {
                const origin = copyOriginAcrossBlocks(function, definitions, store.operand);
                if (localLoadProducing(function, definitions, origin)) |load| {
                    if (load.local == local) continue;
                }
                if (block_index != 0 or (seed != null and seed.? != origin)) {
                    valid = false;
                    break;
                }
                seed = origin;
            },
            else => {},
        };
        if (valid) origins[local] = seed;
    }
    return origins;
}

fn isStableReferenceSourceType(program: Ir.Program, value_type: Ir.Type) bool {
    if (value_type.isNumeric() or value_type == .bool or isViewType(program, value_type)) return true;
    const structure = value_type.structureIndex() orelse return false;
    return structure < program.structures.len and !program.structures[structure].is_class and
        program.structures[structure].collection == null;
}

fn matchingDominatingCollectionReference(
    program: Ir.Program,
    function: Ir.Function,
    definitions: []const usize,
    stable_local_origins: []const ?Ir.ValueId,
    references: []const Ir.Instruction.CollectionReference,
    candidate: Ir.Instruction.CollectionReference,
) bool {
    if (candidate.reference != null) return false;
    const collection = stableValueOrigin(program, function, definitions, stable_local_origins, candidate.collection);
    const index = stableValueOrigin(program, function, definitions, stable_local_origins, candidate.index);
    for (references) |reference| {
        if (reference.reference == null and reference.ownership == candidate.ownership and
            stableValueOrigin(program, function, definitions, stable_local_origins, reference.collection) == collection and
            stableValueOrigin(program, function, definitions, stable_local_origins, reference.index) == index) return true;
    }
    return false;
}

fn stableValueOrigin(
    program: Ir.Program,
    function: Ir.Function,
    definitions: []const usize,
    stable_local_origins: []const ?Ir.ValueId,
    value: Ir.ValueId,
) Ir.ValueId {
    var current = copyOriginAcrossBlocks(function, definitions, value);
    var remaining = function.value_types.len;
    while (remaining != 0) : (remaining -= 1) {
        if (localLoadProducing(function, definitions, current)) |load| {
            current = stable_local_origins[load.local] orelse return current;
            current = copyOriginAcrossBlocks(function, definitions, current);
            continue;
        }
        const field = fieldLoadProducingAcrossBlocks(function, definitions, current) orelse return current;
        const structure_index = function.value_types[field.base].structureIndex() orelse return current;
        if (structure_index >= program.structures.len or program.structures[structure_index].is_class) return current;
        const base = stableValueOrigin(program, function, definitions, stable_local_origins, field.base);
        return stableFieldOrigin(function, definitions, base, field.field, current);
    }
    return current;
}

fn stableFieldOrigin(function: Ir.Function, definitions: []const usize, base: Ir.ValueId, field: usize, fallback: Ir.ValueId) Ir.ValueId {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .field_load => |load| if (load.field == field and
            copyOriginAcrossBlocks(function, definitions, load.base) == base) return load.result,
        else => {},
    };
    return fallback;
}

fn copyOriginAcrossBlocks(function: Ir.Function, definitions: []const usize, value: Ir.ValueId) Ir.ValueId {
    var current = value;
    var remaining = definitions.len;
    while (remaining != 0) : (remaining -= 1) {
        if (definitions[current] != 1) return current;
        const instruction = instructionProducing(function, current) orelse return current;
        if (instruction != .copy) return current;
        current = instruction.copy.operand;
    }
    return value;
}

fn localLoadProducing(function: Ir.Function, definitions: []const usize, value: Ir.ValueId) ?Ir.Instruction.LocalLoad {
    if (definitions[value] != 1) return null;
    const instruction = instructionProducing(function, value) orelse return null;
    return switch (instruction) {
        .local_load => |load| load,
        else => null,
    };
}

fn fieldLoadProducingAcrossBlocks(function: Ir.Function, definitions: []const usize, value: Ir.ValueId) ?Ir.Instruction.FieldLoad {
    if (definitions[value] != 1) return null;
    const instruction = instructionProducing(function, value) orelse return null;
    return switch (instruction) {
        .field_load => |load| load,
        else => null,
    };
}

fn instructionProducing(function: Ir.Function, value: Ir.ValueId) ?Ir.Instruction {
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .copy => |copy| if (copy.result == value) return instruction,
        .local_load => |load| if (load.result == value) return instruction,
        .field_load => |load| if (load.result == value) return instruction,
        else => {},
    };
    return null;
}

fn removeRedundantCollectionChecks(allocator: Allocator, function: Ir.Function) !Ir.Function {
    const dominated = try elideDominatedLastElementChecks(allocator, function);
    const uses = try allocator.alloc(usize, function.value_types.len);
    @memset(uses, 0);
    for (dominated.blocks) |block| {
        for (block.instructions) |instruction| countUses(instruction, uses);
        countTerminatorUses(block.terminator, uses);
    }
    const blocks = try allocator.alloc(Ir.Block, dominated.blocks.len);
    var changed = false;
    for (dominated.blocks, 0..) |block, block_index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions, 0..) |instruction, instruction_index| {
            if (instruction == .collection_load) {
                const load = instruction.collection_load;
                if (load.checked and uses[load.result] == 0 and
                    collectionCheckProven(function, block.instructions, instruction_index, load))
                {
                    changed = true;
                    continue;
                }
            }
            try instructions.append(allocator, instruction);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    if (!changed) return dominated;
    var result = dominated;
    result.blocks = blocks;
    return result;
}

fn elideDominatedLastElementChecks(allocator: Allocator, function: Ir.Function) !Ir.Function {
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    var value_types: std.ArrayList(Ir.Type) = .empty;
    try value_types.appendSlice(allocator, function.value_types);
    var changed = false;
    for (function.blocks, 0..) |block, block_index| {
        const constants = try allocator.alloc(?u64, function.value_types.len);
        @memset(constants, null);
        var nonempty: std.ArrayList(Ir.ValueId) = .empty;
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        for (block.instructions) |instruction| {
            var rewritten = instruction;
            switch (instruction) {
                .constant_int => |value| constants[value.result] = value.bits,
                .collection_load => |value| {
                    if (value.checked and isLastElement(constants, value.index) and containsValue(nonempty.items, value.collection)) {
                        const count = value_types.items.len;
                        try value_types.append(allocator, .int);
                        try instructions.append(allocator, .{ .collection_count = .{
                            .result = count,
                            .collection = value.collection,
                        } });
                        const one = value_types.items.len;
                        try value_types.append(allocator, .int);
                        try instructions.append(allocator, .{ .constant_int = .{
                            .result = one,
                            .bits = 1,
                        } });
                        const normalized = value_types.items.len;
                        try value_types.append(allocator, .int);
                        try instructions.append(allocator, .{ .binary = .{
                            .result = normalized,
                            .operator = .subtract,
                            .left = count,
                            .right = one,
                            .checked = false,
                        } });
                        var load = value;
                        load.index = normalized;
                        load.checked = false;
                        rewritten = .{ .collection_load = load };
                        changed = true;
                    }
                    if (value.checked and !containsValue(nonempty.items, value.collection))
                        try nonempty.append(allocator, value.collection);
                },
                else => if (!collectionAddressStable(&.{instruction})) nonempty.clearRetainingCapacity(),
            }
            try instructions.append(allocator, rewritten);
        }
        blocks[block_index] = .{
            .instructions = try instructions.toOwnedSlice(allocator),
            .terminator = block.terminator,
        };
    }
    if (!changed) return function;
    var result = function;
    result.value_types = try value_types.toOwnedSlice(allocator);
    result.blocks = blocks;
    return result;
}

fn isLastElement(constants: []const ?u64, index: Ir.ValueId) bool {
    return index < constants.len and constants[index] != null and constants[index].? == std.math.maxInt(u64);
}

fn containsValue(values: []const Ir.ValueId, candidate: Ir.ValueId) bool {
    for (values) |value| if (value == candidate) return true;
    return false;
}

fn collectionCheckProven(
    function: Ir.Function,
    instructions: []const Ir.Instruction,
    load_index: usize,
    load: Ir.Instruction.CollectionLoad,
) bool {
    for (instructions[load_index + 1 ..], load_index + 1..) |instruction, replacement_index| {
        const replacement = switch (instruction) {
            .collection_replace => |value| value,
            else => continue,
        };
        if (!std.meta.eql(replacement.position, load.position)) continue;
        const exact_values = replacement.collection == load.collection and replacement.index == load.index;
        if (!exact_values and (!sameStableLocalValue(function, replacement.collection, load.collection) or
            !sameStableLocalValue(function, replacement.index, load.index))) continue;
        if (collectionCheckOrderStable(instructions[load_index + 1 .. replacement_index])) return true;
    }
    for (instructions, 0..) |instruction, reference_index| {
        const reference = switch (instruction) {
            .collection_reference => |value| value,
            else => continue,
        };
        const exact_values = reference.collection == load.collection and reference.index == load.index;
        if (!exact_values and (!sameStableLocalValue(function, reference.collection, load.collection) or
            !sameStableLocalValue(function, reference.index, load.index))) continue;
        if (!referenceFeedsMutation(instructions, reference.result, 0)) continue;
        const start = @min(load_index, reference_index);
        const end = @max(load_index, reference_index);
        if (!collectionAddressStable(instructions[start + 1 .. end])) continue;
        if (reference_index < load_index and
            (exact_values or collectionCheckOrderStable(instructions[start + 1 .. end]))) return true;
        if (std.meta.eql(reference.position, load.position) and
            collectionCheckOrderStable(instructions[start + 1 .. end])) return true;
    }
    return false;
}

fn sameStableLocalValue(function: Ir.Function, left: Ir.ValueId, right: Ir.ValueId) bool {
    if (left == right) return true;
    const left_definition = instructionProducing(function, left) orelse return false;
    const right_definition = instructionProducing(function, right) orelse return false;
    return left_definition == .local_load and right_definition == .local_load and
        left_definition.local_load.local == right_definition.local_load.local;
}

fn referenceFeedsMutation(instructions: []const Ir.Instruction, reference: Ir.ValueId, depth: usize) bool {
    if (depth >= instructions.len) return false;
    for (instructions) |instruction| switch (instruction) {
        .reference_store => |store| if (store.reference == reference) return true,
        .reference_field => |field| if (field.reference == reference and
            referenceFeedsMutation(instructions, field.result, depth + 1)) return true,
        .reference_optional => |optional| if (optional.reference == reference and
            referenceFeedsMutation(instructions, optional.result, depth + 1)) return true,
        .copy => |copy| if (copy.operand == reference and
            referenceFeedsMutation(instructions, copy.result, depth + 1)) return true,
        .call => |call| for (call.arguments) |argument| {
            if (argument == reference) return true;
        },
        else => {},
    };
    return false;
}

fn collectionCheckOrderStable(instructions: []const Ir.Instruction) bool {
    for (instructions) |instruction| switch (instruction) {
        .local_store,
        .global_store,
        .field_store,
        .collection_replace,
        .list_edit,
        .reference_store,
        .address_store,
        .call,
        .indirect_call,
        .boundary_call,
        .boundary_indirect_call,
        .dynamic_call,
        .mutex_lock,
        .mutex_unlock,
        => return false,
        else => {},
    };
    return true;
}

fn collectionAddressStable(instructions: []const Ir.Instruction) bool {
    for (instructions) |instruction| switch (instruction) {
        .global_store,
        .field_store,
        .collection_replace,
        .list_edit,
        .address_store,
        .call,
        .indirect_call,
        .boundary_call,
        .boundary_indirect_call,
        .dynamic_call,
        .mutex_lock,
        .mutex_unlock,
        => return false,
        else => {},
    };
    return true;
}

fn retainStableFieldLoads(
    loads: *std.ArrayList(Ir.Instruction.FieldLoad),
    program: Ir.Program,
    function: Ir.Function,
) void {
    var retained: usize = 0;
    for (loads.items) |load| {
        const structure = function.value_types[load.base].structureIndex() orelse continue;
        if (structure >= program.structures.len or program.structures[structure].is_class) continue;
        loads.items[retained] = load;
        retained += 1;
    }
    loads.shrinkRetainingCapacity(retained);
}

fn hasLocalAddress(function: Ir.Function) bool {
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .local_address) return true;
    };
    return false;
}

fn isViewType(program: Ir.Program, value_type: Ir.Type) bool {
    const structure = value_type.structureIndex() orelse return false;
    if (structure >= program.structures.len) return false;
    const collection = program.structures[structure].collection orelse return false;
    return collection.view;
}

fn countDefinitions(instruction: Ir.Instruction, definitions: []usize) void {
    switch (instruction) {
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
        => {},
        .list_edit => |edit| {
            definitions[edit.result] += 1;
            if (edit.removed) |removed| definitions[removed] += 1;
        },
        .call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        .indirect_call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        .boundary_call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        .boundary_indirect_call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        .dynamic_call => |call| if (call.result) |result| {
            definitions[result] += 1;
        },
        inline else => |value| definitions[value.result] += 1,
    }
}

fn matchingFieldLoad(loads: []const Ir.Instruction.FieldLoad, candidate: Ir.Instruction.FieldLoad) ?Ir.ValueId {
    for (loads) |load| {
        if (load.base == candidate.base and load.field == candidate.field) return load.result;
    }
    return null;
}

fn matchingCollectionLoad(
    loads: []const Ir.Instruction.CollectionLoad,
    candidate: Ir.Instruction.CollectionLoad,
) ?Ir.ValueId {
    for (loads) |load| {
        if (load.collection == candidate.collection and load.index == candidate.index and
            load.checked == candidate.checked) return load.result;
    }
    return null;
}

fn matchingCollectionReference(
    references: []const Ir.Instruction.CollectionReference,
    candidate: Ir.Instruction.CollectionReference,
) ?Ir.ValueId {
    for (references) |reference| {
        if (reference.collection == candidate.collection and reference.index == candidate.index and
            reference.reference == candidate.reference and reference.ownership == candidate.ownership)
            return reference.result;
    }
    return null;
}

fn summarize(function: Ir.Function) GlobalSummary {
    if (function.capture_types.len != 0) return .none;
    if (function.blocks.len != 1) return .none;
    const returned = switch (function.blocks[0].terminator) {
        .return_value => |value| value,
        else => return .none,
    };
    if (function.blocks[0].instructions.len == 0) {
        return if (returned < function.parameter_types.len) .{ .identity = returned } else .none;
    }
    if (function.blocks[0].instructions.len != 1) return .none;
    return switch (function.blocks[0].instructions[0]) {
        .constant_int => |value| if (value.result == returned) .{ .integer = value.bits } else .none,
        .constant_bool => |value| if (value.result == returned) .{ .boolean = value.value } else .none,
        .constant_str => |value| if (value.result == returned) .{ .string = value.value } else .none,
        .constant_float32 => |value| if (value.result == returned) .{ .float32 = value.bits } else .none,
        .constant_float64 => |value| if (value.result == returned) .{ .float64 = value.bits } else .none,
        .binary => |value| if (value.result == returned and
            value.left < function.parameter_types.len and
            value.right < function.parameter_types.len)
            .{ .binary = .{
                .operator = value.operator,
                .left_parameter = value.left,
                .right_parameter = value.right,
            } }
        else
            .none,
        else => .none,
    };
}

fn inlineConstantCall(call: Ir.Instruction.Call, summaries: []const GlobalSummary) ?Ir.Instruction {
    const result = call.result orelse return null;
    if (call.function >= summaries.len) return null;
    return switch (summaries[call.function]) {
        .none => null,
        .identity => |parameter| if (parameter < call.arguments.len)
            .{ .copy = .{ .result = result, .operand = call.arguments[parameter] } }
        else
            null,
        .binary => |summary| if (summary.left_parameter < call.arguments.len and
            summary.right_parameter < call.arguments.len)
            .{ .binary = .{
                .result = result,
                .operator = summary.operator,
                .left = call.arguments[summary.left_parameter],
                .right = call.arguments[summary.right_parameter],
            } }
        else
            null,
        .integer => |bits| .{ .constant_int = .{ .result = result, .bits = bits } },
        .boolean => |value| .{ .constant_bool = .{ .result = result, .value = value } },
        .string => |value| .{ .constant_str = .{ .result = result, .value = value } },
        .float32 => |bits| .{ .constant_float32 = .{ .result = result, .bits = bits } },
        .float64 => |bits| .{ .constant_float64 = .{ .result = result, .bits = bits } },
    };
}

fn canonical(aliases: []const Ir.ValueId, value: Ir.ValueId) Ir.ValueId {
    var current = value;
    while (aliases[current] != current) current = aliases[current];
    return current;
}

fn rewriteInstruction(allocator: Allocator, instruction: Ir.Instruction, aliases: []const Ir.ValueId) !Ir.Instruction {
    return switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_str,
        .constant_bytes,
        .constant_float32,
        .constant_float64,
        .optional_null,
        .global_load,
        .storage_init,
        .local_address,
        .mutex_lock,
        .mutex_unlock,
        => instruction,
        .function_reference => |value| .{ .function_reference = .{
            .result = value.result,
            .function = value.function,
            .captures = try rewriteValues(allocator, value.captures, aliases),
        } },
        .string_address => |value| .{ .string_address = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
        } },
        .string_byte_count => |value| .{ .string_byte_count = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
        } },
        .string_byte_at => |value| .{ .string_byte_at = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .index = canonical(aliases, value.index),
        } },
        .string_from_bytes => |value| .{ .string_from_bytes = .{
            .result = value.result,
            .bytes = canonical(aliases, value.bytes),
        } },
        .optional_some => |value| .{ .optional_some = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .optional_unwrap => |value| .{ .optional_unwrap = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .copy => |value| .{ .copy = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .deep_copy => |value| .{ .deep_copy = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .class_cast => |value| .{ .class_cast = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .class_retain => |value| .{ .class_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .class_drop => |value| .{ .class_drop = .{
            .operand = canonical(aliases, value.operand),
            .ownership = value.ownership,
            .skip_cycle = value.skip_cycle,
            .static_type = value.static_type,
            .plans = value.plans,
        } },
        .list_retain => |value| .{ .list_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .string_retain => |value| .{ .string_retain = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .string_drop => |value| .{ .string_drop = .{ .operand = canonical(aliases, value.operand), .ownership = value.ownership } },
        .list_drop => |value| .{ .list_drop = .{
            .operand = canonical(aliases, value.operand),
            .ownership = value.ownership,
            .deallocate = value.deallocate,
        } },
        .global_store => |value| .{ .global_store = .{ .global = value.global, .operand = canonical(aliases, value.operand) } },
        .structure_init => |value| .{ .structure_init = .{
            .result = value.result,
            .structure = value.structure,
            .fields = try rewriteValues(allocator, value.fields, aliases),
        } },
        .protocol_init => |value| .{ .protocol_init = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .protocol_test => |value| .{ .protocol_test = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .protocol_extract => |value| .{ .protocol_extract = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .structure = value.structure,
        } },
        .list_init => |value| .{ .list_init = .{
            .result = value.result,
            .values = try rewriteValues(allocator, value.values, aliases),
        } },
        .enum_init => |value| .{ .enum_init = .{
            .result = value.result,
            .enumeration = value.enumeration,
            .variant = value.variant,
            .values = try rewriteValues(allocator, value.values, aliases),
        } },
        .enum_test => |value| .{ .enum_test = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
            .variant = value.variant,
        } },
        .enum_payload => |value| .{ .enum_payload = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
            .variant = value.variant,
            .index = value.index,
        } },
        .enum_raw => |value| .{ .enum_raw = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .enumeration = value.enumeration,
        } },
        .field_load => |value| .{ .field_load = .{
            .result = value.result,
            .base = canonical(aliases, value.base),
            .field = value.field,
        } },
        .field_store => |value| .{ .field_store = .{
            .result = value.result,
            .base = canonical(aliases, value.base),
            .field = value.field,
            .replacement = canonical(aliases, value.replacement),
        } },
        .collection_load => |value| .{ .collection_load = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .index = canonical(aliases, value.index),
            .checked = value.checked,
            .position = value.position,
        } },
        .collection_reference => |value| .{ .collection_reference = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .reference = rewriteOptional(value.reference, aliases),
            .index = canonical(aliases, value.index),
            .checked = value.checked,
            .ownership = value.ownership,
            .position = value.position,
        } },
        .collection_replace => |value| .{ .collection_replace = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .index = canonical(aliases, value.index),
            .replacement = canonical(aliases, value.replacement),
            .checked = value.checked,
            .ownership = value.ownership,
            .position = value.position,
        } },
        .collection_count => |value| .{ .collection_count = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
        } },
        .list_edit => |value| .{ .list_edit = .{
            .result = value.result,
            .collection = canonical(aliases, value.collection),
            .ownership = value.ownership,
            .kind = value.kind,
            .index = rewriteOptional(value.index, aliases),
            .argument = rewriteOptional(value.argument, aliases),
            .argument_transferred = value.argument_transferred,
            .removed = value.removed,
            .position = value.position,
        } },
        .collection_slice => |value| .{ .collection_slice = try rewriteSlice(value, aliases) },
        .collection_view => |value| .{ .collection_view = try rewriteSlice(value, aliases) },
        .local_load => |value| .{ .local_load = value },
        .local_store => |value| .{ .local_store = .{ .local = value.local, .operand = canonical(aliases, value.operand) } },
        .reference_load => |value| .{ .reference_load = .{ .result = value.result, .reference = canonical(aliases, value.reference) } },
        .address_load => |value| .{ .address_load = .{
            .result = value.result,
            .address = canonical(aliases, value.address),
            .byte_offset = canonical(aliases, value.byte_offset),
            .type = value.type,
        } },
        .address_store => |value| .{ .address_store = .{
            .address = canonical(aliases, value.address),
            .byte_offset = canonical(aliases, value.byte_offset),
            .operand = canonical(aliases, value.operand),
            .type = value.type,
        } },
        .reference_store => |value| .{ .reference_store = .{
            .reference = canonical(aliases, value.reference),
            .operand = canonical(aliases, value.operand),
        } },
        .reference_field => |value| .{ .reference_field = .{
            .result = value.result,
            .reference = canonical(aliases, value.reference),
            .structure = value.structure,
            .field = value.field,
        } },
        .reference_optional => |value| .{ .reference_optional = .{
            .result = value.result,
            .reference = canonical(aliases, value.reference),
        } },
        .convert => |value| .{ .convert = .{
            .result = value.result,
            .operand = canonical(aliases, value.operand),
            .source = value.source,
            .target = value.target,
            .position = value.position,
            .checked = value.checked,
        } },
        .format_value => |value| .{ .format_value = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .string_concat => |value| .{ .string_concat = .{
            .result = value.result,
            .left = canonical(aliases, value.left),
            .right = canonical(aliases, value.right),
        } },
        .string_count => |value| .{ .string_count = .{ .result = value.result, .operand = canonical(aliases, value.operand) } },
        .unary => |value| .{ .unary = .{
            .result = value.result,
            .operator = value.operator,
            .operand = canonical(aliases, value.operand),
        } },
        .binary => |value| .{ .binary = .{
            .result = value.result,
            .operator = value.operator,
            .left = canonical(aliases, value.left),
            .right = canonical(aliases, value.right),
            .checked = value.checked,
        } },
        .call => |value| .{ .call = .{
            .result = value.result,
            .function = value.function,
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .indirect_call => |value| .{ .indirect_call = .{
            .result = value.result,
            .callee = canonical(aliases, value.callee),
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .boundary_call => |value| .{ .boundary_call = .{
            .result = value.result,
            .function = value.function,
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .boundary_indirect_call => |value| .{ .boundary_indirect_call = .{
            .result = value.result,
            .callee = canonical(aliases, value.callee),
            .signature = value.signature,
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
        } },
        .dynamic_call => |value| .{ .dynamic_call = .{
            .result = value.result,
            .function = value.function,
            .receiver = canonical(aliases, value.receiver),
            .arguments = try rewriteValues(allocator, value.arguments, aliases),
            .implementations = value.implementations,
        } },
        .print => |value| .{ .print = .{ .value = canonical(aliases, value.value), .newline = value.newline } },
        .assert => |value| .{ .assert = .{
            .condition = canonical(aliases, value.condition),
            .message = canonical(aliases, value.message),
            .position = value.position,
        } },
    };
}

fn rewriteSlice(value: Ir.Instruction.CollectionSlice, aliases: []const Ir.ValueId) !Ir.Instruction.CollectionSlice {
    return .{
        .result = value.result,
        .collection = canonical(aliases, value.collection),
        .start = canonical(aliases, value.start),
        .end = canonical(aliases, value.end),
        .reference = rewriteOptional(value.reference, aliases),
    };
}

fn rewriteValues(allocator: Allocator, values: []const Ir.ValueId, aliases: []const Ir.ValueId) ![]const Ir.ValueId {
    const rewritten = try allocator.alloc(Ir.ValueId, values.len);
    for (values, 0..) |value, index| rewritten[index] = canonical(aliases, value);
    return rewritten;
}

fn rewriteOptional(value: ?Ir.ValueId, aliases: []const Ir.ValueId) ?Ir.ValueId {
    return if (value) |present| canonical(aliases, present) else null;
}

fn foldInstruction(function: Ir.Function, instruction: Ir.Instruction, constants: []const Constant) Ir.Instruction {
    return switch (instruction) {
        .unary => |value| foldUnary(function, value, constants) orelse instruction,
        .binary => |value| foldBinary(function, value, constants) orelse instruction,
        .convert => |value| foldConvert(value, constants) orelse instruction,
        else => instruction,
    };
}

fn foldConvert(value: Ir.Instruction.Convert, constants: []const Constant) ?Ir.Instruction {
    if (!value.source.isInteger() or !value.target.isInteger()) return null;
    const bits = switch (constants[value.operand]) {
        .integer => |bits| bits,
        else => return null,
    };
    const number: i128 = if (value.source.isSignedInteger())
        signedValue(bits, value.source.bitWidth())
    else
        @intCast(masked(bits, value.source.bitWidth()));
    if (value.target.isSignedInteger()) {
        if (!fitsSigned(number, value.target.bitWidth())) return null;
    } else {
        if (number < 0 or @as(u128, @intCast(number)) > unsignedMaximum(value.target.bitWidth())) return null;
    }
    return .{ .constant_int = .{
        .result = value.result,
        .bits = integerBits(number, value.target.bitWidth()),
    } };
}

fn foldUnary(function: Ir.Function, value: Ir.Instruction.Unary, constants: []const Constant) ?Ir.Instruction {
    const type_value = function.value_types[value.result];
    if (type_value == .float32) {
        const bits = switch (constants[value.operand]) {
            .float32 => |bits| bits,
            else => return null,
        };
        return .{ .constant_float32 = .{ .result = value.result, .bits = bits ^ 0x80000000 } };
    }
    if (type_value == .float64) {
        const bits = switch (constants[value.operand]) {
            .float64 => |bits| bits,
            else => return null,
        };
        return .{ .constant_float64 = .{ .result = value.result, .bits = bits ^ 0x8000000000000000 } };
    }
    if (!type_value.isSignedInteger()) return null;
    const bits = switch (constants[value.operand]) {
        .integer => |bits| bits,
        else => return null,
    };
    const operand = signedValue(bits, type_value.bitWidth());
    const result = -operand;
    if (!fitsSigned(result, type_value.bitWidth())) return null;
    return .{ .constant_int = .{ .result = value.result, .bits = integerBits(result, type_value.bitWidth()) } };
}

fn foldBinary(function: Ir.Function, value: Ir.Instruction.Binary, constants: []const Constant) ?Ir.Instruction {
    const operand_type = function.value_types[value.left];
    if (value.operator == .shift_left or value.operator == .shift_right) {
        return foldIntegerShift(function, value, constants);
    }
    if (operand_type == .float32) {
        const left = switch (constants[value.left]) {
            .float32 => |bits| bits,
            else => return null,
        };
        const right = switch (constants[value.right]) {
            .float32 => |bits| bits,
            else => return null,
        };
        return foldFloat32(value, left, right);
    }
    if (operand_type == .float64) {
        const left = switch (constants[value.left]) {
            .float64 => |bits| bits,
            else => return null,
        };
        const right = switch (constants[value.right]) {
            .float64 => |bits| bits,
            else => return null,
        };
        return foldFloat64(value, left, right);
    }
    const left_bits = switch (constants[value.left]) {
        .integer => |bits| bits,
        else => return null,
    };
    const right_bits = switch (constants[value.right]) {
        .integer => |bits| bits,
        else => return null,
    };
    if (!operand_type.isInteger()) return null;
    if (isComparison(value.operator)) {
        const result = compareIntegers(value.operator, operand_type, left_bits, right_bits);
        return .{ .constant_bool = .{ .result = value.result, .value = result } };
    }
    const bits = foldInteger(value.operator, operand_type, left_bits, right_bits) orelse return null;
    return .{ .constant_int = .{ .result = value.result, .bits = bits } };
}

fn foldIntegerShift(function: Ir.Function, value: Ir.Instruction.Binary, constants: []const Constant) ?Ir.Instruction {
    const type_value = function.value_types[value.left];
    const count_type = function.value_types[value.right];
    if (!type_value.isInteger() or !count_type.isInteger()) return null;
    const left = switch (constants[value.left]) {
        .integer => |bits| masked(bits, type_value.bitWidth()),
        else => return null,
    };
    const right = switch (constants[value.right]) {
        .integer => |bits| bits,
        else => return null,
    };
    const count: u64 = if (count_type.isSignedInteger()) count: {
        const signed = signedValue(right, count_type.bitWidth());
        if (signed < 0) return null;
        break :count @intCast(signed);
    } else masked(right, count_type.bitWidth());
    if (count >= type_value.bitWidth()) return null;
    const shift: u6 = @intCast(count);
    const result = if (value.operator == .shift_left) left << shift else left >> shift;
    return .{ .constant_int = .{
        .result = value.result,
        .bits = masked(result, type_value.bitWidth()),
    } };
}

fn foldFloat32(value: Ir.Instruction.Binary, left_bits: u32, right_bits: u32) ?Ir.Instruction {
    const left: f32 = @bitCast(left_bits);
    const right: f32 = @bitCast(right_bits);
    if (!std.math.isFinite(left) or !std.math.isFinite(right)) return null;
    if (isComparison(value.operator)) {
        return .{ .constant_bool = .{ .result = value.result, .value = compare(value.operator, left, right) } };
    }
    if (value.operator == .divide and right == 0) return null;
    const result: f32 = switch (value.operator) {
        .add => left + right,
        .subtract => left - right,
        .multiply => left * right,
        .divide => left / right,
        else => return null,
    };
    if (!std.math.isFinite(result)) return null;
    return .{ .constant_float32 = .{ .result = value.result, .bits = @bitCast(result) } };
}

fn foldFloat64(value: Ir.Instruction.Binary, left_bits: u64, right_bits: u64) ?Ir.Instruction {
    const left: f64 = @bitCast(left_bits);
    const right: f64 = @bitCast(right_bits);
    if (!std.math.isFinite(left) or !std.math.isFinite(right)) return null;
    if (isComparison(value.operator)) {
        return .{ .constant_bool = .{ .result = value.result, .value = compare(value.operator, left, right) } };
    }
    if (value.operator == .divide and right == 0) return null;
    const result: f64 = switch (value.operator) {
        .add => left + right,
        .subtract => left - right,
        .multiply => left * right,
        .divide => left / right,
        else => return null,
    };
    if (!std.math.isFinite(result)) return null;
    return .{ .constant_float64 = .{ .result = value.result, .bits = @bitCast(result) } };
}

fn foldInteger(operator: Ir.BinaryOperator, type_value: Ir.Type, left_bits: u64, right_bits: u64) ?u64 {
    const width = type_value.bitWidth();
    if (type_value.isSignedInteger()) {
        const left = signedValue(left_bits, width);
        const right = signedValue(right_bits, width);
        const result = switch (operator) {
            .add => left + right,
            .subtract => left - right,
            .multiply => left * right,
            .divide => if (right == 0 or (left == signedMinimum(width) and right == -1)) return null else @divTrunc(left, right),
            .remainder => if (right == 0 or (left == signedMinimum(width) and right == -1)) return null else @rem(left, right),
            .bit_and => return masked(left_bits & right_bits, width),
            .bit_xor => return masked(left_bits ^ right_bits, width),
            else => return null,
        };
        if (!fitsSigned(result, width)) return null;
        return integerBits(result, width);
    }

    const left: u128 = masked(left_bits, width);
    const right: u128 = masked(right_bits, width);
    const result = switch (operator) {
        .add => left + right,
        .subtract => if (left < right) return null else left - right,
        .multiply => left * right,
        .divide => if (right == 0) return null else left / right,
        .remainder => if (right == 0) return null else left % right,
        .bit_and => left & right,
        .bit_xor => left ^ right,
        else => return null,
    };
    if (result > unsignedMaximum(width)) return null;
    return @intCast(result);
}

fn compareIntegers(operator: Ir.BinaryOperator, type_value: Ir.Type, left_bits: u64, right_bits: u64) bool {
    if (type_value.isSignedInteger()) {
        const left = signedValue(left_bits, type_value.bitWidth());
        const right = signedValue(right_bits, type_value.bitWidth());
        return compare(operator, left, right);
    }
    const left: u128 = masked(left_bits, type_value.bitWidth());
    const right: u128 = masked(right_bits, type_value.bitWidth());
    return compare(operator, left, right);
}

fn compare(operator: Ir.BinaryOperator, left: anytype, right: @TypeOf(left)) bool {
    return switch (operator) {
        .less => left < right,
        .less_equal => left <= right,
        .greater => left > right,
        .greater_equal => left >= right,
        .equal => left == right,
        .not_equal => left != right,
        else => unreachable,
    };
}

fn isComparison(operator: Ir.BinaryOperator) bool {
    return switch (operator) {
        .less, .less_equal, .greater, .greater_equal, .equal, .not_equal => true,
        else => false,
    };
}

fn recordConstant(instruction: Ir.Instruction, constants: []Constant) void {
    if (instructionResult(instruction)) |result| constants[result] = .unknown;
    switch (instruction) {
        .constant_int => |value| constants[value.result] = .{ .integer = value.bits },
        .constant_bool => |value| constants[value.result] = .{ .boolean = value.value },
        .constant_float32 => |value| constants[value.result] = .{ .float32 = value.bits },
        .constant_float64 => |value| constants[value.result] = .{ .float64 = value.bits },
        else => {},
    }
}

fn rewriteTerminator(terminator: Ir.Terminator, aliases: []const Ir.ValueId, constants: []const Constant) Ir.Terminator {
    return switch (terminator) {
        .jump, .return_void => terminator,
        .return_value => |value| .{ .return_value = canonical(aliases, value) },
        .panic => |value| .{ .panic = .{
            .message = canonical(aliases, value.message),
            .position = value.position,
        } },
        .branch => |branch| branch_result: {
            const condition = canonical(aliases, branch.condition);
            if (constants[condition] == .boolean) {
                break :branch_result .{ .jump = if (constants[condition].boolean) branch.then_block else branch.else_block };
            }
            break :branch_result .{ .branch = .{
                .condition = condition,
                .then_block = branch.then_block,
                .else_block = branch.else_block,
            } };
        },
    };
}

fn removeUnreachableBlocks(allocator: Allocator, blocks: []const Ir.Block) ![]const Ir.Block {
    if (blocks.len == 0) return blocks;
    const reachable = try allocator.alloc(bool, blocks.len);
    @memset(reachable, false);
    var pending: std.ArrayList(Ir.BlockId) = .empty;
    try pending.append(allocator, 0);
    while (pending.pop()) |block_id| {
        if (reachable[block_id]) continue;
        reachable[block_id] = true;
        switch (blocks[block_id].terminator) {
            .jump => |target| try pending.append(allocator, target),
            .branch => |branch| {
                try pending.append(allocator, branch.then_block);
                try pending.append(allocator, branch.else_block);
            },
            else => {},
        }
    }

    const remap = try allocator.alloc(Ir.BlockId, blocks.len);
    var count: usize = 0;
    for (reachable, 0..) |present, old| if (present) {
        remap[old] = count;
        count += 1;
    };
    const result = try allocator.alloc(Ir.Block, count);
    var next: usize = 0;
    for (blocks, 0..) |block, old| {
        if (!reachable[old]) continue;
        result[next] = .{
            .instructions = block.instructions,
            .terminator = remapTerminator(block.terminator, remap),
        };
        next += 1;
    }
    return result;
}

fn remapTerminator(terminator: Ir.Terminator, remap: []const Ir.BlockId) Ir.Terminator {
    return switch (terminator) {
        .jump => |target| .{ .jump = remap[target] },
        .branch => |branch| .{ .branch = .{
            .condition = branch.condition,
            .then_block = remap[branch.then_block],
            .else_block = remap[branch.else_block],
        } },
        else => terminator,
    };
}

fn removeDeadConstants(allocator: Allocator, function: Ir.Function) ![]const Ir.Block {
    var current = function.blocks;
    while (true) {
        const uses = try allocator.alloc(usize, function.value_types.len);
        @memset(uses, 0);
        for (current) |block| {
            for (block.instructions) |instruction| countUses(instruction, uses);
            countTerminatorUses(block.terminator, uses);
        }
        var changed = false;
        const next = try allocator.alloc(Ir.Block, current.len);
        for (current, 0..) |block, block_index| {
            var instructions: std.ArrayList(Ir.Instruction) = .empty;
            for (block.instructions) |instruction| {
                if (removableResult(instruction)) |result| if (uses[result] == 0) {
                    changed = true;
                    continue;
                };
                try instructions.append(allocator, instruction);
            }
            next[block_index] = .{
                .instructions = try instructions.toOwnedSlice(allocator),
                .terminator = block.terminator,
            };
        }
        current = next;
        if (!changed) return current;
    }
}

fn removableResult(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        .constant_int => |value| value.result,
        .constant_bool => |value| value.result,
        .constant_str => |value| value.result,
        .constant_float32 => |value| value.result,
        .constant_float64 => |value| value.result,
        .storage_init => |value| value.result,
        .optional_null => |value| value.result,
        .optional_some => |value| value.result,
        .optional_unwrap => |value| value.result,
        .copy => |value| value.result,
        .protocol_test => |value| value.result,
        .protocol_extract => |value| value.result,
        .enum_test => |value| value.result,
        .enum_payload => |value| value.result,
        .enum_raw => |value| value.result,
        .field_load => |value| value.result,
        .collection_load => |value| if (!value.checked) value.result else null,
        .collection_count => |value| value.result,
        .local_load => |value| value.result,
        .reference_load => |value| value.result,
        .reference_field => |value| value.result,
        .reference_optional => |value| value.result,
        .collection_reference => |value| value.result,
        .string_count => |value| value.result,
        .string_byte_at => |value| value.result,
        .string_from_bytes => |value| value.result,
        .binary => |value| if (isRemovableBinary(value.operator)) value.result else null,
        else => null,
    };
}

fn isRemovableBinary(operator: Ir.BinaryOperator) bool {
    return isComparison(operator) or operator == .bit_and or operator == .bit_xor;
}

fn countUses(instruction: Ir.Instruction, uses: []usize) void {
    switch (instruction) {
        .constant_int,
        .constant_bool,
        .constant_str,
        .constant_bytes,
        .constant_float32,
        .constant_float64,
        .optional_null,
        .global_load,
        .storage_init,
        .local_load,
        .local_address,
        => {},
        .function_reference => |value| useValues(uses, value.captures),
        .optional_some => |value| useValue(uses, value.operand),
        .optional_unwrap => |value| useValue(uses, value.operand),
        .copy => |value| useValue(uses, value.operand),
        .deep_copy => |value| useValue(uses, value.operand),
        .class_cast => |value| useValue(uses, value.operand),
        .class_retain => |value| useValue(uses, value.operand),
        .class_drop => |value| useValue(uses, value.operand),
        .list_retain, .list_drop, .string_retain, .string_drop => |value| useValue(uses, value.operand),
        .global_store => |value| useValue(uses, value.operand),
        .structure_init => |value| useValues(uses, value.fields),
        .protocol_init => |value| useValue(uses, value.operand),
        .protocol_test => |value| useValue(uses, value.operand),
        .protocol_extract => |value| useValue(uses, value.operand),
        .list_init => |value| useValues(uses, value.values),
        .enum_init => |value| useValues(uses, value.values),
        .enum_test => |value| useValue(uses, value.operand),
        .enum_payload => |value| useValue(uses, value.operand),
        .enum_raw => |value| useValue(uses, value.operand),
        .field_load => |value| useValue(uses, value.base),
        .field_store => |value| {
            useValue(uses, value.base);
            useValue(uses, value.replacement);
        },
        .collection_load => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.index);
        },
        .collection_reference => |value| {
            useValue(uses, value.collection);
            useOptional(uses, value.reference);
            useValue(uses, value.index);
        },
        .collection_replace => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.index);
            useValue(uses, value.replacement);
        },
        .collection_count => |value| useValue(uses, value.collection),
        .list_edit => |value| {
            useValue(uses, value.collection);
            useOptional(uses, value.index);
            useOptional(uses, value.argument);
        },
        .collection_slice, .collection_view => |value| {
            useValue(uses, value.collection);
            useValue(uses, value.start);
            useValue(uses, value.end);
            useOptional(uses, value.reference);
        },
        .string_address, .string_byte_count => |value| useValue(uses, value.operand),
        .string_byte_at => |value| {
            useValue(uses, value.operand);
            useValue(uses, value.index);
        },
        .string_from_bytes => |value| useValue(uses, value.bytes),
        .local_store => |value| useValue(uses, value.operand),
        .reference_load => |value| useValue(uses, value.reference),
        .address_load => |value| {
            useValue(uses, value.address);
            useValue(uses, value.byte_offset);
        },
        .address_store => |value| {
            useValue(uses, value.address);
            useValue(uses, value.byte_offset);
            useValue(uses, value.operand);
        },
        .reference_store => |value| {
            useValue(uses, value.reference);
            useValue(uses, value.operand);
        },
        .reference_field => |value| useValue(uses, value.reference),
        .reference_optional => |value| useValue(uses, value.reference),
        .convert => |value| useValue(uses, value.operand),
        .format_value => |value| useValue(uses, value.operand),
        .string_concat => |value| {
            useValue(uses, value.left);
            useValue(uses, value.right);
        },
        .string_count => |value| useValue(uses, value.operand),
        .unary => |value| useValue(uses, value.operand),
        .binary => |value| {
            useValue(uses, value.left);
            useValue(uses, value.right);
        },
        .call => |value| useValues(uses, value.arguments),
        .indirect_call => |value| {
            useValue(uses, value.callee);
            useValues(uses, value.arguments);
        },
        .boundary_call => |value| useValues(uses, value.arguments),
        .boundary_indirect_call => |value| {
            useValue(uses, value.callee);
            useValues(uses, value.arguments);
        },
        .dynamic_call => |value| {
            useValue(uses, value.receiver);
            useValues(uses, value.arguments);
        },
        .print => |value| useValue(uses, value.value),
        .assert => |value| {
            useValue(uses, value.condition);
            useValue(uses, value.message);
        },
        .mutex_lock, .mutex_unlock => {},
    }
}

fn countTerminatorUses(terminator: Ir.Terminator, uses: []usize) void {
    switch (terminator) {
        .return_value => |value| useValue(uses, value),
        .branch => |value| useValue(uses, value.condition),
        .panic => |value| useValue(uses, value.message),
        else => {},
    }
}

fn useValue(uses: []usize, value: Ir.ValueId) void {
    uses[value] += 1;
}

fn useValues(uses: []usize, values: []const Ir.ValueId) void {
    for (values) |value| useValue(uses, value);
}

fn useOptional(uses: []usize, value: ?Ir.ValueId) void {
    if (value) |present| useValue(uses, present);
}

fn signedValue(bits: u64, width: u7) i128 {
    const value: i128 = @intCast(masked(bits, width));
    const sign: i128 = @as(i128, 1) << @intCast(width - 1);
    return if (value & sign != 0) value - (@as(i128, 1) << @intCast(width)) else value;
}

fn signedMinimum(width: u7) i128 {
    return -(@as(i128, 1) << @intCast(width - 1));
}

fn fitsSigned(value: i128, width: u7) bool {
    const minimum = signedMinimum(width);
    const maximum = (@as(i128, 1) << @intCast(width - 1)) - 1;
    return value >= minimum and value <= maximum;
}

fn unsignedMaximum(width: u7) u128 {
    return (@as(u128, 1) << @intCast(width)) - 1;
}

fn masked(bits: u64, width: u7) u64 {
    return if (width == 64) bits else bits & ((@as(u64, 1) << @intCast(width)) - 1);
}

fn integerBits(value: i128, width: u7) u64 {
    return masked(@bitCast(@as(i64, @intCast(value))), width);
}

test "release folds constants and propagates copies in straight-line code" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_types = [_]Ir.Type{ .int, .int, .int, .int };
    const instructions = [_]Ir.Instruction{
        .{ .constant_int = .{ .result = 0, .bits = 20 } },
        .{ .copy = .{ .result = 1, .operand = 0 } },
        .{ .constant_int = .{ .result = 2, .bits = 22 } },
        .{ .binary = .{ .result = 3, .operator = .add, .left = 1, .right = 2 } },
    };
    const blocks = [_]Ir.Block{.{ .instructions = &instructions, .terminator = .{ .return_value = 3 } }};
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "answer",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &value_types,
        .blocks = &blocks,
    }} };
    const optimized = try optimize(allocator, program);
    try std.testing.expectEqual(@as(usize, 1), optimized.functions[0].blocks.len);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "const 42"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "copy"));
}

test "SSA value simplification propagates constants and copies across blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{.{ .constant_int = .{ .result = 0, .bits = 20 } }}, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{
            .{ .copy = .{ .result = 1, .operand = 0 } },
            .{ .constant_int = .{ .result = 2, .bits = 22 } },
            .{ .binary = .{ .result = 3, .operator = .add, .left = 1, .right = 2, .checked = true } },
            .{ .constant_bool = .{ .result = 4, .value = true } },
        }, .terminator = .{ .branch = .{ .condition = 4, .then_block = 2, .else_block = 3 } } },
        .{ .instructions = &.{}, .terminator = .{ .return_value = 3 } },
        .{ .instructions = &.{.{ .constant_int = .{ .result = 5, .bits = 0 } }}, .terminator = .{ .return_value = 5 } },
    };
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "inter_block",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{ .int, .int, .int, .int, .bool, .int },
        .blocks = &blocks,
    }} };
    const optimized = try simplifySsaValues(allocator, program);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "const 42"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "copy"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "add"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "branch"));
}

test "SSA value simplification merges linear blocks after propagation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const blocks = [_]Ir.Block{
        .{
            .instructions = &.{.{ .constant_int = .{ .result = 0, .bits = 7 } }},
            .terminator = .{ .jump = 1 },
        },
        .{
            .instructions = &.{.{ .print = .{ .value = 0, .newline = true } }},
            .terminator = .return_void,
        },
    };
    const optimized = try simplifySsaValues(allocator, .{ .functions = &.{.{
        .name = "linear",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{.int},
        .blocks = &blocks,
    }} });
    try std.testing.expectEqual(@as(usize, 1), optimized.functions[0].blocks.len);
    try std.testing.expectEqual(@as(usize, 2), optimized.functions[0].blocks[0].instructions.len);
    try std.testing.expectEqual(Ir.Terminator.return_void, optimized.functions[0].blocks[0].terminator);
}

test "SSA value simplification accepts only unanimous phi constants" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const equal_blocks = [_]Ir.Block{
        .{ .instructions = &.{}, .terminator = .{ .branch = .{ .condition = 0, .then_block = 1, .else_block = 2 } } },
        .{ .instructions = &.{.{ .constant_int = .{ .result = 1, .bits = 7 } }}, .terminator = .{ .jump = 3 } },
        .{ .instructions = &.{.{ .constant_int = .{ .result = 1, .bits = 7 } }}, .terminator = .{ .jump = 3 } },
        .{ .instructions = &.{
            .{ .constant_int = .{ .result = 2, .bits = 1 } },
            .{ .binary = .{ .result = 3, .operator = .add, .left = 1, .right = 2, .checked = true } },
        }, .terminator = .{ .return_value = 3 } },
    };
    const different_blocks = [_]Ir.Block{
        equal_blocks[0],
        equal_blocks[1],
        .{ .instructions = &.{.{ .constant_int = .{ .result = 1, .bits = 8 } }}, .terminator = .{ .jump = 3 } },
        equal_blocks[3],
    };
    const template: Ir.Function = .{
        .name = "phi_constant",
        .parameter_types = &.{.bool},
        .return_type = .int,
        .value_types = &.{ .bool, .int, .int, .int },
        .blocks = &equal_blocks,
    };
    const equal = try simplifySsaValues(allocator, .{ .functions = &.{template} });
    const equal_text = try Ir.writeText(allocator, equal);
    try std.testing.expect(std.mem.containsAtLeast(u8, equal_text, 1, "const 8"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, equal_text, 1, "add"));

    var different = template;
    different.blocks = &different_blocks;
    const retained = try simplifySsaValues(allocator, .{ .functions = &.{different} });
    const retained_text = try Ir.writeText(allocator, retained);
    try std.testing.expect(std.mem.containsAtLeast(u8, retained_text, 1, "add"));
}

test "SSA value simplification preserves checked integer overflow" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const blocks = [_]Ir.Block{.{ .instructions = &.{
        .{ .constant_int = .{ .result = 0, .bits = @as(u64, @bitCast(@as(i64, std.math.maxInt(i64)))) } },
        .{ .constant_int = .{ .result = 1, .bits = 1 } },
        .{ .binary = .{ .result = 2, .operator = .add, .left = 0, .right = 1, .checked = true } },
    }, .terminator = .{ .return_value = 2 } }};
    const optimized = try simplifySsaValues(allocator, .{ .functions = &.{.{
        .name = "checked_overflow",
        .parameter_types = &.{},
        .return_type = .int,
        .value_types = &.{ .int, .int, .int },
        .blocks = &blocks,
    }} });
    const instruction = optimized.functions[0].blocks[0].instructions[2].binary;
    try std.testing.expectEqual(Ir.BinaryOperator.add, instruction.operator);
    try std.testing.expect(instruction.checked);
}

test "SSA value simplification folds representable integer conversions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const position = Source.Position{ .offset = 0, .line = 1, .column = 1 };
    const blocks = [_]Ir.Block{.{ .instructions = &.{
        .{ .constant_int = .{ .result = 0, .bits = 0xf8 } },
        .{ .convert = .{
            .result = 1,
            .operand = 0,
            .source = .int8,
            .target = .int16,
            .position = position,
            .checked = true,
        } },
        .{ .constant_int = .{ .result = 2, .bits = 42 } },
        .{ .convert = .{
            .result = 3,
            .operand = 2,
            .source = .uint8,
            .target = .int16,
            .position = position,
            .checked = true,
        } },
        .{ .constant_int = .{ .result = 4, .bits = 3 } },
        .{ .binary = .{ .result = 5, .operator = .multiply, .left = 1, .right = 4 } },
        .{ .binary = .{ .result = 6, .operator = .add, .left = 5, .right = 3 } },
    }, .terminator = .{ .return_value = 6 } }};
    const optimized = try simplifySsaValues(allocator, .{ .functions = &.{.{
        .name = "constant_conversions",
        .parameter_types = &.{},
        .return_type = .int16,
        .value_types = &.{ .int8, .int16, .uint8, .int16, .int16, .int16, .int16 },
        .blocks = &blocks,
    }} });
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "const 18"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "convert"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "mul"));
    try std.testing.expect(!std.mem.containsAtLeast(u8, text, 1, "add"));
}

test "constant folding preserves failing integer conversions" {
    const position = Source.Position{ .offset = 0, .line = 1, .column = 1 };
    const facts = [_]Constant{.{ .integer = 300 }};
    try std.testing.expect(foldConvert(.{
        .result = 1,
        .operand = 0,
        .source = .int16,
        .target = .uint8,
        .position = position,
        .checked = true,
    }, &facts) == null);
}

test "constant shift folding honors operand and count widths" {
    const function: Ir.Function = .{
        .name = "constant_shift",
        .parameter_types = &.{},
        .return_type = .int8,
        .value_types = &.{ .int8, .int8, .int8 },
        .blocks = &.{},
    };
    const valid = [_]Constant{ .{ .integer = 0xfe }, .{ .integer = 1 } };
    const folded = foldIntegerShift(function, .{
        .result = 2,
        .operator = .shift_right,
        .left = 0,
        .right = 1,
    }, &valid).?;
    try std.testing.expectEqual(@as(u64, 0x7f), folded.constant_int.bits);

    const negative = [_]Constant{ .{ .integer = 0xfe }, .{ .integer = 0xff } };
    try std.testing.expect(foldIntegerShift(function, .{
        .result = 2,
        .operator = .shift_left,
        .left = 0,
        .right = 1,
    }, &negative) == null);

    const too_wide = [_]Constant{ .{ .integer = 0xfe }, .{ .integer = 8 } };
    try std.testing.expect(foldIntegerShift(function, .{
        .result = 2,
        .operator = .shift_left,
        .left = 0,
        .right = 1,
    }, &too_wide) == null);
}

test "release folds finite float constants inside branching functions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_types = [_]Ir.Type{ .float32, .float32, .float32 };
    const entry_instructions = [_]Ir.Instruction{
        .{ .constant_float32 = .{ .result = 0, .bits = @bitCast(@as(f32, 1.0)) } },
        .{ .constant_float32 = .{ .result = 1, .bits = @bitCast(@as(f32, 240.0)) } },
        .{ .binary = .{ .result = 2, .operator = .divide, .left = 0, .right = 1 } },
    };
    const blocks = [_]Ir.Block{
        .{ .instructions = &entry_instructions, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .{ .return_value = 2 } },
    };
    const function: Ir.Function = .{
        .name = "step",
        .parameter_types = &.{},
        .return_type = .float32,
        .value_types = &value_types,
        .blocks = &blocks,
    };
    const optimized = try foldBlockConstants(allocator, function);
    try std.testing.expectEqual(@as(usize, 2), optimized.blocks.len);
    try std.testing.expectEqual(@as(usize, 3), optimized.blocks[0].instructions.len);
    const folded = optimized.blocks[0].instructions[2].constant_float32;
    try std.testing.expectEqual(@as(Ir.ValueId, 2), folded.result);
    try std.testing.expectEqual(
        @as(u32, @bitCast(@as(f32, 1.0) / @as(f32, 240.0))),
        folded.bits,
    );
}

test "release leaves exceptional float arithmetic explicit" {
    const divide: Ir.Instruction.Binary = .{ .result = 2, .operator = .divide, .left = 0, .right = 1 };
    const one: u32 = @bitCast(@as(f32, 1.0));
    const zero: u32 = @bitCast(@as(f32, 0.0));
    const infinity: u32 = @bitCast(std.math.inf(f32));
    const nan: u32 = @bitCast(std.math.nan(f32));
    try std.testing.expect(foldFloat32(divide, one, zero) == null);
    try std.testing.expect(foldFloat32(divide, infinity, one) == null);
    try std.testing.expect(foldFloat32(divide, nan, one) == null);
}

test "release replaces only exact scalar STD Math minimum and maximum calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const arguments = [_]Ir.ValueId{ 0, 1 };
    const caller_instructions = [_]Ir.Instruction{
        .{ .call = .{ .result = 2, .function = 0, .arguments = &arguments } },
        .{ .call = .{ .result = 3, .function = 1, .arguments = &arguments } },
        .{ .call = .{ .result = 4, .function = 2, .arguments = &arguments } },
    };
    const functions = [_]Ir.Function{
        .{
            .name = "STD.Math.min",
            .parameter_types = &.{ .float32, .float32 },
            .return_type = .float32,
            .value_types = &.{ .float32, .float32 },
            .blocks = &.{},
        },
        .{
            .name = "STD.Math.max",
            .parameter_types = &.{ .float32, .float32 },
            .return_type = .float32,
            .value_types = &.{ .float32, .float32 },
            .blocks = &.{},
        },
        .{
            .name = "Application.max",
            .parameter_types = &.{ .float32, .float32 },
            .return_type = .float32,
            .value_types = &.{ .float32, .float32 },
            .blocks = &.{},
        },
        .{
            .name = "caller",
            .parameter_types = &.{ .float32, .float32 },
            .return_type = .float32,
            .value_types = &.{ .float32, .float32, .float32, .float32, .float32 },
            .blocks = &.{.{ .instructions = &caller_instructions, .terminator = .{ .return_value = 2 } }},
        },
    };
    const optimized = try replaceScalarMathCalls(allocator, .{ .functions = &functions });
    const instructions = optimized.functions[3].blocks[0].instructions;
    try std.testing.expectEqual(Ir.BinaryOperator.minimum, instructions[0].binary.operator);
    try std.testing.expectEqual(Ir.BinaryOperator.maximum, instructions[1].binary.operator);
    try std.testing.expect(instructions[2] == .call);
}

test "boolean diamond simplification preserves a merged result used after the branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_types = [_]Ir.Type{ .bool, .bool, .bool };
    const evaluated = [_]Ir.Instruction{
        .{ .copy = .{ .result = 2, .operand = 1 } },
    };
    const short_circuit = [_]Ir.Instruction{
        .{ .constant_bool = .{ .result = 2, .value = false } },
    };
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{}, .terminator = .{ .branch = .{
            .condition = 0,
            .then_block = 1,
            .else_block = 2,
        } } },
        .{ .instructions = &evaluated, .terminator = .{ .jump = 3 } },
        .{ .instructions = &short_circuit, .terminator = .{ .jump = 3 } },
        .{ .instructions = &.{}, .terminator = .{ .branch = .{
            .condition = 2,
            .then_block = 4,
            .else_block = 5,
        } } },
        .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .{ .return_value = 2 } },
    };
    const function: Ir.Function = .{
        .name = "shared",
        .parameter_types = &.{ .bool, .bool },
        .return_type = .bool,
        .value_types = &value_types,
        .blocks = &blocks,
    };

    const optimized = try simplifyBooleanDiamonds(allocator, function);

    try std.testing.expectEqual(@as(usize, blocks.len), optimized.blocks.len);
    try std.testing.expectEqual(@as(Ir.BlockId, 2), optimized.blocks[0].terminator.branch.else_block);
}

test "boolean diamond simplification accepts shared control-only blocks" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const value_types = [_]Ir.Type{ .bool, .bool, .bool };
    const evaluated = [_]Ir.Instruction{
        .{ .copy = .{ .result = 2, .operand = 1 } },
    };
    const short_circuit = [_]Ir.Instruction{
        .{ .constant_bool = .{ .result = 2, .value = false } },
    };
    const blocks = [_]Ir.Block{
        .{ .instructions = &.{}, .terminator = .{ .branch = .{
            .condition = 0,
            .then_block = 1,
            .else_block = 2,
        } } },
        .{ .instructions = &evaluated, .terminator = .{ .jump = 3 } },
        .{ .instructions = &short_circuit, .terminator = .{ .jump = 3 } },
        .{ .instructions = &.{}, .terminator = .{ .branch = .{
            .condition = 2,
            .then_block = 4,
            .else_block = 5,
        } } },
        .{ .instructions = &.{}, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .return_void },
    };
    const function: Ir.Function = .{
        .name = "shared_control",
        .parameter_types = &.{ .bool, .bool },
        .return_type = .void,
        .value_types = &value_types,
        .blocks = &blocks,
    };

    const optimized = try simplifyBooleanDiamonds(allocator, function);

    try std.testing.expectEqual(@as(usize, 4), optimized.blocks.len);
}

test "release preserves representation-changing copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const runtime_type = Ir.Type.structure(0);
    const structures = [_]Ir.Structure{.{
        .name = "Runtime",
        .fields = &.{},
        .is_class = true,
    }};
    const value_types = [_]Ir.Type{ .uint, runtime_type };
    const instructions = [_]Ir.Instruction{
        .{ .copy = .{ .result = 1, .operand = 0 } },
        .{ .class_retain = .{ .operand = 1, .ownership = .root } },
    };
    const blocks = [_]Ir.Block{.{ .instructions = &instructions, .terminator = .return_void }};
    const program: Ir.Program = .{
        .structures = &structures,
        .functions = &.{.{
            .name = "from_address",
            .parameter_types = &.{.uint},
            .return_type = .void,
            .value_types = &value_types,
            .blocks = &blocks,
        }},
    };

    const optimized = try optimize(allocator, program);
    const text = try Ir.writeText(allocator, optimized);
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "copy %0"));
    try std.testing.expect(std.mem.containsAtLeast(u8, text, 1, "class.retain %1"));
}

test {
    _ = @import("ReleaseTests.zig");
    _ = @import("AggregateStoresTests.zig");
    _ = @import("UnusedLocals.zig");
}
