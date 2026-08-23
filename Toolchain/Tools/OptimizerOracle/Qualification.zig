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
    slp: struct {
        function: []const u8,
        required: u3,
        observed: u3,
        native_required: bool,
        native_pairs: usize,
    },
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
        .slp_width => |requirement| try verifySlp(
            allocator,
            requirement.function,
            requirement.minimum,
            requirement.native_pair,
            differential.optimized_ir,
        ),
    };
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
    const machine_program = try Silex.Arm64Lower.lowerWithMode(allocator, program, .release);
    const machine_function = findMachineFunction(machine_program, function_name) orelse
        return error.ContractFunctionMissing;
    var native_pairs: usize = 0;
    for (machine_function.float_lane_slots) |residence| {
        if (residence) |lane| if (lane.lane == 0) {
            native_pairs += 1;
        };
    }
    if (native_pair and native_pairs == 0) return error.ExpectedNativeLanePairMissing;
    return .{ .slp = .{
        .function = function_name,
        .required = minimum,
        .observed = observed,
        .native_required = native_pair,
        .native_pairs = native_pairs,
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
