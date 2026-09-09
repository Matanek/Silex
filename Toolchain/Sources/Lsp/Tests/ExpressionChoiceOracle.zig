const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");
const Completion = @import("../Completion.zig");
const Oracle = @import("CompletionOracleSupport.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");
const Types = @import("../Types.zig");

const Composition = @import("../CompletionContract/Composition.zig");

const CanonicalId = enum { match_expression, result_propagation, move_value, copy_value, anonymous_function, member_surface };

const CanonicalTemplate = struct {
    id: CanonicalId,
    source: []const u8,
};

const Case = struct {
    id: []const u8,
    canonical: CanonicalId,
    schema: ?Composition.SchemaId = null,
    partial_before: []const u8,
    choice: []const u8,
    partial_after: []const u8,
    expected: ?Support.ExpectedItem = null,
    oracle_parameter: ?struct {
        function_name: []const u8,
        parameter_name: []const u8,
    } = null,
    oracle_member: ?struct {
        type_name: []const u8,
        member_name: []const u8,
    } = null,
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

const member_canonical =
    \\public class Widget {
    \\    public var opacity:float = 0.0
    \\    public func paint() {}
    \\    private func secret() {}
    \\}
    \\func main() { Widget().paint() }
;

const cases = [_]Case{
    .{
        .id = "return-match-expression-introducer",
        .canonical = .match_expression,
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
        .canonical = .match_expression,
        .schema = .value_flow_surface,
        .partial_before = "enum Month { january; unknown }\nfunc to_month_str(month:Month) str {\n    return match ",
        .choice = "month",
        .partial_after = "\n}",
        .oracle_parameter = .{
            .function_name = "to_month_str",
            .parameter_name = "month",
        },
        .forbidden = &.{ "while", "public" },
        .expect_first = true,
    },
    .{
        .id = "return-try-expression-introducer",
        .canonical = .result_propagation,
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
        .canonical = .move_value,
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
        .canonical = .copy_value,
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
        .canonical = .anonymous_function,
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
    .{
        .id = "receiver-member-surface",
        .canonical = .member_surface,
        .schema = .receiver_member_surface,
        .partial_before =
        \\public class Widget {
        \\    public var opacity:float = 0.0
        \\    public func paint() {}
        \\    private func secret() {}
        \\}
        \\func main() { Widget().
        ,
        .choice = "paint",
        .partial_after = " }",
        .oracle_member = .{ .type_name = "Widget", .member_name = "paint" },
        .forbidden = &.{ "secret", "while" },
        .expect_first = true,
    },
};

const canonical_templates = [_]CanonicalTemplate{
    .{ .id = .match_expression, .source = canonical },
    .{ .id = .result_propagation, .source = try_canonical },
    .{ .id = .move_value, .source = move_canonical },
    .{ .id = .copy_value, .source = copy_canonical },
    .{ .id = .anonymous_function, .source = function_canonical },
    .{ .id = .member_surface, .source = member_canonical },
};

const Budgets = struct {
    pub const canonical_templates: usize = 6;
    pub const generated_documents: usize = 37;
    pub const assertions: usize = 195;
    pub const protocol_requests: usize = 149;
    pub const server_initializations: usize = 1;
};

const Report = struct {
    semantic_tuples: usize,
    exclusions: usize,
    schemas: usize,
    covered_schemas: usize = 0,
    canonical_templates: usize = 0,
    generated_documents: usize = 0,
    assertions: usize = 0,
    protocol_requests: usize = 0,
    server_initializations: usize = 0,
};

fn canonicalSource(id: CanonicalId) []const u8 {
    for (canonical_templates) |template| if (template.id == id) return template.source;
    unreachable;
}

fn expectedFor(
    allocator: std.mem.Allocator,
    case: Case,
) !Support.ExpectedItem {
    if (case.oracle_parameter) |target| {
        const parameter = try Oracle.parameter(
            allocator,
            canonicalSource(case.canonical),
            target.function_name,
            target.parameter_name,
        );
        return .{
            .label = parameter.name,
            .kind = 6,
            .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ parameter.name, parameter.type_name }),
            .insert_text = parameter.name,
        };
    }
    if (case.oracle_member) |target| {
        const member = try Oracle.publicInstanceMember(
            allocator,
            canonicalSource(case.canonical),
            target.type_name,
            target.member_name,
        );
        return .{
            .label = member.name,
            .kind = member.kind,
            .detail = member.detail,
            .insert_text = member.insert_text,
            .insert_text_format = member.insert_text_format,
        };
    }
    return case.expected orelse error.MissingOracleExpectation;
}

fn runCampaign() !Report {
    const composition = try Composition.audit();
    var report = Report{
        .semantic_tuples = composition.total,
        .exclusions = composition.excluded,
        .schemas = composition.schemas,
    };

    for (canonical_templates) |template| {
        var canonical_arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer canonical_arena.deinit();
        var frontend = FrontendModule.Frontend.init(canonical_arena.allocator());
        frontend.checkDocument(template.source) catch |err| {
            std.debug.print(
                "expression oracle canonical template '{s}' was rejected: {s}\n",
                .{ @tagName(template.id), if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err) },
            );
            return err;
        };
        report.canonical_templates += 1;
    }

    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Package.json",
        .data = "{\"sources\":\".\"}",
    });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    report.server_initializations += 1;
    report.protocol_requests += 1;
    var covered_schemas = [_]bool{false} ** @typeInfo(Composition.SchemaId).@"enum".fields.len;

    for (cases, 0..) |case, case_index| {
        if (case.schema) |schema| covered_schemas[@intFromEnum(schema)] = true;
        const expected = try expectedFor(allocator, case);
        for (0..case.choice.len + 1) |prefix_length| {
            const partial = try std.fmt.allocPrint(
                allocator,
                "{s}{s}<|>{s}",
                .{ case.partial_before, case.choice[0..prefix_length], case.partial_after },
            );
            const marked = try Support.removeMarker(allocator, partial);
            const uri = try std.fmt.allocPrint(
                allocator,
                "file://{s}/Expression-Choice-{d}-{d}.sx",
                .{ root, case_index, prefix_length },
            );
            try Support.openDocument(&server, allocator, uri, 1, marked.text);
            report.protocol_requests += 1;
            try Support.changeDocument(&server, allocator, uri, 2, marked.text);
            report.protocol_requests += 1;
            report.generated_documents += 1;

            const actual = Support.serverCompletionInOpenDocument(&server, allocator, uri, marked) catch |err| {
                std.debug.print(
                    "expression choice oracle '{s}' failed for prefix '{s}': {s}\n",
                    .{ case.id, case.choice[0..prefix_length], @errorName(err) },
                );
                return err;
            };
            report.protocol_requests += 1;
            Support.expectItem(expected, actual) catch |err| {
                std.debug.print(
                    "expression choice oracle '{s}' misses '{s}' for prefix '{s}'\n",
                    .{ case.id, case.choice, case.choice[0..prefix_length] },
                );
                return err;
            };
            report.assertions += 1;
            if (case.expect_first and prefix_length != 0) {
                try Support.expectFirst(case.choice, actual);
                report.assertions += 1;
            }
            for (case.forbidden) |label| {
                Support.expectAbsent(label, actual) catch |err| {
                    const decision = try Completion.decisionAt(allocator, marked.text, marked.cursor, .invoked);
                    std.debug.print(
                        "expression choice oracle '{s}' exposes forbidden '{s}' for prefix '{s}' (kind={s}, recovery={s})\n",
                        .{ case.id, label, case.choice[0..prefix_length], @tagName(decision.kind), @tagName(decision.recovery) },
                    );
                    return err;
                };
                report.assertions += 1;
            }
            try Support.expectNoDuplicates(actual);
            report.assertions += 1;

            const repeated = try Support.serverCompletionInOpenDocument(&server, allocator, uri, marked);
            report.protocol_requests += 1;
            try Support.expectEqualItems(actual, repeated);
            report.assertions += 1;
        }
    }
    for (covered_schemas) |covered| {
        if (covered) report.covered_schemas += 1;
    }
    return report;
}

test "canonical expression choices survive every typed prefix through the server" {
    const report = try runCampaign();
    try std.testing.expectEqual(Budgets.canonical_templates, report.canonical_templates);
    try std.testing.expectEqual(report.schemas, report.covered_schemas);
    try std.testing.expectEqual(Budgets.generated_documents, report.generated_documents);
    try std.testing.expectEqual(Budgets.assertions, report.assertions);
    try std.testing.expectEqual(Budgets.protocol_requests, report.protocol_requests);
    try std.testing.expectEqual(Budgets.server_initializations, report.server_initializations);
}

test "oracle comparison rejects identity metadata visibility insertion and order mismatches" {
    const items = [_]Types.CompletionItem{
        .{
            .label = "visible",
            .kind = 6,
            .detail = "visible:Month",
            .sortText = "0:visible:visible:Month",
            .filterText = "visible",
            .insertText = "visible",
        },
        .{
            .label = "second",
            .kind = 6,
            .detail = "second:Month",
            .sortText = "1:second:second:Month",
            .filterText = "second",
            .insertText = "second",
        },
    };
    try std.testing.expect(!Support.containsLabel("wrong-label", &items));
    try std.testing.expect(!Support.containsLabel("private", &items));
    try std.testing.expectError(error.CompletionDetailMismatch, Support.validateItem(.{
        .label = "visible",
        .kind = 6,
        .detail = "visible:WrongType",
        .insert_text = "visible",
    }, items[0]));
    try std.testing.expectError(error.CompletionInsertionMismatch, Support.validateItem(.{
        .label = "visible",
        .kind = 6,
        .detail = "visible:Month",
        .insert_text = "wrong-insertion",
    }, items[0]));
    try std.testing.expectError(error.UnexpectedFirstCompletionItem, Support.expectFirst("second", &items));
}
