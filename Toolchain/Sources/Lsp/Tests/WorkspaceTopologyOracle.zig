const std = @import("std");
const Completion = @import("../Completion.zig");
const Contract = @import("../CompletionContract.zig");
const Composition = @import("../CompletionContract/Composition.zig");
const WorkspaceFixtures = @import("../CompletionContract/WorkspaceFixtures.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

test "workspace topology registry fixtures are executable completion contracts" {
    const proof = "Lsp.Tests.WorkspaceTopologyOracle: workspace topology registry fixtures are executable completion contracts";
    for (Contract.scenarios) |scenario| {
        switch (scenario.status) {
            .protected => |protected| if (!std.mem.eql(u8, protected, proof)) continue,
            else => continue,
        }
        const fixture = scenario.workspace_fixture orelse continue;
        var temporary = std.testing.tmpDir(.{});
        defer temporary.cleanup();
        const entry_path = try WorkspaceFixtures.install(fixture, &temporary);
        if (std.fs.path.dirname(entry_path)) |parent| try temporary.dir.createDirPath(std.testing.io, parent);
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = entry_path, .data = "func main() {}" });

        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
        const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
        const entry_uri = try std.fmt.allocPrint(allocator, "file://{s}/{s}", .{ root, entry_path });
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        Support.initializeServer(&server, allocator, root_uri) catch |err| {
            std.debug.print("workspace topology fixture '{s}' initialization failed: {s}\n", .{ scenario.id, @errorName(err) });
            return err;
        };

        const items = Support.serverCompletion(&server, allocator, entry_uri, scenario.partial_source) catch |err| {
            std.debug.print("workspace topology fixture '{s}' request failed: {s}\n", .{ scenario.id, @errorName(err) });
            return err;
        };
        for (scenario.required) |label| Support.expectPresent(label, items) catch |err| {
            const marked = try Support.removeMarker(allocator, scenario.partial_source);
            const decision = try Completion.decisionAt(allocator, marked.text, marked.cursor, .invoked);
            const local_type = if (decision.receiver) |receiver|
                if (decision.program) |program|
                    Completion.resolveReceiverTypeForAccess(
                        allocator,
                        marked.text,
                        program,
                        marked.cursor,
                        receiver,
                        decision.safe_member_access,
                    )
                else
                    null
            else
                null;
            std.debug.print("workspace topology fixture '{s}' misses required '{s}'\n", .{ scenario.id, label });
            std.debug.print("  receiver={s} recovery={s} program={any} local_type={s}\n", .{
                decision.receiver orelse "<none>",
                @tagName(decision.recovery),
                decision.program != null,
                local_type orelse "<none>",
            });
            return err;
        };
        for (scenario.forbidden) |label| Support.expectAbsent(label, items) catch |err| {
            std.debug.print("workspace topology fixture '{s}' exposes forbidden '{s}'\n", .{ scenario.id, label });
            return err;
        };
        Support.expectNoDuplicates(items) catch |err| {
            std.debug.print("workspace topology fixture '{s}' contains duplicates\n", .{scenario.id});
            return err;
        };
        const repeated = Support.serverCompletion(&server, allocator, entry_uri, scenario.partial_source) catch |err| {
            std.debug.print("workspace topology fixture '{s}' repeated request failed: {s}\n", .{ scenario.id, @errorName(err) });
            return err;
        };
        Support.expectEqualItems(items, repeated) catch |err| {
            std.debug.print("workspace topology fixture '{s}' is not stable across repetitions\n", .{scenario.id});
            return err;
        };
    }
}

test "workspace topology excludes non-public members from an ordinary dependency" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Api/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"Api\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api/Package.json",
        .data = "{\"name\":\"Api\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api/Module/Surface.sx",
        .data =
        \\public class Surface {
        \\    func visible() {}
        \\    package func package_member() {}
        \\    module func module_member() {}
        \\    local func local_member() {}
        \\    private func private_member() {}
        \\    protected func protected_member() {}
        \\}
        ,
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    const items = try Support.serverCompletionAfterTrigger(
        &server,
        allocator,
        uri,
        "use Api.Surface\nfunc inspect(surface:&Surface) { surface.<|> }",
        ".",
    );
    try Support.expectExactLabels(&.{"visible"}, items);
    try Support.expectItem(.{ .label = "visible", .kind = 2, .detail = "visible() void", .insert_text = "visible()" }, items);
    try Support.expectNoDuplicates(items);
}

test "workspace overlays are authoritative ordered and recover without stale members" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Api/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"Api\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api/Package.json",
        .data = "{\"name\":\"Api\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api/Module/Widget.sx",
        .data = "public class Widget { func disk_member() {} }",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const widget_uri = try std.fmt.allocPrint(allocator, "file://{s}/Api/Module/Widget.sx", .{root});
    const marked = try Support.removeMarker(
        allocator,
        "use Api.Widget\nfunc inspect(widget:&Widget) { widget.<|> }",
    );

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    try Support.openDocument(&server, allocator, main_uri, 1, marked.text);

    const disk = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"disk_member"}, disk);

    try Support.openDocument(
        &server,
        allocator,
        widget_uri,
        10,
        "public class Widget { func first_overlay() {} }",
    );
    const first = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"first_overlay"}, first);

    try Support.changeDocument(
        &server,
        allocator,
        widget_uri,
        12,
        "public class Widget { func latest_overlay(value:int) bool { return true } private func hidden() {} }",
    );
    const latest = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"latest_overlay"}, latest);
    try Support.expectItem(.{
        .label = "latest_overlay",
        .kind = 2,
        .detail = "latest_overlay(value:int) bool",
        .insert_text = "latest_overlay(${1:value})$0",
        .insert_text_format = 2,
    }, latest);

    try Support.changeDocument(
        &server,
        allocator,
        widget_uri,
        11,
        "public class Widget { func stale_overlay() {} }",
    );
    const after_stale = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"latest_overlay"}, after_stale);
    try Support.expectEqualItems(latest, after_stale);

    try Support.changeDocument(&server, allocator, widget_uri, 13, "public class Widget {");
    const invalid = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{}, invalid);

    try Support.changeDocument(
        &server,
        allocator,
        widget_uri,
        14,
        "public class Widget { func recovered_overlay() {} }",
    );
    const recovered = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"recovered_overlay"}, recovered);
    try Support.expectNoDuplicates(recovered);

    try Support.changeDocument(
        &server,
        allocator,
        widget_uri,
        15,
        "public class Widget { func visibility_member() {} }",
    );
    const visible = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"visibility_member"}, visible);

    try Support.changeDocument(
        &server,
        allocator,
        widget_uri,
        16,
        "public class Widget { private func visibility_member() {} }",
    );
    const hidden = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{}, hidden);

    try Support.changeDocument(
        &server,
        allocator,
        widget_uri,
        17,
        "public class Widget {} extend Widget { func extension_member() {} }",
    );
    const extended = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"extension_member"}, extended);

    try Support.changeDocument(&server, allocator, widget_uri, 18, "public class Widget {}");
    const extension_removed = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{}, extension_removed);

    try Support.changeDocument(
        &server,
        allocator,
        widget_uri,
        19,
        "public class Other { func consumer_member() {} }",
    );
    const consumer = try Support.removeMarker(
        allocator,
        "use Api.Widget.Other\nfunc inspect(value:&Other) { value.<|> }",
    );
    try Support.changeDocument(&server, allocator, main_uri, 2, consumer.text);
    const consumer_changed = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, consumer);
    try Support.expectExactLabels(&.{"consumer_member"}, consumer_changed);
    const consumer_repeated = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, consumer);
    try Support.expectEqualItems(consumer_changed, consumer_repeated);

    try Support.changeDocument(&server, allocator, main_uri, 3, marked.text);
    const stale_consumer = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{}, stale_consumer);
}

test "live reexports replace disk aliases and navigate to canonical declarations" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Api/Module");
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\",\"dependencies\":{\"Api\":\"=1.0.0\"}}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api/Package.json",
        .data = "{\"name\":\"Api\",\"version\":\"1.0.0\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api/Module/Widget.sx",
        .data = "public class Widget { func paint() {} }",
    });
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Api/Module/Facade.sx",
        .data = "public use Api.Widget.Widget as DiskWidget",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const facade_uri = try std.fmt.allocPrint(allocator, "file://{s}/Api/Module/Facade.sx", .{root});
    const widget_uri = try std.fmt.allocPrint(allocator, "file://{s}/Api/Module/Widget.sx", .{root});
    const marked = try Support.removeMarker(
        allocator,
        "use Api.Facade\nfunc inspect(widget:&Facade.LiveWidget) { widget.<|> }",
    );

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    try Support.openDocument(&server, allocator, main_uri, 1, marked.text);
    try Support.openDocument(
        &server,
        allocator,
        facade_uri,
        20,
        "public use Api.Widget.Widget as LiveWidget",
    );

    const live = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{"paint"}, live);
    const definition = (try Support.serverDefinition(
        &server,
        allocator,
        main_uri,
        "use Api.Facade\nfunc inspect(widget:&Facade.Live<|>Widget) {}",
    )).?;
    try std.testing.expectEqualStrings(widget_uri, definition.uri);
    try std.testing.expectEqual(@as(usize, 0), definition.range.start.line);
    try Support.changeDocument(&server, allocator, main_uri, 2, marked.text);

    try Support.changeDocument(
        &server,
        allocator,
        facade_uri,
        21,
        "public use Api.Widget.Widget as RenamedWidget",
    );
    const removed = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
    try Support.expectExactLabels(&.{}, removed);

    try Support.changeDocument(&server, allocator, facade_uri, 22, "public use Api.Widget.");
    const invalid = try Support.serverCompletion(
        &server,
        allocator,
        main_uri,
        "use Api.Facade\nfunc inspect(widget:&Facade.<|>) {}",
    );
    try Support.expectExactLabels(&.{}, invalid);
}

test "workspace visibility respects private and protected access in the current file" {
    const cases = [_]struct {
        source: []const u8,
        expected: []const []const u8,
    }{
        .{
            .source = "public class Base { func visible() {}\nprivate func private_member() {}\nprotected func protected_member() {}\nfunc inside() { self.<|> } }",
            .expected = &.{ "inside", "private_member", "protected_member", "visible" },
        },
        .{
            .source = "public class Base { func visible() {}\nprivate func private_member() {}\nprotected func protected_member() {}\nfunc inside() {} }\npublic class Child : Base { func inside_child() { self.<|> } }",
            .expected = &.{ "inside", "inside_child", "protected_member", "visible" },
        },
        .{
            .source = "public class Base { func visible() {}\nprivate func private_member() {}\nprotected func protected_member() {}\nfunc inside() {} }\nfunc outside(base:Base) { base.<|> }",
            .expected = &.{ "inside", "visible" },
        },
        .{
            .source = "package class PackageApi { package func shared() {}\nprivate func private_member() {} }\nfunc consume(api:PackageApi) { api.<|> }",
            .expected = &.{"shared"},
        },
        .{
            .source = "class ModuleApi { func shared() {}\nlocal func local_member() {}\nprivate func private_member() {} }\nfunc consume(api:ModuleApi) { api.<|> }",
            .expected = &.{ "local_member", "shared" },
        },
        .{
            .source = "local class LocalApi { local func shared() {}\nprivate func private_member() {} }\nfunc consume(api:LocalApi) { api.<|> }",
            .expected = &.{"shared"},
        },
        .{
            .source = "public class Registry { static func visible() {}\nprivate static func private_member() {}\nprotected static func protected_member() {} }\nfunc consume() { Registry.<|> }",
            .expected = &.{"visible"},
        },
        .{
            .source = "public class Registry { static func visible() {}\nprivate static func private_member() {}\nprotected static func protected_member() {}\nstatic func inspect() { Registry.<|> } }",
            .expected = &.{ "inspect", "private_member", "protected_member", "visible" },
        },
    };

    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
        defer server.deinit();
        const uri = try std.fmt.allocPrint(allocator, "file:///Part05-Local-Visibility-{d}.sx", .{index});
        const items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, case.source, ".");
        Support.expectExactLabels(case.expected, items) catch |err| {
            const completed = try Support.removeMarker(allocator, case.source);
            const decision = try Completion.decisionAt(allocator, completed.text, completed.cursor, .trigger_character);
            std.debug.print("workspace local visibility case {d} failed\n", .{index});
            std.debug.print("  receiver={s} recovery={s} program={any}\n{s}\n", .{
                decision.receiver orelse "<none>",
                @tagName(decision.recovery),
                decision.program != null,
                completed.text,
            });
            return err;
        };
        try Support.expectNoDuplicates(items);
    }
}

const TopologyProof = struct {
    topology: Composition.TopologyKind,
    scenario: []const u8,
};

const topology_proofs = [_]TopologyProof{
    .{ .topology = .same_file, .scenario = "member-local-incomplete-if" },
    .{ .topology = .module_file, .scenario = "origin-current-module" },
    .{ .topology = .submodule, .scenario = "topology-submodule" },
    .{ .topology = .package, .scenario = "visibility-imported-private-negative" },
    .{ .topology = .dependency, .scenario = "member-imported-alias" },
    .{ .topology = .development_dependency, .scenario = "topology-development-dependency" },
    .{ .topology = .friend_dependency, .scenario = "topology-friend-package" },
    .{ .topology = .alias, .scenario = "member-imported-alias" },
    .{ .topology = .reexport, .scenario = "cascade-imported-principal-reexport" },
    .{ .topology = .contribution, .scenario = "topology-catalog-fragment-field-chain" },
    .{ .topology = .catalog, .scenario = "topology-catalog-fragment-field-chain" },
    .{ .topology = .atom, .scenario = "member-imported-atom" },
    .{ .topology = .extension, .scenario = "topology-merged-extension" },
    .{ .topology = .platform_fragment, .scenario = "topology-platform-fragment" },
    .{ .topology = .unsaved_overlay, .scenario = "overlay-unsaved-import" },
};

fn hasScenario(identifier: []const u8) bool {
    for (Contract.scenarios) |scenario| if (std.mem.eql(u8, scenario.id, identifier)) return true;
    return false;
}

fn auditTopologyCoverage(suppressed: ?Composition.TopologyKind) !usize {
    var covered = [_]bool{false} ** @typeInfo(Composition.TopologyKind).@"enum".fields.len;
    var proofs: usize = 0;
    for (topology_proofs) |proof| {
        if (suppressed != null and proof.topology == suppressed.?) continue;
        if (!hasScenario(proof.scenario)) return error.MissingTopologyScenario;
        covered[@intFromEnum(proof.topology)] = true;
        proofs += 1;
    }
    for (covered) |present| if (!present) return error.MissingTopologyProof;
    return proofs;
}

fn auditWorkspaceMemberKeys(suppressed: ?Composition.ProducerKind) !usize {
    var producers = [_]bool{false} ** @typeInfo(Composition.ProducerKind).@"enum".fields.len;
    for ([_]Composition.ProducerKind{ .intrinsic, .imported_value, .workspace_contribution }) |producer| {
        if (suppressed == null or producer != suppressed.?) producers[@intFromEnum(producer)] = true;
    }
    var proofs: usize = 0;
    for (std.enums.values(Composition.DemandKind)) |demand| for (std.enums.values(Composition.ProducerKind)) |producer|
        for (std.enums.values(Composition.ConsumerKind)) |consumer| for (std.enums.values(Composition.TransformKind)) |transform| {
            const status = Composition.statusFor(.{ .demand = demand, .producer = producer, .consumer = consumer, .transform = transform });
            const schema = switch (status) {
                .proved => |owned| owned,
                .required, .excluded => continue,
            };
            if (schema != .workspace_member_surface) continue;
            if (!producers[@intFromEnum(producer)]) return error.MissingWorkspaceProducerProof;
            proofs += 1;
        };
    return proofs;
}

test "intrinsic and workspace member producers close the semantic matrix" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const intrinsic = try Support.serverCompletionAfterTrigger(
        &server,
        allocator,
        "file:///Workspace-Intrinsic.sx",
        "func inspect(text:str) { text.<|> }\nfunc main() {}",
        ".",
    );
    try Support.expectExactLabels(&.{"count"}, intrinsic);
    try Support.expectItem(.{ .label = "count", .kind = 2, .detail = "count() int", .insert_text = "count()" }, intrinsic);
    try std.testing.expectEqual(@as(usize, 23), try auditWorkspaceMemberKeys(null));
    for ([_]Composition.ProducerKind{ .intrinsic, .imported_value, .workspace_contribution }) |producer| {
        try std.testing.expectError(error.MissingWorkspaceProducerProof, auditWorkspaceMemberKeys(producer));
    }
}

test "every workspace topology has a registered proof and suppression is detected" {
    try std.testing.expectEqual(topology_proofs.len, try auditTopologyCoverage(null));
    for (std.enums.values(Composition.TopologyKind)) |topology| {
        try std.testing.expectError(error.MissingTopologyProof, auditTopologyCoverage(topology));
    }
}
