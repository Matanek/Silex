const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const defs = "struct Registry{static var saved:(func())[]=[]} ";
fn accepted(comptime source: []const u8, expected: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var frontend = Frontend.Frontend.init(a);
    const program = frontend.compile(defs ++ source) catch |err| {
        if (frontend.diagnostic) |d| std.debug.print("{s}\n", .{d.message});
        return err;
    };
    try std.testing.expect((try @import("Semantic/CallbackProvenance.zig").checkConfigured(a, program.ir, null, .{ .confinement = false })) == null);
    const output = try Interpreter.runCapture(a, program.ir);
    try std.testing.expectEqualStrings(expected, output.stdout);
}
fn rejected(comptime source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(defs ++ source));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}
test "callback confinement mutual recursion propagates a retaining base case" {
    try rejected(
        \\func first(flag:bool,callback:func()){second(flag,callback)}
        \\func second(flag:bool,callback:func()){if flag{first(false,callback)}else{Registry.saved.append(callback)}}
        \\func setup(){let value=7;first(true,func(){print(value)})}
        \\func main(){}
    );
}
test "callback confinement mutual recursion preserves a synchronous base case" {
    try accepted(
        \\func first(flag:bool,callback:func()){second(flag,callback)}
        \\func second(flag:bool,callback:func()){if flag{first(false,callback)}else{callback()}}
        \\func setup(){let value=7;first(true,func(){print(value)})}
        \\func main(){setup()}
    , "7\n");
}
const factory =
    \\class Driver{let action:func(func());func apply(callback:func()){self.action(callback)}}
    \\func make(action:func(func())) Driver{return Driver(action:action)}
    \\enum Route{skip(Driver);run(Driver)}
    \\func now(callback:func()){callback()}
    \\func later(callback:func()){Registry.saved.append(callback)}
;
test "callback confinement factory instances keep distinct nonretaining and retaining fields" {
    try accepted(factory ++
        \\func setup(){var choices:Route[]=[Route.skip(make(later)),Route.run(make(now))];let value=7;for choice in choices{match choice{skip(driver)=>{};run(driver)=>{driver.apply(func(){print(value)})}}}}
        \\func main(){setup()}
    , "7\n");
}
test "callback confinement factory instances preserve a reachable retaining field" {
    try rejected(factory ++
        \\func setup(){var choices:Route[]=[Route.skip(make(now)),Route.run(make(later))];let value=7;for choice in choices{match choice{skip(driver)=>{};run(driver)=>{driver.apply(func(){print(value)})}}}}
        \\func main(){}
    );
}
