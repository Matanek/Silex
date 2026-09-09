const std = @import("std");
const Contract = @import("Lsp/CompletionContract.zig");
const Composition = @import("Lsp/CompletionContract/Composition.zig");
const CorpusAudit = @import("Lsp/CorpusAudit.zig");
const LspTypes = @import("Lsp/Types.zig");

// Maintainer rule: a syntax, AST/type-flow, semantic producer/consumer,
// transform, topology, editing, or trigger addition must extend its exhaustive
// policy and permanent proof before the ordinary build is allowed to pass.
// Quantified totals are intentionally pinned: changing them is an explicit
// contract migration, never an incidental regeneration.

test "ordinary build admits the complete clean completion contract" {
    try Contract.auditRelease(&Contract.scenarios);
    try Composition.auditRelease();

    const statistics = try Composition.audit();
    try std.testing.expectEqual(@as(usize, 65_340), statistics.total);
    try std.testing.expectEqual(@as(usize, 3_035), statistics.proved);
    try std.testing.expectEqual(@as(usize, 0), statistics.required);
    try std.testing.expectEqual(@as(usize, 62_305), statistics.excluded);
    try std.testing.expectEqual(@as(usize, 4), statistics.schemas);
    try std.testing.expectEqual(@as(usize, 10), std.meta.fields(Composition.DemandKind).len);
    try std.testing.expectEqual(@as(usize, 27), std.meta.fields(Composition.ProducerKind).len);
    try std.testing.expectEqual(@as(usize, 22), std.meta.fields(Composition.ConsumerKind).len);
    try std.testing.expectEqual(@as(usize, 11), std.meta.fields(Composition.TransformKind).len);
    try std.testing.expectEqual(@as(usize, 12), std.meta.fields(Composition.EditingMutation).len);
    try std.testing.expectEqual(@as(usize, 15), std.meta.fields(Composition.TopologyKind).len);
    try std.testing.expectEqual(@as(usize, 7), std.meta.fields(LspTypes.CompletionTriggerCharacter).len);
}

test "every ecosystem classification maps to a permanent completion proof" {
    comptime {
        @setEvalBranchQuota(100_000);
        if (CorpusAudit.proof_mappings.len != std.meta.fields(CorpusAudit.Signal).len) {
            @compileError("every corpus signal needs exactly one permanent proof mapping");
        }
        for (CorpusAudit.proof_mappings, 0..) |mapping, index| {
            if (!Contract.hasScenario(mapping.scenario)) {
                @compileError(std.fmt.comptimePrint(
                    "corpus signal {s} names missing completion proof {s}",
                    .{ @tagName(mapping.signal), mapping.scenario },
                ));
            }
            for (CorpusAudit.proof_mappings[index + 1 ..]) |other| {
                if (mapping.signal == other.signal) {
                    @compileError(std.fmt.comptimePrint(
                        "corpus signal {s} has more than one proof mapping",
                        .{@tagName(mapping.signal)},
                    ));
                }
            }
        }
    }
}
