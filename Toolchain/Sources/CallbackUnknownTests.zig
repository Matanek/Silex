const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const declarations =
    \\struct Registry { static var saved:(func())[] = [] }
    \\class Slot { var callback:(func())? = null; func set(callback:func()) { self.callback = callback } func clear() { self.callback = null } }
    \\func known_false() bool { let related = Registry.saved; return false }
    \\func known_true() bool { return true }
    \\func invoke(callback:func()) { callback() }
    \\func save(callback:func()) { Registry.saved.append(callback) }
;
fn rejected(comptime source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(declarations ++ source));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}
fn accepted(comptime source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++ source);
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
test "callback alternatives keep an unknown scalar target beside a known false target" {
    try rejected(
        \\func setup(target:Slot, choice:func() bool, change:bool) { var choose = choice; if change { choose = known_false } let enabled = choose(); let value = 7; if enabled { target.set(func() { print(value) }) } }
        \\func main() { var target = Slot(); setup(target,known_true,false) }
    );
}
test "callback alternatives preserve a copied unknown function value" {
    try rejected(
        \\func setup(target:Slot, choice:func() bool, change:bool) { var choose = copy choice; if change { choose = known_false } let enabled = choose(); let value = 7; if enabled { target.set(func() { print(value) }) } }
        \\func main() { var target = Slot(); setup(target,known_true,false) }
    );
}
test "callback alternatives preserve unknown elements in a collection" {
    try rejected(
        \\func setup(target:Slot, choice:func() bool, index:int) { let choices:(func() bool)[] = [choice,known_false]; let choose = choices[index]; let enabled = choose(); let value = 7; if enabled { target.set(func() { print(value) }) } }
        \\func main() { var target = Slot(); setup(target,known_true,0) }
    );
}
test "callback alternatives replay a potentially retaining higher order target" {
    try rejected(
        \\func setup(writer:func(func()), change:bool) { var selected = writer; if change { selected = invoke } let value = 7; selected(func() { print(value) }) }
        \\func main() { setup(save,false) }
    );
}
test "callback alternatives preserve unknown fields through an owner copy" {
    try rejected(
        \\class Choice { let callback:func() bool }
        \\func setup(target:Slot, choice:func() bool, change:bool) { var original = Choice(callback:choice); var detached = copy original; var choose = detached.callback; if change { choose = known_false } let enabled = choose(); let value = 7; if enabled { target.set(func() { print(value) }) } }
        \\func main() { var target = Slot(); setup(target,known_true,false) }
    );
}
test "callback alternatives preserve an optional unknown function value" {
    try rejected(
        \\func setup(target:Slot, choice:func() bool, change:bool) { var chosen:(func() bool)? = choice; if change { chosen = known_false } let value = 7; if let choose = chosen { if choose() { target.set(func() { print(value) }) } } }
        \\func main() { var target = Slot(); setup(target,known_true,false) }
    );
}
test "callback alternatives retain a synchronous higher order caller" {
    try accepted(
        \\func setup(writer:func(func()), change:bool) { var selected = writer; if change { selected = invoke } let value = 7; selected(func() { print(value) }) }
        \\func main() { setup(invoke,false) }
    );
}
test "callback alternatives allow an opaque notification before a cleared local loan" {
    try accepted(
        \\func empty() {}
        \\func setup(work:func(), change:bool) { var selected = copy work; if change { selected = empty } selected(); var slot = Slot(); var count = 0; slot.set(func() { count++ }); slot.clear(); assert(count == 0) }
        \\func main() { setup(empty,false) }
    );
}

test "callback alternatives external collection receiver keeps a possible retained loan" {
    try rejected(
        \\func setup(targets:Slot[],index:int) { let value=7; var target=targets[index]; target.set(func() { print(value) }) }
        \\func main() { var target=Slot(); setup([target],0) }
    );
}
test "callback alternatives external collection preserves an unknown function target" {
    try rejected(
        \\func setup(target:Slot,choices:(func() bool)[],index:int,change:bool) { var choose=choices[index]; if change { choose=known_false } let enabled=choose(); let value=7; if enabled { target.set(func() { print(value) }) } }
        \\func main() { var target=Slot(); setup(target,[known_true],0,false) }
    );
}

test "callback alternatives external collection does not clear a different possible receiver" {
    try rejected(
        \\func setup(targets:Slot[],first:int,second:int) { let value=7; var one=targets[first]; one.set(func() { print(value) }); var other=targets[second]; other.clear() }
        \\func main() { var first=Slot(); var second=Slot(); setup([first,second],0,1) }
    );
}
test "callback alternatives external collection allows clearing one known indexed receiver" {
    try accepted(
        \\func setup(targets:Slot[]) { let value=7; var target=targets[0]; target.set(func() { print(value) }); target.clear() }
        \\func main() { var target=Slot(); setup([target]) }
    );
}
