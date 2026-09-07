const std = @import("std");
const Silex = @import("silex_optimizer_api");
const IrStats = @import("IrStats.zig");
const Registry = @import("Registry.zig");
const Report = @import("Report.zig");

const output_directory = ".zig-cache/optimizer-oracle";

const MachineProfile = struct {
    instructions: usize = 0,
    stack_slots: usize = 0,
    frame_bytes: u32 = 0,
    calls: usize = 0,
    branches: usize = 0,
    collection_loads: usize = 0,
    reference_loads: usize = 0,
    simd_pairs: usize = 0,
    postindexed_cursors: usize = 0,
    pointer_terminated_cursors: usize = 0,
};

pub fn run(
    io: std.Io,
    allocator: std.mem.Allocator,
    environment: *const std.process.Environ.Map,
    registry: Registry.Manifest,
    source_path: []const u8,
    function_name: []const u8,
) !void {
    var compiler = Silex.Project.Compiler.init(allocator, io);
    if (environment.get("HOME") orelse environment.get("USERPROFILE")) |home| {
        if (Silex.Target.host()) |host| {
            const root = try std.fs.path.join(allocator, &.{ home, ".silex", "toolchain" });
            compiler.shadercross_path = try Silex.ToolchainSetup.executablePath(allocator, root, host);
        }
    }
    const compilation = compiler.compile(source_path) catch |err| {
        if (compiler.diagnostic) |diagnostic| {
            try Report.line(io, allocator, "hot-budget source rejected: {s}", .{diagnostic.message});
        }
        return err;
    };
    const root = findIrFunctionId(compilation.ir, function_name) orelse return error.ContractFunctionMissing;
    // Keep the selected function's transitive closure intact while optimizing.
    // Direct-call operands are function indices, so extracting one caller
    // invalidates retained calls. Optimizing the complete parsed package graph
    // is also incorrect because it contains deliberately unreachable generic
    // and backend variants that executable closure normally removes.
    const scope = try Silex.ProgramScope.close(allocator, compilation.ir, &.{root});
    const optimized = Silex.ReleaseOptimizer.optimizeWithOptions(allocator, scope.program, .{
        .verify_each_pass = true,
    }) catch |err| {
        try Report.line(io, allocator, "hot-budget optimizer rejected the selected function: {t}", .{err});
        try diagnoseVerifierFailure(io, allocator, scope.program);
        return err;
    };
    const function = findIrFunction(optimized, function_name) orelse return error.ContractFunctionMissing;
    const portable = IrStats.profile(.{ .functions = &.{function} });
    const field_loads = countFieldLoads(function);
    const machine_program = Silex.Arm64Lower.lowerWithModeAndBoundaries(
        allocator,
        optimized,
        compilation.boundaries,
        .release,
    ) catch |err| {
        try Report.line(io, allocator, "hot-budget ARM64 lowering rejected the program: {t}", .{err});
        return err;
    };
    const machine = findMachineFunction(machine_program, function_name) orelse return error.ContractFunctionMissing;
    var machine_profile = profileMachineFunction(machine);
    if (try Silex.Arm64LoopCursor.find(allocator, machine)) |cursor| {
        machine_profile.postindexed_cursors = 1;
        machine_profile.pointer_terminated_cursors = @intFromBool(cursor.termination != null);
    }
    const source_hash = try fileSha256(allocator, io, source_path);
    try Registry.validateHotMeasurement(registry, source_hash, function_name, .{
        .ir_field_loads = @intCast(field_loads),
        .ir_checked_operations = @intCast(portable.checked_operations),
        .machine_collection_loads = @intCast(machine_profile.collection_loads),
        .machine_calls = @intCast(machine_profile.calls),
        .machine_branches = @intCast(machine_profile.branches),
        .machine_stack_slots = @intCast(machine_profile.stack_slots),
        .machine_frame_bytes = machine_profile.frame_bytes,
        .machine_simd_xy_pairs = @intCast(machine_profile.simd_pairs),
        .machine_postindexed_cursors = @intCast(machine_profile.postindexed_cursors),
        .machine_pointer_terminated_cursors = @intCast(machine_profile.pointer_terminated_cursors),
    });
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    var report: std.Io.Writer.Allocating = .init(allocator);
    errdefer report.deinit();
    try report.writer.writeAll("source_sha256\tfunction\tir_instructions\tir_blocks\tir_local_loads\tir_local_stores\tir_other_loads\tir_field_loads\tir_other_stores\tir_calls\tir_branches\tir_checked\tmachine_instructions\tmachine_stack_slots\tmachine_frame_bytes\tmachine_calls\tmachine_branches\tmachine_collection_loads\tmachine_reference_loads\tmachine_simd_pairs\tmachine_postindexed_cursors\tmachine_pointer_terminated_cursors\n");
    try report.writer.print("{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n", .{
        source_hash,
        function_name,
        portable.counts.instructions,
        portable.counts.blocks,
        portable.local_loads,
        portable.local_stores,
        portable.other_loads,
        field_loads,
        portable.other_stores,
        portable.calls,
        portable.branches,
        portable.checked_operations,
        machine_profile.instructions,
        machine_profile.stack_slots,
        machine_profile.frame_bytes,
        machine_profile.calls,
        machine_profile.branches,
        machine_profile.collection_loads,
        machine_profile.reference_loads,
        machine_profile.simd_pairs,
        machine_profile.postindexed_cursors,
        machine_profile.pointer_terminated_cursors,
    });
    const report_path = output_directory ++ "/hot-budget.tsv";
    try writeFile(io, report_path, try report.toOwnedSlice());
    try Report.heading(io, allocator, "real-consumer hot-function budget");
    try Report.line(io, allocator, "  {s}: {d} IR instructions, {d} machine instructions", .{
        function_name,
        portable.counts.instructions,
        machine_profile.instructions,
    });
    try Report.line(io, allocator, "  loads: {d} collection, {d} reference; calls {d}; branches {d}", .{
        machine_profile.collection_loads,
        machine_profile.reference_loads,
        machine_profile.calls,
        machine_profile.branches,
    });
    try Report.line(io, allocator, "  residence: {d} stack slots, {d} frame bytes, {d} SIMD pairs", .{
        machine_profile.stack_slots,
        machine_profile.frame_bytes,
        machine_profile.simd_pairs,
    });
    try Report.line(io, allocator, "  loop cursors: {d} post-indexed, {d} pointer-terminated", .{
        machine_profile.postindexed_cursors,
        machine_profile.pointer_terminated_cursors,
    });
    try Report.line(io, allocator, "hot budget: {s}", .{report_path});
    try Report.line(io, allocator, "structural budget: accepted", .{});
}

fn countFieldLoads(function: Silex.Ir.Function) usize {
    var count: usize = 0;
    for (function.blocks) |block| for (block.instructions) |instruction| {
        if (instruction == .field_load) count += 1;
    };
    return count;
}

fn diagnoseVerifierFailure(io: std.Io, allocator: std.mem.Allocator, program: Silex.Ir.Program) !void {
    if (try reportFirstInvalidFunction(io, allocator, program, "input")) return;
    for (Silex.ReleaseOptimizer.pass_descriptors) |descriptor| {
        const prefix = try Silex.ReleaseOptimizer.optimizeWithOptions(allocator, program, .{
            .stop_after = descriptor.id,
        });
        if (try reportFirstInvalidFunction(io, allocator, prefix, @tagName(descriptor.id))) return;
    }
}

fn reportFirstInvalidFunction(
    io: std.Io,
    allocator: std.mem.Allocator,
    program: Silex.Ir.Program,
    stage: []const u8,
) !bool {
    for (program.functions) |function| {
        Silex.ReleaseVerifier.verifyFunction(allocator, program, function) catch |err| {
            try Report.line(io, allocator, "  verifier failure after {s}: {s}: {t}", .{
                stage,
                function.name,
                err,
            });
            if (err == error.InvalidProgram) {
                for (function.blocks, 0..) |block, block_index| {
                    for (block.instructions, 0..) |instruction, instruction_index| {
                        Silex.ReleaseVerifier.verifyInstructionType(program, function, instruction) catch |type_error| {
                            try Report.line(io, allocator, "    type contract bb{d} instruction {d} ({s}): {t}", .{
                                block_index,
                                instruction_index,
                                @tagName(instruction),
                                type_error,
                            });
                            return true;
                        };
                    }
                    Silex.ReleaseVerifier.verifyTerminatorType(function, block.terminator) catch |type_error| {
                        try Report.line(io, allocator, "    terminator contract bb{d} ({s}): {t}", .{
                            block_index,
                            @tagName(block.terminator),
                            type_error,
                        });
                        return true;
                    };
                }
            }
            return true;
        };
    }
    return false;
}

fn profileMachineFunction(function: Silex.Arm64Machine.Function) MachineProfile {
    var result: MachineProfile = .{
        .instructions = function.instructions.len,
        .stack_slots = function.slot_count,
        .frame_bytes = function.frame_size,
    };
    for (0..function.slot_count) |slot| {
        const scalar_resident = slot < function.register_slots.len and function.register_slots[slot] != null;
        const float_resident = slot < function.float_register_slots.len and function.float_register_slots[slot] != null;
        const lane_resident = slot < function.float_lane_slots.len and function.float_lane_slots[slot] != null;
        if ((scalar_resident or float_resident or lane_resident) and result.stack_slots != 0) result.stack_slots -= 1;
        if (lane_resident and function.float_lane_slots[slot].?.lane == 0) result.simd_pairs += 1;
    }
    for (function.instructions) |instruction| switch (instruction) {
        .call, .indirect_call, .external_call, .external_indirect_call, .dynamic_call => result.calls += 1,
        .branch, .jump => result.branches += 1,
        .collection_load => result.collection_loads += 1,
        .reference_load => result.reference_loads += 1,
        else => {},
    };
    return result;
}

fn findIrFunction(program: Silex.Ir.Program, name: []const u8) ?Silex.Ir.Function {
    for (program.functions) |function| if (std.mem.eql(u8, function.name, name)) return function;
    return null;
}

fn findIrFunctionId(program: Silex.Ir.Program, name: []const u8) ?Silex.Ir.FunctionId {
    for (program.functions, 0..) |function, function_id| {
        if (std.mem.eql(u8, function.name, name)) return function_id;
    }
    return null;
}

fn findMachineFunction(program: Silex.Arm64Machine.Program, name: []const u8) ?Silex.Arm64Machine.Function {
    for (program.functions) |function| if (std.mem.eql(u8, function.name, name)) return function;
    return null;
}

fn fileSha256(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]const u8 {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024));
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.allocPrint(allocator, "{s}", .{std.fmt.bytesToHex(digest, .lower)});
}

fn writeFile(io: std.Io, path: []const u8, bytes: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}
