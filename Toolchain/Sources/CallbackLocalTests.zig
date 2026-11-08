const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const declarations =
    \\class Slot { var callback:(func())? = null; func set(callback:func()) { self.callback = callback } func clear() { self.callback = null } func invoke() { if let callback = self.callback { callback() } } }
    \\func identity(callback:func()) func() { return callback }
    \\func attach(slot:Slot,callback:func()) { slot.set(callback) }
;
fn rejected(comptime source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(declarations ++ source));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}
test "callback private locals preserve a callback after a recursive call" {
    try rejected(
        \\func setup(target:Slot,depth:int) { let value=7; var callback=func() { print(value) }; if depth > 0 { setup(target,depth-1); target.set(callback) } }
        \\func main() { var target=Slot(); setup(target,1) }
    );
}
test "callback private locals remain visible at a captured binding scope end" {
    try rejected(
        \\func setup() { var retained:(func())?=null; { let value=7; retained=identity(func() { print(value) }) } if let callback=retained { callback() } }
        \\func main() { setup() }
    );
}
test "callback private locals preserve shared class fields at scope end" {
    try rejected(
        \\func setup() { var owner=Slot(); var alias=owner; { let value=7; attach(alias,func() { print(value) }) } owner.invoke() }
        \\func main() { setup() }
    );
}
test "callback private locals keep an explicitly assigned true control value" {
    try rejected(
        \\func setup(target:Slot) { var enabled=false; enabled=true; let value=7; if enabled { target.set(func() { print(value) }) } }
        \\func main() { var target=Slot(); setup(target) }
    );
}
test "callback private locals preserve a false loop control fact without an alias" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\func setup(target:Slot) { var enabled=false; for index in 0...2 { enabled=false } let value=7; if enabled { target.set(func() { print(value) }) } }
        \\func main() { var target=Slot(); setup(target); target.invoke() }
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
