const std = @import("std");
const Completion = @import("../Completion.zig");
const Contract = @import("../CompletionContract.zig");
const WorkspaceFixtures = @import("../CompletionContract/WorkspaceFixtures.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

test "part 05 workspace registry fixtures are executable completion contracts" {
    const proof = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts";
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
            std.debug.print("Part 05 registry fixture '{s}' initialization failed: {s}\n", .{ scenario.id, @errorName(err) });
            return err;
        };

        const items = Support.serverCompletion(&server, allocator, entry_uri, scenario.partial_source) catch |err| {
            std.debug.print("Part 05 registry fixture '{s}' request failed: {s}\n", .{ scenario.id, @errorName(err) });
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
            std.debug.print("Part 05 registry fixture '{s}' misses required '{s}'\n", .{ scenario.id, label });
            std.debug.print("  receiver={s} recovery={s} program={any} local_type={s}\n", .{
                decision.receiver orelse "<none>",
                @tagName(decision.recovery),
                decision.program != null,
                local_type orelse "<none>",
            });
            return err;
        };
        for (scenario.forbidden) |label| Support.expectAbsent(label, items) catch |err| {
            std.debug.print("Part 05 registry fixture '{s}' exposes forbidden '{s}'\n", .{ scenario.id, label });
            return err;
        };
        Support.expectNoDuplicates(items) catch |err| {
            std.debug.print("Part 05 registry fixture '{s}' contains duplicates\n", .{scenario.id});
            return err;
        };
        const repeated = Support.serverCompletion(&server, allocator, entry_uri, scenario.partial_source) catch |err| {
            std.debug.print("Part 05 registry fixture '{s}' repeated request failed: {s}\n", .{ scenario.id, @errorName(err) });
            return err;
        };
        Support.expectEqualItems(items, repeated) catch |err| {
            std.debug.print("Part 05 registry fixture '{s}' is not stable across repetitions\n", .{scenario.id});
            return err;
        };
    }
}
