const std = @import("std");
const Completion = @import("../Completion.zig");
const Support = @import("Support.zig");
const Frontend = @import("../../Frontend.zig").Frontend;

test "nested callback completion keeps every lexical level visible" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const source =
        \\func apply(value:int, callback:func(int) int) int { return callback(value) }
        \\func main() {
        \\    let base = 30
        \\    apply(5, func(outer:int) int {
        \\        let offset = 2
        \\        return apply(outer, func(inner:int) int {
        \\            return ba
        \\        })
        \\    })
        \\}
    ;
    const cursor = std.mem.indexOf(u8, source, "return ba").? + "return ba".len;
    const items = try Completion.itemsAt(allocator, source, cursor, .invoked);
    try std.testing.expect(hasLabel(items, "base"));
    try std.testing.expect(!hasLabel(items, "__silex_anonymous_0"));
}

fn hasLabel(items: anytype, label: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.label, label)) return true;
    return false;
}

test "generic reader remains discoverable inside a captured callback" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const header =
        \\class Cell<T> { let value:T; init(value:T) { self.value = value } }
        \\struct Reader {
        \\    func read<T>(cell:Cell<T>) T { return cell.value }
        \\    private func hidden() {}
        \\}
    ;
    const canonical = header ++
        "\nfunc main() { var state = Cell<str>(\"Silex\"); let describe = func(reader:Reader) str { return reader.read(state) }; print(describe(Reader())) }";
    var frontend = Frontend.init(allocator);
    _ = try frontend.compile(canonical);
    for ([_][]const u8{ "reader.<|>", "reader.re<|>" }) |partial| {
        const source = try std.fmt.allocPrint(allocator, "{s}\nfunc main() {{ var state = Cell<str>(\"Silex\"); let describe = func(reader:Reader) str {{ return {s} }}; print(describe(Reader())) }}", .{ header, partial });
        const items = try Support.complete(allocator, source);
        try std.testing.expect(hasLabel(items, "read"));
        try std.testing.expect(!hasLabel(items, "hidden"));
        try Support.expectNoDuplicates(items);
        try Support.expectEqualItems(items, try Support.complete(allocator, source));
    }
}

test "callback fields on indexed receivers remain discoverable and callable" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const header =
        \\struct Slot { var callback:func(int) int; private var hidden:int = 0 }
        \\class Owner { var slots:Slot[] }
        \\func add(value:int) int { return value }
    ;
    const setup = "\nfunc main() { let slots:Slot[] = [Slot(callback:add)]; var owner = Owner(slots:slots); ";
    var frontend = Frontend.init(allocator);
    _ = try frontend.compile(header ++ setup ++ "print(owner.slots[0].callback(3)) }");
    for ([_][]const u8{ "slots[0].<|>", "slots[0].ca<|>", "owner.slots[0].<|>" }) |partial| {
        const source = try std.fmt.allocPrint(allocator, "{s}{s}{s} }}", .{ header, setup, partial });
        const items = try Support.complete(allocator, source);
        try std.testing.expect(hasLabel(items, "callback"));
        try std.testing.expect(!hasLabel(items, "hidden"));
        try std.testing.expect(!hasLabel(items, "count"));
        for (items) |item| if (std.mem.eql(u8, item.label, "callback")) {
            try std.testing.expectEqualStrings("callback", item.insertText.?);
        };
        try Support.expectNoDuplicates(items);
        try Support.expectEqualItems(items, try Support.complete(allocator, source));
    }
}

test "grouped callback type contexts retain types and exclude values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const header = "struct Target {}\nfunc factory() Target { return Target() }\n";
    var frontend = Frontend.init(allocator);
    _ = try frontend.compile(header ++ "func main() { let convert:(func(str) Target?)? = null }\n");
    for ([_][]const u8{
        "let convert:(<|>)? = null",
        "let convert:(func(<|>) Target?)? = null",
        "let convert:(func(str) Tar<|>?)? = null",
        "let convert:((Tar<|>))? = null",
    }) |partial| {
        const source = try std.fmt.allocPrint(allocator, "{s}func main() {{ {s} }}", .{ header, partial });
        const items = try Support.complete(allocator, source);
        try std.testing.expect(hasLabel(items, "Target"));
        try std.testing.expect(!hasLabel(items, "factory"));
        try std.testing.expect(!hasLabel(items, "true"));
        for (items) |item| if (std.mem.eql(u8, item.label, "Target")) {
            try std.testing.expectEqualStrings("Target", item.insertText.?);
        };
        try Support.expectNoDuplicates(items);
        try Support.expectEqualItems(items, try Support.complete(allocator, source));
    }
}

test "distinct callable collection signatures keep contextual completion" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const header =
        \\func integer(value:int) int { return value }
        \\func text(value:str) str { return value }
        \\func wrap<T>(value:T) T[] { return [value] }
    ;
    const setup = "\nfunc main() { let message = \"Silex\"; let amount = 2; var integers:(func(int) int)[] = [integer]; var strings:(func(str) str)[] = [text]; var inferred = wrap(text); ";
    var frontend = Frontend.init(a);
    _ = try frontend.compile(header ++ setup ++ "strings.append(text); inferred.append(text); let transform = inferred[0]; print(transform(message)); let read = integers[0]; print(read(amount)) }");
    for ([_]struct { expression: []const u8, positive: []const u8, negative: []const u8, insertion: []const u8 }{
        .{ .expression = "let more:(func(int) int)[] = [<|>]", .positive = "integer", .negative = "text", .insertion = "integer" },
        .{ .expression = "strings.append(<|>)", .positive = "text", .negative = "integer", .insertion = "text" },
        .{ .expression = "inferred.append(<|>)", .positive = "text", .negative = "integer", .insertion = "text" },
        .{ .expression = "let transform = inferred[0]; transform(<|>)", .positive = "message", .negative = "amount", .insertion = "message" },
    }) |case| {
        const source = try std.fmt.allocPrint(a, "{s}{s}{s} }}", .{ header, setup, case.expression });
        const items = try Support.complete(a, source);
        if (!hasLabel(items, case.positive) or hasLabel(items, case.negative)) {
            std.debug.print("collection context: {s}\n", .{case.expression});
            for (items) |item| if (std.mem.eql(u8, item.label, case.positive) or std.mem.eql(u8, item.label, case.negative)) std.debug.print("candidate: {s} insertion={s}\n", .{ item.label, item.insertText orelse "" });
        }
        try std.testing.expect(hasLabel(items, case.positive));
        try std.testing.expect(!hasLabel(items, case.negative));
        for (items) |item| if (std.mem.eql(u8, item.label, case.positive)) try std.testing.expectEqualStrings(case.insertion, item.insertText.?);
        try Support.expectNoDuplicates(items);
        try Support.expectEqualItems(items, try Support.complete(a, source));
    }
}

test "generic callable collections infer values without concrete annotations" {
    const header = "func text(value:str) str { return value }\nfunc integer(value:int) int { return value }\nfunc wrap<T>(value:T) T[] { return [value] }\n";
    const setup = "\nfunc main() { let message = \"Silex\"; let amount = 2; var inferred = wrap(value:text); ";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.init(a);
    _ = try frontend.compile(header ++ setup ++ "inferred.insert(0,text); let transform = inferred[0]; print(transform(message)) }");
    for ([_]struct { expression: []const u8, positive: []const u8, negative: []const u8 }{
        .{ .expression = "inferred.append(<|>)", .positive = "text", .negative = "integer" },
        .{ .expression = "inferred.prepend(<|>)", .positive = "text", .negative = "integer" },
        .{ .expression = "inferred.insert(0,<|>)", .positive = "text", .negative = "integer" },
        .{ .expression = "inferred.replace(0,<|>)", .positive = "text", .negative = "integer" },
        .{ .expression = "inferred.insert(<|>,text)", .positive = "amount", .negative = "message" },
        .{ .expression = "let transform = inferred[0]; transform(<|>)", .positive = "message", .negative = "amount" },
    }) |case| {
        const source = try std.fmt.allocPrint(a, "{s}{s}{s} }}", .{ header, setup, case.expression });
        const items = try Support.complete(a, source);
        if (!hasLabel(items, case.positive) or hasLabel(items, case.negative)) {
            std.debug.print("inferred collection context: {s}\n", .{case.expression});
            for (items) |item| std.debug.print("candidate {s}: {s}\n", .{ item.label, item.detail });
        }
        try std.testing.expect(hasLabel(items, case.positive));
        try std.testing.expect(!hasLabel(items, case.negative));
        for (items) |item| if (std.mem.eql(u8, item.label, case.positive)) try std.testing.expectEqualStrings(case.positive, item.insertText.?);
        try Support.expectNoDuplicates(items);
        try Support.expectEqualItems(items, try Support.complete(a, source));
    }
}

test "generic callable collection completion preserves modes and nominal type arguments" {
    const cases = [_]struct { header: []const u8, canonical: []const u8, source: []const u8, positive: []const u8, negative: []const u8 }{
        .{
            .header = "func read(value:@int) {}\nfunc write(value:&int) {}\nfunc wrap<T>(value:T) T[] { return [value] }\n",
            .canonical = "func main() { var values = wrap(write); values.append(write) }",
            .source = "func main() { var values = wrap(write); values.append(<|>) }",
            .positive = "write",
            .negative = "read",
        },
        .{
            .header = "class Box<T> { var value:T }\nfunc integer(value:Box<int>) int { return value.value }\nfunc text(value:Box<str>) str { return value.value }\nfunc wrap<T>(value:T) T[] { return [value] }\n",
            .canonical = "func main() { var values = wrap(integer); values.append(integer) }",
            .source = "func main() { var values = wrap(integer); values.append(<|>) }",
            .positive = "integer",
            .negative = "text",
        },
    };
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const a = arena.allocator();
        var frontend = Frontend.init(a);
        _ = try frontend.compile(try std.fmt.allocPrint(a, "{s}{s}", .{ case.header, case.canonical }));
        const items = try Support.complete(a, try std.fmt.allocPrint(a, "{s}{s}", .{ case.header, case.source }));
        try std.testing.expect(hasLabel(items, case.positive));
        try std.testing.expect(!hasLabel(items, case.negative));
        for (items) |item| if (std.mem.eql(u8, item.label, case.positive)) try std.testing.expectEqualStrings(case.positive, item.insertText.?);
        try Support.expectNoDuplicates(items);
    }
}
