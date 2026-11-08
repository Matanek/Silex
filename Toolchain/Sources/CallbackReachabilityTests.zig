const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const M = @import("Semantic/CallbackFlow/Model.zig");
const Flow = @import("Semantic/CallbackProvenance.zig");
const Transfer = @import("Semantic/CallbackFlow/Transfer.zig");
const declarations =
    \\struct Registry {static var saved:(func())[]=[]}
    \\class Owner {var saved:(func())[]=[]}
    \\class Number {var value:int=0}
    \\func retain(owner:Owner,callback:func()){Registry.saved.append(callback)}
;
fn accepted(comptime source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = frontend.compile(declarations ++ source) catch |err| {
        if (frontend.diagnostic) |d| std.debug.print("{s}\n", .{d.message});
        return err;
    };
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
fn rejected(comptime source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(declarations ++ source));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}
test "callback reachability excludes a call on a definitely absent tracked receiver" {
    try accepted(
        \\func maybe(owner:Owner?,callback:func()){if var present=owner {retain(present,callback)}}
        \\func setup(){let value=7;maybe(null,func(){print(value)})}
        \\func main(){setup()}
    );
}
test "callback reachability preserves a possibly present tracked receiver" {
    try rejected(
        \\func setup(owner:Owner?){let value=7;if var present=owner {retain(present,func(){print(value)})}}
        \\func main(){}
    );
}
test "callback reachability unknown class factory results remain external capabilities" {
    try rejected(
        \\func setup(factory:func() Owner){var owner=factory();let value=7;owner.saved.append(func(){print(value)})}
        \\func main(){}
    );
}
test "callback reachability does not prune a noncarrier class argument" {
    try rejected(
        \\func save(number:Number,callback:func()){Registry.saved.append(callback)}
        \\func setup(){var number=Number();let value=7;save(number,func(){print(value)})}
        \\func main(){}
    );
}
test "callback reachability preserves synchronous use beside a noncarrier class" {
    try accepted(
        \\func consume(number:Number,callback:func()){callback()}
        \\func setup(){var number=Number();let value=7;consume(number,func(){print(value)})}
        \\func main(){setup()}
    );
}
test "callback reachability distinguishes an empty function branch from an opaque target" {
    try accepted(
        \\func trigger(notify:(func())?,callback:func()){if let selected=notify {selected()} callback()}
        \\func setup(){let value=7;trigger(null,func(){print(value)})}
        \\func main(){setup()}
    );
}
test "callback reachability native function loads keep their opaque alternative" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const fs = [_]Ir.Function{.{ .name = "load", .parameter_types = &.{}, .return_type = .void, .value_types = &.{ .address, .int, .function(0) }, .blocks = &.{} }};
    const p: Ir.Program = .{ .functions = &fs, .function_types = &.{.{ .parameter_types = &.{}, .return_type = .void }} };
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = p, .capable = try M.emptyTypes(a, p), .relevant = &.{}, .borrowed = &.{}, .generators = &.{} };
    var frame: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0 };
    try e.frames.append(a, &frame);
    var state: M.State = .{ .memory = .empty };
    try Transfer.step(&e, 0, 0, 0, .{ .address_load = .{ .result = 2, .address = 0, .byte_offset = 1, .type = .function(0) } }, &state);
    try std.testing.expect(state.get(2).unknown_callable);
}
