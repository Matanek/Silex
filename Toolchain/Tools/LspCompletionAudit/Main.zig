const std = @import("std");
const Lsp = @import("silex_lsp_audit");

pub fn main(init: std.process.Init) u8 {
    return run(init) catch |err| {
        std.debug.print("LSP completion corpus audit: {t}\n", .{err});
        return 1;
    };
}

fn run(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const arguments = try init.minimal.args.toSlice(allocator);
    if (arguments.len != 2) return error.InvalidArguments;
    const inventory = try Lsp.CorpusAudit.inventoryWorkspace(allocator, init.io, arguments[1]);
    const report = inventory.report;
    try Lsp.CorpusAudit.requireRepresentative(report);

    const stdout = std.Io.File.stdout();
    try stdout.writeStreamingAll(init.io, try std.fmt.allocPrint(
        allocator,
        "source_files\t{d}\nsource_bytes\t{d}\nchoice_sites\t{d}\nmapped_sites\t{d}\nfingerprint\t{x:0>16}\n",
        .{ report.source_files, report.source_bytes, report.choice_sites, report.mapped_sites, report.fingerprint },
    ));
    inline for (std.meta.fields(Lsp.CorpusAudit.Signal)) |field| {
        const signal: Lsp.CorpusAudit.Signal = @enumFromInt(field.value);
        try stdout.writeStreamingAll(init.io, try std.fmt.allocPrint(
            allocator,
            "classification\t{s}\t{d}\t{s}\n",
            .{ Lsp.CorpusAudit.signalName(signal), report.count(signal), Lsp.CorpusAudit.proofForSignal(signal) },
        ));
    }
    for (inventory.sources) |source| {
        try stdout.writeStreamingAll(init.io, try std.fmt.allocPrint(
            allocator,
            "source\t{s}\t{d}\t{d}\n",
            .{ source.path, source.bytes, source.site_count },
        ));
    }
    for (inventory.sites) |site| {
        try stdout.writeStreamingAll(init.io, try std.fmt.allocPrint(
            allocator,
            "site\t{s}\t{d}\t{d}\t{d}\t{s}\t{s}\n",
            .{ site.path, site.line, site.column, site.offset, Lsp.CorpusAudit.signalName(site.signal), site.scenario },
        ));
    }
    try auditSemanticSamples(init, allocator, arguments[1], stdout);
    return 0;
}

const Sample = struct {
    id: []const u8,
    relative_path: []const u8,
    project_root: []const u8,
    oracle_source_path: []const u8,
    canonical_site: []const u8,
    partial_site: []const u8,
    oracle_type: []const u8,
    same_file_oracle: bool = false,
};

const samples = [_]Sample{
    .{
        .id = "example-canvas-constructor-cascade",
        .relative_path = "Silex-Examples/Sources/ShapeGallery2D/Main.sx",
        .project_root = "Silex-Examples",
        .oracle_source_path = "Packages/GFX.Canvas/Module/Canvas.sx",
        .canonical_site = "var gallery = Canvas()",
        .partial_site = "Canvas()..<|>",
        .oracle_type = "Canvas",
    },
    .{
        .id = "example-canvas-vec2-member",
        .relative_path = "Silex-Examples/Sources/ShapeGallery2D/Drawing.sx",
        .project_root = "Silex-Examples",
        .oracle_source_path = "Packages/STD/Module/Math/@Vec2.sx",
        .canonical_site = "position.add(Math.Vec2(16.0, 12.0))",
        .partial_site = "position.<|>",
        .oracle_type = "Vec2",
    },
    .{
        .id = "package-ecs-query-binding",
        .relative_path = "Packages/GFX/Tests/Application/ECSParallelQueries.sx",
        .project_root = "Packages/GFX",
        .oracle_source_path = "Packages/GFX/Tests/Application/ECSParallelQueries.sx",
        .canonical_site = "advance_position(position, step.value)",
        .partial_site = "advance_position(position, step.<|>)",
        .oracle_type = "HelperStep",
        .same_file_oracle = true,
    },
};

fn auditSemanticSamples(
    init: std.process.Init,
    allocator: std.mem.Allocator,
    workspace_root: []const u8,
    stdout: std.Io.File,
) !void {
    const home = init.environ_map.get("HOME") orelse init.environ_map.get("USERPROFILE") orelse
        return error.MissingPackageStore;
    const packages_root = try std.fs.path.join(allocator, &.{ home, ".silex", "packages" });
    for (samples) |sample| {
        const project_root = try std.fs.path.join(allocator, &.{ workspace_root, sample.project_root });
        const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{project_root});
        var server = Lsp.Server.Server.initWithPackages(allocator, init.io, packages_root);
        defer server.deinit();
        try Lsp.Support.initializeServer(&server, allocator, root_uri);
        const full_path = try std.fs.path.join(allocator, &.{ workspace_root, sample.relative_path });
        const canonical = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            full_path,
            allocator,
            .limited(16 * 1024 * 1024),
        );
        if (std.mem.count(u8, canonical, sample.canonical_site) != 1) {
            return error.SemanticSampleDrift;
        }
        const partial = try std.mem.replaceOwned(
            u8,
            allocator,
            canonical,
            sample.canonical_site,
            sample.partial_site,
        );

        const oracle_path = try std.fs.path.join(allocator, &.{ workspace_root, sample.oracle_source_path });
        const oracle_source = try std.Io.Dir.cwd().readFileAlloc(
            init.io,
            oracle_path,
            allocator,
            .limited(16 * 1024 * 1024),
        );
        const expected = (if (sample.same_file_oracle)
            Lsp.CompletionOracle.parsedSameFileInstanceMembers(allocator, oracle_source, sample.oracle_type)
        else
            Lsp.CompletionOracle.parsedPublicInstanceMembers(allocator, oracle_source, sample.oracle_type)) catch |err| {
            std.debug.print(
                "semantic sample {s} frontend declaration oracle failed: {s}\n",
                .{ sample.id, @errorName(err) },
            );
            return err;
        };
        const uri = try std.fmt.allocPrint(allocator, "file://{s}", .{full_path});
        const actual = Lsp.Support.serverCompletionAfterTrigger(&server, allocator, uri, partial, ".") catch |err| {
            std.debug.print("semantic sample {s} server request failed: {s}\n", .{ sample.id, @errorName(err) });
            return err;
        };
        expectSameLabels(expected, actual) catch |err| {
            std.debug.print(
                "semantic sample {s} differs: expected {d}, actual {d}\nexpected:",
                .{ sample.id, expected.len, actual.len },
            );
            for (expected) |label| std.debug.print(" {s}", .{label});
            std.debug.print("\nactual:", .{});
            for (actual) |item| std.debug.print(" {s}", .{item.label});
            std.debug.print("\n", .{});
            return err;
        };
        try stdout.writeStreamingAll(init.io, try std.fmt.allocPrint(
            allocator,
            "semantic_sample\t{s}\t{s}\t{s}\t{d}\n",
            .{ sample.id, sample.relative_path, sample.oracle_type, actual.len },
        ));
    }
}

fn expectSameLabels(expected: []const []const u8, actual: []const Lsp.Types.CompletionItem) !void {
    for (expected) |expected_label| {
        var found = false;
        for (actual) |item| {
            if (std.mem.eql(u8, expected_label, baseLabel(item.label))) {
                found = true;
                break;
            }
        }
        if (!found) return error.SemanticSampleSurfaceMismatch;
    }
    for (actual) |item| {
        const actual_label = baseLabel(item.label);
        var found = false;
        for (expected) |expected_label| {
            if (std.mem.eql(u8, expected_label, actual_label)) {
                found = true;
                break;
            }
        }
        if (!found) return error.SemanticSampleSurfaceMismatch;
    }
}

fn baseLabel(label: []const u8) []const u8 {
    const opening = std.mem.indexOfScalar(u8, label, '(') orelse return label;
    return label[0..opening];
}
