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
        .slp_width => |requirement| try verifySlp(
            allocator,
            requirement.function,
            requirement.minimum,
            requirement.native_pair,
            differential.optimized_ir,
        ),
    };
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
