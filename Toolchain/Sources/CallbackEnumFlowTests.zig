const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Proof = @import("Semantic/CallbackProvenance.zig");
const defs = "class Box {var callback:(func())?=null;func set(callback:func()){self.callback=callback}} enum Mode {draw(int);record(int)} ";
fn accept(comptime code: []const u8, expected: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var f = Frontend.Frontend.init(arena.allocator());
    const p = f.compile(defs ++ code) catch |err| {
        if (f.diagnostic) |d| std.debug.print("{s}\n", .{d.message});
        return err;
    };
    try std.testing.expect((try Proof.checkConfigured(arena.allocator(), p.ir, null, .{ .prune_dead_values = false, .index_frames = false, .sparse_controls = false })) == null);
    try std.testing.expect((try Proof.checkConfigured(arena.allocator(), p.ir, null, .{ .payload_tags = false })) != null);
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqualStrings(expected, result.stdout);
}
fn reject(comptime code: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var f = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, f.compile(defs ++ code));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", f.diagnostic.?.message);
}
test "callback payload tags exclude a known impossible retaining match" {
    try accept(
        \\func setup(target:Box){let mode=Mode.draw(4);let value=7;match mode {draw(count)=>{print(count)};record(count)=>{target.set(func(){print(value)})}}}
        \\func main(){var target=Box();setup(target)}
    , "4\n");
}
test "callback payload tags never prove equal associated values" {
    try reject(
        \\func setup(target:Box){let first=Mode.draw(1);let second=Mode.draw(2);let value=7;if first!=second {target.set(func(){print(value)})}}
        \\func main(){}
    );
}
test "callback payload tags keep a possible retaining match after a join" {
    try reject(
        \\func setup(target:Box,change:bool){var mode=Mode.draw(4);if change {mode=Mode.record(5)} let value=7;match mode {draw(count)=>{print(count)};record(count)=>{target.set(func(){print(value)})}}}
        \\func main(){}
    );
}
test "callback payload tags preserve construction through a copy" {
    try accept(
        \\func setup(target:Box){let original=Mode.draw(4);let mode=copy original;let value=7;match mode {draw(count)=>{print(count)};record(count)=>{target.set(func(){print(value)})}}}
        \\func main(){var target=Box();setup(target)}
    , "4\n");
}

const routed =
    \\struct Registry {static var saved:(func())[]=[]}
    \\class Driver {let action:func(func());func apply(callback:func()){self.action(callback)}}
    \\enum Route {skip(Driver);run(Driver)}
    \\func now(callback:func()){callback()}
    \\func later(callback:func()){Registry.saved.append(callback)}
;
test "callback payload tags correlate a safe payload with its selected variant" {
    try accept(routed ++
        \\func setup(){var choices:Route[]=[Route.skip(Driver(action:later)),Route.run(Driver(action:now))];let value=7;for choice in choices {match choice {skip(driver)=>{};run(driver)=>{driver.apply(func(){print(value)})}}}}
        \\func main(){setup()}
    , "7\n");
}
test "callback payload tags retain a storing payload on the selected variant" {
    try reject(routed ++
        \\func setup(){var choices:Route[]=[Route.skip(Driver(action:now)),Route.run(Driver(action:later))];let value=7;for choice in choices {match choice {skip(driver)=>{};run(driver)=>{driver.apply(func(){print(value)})}}}}
        \\func main(){}
    );
}
