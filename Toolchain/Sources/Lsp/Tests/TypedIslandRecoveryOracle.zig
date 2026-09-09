const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");
const Completion = @import("../Completion.zig");
const Composition = @import("../CompletionContract/Composition.zig");
const Oracle = @import("CompletionOracleSupport.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

const surface =
    \\public struct Surface {
    \\    public func paint() {}
    \\}
;

const FamilyKind = enum { member, cascade, nested_callback, loop_binding, tuple_destructuring };

const Family = struct {
    id: []const u8,
    kind: FamilyKind,
    partial: []const u8,
    target: []const u8,
};

const families = [_]Family{
    .{
        .id = "member",
        .kind = .member,
        .partial = surface ++ "\n" ++
            \\func inspect(surface_value:Surface) {
            \\    surface_value.<|>
            \\}
            \\func main() {}
        ,
        .target = "surface_value.<|>",
    },
    .{
        .id = "cascade",
        .kind = .cascade,
        .partial = surface ++ "\n" ++
            \\func inspect() {
            \\    Surface()..<|>
            \\}
            \\func main() {}
        ,
        .target = "Surface()..<|>",
    },
    .{
        .id = "nested-callback",
        .kind = .nested_callback,
        .partial = surface ++ "\n" ++
            \\func accept(callback:func()) { callback() }
            \\func inspect(surface_value:Surface) {
            \\    accept(func() {
            \\        surface_value.<|>
            \\    })
            \\}
            \\func main() {}
        ,
        .target = "surface_value.<|>",
    },
    .{
        .id = "loop-binding",
        .kind = .loop_binding,
        .partial = surface ++ "\n" ++
            \\func inspect(values:Surface[]) {
            \\    for surface_value in values {
            \\        surface_value.<|>
            \\    }
            \\}
            \\func main() {}
        ,
        .target = "surface_value.<|>",
    },
    .{
        .id = "tuple-destructuring",
        .kind = .tuple_destructuring,
        .partial = surface ++ "\n" ++
            \\func pair() (Surface, int) { return (Surface(), 1) }
            \\func inspect() {
            \\    let (surface_value, count) = pair()
            \\    surface_value.<|>
            \\}
            \\func main() {}
        ,
        .target = "surface_value.<|>",
    },
};

const Equality = enum { exact, prefixed_exact };

fn mutationEquality(mutation: Composition.EditingMutation) Equality {
    return switch (mutation) {
        .prefixed_cursor, .delete_and_retype => .prefixed_exact,
        else => .exact,
    };
}

fn mutatedSource(
    allocator: std.mem.Allocator,
    family: Family,
    mutation: Composition.EditingMutation,
) ![]const u8 {
    return switch (mutation) {
        .empty_cursor => allocator.dupe(u8, family.partial),
        .prefixed_cursor => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try prefixedTarget(allocator, family.target, "pa")),
        .delete_and_retype => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try prefixedTarget(allocator, family.target, "p")),
        .missing_delimiter => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "print({s}", .{family.target})),
        .missing_body => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "if {s}", .{family.target})),
        .nested_expression => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "print({s})", .{family.target})),
        .interpolation => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "print(\"$({s})\")", .{family.target})),
        .unicode_before_cursor => std.fmt.allocPrint(allocator, "// précomposé é 🙂\n{s}", .{family.partial}),
        .error_before_cursor => std.fmt.allocPrint(allocator, "func broken( {{ }}\n{s}", .{family.partial}),
        .error_at_cursor => std.mem.replaceOwned(u8, allocator, family.partial, family.target, try std.fmt.allocPrint(allocator, "if ({s}", .{family.target})),
        .error_after_cursor => std.fmt.allocPrint(allocator, "{s}\nfunc broken( {{ }}", .{family.partial}),
        .error_in_neighbour_block => std.fmt.allocPrint(allocator, "func neighbour() {{ if }}\n{s}", .{family.partial}),
    };
}

fn prefixedTarget(allocator: std.mem.Allocator, target: []const u8, prefix: []const u8) ![]const u8 {
    const marker = std.mem.indexOf(u8, target, "<|>") orelse return error.MissingCompletionMarker;
    return std.fmt.allocPrint(allocator, "{s}{s}<|>{s}", .{ target[0..marker], prefix, target[marker + 3 ..] });
}

fn canonicalSource(allocator: std.mem.Allocator, family: Family) ![]const u8 {
    return std.mem.replaceOwned(u8, allocator, family.partial, "<|>", "paint()");
}

fn expectTypedIsland(
    allocator: std.mem.Allocator,
    server: *ServerModule.Server,
    uri: []const u8,
    source: []const u8,
    clean: []const @import("../Types.zig").CompletionItem,
    equality: Equality,
) !void {
    const actual = try Support.serverCompletionAfterTrigger(server, allocator, uri, source, ".");
    switch (equality) {
        .exact, .prefixed_exact => try Support.expectEqualItems(clean, actual),
    }
    try Support.expectNoDuplicates(actual);
    const marked = try Support.removeMarker(allocator, source);
    const recovery = try Completion.recoveryAt(allocator, marked.text, marked.cursor);
    try std.testing.expect(recovery != .unavailable);
}

test "typed islands preserve their clean member surface across every applicable mutation" {
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    for (families, 0..) |family, family_index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const canonical = try canonicalSource(allocator, family);
        var frontend = FrontendModule.Frontend.init(allocator);
        frontend.checkDocument(canonical) catch |err| {
            std.debug.print("typed-island canonical '{s}' failed: {s}\n", .{ family.id, if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err) });
            return err;
        };
        const expected = try Oracle.publicInstanceMember(allocator, canonical, "Surface", "paint");
        const clean_uri = try std.fmt.allocPrint(allocator, "file:///Typed-Island-{d}-clean.sx", .{family_index});
        const clean = try Support.serverCompletionAfterTrigger(&server, allocator, clean_uri, family.partial, ".");
        try Support.expectExactLabels(&.{"paint"}, clean);
        try Support.expectItem(.{
            .label = expected.name,
            .kind = expected.kind,
            .detail = expected.detail,
            .insert_text = expected.insert_text,
            .insert_text_format = expected.insert_text_format,
        }, clean);

        for (std.enums.values(Composition.EditingMutation), 0..) |mutation, mutation_index| {
            const mutated = try mutatedSource(allocator, family, mutation);
            const uri = try std.fmt.allocPrint(allocator, "file:///Typed-Island-{d}-{d}.sx", .{ family_index, mutation_index });
            expectTypedIsland(allocator, &server, uri, mutated, clean, mutationEquality(mutation)) catch |err| {
                const marked = try Support.removeMarker(allocator, mutated);
                const decision = try Completion.decisionAt(allocator, marked.text, marked.cursor, .trigger_character);
                std.debug.print("typed-island family '{s}' mutation '{s}' failed (recovery={s}, kind={s})\n", .{ family.id, @tagName(mutation), @tagName(decision.recovery), @tagName(decision.kind) });
                return err;
            };
        }
    }
}

fn auditMutationCoverage(suppressed_family: ?FamilyKind, suppressed_mutation: ?Composition.EditingMutation) !usize {
    var mutations = [_]bool{false} ** @typeInfo(Composition.EditingMutation).@"enum".fields.len;
    var family_coverage = [_]bool{false} ** @typeInfo(FamilyKind).@"enum".fields.len;
    var proofs: usize = 0;
    for (families) |family| {
        if (suppressed_family != null and family.kind == suppressed_family.?) continue;
        for (std.enums.values(Composition.EditingMutation)) |mutation| {
            if (suppressed_mutation != null and mutation == suppressed_mutation.?) continue;
            mutations[@intFromEnum(mutation)] = true;
            family_coverage[@intFromEnum(family.kind)] = true;
            proofs += 1;
        }
    }
    for (mutations) |covered| if (!covered) return error.MissingMutationOwner;
    for (family_coverage) |covered| if (!covered) return error.MissingFamilyMutationProof;
    return proofs;
}

test "every editing mutation and typed family has a checked proof owner" {
    try std.testing.expectEqual(families.len * @typeInfo(Composition.EditingMutation).@"enum".fields.len, try auditMutationCoverage(null, null));
}

test "suppressing a mutation or typed family breaks the recovery campaign" {
    for (std.enums.values(Composition.EditingMutation)) |mutation| {
        try std.testing.expectError(error.MissingMutationOwner, auditMutationCoverage(null, mutation));
    }
    for (std.enums.values(FamilyKind)) |family| {
        try std.testing.expectError(error.MissingFamilyMutationProof, auditMutationCoverage(family, null));
    }
}

test "an unresolved receiver degrades to a bounded empty member surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const items = try Support.serverCompletionAfterTrigger(
        &server,
        allocator,
        "file:///Typed-Island-Unresolved.sx",
        "func inspect() { unknown.<|> }\nfunc main() {}",
        ".",
    );
    try Support.expectExactLabels(&.{}, items);
}

fn auditRecoveryPolicy(fail_closed: bool) !void {
    for (families) |family| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        for ([_]Composition.EditingMutation{ .missing_delimiter, .missing_body, .error_at_cursor }) |mutation| {
            const source = try mutatedSource(allocator, family, mutation);
            const marked = try Support.removeMarker(allocator, source);
            const recovery = if (fail_closed)
                Completion.Recovery.unavailable
            else
                try Completion.recoveryAt(allocator, marked.text, marked.cursor);
            if (recovery == .unavailable) return error.FailClosedRecovery;
        }
    }
}

test "restoring fail-closed parsing breaks typed-island admission" {
    try auditRecoveryPolicy(false);
    try std.testing.expectError(error.FailClosedRecovery, auditRecoveryPolicy(true));
}
