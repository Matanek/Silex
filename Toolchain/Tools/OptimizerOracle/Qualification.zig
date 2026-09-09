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
    aggregate_scalarization: struct {
        function: []const u8,
        raw_operations: usize,
        optimized_operations: usize,
    },
    reference_memory: struct {
        overwritten: []const u8,
        observed: []const u8,
        raw_overwritten_stores: usize,
        optimized_overwritten_stores: usize,
        optimized_observed_loads: usize,
        optimized_observed_stores: usize,
    },
    view_memory: struct {
        function: []const u8,
        raw_loads: usize,
        optimized_loads: usize,
        raw_stores: usize,
        optimized_stores: usize,
        optimized_guards: usize,
    },
    owning_collection: struct {
        function: []const u8,
        raw_loads: usize,
        optimized_loads: usize,
        optimized_stores: usize,
        optimized_guards: usize,
    },
    ssa_values: struct {
        function: []const u8,
        raw_branches: usize,
        optimized_branches: usize,
        raw_arithmetic: usize,
        optimized_arithmetic: usize,
    },
    integer_conversions: struct {
        function: []const u8,
        raw_conversions: usize,
        optimized_conversions: usize,
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
        bounded_shift: []const u8,
        bounded_loop: []const u8,
        raw_proven_checks: usize,
        optimized_proven_checks: usize,
        optimized_unproven_checks: usize,
    },
    call_specialization: struct {
        function: []const u8,
        raw_calls: usize,
        optimized_calls: usize,
        raw_reference_stores: usize,
        optimized_reference_stores: usize,
    },
    slp: struct {
        function: []const u8,
        required: u3,
        observed: u3,
        arm64_required: bool,
        x64_required: bool,
        arm64_pairs: usize,
        x64_pairs: usize,
    },
    loop_cursor: struct {
        function: []const u8,
        postindexed: bool,
        pointer_terminated: bool,
    },
    loop_residence: struct {
        function: []const u8,
        arm64_resident: usize,
        x64_resident: usize,
        total: usize,
    },
    x64_regional_budget: struct {
        function: []const u8,
        resident: usize,
        total: usize,
        stack_slots: usize,
        frame_slots: usize,
        frame_bytes: u32,
        direct_calls: usize,
        indirect_calls: usize,
        aggregate_barriers: usize,
        aggregate_width: usize,
        loop_stack_loads: usize,
        loop_stack_stores: usize,
    },
};

pub const SsaValueCounter = struct {
    function: []const u8,
    enabled_branches: usize,
    disabled_branches: usize,
    enabled_arithmetic: usize,
    disabled_arithmetic: usize,
};

pub const IntegerConversionCounter = struct {
    function: []const u8,
    enabled_conversions: usize,
    disabled_conversions: usize,
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

pub const MemoryCounter = struct {
    function: []const u8,
    enabled_operations: usize,
    disabled_operations: usize,
    enabled_guards: usize,
    disabled_guards: usize,
};

pub const CallCounter = struct {
    function: []const u8,
    enabled_calls: usize,
    disabled_calls: usize,
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
        .scalarizes_aggregate => |function_name| verifyAggregateScalarization(function_name, differential),
        .elides_reference_memory => |requirement| verifyReferenceMemory(requirement, differential),
        .coalesces_view_memory => |function_name| verifyViewMemory(function_name, differential),
        .forwards_owning_collection => |function_name| verifyOwningCollection(function_name, differential),
        .simplifies_ssa_values => |function_name| verifySsaValueSimplification(function_name, differential),
        .promotes_critical_edge => |function_name| verifyCriticalEdgePromotion(function_name, differential),
        .coalesces_forwarded_phi => |function_name| verifyCriticalEdgePromotion(function_name, differential),
        .promotes_distinct_phis => |function_name| verifyCriticalEdgePromotion(function_name, differential),
        .folds_integer_conversions => |function_name| verifyIntegerConversionFolding(function_name, differential),
        .proves_integer_ranges => |requirement| verifyIntegerRanges(requirement, differential),
        .specializes_effectful_calls => |function_name| verifyCallSpecialization(function_name, differential),
        .specializes_branching_reference_calls => |function_name| verifyBranchingReferenceCallSpecialization(
            function_name,
            differential,
        ),
        .slp_width => |requirement| try verifySlp(
            allocator,
            requirement.function,
            requirement.minimum,
            requirement.arm64_pair,
            requirement.x64_pair,
            differential.optimized_ir,
        ),
        .arm64_loop_cursor => |requirement| try verifyArm64LoopCursor(
            allocator,
            requirement.function,
            requirement.pointer_terminated,
            differential.optimized_ir,
        ),
        .native_loop_residence => |requirement| try verifyNativeLoopResidence(
            allocator,
            requirement.function,
            requirement.arm64_minimum,
            requirement.x64_minimum,
            differential.optimized_ir,
        ),
        .x64_regional_budget => |requirement| try verifyX64RegionalBudget(
            allocator,
            requirement.function,
            requirement.minimum_resident,
            requirement.stack_slots,
            requirement.frame_bytes,
            requirement.direct_calls,
            requirement.indirect_calls,
            requirement.aggregate_width,
            requirement.loop_stack_loads,
            requirement.loop_stack_stores,
            differential.optimized_ir,
        ),
    };
}

fn verifyCallSpecialization(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw = IrStats.profile(.{ .functions = &.{findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    const raw_closure = IrStats.profile(differential.raw_ir);
    const optimized = IrStats.profile(.{ .functions = &.{findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    if (raw.internal_calls < 2 or optimized.internal_calls != 0)
        return error.ExpectedEffectfulCallSpecializationMissing;
    if (raw_closure.reference_stores == 0 or optimized.reference_stores != 0)
        return error.InlinedReferenceEffectNotScalarized;
    return .{ .call_specialization = .{
        .function = function_name,
        .raw_calls = raw.internal_calls,
        .optimized_calls = optimized.internal_calls,
        .raw_reference_stores = raw_closure.reference_stores,
        .optimized_reference_stores = optimized.reference_stores,
    } };
}

fn verifyBranchingReferenceCallSpecialization(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw = IrStats.profile(.{ .functions = &.{findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    const raw_closure = IrStats.profile(differential.raw_ir);
    const optimized = IrStats.profile(.{ .functions = &.{findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    if (raw.internal_calls == 0 or optimized.internal_calls != 0)
        return error.ExpectedEffectfulCallSpecializationMissing;
    if (raw_closure.reference_stores == 0)
        return error.ExpectedReferenceEffectMissing;
    return .{ .call_specialization = .{
        .function = function_name,
        .raw_calls = raw.internal_calls,
        .optimized_calls = optimized.internal_calls,
        .raw_reference_stores = raw_closure.reference_stores,
        .optimized_reference_stores = optimized.reference_stores,
    } };
}

pub fn verifyCallCounter(
    function_name: []const u8,
    enabled: Differential.Result,
    disabled: Differential.Result,
) !CallCounter {
    const enabled_profile = IrStats.profile(.{ .functions = &.{findFunction(
        enabled.optimized_ir,
        function_name,
    ) orelse return error.ContractFunctionMissing} });
    const disabled_profile = IrStats.profile(.{ .functions = &.{findFunction(
        disabled.optimized_ir,
        function_name,
    ) orelse return error.ContractFunctionMissing} });
    if (enabled_profile.internal_calls >= disabled_profile.internal_calls)
        return error.ExpectedCallCounterEvidenceMissing;
    return .{
        .function = function_name,
        .enabled_calls = enabled_profile.internal_calls,
        .disabled_calls = disabled_profile.internal_calls,
    };
}

fn verifyAggregateScalarization(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw = IrStats.profile(.{ .functions = &.{findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    const optimized = IrStats.profile(.{ .functions = &.{findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    if (raw.value_aggregate_operations == 0 or
        optimized.value_aggregate_operations >= raw.value_aggregate_operations)
        return error.ExpectedAggregateScalarizationMissing;
    return .{ .aggregate_scalarization = .{
        .function = function_name,
        .raw_operations = raw.value_aggregate_operations,
        .optimized_operations = optimized.value_aggregate_operations,
    } };
}

fn verifyReferenceMemory(requirement: anytype, differential: Differential.Result) !Evidence {
    const raw_overwritten = IrStats.profile(.{ .functions = &.{findFunction(
        differential.raw_ir,
        requirement.overwritten,
    ) orelse return error.ContractFunctionMissing} });
    const optimized_overwritten = IrStats.profile(.{ .functions = &.{findFunction(
        differential.optimized_ir,
        requirement.overwritten,
    ) orelse return error.ContractFunctionMissing} });
    const optimized_observed = IrStats.profile(.{ .functions = &.{findFunction(
        differential.optimized_ir,
        requirement.observed,
    ) orelse return error.ContractFunctionMissing} });
    if (raw_overwritten.reference_stores < 2 or
        optimized_overwritten.reference_stores >= raw_overwritten.reference_stores)
        return error.ExpectedReferenceDeadStoreElisionMissing;
    if (optimized_observed.reference_loads == 0 or optimized_observed.reference_stores < 2)
        return error.PossiblyAliasingReferenceObservationRemoved;
    return .{ .reference_memory = .{
        .overwritten = requirement.overwritten,
        .observed = requirement.observed,
        .raw_overwritten_stores = raw_overwritten.reference_stores,
        .optimized_overwritten_stores = optimized_overwritten.reference_stores,
        .optimized_observed_loads = optimized_observed.reference_loads,
        .optimized_observed_stores = optimized_observed.reference_stores,
    } };
}

fn verifyViewMemory(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw = IrStats.profile(.{ .functions = &.{findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    const optimized = IrStats.profile(.{ .functions = &.{findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    if (raw.other_loads == 0 or optimized.other_loads >= raw.other_loads or
        raw.other_stores < 2 or optimized.other_stores >= raw.other_stores)
        return error.ExpectedViewMemoryCoalescingMissing;
    if (optimized.other_stores == 0 or optimized.safety_guards == 0)
        return error.ObservableViewMutationOrBoundsGuardRemoved;
    return .{ .view_memory = .{
        .function = function_name,
        .raw_loads = raw.other_loads,
        .optimized_loads = optimized.other_loads,
        .raw_stores = raw.other_stores,
        .optimized_stores = optimized.other_stores,
        .optimized_guards = optimized.safety_guards,
    } };
}

fn verifyOwningCollection(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw = IrStats.profile(.{ .functions = &.{findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    const optimized = IrStats.profile(.{ .functions = &.{findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing} });
    if (raw.other_loads < 2 or optimized.other_loads != 0)
        return error.ExpectedOwningCollectionForwardingMissing;
    if (optimized.other_stores != 1 or optimized.safety_guards != 0)
        return error.OwningCollectionMutationContractChanged;
    return .{ .owning_collection = .{
        .function = function_name,
        .raw_loads = raw.other_loads,
        .optimized_loads = optimized.other_loads,
        .optimized_stores = optimized.other_stores,
        .optimized_guards = optimized.safety_guards,
    } };
}

pub fn verifyMemoryCounter(
    function_name: []const u8,
    enabled: Differential.Result,
    disabled: Differential.Result,
) !MemoryCounter {
    const enabled_profile = IrStats.profile(.{ .functions = &.{findFunction(
        enabled.optimized_ir,
        function_name,
    ) orelse return error.ContractFunctionMissing} });
    const disabled_profile = IrStats.profile(.{ .functions = &.{findFunction(
        disabled.optimized_ir,
        function_name,
    ) orelse return error.ContractFunctionMissing} });
    const enabled_operations = enabled_profile.other_loads + enabled_profile.other_stores;
    const disabled_operations = disabled_profile.other_loads + disabled_profile.other_stores;
    if (enabled_operations >= disabled_operations) return error.ExpectedMemoryCounterEvidenceMissing;
    if (enabled_profile.safety_guards > disabled_profile.safety_guards)
        return error.MemoryOptimizationIntroducedSafetyGuard;
    return .{
        .function = function_name,
        .enabled_operations = enabled_operations,
        .disabled_operations = disabled_operations,
        .enabled_guards = enabled_profile.safety_guards,
        .disabled_guards = disabled_profile.safety_guards,
    };
}

const IntegerConversionProfile = struct {
    conversions: usize = 0,
    arithmetic: usize = 0,
};

fn verifyIntegerConversionFolding(function_name: []const u8, differential: Differential.Result) !Evidence {
    const raw_function = findFunction(differential.raw_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const optimized_function = findFunction(differential.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const raw = integerConversionProfile(raw_function);
    const optimized = integerConversionProfile(optimized_function);
    if (raw.conversions == 0 or optimized.conversions >= raw.conversions)
        return error.ExpectedIntegerConversionReductionMissing;
    if (raw.arithmetic == 0 or optimized.arithmetic >= raw.arithmetic)
        return error.ExpectedConvertedArithmeticReductionMissing;
    return .{ .integer_conversions = .{
        .function = function_name,
        .raw_conversions = raw.conversions,
        .optimized_conversions = optimized.conversions,
        .raw_arithmetic = raw.arithmetic,
        .optimized_arithmetic = optimized.arithmetic,
    } };
}

pub fn verifyIntegerConversionCounter(
    function_name: []const u8,
    enabled: Differential.Result,
    disabled: Differential.Result,
) !IntegerConversionCounter {
    const enabled_function = findFunction(enabled.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const disabled_function = findFunction(disabled.optimized_ir, function_name) orelse
        return error.ContractFunctionMissing;
    const enabled_profile = integerConversionProfile(enabled_function);
    const disabled_profile = integerConversionProfile(disabled_function);
    if (enabled_profile.conversions >= disabled_profile.conversions)
        return error.ExpectedIntegerConversionCounterEvidenceMissing;
    if (enabled_profile.arithmetic >= disabled_profile.arithmetic)
        return error.ExpectedConvertedArithmeticCounterEvidenceMissing;
    return .{
        .function = function_name,
        .enabled_conversions = enabled_profile.conversions,
        .disabled_conversions = disabled_profile.conversions,
        .enabled_arithmetic = enabled_profile.arithmetic,
        .disabled_arithmetic = disabled_profile.arithmetic,
    };
}

fn integerConversionProfile(function: Silex.Ir.Function) IntegerConversionProfile {
    var result: IntegerConversionProfile = .{};
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .convert => result.conversions += 1,
        .binary, .unary => result.arithmetic += 1,
        else => {},
    };
    return result;
}

fn verifyIntegerRanges(requirement: anytype, differential: Differential.Result) !Evidence {
    const raw_add = findFunction(differential.raw_ir, requirement.bounded_add) orelse
        return error.ContractFunctionMissing;
    const raw_subtract = findFunction(differential.raw_ir, requirement.bounded_subtract) orelse
        return error.ContractFunctionMissing;
    const raw_conversion = findFunction(differential.raw_ir, requirement.bounded_conversion) orelse
        return error.ContractFunctionMissing;
    const raw_shift = findFunction(differential.raw_ir, requirement.bounded_shift) orelse
        return error.ContractFunctionMissing;
    const raw_loop = findFunction(differential.raw_ir, requirement.bounded_loop) orelse
        return error.ContractFunctionMissing;
    const optimized_add = findFunction(differential.optimized_ir, requirement.bounded_add) orelse
        return error.ContractFunctionMissing;
    const optimized_subtract = findFunction(differential.optimized_ir, requirement.bounded_subtract) orelse
        return error.ContractFunctionMissing;
    const optimized_conversion = findFunction(differential.optimized_ir, requirement.bounded_conversion) orelse
        return error.ContractFunctionMissing;
    const optimized_shift = findFunction(differential.optimized_ir, requirement.bounded_shift) orelse
        return error.ContractFunctionMissing;
    const optimized_loop = findFunction(differential.optimized_ir, requirement.bounded_loop) orelse
        return error.ContractFunctionMissing;
    const optimized_unproven = findFunction(differential.optimized_ir, requirement.unproven_add) orelse
        return error.ContractFunctionMissing;
    const raw_proven = checkedOperationCount(raw_add) + checkedOperationCount(raw_subtract) +
        checkedOperationCount(raw_conversion) + checkedOperationCount(raw_shift) + checkedOperationCount(raw_loop);
    const optimized_proven = checkedOperationCount(optimized_add) + checkedOperationCount(optimized_subtract) +
        checkedOperationCount(optimized_conversion) + checkedOperationCount(optimized_shift) +
        checkedOperationCount(optimized_loop);
    const unproven = checkedOperationCount(optimized_unproven);
    if (raw_proven < 6 or optimized_proven != 0) return error.ExpectedRangeProofMissing;
    if (unproven == 0) return error.UnprovenOverflowCheckRemoved;
    return .{ .integer_ranges = .{
        .bounded_add = requirement.bounded_add,
        .bounded_subtract = requirement.bounded_subtract,
        .bounded_conversion = requirement.bounded_conversion,
        .bounded_shift = requirement.bounded_shift,
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
    const shift = findFunction(program, requirement.bounded_shift) orelse return error.ContractFunctionMissing;
    const loop = findFunction(program, requirement.bounded_loop) orelse return error.ContractFunctionMissing;
    return checkedOperationCount(add) + checkedOperationCount(subtract) + checkedOperationCount(conversion) +
        checkedOperationCount(shift) + checkedOperationCount(loop);
}

fn checkedOperationCount(function: Silex.Ir.Function) usize {
    var count: usize = 0;
    for (function.blocks) |block| for (block.instructions) |instruction| switch (instruction) {
        .binary => |binary| count += @intFromBool(binary.checked and switch (binary.operator) {
            .add, .subtract, .multiply, .divide, .remainder, .shift_left, .shift_right => true,
            else => false,
        }),
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
    arm64_pair: bool,
    x64_pair: bool,
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
    if (arm64_pair and arm64_pairs == 0) return error.ExpectedArm64LanePairMissing;
    if (x64_pair and x64_pairs == 0) return error.ExpectedX64LanePairMissing;
    return .{ .slp = .{
        .function = function_name,
        .required = minimum,
        .observed = observed,
        .arm64_required = arm64_pair,
        .x64_required = x64_pair,
        .arm64_pairs = arm64_pairs,
        .x64_pairs = x64_pairs,
    } };
}

fn verifyArm64LoopCursor(
    allocator: std.mem.Allocator,
    function_name: []const u8,
    require_pointer_termination: bool,
    program: Silex.Ir.Program,
) !Evidence {
    const arm64_program = try Silex.Arm64Lower.lowerWithMode(allocator, program, .release);
    const function = findMachineFunction(arm64_program, function_name) orelse
        return error.ContractFunctionMissing;
    const cursor = (try Silex.Arm64LoopCursor.find(allocator, function)) orelse
        return error.ExpectedArm64LoopCursorMissing;
    const pointer_terminated = cursor.termination != null;
    if (require_pointer_termination and !pointer_terminated)
        return error.ExpectedArm64PointerTerminationMissing;
    return .{ .loop_cursor = .{
        .function = function_name,
        .postindexed = true,
        .pointer_terminated = pointer_terminated,
    } };
}

fn verifyNativeLoopResidence(
    allocator: std.mem.Allocator,
    function_name: []const u8,
    arm64_minimum: u16,
    x64_minimum: u16,
    program: Silex.Ir.Program,
) !Evidence {
    const arm64_program = try Silex.Arm64Lower.lowerWithMode(allocator, program, .release);
    const arm64_function = findMachineFunction(arm64_program, function_name) orelse
        return error.ContractFunctionMissing;
    var arm64_resident: usize = 0;
    for (arm64_function.register_slots) |residence| arm64_resident += @intFromBool(residence != null);
    if (arm64_resident < arm64_minimum) return error.ExpectedArm64LoopResidenceMissing;

    const stack_program = try Silex.Arm64Lower.lowerWithMode(allocator, program, .debug);
    const x64_program = try Silex.X64RegisterAllocation.allocateProgram(allocator, stack_program);
    const x64_function = findMachineFunction(x64_program, function_name) orelse
        return error.ContractFunctionMissing;
    var x64_resident: usize = 0;
    for (x64_function.register_slots) |residence| x64_resident += @intFromBool(residence != null);
    if (x64_resident < x64_minimum) return error.ExpectedX64LoopResidenceMissing;

    return .{ .loop_residence = .{
        .function = function_name,
        .arm64_resident = arm64_resident,
        .x64_resident = x64_resident,
        .total = arm64_function.slot_count,
    } };
}

fn verifyX64RegionalBudget(
    allocator: std.mem.Allocator,
    function_name: []const u8,
    minimum_resident: u16,
    expected_stack_slots: u16,
    expected_frame_bytes: u32,
    expected_direct_calls: u16,
    expected_indirect_calls: u16,
    expected_aggregate_width: u16,
    expected_loop_stack_loads: u16,
    expected_loop_stack_stores: u16,
    program: Silex.Ir.Program,
) !Evidence {
    const stack_program = try Silex.Arm64Lower.lowerWithMode(allocator, program, .debug);
    const x64_program = try Silex.X64RegisterAllocation.allocateProgram(allocator, stack_program);
    const function = findMachineFunction(x64_program, function_name) orelse
        return error.ContractFunctionMissing;
    var resident: usize = 0;
    for (function.register_slots) |residence| resident += @intFromBool(residence != null);
    if (resident < minimum_resident) return error.ExpectedX64LoopResidenceMissing;

    var direct_calls: usize = 0;
    var indirect_calls: usize = 0;
    var aggregate_barriers: usize = 0;
    var aggregate_width: usize = 0;
    for (function.instructions) |instruction| switch (instruction) {
        .call => direct_calls += 1,
        .indirect_call => indirect_calls += 1,
        .copy_range => aggregate_barriers += 1,
        .aggregate_init => |value| {
            aggregate_barriers += 1;
            aggregate_width += value.result.width;
        },
        else => {},
    };
    if (direct_calls != expected_direct_calls or indirect_calls != expected_indirect_calls)
        return error.X64CallBarrierMismatch;
    if (aggregate_barriers == 0) return error.ExpectedX64AggregateBarrierMissing;
    if (aggregate_width != expected_aggregate_width) return error.X64AggregateWidthMismatch;

    const loop_traffic = try profileX64LoopStackTraffic(allocator, function);
    if (loop_traffic.loads != expected_loop_stack_loads or loop_traffic.stores != expected_loop_stack_stores)
        return error.X64LoopStackTrafficMismatch;

    const stack_slots = @as(usize, function.slot_count) - resident;
    if (stack_slots != expected_stack_slots or function.frame_size != expected_frame_bytes) {
        std.debug.print(
            "X64 regional budget mismatch for {s}: {d} resident/{d}, {d} stack slots, stack base {d}, {d} frame bytes; stack homes",
            .{ function_name, resident, function.slot_count, stack_slots, function.stack_slot_base, function.frame_size },
        );
        for (function.register_slots, 0..) |residence, slot| {
            if (residence == null) std.debug.print(" {d}", .{slot});
        }
        std.debug.print("\n", .{});
        return error.X64RegionalBudgetMismatch;
    }
    return .{ .x64_regional_budget = .{
        .function = function_name,
        .resident = resident,
        .total = function.slot_count,
        .stack_slots = stack_slots,
        .frame_slots = @as(usize, function.slot_count) - function.stack_slot_base,
        .frame_bytes = function.frame_size,
        .direct_calls = direct_calls,
        .indirect_calls = indirect_calls,
        .aggregate_barriers = aggregate_barriers,
        .aggregate_width = aggregate_width,
        .loop_stack_loads = loop_traffic.loads,
        .loop_stack_stores = loop_traffic.stores,
    } };
}

const X64LoopStackTraffic = struct {
    loads: usize = 0,
    stores: usize = 0,
};

fn profileX64LoopStackTraffic(
    allocator: std.mem.Allocator,
    function: Silex.Arm64Machine.Function,
) !X64LoopStackTraffic {
    const in_loop = try allocator.alloc(bool, function.instructions.len);
    defer allocator.free(in_loop);
    @memset(in_loop, false);
    var found = false;
    for (function.instructions, 0..) |instruction, source| switch (instruction) {
        .jump => |target| if (target <= source) {
            @memset(in_loop[target .. source + 1], true);
            found = true;
        },
        .branch => |branch| {
            if (branch.then_instruction <= source) {
                @memset(in_loop[branch.then_instruction .. source + 1], true);
                found = true;
            }
            if (branch.else_instruction <= source) {
                @memset(in_loop[branch.else_instruction .. source + 1], true);
                found = true;
            }
        },
        else => {},
    };
    if (!found) return error.ExpectedX64LoopMissing;

    var result: X64LoopStackTraffic = .{};
    for (function.instructions, in_loop) |instruction, selected| {
        if (!selected) continue;
        switch (instruction) {
            .constant_int => |value| countStackStore(function, value.result, &result),
            .constant_bool => |value| countStackStore(function, value.result, &result),
            .copy => |value| {
                countStackLoad(function, value.operand, &result);
                countStackStore(function, value.result, &result);
            },
            .unary => |value| {
                countStackLoad(function, value.operand, &result);
                countStackStore(function, value.result, &result);
            },
            .binary => |value| {
                countStackLoad(function, value.left, &result);
                countStackLoad(function, value.right, &result);
                countStackStore(function, value.result, &result);
            },
            .return_value => |value| countStackLoad(function, value.start, &result),
            .branch => |value| countStackLoad(function, value.condition, &result),
            .return_void, .jump => {},
            else => return error.UnsupportedX64RegionalLoopInstruction,
        }
    }
    // This counts every possible value access of the regional instruction
    // set. A zero upper bound is therefore an exact zero even when a target
    // peephole elides a constant or reuses an operand.
    return result;
}

fn countStackLoad(
    function: Silex.Arm64Machine.Function,
    slot: Silex.Arm64Machine.Slot,
    traffic: *X64LoopStackTraffic,
) void {
    if (!hasX64Residence(function, slot)) traffic.loads += 1;
}

fn countStackStore(
    function: Silex.Arm64Machine.Function,
    slot: Silex.Arm64Machine.Slot,
    traffic: *X64LoopStackTraffic,
) void {
    if (!hasX64Residence(function, slot)) traffic.stores += 1;
}

fn hasX64Residence(function: Silex.Arm64Machine.Function, slot: Silex.Arm64Machine.Slot) bool {
    return function.register_slots.len != 0 and function.register_slots[slot] != null;
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
