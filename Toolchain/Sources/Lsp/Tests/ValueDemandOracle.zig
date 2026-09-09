const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");
const Composition = @import("../CompletionContract/Composition.zig");
const Oracle = @import("CompletionOracleSupport.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");
const Types = @import("../Types.zig");

const marker = "<|>";

const OracleTarget = union(enum) {
    parameter: struct { function: []const u8, name: []const u8 },
    function: []const u8,
};

const Case = struct {
    id: []const u8,
    consumer: Composition.ConsumerKind,
    demand: Composition.DemandKind = .value,
    partial: []const u8,
    completion: []const u8,
    canonical: ?[]const u8 = null,
    oracle: OracleTarget,
    incompatible: ?[]const u8,
    incompatible_is_valid: bool = false,
};

const value_types =
    \\struct Wanted {}
    \\struct Wrong {}
;

const function_values = value_types ++
    \\func make_candidate() Wanted { return Wanted() }
    \\func make_wrong() Wrong { return Wrong() }
;

const cases = [_]Case{
    .{
        .id = "initializer",
        .consumer = .initializer,
        .partial = value_types ++ "\nfunc inspect(candidate:Wanted, candidate_wrong:Wrong) {\n    let result:Wanted = <|>\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "plain-assignment",
        .consumer = .assignment,
        .partial = value_types ++ "\nfunc inspect(candidate:Wanted, candidate_wrong:Wrong) { var result:Wanted = candidate\nresult = <|> }\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "compound-assignment",
        .consumer = .assignment,
        .partial = "func inspect(candidate:int, candidate_wrong:str) { var result:int = 0\nresult += <|> }\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "field-default",
        .consumer = .field_default,
        .partial = function_values ++ "\nstruct Holder { var value:Wanted = <|> }\nfunc main() {}",
        .completion = "make_candidate()",
        .oracle = .{ .function = "make_candidate" },
        .incompatible = "make_wrong",
    },
    .{
        .id = "property-default",
        .consumer = .property_default,
        .partial = function_values ++ "\nstruct Holder { var stored:Wanted = make_candidate(); let value:Wanted = <|> { get { return self.stored } } }\nfunc main() {}",
        .completion = "make_candidate()",
        .oracle = .{ .function = "make_candidate" },
        .incompatible = "make_wrong",
    },
    .{
        .id = "return-value",
        .consumer = .return_value,
        .partial = value_types ++ "\nfunc inspect(candidate:Wanted, candidate_wrong:Wrong) Wanted { return <|> }\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "match-subject",
        .consumer = .match_subject,
        .partial = "enum Choice { first; second }\nfunc inspect(candidate:Choice, candidate_wrong:int) int {\n    return match <|>\n}\nfunc main() {}",
        .completion = "candidate",
        .canonical = "enum Choice { first; second }\nfunc inspect(candidate:Choice, candidate_wrong:int) int {\n    return match candidate { first => 1; second => 2 }\n}\nfunc main() {}",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "positional-argument",
        .consumer = .argument_value,
        .partial = value_types ++ "\nfunc consume(value:Wanted) {}\nfunc inspect(candidate:Wanted, candidate_wrong:Wrong) { consume(<|>) }\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "named-argument",
        .consumer = .argument_value,
        .partial = value_types ++ "\nfunc consume(other:int, value:Wanted) {}\nfunc inspect(candidate:Wanted, candidate_wrong:Wrong) {\n    consume(value:<|>, other:0)\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "cascade-argument",
        .consumer = .cascade_argument_value,
        .partial = value_types ++ "\nclass Pipeline { func consume(value:Wanted) Pipeline { return self } }\nfunc inspect(candidate:Wanted, candidate_wrong:Wrong) { Pipeline()..consume(<|>) }\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "cascade-assignment",
        .consumer = .cascade_assignment,
        .partial = value_types ++ "\nclass Settings { var value:Wanted }\nfunc inspect(candidate:Wanted, candidate_wrong:Wrong) {\n    Settings(value:candidate)..value = <|>\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "aggregate-value",
        .consumer = .aggregate_value,
        .partial = value_types ++ "\nstruct Holder { var other:int; var value:Wanted }\nfunc inspect(candidate:Wanted, candidate_wrong:Wrong) {\n    Holder(value:<|>, other:0)\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "if-condition",
        .consumer = .condition,
        .demand = .condition,
        .partial = "func inspect(candidate:bool, candidate_wrong:int) {\n    if <|> {}\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "elif-condition",
        .consumer = .condition,
        .demand = .condition,
        .partial = "func inspect(candidate:bool, candidate_wrong:int) {\n    if false {} elif <|> {}\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "while-condition",
        .consumer = .condition,
        .demand = .condition,
        .partial = "func inspect(candidate:bool, candidate_wrong:int) {\n    while <|> {}\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "collection-loop-source",
        .consumer = .loop_source,
        .demand = .iterable,
        .partial = "func inspect(candidate:int[], candidate_wrong:int) {\n    for value in <|> {}\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "cursor-loop-source",
        .consumer = .loop_source,
        .demand = .iterable,
        .partial = "class Cursor { func next() int? { return null } }\nfunc inspect(candidate:Cursor, candidate_wrong:int) {\n    for value in <|> {}\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
    },
    .{
        .id = "interpolation",
        .consumer = .interpolation,
        .partial = "func inspect(candidate:bool, candidate_wrong:int) {\n    print(\"$(<|>)\")\n}\nfunc main() {}",
        .completion = "candidate",
        .oracle = .{ .parameter = .{ .function = "inspect", .name = "candidate" } },
        .incompatible = "candidate_wrong",
        .incompatible_is_valid = true,
    },
};

fn canonicalSource(allocator: std.mem.Allocator, case: Case) ![]const u8 {
    if (case.canonical) |canonical| return canonical;
    const cursor = std.mem.indexOf(u8, case.partial, marker) orelse return error.MissingCompletionMarker;
    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{
        case.partial[0..cursor],
        case.completion,
        case.partial[cursor + marker.len ..],
    });
}

fn expectedItem(allocator: std.mem.Allocator, canonical: []const u8, target: OracleTarget) !Support.ExpectedItem {
    return switch (target) {
        .parameter => |parameter_target| blk: {
            const value = try Oracle.parameter(allocator, canonical, parameter_target.function, parameter_target.name);
            break :blk .{
                .label = value.name,
                .kind = 6,
                .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ value.name, value.type_name }),
                .insert_text = value.name,
            };
        },
        .function => |name| blk: {
            const value = try Oracle.functionValue(allocator, canonical, name);
            break :blk .{
                .label = value.name,
                .kind = value.kind,
                .detail = value.detail,
                .insert_text = value.insert_text,
                .insert_text_format = value.insert_text_format,
            };
        },
    };
}

fn itemNamed(items: []const Types.CompletionItem, name: []const u8) ?Types.CompletionItem {
    for (items) |item| if (std.mem.eql(u8, item.filterText orelse item.label, name)) return item;
    return null;
}

fn expectPreferred(preferred: []const u8, other: []const u8, items: []const Types.CompletionItem) !void {
    const preferred_item = itemNamed(items, preferred) orelse return error.MissingCompletionItem;
    const other_item = itemNamed(items, other) orelse return;
    try std.testing.expect(std.mem.order(u8, preferred_item.sortText orelse "", other_item.sortText orelse "") == .lt);
}

test "value demand is preserved across every declared consumer" {
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const canonical = try canonicalSource(allocator, case);
        var frontend = FrontendModule.Frontend.init(allocator);
        frontend.checkDocument(canonical) catch |err| {
            std.debug.print(
                "value-demand canonical '{s}' failed: {s}\n",
                .{ case.id, if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err) },
            );
            return err;
        };
        const expected = try expectedItem(allocator, canonical, case.oracle);
        const uri = try std.fmt.allocPrint(allocator, "file:///Value-Demand-{d}.sx", .{index});
        const actual = try Support.serverCompletion(&server, allocator, uri, case.partial);
        Support.expectItem(expected, actual) catch |err| {
            std.debug.print("value-demand consumer '{s}' lost '{s}'\n", .{ case.id, expected.label });
            return err;
        };
        if (case.incompatible) |incompatible| {
            if (!case.incompatible_is_valid) try expectPreferred(expected.label, incompatible, actual);
        }
        try Support.expectNoDuplicates(actual);
        const repeated = try Support.serverCompletion(&server, allocator, uri, case.partial);
        try Support.expectEqualItems(actual, repeated);
    }
}

fn auditConsumerCoverage(suppressed: ?Composition.ConsumerKind) !usize {
    var consumers = [_]bool{false} ** @typeInfo(Composition.ConsumerKind).@"enum".fields.len;
    for (cases) |case| if (suppressed == null or case.consumer != suppressed.?) {
        consumers[@intFromEnum(case.consumer)] = true;
    };
    var covered: usize = 0;
    for (std.enums.values(Composition.DemandKind)) |demand| {
        for (std.enums.values(Composition.ProducerKind)) |producer| {
            for (std.enums.values(Composition.ConsumerKind)) |consumer| {
                for (std.enums.values(Composition.TransformKind)) |transform| {
                    const status = Composition.statusFor(.{
                        .demand = demand,
                        .producer = producer,
                        .consumer = consumer,
                        .transform = transform,
                    });
                    const schema = switch (status) {
                        .proved => |owned| owned,
                        .required, .excluded => continue,
                    };
                    if (schema != .value_flow_surface or !Composition.isValueDemandKey(.{
                        .demand = demand,
                        .producer = producer,
                        .consumer = consumer,
                        .transform = transform,
                    })) continue;
                    if (!consumers[@intFromEnum(consumer)]) return error.MissingValueConsumerEdge;
                    covered += 1;
                }
            }
        }
    }
    if (covered == 0) return error.EmptyValueDemandCampaign;
    return covered;
}

test "every applicable value-demand key has generated consumer coverage" {
    try std.testing.expect((try auditConsumerCoverage(null)) > cases.len);
}

test "suppressing any value consumer edge breaks its family" {
    for (std.enums.values(Composition.ConsumerKind)) |consumer| {
        if (!Composition.isValueDemandConsumer(consumer)) continue;
        try std.testing.expectError(error.MissingValueConsumerEdge, auditConsumerCoverage(consumer));
    }
}
