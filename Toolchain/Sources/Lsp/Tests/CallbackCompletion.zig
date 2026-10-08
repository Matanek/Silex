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
