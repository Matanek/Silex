const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");
const Completion = @import("../Completion.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

const Case = struct {
    id: []const u8,
    canonical_source: []const u8,
    partial_before: []const u8,
    choice: []const u8,
    partial_after: []const u8,
    expected: Support.ExpectedItem,
    forbidden: []const []const u8,
    expect_first: bool = false,
};

const canonical =
    \\enum Month { january; unknown }
    \\func to_month_str(month:Month) str {
    \\    return match month {
    \\        january => "January"
    \\        unknown => "Unknown"
    \\    }
    \\}
    \\func main() { print(to_month_str(Month.january)) }
;

const try_canonical =
    \\func parse() Result<int, str> { return Result<int, str>.success(1) }
    \\func propagate() Result<int, str> { return Result<int, str>.success(try parse()) }
    \\func main() {}
;

const move_canonical =
    \\struct Box { let value:int }
    \\func transfer(value:Box) Box { return move value }
    \\func main() {}
;

const copy_canonical =
    \\class State { var value:int }
    \\struct Owner { var state:State }
    \\func detach(value:Owner) Owner { return copy value }
    \\func main() {}
;

const function_canonical =
    \\func callback() func(int) int {
    \\    return func(value:int) int { return value }
    \\}
    \\func main() {}
;

const cases = [_]Case{
    .{
        .id = "return-match-expression-introducer",
        .canonical_source = canonical,
        .partial_before = "enum Month { january; unknown }\nfunc to_month_str(month:Month) str {\n    return ",
        .choice = "match",
        .partial_after = "\n}",
        .expected = .{
            .label = "match",
            .kind = 14,
            .detail = "Silex match expression",
            .insert_text = "match",
        },
        .forbidden = &.{ "while", "public" },
    },
    .{
        .id = "match-subject-parameter",
        .canonical_source = canonical,
        .partial_before = "enum Month { january; unknown }\nfunc to_month_str(month:Month) str {\n    return match ",
        .choice = "month",
        .partial_after = "\n}",
        .expected = .{
            .label = "month",
            .kind = 6,
            .detail = "month:Month",
            .insert_text = "month",
        },
        .forbidden = &.{ "while", "public" },
        .expect_first = true,
    },
    .{
        .id = "return-try-expression-introducer",
        .canonical_source = try_canonical,
        .partial_before =
        \\func parse() Result<int, str> { return Result<int, str>.success(1) }
        \\func propagate() Result<int, str> { return Result<int, str>.success(
        ,
        .choice = "try",
        .partial_after = ")\n}",
        .expected = .{
            .label = "try",
            .kind = 14,
            .detail = "Silex result propagation",
            .insert_text = "try",
        },
        .forbidden = &.{ "while", "public" },
    },
    .{
        .id = "return-move-expression-introducer",
        .canonical_source = move_canonical,
        .partial_before = "struct Box { let value:int }\nfunc transfer(value:Box) Box { return ",
        .choice = "move",
        .partial_after = "\n}",
        .expected = .{
            .label = "move",
            .kind = 14,
            .detail = "Silex value transfer",
            .insert_text = "move",
        },
        .forbidden = &.{ "while", "public" },
    },
    .{
        .id = "return-copy-expression-introducer",
        .canonical_source = copy_canonical,
        .partial_before = "class State { var value:int }\nstruct Owner { var state:State }\nfunc detach(value:Owner) Owner { return ",
        .choice = "copy",
        .partial_after = "\n}",
        .expected = .{
            .label = "copy",
            .kind = 14,
            .detail = "Silex detached copy",
            .insert_text = "copy",
        },
        .forbidden = &.{ "while", "public" },
    },
    .{
        .id = "return-function-expression-introducer",
        .canonical_source = function_canonical,
        .partial_before = "func callback() func(int) int { return ",
        .choice = "func",
        .partial_after = "\n}",
        .expected = .{
            .label = "func",
            .kind = 14,
            .detail = "Silex anonymous function",
            .insert_text = "func",
        },
        .forbidden = &.{ "while", "public" },
    },
};

test "canonical expression choices survive every typed prefix through the server" {
    for (cases, 0..) |case, case_index| {
        var canonical_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer canonical_arena.deinit();
        var frontend = FrontendModule.Frontend.init(canonical_arena.allocator());
        frontend.checkDocument(case.canonical_source) catch |err| {
            std.debug.print(
                "expression choice oracle '{s}' rejected its canonical source: {s}\n",
                .{ case.id, if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err) },
            );
            return err;
        };

        for (0..case.choice.len + 1) |prefix_length| {
            var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
            defer arena.deinit();
            const allocator = arena.allocator();
            const partial = try std.fmt.allocPrint(
                allocator,
                "{s}{s}<|>{s}",
                .{ case.partial_before, case.choice[0..prefix_length], case.partial_after },
            );
            const uri = try std.fmt.allocPrint(
                allocator,
                "file:///Expression-Choice-{d}-{d}.sx",
                .{ case_index, prefix_length },
            );

            var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
            defer server.deinit();
            const actual = Support.serverCompletion(&server, allocator, uri, partial) catch |err| {
                std.debug.print(
                    "expression choice oracle '{s}' failed for prefix '{s}': {s}\n",
                    .{ case.id, case.choice[0..prefix_length], @errorName(err) },
                );
                return err;
            };
            Support.expectItem(case.expected, actual) catch |err| {
                std.debug.print(
                    "expression choice oracle '{s}' misses '{s}' for prefix '{s}'\n",
                    .{ case.id, case.choice, case.choice[0..prefix_length] },
                );
                return err;
            };
            if (case.expect_first and prefix_length != 0) try Support.expectFirst(case.choice, actual);
            for (case.forbidden) |label| Support.expectAbsent(label, actual) catch |err| {
                const marked = try Support.removeMarker(allocator, partial);
                const decision = try Completion.decisionAt(allocator, marked.text, marked.cursor, .invoked);
                std.debug.print(
                    "expression choice oracle '{s}' exposes forbidden '{s}' for prefix '{s}' (kind={s}, recovery={s})\n",
                    .{ case.id, label, case.choice[0..prefix_length], @tagName(decision.kind), @tagName(decision.recovery) },
                );
                return err;
            };
            try Support.expectNoDuplicates(actual);

            var repeated_server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
            defer repeated_server.deinit();
            const repeated = try Support.serverCompletion(&repeated_server, allocator, uri, partial);
            try Support.expectEqualItems(actual, repeated);
        }
    }
}
