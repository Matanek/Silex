const std = @import("std");
const Silex = @import("silex_optimizer_api");
const Differential = @import("Differential.zig");
const Generator = @import("Generator.zig");
const IrStats = @import("IrStats.zig");

pub const Evidence = union(enum) {
    none,
    blocks: struct {
        function: []const u8,
        raw: usize,
        optimized: usize,
    },
    bounds: struct {
        function: []const u8,
        raw: usize,
        optimized: usize,
    },
    scalar_loop: struct {
        function: []const u8,
        raw_collection_loads: usize,
        optimized_collection_loads: usize,
        raw_calls: usize,
        optimized_calls: usize,
    },
    ssa_values: struct {
        function: []const u8,
        raw_branches: usize,
        optimized_branches: usize,
        raw_arithmetic: usize,
        optimized_arithmetic: usize,
    },
    critical_edge: struct {
        function: []const u8,
        raw_local_operations: usize,
        optimized_local_operations: usize,
        raw_blocks: usize,
        optimized_blocks: usize,
    },
    integer_ranges: struct {
        bounded_add: []const u8,
        bounded_subtract: []const u8,
        bounded_conversion: []const u8,
        bounded_loop: []const u8,
        raw_proven_checks: usize,
        optimized_proven_checks: usize,
        optimized_unproven_checks: usize,
    },
    slp: struct {
        function: []const u8,
        required: u3,
        observed: u3,
        native_required: bool,
        arm64_pairs: usize,
        x64_pairs: usize,
    },
};

pub const SsaValueCounter = struct {
    function: []const u8,
    enabled_branches: usize,
    disabled_branches: usize,
    enabled_arithmetic: usize,
    disabled_arithmetic: usize,
};

pub const SsaPromotionCounter = struct {
    function: []const u8,
    enabled_local_operations: usize,
    disabled_local_operations: usize,
    enabled_blocks: usize,
    disabled_blocks: usize,
};

pub const IntegerRangeCounter = struct {
    enabled_proven_checks: usize,
    disabled_proven_checks: usize,
    enabled_unproven_checks: usize,
    disabled_unproven_checks: usize,
};

pub fn verifyContract(
    allocator: std.mem.Allocator,
    contract: Generator.StructuralContract,
    differential: Differential.Result,
) !Evidence {
    return switch (contract) {
        .none => .none,
        .reduces_blocks => |function_name| verifyBlockReduction(function_name, differential),
        .removes_collection_bounds => |function_name| verifyCollectionBounds(function_name, differential),
        .scalarizes_dense_loop => |function_name| verifyDenseScalarLoop(function_name, differential),
        .simplifies_ssa_values => |function_name| verifySsaValueSimplification(function_name, differential),
        .promotes_critical_edge => |function_name| verifyCriticalEdgePromotion(function_name, differential),
        .coalesces_forwarded_phi => |function_name| verifyCriticalEdgePromotion(function_name, differential),
        .promotes_distinct_phis => |function_name| verifyCriticalEdgePromotion(function_name, differential),
        .proves_integer_ranges => |requirement| verifyIntegerRanges(requirement, differential),
        .slp_width => |requirement| try verifySlp(
            allocator,
            requirement.function,
            requirement.minimum,
            requirement.native_pair,
            differential.optimized_ir,
        ),
    };
}

fn verifyIntegerRanges(requirement: anytype, differential: Differential.Result) !Evidence {
    const raw_add = findFunction(differential.raw_ir, requirement.bounded_add) orelse
        return error.ContractFunctionMissing;
    const raw_subtract = findFunction(differential.raw_ir, requirement.bounded_subtract) orelse
        return error.ContractFunctionMissing;
    const raw_conversion = findFunction(differential.raw_ir, requirement.bounded_conversion) orelse
        return error.ContractFunctionMissing;
    const raw_loop = findFunction(differential.raw_ir, requirement.bounded_loop) orelse
        return error.ContractFunctionMissing;
    const optimized_add = findFunction(differential.optimized_ir, requirement.bounded_add) orelse
        return error.ContractFunctionMissing;
    const optimized_subtract = findFunction(differential.optimized_ir, requirement.bounded_subtract) orelse
        return error.ContractFunctionMissing;
    const optimized_conversion = findFunction(differential.optimized_ir, requirement.bounded_conversion) orelse
        return error.ContractFunctionMissing;
    const optimized_loop = findFunction(differential.optimized_ir, requirement.bounded_loop) orelse
        return error.ContractFunctionMissing;
    const optimized_unproven = findFunction(differential.optimized_ir, requirement.unproven_add) orelse
        return error.ContractFunctionMissing;
    const raw_proven = checkedOperationCount(raw_add) + checkedOperationCount(raw_subtract) +
        checkedOperationCount(raw_conversion) + checkedOperationCount(raw_loop);
    const optimized_proven = checkedOperationCount(optimized_add) + checkedOperationCount(optimized_subtract) +
        checkedOperationCount(optimized_conversion) + checkedOperationCount(optimized_loop);
    const unproven = checkedOperationCount(optimized_unproven);
    if (raw_proven < 6 or optimized_proven != 0) return error.ExpectedRangeProofMissing;
    if (unproven == 0) return error.UnprovenOverflowCheckRemoved;
    return .{ .integer_ranges = .{
        .bounded_add = requirement.bounded_add,
        .bounded_subtract = requirement.bounded_subtract,
        .bounded_conversion = requirement.bounded_conversion,
        .bounded_loop = requirement.bounded_loop,
        .raw_proven_checks = raw_proven,
        .optimized_proven_checks = optimized_proven,
        .optimized_unproven_checks = unproven,
    } };
}

pub fn verifyIntegerRangeCounter(
    requirement: anytype,
    enabled: Differential.Result,
    disabled: Differential.Result,
) !IntegerRangeCounter {
    const enabled_proven = try rangeProofChecks(requirement, enabled.optimized_ir);
    const disabled_proven = try rangeProofChecks(requirement, disabled.optimized_ir);
    const enabled_unproven = checkedOperationCount(findFunction(enabled.optimized_ir, requirement.unproven_add) orelse
        return error.ContractFunctionMissing);
    const disabled_unproven = checkedOperationCount(findFunction(disabled.optimized_ir, requirement.unproven_add) orelse
        return error.ContractFunctionMissing);
    if (enabled_proven >= disabled_proven) return error.ExpectedRangeCounterEvidenceMissing;
    if (enabled_unproven == 0 or disabled_unproven == 0) return error.UnprovenOverflowCheckRemoved;
    return .{
        .enabled_proven_checks = enabled_proven,
        .disabled_proven_checks = disabled_proven,
        .enabled_unproven_checks = enabled_unproven,
        .disabled_unproven_checks = disabled_unproven,
    };
}

fn rangeProofChecks(requirement: anytype, program: Silex.Ir.Program) !usize {
    const add = findFunction(program, requirement.bounded_add) orelse return error.ContractFunctionMissing;
    const subtract = findFunction(program, requirement.bounded_subtract) orelse return error.ContractFunctionMissing;
    const conversion = findFunction(program, requirement.bounded_conversion) orelse return error.ContractFunctionMissing;
    const loop = findFunction(program, requirement.bounded_loop) orelse return error.ContractFunctionMissing;
    return checkedOperationCount(add) + checkedOperationCount(subtract) + checkedOperationCount(conversion) +
        checkedOperationCount(loop);
}

fn checkedOperationCount(function: Silex.Ir.Function) usize {
    var count: usize = 0;
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .binary => |binary| count += @intFromBool(binary.checked and (binary.operator == .add or binary.operator == .subtract or binary.operator == .multiply)),
        .convert => |conversion| count += @intFromBool(conversion.checked),
        else => {},
    };
    return count;
}

fn verifyCriticalEdgePromotion(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw_function = findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const optimized_function = findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const raw = IrStats.countFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const optimized = IrStats.countFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const raw_local_operations = localOperationCount(raw_function);
    const optimized_local_operations = localOperationCount(optimized_function);
    if (raw_local_operations == 0 or optimized_local_operations >= raw_local_operations)
        return error.ExpectedCriticalEdgePromotionMissing;
    if (optimized.blocks > raw.blocks) return error.UnprofitableCriticalEdgeSplit;
    return .{ .critical_edge = .{
        .function = function_name,
        .raw_local_operations = raw_local_operations,
        .optimized_local_operations = optimized_local_operations,
        .raw_blocks = raw.blocks,
        .optimized_blocks = optimized.blocks,
    } };
}

pub fn verifySsaPromotionCounter(
    function_name: []const u8,
    enabled: Differential.Result,
    disabled: Differential.Result,
) !SsaPromotionCounter {
    const enabled_function = findFunction(enabled.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const disabled_function = findFunction(disabled.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const enabled_profile = IrStats.countFunction(enabled.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const disabled_profile = IrStats.countFunction(disabled.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const enabled_local_operations = localOperationCount(enabled_function);
    const disabled_local_operations = localOperationCount(disabled_function);
    if (enabled_local_operations >= disabled_local_operations)
        return error.ExpectedCriticalEdgeCounterEvidenceMissing;
    if (enabled_profile.blocks > disabled_profile.blocks)
        return error.UnprofitableCriticalEdgeSplit;
    return .{
        .function = function_name,
        .enabled_local_operations = enabled_local_operations,
        .disabled_local_operations = disabled_local_operations,
        .enabled_blocks = enabled_profile.blocks,
        .disabled_blocks = disabled_profile.blocks,
    };
}

fn localOperationCount(function: Silex.Ir.Function) usize {
    var count: usize = 0;
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .local_load, .local_store => count += 1,
        else => {},
    };
    return count;
}

const SsaValueProfile = struct {
    branches: usize = 0,
    arithmetic: usize = 0,
};

fn verifySsaValueSimplification(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw_function = findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const optimized_function = findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const raw = ssaValueProfile(raw_function);
    const optimized = ssaValueProfile(optimized_function);
    if (raw.branches == 0 or optimized.branches >= raw.branches)
        return error.ExpectedSsaBranchReductionMissing;
    if (raw.arithmetic == 0 or optimized.arithmetic >= raw.arithmetic)
        return error.ExpectedSsaArithmeticReductionMissing;
    return .{ .ssa_values = .{
        .function = function_name,
        .raw_branches = raw.branches,
        .optimized_branches = optimized.branches,
        .raw_arithmetic = raw.arithmetic,
        .optimized_arithmetic = optimized.arithmetic,
    } };
}

pub fn verifySsaValueCounter(
    function_name: []const u8,
    enabled: Differential.Result,
    disabled: Differential.Result,
) !SsaValueCounter {
    const enabled_function = findFunction(enabled.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const disabled_function = findFunction(disabled.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const enabled_profile = ssaValueProfile(enabled_function);
    const disabled_profile = ssaValueProfile(disabled_function);
    if (enabled_profile.branches >= disabled_profile.branches)
        return error.ExpectedSsaBranchCounterEvidenceMissing;
    if (enabled_profile.arithmetic >= disabled_profile.arithmetic)
        return error.ExpectedSsaArithmeticCounterEvidenceMissing;
    return .{
        .function = function_name,
        .enabled_branches = enabled_profile.branches,
        .disabled_branches = disabled_profile.branches,
        .enabled_arithmetic = enabled_profile.arithmetic,
        .disabled_arithmetic = disabled_profile.arithmetic,
    };
}

fn ssaValueProfile(function: Silex.Ir.Function) SsaValueProfile {
    var result: SsaValueProfile = .{};
    for (function.blocks) |block| {
        if (block.terminator == .branch) result.branches += 1;
        for (block.instructions) |instruction| if (instruction == .binary) {
            result.arithmetic += 1;
        };
    }
    return result;
}

const ScalarLoopProfile = struct {
    collection_loads: usize = 0,
    calls: usize = 0,
};

fn verifyDenseScalarLoop(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw_function = findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const optimized_function = findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const raw = scalarLoopProfile(raw_function);
    const optimized = scalarLoopProfile(optimized_function);
    if (raw.collection_loads == 0 or optimized.collection_loads >= raw.collection_loads)
        return error.ExpectedCollectionLoadReductionMissing;
    if (raw.calls == 0 or optimized.calls >= raw.calls)
        return error.ExpectedDenseLoopInliningMissing;
    return .{ .scalar_loop = .{
        .function = function_name,
        .raw_collection_loads = raw.collection_loads,
        .optimized_collection_loads = optimized.collection_loads,
        .raw_calls = raw.calls,
        .optimized_calls = optimized.calls,
    } };
}

fn scalarLoopProfile(function: Silex.Ir.Function) ScalarLoopProfile {
    var result: ScalarLoopProfile = .{};
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .collection_load => result.collection_loads += 1,
        .call, .indirect_call, .boundary_call, .dynamic_call => result.calls += 1,
        else => {},
    };
    return result;
}

fn verifyCollectionBounds(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw_function = findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const optimized_function = findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const raw = checkedCollectionLoads(raw_function);
    const optimized = checkedCollectionLoads(optimized_function);
    if (raw == 0 or optimized >= raw) return error.ExpectedCollectionBoundsRemovalMissing;
    return .{ .bounds = .{
        .function = function_name,
        .raw = raw,
        .optimized = optimized,
    } };
}

fn checkedCollectionLoads(function: Silex.Ir.Function) usize {
    var count: usize = 0;
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .collection_load => |load| if (load.checked) {
            count += 1;
        },
        else => {},
    };
    return count;
}

fn verifyBlockReduction(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw = IrStats.countFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const optimized = IrStats.countFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    if (optimized.blocks >= raw.blocks) return error.ExpectedBlockReductionMissing;
    return .{ .blocks = .{
        .function = function_name,
        .raw = raw.blocks,
        .optimized = optimized.blocks,
    } };
}

fn verifySlp(
    allocator: std.mem.Allocator,
    function_name: []const u8,
    minimum: u3,
    native_pair: bool,
    program: Silex.Ir.Program,
) !Evidence {
    const function = findFunction(program, function_name) orelse return error.ContractFunctionMissing;
    const plan = try Silex.Slp.analyze(allocator, function);
    var observed: u3 = 0;
    for (plan.groups) |group| observed = @max(observed, group.width);
    if (observed < minimum) return error.ExpectedSlpWidthMissing;
    const arm64_program = try Silex.Arm64Lower.lowerWithMode(allocator, program, .release);
    const arm64_function = findMachineFunction(arm64_program, function_name) orelse
        return error.ContractFunctionMissing;
    var arm64_pairs: usize = 0;
    for (arm64_function.float_lane_slots) |residence| {
        if (residence) |lane| if (lane.lane == 0) {
            arm64_pairs += 1;
        };
    }
    const stack_program = try Silex.Arm64Lower.lowerWithMode(allocator, program, .debug);
    const x64_program = try Silex.X64RegisterAllocation.allocateProgram(allocator, stack_program);
    const x64_function = findMachineFunction(x64_program, function_name) orelse
        return error.ContractFunctionMissing;
    var x64_pairs: usize = 0;
    for (x64_function.float_lane_slots) |residence| {
        if (residence) |lane| if (lane.lane == 0) {
            x64_pairs += 1;
        };
    }
    if (native_pair and (arm64_pairs == 0 or x64_pairs == 0)) return error.ExpectedNativeLanePairMissing;
    return .{ .slp = .{
        .function = function_name,
        .required = minimum,
        .observed = observed,
        .native_required = native_pair,
        .arm64_pairs = arm64_pairs,
        .x64_pairs = x64_pairs,
    } };
}

fn findMachineFunction(
    program: Silex.Arm64Machine.Program,
    name: []const u8,
) ?Silex.Arm64Machine.Function {
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, name)) return function;
    }
    return null;
}

fn findFunction(program: Silex.Ir.Program, name: []const u8) ?Silex.Ir.Function {
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, name)) return function;
    }
    return null;
}
