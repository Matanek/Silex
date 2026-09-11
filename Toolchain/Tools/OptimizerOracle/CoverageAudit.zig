const std = @import("std");
const Silex = @import("silex_optimizer_api");
const Registry = @import("Registry.zig");
const Generator = @import("Generator.zig");
const Differential = @import("Differential.zig");
const Llvm = @import("Llvm.zig");
const LlvmCoverage = @import("LlvmCoverage.zig");
const IrStats = @import("IrStats.zig");
const Parity = @import("Parity.zig");

const Allocator = std.mem.Allocator;
pub const Family = struct {
    id: []const u8,
    positive_cases: []const []const u8,
    negative_cases: []const []const u8,
    passes: []const []const u8,
    ir_families: []const []const u8,
    preconditions: []const u8,
    scope: enum { @"bounded-corpus" },
    open_questions: []const []const u8,
    next_experiment: []const u8,
    owner: enum { optimizer, @"llvm-bridge", machine, qualification },
    targets: []const []const u8,
};
const Technique = struct { family: []const u8, coverage_ids: []const []const u8 };
pub const Manifest = struct { schema_version: u32, families: []const Family, techniques: []const Technique };

pub fn load(allocator: Allocator, io: std.Io, directory: []const u8) !Manifest {
    const path = try std.fs.path.join(allocator, &.{ directory, "Assurance.json" });
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(1024 * 1024));
    return std.json.parseFromSliceLeaky(Manifest, allocator, bytes, .{});
}

pub fn audit(manifest: Manifest, registry: Registry.Manifest) !void {
    if (manifest.schema_version != 1) return error.UnsupportedAssuranceSchema;
    if (manifest.families.len != registry.coverage.len) return error.IncompleteAssuranceCoverage;
    for (registry.coverage) |coverage| {
        var found: usize = 0;
        for (manifest.families) |family| if (same(family.id, coverage.id)) {
            found += 1;
        };
        if (found != 1) return error.IncompleteAssuranceCoverage;
    }
    for (manifest.families) |family| {
        if (family.preconditions.len == 0 or family.next_experiment.len == 0 or
            family.open_questions.len == 0 or family.targets.len == 0 or
            family.positive_cases.len == 0 or family.negative_cases.len == 0)
            return error.IncompleteAssuranceScope;
        // This schema describes bounded evidence. It cannot promote an entry to
        // general parity by deleting its questions or changing a status boolean.
        try unique(family.open_questions);
        try unique(family.targets);
        if (!contains(family.targets, "arm64") or !contains(family.targets, "x64"))
            return error.IncompleteAssuranceTargets;
        for (family.targets) |target| if (!same(target, "arm64") and !same(target, "x64"))
            return error.InvalidAssuranceTarget;
        try auditCases(family.positive_cases);
        try auditCases(family.negative_cases);
        try unique(family.passes);
        for (family.passes) |pass| {
            var found = false;
            for (registry.passes) |entry| if (same(entry.id, pass)) {
                found = true;
            };
            if (!found) return error.UnknownAssurancePass;
        }
        try unique(family.ir_families);
        for (family.ir_families) |name| {
            var found = false;
            for (registry.portable_ir) |entry| if (same(entry.family, name)) {
                found = true;
            };
            if (!found) return error.UnknownAssuranceIrFamily;
        }
    }
    for (registry.passes) |pass| {
        var found = false;
        for (manifest.families) |family| for (family.passes) |name| {
            if (same(pass.id, name)) found = true;
        };
        if (!found) return error.UnownedAssurancePass;
    }
    for (registry.portable_ir) |ir_family| {
        var found = false;
        for (manifest.families) |family| for (family.ir_families) |name| {
            if (same(ir_family.family, name)) found = true;
        };
        if (!found) return error.UnownedAssuranceIrFamily;
    }
    if (manifest.techniques.len != registry.transposition.len) return error.IncompleteAssuranceTechniques;
    for (registry.transposition) |entry| {
        var occurrences: usize = 0;
        for (manifest.techniques) |technique| if (same(entry.family, technique.family)) {
            occurrences += 1;
        };
        if (occurrences != 1) return error.IncompleteAssuranceTechniques;
    }
    for (manifest.techniques) |technique| {
        if (technique.coverage_ids.len == 0) return error.UnownedAssuranceTechnique;
        try unique(technique.coverage_ids);
        for (technique.coverage_ids) |id| {
            var found = false;
            for (manifest.families) |family| if (same(family.id, id)) {
                found = true;
            };
            if (!found) return error.UnknownAssuranceFamily;
        }
    }
    for (Generator.corpus) |entry| {
        if (!entry.timing) continue;
        var found = false;
        for (manifest.families) |family| if (contains(family.positive_cases, entry.name)) {
            found = true;
        };
        if (!found) return error.UnownedTimingCase;
    }
}

fn auditCases(cases: []const []const u8) !void {
    try unique(cases);
    for (cases) |name| {
        var found = false;
        for (Generator.corpus) |entry| if (same(entry.name, name)) {
            found = true;
        };
        for (Generator.regressions) |entry| if (same(entry.name, name)) {
            found = true;
        };
        if (!found) return error.UnknownAssuranceCase;
    }
}

fn unique(values: []const []const u8) !void {
    for (values, 0..) |value, index| {
        if (value.len == 0) return error.EmptyAssuranceValue;
        if (contains(values[0..index], value)) return error.DuplicateAssuranceValue;
    }
}
fn contains(values: []const []const u8, value: []const u8) bool {
    for (values) |item| if (same(item, value)) return true;
    return false;
}
fn same(left: []const u8, right: []const u8) bool {
    return std.mem.eql(u8, left, right);
}

pub fn report(allocator: Allocator, io: std.Io, manifest: Manifest, registry: Registry.Manifest, directory: []const u8) !void {
    const output = ".zig-cache/optimizer-oracle";
    try std.Io.Dir.cwd().createDirPath(io, output);
    var table: std.Io.Writer.Allocating = .init(allocator);
    defer table.deinit();
    try table.writer.writeAll("family\tlegacy_state\tlegacy_timing_proofs\tcurrent_timing_cases\tscope\towner\topen_questions\n");
    for (manifest.families) |family| {
        var state: []const u8 = "unknown";
        var timing_proofs: usize = 0;
        for (registry.coverage) |entry| {
            if (!same(family.id, entry.id)) continue;
            state = entry.state;
            for (entry.proof_ids) |id| for (registry.proofs) |proof| {
                if (same(proof.id, id) and same(proof.kind, "timing")) timing_proofs += 1;
            };
        }
        var timing_cases: usize = 0;
        for (Generator.corpus) |entry| if (entry.timing and contains(family.positive_cases, entry.name)) {
            timing_cases += 1;
        };
        try table.writer.print("{s}\t{s}\t{d}\t{d}\t{s}\t{s}\t{d}\n", .{ family.id, state, timing_proofs, timing_cases, @tagName(family.scope), @tagName(family.owner), family.open_questions.len });
    }
    try write(io, output ++ "/assurance.tsv", table.written());
    table.clearRetainingCapacity();
    try table.writer.writeAll("ir_operation\tllvm_model\n");
    var modeled: usize = 0;
    inline for (@typeInfo(Silex.Ir.Instruction).@"union".fields) |field| {
        const support = LlvmCoverage.classify(@field(std.meta.Tag(Silex.Ir.Instruction), field.name));
        if (support != .unsupported) modeled += 1;
        try table.writer.print("{s}\t{s}\n", .{ field.name, @tagName(support) });
    }
    try write(io, output ++ "/llvm-operation-coverage.tsv", table.written());
    table.clearRetainingCapacity();
    try table.writer.writeAll("proof\tkind\tsource_identity\toutcome\n");
    try validateCompilerHistory(allocator, io, registry, directory);
    for (registry.proofs) |proof| {
        if (!same(proof.repository, "Silex")) continue;
        const path = try std.fs.path.join(allocator, &.{ directory, "../../..", proof.source });
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .limited(16 * 1024 * 1024));
        const identity = if (same(&sha256(bytes), proof.source_sha256)) "current-source-historical-run" else "changed-source-historical-run";
        try table.writer.print("{s}\t{s}\t{s}\t{s}\n", .{ proof.id, proof.kind, identity, proof.outcome });
    }
    try write(io, output ++ "/proof-scope.tsv", table.written());
    const summary = try std.fmt.allocPrint(allocator, "coverage audit: {d} bounded families, {d} LLVM techniques, {d}/{d} modeled IR operation tags (including abstract lifetime operations)\nqualified timing policy: >= {d} pairs, <= {d} ppm spread; global parity not established by this audit\nreports: {s}/assurance.tsv, llvm-operation-coverage.tsv, proof-scope.tsv\n", .{ manifest.families.len, manifest.techniques.len, modeled, @typeInfo(Silex.Ir.Instruction).@"union".fields.len, Parity.minimum_samples, Parity.maximum_spread_ppm, output });
    try std.Io.File.stdout().writeStreamingAll(io, summary);
}

fn validateCompilerHistory(allocator: Allocator, io: std.Io, registry: Registry.Manifest, directory: []const u8) !void {
    const root = try std.fs.path.join(allocator, &.{ directory, "../../.." });
    for (registry.proofs) |proof| {
        if (!same(proof.repository, "Silex")) continue;
        const ancestor = try std.process.run(allocator, io, .{ .argv = &.{ "git", "-C", root, "merge-base", "--is-ancestor", proof.revision, "HEAD" } });
        if (ancestor.term != .exited or ancestor.term.exited != 0) return error.UnavailableHistoricalProof;
        const object = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ proof.revision, proof.source });
        const historical = try std.process.run(allocator, io, .{ .argv = &.{ "git", "-C", root, "show", object }, .stdout_limit = .limited(16 * 1024 * 1024) });
        if (historical.term != .exited or historical.term.exited != 0) return error.UnavailableHistoricalProof;
        if (!same(&sha256(historical.stdout), proof.source_sha256)) return error.HistoricalProofSourceMismatch;
    }
}

pub fn scan(allocator: Allocator, io: std.Io, directory: []const u8) !void {
    try std.Io.Dir.cwd().createDirPath(io, ".zig-cache/optimizer-oracle");
    // A failed attempt must not leave an older complete scan looking current.
    for ([_][]const u8{
        ".zig-cache/optimizer-oracle/llvm-case-coverage.tsv",
        ".zig-cache/optimizer-oracle/llvm-case-coverage.partial.tsv",
    }) |path| std.Io.Dir.cwd().deleteFile(io, path) catch |err| switch (err) {
        error.FileNotFound => {},
        else => return err,
    };
    var seen: std.StringHashMap(void) = .init(allocator);
    defer seen.deinit();
    var table: std.Io.Writer.Allocating = .init(allocator);
    defer table.deinit();
    errdefer write(io, ".zig-cache/optimizer-oracle/llvm-case-coverage.partial.tsv", table.written()) catch {};
    try table.writer.writeAll("case\tsource_sha256\tsemantic\tllvm_raw\tllvm_release\ttimed\traw_unmodeled_tags\trelease_unmodeled_tags\n");
    for (Generator.corpus) |entry| {
        try seen.put(entry.name, {});
        try probe(allocator, io, directory, entry.name, entry.timing, &table.writer);
    }
    for (Generator.regressions) |entry| {
        if (seen.contains(entry.name)) continue;
        try seen.put(entry.name, {});
        try probe(allocator, io, directory, entry.name, false, &table.writer);
    }
    try write(io, ".zig-cache/optimizer-oracle/llvm-case-coverage.tsv", table.written());
    try std.Io.File.stdout().writeStreamingAll(io, "LLVM case coverage written to .zig-cache/optimizer-oracle/llvm-case-coverage.tsv; emission alone is not execution evidence\n");
}

fn probe(allocator: Allocator, io: std.Io, directory: []const u8, name: []const u8, timed: bool, writer: *std.Io.Writer) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const path = try std.fs.path.join(a, &.{ directory, name });
    const source = try std.Io.Dir.cwd().readFileAlloc(io, path, a, .limited(1024 * 1024));
    const result = Differential.verifyPath(io, a, path) catch |err| {
        std.debug.print("coverage probe failed for {s}: {t}\n", .{ name, err });
        return err;
    };
    const raw = try emission(a, result.raw_ir, result.boundaries);
    const optimized = try emission(a, result.optimized_ir, result.boundaries);
    try writer.print("{s}\t{s}\tmatched\t{s}\t{s}\t{any}\t{s}\t{s}\n", .{
        name,                                sha256(source),                            raw, optimized, timed,
        try unmodeledTags(a, result.raw_ir), try unmodeledTags(a, result.optimized_ir),
    });
}
fn unmodeledTags(allocator: Allocator, program: Silex.Ir.Program) ![]const u8 {
    const Tag = std.meta.Tag(Silex.Ir.Instruction);
    var seen = std.EnumSet(Tag).initEmpty();
    const reachable = try IrStats.reachableFunctions(allocator, program);
    for (program.functions, 0..) |function, function_index| {
        if (!reachable[function_index]) continue;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            const tag = std.meta.activeTag(instruction);
            if (LlvmCoverage.classify(tag) == .unsupported) seen.insert(tag);
        };
    }
    var names: std.Io.Writer.Allocating = .init(allocator);
    defer names.deinit();
    var iterator = seen.iterator();
    while (iterator.next()) |tag| {
        if (names.written().len != 0) try names.writer.writeByte(',');
        try names.writer.writeAll(@tagName(tag));
    }
    return allocator.dupe(u8, names.written());
}

fn emission(
    allocator: Allocator,
    program: Silex.Ir.Program,
    boundaries: []const Silex.Boundary.Function,
) ![]const u8 {
    _ = Llvm.emitWithBoundaries(allocator, program, boundaries) catch |err| switch (err) {
        error.UnsupportedInstruction, error.UnsupportedType => return @errorName(err),
        else => return err,
    };
    return "emitted";
}
fn sha256(bytes: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
    return std.fmt.bytesToHex(digest, .lower);
}
fn write(io: std.Io, path: []const u8, bytes: []const u8) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, bytes);
}

test "bounded assurance owns every family, pass, IR family and LLVM technique" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const registry = try Registry.load(arena.allocator(), std.testing.io, "Benchmarks/Optimizer");
    const manifest = try load(arena.allocator(), std.testing.io, "Benchmarks/Optimizer");
    try audit(manifest, registry);
}

test "assurance rejects removed coverage, techniques, negative cases and fabricated closure" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const registry = try Registry.load(a, std.testing.io, "Benchmarks/Optimizer");
    var manifest = try load(a, std.testing.io, "Benchmarks/Optimizer");
    const original = manifest;
    manifest.families = manifest.families[1..];
    try std.testing.expectError(error.IncompleteAssuranceCoverage, audit(manifest, registry));
    manifest = original;
    manifest.techniques = manifest.techniques[1..];
    try std.testing.expectError(error.IncompleteAssuranceTechniques, audit(manifest, registry));
    manifest = original;
    const families = try a.dupe(Family, manifest.families);
    manifest.families = families;
    families[0].negative_cases = &.{};
    try std.testing.expectError(error.IncompleteAssuranceScope, audit(manifest, registry));
    families[0] = original.families[0];
    families[0].open_questions = &.{};
    try std.testing.expectError(error.IncompleteAssuranceScope, audit(manifest, registry));
    families[0] = original.families[0];
    families[0].positive_cases = &.{"not-registered.sx"};
    try std.testing.expectError(error.UnknownAssuranceCase, audit(manifest, registry));
    families[0] = original.families[0];
    families[0].passes = &.{};
    try std.testing.expectError(error.UnownedAssurancePass, audit(manifest, registry));
    families[0] = original.families[0];
    families[0].targets = &.{"arm64"};
    try std.testing.expectError(error.IncompleteAssuranceTargets, audit(manifest, registry));
}
