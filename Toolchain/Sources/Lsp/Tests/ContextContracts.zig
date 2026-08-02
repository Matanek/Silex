const std = @import("std");
const Support = @import("Support.zig");

const fundamental_types = [_][]const u8{
    "bool",   "float",  "float32", "float64", "int",  "int16",
    "int32",  "int64",  "int8",    "str",     "uint", "uint16",
    "uint32", "uint64", "uint8",   "void",
};

test "offer declaration keywords from the first typed character" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    for ([_][]const u8{ "f<|>", "fu<|>", "fun<|>" }) |source| {
        const items = try Support.complete(allocator, source);
        try Support.expectExactLabels(&.{"func"}, items);
        try Support.expectItem(.{
            .label = "func",
            .kind = 14,
            .detail = "Silex function declaration",
            .insert_text = "func",
        }, items);
    }
}

test "offer statement keywords from the first typed character" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    for ([_][]const u8{ "l<|>", "le<|>" }) |prefix| {
        const source = try std.fmt.allocPrint(allocator, "func main() {{\n    {s}\n}}", .{prefix});
        const items = try Support.complete(allocator, source);
        try Support.expectFirst("let", items);
        try Support.expectPresent("let", items);
    }

    const cases = [_]struct { source: []const u8, expected: []const u8 }{
        .{ .source = "func main() { i<|> }", .expected = "if" },
        .{ .source = "func main() { r<|> }", .expected = "return" },
        .{ .source = "func main() {\n    var value = tr<|>\n}", .expected = "try" },
    };
    for (cases) |case| {
        const items = try Support.complete(allocator, case.source);
        try Support.expectPresent(case.expected, items);
    }
}

test "return type context contains only local types and fundamental types" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const items = try Support.complete(arena.allocator(),
        \\struct LocalType {}
        \\enum LocalEnum { ready }
        \\protocol LocalProtocol {}
        \\func make_value() LocalType { return LocalType() }
        \\func test(parameter:LocalType) <|>
    );

    var expected: [4 + fundamental_types.len][]const u8 = undefined;
    expected[0] = "Result";
    expected[1] = "LocalEnum";
    expected[2] = "LocalProtocol";
    expected[3] = "LocalType";
    @memcpy(expected[4..], &fundamental_types);
    try Support.expectExactLabels(&expected, items);
    try Support.expectAbsent("make_value", items);
    try Support.expectAbsent("parameter", items);
    try Support.expectAbsent("return", items);
    try Support.expectAbsent("true", items);
    try Support.expectNoDuplicates(items);
}

test "generic argument context preserves the complete type catalogue" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const sources = [_][]const u8{
        \\struct LocalType {}
        \\enum LocalEnum { ready }
        \\func test() Result<<|>>
        ,
        \\struct LocalType {}
        \\enum LocalEnum { ready }
        \\func test() Result<int, <|>>
        ,
    };
    for (sources) |source| {
        const items = try Support.complete(allocator, source);
        var expected: [3 + fundamental_types.len][]const u8 = undefined;
        expected[0] = "Result";
        expected[1] = "LocalEnum";
        expected[2] = "LocalType";
        @memcpy(expected[3..], &fundamental_types);
        try Support.expectExactLabels(&expected, items);
        try Support.expectAbsent("ready", items);
        try Support.expectAbsent("return", items);
        try Support.expectNoDuplicates(items);
    }
}

test "field parameter and generic annotations expose the complete type catalogue" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const field_items = try Support.complete(allocator,
        \\struct LocalType {}
        \\struct Error {
        \\    let message:<|>
        \\}
    );
    var field_expected: [3 + fundamental_types.len][]const u8 = undefined;
    field_expected[0] = "Result";
    field_expected[1] = "Error";
    field_expected[2] = "LocalType";
    @memcpy(field_expected[3..], &fundamental_types);
    try Support.expectExactLabels(&field_expected, field_items);
    try Support.expectAbsent("let", field_items);
    try Support.expectAbsent("true", field_items);
    try Support.expectNoDuplicates(field_items);

    const parameter_items = try Support.complete(allocator,
        \\struct LocalType {}
        \\func report(message:<|>) {}
    );
    var parameter_expected: [2 + fundamental_types.len][]const u8 = undefined;
    parameter_expected[0] = "Result";
    parameter_expected[1] = "LocalType";
    @memcpy(parameter_expected[2..], &fundamental_types);
    try Support.expectExactLabels(&parameter_expected, parameter_items);
    try Support.expectAbsent("let", parameter_items);
    try Support.expectAbsent("true", parameter_items);
    try Support.expectNoDuplicates(parameter_items);

    const generic_items = try Support.complete(allocator,
        \\struct LocalType {}
        \\protocol LocalProtocol {}
        \\func draw<T:<|>>() {}
    );
    var generic_expected: [3 + fundamental_types.len][]const u8 = undefined;
    generic_expected[0] = "Result";
    generic_expected[1] = "LocalProtocol";
    generic_expected[2] = "LocalType";
    @memcpy(generic_expected[3..], &fundamental_types);
    try Support.expectExactLabels(&generic_expected, generic_items);
    try Support.expectAbsent("return", generic_items);
    try Support.expectAbsent("true", generic_items);
    try Support.expectNoDuplicates(generic_items);
}

test "completion is deterministic for incomplete source" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\struct Error { let message:str }
        \\func test(fails:bool) Result<int, Error> {
        \\    var value = try test(true) else error {
        \\        print("$(er<|>)")
        \\    }
        \\}
    ;
    const first = try Support.complete(allocator, source);
    const second = try Support.complete(allocator, source);
    try Support.expectEqualItems(first, second);
    try Support.expectPresent("error", first);
    try Support.expectNoDuplicates(first);
}

test "offer the implicit try error binding while its required name is being typed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const sources = [_][]const u8{
        \\struct Error { let message:str }
        \\func test() Result<int, Error> { return Result<int, Error>.success(42) }
        \\func main() {
        \\    var value = try test() else <|> {
        \\        return
        \\    }
        \\}
        ,
        \\struct Error { let message:str }
        \\func test() Result<int, Error> { return Result<int, Error>.success(42) }
        \\func main() {
        \\    var value = try test() else e<|> {
        \\        return
        \\    }
        \\}
        ,
    };
    for (sources) |source| {
        const items = try Support.complete(allocator, source);
        try Support.expectFirst("error", items);
        try Support.expectItem(.{
            .label = "error",
            .kind = 6,
            .detail = "error:Error",
            .insert_text = "error {$0}",
            .insert_text_format = 2,
        }, items);
        if (std.mem.indexOf(u8, source, "else <|>") != null) {
            try Support.expectExactLabels(&.{ "error", "{}" }, items);
            try Support.expectItem(.{
                .label = "{}",
                .kind = 14,
                .detail = "Silex fallback block",
                .insert_text = "{$0}",
                .insert_text_format = 2,
            }, items);
        } else try Support.expectExactLabels(&.{"error"}, items);
        try Support.expectNoDuplicates(items);
    }
}

test "offer only the two try fallback constructs after a completed operand" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const sources = [_][]const u8{
        \\struct Error {}
        \\func test() Result<int, Error> { return Result<int, Error>.success(42) }
        \\func main() {
        \\    var value = try test()<|>
        \\}
        ,
        \\struct Error {}
        \\func test() Result<int, Error> { return Result<int, Error>.success(42) }
        \\func main() {
        \\    var value = try test() <|>
        \\}
        ,
        \\struct Error {}
        \\func test() Result<int, Error> { return Result<int, Error>.success(42) }
        \\func main() {
        \\    var value = try test() e<|>
        \\}
        ,
    };
    for (sources) |source| {
        const items = try Support.complete(allocator, source);
        try Support.expectExactLabels(&.{ "else", "else error" }, items);
        try Support.expectItem(.{
            .label = "else",
            .kind = 14,
            .detail = "Silex fallback branch",
            .insert_text = "else {$0}",
            .insert_text_format = 2,
        }, items);
        try Support.expectItem(.{
            .label = "else error",
            .kind = 14,
            .detail = "Silex fallback branch with implicit error binding",
            .insert_text = "else error {$0}",
            .insert_text_format = 2,
        }, items);
    }

    const ordinary = try Support.complete(allocator,
        \\func test() int { return 42 }
        \\func main() { var value = test() e<|> }
    );
    try Support.expectAbsent("else", ordinary);
    try Support.expectAbsent("else error", ordinary);
}
