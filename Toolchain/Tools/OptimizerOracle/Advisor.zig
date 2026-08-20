const std = @import("std");
const IrStats = @import("IrStats.zig");
const LlvmStats = @import("LlvmStats.zig");

pub const Kind = enum {
    stack_to_ssa,
    loop_induction_ssa,
    safety_check_elision,
    interprocedural_specialization,
    constant_propagation,
    control_flow_simplification,
    strength_reduction,
    range_analysis,
    conversion_elision,
    vectorization,

    pub fn label(self: Kind) []const u8 {
        return switch (self) {
            .stack_to_ssa => "promotion of local variables to SSA",
            .loop_induction_ssa => "loop induction variables and PHI nodes",
            .safety_check_elision => "proven safety-check elimination",
            .interprocedural_specialization => "interprocedural specialization and inlining",
            .constant_propagation => "constant propagation and dead-code elimination",
            .control_flow_simplification => "control-flow graph simplification",
            .strength_reduction => "arithmetic strength reduction",
            .range_analysis => "range and signedness analysis",
            .conversion_elision => "redundant conversion elimination",
            .vectorization => "loop and lane vectorization",
        };
    }

    pub fn action(self: Kind) []const u8 {
        return switch (self) {
            .stack_to_ssa => "Promote non-escaping locals to SSA, then remove redundant loads and stores.",
            .loop_induction_ssa => "Recognize induction variables and represent them with PHI nodes to expose loop invariants.",
            .safety_check_elision => "Use range and dominance proofs to remove only checks already implied by control flow.",
            .interprocedural_specialization => "Specialize small calls for known arguments before inlining and dead-code elimination.",
            .constant_propagation => "Propagate constants across calls and branches, then remove unreachable computations and blocks.",
            .control_flow_simplification => "Merge equivalent blocks and branches after propagation while preserving reused values.",
            .strength_reduction => "Canonicalize multiplication and division by powers of two into shifts when semantics permit.",
            .range_analysis => "Propagate ranges, signedness, and non-negativity to select simpler operations and prove checks.",
            .conversion_elision => "Compose consecutive conversions and remove those whose source range already fits the target.",
            .vectorization => "Extend SLP and dependence analysis to loops where LLVM materializes vector operations.",
        };
    }
};

pub const Finding = struct {
    kind: Kind,
    score: u8,
    evidence: []const u8,
};

pub const Analysis = struct {
    findings: []const Finding,
};

pub const SummaryEntry = struct {
    kind: Kind,
    workloads: usize = 0,
    score_sum: usize = 0,
    maximum_score: u8 = 0,
};

const kind_count = @typeInfo(Kind).@"enum".fields.len;

pub const Summary = struct {
    entries: [kind_count]SummaryEntry = initialSummary(),

    pub fn add(self: *Summary, analysis: Analysis) void {
        var observed: [kind_count]bool = @splat(false);
        for (analysis.findings) |finding| {
            const index = @intFromEnum(finding.kind);
            self.entries[index].score_sum += finding.score;
            self.entries[index].maximum_score = @max(self.entries[index].maximum_score, finding.score);
            if (!observed[index]) {
                self.entries[index].workloads += 1;
                observed[index] = true;
            }
        }
    }

    pub fn ranked(self: Summary, allocator: std.mem.Allocator) ![]SummaryEntry {
        var result: std.ArrayList(SummaryEntry) = .empty;
        for (self.entries) |entry| if (entry.workloads != 0) try result.append(allocator, entry);
        std.mem.sort(SummaryEntry, result.items, {}, struct {
            fn lessThan(_: void, left: SummaryEntry, right: SummaryEntry) bool {
                if (left.score_sum != right.score_sum) return left.score_sum > right.score_sum;
                return left.maximum_score > right.maximum_score;
            }
        }.lessThan);
        return result.toOwnedSlice(allocator);
    }
};

pub fn analyze(
    allocator: std.mem.Allocator,
    raw_silex: IrStats.Profile,
    optimized_silex: IrStats.Profile,
    llvm: LlvmStats.Comparison,
) !Analysis {
    var findings: std.ArrayList(Finding) = .empty;
    const raw_llvm = llvm.raw;
    const optimized_llvm = llvm.optimized;
    const llvm_memory_removed = llvm.matched.memory_removed;
    const silex_local_removed = removed(
        raw_silex.local_loads + raw_silex.local_stores,
        optimized_silex.local_loads + optimized_silex.local_stores,
    );
    if (llvm_memory_removed >= 2 and llvm_memory_removed > silex_local_removed) try append(
        allocator,
        &findings,
        .stack_to_ssa,
        score(88, llvm_memory_removed, 2),
        "LLVM removes {d} local-memory operations ({d} -> {d}); Silex removes {d}.",
        .{ llvm_memory_removed, raw_llvm.memoryOperations(), optimized_llvm.memoryOperations(), silex_local_removed },
    );

    if (raw_silex.loop_back_edges != 0 and llvm.matched.phis_added != 0) try append(
        allocator,
        &findings,
        .loop_induction_ssa,
        score(82, llvm.matched.phis_added, 1),
        "LLVM introduces {d} additional PHI nodes in a program with {d} Silex loop back edge(s).",
        .{ llvm.matched.phis_added, raw_silex.loop_back_edges },
    );

    const llvm_safety_removed = llvm.matched.safety_removed;
    const silex_checks_removed = removed(raw_silex.checked_operations, optimized_silex.checked_operations);
    if (llvm_safety_removed != 0 and llvm_safety_removed > silex_checks_removed) try append(
        allocator,
        &findings,
        .safety_check_elision,
        score(86, llvm_safety_removed, 2),
        "LLVM proves and removes {d} safety guard(s); Silex removes {d} checked operation(s).",
        .{ llvm_safety_removed, silex_checks_removed },
    );

    const internal_calls_removed = llvm.matched.internal_calls_removed;
    if (internal_calls_removed != 0) try append(
        allocator,
        &findings,
        .interprocedural_specialization,
        score(76, internal_calls_removed, 1),
        "LLVM eliminates {d} internal Silex call(s) ({d} -> {d}) through specialization and inlining.",
        .{ internal_calls_removed, raw_llvm.internal_calls, optimized_llvm.internal_calls },
    );

    const llvm_compute_removed = llvm.matched.compute_removed;
    const silex_compute_removed = removed(
        raw_silex.arithmetic + raw_silex.comparisons + raw_silex.conversions,
        optimized_silex.arithmetic + optimized_silex.comparisons + optimized_silex.conversions,
    );
    if ((optimized_llvm.constant_prints > raw_llvm.constant_prints or llvm_compute_removed >= 3) and
        llvm_compute_removed > silex_compute_removed)
    {
        try append(
            allocator,
            &findings,
            .constant_propagation,
            score(80, llvm_compute_removed, 3),
            "LLVM removes {d} computation(s) and produces {d} constant print operation(s); Silex removes {d} computation(s).",
            .{ llvm_compute_removed, optimized_llvm.constant_prints, silex_compute_removed },
        );
    }

    const llvm_blocks_removed = llvm.matched.blocks_removed;
    const silex_blocks_removed = removed(raw_silex.counts.blocks, optimized_silex.counts.blocks);
    if (llvm_blocks_removed != 0 and llvm_blocks_removed > silex_blocks_removed) try append(
        allocator,
        &findings,
        .control_flow_simplification,
        score(72, llvm_blocks_removed, 1),
        "LLVM removes {d} block(s) from the same functions; Silex removes {d}.",
        .{ llvm_blocks_removed, silex_blocks_removed },
    );

    const multiplies_removed = llvm.matched.multiplies_removed;
    const shifts_added = llvm.matched.shifts_added;
    if (multiplies_removed != 0 and shifts_added != 0 and optimized_silex.shifts <= raw_silex.shifts) try append(
        allocator,
        &findings,
        .strength_reduction,
        72,
        "LLVM replaces at least {d} multiplication(s) with {d} additional shift(s); Silex adds no shifts.",
        .{ multiplies_removed, shifts_added },
    );

    const signed_remainders_removed = llvm.matched.signed_remainders_removed;
    const unsigned_remainders_added = llvm.matched.unsigned_remainders_added;
    if ((signed_remainders_removed != 0 and unsigned_remainders_added != 0) or
        llvm.matched.range_attributes_added != 0)
    {
        try append(
            allocator,
            &findings,
            .range_analysis,
            70,
            "LLVM derives {d} new range attribute(s) and converts {d} signed remainder operation(s) to unsigned.",
            .{ llvm.matched.range_attributes_added, unsigned_remainders_added },
        );
    }

    const llvm_conversions_removed = llvm.matched.conversions_removed;
    const silex_conversions_removed = removed(raw_silex.conversions, optimized_silex.conversions);
    if (llvm_conversions_removed != 0 and llvm_conversions_removed > silex_conversions_removed) try append(
        allocator,
        &findings,
        .conversion_elision,
        score(68, llvm_conversions_removed, 1),
        "LLVM removes {d} conversion(s); Silex removes {d}.",
        .{ llvm_conversions_removed, silex_conversions_removed },
    );

    const vector_operations_added = llvm.matched.vector_operations_added;
    if (vector_operations_added != 0) try append(
        allocator,
        &findings,
        .vectorization,
        score(90, vector_operations_added, 1),
        "LLVM introduces {d} vector operation(s) absent from the initial IR.",
        .{vector_operations_added},
    );

    std.mem.sort(Finding, findings.items, {}, struct {
        fn lessThan(_: void, left: Finding, right: Finding) bool {
            return left.score > right.score;
        }
    }.lessThan);
    return .{ .findings = try findings.toOwnedSlice(allocator) };
}

fn append(
    allocator: std.mem.Allocator,
    findings: *std.ArrayList(Finding),
    kind: Kind,
    finding_score: u8,
    comptime format: []const u8,
    arguments: anytype,
) !void {
    try findings.append(allocator, .{
        .kind = kind,
        .score = finding_score,
        .evidence = try std.fmt.allocPrint(allocator, format, arguments),
    });
}

fn removed(before: usize, after: usize) usize {
    return before -| after;
}

fn score(base: u8, evidence: usize, unit: usize) u8 {
    return @min(100, base + @as(u8, @intCast(@min(12, evidence / unit))));
}

fn initialSummary() [kind_count]SummaryEntry {
    var entries: [kind_count]SummaryEntry = undefined;
    for (&entries, 0..) |*entry, index| entry.* = .{ .kind = @enumFromInt(index) };
    return entries;
}

test "advisor guidance uses stable English labels" {
    const expected_labels = [_][]const u8{
        "promotion of local variables to SSA",
        "loop induction variables and PHI nodes",
        "proven safety-check elimination",
        "interprocedural specialization and inlining",
        "constant propagation and dead-code elimination",
        "control-flow graph simplification",
        "arithmetic strength reduction",
        "range and signedness analysis",
        "redundant conversion elimination",
        "loop and lane vectorization",
    };

    for (expected_labels, 0..) |expected, index| {
        const kind: Kind = @enumFromInt(index);
        try std.testing.expectEqualStrings(expected, kind.label());
        for (kind.action()) |byte| try std.testing.expect(byte < 0x80);
    }
}

test "advisor ranks SSA promotion and safety proof from concrete deltas" {
    var raw_silex: IrStats.Profile = .{};
    raw_silex.local_loads = 4;
    raw_silex.local_stores = 3;
    raw_silex.checked_operations = 4;
    raw_silex.loop_back_edges = 1;
    const optimized_silex = raw_silex;
    var raw_llvm: LlvmStats.Profile = .{};
    raw_llvm.allocas = 2;
    raw_llvm.loads = 4;
    raw_llvm.stores = 3;
    raw_llvm.overflow_intrinsics = 4;
    raw_llvm.trap_branches = 4;
    var optimized_llvm: LlvmStats.Profile = .{};
    optimized_llvm.phis = 2;
    const analysis = try analyze(std.testing.allocator, raw_silex, optimized_silex, .{
        .raw = raw_llvm,
        .optimized = optimized_llvm,
        .matched = .{
            .memory_removed = 9,
            .phis_added = 2,
            .safety_removed = 8,
        },
    });
    defer {
        for (analysis.findings) |finding| std.testing.allocator.free(finding.evidence);
        std.testing.allocator.free(analysis.findings);
    }
    try std.testing.expect(analysis.findings.len >= 3);
    try std.testing.expectEqual(Kind.stack_to_ssa, analysis.findings[0].kind);
    try std.testing.expectEqualStrings(
        "LLVM removes 9 local-memory operations (9 -> 0); Silex removes 0.",
        analysis.findings[0].evidence,
    );
}
