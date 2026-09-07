const std = @import("std");
const Silex = @import("silex_optimizer_api");
const Advisor = @import("Advisor.zig");
const Benchmark = @import("Benchmark.zig");
const Differential = @import("Differential.zig");
const Generator = @import("Generator.zig");
const HotBudget = @import("HotBudget.zig");
const IrStats = @import("IrStats.zig");
const Llvm = @import("Llvm.zig");
const LlvmStats = @import("LlvmStats.zig");
const Metamorphic = @import("Metamorphic.zig");
const Native = @import("Native.zig");
const NativeGenerator = @import("NativeGenerator.zig");
const Qualification = @import("Qualification.zig");
const Registry = @import("Registry.zig");
const Reducer = @import("Reducer.zig");
const Report = @import("Report.zig");

const usage =
    \\Usage: zig build optimizer-oracle -- <command> [options]
    \\
    \\Commands:
    \\  audit               Validate coverage, baselines, passes and LLVM pins
    \\  verify              Compare raw and Release IR through the interpreter
    \\  passes              List the stable Release pass registry
    \\  verify-prefix PASS  Verify the corpus through one Release pass
    \\  verify-without PASS Verify the corpus with exactly one pass disabled
    \\  cache-proof         Compare cold, primed and warm Release artifacts
    \\  metamorphic        Qualify equivalent source-shape variants
    \\  hot-budget SOURCE FUNCTION
    \\                      Profile one real Release function through ARM64 lowering
    \\  compare [samples]   Compare Silex Release with LLVM -O3 (default: 11)
    \\  fuzz [count] [seed] Generate deterministic typed numeric programs
    \\  fuzz-llvm [count] [seed]
    \\                      Execute generated programs through LLVM (default: 16)
    \\  qualify [count] [seed]
    \\                      Verify native Debug/Release regressions and generated scenarios
    \\  gate                Run the complete optimizer qualification before integration
    \\
    \\LLVM is a development oracle only. The Silex compiler never consumes its output.
    \\
;

const output_directory = ".zig-cache/optimizer-oracle";
const generated_source_directory = output_directory ++ "/SilexOptimizerOracle";

pub fn main(init: std.process.Init) u8 {
    return run(init) catch |err| {
        std.debug.print("optimizer oracle: {t}\n", .{err});
        return 1;
    };
}

fn run(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const arguments = try init.minimal.args.toSlice(allocator);
    if (arguments.len < 4 or isHelp(arguments[3])) {
        try std.Io.File.stdout().writeStreamingAll(init.io, usage);
        return 0;
    }
    const silex_binary = arguments[1];
    const corpus_directory = arguments[2];
    const command = arguments[3];
    const registry = try Registry.load(allocator, init.io, corpus_directory);
    try Registry.audit(registry);
    if (std.mem.eql(u8, command, "audit")) {
        if (arguments.len != 4) return error.InvalidArguments;
        try Registry.validateQualificationCorpus(allocator, init.io, registry, corpus_directory);
        try reportRegistry(init.io, allocator, registry);
        return 0;
    }
    if (std.mem.eql(u8, command, "verify")) {
        if (arguments.len != 4) return error.InvalidArguments;
        try verifyCorpus(init.io, allocator, corpus_directory);
        return 0;
    }
    if (std.mem.eql(u8, command, "passes")) {
        if (arguments.len != 4) return error.InvalidArguments;
        try reportPasses(init.io, allocator);
        return 0;
    }
    if (std.mem.eql(u8, command, "verify-prefix") or std.mem.eql(u8, command, "verify-without")) {
        if (arguments.len != 5) return error.InvalidArguments;
        const pass = Silex.ReleaseOptimizer.PassId.parse(arguments[4]) orelse return error.InvalidPass;
        const options: Silex.ReleaseOptimizer.Options = if (std.mem.eql(u8, command, "verify-prefix"))
            .{ .verify_each_pass = true, .stop_after = pass }
        else
            .{ .verify_each_pass = true, .disabled = pass };
        try verifyCorpusWithOptions(init.io, allocator, corpus_directory, options);
        return 0;
    }
    if (std.mem.eql(u8, command, "cache-proof")) {
        if (arguments.len != 4) return error.InvalidArguments;
        try verifyCacheReproducibility(init.io, allocator, silex_binary, corpus_directory);
        return 0;
    }
    if (std.mem.eql(u8, command, "metamorphic")) {
        if (arguments.len != 4) return error.InvalidArguments;
        try qualifyMetamorphic(init.io, allocator, silex_binary);
        return 0;
    }
    if (std.mem.eql(u8, command, "hot-budget")) {
        if (arguments.len != 6) return error.InvalidArguments;
        try HotBudget.run(init.io, allocator, init.environ_map, registry, arguments[4], arguments[5]);
        return 0;
    }
    if (std.mem.eql(u8, command, "compare")) {
        const samples = if (arguments.len == 5) try std.fmt.parseInt(usize, arguments[4], 10) else 11;
        if (arguments.len > 5 or samples < 5 or samples % 2 == 0) return error.InvalidArguments;
        try Registry.validateOracleEnvironment(allocator, init.io, registry.oracle);
        try compareCorpus(init.io, allocator, silex_binary, corpus_directory, registry.oracle, samples);
        return 0;
    }
    if (std.mem.eql(u8, command, "fuzz")) {
        const count = if (arguments.len >= 5) try std.fmt.parseInt(usize, arguments[4], 10) else 100;
        const seed = if (arguments.len >= 6) try std.fmt.parseInt(u64, arguments[5], 0) else 1;
        if (arguments.len > 6 or count == 0) return error.InvalidArguments;
        try fuzz(init.io, allocator, count, seed);
        return 0;
    }
    if (std.mem.eql(u8, command, "fuzz-llvm")) {
        const count = if (arguments.len >= 5) try std.fmt.parseInt(usize, arguments[4], 10) else 16;
        const seed = if (arguments.len >= 6) try std.fmt.parseInt(u64, arguments[5], 0) else 1;
        if (arguments.len > 6 or count == 0) return error.InvalidArguments;
        try Registry.validateOracleEnvironment(allocator, init.io, registry.oracle);
        try fuzzLlvm(init.io, allocator, registry.oracle, count, seed);
        return 0;
    }
    if (std.mem.eql(u8, command, "qualify")) {
        const count = if (arguments.len >= 5) try std.fmt.parseInt(usize, arguments[4], 10) else 8;
        const seed = if (arguments.len >= 6) try std.fmt.parseInt(u64, arguments[5], 0) else 1;
        if (arguments.len > 6 or count == 0) return error.InvalidArguments;
        try qualifyNative(init.io, allocator, silex_binary, corpus_directory, count, seed);
        return 0;
    }
    if (std.mem.eql(u8, command, "gate")) {
        if (arguments.len != 4) return error.InvalidArguments;
        try Registry.validateOracleEnvironment(allocator, init.io, registry.oracle);
        try Registry.validateQualificationCorpus(allocator, init.io, registry, corpus_directory);
        try reportRegistry(init.io, allocator, registry);
        try verifyCorpus(init.io, allocator, corpus_directory);
        try verifyCacheReproducibility(init.io, allocator, silex_binary, corpus_directory);
        try qualifyMetamorphic(init.io, allocator, silex_binary);
        try qualifyNative(init.io, allocator, silex_binary, corpus_directory, 8, 1);
        try fuzz(init.io, allocator, 128, 1);
        try fuzzLlvm(init.io, allocator, registry.oracle, 32, 1);
        try compareCorpus(init.io, allocator, silex_binary, corpus_directory, registry.oracle, 5);
        try Report.heading(init.io, allocator, "optimizer qualification gate passed");
        return 0;
    }
    std.debug.print("optimizer oracle: unknown command '{s}'\n\n{s}", .{ command, usage });
    return 1;
}

fn qualifyNative(
    io: std.Io,
    allocator: std.mem.Allocator,
    silex_binary: []const u8,
    corpus_directory: []const u8,
    generated_count: usize,
    initial_seed: u64,
) !void {
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    try Report.heading(io, allocator, "native optimizer regression qualification");
    for (Generator.regressions) |entry| {
        const source_path = try std.fs.path.join(allocator, &.{ corpus_directory, entry.name });
        const source = try std.Io.Dir.cwd().readFileAlloc(io, source_path, allocator, .limited(1024 * 1024));
        const differential = try Differential.verify(allocator, source);
        const evidence = try Qualification.verifyContract(allocator, entry.contract, differential);
        var ssa_counter: ?Qualification.SsaValueCounter = null;
        if (entry.contract == .simplifies_ssa_values) {
            const without = try Differential.verifyWithOptions(allocator, source, .{
                .verify_each_pass = true,
                .disabled = .ssa_value_simplification,
            });
            ssa_counter = try Qualification.verifySsaValueCounter(
                entry.contract.simplifies_ssa_values,
                differential,
                without,
            );
        }
        var conversion_counter: ?Qualification.IntegerConversionCounter = null;
        if (entry.contract == .folds_integer_conversions) {
            const without = try Differential.verifyWithOptions(allocator, source, .{
                .verify_each_pass = true,
                .disabled = .ssa_value_simplification,
            });
            conversion_counter = try Qualification.verifyIntegerConversionCounter(
                entry.contract.folds_integer_conversions,
                differential,
                without,
            );
        }
        var promotion_counter: ?Qualification.SsaPromotionCounter = null;
        const promotion_function: ?[]const u8 = switch (entry.contract) {
            .promotes_critical_edge => |function_name| function_name,
            .coalesces_forwarded_phi => |function_name| function_name,
            .promotes_distinct_phis => |function_name| function_name,
            else => null,
        };
        if (promotion_function) |function_name| {
            const without = try Differential.verifyWithOptions(allocator, source, .{
                .verify_each_pass = true,
                .disabled = .ssa_promotion_post,
            });
            promotion_counter = try Qualification.verifySsaPromotionCounter(
                function_name,
                differential,
                without,
            );
        }
        var range_counter: ?Qualification.IntegerRangeCounter = null;
        if (entry.contract == .proves_integer_ranges) {
            const without = try Differential.verifyWithOptions(allocator, source, .{
                .verify_each_pass = true,
                .disabled = .value_range_analysis,
            });
            range_counter = try Qualification.verifyIntegerRangeCounter(
                entry.contract.proves_integer_ranges,
                differential,
                without,
            );
        }
        var memory_counter: ?Qualification.MemoryCounter = null;
        const memory_function: ?[]const u8 = switch (entry.contract) {
            .elides_reference_memory => |requirement| requirement.overwritten,
            .coalesces_view_memory => |function_name| function_name,
            .forwards_owning_collection => |function_name| function_name,
            else => null,
        };
        if (memory_function) |function_name| {
            const without = try Differential.verifyWithOptions(allocator, source, .{
                .verify_each_pass = true,
                .disabled = .reference_memory_elision,
            });
            memory_counter = try Qualification.verifyMemoryCounter(function_name, differential, without);
        }
        var call_counter: ?Qualification.CallCounter = null;
        if (entry.contract == .specializes_effectful_calls) {
            const without = try Differential.verifyWithOptions(allocator, source, .{
                .verify_each_pass = true,
                .disabled = .value_inlining,
            });
            call_counter = try Qualification.verifyCallCounter(
                entry.contract.specializes_effectful_calls,
                differential,
                without,
            );
        }
        const stem = std.fs.path.stem(entry.name);
        const artifact_stem = try std.fmt.allocPrint(
            allocator,
            "{s}/regression-{s}",
            .{ output_directory, stem },
        );
        const native = try Native.verify(
            allocator,
            io,
            silex_binary,
            source_path,
            differential.execution,
            artifact_stem,
            true,
        );
        try Report.line(io, allocator, "  PASS {s}", .{entry.name});
        try Report.line(io, allocator, "    protects: {s}", .{entry.concern});
        try reportEvidence(io, allocator, evidence);
        if (ssa_counter) |counter| {
            try Report.line(
                io,
                allocator,
                "    counter: disabling ssa_value_simplification retains {d} branches and {d} arithmetic operation(s), versus {d} and {d}",
                .{
                    counter.disabled_branches,
                    counter.disabled_arithmetic,
                    counter.enabled_branches,
                    counter.enabled_arithmetic,
                },
            );
        }
        if (conversion_counter) |counter| {
            try Report.line(
                io,
                allocator,
                "    counter: disabling ssa_value_simplification retains {d} conversions and {d} arithmetic operation(s), versus {d} and {d}",
                .{
                    counter.disabled_conversions,
                    counter.disabled_arithmetic,
                    counter.enabled_conversions,
                    counter.enabled_arithmetic,
                },
            );
        }
        if (promotion_counter) |counter| {
            try Report.line(
                io,
                allocator,
                "    counter: disabling ssa_promotion_post retains {d} local operation(s) versus {d}, with blocks {d} versus {d}",
                .{
                    counter.disabled_local_operations,
                    counter.enabled_local_operations,
                    counter.disabled_blocks,
                    counter.enabled_blocks,
                },
            );
        }
        if (range_counter) |counter| {
            try Report.line(
                io,
                allocator,
                "    counter: disabling value_range_analysis retains {d} proven check(s) versus {d}; unproven checks remain {d}/{d}",
                .{
                    counter.disabled_proven_checks,
                    counter.enabled_proven_checks,
                    counter.disabled_unproven_checks,
                    counter.enabled_unproven_checks,
                },
            );
        }
        if (memory_counter) |counter| {
            try Report.line(
                io,
                allocator,
                "    counter: disabling reference_memory_elision retains {d} memory operation(s) versus {d} in {s}; guards {d}/{d}",
                .{
                    counter.disabled_operations,
                    counter.enabled_operations,
                    counter.function,
                    counter.disabled_guards,
                    counter.enabled_guards,
                },
            );
        }
        if (call_counter) |counter| {
            try Report.line(
                io,
                allocator,
                "    counter: disabling value_inlining retains {d} call(s) versus {d} in {s}",
                .{ counter.disabled_calls, counter.enabled_calls, counter.function },
            );
        }
        try Report.line(io, allocator, "    binaries: Debug {d} bytes, Release {d} bytes", .{
            native.debug_size.?,
            native.release_size,
        });
    }
    try qualifyGeneratedNative(io, allocator, silex_binary, generated_count, initial_seed);
    try Report.line(io, allocator, "qualified: {d} fixed regressions and {d} generated native scenarios", .{
        Generator.regressions.len,
        generated_count,
    });
}

fn qualifyGeneratedNative(
    io: std.Io,
    allocator: std.mem.Allocator,
    silex_binary: []const u8,
    count: usize,
    initial_seed: u64,
) !void {
    // Generated consumers own a package root: never inherit a manifest from
    // a shared temporary parent or collide with another worktree's campaign.
    try std.Io.Dir.cwd().createDirPath(io, generated_source_directory ++ "/Module");
    try writeFile(io, generated_source_directory ++ "/Package.json",
        \\{"name":"SilexOptimizerOracle","version":"0.0.0"}
    );
    for (0..count) |index| {
        const seed = initial_seed +% index;
        const source = try NativeGenerator.source(allocator, seed);
        const source_path = try std.fmt.allocPrint(
            allocator,
            "{s}/NativeScenario{d}.sx",
            .{ generated_source_directory, seed },
        );
        try writeFile(io, source_path, source);
        const differential = Differential.verify(allocator, source) catch |err| {
            try Report.line(io, allocator, "  FAIL generated native seed {d}: {s}", .{ seed, source_path });
            return err;
        };
        const artifact_stem = try std.fmt.allocPrint(
            allocator,
            "{s}/native-scenario-{d}",
            .{ output_directory, seed },
        );
        _ = Native.verify(
            allocator,
            io,
            silex_binary,
            source_path,
            differential.execution,
            artifact_stem,
            false,
        ) catch |err| {
            try Report.line(io, allocator, "  FAIL generated native seed {d}: {s}", .{ seed, source_path });
            return err;
        };
    }
}

fn reportEvidence(io: std.Io, allocator: std.mem.Allocator, evidence: Qualification.Evidence) !void {
    switch (evidence) {
        .none => {},
        .blocks => |blocks| try Report.line(
            io,
            allocator,
            "    contract: {s} blocks {d} -> {d}",
            .{ blocks.function, blocks.raw, blocks.optimized },
        ),
        .bounds => |bounds| try Report.line(
            io,
            allocator,
            "    contract: {s} checked collection loads {d} -> {d}",
            .{ bounds.function, bounds.raw, bounds.optimized },
        ),
        .scalar_loop => |scalar| try Report.line(
            io,
            allocator,
            "    contract: {s} collection loads {d} -> {d}, calls {d} -> {d}",
            .{
                scalar.function,
                scalar.raw_collection_loads,
                scalar.optimized_collection_loads,
                scalar.raw_calls,
                scalar.optimized_calls,
            },
        ),
        .aggregate_scalarization => |aggregate| try Report.line(
            io,
            allocator,
            "    contract: {s} value-aggregate operations {d} -> {d}",
            .{ aggregate.function, aggregate.raw_operations, aggregate.optimized_operations },
        ),
        .reference_memory => |memory| try Report.line(
            io,
            allocator,
            "    contract: {s} reference stores {d} -> {d}; {s} retains {d} load(s) and {d} store(s)",
            .{
                memory.overwritten,
                memory.raw_overwritten_stores,
                memory.optimized_overwritten_stores,
                memory.observed,
                memory.optimized_observed_loads,
                memory.optimized_observed_stores,
            },
        ),
        .view_memory => |memory| try Report.line(
            io,
            allocator,
            "    contract: {s} view loads {d} -> {d}, stores {d} -> {d}, {d} guard(s) retained",
            .{
                memory.function,
                memory.raw_loads,
                memory.optimized_loads,
                memory.raw_stores,
                memory.optimized_stores,
                memory.optimized_guards,
            },
        ),
        .owning_collection => |memory| try Report.line(
            io,
            allocator,
            "    contract: {s} owning loads {d} -> {d}, {d} mutation(s) and {d} guard(s) retained",
            .{
                memory.function,
                memory.raw_loads,
                memory.optimized_loads,
                memory.optimized_stores,
                memory.optimized_guards,
            },
        ),
        .ssa_values => |ssa| try Report.line(
            io,
            allocator,
            "    contract: {s} branches {d} -> {d}, arithmetic {d} -> {d}",
            .{
                ssa.function,
                ssa.raw_branches,
                ssa.optimized_branches,
                ssa.raw_arithmetic,
                ssa.optimized_arithmetic,
            },
        ),
        .integer_conversions => |conversion| try Report.line(
            io,
            allocator,
            "    contract: {s} conversions {d} -> {d}, arithmetic {d} -> {d}",
            .{
                conversion.function,
                conversion.raw_conversions,
                conversion.optimized_conversions,
                conversion.raw_arithmetic,
                conversion.optimized_arithmetic,
            },
        ),
        .critical_edge => |edge| try Report.line(
            io,
            allocator,
            "    contract: {s} local operations {d} -> {d}, blocks {d} -> {d}",
            .{
                edge.function,
                edge.raw_local_operations,
                edge.optimized_local_operations,
                edge.raw_blocks,
                edge.optimized_blocks,
            },
        ),
        .integer_ranges => |ranges| try Report.line(
            io,
            allocator,
            "    contract: {s}, {s}, {s}, {s}, {s} proven checks {d} -> {d}; {d} unproven check(s) retained",
            .{
                ranges.bounded_add,
                ranges.bounded_subtract,
                ranges.bounded_conversion,
                ranges.bounded_shift,
                ranges.bounded_loop,
                ranges.raw_proven_checks,
                ranges.optimized_proven_checks,
                ranges.optimized_unproven_checks,
            },
        ),
        .call_specialization => |calls| try Report.line(
            io,
            allocator,
            "    contract: {s} calls {d} -> {d}, reference stores {d} -> {d} after scalar replacement",
            .{
                calls.function,
                calls.raw_calls,
                calls.optimized_calls,
                calls.raw_reference_stores,
                calls.optimized_reference_stores,
            },
        ),
        .slp => |slp| try Report.line(
            io,
            allocator,
            "    contract: {s} SLP width {d} (required >= {d}), {d} ARM64 and {d} X64 native XY pairs{s}",
            .{
                slp.function,
                slp.observed,
                slp.required,
                slp.arm64_pairs,
                slp.x64_pairs,
                if (slp.native_required) " (required)" else "",
            },
        ),
    }
}

fn verifyCorpus(io: std.Io, allocator: std.mem.Allocator, corpus_directory: []const u8) !void {
    return verifyCorpusWithOptions(io, allocator, corpus_directory, .{ .verify_each_pass = true });
}

fn verifyCorpusWithOptions(
    io: std.Io,
    allocator: std.mem.Allocator,
    corpus_directory: []const u8,
    options: Silex.ReleaseOptimizer.Options,
) !void {
    try Report.heading(io, allocator, "semantic verification");
    for (Generator.corpus) |entry| {
        const path = try std.fs.path.join(allocator, &.{ corpus_directory, entry.name });
        const source = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
        const result = try Differential.verifyWithOptions(allocator, source, options);
        switch (result.execution) {
            .completed => |outcome| try Report.line(io, allocator, "  PASS {s} ({d} bytes output)", .{
                entry.name,
                outcome.stdout.len,
            }),
            .failed => |err| try Report.line(io, allocator, "  PASS {s} (preserved {t})", .{ entry.name, err }),
        }
    }
    try Report.line(io, allocator, "verified: {d} corpus programs", .{Generator.corpus.len});
}

fn reportPasses(io: std.Io, allocator: std.mem.Allocator) !void {
    try Report.heading(io, allocator, "stable Release pass registry");
    for (Silex.ReleaseOptimizer.pass_descriptors, 0..) |pass, index| {
        try Report.line(io, allocator, "  {d}. {s}", .{ index + 1, @tagName(pass.id) });
        try Report.line(io, allocator, "     requires: {s}", .{pass.precondition});
        try Report.line(io, allocator, "     ensures: {s}", .{pass.postcondition});
        try Report.line(io, allocator, "     preserves: {s}", .{pass.preserves});
    }
}

fn verifyCacheReproducibility(
    io: std.Io,
    allocator: std.mem.Allocator,
    silex_binary: []const u8,
    corpus_directory: []const u8,
) !void {
    const cases = [_][]const u8{
        "IntegerArithmetic.sx",
        "BranchingLoop.sx",
        "Regressions/AggregateFieldStores.sx",
        "Regressions/DenseScalarLoop.sx",
    };
    try std.Io.Dir.cwd().createDirPath(io, output_directory ++ "/cache-proof");
    var report: std.Io.Writer.Allocating = .init(allocator);
    errdefer report.deinit();
    try report.writer.writeAll("workload\tcold_sha256\tprimed_sha256\twarm_sha256\toutput_sha256\n");
    try Report.heading(io, allocator, "cold and warm cache reproducibility");
    for (cases) |name| {
        const source_path = try std.fs.path.join(allocator, &.{ corpus_directory, name });
        const stem = std.fs.path.stem(name);
        const cold_path = try std.fmt.allocPrint(allocator, "{s}/cache-proof/{s}-cold", .{ output_directory, stem });
        const primed_path = try std.fmt.allocPrint(allocator, "{s}/cache-proof/{s}-primed", .{ output_directory, stem });
        const warm_path = try std.fmt.allocPrint(allocator, "{s}/cache-proof/{s}-warm", .{ output_directory, stem });
        _ = try successfulCommand(allocator, io, &.{ silex_binary, "compile", source_path, "-r", "-n", "-o", cold_path });
        _ = try successfulCommand(allocator, io, &.{ silex_binary, "compile", source_path, "-r", "-o", primed_path });
        _ = try successfulCommand(allocator, io, &.{ silex_binary, "compile", source_path, "-r", "-o", warm_path });
        const cold_hash = try fileSha256(allocator, io, cold_path);
        const primed_hash = try fileSha256(allocator, io, primed_path);
        const warm_hash = try fileSha256(allocator, io, warm_path);
        if (!std.mem.eql(u8, cold_hash, primed_hash) or !std.mem.eql(u8, cold_hash, warm_hash))
            return error.CacheArtifactMismatch;
        const cold_run = try successfulCommand(allocator, io, &.{cold_path});
        const primed_run = try successfulCommand(allocator, io, &.{primed_path});
        const warm_run = try successfulCommand(allocator, io, &.{warm_path});
        if (!std.mem.eql(u8, cold_run.stdout, primed_run.stdout) or
            !std.mem.eql(u8, cold_run.stdout, warm_run.stdout) or
            !std.mem.eql(u8, cold_run.stderr, primed_run.stderr) or
            !std.mem.eql(u8, cold_run.stderr, warm_run.stderr))
        {
            return error.CacheExecutionMismatch;
        }
        var output_digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(cold_run.stdout, &output_digest, .{});
        const output_hash = std.fmt.bytesToHex(output_digest, .lower);
        try report.writer.print("{s}\t{s}\t{s}\t{s}\t{s}\n", .{
            name,
            cold_hash,
            primed_hash,
            warm_hash,
            &output_hash,
        });
        try Report.line(io, allocator, "  PASS {s}: {s}", .{ name, cold_hash });
    }
    const path = output_directory ++ "/cache-proof.tsv";
    try writeFile(io, path, try report.toOwnedSlice());
    try Report.line(io, allocator, "cache proof: {s}", .{path});
}

fn qualifyMetamorphic(
    io: std.Io,
    allocator: std.mem.Allocator,
    silex_binary: []const u8,
) !void {
    const directory = output_directory ++ "/SilexOptimizerMetamorphic";
    try std.Io.Dir.cwd().createDirPath(io, directory ++ "/Module");
    try writeFile(io, directory ++ "/Package.json",
        \\{"name":"SilexOptimizerMetamorphic","version":"0.0.0"}
    );
    var report: std.Io.Writer.Allocating = .init(allocator);
    errdefer report.deinit();
    try report.writer.writeAll("case\taxis\tleft_sha256\tright_sha256\tleft_instructions\tright_instructions\tleft_blocks\tright_blocks\tleft_calls\tright_calls\tstructural_class\n");
    try Report.heading(io, allocator, "metamorphic qualification");
    for (Metamorphic.pairs, 0..) |pair, pair_index| {
        const left_path = try std.fmt.allocPrint(allocator, "{s}/Case{d}Left.sx", .{ directory, pair_index });
        const right_path = try std.fmt.allocPrint(allocator, "{s}/Case{d}Right.sx", .{ directory, pair_index });
        try writeFile(io, left_path, pair.left);
        try writeFile(io, right_path, pair.right);
        const left = try Differential.verify(allocator, pair.left);
        const right = try Differential.verify(allocator, pair.right);
        if (!executionEqual(left.execution, right.execution)) return error.MetamorphicSemanticMismatch;
        _ = try Native.verify(allocator, io, silex_binary, left_path, left.execution, try std.fmt.allocPrint(
            allocator,
            "{s}/{s}-left",
            .{ directory, pair.id },
        ), true);
        _ = try Native.verify(allocator, io, silex_binary, right_path, right.execution, try std.fmt.allocPrint(
            allocator,
            "{s}/{s}-right",
            .{ directory, pair.id },
        ), true);
        const left_profile = IrStats.profile(left.optimized_ir);
        const right_profile = IrStats.profile(right.optimized_ir);
        const structural_equivalent = left_profile.counts.instructions == right_profile.counts.instructions and
            left_profile.counts.blocks == right_profile.counts.blocks and
            left_profile.calls == right_profile.calls and
            left_profile.local_loads + left_profile.local_stores == right_profile.local_loads + right_profile.local_stores;
        const left_hash = sourceSha256(pair.left);
        const right_hash = sourceSha256(pair.right);
        try report.writer.print("{s}\t{s}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{s}\n", .{
            pair.id,
            pair.axis,
            &left_hash,
            &right_hash,
            left_profile.counts.instructions,
            right_profile.counts.instructions,
            left_profile.counts.blocks,
            right_profile.counts.blocks,
            left_profile.calls,
            right_profile.calls,
            if (structural_equivalent) "equivalent" else "gap",
        });
        try Report.line(io, allocator, "  PASS {s}: semantics and native modes agree, structure {s}", .{
            pair.id,
            if (structural_equivalent) "equivalent" else "records a gap",
        });
    }
    const path = output_directory ++ "/metamorphic.tsv";
    try writeFile(io, path, try report.toOwnedSlice());
    try Report.line(io, allocator, "metamorphic report: {s}", .{path});
}

fn executionEqual(left: Differential.Execution, right: Differential.Execution) bool {
    return switch (left) {
        .failed => |left_error| switch (right) {
            .failed => |right_error| left_error == right_error,
            .completed => false,
        },
        .completed => |left_result| switch (right) {
            .failed => false,
            .completed => |right_result| left_result.exit_code == right_result.exit_code and
                std.mem.eql(u8, left_result.stdout, right_result.stdout) and
                std.mem.eql(u8, left_result.stderr, right_result.stderr),
        },
    };
}

fn sourceSha256(source: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

fn fuzz(io: std.Io, allocator: std.mem.Allocator, count: usize, initial_seed: u64) !void {
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    try Report.heading(io, allocator, "deterministic numeric fuzzing");
    for (0..count) |index| {
        const seed = initial_seed +% index;
        const source = try Generator.source(allocator, seed);
        _ = Differential.verify(allocator, source) catch |err| {
            const reduced = Reducer.reduce(allocator, source, err) catch source;
            const failure_path = try std.fmt.allocPrint(
                allocator,
                "{s}/failure-{d}.sx",
                .{ output_directory, seed },
            );
            try writeFile(io, failure_path, reduced);
            try Report.line(io, allocator, "  FAIL seed {d}: {s}", .{ seed, failure_path });
            return err;
        };
    }
    try Report.line(io, allocator, "verified: {d} generated programs (seed {d}..{d})", .{
        count,
        initial_seed,
        initial_seed +% count -% 1,
    });
}

fn fuzzLlvm(
    io: std.Io,
    allocator: std.mem.Allocator,
    oracle: Registry.Oracle,
    count: usize,
    initial_seed: u64,
) !void {
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    try Report.heading(io, allocator, "LLVM differential fuzzing");
    const llvm_path = output_directory ++ "/fuzz.ll";
    const executable_path = output_directory ++ "/fuzz-llvm";
    for (0..count) |index| {
        const seed = initial_seed +% index;
        const source = try Generator.source(allocator, seed);
        const differential = try Differential.verify(allocator, source);
        const expected = switch (differential.execution) {
            .completed => |outcome| outcome,
            .failed => return error.UnexpectedRuntimeFailure,
        };
        try writeFile(io, llvm_path, try Llvm.emit(allocator, differential.raw_ir));
        const cpu_argument = try std.fmt.allocPrint(allocator, "-mcpu={s}", .{oracle.cpu});
        _ = try successfulCommand(allocator, io, &.{
            oracle.executable, oracle.optimization, "-target", oracle.target_triple,
            cpu_argument,      llvm_path,           "-o",      executable_path,
        });
        const actual = try successfulCommand(allocator, io, &.{executable_path});
        if (!std.mem.eql(u8, expected.stdout, actual.stdout) or
            !std.mem.eql(u8, expected.stderr, actual.stderr))
        {
            const failure_path = try std.fmt.allocPrint(
                allocator,
                "{s}/llvm-failure-{d}.sx",
                .{ output_directory, seed },
            );
            try writeFile(io, failure_path, source);
            try Report.line(io, allocator, "  FAIL seed {d}: {s}", .{ seed, failure_path });
            return error.SemanticMismatch;
        }
    }
    try Report.line(io, allocator, "verified: {d} LLVM programs (seed {d}..{d})", .{
        count,
        initial_seed,
        initial_seed +% count -% 1,
    });
}

fn compareCorpus(
    io: std.Io,
    allocator: std.mem.Allocator,
    silex_binary: []const u8,
    corpus_directory: []const u8,
    oracle: Registry.Oracle,
    samples: usize,
) !void {
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    try Report.heading(io, allocator, "Silex Release versus LLVM -O3");
    try Report.line(io, allocator, "artifacts: {s}", .{output_directory});
    var machine_report: std.Io.Writer.Allocating = .init(allocator);
    errdefer machine_report.deinit();
    try machine_report.writer.writeAll(
        "workload\tsource_sha256\traw_ir_instructions\toptimized_ir_instructions\tbackend\toracle_revision\ttarget\tcpu\tbinary_sha256\tsamples\tbatch\tminimum_ns\tp10_ns\tmedian_ns\tp90_ns\tmaximum_ns\tmad_ns\tmad_ppm\tbinary_bytes\n",
    );
    var opportunity_report: std.Io.Writer.Allocating = .init(allocator);
    errdefer opportunity_report.deinit();
    try opportunity_report.writer.writeAll(
        "workload\trank\tscore\tpriority\tkind\tevidence\taction\n",
    );
    var opportunity_summary: Advisor.Summary = .{};
    for (Generator.corpus) |entry| {
        const name = entry.name;
        const source_path = try std.fs.path.join(allocator, &.{ corpus_directory, name });
        const source = try std.Io.Dir.cwd().readFileAlloc(io, source_path, allocator, .limited(1024 * 1024));
        const differential = try Differential.verify(allocator, source);
        const expected = switch (differential.execution) {
            .completed => |outcome| outcome,
            .failed => return error.UnexpectedRuntimeFailure,
        };
        const stem = std.fs.path.stem(name);
        const raw_silex_path = try artifactPath(allocator, stem, "raw.sir");
        const optimized_silex_path = try artifactPath(allocator, stem, "silex.sir");
        const raw_llvm_path = try artifactPath(allocator, stem, "raw.ll");
        const silex_llvm_path = try artifactPath(allocator, stem, "silex.ll");
        const optimized_llvm_path = try artifactPath(allocator, stem, "llvm.ll");
        const llvm_binary_path = try artifactPath(allocator, stem, "llvm");
        const native_binary_path = try artifactPath(allocator, stem, "silex");

        const raw_llvm = try Llvm.emit(allocator, differential.raw_ir);
        const silex_llvm = try Llvm.emit(allocator, differential.optimized_ir);
        try writeFile(io, raw_silex_path, try Silex.Ir.writeText(allocator, differential.raw_ir));
        try writeFile(io, optimized_silex_path, try Silex.Ir.writeText(allocator, differential.optimized_ir));
        try writeFile(io, raw_llvm_path, raw_llvm);
        try writeFile(io, silex_llvm_path, silex_llvm);
        const cpu_argument = try std.fmt.allocPrint(allocator, "-mcpu={s}", .{oracle.cpu});
        _ = try successfulCommand(allocator, io, &.{
            oracle.executable, "-S",                 "-emit-llvm", oracle.optimization,
            "-target",         oracle.target_triple, cpu_argument, raw_llvm_path,
            "-o",              optimized_llvm_path,
        });
        const optimized_llvm = try std.Io.Dir.cwd().readFileAlloc(
            io,
            optimized_llvm_path,
            allocator,
            .limited(16 * 1024 * 1024),
        );
        _ = try successfulCommand(allocator, io, &.{
            oracle.executable, oracle.optimization, "-target", oracle.target_triple,
            cpu_argument,      optimized_llvm_path, "-o",      llvm_binary_path,
        });
        _ = try successfulCommand(allocator, io, &.{
            silex_binary, "compile", source_path, "-r", "-n", "-o", native_binary_path,
        });

        const llvm_result = try successfulCommand(allocator, io, &.{llvm_binary_path});
        const native_result = try successfulCommand(allocator, io, &.{native_binary_path});
        if (!std.mem.eql(u8, expected.stdout, llvm_result.stdout) or
            !std.mem.eql(u8, expected.stdout, native_result.stdout) or
            !std.mem.eql(u8, expected.stderr, llvm_result.stderr) or
            !std.mem.eql(u8, expected.stderr, native_result.stderr))
        {
            return error.SemanticMismatch;
        }

        const native_size = (try std.Io.Dir.cwd().statFile(io, native_binary_path, .{})).size;
        const llvm_size = (try std.Io.Dir.cwd().statFile(io, llvm_binary_path, .{})).size;
        const native_hash = try fileSha256(allocator, io, native_binary_path);
        const llvm_hash = try fileSha256(allocator, io, llvm_binary_path);
        const raw_stats = IrStats.count(differential.raw_ir);
        const optimized_stats = IrStats.count(differential.optimized_ir);
        const llvm_comparison = LlvmStats.compare(raw_llvm, optimized_llvm, differential.raw_ir.functions.len);
        const advice = try Advisor.analyze(
            allocator,
            try IrStats.compare(allocator, differential.raw_ir, differential.optimized_ir),
            llvm_comparison,
        );
        opportunity_summary.add(advice);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(source, &digest, .{});
        const source_hash = std.fmt.bytesToHex(digest, .lower);
        try Report.line(io, allocator, "  PASS {s}", .{name});
        try Report.ir(io, allocator, raw_stats, optimized_stats);
        try reportAdvice(io, allocator, advice);
        for (advice.findings, 0..) |finding, rank| try appendOpportunityRow(
            &opportunity_report.writer,
            name,
            rank + 1,
            finding,
        );
        try Report.line(io, allocator, "  size: Silex {d} bytes, LLVM {d} bytes", .{ native_size, llvm_size });
        if (!entry.timing) {
            try Report.line(io, allocator, "  timing: skipped correctness probe", .{});
            continue;
        }
        const measurements = Benchmark.measurePair(
            allocator,
            io,
            native_binary_path,
            llvm_binary_path,
            .{ .samples = samples },
        ) catch |err| {
            try Report.line(io, allocator, "  timing: rejected ({t})", .{err});
            return err;
        };
        try Report.benchmark(io, allocator, "Silex Release", measurements.left);
        try Report.benchmark(io, allocator, "LLVM -O3", measurements.right);
        const relative_percent: u64 = if (measurements.right.median_ns == 0)
            0
        else
            @intCast((@as(u128, measurements.left.median_ns) * 100) / measurements.right.median_ns);
        try Report.line(io, allocator, "  relative median: Silex {d}% of LLVM time", .{relative_percent});
        if (measurements.left.spreadPpm() > 200_000 or measurements.right.spreadPpm() > 200_000) {
            try Report.line(io, allocator, "  stability: noisy sample set; treat timing as diagnostic", .{});
        }
        try appendMachineRow(
            &machine_report.writer,
            name,
            &source_hash,
            raw_stats,
            optimized_stats,
            "silex-release",
            oracle,
            native_hash,
            measurements.left,
            native_size,
        );
        try appendMachineRow(
            &machine_report.writer,
            name,
            &source_hash,
            raw_stats,
            optimized_stats,
            "llvm-o3",
            oracle,
            llvm_hash,
            measurements.right,
            llvm_size,
        );
    }
    const report_path = output_directory ++ "/report.tsv";
    try writeFile(io, report_path, try machine_report.toOwnedSlice());
    try Report.line(io, allocator, "machine report: {s}", .{report_path});
    const opportunities_path = output_directory ++ "/opportunities.tsv";
    try writeFile(io, opportunities_path, try opportunity_report.toOwnedSlice());
    try reportOpportunitySummary(io, allocator, opportunity_summary);
    try Report.line(io, allocator, "optimization guidance: {s}", .{opportunities_path});
}

fn reportAdvice(io: std.Io, allocator: std.mem.Allocator, advice: Advisor.Analysis) !void {
    if (advice.findings.len == 0) {
        try Report.line(io, allocator, "  LLVM guidance: no missing transformation identified", .{});
        return;
    }
    try Report.line(io, allocator, "  LLVM guidance:", .{});
    for (advice.findings) |finding| {
        try Report.line(io, allocator, "    [{s} {d}] {s}", .{
            priority(finding.score),
            finding.score,
            finding.kind.label(),
        });
        try Report.line(io, allocator, "      evidence: {s}", .{finding.evidence});
        try Report.line(io, allocator, "      action: {s}", .{finding.kind.action()});
    }
}

fn reportOpportunitySummary(
    io: std.Io,
    allocator: std.mem.Allocator,
    summary: Advisor.Summary,
) !void {
    const ranked = try summary.ranked(allocator);
    try Report.heading(io, allocator, "ranked Silex optimization priorities");
    if (ranked.len == 0) {
        try Report.line(io, allocator, "  no missing transformation identified", .{});
        return;
    }
    for (ranked, 0..) |entry, index| try Report.line(io, allocator, "  {d}. {s} ({d} workloads, score {d})", .{
        index + 1,
        entry.kind.label(),
        entry.workloads,
        entry.score_sum,
    });
}

fn appendOpportunityRow(
    writer: *std.Io.Writer,
    workload: []const u8,
    rank: usize,
    finding: Advisor.Finding,
) !void {
    try writer.print("{s}\t{d}\t{d}\t{s}\t{s}\t{s}\t{s}\n", .{
        workload,
        rank,
        finding.score,
        priority(finding.score),
        @tagName(finding.kind),
        finding.evidence,
        finding.kind.action(),
    });
}

fn priority(finding_score: u8) []const u8 {
    if (finding_score >= 90) return "critical";
    if (finding_score >= 80) return "high";
    if (finding_score >= 70) return "medium";
    return "low";
}

fn appendMachineRow(
    writer: *std.Io.Writer,
    workload: []const u8,
    source_hash: []const u8,
    raw: IrStats.Counts,
    optimized: IrStats.Counts,
    backend: []const u8,
    oracle: Registry.Oracle,
    binary_hash: []const u8,
    summary: Benchmark.Summary,
    binary_size: u64,
) !void {
    try writer.print(
        "{s}\t{s}\t{d}\t{d}\t{s}\t{s}\t{s}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n",
        .{
            workload,
            source_hash,
            raw.instructions,
            optimized.instructions,
            backend,
            oracle.source_revision,
            oracle.target_triple,
            oracle.cpu,
            binary_hash,
            summary.samples,
            summary.batch,
            summary.minimum_ns,
            summary.percentile_10_ns,
            summary.median_ns,
            summary.percentile_90_ns,
            summary.maximum_ns,
            summary.median_absolute_deviation_ns,
            summary.deviationPpm(),
            binary_size,
        },
    );
}

fn reportRegistry(io: std.Io, allocator: std.mem.Allocator, registry: Registry.Manifest) !void {
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    try Report.heading(io, allocator, "optimization coverage registry");
    try Report.line(io, allocator, "  schema: {d}", .{registry.schema_version});
    try Report.line(io, allocator, "  LLVM executable: {s}", .{registry.oracle.version_line});
    try Report.line(io, allocator, "  LLVM sources: {s} ({s})", .{
        registry.oracle.source_revision,
        registry.oracle.source_tag,
    });
    try Report.line(io, allocator, "  target: {s}, CPU {s}, {s}", .{
        registry.oracle.target_triple,
        registry.oracle.cpu,
        registry.oracle.optimization,
    });
    try Report.line(io, allocator, "  coverage: {d} families, {d} baselines, {d} hot functions, {d} workspace repositories, {d} sealed qualification projects", .{
        registry.coverage.len,
        registry.baselines.len,
        registry.hot_functions.len,
        registry.workspace_baseline.len,
        registry.qualification_corpus.len,
    });
    const plan_path = output_directory ++ "/coverage-plan.tsv";
    const plan = try Registry.writeCoveragePlan(allocator, io, registry, plan_path);
    try Report.line(io, allocator, "  interactions: {d} pairwise cases, {d} risk triplets, SHA-256 {s}", .{
        plan.pairwise_cases,
        plan.risk_triplets,
        &plan.sha256,
    });
    try Report.line(io, allocator, "  plan: {s}", .{plan_path});
}

fn fileSha256(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]const u8 {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(128 * 1024 * 1024));
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.allocPrint(allocator, "{s}", .{std.fmt.bytesToHex(digest, .lower)});
}

fn successfulCommand(
    allocator: std.mem.Allocator,
    io: std.Io,
    arguments: []const []const u8,
) !std.process.RunResult {
    const result = try std.process.run(allocator, io, .{
        .argv = arguments,
        .stdout_limit = .limited(16 * 1024 * 1024),
        .stderr_limit = .limited(16 * 1024 * 1024),
    });
    const success = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!success) {
        std.debug.print("optimizer oracle command failed ({any}):", .{result.term});
        for (arguments) |argument| std.debug.print(" {s}", .{argument});
        std.debug.print("\n", .{});
        const output = std.mem.trim(u8, result.stdout, " \t\r\n");
        if (output.len != 0) std.debug.print("stdout:\n{s}\n", .{output});
        const detail = std.mem.trim(u8, result.stderr, " \t\r\n");
        if (detail.len != 0) std.debug.print("stderr:\n{s}\n", .{detail});
        return error.CommandFailed;
    }
    return result;
}

fn artifactPath(allocator: std.mem.Allocator, stem: []const u8, suffix: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}/{s}-{s}", .{ output_directory, stem, suffix });
}

fn writeFile(io: std.Io, path: []const u8, bytes: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}

fn isHelp(argument: []const u8) bool {
    return std.mem.eql(u8, argument, "help") or
        std.mem.eql(u8, argument, "-h") or
        std.mem.eql(u8, argument, "--help");
}

test {
    _ = Advisor;
    _ = Benchmark;
    _ = Differential;
    _ = Generator;
    _ = HotBudget;
    _ = IrStats;
    _ = Llvm;
    _ = LlvmStats;
    _ = Metamorphic;
    _ = Native;
    _ = NativeGenerator;
    _ = Qualification;
    _ = Registry;
    _ = Reducer;
}
