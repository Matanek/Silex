const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const declarations =
    \\struct Registry { static var saved:(func())[] = [] }
    \\protocol Handler { func apply(callback:func()) }
    \\func dispatch(handler:Handler, callback:func()) { handler.apply(callback) }
    \\struct Run:Handler { func apply(callback:func()) { callback() } }
    \\struct Keep:Handler { func apply(callback:func()) { Registry.saved.append(callback) } }
;
test "callback protocol known concrete conformer excludes retaining alternatives" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const source = declarations ++
        \\func setup() { let value = 7; dispatch(Run(),func() { print(value) }) }
        \\func main() { setup() }
    ;
    const compiled = frontend.compile(source) catch |err| {
        if (frontend.diagnostic) |d| std.debug.print("{s}\n", .{d.message});
        return err;
    };
    const result = try Interpreter.runCapture(arena.allocator(), compiled.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
test "callback protocol concrete retaining conformer remains rejected" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(declarations ++
        \\func setup() { let value = 7; dispatch(Keep(),func() { print(value) }) }
        \\func main() {}
    ));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}

fn rejected(comptime source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(declarations ++ source));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}

test "callback protocol unknown input keeps retaining alternatives" {
    try rejected(
        \\func setup(handler:Handler) { let value = 7; dispatch(handler,func() { print(value) }) }
        \\func main() {}
    );
}
test "callback protocol copy keeps an unknown alternative beside a known conformer" {
    try rejected(
        \\func setup(handler:Handler, change:bool) { var selected = copy handler; if change { selected = Run() } let value = 7; dispatch(selected,func() { print(value) }) }
        \\func main() {}
    );
}
test "callback protocol skipped returns stay unknown in a callable union" {
    try rejected(
        \\func run() Handler { let related = Registry.saved; return Run() }
        \\func keep() Handler { return Keep() }
        \\func setup(index:int) { let choices:(func() Handler)[] = [run,keep]; let choose = choices[index]; let value = 7; dispatch(choose(),func() { print(value) }) }
        \\func main() {}
    );
}
test "callback protocol captured local loses its concrete tag" {
    try rejected(
        \\func forward(writer:func()) { writer() }
        \\func setup() { var handler:Handler = Run(); forward(func() { handler = Keep() }); let value = 7; dispatch(handler,func() { print(value) }) }
        \\func main() {}
    );
}
test "callback protocol explicit private local replacement changes its tag" {
    try rejected(
        \\func setup(change:bool) { var handler:Handler = Run(); if change { handler = Keep() } let value = 7; dispatch(handler,func() { print(value) }) }
        \\func main() {}
    );
}

const Ir = @import("Ir.zig");
const M = @import("Semantic/CallbackFlow/Model.zig");
const Flow = @import("Semantic/CallbackProvenance.zig");
const Transfer = @import("Semantic/CallbackFlow/Transfer.zig");
fn boxedClassTag(unknown_parent: bool, mixed: bool) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const types = [_]Ir.Structure{
        .{ .name = "Handler", .fields = &.{}, .is_protocol = true },
        .{ .name = "Base", .fields = &.{}, .is_class = true },
        .{ .name = "Child", .fields = &.{}, .is_class = true, .base = 1 },
        .{ .name = "GrandChild", .fields = &.{}, .is_class = true, .base = 2 },
    };
    const functions = [_]Ir.Function{.{ .name = "box", .parameter_types = &.{}, .return_type = .void, .value_types = &.{ .structure(1), .structure(0), .bool }, .blocks = &.{} }};
    const p: Ir.Program = .{ .structures = &types, .functions = &functions };
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = p, .capable = try M.emptyTypes(a, p), .relevant = &.{}, .borrowed = &.{}, .generators = &.{} };
    var frame: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0 };
    try e.frames.append(a, &frame);
    const child = try e.node(.{ .frame = 0, .category = .object, .value = 0 }, .{ .object = .{ .type = .structure(2), .many = false, .unknown_parent = if (unknown_parent) 0 else null, .external = false } });
    var input = try M.Value.one(a, child);
    if (mixed) {
        const base = try e.object(0, .object, 1, .structure(1), false);
        input = try M.Value.join(input, try M.Value.one(a, base), a);
    }
    var state: M.State = .{ .memory = .empty };
    try state.set(a, 0, input);
    try Transfer.step(&e, 0, 0, 0, .{ .protocol_init = .{ .result = 1, .operand = 0, .structure = 1 } }, &state);
    if (unknown_parent or mixed) {
        const tags = state.get(1).scalar.choices.values;
        try std.testing.expectEqualSlices(usize, if (unknown_parent) &.{ 2, 3 } else &.{ 1, 2 }, tags);
    } else {
        try std.testing.expectEqual(@as(usize, 2), state.get(1).scalar.protocol);
    }
    try Transfer.step(&e, 0, 0, 1, .{ .protocol_test = .{ .result = 2, .operand = 1, .structure = 1 } }, &state);
    if (mixed) try std.testing.expect(state.get(2).scalar == .unknown) else try std.testing.expectEqual(false, state.get(2).scalar.boolean);
    if (unknown_parent) {
        try std.testing.expect(state.get(1).scalar.matches(null, 2) == null);
        try std.testing.expect(state.get(1).scalar.matches(null, 3) == null);
    }
}
test "callback protocol boxing a base preserves the actual derived class tag" {
    try boxedClassTag(false, false);
}
test "callback protocol boxing a copied external shape retains every possible subclass" {
    try boxedClassTag(true, false);
}
test "callback protocol boxing mixed dynamic classes keeps all alternatives" {
    try boxedClassTag(false, true);
}

test "callback protocol skipped optional returns stay unknown in a callable union" {
    try rejected(
        \\func run() Handler? { let related = Registry.saved; return Run() }
        \\func keep() Handler? { return Keep() }
        \\func setup(index:int) { let choices:(func() Handler?)[] = [run,keep]; let choose = choices[index]; var selected = choose(); let value = 7; if var handler = selected { dispatch(handler,func() { print(value) }) } }
        \\func main() {}
    );
}
test "callback protocol mutable fields stay unknown across a replacement helper" {
    try rejected(
        \\class Holder { var handler:Handler }
        \\func replace(holder:Holder) { holder.handler = Keep() }
        \\func setup() { var holder = Holder(handler:Run()); replace(holder); let value = 7; dispatch(holder.handler,func() { print(value) }) }
        \\func main() {}
    );
}

const mutable_protocol =
    \\class DispatchOwner { var handler:Handler; let marker:func() }
    \\func empty() {}
;
test "callback protocol concrete mutable class field keeps its dispatch tag" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++ mutable_protocol ++
        \\func setup() { var owner=DispatchOwner(handler:Run(),marker:empty); let value=7; dispatch(owner.handler,func() { print(value) }) }
        \\func main() { setup() }
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
test "callback protocol known mutable field replacement updates its dispatch tag" {
    try rejected(mutable_protocol ++
        \\func replace(owner:DispatchOwner) { owner.handler=Keep() }
        \\func setup() { var owner=DispatchOwner(handler:Run(),marker:empty); replace(owner); let value=7; dispatch(owner.handler,func() { print(value) }) }
        \\func main() { setup() }
    );
}
test "callback protocol opaque notification invalidates a mutable dispatch tag" {
    try rejected(mutable_protocol ++
        \\struct Exposed { static var owner:DispatchOwner?=null }
        \\func replace() { if var owner=Exposed.owner { owner.handler=Keep() } }
        \\func setup(notify:func()) { var owner=DispatchOwner(handler:Run(),marker:empty); Exposed.owner=owner; notify(); let value=7; dispatch(owner.handler,func() { print(value) }) }
        \\func main() { setup(replace) }
    );
}

test "callback protocol known collection keeps one concrete dispatch target" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const source = declarations ++
        \\struct Row:Handler { let marker:func(); func apply(callback:func()) {callback()} }
        \\func setup() {let value=7; let handlers:Handler[]=[Row(marker:func(){print(value)})]; for handler in handlers {dispatch(handler,func(){print(value)})} }
        \\func main(){setup()}
    ;
    const compiled = frontend.compile(source) catch |err| {
        if (frontend.diagnostic) |d| std.debug.print("{s}\n", .{d.message});
        return err;
    };
    const result = try Interpreter.runCapture(arena.allocator(), compiled.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

const collection_protocol =
    \\struct Row:Handler { let marker:func(); func apply(callback:func()) {callback()} }
    \\class Choices {var items:Handler[];let marker:func()}
    \\struct ExposedChoices {static var owner:Choices?=null}
    \\func no_change(){}
    \\func replace_choices(owner:Choices){owner.items=[Keep()]}
;
test "callback protocol collection replacement keeps retaining alternatives" {
    try rejected(collection_protocol ++
        \\func setup(){let value=7;var owner=Choices(items:[Row(marker:no_change)],marker:no_change);replace_choices(owner);for handler in owner.items {dispatch(handler,func(){print(value)})}}
        \\func main(){}
    );
}
test "callback protocol opaque collection replacement cannot preserve a stale tag" {
    try rejected(collection_protocol ++
        \\func setup(notify:func()){let value=7;var owner=Choices(items:[Row(marker:no_change)],marker:no_change);ExposedChoices.owner=owner;notify();for handler in owner.items {dispatch(handler,func(){print(value)})} ExposedChoices.owner=null}
        \\func replace_exposed(){if var owner=ExposedChoices.owner {replace_choices(owner)}}
        \\func main(){setup(replace_exposed)}
    );
}
test "callback protocol mixed opaque notification invalidates mutable collection tags" {
    try rejected(collection_protocol ++
        \\func setup(notify:func(),change:bool){let value=7;var owner=Choices(items:[Row(marker:no_change)],marker:no_change);ExposedChoices.owner=owner;var selected=notify;if change {selected=no_change} selected();for handler in owner.items {dispatch(handler,func(){print(value)})} ExposedChoices.owner=null}
        \\func replace_exposed(){if var owner=ExposedChoices.owner {replace_choices(owner)}}
        \\func main(){setup(replace_exposed,false)}
    );
}
