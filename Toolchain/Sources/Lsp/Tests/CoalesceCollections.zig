const std = @import("std");
const Support = @import("Support.zig");
const Server = @import("../Server.zig").Server;

test "coalescing collection completion uses the payload element in local return and nested literals" {
    const cases = [_][]const u8{
        "func load() int[]? { return null }\nfunc main() { let value_number:int = 7; let value_text:str = \"x\"; let result = load() ?? [<|>] }",
        "func restore(source:int[]?) int[] { let value_number:int = 7; let value_text:str = \"x\"; return source ?? [<|>] }",
        "func main() { let source:int[][]? = null; let value_number:int = 7; let value_text:str = \"x\"; let result = source ?? [[<|>]] }",
        "func main() { let first:int[]? = null; let second:int[]? = null; let value_number:int = 7; let value_text:str = \"x\"; let result = first ?? second ?? [<|>] }",
        "func main() { let source:int[]? = null; let value_number:int = 7; let value_text:str = \"x\"; let result = source ?? ([\n<|>\n]) }",
        "func main() { let source:(int[],str)? = null; let value_number:int = 7; let value_text:str = \"x\"; let result = source ?? ([<|>],\"x\") }",
        "func main() { let source:(int[],str)? = null; let value_number:int = 7; let value_text:str = \"x\"; let result = source ?? (([<|>],\"x\")) }",
        "func main() { let source:(text:str,items:int[])? = null; let value_number:int = 7; let value_text:str = \"x\"; let result = source ?? (text:\"x\",items:[<|>]) }",
        "struct Holder<T> { let value:T?; func get() T? { return self.value } }\nfunc main() { let source:Holder<int[]> = Holder<int[]>(value:null); let value_number:int = 7; let value_text:str = \"x\"; let result = source.get() ?? [<|>] }",
    };
    for (cases) |source| {
        errdefer std.debug.print("completion source: {s}\n", .{source});
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const items = try Support.complete(arena.allocator(), source);
        const repeated = try Support.complete(arena.allocator(), source);
        try Support.expectItem(.{ .label = "value_number", .kind = 6, .detail = "value_number:int", .insert_text = "value_number" }, items);
        try Support.expectAbsent("value_text", items);
        try Support.expectFirst("value_number", items);
        try Support.expectNoDuplicates(items);
        try Support.expectEqualItems(items, repeated);
    }
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const text_slot = try Support.complete(
        arena.allocator(),
        "func main() { let source:(int[],str)? = null; let value_number:int = 7; let value_text:str = \"x\"; let result = source ?? ([],<|>) }",
    );
    try Support.expectPresent("value_text", text_slot);
    try Support.expectAbsent("value_number", text_slot);
    try Support.expectNoDuplicates(text_slot);
    const prefix = try Support.complete(
        arena.allocator(),
        "func main() { let source:int[]? = null; let value_number:int = 7; let value_text:str = \"x\"; let result = source ?? [value_<|>] }",
    );
    // A started name can be an expression root with a member continuation.
    try Support.expectFirst("value_number", prefix);
    try Support.expectPresent("value_text", prefix);
    try Support.expectNoDuplicates(prefix);
}

test "coalescing collection completion preserves inner calls and ends with the literal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const inner = try Support.complete(
        allocator,
        "func load() int[]? { return null }\nfunc make(text:str) int { return 0 }\nfunc main() { let value_number:int = 7; let value_text:str = \"x\"; let result = load() ?? [make(<|>)] }",
    );
    try Support.expectPresent("value_text", inner);
    try Support.expectAbsent("value_number", inner);
    const after = try Support.complete(
        allocator,
        "func load() int[]? { return null }\nfunc main() { let value_number:int = 7; let value_text:str = \"x\"; let result = load() ?? [7]; value_<|> }",
    );
    try Support.expectPresent("value_number", after);
    try Support.expectPresent("value_text", after);
    try Support.expectNoDuplicates(after);
    const numeric = try Support.complete(
        allocator,
        "func main() { let source:int8? = null; let value_fraction:float64 = 1.5; let result = source ?? (<|>) }",
    );
    try Support.expectPresent("value_fraction", numeric);
    try Support.expectNoDuplicates(numeric);
}

test "coalescing collection completion reaches the server document without leaking temporary symbols" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const items = try Support.serverCompletion(
        &server,
        arena.allocator(),
        "file:///CoalesceCollections.sx",
        "func load() int[]? { return null }\nfunc main() { let value_number:int = 7; let value_text:str = \"x\"; let result = load() ?? [<|>] }",
    );
    try Support.expectPresent("value_number", items);
    try Support.expectAbsent("value_text", items);
    try Support.expectAbsent("__completion", items);
    try Support.expectNoDuplicates(items);
}
