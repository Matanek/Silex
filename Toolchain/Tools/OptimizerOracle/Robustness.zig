const std = @import("std");
const Silex = @import("silex_optimizer_api");
const InteractionGenerator = @import("InteractionGenerator.zig");
const Native = @import("Native.zig");
const Registry = @import("Registry.zig");
const Reducer = @import("Reducer.zig");
const Report = @import("Report.zig");

const output_directory = ".zig-cache/optimizer-oracle/robustness";
const maximum_source_bytes = 512 * 1024;
const maximum_ir_bytes = 4 * 1024 * 1024;
const maximum_native_bytes = 16 * 1024 * 1024;

pub const Level = enum {
    quick,
    qualified,
};

pub const Summary = struct {
    generated_cases: usize = 0,
    pairwise_cases: usize = 0,
    risk_triplets: usize = 0,
    native_cases: usize = 0,
    negative_cases: usize = 0,
    arm64_lowerings: usize = 0,
    x64_lowerings: usize = 0,
};

const Verification = struct {
    source_sha256: [64]u8,
    raw_ir_sha256: [64]u8,
    optimized_ir_sha256: [64]u8,
    output_sha256: [64]u8,
    native_debug_sha256: [64]u8 = [_]u8{'-'} ** 64,
    native_release_sha256: [64]u8 = [_]u8{'-'} ** 64,
    raw_ir_bytes: usize,
    optimized_ir_bytes: usize,
    release_prefixes: usize,
};

pub fn run(
    io: std.Io,
    allocator: std.mem.Allocator,
    silex_binary: []const u8,
    interactions: Registry.Interactions,
    level: Level,
) !Summary {
    const started = std.Io.Clock.awake.now(io);
    const run_id = std.Io.Clock.real.now(io).toNanoseconds();
    try std.Io.Dir.cwd().createDirPath(io, output_directory);
    var report: std.Io.Writer.Allocating = .init(allocator);
    errdefer report.deinit();
    try report.writer.writeAll(
        "kind\tid\tseed\tfirst_axis\tfirst_state\tsecond_axis\tsecond_state\trisk_triplet\t" ++
            "source_sha256\traw_ir_sha256\toptimized_ir_sha256\toutput_sha256\t" ++
            "native_debug_code_sha256\tnative_release_executable_sha256\traw_ir_bytes\toptimized_ir_bytes\t" ++
            "release_prefixes\tarm64\tx64\tnative_debug\tnative_release\n",
    );
    try Report.heading(io, allocator, switch (level) {
        .quick => "quick adversarial interaction qualification",
        .qualified => "qualified adversarial interaction campaign",
    });

    var summary: Summary = .{};
    var pair_index: usize = 0;
    for (interactions.axes, 0..) |first, first_index| {
        for (interactions.axes[first_index + 1 ..]) |second| {
            for (0..4) |combination| {
                const seed = interactions.pairwise_seed +% summary.pairwise_cases;
                const native = switch (level) {
                    .quick => combination == 3 and pair_index % 4 == 0,
                    .qualified => combination == 3,
                };
                const request: InteractionGenerator.Request = .{
                    .seed = seed,
                    .first_axis = first,
                    .first_state = combination & 1 != 0,
                    .second_axis = second,
                    .second_state = combination & 2 != 0,
                };
                const id = try std.fmt.allocPrint(allocator, "pair-{d}", .{summary.pairwise_cases});
                const verification = try executeCase(io, allocator, silex_binary, id, request, native);
                try writeRow(
                    &report.writer,
                    "pairwise",
                    id,
                    request,
                    verification,
                    native,
                );
                summary.generated_cases += 1;
                summary.pairwise_cases += 1;
                summary.native_cases += @intFromBool(native);
                summary.arm64_lowerings += 1;
                summary.x64_lowerings += 1;
            }
            pair_index += 1;
        }
    }
    for (interactions.risk_triplets, 0..) |risk, index| {
        const seed = interactions.triplet_seed +% index;
        const request: InteractionGenerator.Request = .{
            .seed = seed,
            .first_axis = "risk",
            .first_state = true,
            .risk_triplet = risk,
        };
        const id = try std.fmt.allocPrint(allocator, "risk-{d}", .{index});
        const verification = try executeCase(io, allocator, silex_binary, id, request, true);
        try writeRow(&report.writer, "triplet", id, request, verification, true);
        summary.generated_cases += 1;
        summary.risk_triplets += 1;
        summary.native_cases += 1;
        summary.arm64_lowerings += 1;
        summary.x64_lowerings += 1;
    }
    summary.negative_cases = try verifyNegativeCorpus(io, allocator, &report.writer);

    const report_bytes = try report.toOwnedSlice();
    const level_name = @tagName(level);
    const report_path = try std.fmt.allocPrint(
        allocator,
        "{s}/interactions-v1-{s}-{d}-{d}.tsv",
        .{ output_directory, level_name, interactions.pairwise_seed, interactions.triplet_seed },
    );
    try sealReport(io, allocator, report_path, report_bytes);
    const elapsed_ns = started.durationTo(std.Io.Clock.awake.now(io)).toNanoseconds();
    const run_path = try std.fmt.allocPrint(
        allocator,
        "{s}/run-{s}-{d}.tsv",
        .{ output_directory, level_name, run_id },
    );
    const run_record = try std.fmt.allocPrint(
        allocator,
        "level\tpairwise_seed\ttriplet_seed\tpairwise_cases\trisk_triplets\tnative_cases\tnegative_cases\t" ++
            "elapsed_ns\tmaximum_source_bytes\tmaximum_ir_bytes\tmaximum_native_bytes\n" ++
            "{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\n",
        .{
            level_name,
            interactions.pairwise_seed,
            interactions.triplet_seed,
            summary.pairwise_cases,
            summary.risk_triplets,
            summary.native_cases,
            summary.negative_cases,
            elapsed_ns,
            maximum_source_bytes,
            maximum_ir_bytes,
            maximum_native_bytes,
        },
    );
    try writeFile(io, run_path, run_record);
    try Report.line(io, allocator, "robustness report: {s}", .{report_path});
    try Report.line(io, allocator, "campaign record: {s} ({d} ns)", .{ run_path, elapsed_ns });
    try Report.line(
        io,
        allocator,
        "qualified: {d} pairwise cases, {d} risk triplets, {d} native cases, {d} negative cases",
        .{ summary.pairwise_cases, summary.risk_triplets, summary.native_cases, summary.negative_cases },
    );
    return summary;
}

fn executeCase(
    io: std.Io,
    allocator: std.mem.Allocator,
    silex_binary: []const u8,
    id: []const u8,
    request: InteractionGenerator.Request,
    native: bool,
) !Verification {
    _ = id;
    const sources = try InteractionGenerator.source(allocator, request);
    if (sources.main.len > maximum_source_bytes) return error.SourceBudgetExceeded;
    const case_name = try std.fmt.allocPrint(allocator, "RobustnessCase{d}", .{request.seed});
    const directory = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ output_directory, case_name });
    try std.Io.Dir.cwd().createDirPath(io, directory);
    const main_path = try std.fmt.allocPrint(allocator, "{s}/Main.sx", .{directory});
    try writeFile(io, main_path, sources.main);
    const stale_support_paths = [_][]const u8{
        try std.fmt.allocPrint(allocator, "{s}/Support.sx", .{directory}),
        try std.fmt.allocPrint(allocator, "{s}/Module/Support.sx", .{directory}),
    };
    for (stale_support_paths) |path| std.Io.Dir.cwd().deleteFile(io, path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    const manifest_path = try std.fmt.allocPrint(allocator, "{s}/Package.json", .{directory});
    if (sources.support) |support| {
        try writeFile(
            io,
            manifest_path,
            "{\"sources\":\".\",\"dependencies\":{\"Support\":\"=1.0.0\"}}\n",
        );
        const support_module_directory = try std.fmt.allocPrint(allocator, "{s}/Support/Module", .{directory});
        try std.Io.Dir.cwd().createDirPath(io, support_module_directory);
        const support_manifest_path = try std.fmt.allocPrint(allocator, "{s}/Support/Package.json", .{directory});
        const support_path = try std.fmt.allocPrint(allocator, "{s}/@Module.sx", .{support_module_directory});
        try writeFile(io, support_manifest_path, "{\"name\":\"Support\",\"version\":\"1.0.0\"}\n");
        try writeFile(io, support_path, support);
        const links_directory = try std.fmt.allocPrint(allocator, "{s}/.silex/links", .{directory});
        try std.Io.Dir.cwd().createDirPath(io, links_directory);
        const link_path = try std.fmt.allocPrint(allocator, "{s}/Support.json", .{links_directory});
        const support_root = try std.fmt.allocPrint(allocator, "{s}/Support", .{directory});
        const link = try std.fmt.allocPrint(allocator, "{{\"path\":\"{s}\"}}\n", .{support_root});
        try writeFile(io, link_path, link);
    } else {
        try writeFile(io, manifest_path, "{\"sources\":\".\"}\n");
    }

    var first = verifyProject(io, allocator, main_path, sources) catch |err| {
        const reduced = if (sources.support == null)
            Reducer.reduce(allocator, sources.main, err) catch sources.main
        else
            sources.main;
        const failure_path = try std.fmt.allocPrint(allocator, "{s}/failure.sx", .{directory});
        const metadata_path = try std.fmt.allocPrint(allocator, "{s}/failure.tsv", .{directory});
        try writeFile(io, failure_path, reduced);
        const metadata = try std.fmt.allocPrint(
            allocator,
            "seed\tfirst_axis\tfirst_state\tsecond_axis\tsecond_state\trisk_triplet\terror\n" ++
                "{d}\t{s}\t{d}\t{s}\t{d}\t{s}\t{t}\n",
            .{
                request.seed,
                request.first_axis,
                @intFromBool(request.first_state),
                request.second_axis orelse "-",
                @intFromBool(request.second_state),
                request.risk_triplet orelse "-",
                err,
            },
        );
        try writeFile(io, metadata_path, metadata);
        return err;
    };
    const repeated = try verifyProject(io, allocator, main_path, sources);
    if (!std.mem.eql(u8, &first.raw_ir_sha256, &repeated.raw_ir_sha256) or
        !std.mem.eql(u8, &first.optimized_ir_sha256, &repeated.optimized_ir_sha256) or
        !std.mem.eql(u8, &first.output_sha256, &repeated.output_sha256))
    {
        return error.NondeterministicCompilation;
    }
    if (native) {
        var compiler = Silex.Project.Compiler.init(allocator, io);
        const compilation = try compiler.compile(main_path);
        const optimized = try Silex.ReleaseOptimizer.optimizeWithOptions(allocator, compilation.ir, .{
            .verify_each_pass = true,
        });
        const expected = try Silex.Interpreter.runCapture(allocator, optimized);
        const artifact_stem = try std.fmt.allocPrint(allocator, "{s}/native", .{directory});
        const result = try Native.verify(
            allocator,
            io,
            silex_binary,
            main_path,
            .{ .completed = expected },
            artifact_stem,
            true,
        );
        const repeated_stem = try std.fmt.allocPrint(allocator, "{s}/native-repeated", .{directory});
        const repeated_native = try Native.verify(
            allocator,
            io,
            silex_binary,
            main_path,
            .{ .completed = expected },
            repeated_stem,
            true,
        );
        if (result.debug_size.? > maximum_native_bytes or result.release_size > maximum_native_bytes)
            return error.NativeArtifactBudgetExceeded;
        if (repeated_native.debug_size.? > maximum_native_bytes or repeated_native.release_size > maximum_native_bytes)
            return error.NativeArtifactBudgetExceeded;
        first.native_debug_sha256 = try fileSha256(allocator, io, artifact_stem, "-debug.silex.o");
        first.native_release_sha256 = try fileSha256(allocator, io, artifact_stem, "-release");
        const repeated_debug_sha256 = try fileSha256(allocator, io, repeated_stem, "-debug.silex.o");
        const repeated_release_sha256 = try fileSha256(allocator, io, repeated_stem, "-release");
        if (!std.mem.eql(u8, &first.native_debug_sha256, &repeated_debug_sha256) or
            !std.mem.eql(u8, &first.native_release_sha256, &repeated_release_sha256))
        {
            return error.NondeterministicNativeCode;
        }
    }
    return first;
}

fn verifyProject(
    io: std.Io,
    allocator: std.mem.Allocator,
    main_path: []const u8,
    sources: InteractionGenerator.Sources,
) !Verification {
    var compiler = Silex.Project.Compiler.init(allocator, io);
    const compilation = try compiler.compile(main_path);
    try Silex.ReleaseVerifier.verify(allocator, compilation.ir);
    const raw = try Silex.Interpreter.runCapture(allocator, compilation.ir);
    for (Silex.ReleaseOptimizer.pass_descriptors) |descriptor| {
        const prefix = try Silex.ReleaseOptimizer.optimizeWithOptions(allocator, compilation.ir, .{
            .verify_each_pass = true,
            .stop_after = descriptor.id,
        });
        const prefix_execution = try Silex.Interpreter.runCapture(allocator, prefix);
        if (!equalRun(raw, prefix_execution)) return error.ReleasePrefixSemanticMismatch;
    }
    const optimized = try Silex.ReleaseOptimizer.optimizeWithOptions(allocator, compilation.ir, .{
        .verify_each_pass = true,
    });
    try Silex.ReleaseVerifier.verify(allocator, optimized);
    const release = try Silex.Interpreter.runCapture(allocator, optimized);
    if (!equalRun(raw, release)) return error.SemanticMismatch;

    const raw_text = try Silex.Ir.writeText(allocator, compilation.ir);
    const optimized_text = try Silex.Ir.writeText(allocator, optimized);
    if (raw_text.len > maximum_ir_bytes or optimized_text.len > maximum_ir_bytes)
        return error.IrBudgetExceeded;
    _ = try Silex.Arm64Lower.lowerWithMode(allocator, optimized, .release);
    const stack_machine = try Silex.Arm64Lower.lowerWithMode(allocator, optimized, .debug);
    _ = try Silex.X64RegisterAllocation.allocateProgram(allocator, stack_machine);

    return .{
        .source_sha256 = combinedSourceHash(sources),
        .raw_ir_sha256 = sha256(raw_text),
        .optimized_ir_sha256 = sha256(optimized_text),
        .output_sha256 = runHash(raw),
        .raw_ir_bytes = raw_text.len,
        .optimized_ir_bytes = optimized_text.len,
        .release_prefixes = Silex.ReleaseOptimizer.pass_descriptors.len,
    };
}

fn verifyNegativeCorpus(
    io: std.Io,
    allocator: std.mem.Allocator,
    writer: *std.Io.Writer,
) !usize {
    _ = io;
    const invalid = [_]struct { id: []const u8, source: []const u8 }{
        .{ .id = "unknown-name", .source = "func main() { print(missing_value) }" },
        .{ .id = "type-mismatch", .source = "func main() { let value:int = true; print(value) }" },
        .{ .id = "invalid-loop", .source = "func main() { for value in 42 { print(value) } }" },
        .{ .id = "immutable-mutation", .source = "func main() { let values = [1, 2]; values.append(3) }" },
    };
    for (invalid) |entry| {
        const first = try invalidDiagnostic(allocator, entry.source);
        const repeated = try invalidDiagnostic(allocator, entry.source);
        if (!std.mem.eql(u8, first, repeated)) return error.UnstableDiagnostic;
        const request: InteractionGenerator.Request = .{
            .seed = 0,
            .first_axis = "invalid",
            .first_state = true,
        };
        const source_hash = sha256(entry.source);
        const diagnostic_hash = sha256(first);
        const verification: Verification = .{
            .source_sha256 = source_hash,
            .raw_ir_sha256 = [_]u8{'-'} ** 64,
            .optimized_ir_sha256 = [_]u8{'-'} ** 64,
            .output_sha256 = diagnostic_hash,
            .raw_ir_bytes = 0,
            .optimized_ir_bytes = 0,
            .release_prefixes = 0,
        };
        try writeRow(writer, "negative", entry.id, request, verification, false);
    }
    return invalid.len;
}

fn invalidDiagnostic(allocator: std.mem.Allocator, source: []const u8) ![]const u8 {
    var frontend = Silex.Frontend.init(allocator);
    _ = frontend.compile(source) catch |err| {
        if (err != error.InvalidSource) return err;
        const diagnostic = frontend.diagnostic orelse return error.MissingDiagnostic;
        if (diagnostic.message.len == 0) return error.MissingDiagnostic;
        return diagnostic.message;
    };
    return error.InvalidSourceAccepted;
}

fn writeRow(
    writer: *std.Io.Writer,
    kind: []const u8,
    id: []const u8,
    request: InteractionGenerator.Request,
    verification: Verification,
    native: bool,
) !void {
    try writer.print(
        "{s}\t{s}\t{d}\t{s}\t{d}\t{s}\t{d}\t{s}\t{s}\t{s}\t{s}\t{s}\t{s}\t{s}\t{d}\t{d}\t{d}\tpassed\tpassed\t{s}\t{s}\n",
        .{
            kind,
            id,
            request.seed,
            request.first_axis,
            @intFromBool(request.first_state),
            request.second_axis orelse "-",
            @intFromBool(request.second_state),
            request.risk_triplet orelse "-",
            &verification.source_sha256,
            &verification.raw_ir_sha256,
            &verification.optimized_ir_sha256,
            &verification.output_sha256,
            &verification.native_debug_sha256,
            &verification.native_release_sha256,
            verification.raw_ir_bytes,
            verification.optimized_ir_bytes,
            verification.release_prefixes,
            if (native) "passed" else "not-selected",
            if (native) "passed" else "not-selected",
        },
    );
}

fn fileSha256(
    allocator: std.mem.Allocator,
    io: std.Io,
    stem: []const u8,
    suffix: []const u8,
) ![64]u8 {
    const path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ stem, suffix });
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(maximum_native_bytes + 1));
    return sha256(bytes);
}

fn sealReport(io: std.Io, allocator: std.mem.Allocator, path: []const u8, bytes: []const u8) !void {
    const existing = std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(32 * 1024 * 1024)) catch |err| switch (err) {
        error.FileNotFound => {
            try writeFile(io, path, bytes);
            return;
        },
        else => return err,
    };
    if (!std.mem.eql(u8, existing, bytes)) return error.SealedReportConflict;
}

fn writeFile(io: std.Io, path: []const u8, bytes: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}

fn equalRun(left: Silex.Interpreter.RunResult, right: Silex.Interpreter.RunResult) bool {
    return left.exit_code == right.exit_code and
        std.mem.eql(u8, left.stdout, right.stdout) and
        std.mem.eql(u8, left.stderr, right.stderr);
}

fn combinedSourceHash(sources: InteractionGenerator.Sources) [64]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(sources.main);
    if (sources.support) |support| hasher.update(support);
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn runHash(result: Silex.Interpreter.RunResult) [64]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(&.{result.exit_code});
    hasher.update(result.stdout);
    hasher.update(result.stderr);
    var digest: [32]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn sha256(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}

const Verdict = struct {
    value_sha256: [64]u8,
    effect_sha256: [64]u8,
    diagnostic_sha256: [64]u8,
    exit_code: u8,
    debug: bool,
    release: bool,
    target: bool,
    cache: bool,
};

fn validateVerdict(expected: Verdict, actual: Verdict) !void {
    if (!std.mem.eql(u8, &expected.value_sha256, &actual.value_sha256)) return error.ValueMutationUndetected;
    if (!std.mem.eql(u8, &expected.effect_sha256, &actual.effect_sha256)) return error.EffectMutationUndetected;
    if (!std.mem.eql(u8, &expected.diagnostic_sha256, &actual.diagnostic_sha256)) return error.DiagnosticMutationUndetected;
    if (expected.exit_code != actual.exit_code) return error.ExitMutationUndetected;
    if (expected.debug != actual.debug or expected.release != actual.release) return error.ModeMutationUndetected;
    if (expected.target != actual.target) return error.TargetMutationUndetected;
    if (expected.cache != actual.cache) return error.CacheMutationUndetected;
}

test "verdict mutations cover every observable adversarial dimension" {
    const digest = sha256("stable");
    const other = sha256("mutated");
    const baseline: Verdict = .{
        .value_sha256 = digest,
        .effect_sha256 = digest,
        .diagnostic_sha256 = digest,
        .exit_code = 0,
        .debug = true,
        .release = true,
        .target = true,
        .cache = true,
    };
    var mutation = baseline;
    mutation.value_sha256 = other;
    try std.testing.expectError(error.ValueMutationUndetected, validateVerdict(baseline, mutation));
    mutation = baseline;
    mutation.effect_sha256 = other;
    try std.testing.expectError(error.EffectMutationUndetected, validateVerdict(baseline, mutation));
    mutation = baseline;
    mutation.diagnostic_sha256 = other;
    try std.testing.expectError(error.DiagnosticMutationUndetected, validateVerdict(baseline, mutation));
    mutation = baseline;
    mutation.exit_code = 1;
    try std.testing.expectError(error.ExitMutationUndetected, validateVerdict(baseline, mutation));
    mutation = baseline;
    mutation.debug = false;
    try std.testing.expectError(error.ModeMutationUndetected, validateVerdict(baseline, mutation));
    mutation = baseline;
    mutation.target = false;
    try std.testing.expectError(error.TargetMutationUndetected, validateVerdict(baseline, mutation));
    mutation = baseline;
    mutation.cache = false;
    try std.testing.expectError(error.CacheMutationUndetected, validateVerdict(baseline, mutation));
}

test "all registered axes change the generated source" {
    const axes = [_][]const u8{ "type", "control", "memory", "alias", "call", "loop", "error", "package", "target" };
    for (axes) |axis| {
        const disabled = try InteractionGenerator.source(std.testing.allocator, .{
            .seed = 99,
            .first_axis = axis,
            .first_state = false,
        });
        defer std.testing.allocator.free(disabled.main);
        const enabled = try InteractionGenerator.source(std.testing.allocator, .{
            .seed = 99,
            .first_axis = axis,
            .first_state = true,
        });
        defer std.testing.allocator.free(enabled.main);
        try std.testing.expect(!std.mem.eql(u8, disabled.main, enabled.main) or disabled.support != enabled.support);
    }
}
