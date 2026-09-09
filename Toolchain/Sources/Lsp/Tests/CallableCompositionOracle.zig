const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");
const Completion = @import("../Completion.zig");
const Composition = @import("../CompletionContract/Composition.zig");
const Oracle = @import("CompletionOracleSupport.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

const ProducerCase = struct {
    id: []const u8,
    producer: Composition.ProducerKind,
    canonical: []const u8,
    partial: []const u8,
    expected: union(enum) {
        function: []const u8,
        method: struct { owner: []const u8, name: []const u8 },
        item: Support.ExpectedItem,
    },
    forbidden: []const u8,
};

const producer_cases = [_]ProducerCase{
    .{
        .id = "direct-function",
        .producer = .function_declaration,
        .canonical = "func accept(callback:func(int) bool) {}\nfunc candidate(value:int) bool { return true }\nfunc wrong(value:str) bool { return true }\nfunc main() { accept(candidate) }",
        .partial = "func accept(callback:func(int) bool) {}\nfunc candidate(value:int) bool { return true }\nfunc wrong(value:str) bool { return true }\nfunc main() { accept(<|>) }",
        .expected = .{ .function = "candidate" },
        .forbidden = "wrong",
    },
    .{
        .id = "static-method",
        .producer = .method_declaration,
        .canonical = "struct Predicates { static func candidate(value:int) bool { return true } static func wrong(value:str) bool { return true } }\nfunc accept(callback:func(int) bool) {}\nfunc main() { accept(Predicates.candidate) }",
        .partial = "struct Predicates { static func candidate(value:int) bool { return true } static func wrong(value:str) bool { return true } }\nfunc accept(callback:func(int) bool) {}\nfunc main() { accept(Predicates.<|>) }",
        .expected = .{ .method = .{ .owner = "Predicates", .name = "candidate" } },
        .forbidden = "wrong",
    },
    .{
        .id = "bound-method",
        .producer = .bound_method,
        .canonical = "struct Predicates { func candidate(value:int) bool { return true } func wrong(value:str) bool { return true } }\nfunc accept(callback:func(int) bool) {}\nfunc inspect(predicates:Predicates) { accept(predicates.candidate) }\nfunc main() {}",
        .partial = "struct Predicates { func candidate(value:int) bool { return true } func wrong(value:str) bool { return true } }\nfunc accept(callback:func(int) bool) {}\nfunc inspect(predicates:Predicates) { accept(predicates.<|>) }\nfunc main() {}",
        .expected = .{ .method = .{ .owner = "Predicates", .name = "candidate" } },
        .forbidden = "wrong",
    },
    .{
        .id = "callback-parameter",
        .producer = .callback_parameter,
        .canonical = "func accept(callback:func(int) bool) {}\nfunc inspect(candidate:func(int) bool, wrong:func(str) bool) { accept(candidate) }\nfunc main() {}",
        .partial = "func accept(callback:func(int) bool) {}\nfunc inspect(candidate:func(int) bool, wrong:func(str) bool) { accept(<|>) }\nfunc main() {}",
        .expected = .{ .item = .{ .label = "candidate", .kind = 6, .detail = "candidate(int) bool", .insert_text = "candidate" } },
        .forbidden = "wrong",
    },
    .{
        .id = "callback-field",
        .producer = .callback_field,
        .canonical = "struct Callbacks { let candidate:func(int) bool; let wrong:func(str) bool }\nfunc accept(callback:func(int) bool) {}\nfunc inspect(callbacks:Callbacks) { accept(callbacks.candidate) }\nfunc main() {}",
        .partial = "struct Callbacks { let candidate:func(int) bool; let wrong:func(str) bool }\nfunc accept(callback:func(int) bool) {}\nfunc inspect(callbacks:Callbacks) { accept(callbacks.<|>) }\nfunc main() {}",
        .expected = .{ .item = .{ .label = "candidate", .kind = 5, .detail = "candidate:function", .insert_text = "candidate" } },
        .forbidden = "wrong",
    },
    .{
        .id = "returned-callback",
        .producer = .returned_callback,
        .canonical = "func make_candidate() func(int) bool { return func(value:int) bool { return true } }\nfunc make_wrong() func(str) bool { return func(value:str) bool { return true } }\nfunc accept(callback:func(int) bool) {}\nfunc main() { accept(make_candidate()) }",
        .partial = "func make_candidate() func(int) bool { return func(value:int) bool { return true } }\nfunc make_wrong() func(str) bool { return func(value:str) bool { return true } }\nfunc accept(callback:func(int) bool) {}\nfunc main() { accept(<|>) }",
        .expected = .{ .item = .{ .label = "make_candidate", .kind = 3, .detail = "make_candidate() function", .insert_text = "make_candidate()" } },
        .forbidden = "make_wrong",
    },
    .{
        .id = "tuple-callable",
        .producer = .tuple_callable,
        .canonical = "func accept(callback:func(int) bool) {}\nfunc inspect(callbacks:(candidate:func(int) bool, wrong:func(str) bool)) { accept(callbacks.candidate) }\nfunc main() {}",
        .partial = "func accept(callback:func(int) bool) {}\nfunc inspect(callbacks:(candidate:func(int) bool, wrong:func(str) bool)) { accept(callbacks.<|>) }\nfunc main() {}",
        .expected = .{ .item = .{ .label = "candidate", .kind = 5, .detail = "candidate:function", .insert_text = "candidate" } },
        .forbidden = "wrong",
    },
    .{
        .id = "injected-callable",
        .producer = .injected_callable,
        .canonical = "func accept(callback:func(int) bool) {}\nfunc system(candidate:func(int) bool, wrong:func(str) bool) { accept(candidate) }\nfunc main() {}",
        .partial = "func accept(callback:func(int) bool) {}\nfunc system(candidate:func(int) bool, wrong:func(str) bool) { accept(<|>) }\nfunc main() {}",
        .expected = .{ .item = .{ .label = "candidate", .kind = 6, .detail = "candidate(int) bool", .insert_text = "candidate" } },
        .forbidden = "wrong",
    },
};

fn expectedProducerItem(allocator: std.mem.Allocator, case: ProducerCase) !Support.ExpectedItem {
    return switch (case.expected) {
        .function => |name| blk: {
            const item = try Oracle.functionReference(allocator, case.canonical, name);
            break :blk .{ .label = item.name, .kind = item.kind, .detail = item.detail, .insert_text = item.insert_text };
        },
        .method => |target| blk: {
            const item = try Oracle.methodReference(allocator, case.canonical, target.owner, target.name);
            break :blk .{ .label = item.name, .kind = item.kind, .detail = item.detail, .insert_text = item.insert_text };
        },
        .item => |item| item,
    };
}

test "callable producers preserve identity signature filtering and insertion" {
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    for (producer_cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        var frontend = FrontendModule.Frontend.init(allocator);
        frontend.checkDocument(case.canonical) catch |err| {
            std.debug.print("callable producer canonical '{s}' failed: {s}\n", .{ case.id, if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err) });
            return err;
        };
        const uri = try std.fmt.allocPrint(allocator, "file:///Callable-Producer-{d}.sx", .{index});
        const items = try Support.serverCompletion(&server, allocator, uri, case.partial);
        const expected = try expectedProducerItem(allocator, case);
        Support.expectItem(expected, items) catch |err| {
            std.debug.print("callable producer '{s}' lost '{s}'\n", .{ case.id, expected.label });
            for (items) |item| std.debug.print("  {s} | {s} | {s}\n", .{ item.label, item.detail, item.insertText orelse "<none>" });
            return err;
        };
        try Support.expectAbsent(case.forbidden, items);
        try Support.expectNoDuplicates(items);
        const repeated = try Support.serverCompletion(&server, allocator, uri, case.partial);
        try Support.expectEqualItems(items, repeated);
    }
}

const InvocationCase = struct {
    id: []const u8,
    producer: Composition.ProducerKind,
    partial: []const u8,
};

const value_declarations = "func inspect_value(candidate:int, wrong:str) {}\n";

const invocation_cases = [_]InvocationCase{
    .{ .id = "callback-parameter", .producer = .callback_parameter, .partial = "func inspect(candidate:int, wrong:str, callback:func(int) bool) { callback(<|>) }\nfunc main() {}" },
    .{ .id = "callback-field", .producer = .callback_field, .partial = "struct Holder { let callback:func(int) bool }\nfunc inspect(candidate:int, wrong:str, holder:Holder) { holder.callback(<|>) }\nfunc main() {}" },
    .{ .id = "function-return", .producer = .returned_callback, .partial = "func produce() func(int) bool { return func(value:int) bool { return true } }\nfunc inspect(candidate:int, wrong:str) {\n    let callback = produce()\n    callback(<|>)\n}\nfunc main() {}" },
    .{ .id = "method-return", .producer = .returned_callback, .partial = "struct Factory { func produce() func(int) bool { return func(value:int) bool { return true } } }\nfunc inspect(candidate:int, wrong:str, factory:Factory) {\n    let callback = factory.produce()\n    callback(<|>)\n}\nfunc main() {}" },
    .{ .id = "callback-return", .producer = .returned_callback, .partial = "func inspect(candidate:int, wrong:str, produce:func() func(int) bool) {\n    let callback = produce()\n    callback(<|>)\n}\nfunc main() {}" },
    .{ .id = "named-tuple-element", .producer = .tuple_callable, .partial = "func inspect(candidate:int, wrong:str, callbacks:(run:func(int) bool, stop:func())) { callbacks.run(<|>) }\nfunc main() {}" },
    .{ .id = "destructured-tuple-element", .producer = .tuple_callable, .partial = "func inspect(candidate:int, wrong:str, callbacks:(func(int) bool, func())) {\n    let (run, stop) = callbacks\n    run(<|>)\n}\nfunc main() {}" },
    .{ .id = "injected-callback", .producer = .injected_callable, .partial = "func system(candidate:int, wrong:str, injected:func(int) bool) { injected(<|>) }\nfunc main() {}" },
};

test "callable invocation propagates positional signatures through every producer form" {
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    for (invocation_cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const canonical = try std.mem.replaceOwned(u8, allocator, case.partial, "<|>", "candidate");
        var frontend = FrontendModule.Frontend.init(allocator);
        frontend.checkDocument(canonical) catch |err| {
            std.debug.print("callable invocation canonical '{s}' failed: {s}\n", .{ case.id, if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err) });
            return err;
        };
        const parameter = try Oracle.parameter(allocator, canonical, if (std.mem.startsWith(u8, case.id, "injected")) "system" else "inspect", "candidate");
        const expected: Support.ExpectedItem = .{
            .label = parameter.name,
            .kind = 6,
            .detail = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ parameter.name, parameter.type_name }),
            .insert_text = parameter.name,
        };
        const uri = try std.fmt.allocPrint(allocator, "file:///Callable-Invocation-{d}.sx", .{index});
        const items = try Support.serverCompletion(&server, allocator, uri, case.partial);
        Support.expectItem(expected, items) catch |err| {
            std.debug.print("callable invocation '{s}' lost its argument type\n", .{case.id});
            return err;
        };
        try Support.expectAbsent("wrong", items);
        try Support.expectNoDuplicates(items);
    }
}

test "callback calls stay positional while declaration calls expose only remaining labels" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();

    const direct_marked = try Support.removeMarker(
        allocator,
        "func schedule(stage:int, callback:func(), priority:int = 0) {}\nfunc main() { schedule(stage:1, <|>) }",
    );
    const direct = try Completion.parameterItemsAt(allocator, direct_marked.text, direct_marked.cursor);
    try Support.expectExactLabels(&.{ "callback", "priority" }, direct);
    try Support.expectItem(.{ .label = "callback", .kind = 6, .detail = "callback:function", .insert_text = "callback:" }, direct);
    try Support.expectItem(.{ .label = "priority", .kind = 6, .detail = "priority:int = 0", .insert_text = "priority:" }, direct);

    const method_marked = try Support.removeMarker(
        allocator,
        "struct Scheduler { func schedule(stage:int, callback:func(), priority:int = 0) {} }\nfunc inspect(scheduler:Scheduler) { scheduler.schedule(stage:1, <|>) }\nfunc main() {}",
    );
    const method = try Completion.parameterItemsAt(allocator, method_marked.text, method_marked.cursor);
    try Support.expectExactLabels(&.{ "callback", "priority" }, method);
    try Support.expectItem(.{ .label = "callback", .kind = 6, .detail = "callback:function", .insert_text = "callback:" }, method);
    try Support.expectItem(.{ .label = "priority", .kind = 6, .detail = "priority:int = 0", .insert_text = "priority:" }, method);

    const marked = try Support.removeMarker(allocator, "func inspect(callback:func(int, str), candidate:int) { callback(candidate, <|>) }\nfunc main() {}");
    const labels = try Completion.parameterItemsAt(allocator, marked.text, marked.cursor);
    try std.testing.expectEqual(@as(usize, 0), labels.len);
}

test "overload filtering defaults anonymous functions and nested callback demands are exact" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();

    const overloads = try Support.serverCompletion(&server, allocator, "file:///Callable-Overloads.sx", "func convert(value:int) int { return value }\nfunc convert(value:str) str { return value }\nfunc accept(callback:func(int) int) {}\nfunc main() { accept(con<|>) }");
    try Support.expectExactLabels(&.{"convert"}, overloads);
    try Support.expectItem(.{ .label = "convert", .kind = 3, .detail = "convert(value:int) int", .insert_text = "convert" }, overloads);

    const defaults = try Support.serverCompletion(&server, allocator, "file:///Callable-Defaults.sx", "func schedule(stage:int, callback:func(), priority:int = 0) {}\nfunc main() { sche<|> }");
    const DefaultShape = struct { label: []const u8, detail: []const u8, insertion: []const u8 };
    for ([_]DefaultShape{
        .{ .label = "schedule(stage:int, callback:function)", .detail = "schedule(stage:int, callback:function) void", .insertion = "schedule(${1:stage}, ${2:callback})$0" },
        .{ .label = "schedule(stage:int, callback:function, priority:int = 0)", .detail = "schedule(stage:int, callback:function, priority:int = 0) void", .insertion = "schedule(${1:stage}, ${2:callback}, ${3:priority})$0" },
    }) |shape| {
        var found = false;
        for (defaults) |item| {
            if (!std.mem.eql(u8, item.label, shape.label)) continue;
            try std.testing.expectEqual(@as(u8, 3), item.kind);
            try std.testing.expectEqualStrings(shape.detail, item.detail);
            try std.testing.expectEqualStrings("schedule", item.filterText.?);
            try std.testing.expectEqualStrings(shape.insertion, item.insertText.?);
            try std.testing.expectEqual(@as(?u8, 2), item.insertTextFormat);
            found = true;
        }
        try std.testing.expect(found);
    }

    const anonymous = try Support.serverCompletion(&server, allocator, "file:///Callable-Anonymous.sx", "func accept(callback:func(int) bool) {}\nfunc main() { accept(<|>) }");
    try Support.expectItem(.{ .label = "func", .kind = 14, .detail = "Silex anonymous function", .insert_text = "func" }, anonymous);

    const nested = try Support.serverCompletion(&server, allocator, "file:///Callable-Nested.sx", "func candidate(value:int) bool { return true }\nfunc wrong(value:str) bool { return true }\nfunc inspect(invoke:func(func(int) bool)) { invoke(<|>) }\nfunc main() {}");
    try Support.expectItem(.{ .label = "candidate", .kind = 3, .detail = "candidate(value:int) bool", .insert_text = "candidate" }, nested);
    try Support.expectAbsent("wrong", nested);
}

test "imported callable values use the same expected signature engine" {
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
        .sub_path = "Api/Module/Callbacks.sx",
        .data = "public func candidate(value:int) bool { return true }\npublic func wrong(value:str) bool { return true }",
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
    const items = try Support.serverCompletion(
        &server,
        allocator,
        uri,
        "use Api.Callbacks.candidate\nuse Api.Callbacks.wrong\nfunc accept(callback:func(int) bool) {}\nfunc main() { accept(<|>) }",
    );
    Support.expectItem(.{ .label = "candidate", .kind = 3, .detail = "candidate(value:int) bool", .insert_text = "candidate" }, items) catch |err| {
        for (items) |item| std.debug.print("imported callable {s} | {s} | {s}\n", .{ item.label, item.detail, item.insertText orelse "<none>" });
        return err;
    };
    try Support.expectAbsent("wrong", items);
    try Support.expectNoDuplicates(items);
}

fn auditProducerCoverage(suppressed: ?Composition.ProducerKind) !usize {
    var producers = [_]bool{false} ** @typeInfo(Composition.ProducerKind).@"enum".fields.len;
    for (producer_cases) |case| if (suppressed == null or case.producer != suppressed.?) {
        producers[@intFromEnum(case.producer)] = true;
    };
    for (invocation_cases) |case| if (suppressed == null or case.producer != suppressed.?) {
        producers[@intFromEnum(case.producer)] = true;
    };
    if (suppressed == null or suppressed.? != .imported_callable) producers[@intFromEnum(Composition.ProducerKind.imported_callable)] = true;
    var covered: usize = 0;
    for (std.enums.values(Composition.DemandKind)) |demand| for (std.enums.values(Composition.ProducerKind)) |producer|
        for (std.enums.values(Composition.ConsumerKind)) |consumer| for (std.enums.values(Composition.TransformKind)) |transform| {
            const status = Composition.statusFor(.{ .demand = demand, .producer = producer, .consumer = consumer, .transform = transform });
            const schema = switch (status) {
                .proved => |owned| owned,
                .required, .excluded => continue,
            };
            if (schema != .callable_composition_surface) continue;
            if (!producers[@intFromEnum(producer)]) return error.MissingCallableProducerEdge;
            covered += 1;
        };
    if (covered == 0) return error.EmptyCallableCampaign;
    return covered;
}

test "every callable composition key has generated producer coverage" {
    try std.testing.expect((try auditProducerCoverage(null)) > producer_cases.len + invocation_cases.len);
}

test "suppressing any callable producer breaks its generated family" {
    for (std.enums.values(Composition.ProducerKind)) |producer| {
        if (!Composition.isCallableProducer(producer)) continue;
        try std.testing.expectError(error.MissingCallableProducerEdge, auditProducerCoverage(producer));
    }
}
