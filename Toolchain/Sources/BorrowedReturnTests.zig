const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

fn run(source: []const u8) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = Frontend.Frontend.init(allocator);
    const result = try Interpreter.runCapture(allocator, (try frontend.compile(source)).ir);
    return std.testing.allocator.dupe(u8, result.stdout);
}

test "borrowed returns infer provenance without a return prefix" {
    const output = try run(
        \\struct State { var value:int }
        \\struct Owner { var state:State }
        \\func inspect(owner:@Owner) @State { return owner.state }
        \\func inspect_again(owner:@Owner) @State { return inspect(owner) }
        \\func edit(owner:&Owner) &State { return owner.state }
        \\func read(owner:@Owner) {
        \\    let view = inspect_again(owner)
        \\    print(view.value)
        \\}
        \\func change(owner:&Owner) {
        \\    if true {
        \\        var alias = edit(owner)
        \\        alias.value += 2
        \\        print(alias.value)
        \\    }
        \\    print(owner.state.value)
        \\}
        \\func main() {
        \\    var owner = Owner(state:State(value:40))
        \\    read(owner)
        \\    change(owner)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("40\n42\n42\n", output);
}

test "borrowed return provenance can be qualified" {
    const output = try run(
        \\struct State { let value:int }
        \\struct Owner { let state:State }
        \\func first_state(first:@Owner, second:@Owner) @first:State { return first.state }
        \\func main() {
        \\    let first = Owner(state:State(value:1))
        \\    let second = Owner(state:State(value:2))
        \\    let view:@State = first_state(first, second)
        \\    print(view.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("1\n", output);
}

test "methods return shared and mutable aliases without return prefixes" {
    const output = try run(
        \\struct State { var value:int }
        \\struct Owner {
        \\    var state:State
        \\    func inspect() @State { return self.state }
        \\    func edit() &State { return self.state }
        \\}
        \\func main() {
        \\    var owner = Owner(state:State(value:5))
        \\    if true { let view = owner.inspect(); print(view.value) }
        \\    if true { var alias = owner.edit(); alias.value += 2; print(alias.value) }
        \\    print(owner.state.value)
        \\}
    );
    defer std.testing.allocator.free(output);
    try std.testing.expectEqualStrings("5\n7\n7\n", output);
}

test "borrowed returns reject ambiguous wrong and temporary provenance" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct State { let value:int }
        \\struct Owner { let state:State }
        \\func choose(first:@Owner, second:@Owner) @State { return first.state }
        \\func main() {}
    ));
    try std.testing.expect(std.mem.containsAtLeast(u8, frontend.diagnostic.?.message, 1, "provenance is ambiguous"));

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct State { let value:int }
        \\struct Owner { let state:State }
        \\func choose(first:@Owner, second:@Owner) @first:State { return second.state }
        \\func main() {}
    ));
    try std.testing.expect(std.mem.containsAtLeast(u8, frontend.diagnostic.?.message, 1, "must originate from parameter 'first'"));

    frontend.diagnostic = null;
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct State { let value:int }
        \\struct Owner { let state:State }
        \\func inspect(owner:@Owner) @State { return owner.state }
        \\func main() { let view = inspect(Owner(state:State(value:1))); print(view.value) }
    ));
    try std.testing.expectEqualStrings("borrowed return cannot originate from a temporary", frontend.diagnostic.?.message);
}

test "mutable aliases are exclusive and cannot be copied" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(
        \\struct State { var value:int }
        \\struct Owner { var state:State }
        \\func edit(owner:&Owner) &State { return owner.state }
        \\func main() {
        \\    var owner = Owner(state:State(value:1))
        \\    var first = edit(owner)
        \\    let second = first
        \\    print(second.value)
        \\}
    ));
    try std.testing.expectEqualStrings("a mutable alias cannot be copied or weakened by another declaration", frontend.diagnostic.?.message);
}
