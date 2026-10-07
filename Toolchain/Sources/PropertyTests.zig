const std = @import("std");
const Frontend = @import("Frontend.zig");

fn expectCompileError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

test "property diagnostics preserve the source contract" {
    try expectCompileError(
        "struct Value { let answer:int { get { return 42 } } } func main() { var value = Value(); value.answer = 1 }",
        "cannot assign to read-only property",
    );
    try expectCompileError(
        "struct Value { let answer:int { set(value) {} get { return value } } } func main() {}",
        "a 'let' property cannot declare a setter",
    );
    try expectCompileError(
        "struct Counter { var reads:int; let value:int { get { self.reads++; return 1 } } } func main() {}",
        "a getter cannot mutate self; use an explicit method for observable mutation",
    );
    try expectCompileError(
        "protocol Named { var name:str } func main() {}",
        "a protocol can declare only method or property requirements",
    );
    try expectCompileError(
        "struct Value { let answer:int { get { return 42 } } } func main() { let value = Value(answer:1) }",
        "structure 'Value' has no field named 'answer'",
    );
}

test "nested mutation rejects a value returned by a property" {
    try expectCompileError(
        "struct Point { var x:int } struct Player { var stored:Point; let position:Point { get { return self.stored } } } func main() { var player = Player(stored:Point(x:1)); player.position.x = 10 }",
        "cannot mutate a member of value returned by property 'position'; assign a new property value instead",
    );
}

test "getters cannot mutate self through prepared views or nested protocol methods" {
    try expectCompileError(
        "func fill(values:&int[..]) {} struct Owner { var values:int[1]; let count:int { get { fill(&self.values[0:1]); return 1 } } } func main() {}",
        "a getter cannot mutate self; use an explicit method for observable mutation",
    );
    try expectCompileError(
        "protocol Resettable { func reset() } struct State:Resettable { var value:int; func reset() { self.value = 0 } } class Owner { var state:Resettable; init(state:Resettable) { self.state = state } let value:int { get { self.state.reset(); return 0 } } } func main() {}",
        "a getter cannot mutate self; use an explicit method for observable mutation",
    );
}
