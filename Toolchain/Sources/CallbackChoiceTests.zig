const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const M = @import("Semantic/CallbackFlow/Model.zig");
const declarations =
    \\struct Registry {static var saved:(func())[]=[]}
    \\protocol Handler {func apply(callback:func())}
    \\struct First:Handler {let marker:func();func apply(callback:func()){callback()}}
    \\struct Second:Handler {let marker:func();func apply(callback:func()){callback()}}
    \\struct Keep:Handler {func apply(callback:func()){Registry.saved.append(callback)}}
    \\func ignore(){}
    \\func dispatch(handler:Handler,callback:func()){handler.apply(callback)}
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
test "callback choices preserve two safe protocol targets without introducing a third" {
    try accepted(
        \\func setup(){let value=7;let options:Handler[]=[First(marker:ignore),Second(marker:ignore)];for handler in options {dispatch(handler,func(){print(value)})}}
        \\func main(){setup()}
    );
}
test "callback choices retain a storing target in a protocol union" {
    try rejected(
        \\func setup(){let value=7;let options:Handler[]=[First(marker:ignore),Keep()];for handler in options {dispatch(handler,func(){print(value)})}}
        \\func main(){}
    );
}
test "callback choices cannot narrow an external protocol alternative" {
    try rejected(
        \\func setup(other:Handler){let value=7;let options:Handler[]=[First(marker:ignore),other];for handler in options {dispatch(handler,func(){print(value)})}}
        \\func main(){}
    );
}
test "callback choices concrete protocol tags do not prove payload equality" {
    try std.testing.expect(M.Scalar.equal(.{ .protocol = 1 }, .{ .protocol = 1 }) == null);
}
test "callback choices promoted finite tags survive their invocation arena" {
    var outer = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer outer.deinit();
    var inner = std.heap.ArenaAllocator.init(std.testing.allocator);
    const a = inner.allocator();
    const joined = try M.Value.join(.{ .scalar = .{ .variant = .{ .enumeration = 2, .variant = 1 } } }, .{ .scalar = .{ .variant = .{ .enumeration = 2, .variant = 3 } } }, a);
    const promoted = try joined.promote(a, outer.allocator());
    try std.testing.expect(promoted.scalar.choices.values.ptr != joined.scalar.choices.values.ptr);
    inner.deinit();
    try std.testing.expectEqualSlices(usize, &.{ 1, 3 }, promoted.scalar.choices.values);
    try std.testing.expectEqual(false, promoted.scalar.matches(2, 4).?);
    try std.testing.expect(promoted.scalar.matches(2, 1) == null);
}
const routed_classes =
    \\protocol Route {func apply(callback:func())}
    \\class Forward:Route {let handler:func(func());func apply(callback:func()){self.handler(callback)}}
    \\class Direct:Route {let handler:func(func());func apply(callback:func()){callback()}}
    \\func now(callback:func()){callback()}
    \\func later(callback:func()){Registry.saved.append(callback)}
    \\func route(value:Route,callback:func()){value.apply(callback)}
;
test "callback choices a protocol branch projects only its concrete payload" {
    try accepted(routed_classes ++
        \\func setup(){var choices:Route[]=[Forward(handler:now),Direct(handler:later)];let value=7;for item in choices {route(item,func(){print(value)})}}
        \\func main(){setup()}
    );
}
test "callback choices payload projection keeps the real retaining receiver" {
    try rejected(routed_classes ++
        \\func setup(){var choices:Route[]=[Forward(handler:later),Direct(handler:now)];let value=7;for item in choices {route(item,func(){print(value)})}}
        \\func main(){}
    );
}
test "callback choices an absent optional protocol cannot invoke a retaining conformer" {
    try accepted(
        \\func maybe(handler:Handler?,callback:func()){if var selected=handler {dispatch(selected,callback)}}
        \\func setup(){let value=7;maybe(null,func(){print(value)})}
        \\func main(){setup()}
    );
}
const optional_flag =
    \\class OptionalFlag {var flag:bool?=null;let marker:func()}
    \\struct LiveFlags {static var owner:OptionalFlag?=null}
    \\func enable_optional(flag:&bool?){flag=true}
    \\func clear_optional(flag:&bool?){flag=null}
;
test "callback choices an unknown optional protocol retains its unsafe alternative" {
    try rejected(
        \\func maybe(handler:Handler?,callback:func()){if var selected=handler {dispatch(selected,callback)}}
        \\func setup(handler:Handler?){let value=7;maybe(handler,func(){print(value)})}
        \\func main(){}
    );
}
test "callback choices mutable optional presence follows a scalar reference setter" {
    try rejected(optional_flag ++
        \\func setup(){var flags=OptionalFlag(marker:ignore);enable_optional(flags.flag);let value=7;if flags.flag!=null {Registry.saved.append(func(){print(value)})}}
        \\func main(){}
    );
}
test "callback choices clearing mutable optional presence keeps a synchronous scope safe" {
    try accepted(optional_flag ++
        \\func setup(){var flags=OptionalFlag(marker:ignore);flags.flag=true;clear_optional(flags.flag);let value=7;if flags.flag!=null {Registry.saved.append(func(){print(value)})}}
        \\func main(){setup()}
    );
}
test "callback choices opaque calls invalidate a mutable absent optional fact" {
    try rejected(optional_flag ++
        \\func change_flag(){if var owner=LiveFlags.owner {owner.flag=true}}
        \\func setup(notify:func()){var flags=OptionalFlag(marker:ignore);LiveFlags.owner=flags;notify();let value=7;if flags.flag!=null {Registry.saved.append(func(){print(value)})} LiveFlags.owner=null}
        \\func main(){setup(change_flag)}
    );
}
test "callback choices copying an absent optional protocol preserves absence" {
    try accepted(
        \\func maybe(handler:Handler?,callback:func()){if var selected=handler {dispatch(selected,callback)}}
        \\func setup(){var handler:Handler?=null;var copied=copy handler;let value=7;maybe(copied,func(){print(value)})}
        \\func main(){setup()}
    );
}
test "callback choices two absent CFG branches remain absent" {
    try accepted(
        \\func maybe(handler:Handler?,callback:func()){if var selected=handler {dispatch(selected,callback)}}
        \\func setup(change:bool){var handler:Handler?=null;if change {handler=null} else {handler=null} let value=7;maybe(handler,func(){print(value)})}
        \\func main(){setup(true);setup(false)}
    );
}
test "callback choices an optional join keeps a present retaining branch" {
    try rejected(
        \\func maybe(handler:Handler?,callback:func()){if var selected=handler {dispatch(selected,callback)}}
        \\func setup(change:bool){var handler:Handler?=null;if change {handler=Keep()} let value=7;maybe(handler,func(){print(value)})}
        \\func main(){}
    );
}

test "callback choices nullable reference writers remain relevant through a global target change" {
    try rejected(optional_flag ++
        \\class ScalarWriter {var writer:func(&bool?)}
        \\struct WriterRegistry {static var owner:ScalarWriter?=null}
        \\func install(){if var owner=WriterRegistry.owner {owner.writer=enable_optional}}
        \\func setup(){var flags=OptionalFlag(marker:ignore);var writer=ScalarWriter(writer:clear_optional);WriterRegistry.owner=writer;install();writer.writer(flags.flag);let value=7;if flags.flag!=null {Registry.saved.append(func(){print(value)})} WriterRegistry.owner=null}
        \\func main(){}
    );
}
test "callback choices global nullable reference target changes preserve a safe clear" {
    try accepted(optional_flag ++
        \\class ScalarWriter {var writer:func(&bool?)}
        \\struct WriterRegistry {static var owner:ScalarWriter?=null}
        \\func install(){if var owner=WriterRegistry.owner {owner.writer=clear_optional}}
        \\func setup(){var flags=OptionalFlag(marker:ignore);flags.flag=true;var writer=ScalarWriter(writer:enable_optional);WriterRegistry.owner=writer;install();writer.writer(flags.flag);let value=7;if flags.flag!=null {Registry.saved.append(func(){print(value)})} WriterRegistry.owner=null}
        \\func main(){setup()}
    );
}
test "callback choices nullable reference writers remain relevant through a scalar dispatcher" {
    try rejected(optional_flag ++
        \\func forward(writer:func(&bool?),flag:&bool?){writer(flag)}
        \\func setup(){var flags=OptionalFlag(marker:ignore);forward(enable_optional,flags.flag);let value=7;if flags.flag!=null {Registry.saved.append(func(){print(value)})}}
        \\func main(){}
    );
}
