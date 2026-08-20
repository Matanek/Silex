const std = @import("std");
const Advisor = @import("Advisor.zig");
const Benchmark = @import("Benchmark.zig");
const Differential = @import("Differential.zig");
const Generator = @import("Generator.zig");
const IrStats = @import("IrStats.zig");
const Llvm = @import("Llvm.zig");
const LlvmStats = @import("LlvmStats.zig");
const Native = @import("Native.zig");
const NativeGenerator = @import("NativeGenerator.zig");
const Qualification = @import("Qualification.zig");
const Reducer = @import("Reducer.zig");
const Report = @import("Report.zig");

const usage =
    \\Usage: zig build optimizer-oracle -- <command> [options]
    \\
    \\Commands:
    \\  verify              Compare raw and Release IR through the interpreter
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
const generated_source_directory = "/private/tmp/SilexOptimizerOracle";

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
    if (std.mem.eql(u8, command, "verify")) {
        if (arguments.len != 4) return error.InvalidArguments;
        try verifyCorpus(init.io, allocator, corpus_directory);
        return 0;
    }
    if (std.mem.eql(u8, command, "compare")) {
        const samples = if (arguments.len == 5) try std.fmt.parseInt(usize, arguments[4], 10) else 11;
        if (arguments.len > 5 or samples < 5 or samples % 2 == 0) return error.InvalidArguments;
        try compareCorpus(init.io, allocator, silex_binary, corpus_directory, samples);
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
        try fuzzLlvm(init.io, allocator, count, seed);
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
        try verifyCorpus(init.io, allocator, corpus_directory);
        try qualifyNative(init.io, allocator, silex_binary, corpus_directory, 8, 1);
        try fuzz(init.io, allocator, 128, 1);
        try fuzzLlvm(init.io, allocator, 32, 1);
        try compareCorpus(init.io, allocator, silex_binary, corpus_directory, 5);
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
    try std.Io.Dir.cwd().createDirPath(io, generated_source_directory);
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
        .slp => |slp| try Report.line(
            io,
            allocator,
            "    contract: {s} SLP width {d} (required >= {d}), {d} native XY pairs{s}",
            .{
                slp.function,
                slp.observed,
                slp.required,
                slp.native_pairs,
                if (slp.native_required) " (required)" else "",
            },
        ),
    }
}

fn verifyCorpus(io: std.Io, allocator: std.mem.Allocator, corpus_directory: []const u8) !void {
    try Report.heading(io, allocator, "semantic verification");
    for (Generator.corpus) |entry| {
        const path = try std.fs.path.join(allocator, &.{ corpus_directory, entry.name });
        const source = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
        const result = try Differential.verify(allocator, source);
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

fn fuzzLlvm(io: std.Io, allocator: std.mem.Allocator, count: usize, initial_seed: u64) !void {
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
        _ = try successfulCommand(allocator, io, &.{ "clang", "-O3", llvm_path, "-o", executable_path });
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
    samples: usize,
) !void {
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    try Report.heading(io, allocator, "Silex Release versus LLVM -O3");
    try Report.line(io, allocator, "artifacts: {s}", .{output_directory});
    var machine_report: std.Io.Writer.Allocating = .init(allocator);
    errdefer machine_report.deinit();
    try machine_report.writer.writeAll(
        "workload\tsource_sha256\traw_ir_instructions\toptimized_ir_instructions\tbackend\tsamples\tbatch\tminimum_ns\tp10_ns\tmedian_ns\tp90_ns\tmaximum_ns\tmad_ns\tmad_ppm\tbinary_bytes\n",
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
        const raw_llvm_path = try artifactPath(allocator, stem, "raw.ll");
        const silex_llvm_path = try artifactPath(allocator, stem, "silex.ll");
        const optimized_llvm_path = try artifactPath(allocator, stem, "llvm.ll");
        const llvm_binary_path = try artifactPath(allocator, stem, "llvm");
        const native_binary_path = try artifactPath(allocator, stem, "silex");

        const raw_llvm = try Llvm.emit(allocator, differential.raw_ir);
        const silex_llvm = try Llvm.emit(allocator, differential.optimized_ir);
        try writeFile(io, raw_llvm_path, raw_llvm);
        try writeFile(io, silex_llvm_path, silex_llvm);
        _ = try successfulCommand(allocator, io, &.{
            "clang", "-S", "-emit-llvm", "-O3", raw_llvm_path, "-o", optimized_llvm_path,
        });
        const optimized_llvm = try std.Io.Dir.cwd().readFileAlloc(
            io,
            optimized_llvm_path,
            allocator,
            .limited(16 * 1024 * 1024),
        );
        _ = try successfulCommand(allocator, io, &.{ "clang", "-O3", optimized_llvm_path, "-o", llvm_binary_path });
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
        const raw_stats = IrStats.count(differential.raw_ir);
        const optimized_stats = IrStats.count(differential.optimized_ir);
        const llvm_comparison = LlvmStats.compare(raw_llvm, optimized_llvm, differential.raw_ir.functions.len);
        const advice = try Advisor.analyze(
            allocator,
            IrStats.profile(differential.raw_ir),
            IrStats.profile(differential.optimized_ir),
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
    summary: Benchmark.Summary,
    binary_size: u64,
) !void {
    try writer.print(
        "{s}\t{s}\t{d}\t{d}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n",
        .{
            workload,
            source_hash,
            raw.instructions,
            optimized.instructions,
            backend,
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
        const detail = std.mem.trim(u8, result.stderr, " \t\r\n");
        if (detail.len != 0) std.debug.print("{s}\n", .{detail});
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
    _ = IrStats;
    _ = Llvm;
    _ = LlvmStats;
    _ = Native;
    _ = NativeGenerator;
    _ = Qualification;
    _ = Reducer;
}
