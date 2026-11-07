const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");

const box = "class Box { var callback:(func())? = null; func set(callback:func()) { self.callback = callback } func invoke() { if let callback = self.callback { callback() } } } ";

fn reject(source: []const u8, message: []const u8) !void {
    return rejectCompilation(source, message, false);
}

fn rejectCompilation(source: []const u8, message: []const u8, tests: bool) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, if (tests) frontend.compileTests(source) else frontend.compile(source));
    try std.testing.expectEqualStrings(message, frontend.diagnostic.?.message);
}

fn accept(source: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const result = try Interpreter.runCapture(arena.allocator(), (try frontend.compile(source)).ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback provenance rejects a lexical return through helper arguments" {
    try reject(
        \\func identity(callback:func()) func() { return callback }
        \\func forward(callback:func()) func() { return identity(callback) }
        \\func make() func() { let number = 7; return forward(func() { print(number) }) }
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance rejects a returned aggregate constructed by a helper" {
    try reject(
        \\class Holder { let callback:func() }
        \\func wrap(callback:func()) Holder { return Holder(callback:callback) }
        \\func make() Holder { let number = 7; return wrap(func() { print(number) }) }
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance rejects retention in an external receiver through helpers" {
    try reject(box ++
        \\func store(box:Box, callback:func()) { box.set(callback) }
        \\func setup(box:Box) { let number = 7; store(box, func() { print(number) }) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves synchronous helpers local storage and owned methods" {
    try accept(box ++
        \\func identity(callback:func()) func() { return callback }
        \\func invoke(callback:func()) { callback() }
        \\func store(box:Box, callback:func()) { box.set(callback) }
        \\class Counter { var count:int = 0; func increment() { self.count++ } }
        \\func setup(box:Box) { var counter = Counter(); store(box, counter.increment) }
        \\func main() {
        \\    var count = 0
        \\    let callback = identity(func() { count++ })
        \\    invoke(callback)
        \\    var box = Box()
        \\    var alias = box
        \\    store(alias, callback)
        \\    box.invoke()
        \\    assert(count == 2)
        \\    setup(box)
        \\    box.invoke()
        \\}
    );
}

test "callback provenance separates independent fields returned by helpers" {
    try accept(
        \\class Pair { let first:func(); let second:func() }
        \\func empty() {}
        \\func select(first:func(), second:func()) func() {
        \\    var pair = Pair(first:first, second:second)
        \\    return pair.second
        \\}
        \\func make() func() { let number = 7; return select(func() { print(number) }, empty) }
        \\func main() { let callback = make(); callback() }
    );
}

test "callback provenance respects replacement before a return" {
    try accept(
        \\func empty() {}
        \\func identity(callback:func()) func() { return callback }
        \\func make() func() {
        \\    let number = 7
        \\    var callback = identity(func() { print(number) })
        \\    callback = empty
        \\    return callback
        \\}
        \\func main() { let callback = make(); callback() }
    );
}

test "callback provenance detects a local object escaping after helper storage" {
    try reject(box ++
        \\func store(box:Box, callback:func()) { box.set(callback) }
        \\func make() Box { let number = 7; var box = Box(); store(box, func() { print(number) }); return box }
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance follows fields mutated by a helper before returning them" {
    try reject(box ++
        \\func read(box:Box) (func())? { return box.callback }
        \\func make() (func())? {
        \\    let number = 7
        \\    var box = Box()
        \\    box.set(func() { print(number) })
        \\    return read(box)
        \\}
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance follows known indirect retention calls" {
    try reject(box ++
        \\func store(box:Box, callback:func()) { box.set(callback) }
        \\func setup(box:Box) { let number = 7; let write:func(Box,func()) = store; write(box,func() { print(number) }) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance reaches a fixed point through recursive helpers" {
    try reject(
        \\func first(callback:func(), depth:int) func() { if depth == 0 { return callback } return second(callback,depth - 1) }
        \\func second(callback:func(), depth:int) func() { return first(callback,depth) }
        \\func make() func() { let number = 7; return second(func() { print(number) },2) }
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance preserves independent fields after helper mutation" {
    try accept(
        \\class Pair {
        \\    var first:func()
        \\    let second:func()
        \\    func set(callback:func()) { self.first = callback }
        \\}
        \\func empty() {}
        \\func read(pair:Pair) func() { return pair.second }
        \\func make() func() {
        \\    let number = 7
        \\    var pair = Pair(first:empty, second:empty)
        \\    pair.set(func() { print(number) })
        \\    return read(pair)
        \\}
        \\func main() { let callback = make(); callback() }
    );
}

test "callback provenance respects field replacement through helpers" {
    try accept(box ++
        \\func empty() {}
        \\func make() Box {
        \\    let number = 7
        \\    var box = Box()
        \\    box.set(func() { print(number) })
        \\    box.set(empty)
        \\    return box
        \\}
        \\func main() { var box = make(); box.invoke() }
    );
}

test "callback provenance preserves scalar results from callbacks with captures" {
    try accept(
        \\func invoke(callback:func() int) int { return callback() }
        \\func make() int { let number = 7; return invoke(func() int { return number }) }
        \\func main() { assert(make() == 7) }
    );
}

test "callback provenance keeps a possible retained value across a conditional overwrite" {
    try reject(box ++
        \\func empty() {}
        \\func maybe(box:Box, callback:func(), enabled:bool) { if enabled { box.set(callback) } }
        \\func make(enabled:bool) Box {
        \\    let number = 7
        \\    var box = Box()
        \\    box.set(func() { print(number) })
        \\    maybe(box,empty,enabled)
        \\    return box
        \\}
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance joins both sides of conditional field writes" {
    try reject(box ++
        \\func empty() {}
        \\func make(enabled:bool) Box {
        \\    let number = 7
        \\    var box = Box()
        \\    if enabled { box.set(func() { print(number) }) } else { box.set(empty) }
        \\    return box
        \\}
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance allows a synchronous temporary external field with cleanup" {
    try accept(box ++
        \\func empty() {}
        \\func setup(box:Box) { var count = 0; box.set(func() { count++ }); box.invoke(); box.set(empty); assert(count == 1) }
        \\func main() { var box = Box(); setup(box); box.invoke() }
    );
}

test "callback provenance follows retention through a callable parameter" {
    try reject(box ++
        \\func store(box:Box, callback:func()) { box.set(callback) }
        \\func dispatch(writer:func(Box,func()), box:Box, callback:func()) { writer(box,callback) }
        \\func setup(box:Box) { let number = 7; dispatch(store,box,func() { print(number) }) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves synchronous calls through a callable parameter" {
    try accept(
        \\func run(callback:func()) { callback() }
        \\func dispatch(runner:func(func()), callback:func()) { runner(callback) }
        \\func main() { var count = 0; dispatch(run,func() { count++ }); assert(count == 1) }
    );
}

test "callback provenance rejects storage past an inner lexical block" {
    try reject(box ++
        \\func store(box:Box, callback:func()) { box.set(callback) }
        \\func main() { var box = Box(); { let value = 7; store(box,func() { print(value) }) } box.invoke() }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance rejects appending to an external collection" {
    try reject(
        \\func append(values:&(func())[], callback:func()) { values.append(callback) }
        \\func setup(values:&(func())[]) { let value = 7; append(values,func() { print(value) }) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance separates synchronous and retaining uses of one dispatcher" {
    try accept(box ++
        \\func empty() {}
        \\func store(box:Box, callback:func()) { box.set(callback) }
        \\func run(box:Box, callback:func()) { callback() }
        \\func dispatch(writer:func(Box,func()), box:Box, callback:func()) { writer(box,callback) }
        \\func main() { var box = Box(); dispatch(store,box,empty); var count = 0; dispatch(run,box,func() { count++ }); assert(count == 1) }
    );
}

test "callback provenance follows retention by a passed closure environment" {
    try reject(box ++
        \\func dispatch(writer:func(func()), callback:func()) { writer(callback) }
        \\func setup(box:Box) { let value = 7; dispatch(func(callback:func()) { box.set(callback) }, func() { print(value) }) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance follows projected aliases into an external object" {
    try reject(box ++
        \\class Outer { var inner:Box }
        \\func setup(outer:Outer) { let value = 7; var alias = outer.inner; alias.set(func() { print(value) }) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves cleanup through a projected alias" {
    try accept(box ++
        \\class Outer { var inner:Box }
        \\func empty() {}
        \\func setup(outer:Outer) { var count = 0; var alias = outer.inner; alias.set(func() { count++ }); alias.invoke(); alias.set(empty); assert(count == 1) }
        \\func main() { var outer = Outer(inner:Box()); setup(outer) }
    );
}

test "callback provenance follows mutable references to callback fields" {
    try reject(box ++
        \\func put(slot:&(func())?, callback:func()) { slot = callback }
        \\func setup(box:&Box) { let value = 7; put(box.callback,func() { print(value) }) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance allows clearing an external callback collection" {
    try accept(
        \\func append(values:&(func())[], callback:func()) { values.append(callback) }
        \\func setup(values:&(func())[]) { var count = 0; append(values,func() { count++ }); { let invoke = values[0]; invoke() } values.clear(); assert(count == 1) }
        \\func main() { var values:(func())[] = []; setup(values); assert(values.count() == 0) }
    );
}

test "callback provenance preserves independent callback collection elements" {
    try accept(
        \\func empty() {}
        \\func select(first:func(), second:func()) func() { let values:(func())[] = [first,second]; return values[1] }
        \\func make() func() { let value = 7; return select(func() { print(value) },empty) }
        \\func main() { let callback = make(); callback() }
    );
}

test "callback provenance resolves returned callable environments" {
    try reject(box ++
        \\func writer(box:Box) func(func()) { return box.set }
        \\func dispatch(write:func(func()), callback:func()) { write(callback) }
        \\func setup(box:Box) { let value = 7; dispatch(writer(box),func() { print(value) }) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves returned owned synchronous methods" {
    try accept(
        \\class Runner { func run(callback:func()) { callback() } }
        \\func runner() func(func()) { var value = Runner(); return value.run }
        \\func main() { var count = 0; let run = runner(); run(func() { count++ }); assert(count == 1) }
    );
}

test "callback provenance resolves recursive retaining callables" {
    try reject(box ++
        \\func store(box:Box, callback:func()) { box.set(callback) }
        \\func dispatch(writer:func(Box,func()), box:Box, callback:func(), depth:int) { if depth == 0 { writer(box,callback) } else { dispatch(writer,box,callback,depth - 1) } }
        \\func setup(box:Box) { let value = 7; dispatch(store,box,func() { print(value) },2) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves recursive synchronous callables" {
    try accept(
        \\func run(callback:func()) { callback() }
        \\func dispatch(runner:func(func()), callback:func(), depth:int) { if depth == 0 { runner(callback) } else { dispatch(runner,callback,depth - 1) } }
        \\func main() { var count = 0; dispatch(run,func() { count++ },2); assert(count == 1) }
    );
}

test "callback provenance preserves a capture whose binding outlives an inner block" {
    try accept(box ++
        \\func empty() {}
        \\func identity(callback:func()) func() { return callback }
        \\func main() { var count = 0; var box = Box(); { box.set(identity(func() { count++ })) } box.invoke(); box.set(empty); assert(count == 1) }
    );
}

test "callback provenance includes retaining finalizers" {
    try reject(box ++
        \\class Holder { var target:Box; var callback:func(); drop { self.target.set(self.callback) } }
        \\func identity(callback:func()) func() { return callback }
        \\func setup(target:Box) { let value = 7; var holder = Holder(target:target,callback:identity(func() { print(value) })) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves cleanup before retaining finalizers" {
    try accept(box ++
        \\class Holder { var target:Box; var callback:func(); drop { self.target.set(self.callback) } }
        \\func empty() {}
        \\func identity(callback:func()) func() { return callback }
        \\func setup(target:Box) { let value = 7; var holder = Holder(target:target,callback:identity(func() { print(value) })); holder.callback = empty }
        \\func main() { var target = Box(); setup(target); target.invoke() }
    );
}

test "callback provenance does not finalize a receiver still owned by its caller" {
    try accept(box ++
        \\class Holder { var target:Box; var callback:func(); func invoke() { self.callback() } drop { self.target.set(self.callback) } }
        \\func empty() {}
        \\func identity(callback:func()) func() { return callback }
        \\func invoke(holder:Holder) { holder.invoke() }
        \\func setup(target:Box) { var value = 0; var holder = Holder(target:target,callback:identity(func() { value++ })); invoke(holder); holder.callback = empty; assert(value == 1) }
        \\func main() { var target = Box(); setup(target); target.invoke() }
    );
}

test "callback provenance includes finalizers of an unreachable cycle" {
    try reject(box ++
        \\class Holder { var target:Box; var next:Holder? = null; var callback:func(); drop { self.target.set(self.callback) } }
        \\func identity(callback:func()) func() { return callback }
        \\func setup(target:Box) { let value = 7; var holder = Holder(target:target,callback:identity(func() { print(value) })); holder.next = holder }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves a finalizer delayed by an owning field" {
    try accept(box ++
        \\class Holder { var target:Box; var callback:func(); drop { self.target.set(self.callback) } }
        \\class Owner { var holder:Holder }
        \\func empty() {}
        \\func identity(callback:func()) func() { return callback }
        \\func invoke(holder:Holder) { holder.callback() }
        \\func main() { var target = Box(); var value = 0; var owner = Owner(holder:Holder(target:target,callback:identity(func() { value++ }))); invoke(owner.holder); owner.holder.callback = empty; assert(value == 1) }
    );
}

test "callback provenance includes finalizers reached through owned bound methods" {
    try reject(box ++
        \\class Holder { var target:Box; var callback:func(); func invoke() { self.callback() } drop { self.target.set(self.callback) } }
        \\func identity(callback:func()) func() { return callback }
        \\func setup(target:Box) { let value = 7; let callback = Holder(target:target,callback:identity(func() { print(value) })).invoke; callback() }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance considers aliasing external parameters" {
    try reject(box ++
        \\func identity(callback:func()) func() { return callback }
        \\func make(first:Box, second:Box) (func())? { let value = 7; first.set(identity(func() { print(value) })); let saved = second.callback; first.callback = null; return saved }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance considers aliases discovered through later projections" {
    try reject(box ++
        \\class Outer { var box:Box }
        \\func identity(callback:func()) func() { return callback }
        \\func make(first:Box, second:Outer) (func())? { let value = 7; first.set(identity(func() { print(value) })); let saved = second.box.callback; first.callback = null; return saved }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance resolves a borrowed callback created inside a higher order helper" {
    try reject(box ++
        \\class Writer { var box:Box; func write(callback:func()) { self.box.set(callback) } }
        \\func identity(callback:func()) func() { return callback }
        \\func setup(runner:func(func())) { let value = 7; runner(identity(func() { print(value) })) }
        \\func main() { var box = Box(); var writer = Writer(box:box); setup(writer.write) }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves a synchronous factory inside a higher order helper" {
    try accept(
        \\func run(callback:func()) { callback() }
        \\func identity(callback:func()) func() { return callback }
        \\func setup(runner:func(func())) { var value = 0; runner(identity(func() { value++ })); assert(value == 1) }
        \\func main() { setup(run) }
    );
}

test "callback provenance checks higher order retention from a test entry" {
    try rejectCompilation(box ++
        \\class Writer { var box:Box; func write(callback:func()) { self.box.set(callback) } }
        \\func identity(callback:func()) func() { return callback }
        \\func setup(runner:func(func())) { let value = 7; runner(identity(func() { print(value) })) }
        \\test "retaining entry" { var box = Box(); var writer = Writer(box:box); setup(writer.write) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope", true);
}

test "callback provenance preserves loans in a deep copy after a helper returns" {
    try reject(
        \\class Holder { var callback:func(); func invoke() { self.callback() } }
        \\func identity(callback:func()) func() { return callback }
        \\func invoke(holder:Holder) { holder.invoke() }
        \\func make() Holder { let value = 7; var holder = Holder(callback:identity(func() { print(value) })); var detached = copy holder; invoke(detached); return detached }
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance preserves the initial owner of a deep copy" {
    try accept(
        \\func empty() {}
        \\class Holder { static var drops:int = 0; var callback:func() = empty; func invoke() { self.callback() } drop { Holder.drops++ } }
        \\func invoke(holder:Holder) { holder.invoke() }
        \\func main() { var original = Holder(); var detached = copy original; invoke(detached); assert(Holder.drops == 0); detached.invoke() }
    );
}

test "callback provenance keeps copied value fields distinct through mutable projections" {
    try reject(
        \\struct Payload { var callback:func() }
        \\class Pair { var first:Payload; var second:Payload }
        \\func empty() {}
        \\func identity(callback:func()) func() { return callback }
        \\func clear(callback:&func()) { callback = empty }
        \\func make() func() { let value = 7; let payload = Payload(callback:identity(func() { print(value) })); var pair = copy Pair(first:payload,second:payload); clear(pair.first.callback); return pair.second.callback }
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance preserves possible loans through recursively copied value fields" {
    try reject(box ++
        \\struct Payload { var callback:func() }
        \\class Holder { var payload:Payload }
        \\func empty() {}
        \\func identity(callback:func()) func() { return callback }
        \\func clear(callback:&func()) { callback = empty }
        \\func detach(holder:Holder, depth:int) Holder { var result = copy holder; if depth > 0 { var other = detach(result,depth - 1); clear(other.payload.callback) } return result }
        \\func setup(target:Box) { let value = 7; var holder = Holder(payload:Payload(callback:identity(func() { print(value) }))); var detached = detach(holder,2); target.set(detached.payload.callback) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance terminates on recursive copies without lexical loans" {
    try accept(
        \\struct Payload { var callback:func() }
        \\class Holder { var payload:Payload }
        \\func empty() {}
        \\func clear(callback:&func()) { callback = empty }
        \\func detach(holder:Holder, depth:int) Holder { var result = copy holder; if depth > 0 { var other = detach(result,depth - 1); clear(other.payload.callback) } return result }
        \\func main() { var original = Holder(payload:Payload(callback:empty)); var detached = detach(original,2); detached.payload.callback() }
    );
}

test "callback provenance includes callback fields behind a protocol conformer" {
    try reject(box ++
        \\protocol Store { func store(callback:func()) }
        \\class Writer:Store { var box:Box; func store(callback:func()) { self.box.set(callback) } }
        \\func identity(callback:func()) func() { return callback }
        \\func setup(writer:Store) { let value = 7; writer.store(identity(func() { print(value) })) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance resolves global callable state when a finalizer creates the loan" {
    try reject(
        \\struct Registry { static var saved:(func())[] = []; static var writers:(func(func()))[] = [save] }
        \\func save(callback:func()) { Registry.saved.append(callback) }
        \\func identity(callback:func()) func() { return callback }
        \\class Plain { drop { let value = 7; { let writer = Registry.writers[0]; writer(identity(func() { print(value) })) } } }
        \\func main() { var plain = Plain() }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves a synchronous global callable used by a finalizer" {
    try accept(
        \\struct Registry { static var writers:(func(func()))[] = [run] }
        \\func run(callback:func()) { callback() }
        \\func identity(callback:func()) func() { return callback }
        \\class Plain { drop { var value = 0; { let writer = Registry.writers[0]; writer(identity(func() { value++ })) } assert(value == 1) } }
        \\func main() { var plain = Plain() }
    );
}

test "callback provenance preserves distinct signatures in collections and generic specializations" {
    try accept(
        \\func empty() {}
        \\func run(callback:func()) { callback() }
        \\func wrap<T>(value:T) T[] { return [value] }
        \\class Holder<T> { var value:T }
        \\func main() { let callbacks:(func())[] = [empty]; let runners:(func(func()))[] = [run]; let generic_callbacks = wrap(empty); let generic_runners = wrap(run); var one = Holder<func()>(value:empty); var two = Holder<func(func())>(value:run); let callback = callbacks[0]; let runner = runners[0]; runner(callback); let generic_callback = generic_callbacks[0]; let generic_runner = generic_runners[0]; generic_runner(generic_callback); two.value(one.value) }
    );
}

test "callback provenance preserves parameter modes in callable collection identities" {
    try accept(
        \\func read(value:@int) { assert(value == 1) }
        \\func write(value:&int) { value++ }
        \\func main() { let readers:(func(@int))[] = [read]; let writers:(func(&int))[] = [write]; var value = 0; let writer = writers[0]; writer(value); let reader = readers[0]; reader(value) }
    );
}

test "callback provenance distinguishes repeated helper allocations before separate clears" {
    try reject(
        "class Slot { var callback:(func())? = null; func set(callback:func()) { self.callback = callback } func clear() { self.callback = null } } " ++
            "func make() Slot { return Slot() } " ++
            "func main() { var slots:Slot[] = []; for index in 0...2 { slots.append(make()) } var first = slots[0]; var second = slots[1]; " ++
            "{ let value = 7; first.set(func() { print(value) }); second.clear() } }",
        "capturing function value cannot be stored beyond its lexical scope",
    );
}

test "callback provenance preserves synchronous calls through repeated helper allocations" {
    try accept(
        box ++
            "func make() Box { return Box() } " ++
            "func call(slot:Box, callback:func()) { slot.set(callback); slot.invoke(); slot.set(empty) } func empty() {} " ++
            "func main() { var count = 0; for index in 0...3 { var slot = make(); call(slot,func() { count++ }) } assert(count == 3) }",
    );
}

test "callback provenance resolves opaque factories returning a retained object" {
    try reject(box ++
        \\struct Registry { static var slots:Box[] = [] }
        \\func make() Box { var slot = Box(); Registry.slots.append(slot); return slot }
        \\func setup(factory:func() Box) { var slot = factory(); let value = 7; slot.set(func() { print(value) }) }
        \\func main() { setup(make) }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance resolves an object remembered before the loan exists" {
    try reject(box ++
        \\struct Registry { static var slots:Box[] = [] }
        \\func remember(slot:Box) { Registry.slots.append(slot) }
        \\func setup(writer:func(Box)) { var slot = Box(); writer(slot); let value = 7; slot.set(func() { print(value) }) }
        \\func main() { setup(remember) }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance resolves zero argument mutation of a known global writer before a loan" {
    try reject(
        \\struct Registry { static var writers:(func(func()))[] = []; static var saved:(func())[] = [] }
        \\func run(callback:func()) { callback() }
        \\func save(callback:func()) { Registry.saved.append(callback) }
        \\func change() { Registry.writers.clear(); Registry.writers.append(save) }
        \\func setup(change:func()) { Registry.writers.clear(); Registry.writers.append(run); change(); let value = 7; let writer = Registry.writers[0]; writer(func() { print(value) }) }
        \\func main() { setup(change) }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance resolves opaque retention that delays a clearing finalizer" {
    try reject(
        \\struct Registry { static var guards:Guard[] = []; static var held:Guard[] = []; static var saved:(func())[] = [] }
        \\class Guard { drop { Registry.saved.clear() } }
        \\func hold() { Registry.held.append(Registry.guards[0]) }
        \\func setup(notify:func()) { let value = 7; { var guard = Guard(); Registry.guards.append(guard); notify(); Registry.saved.append(func() { print(value) }); Registry.guards.clear() } }
        \\func main() { setup(hold) }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance permits opaque notifications after a synchronous loan ends" {
    try accept(
        \\func empty() {}
        \\func setup(notify:func()) { var value = 0; { let callback = func() { value++ }; callback() } notify(); assert(value == 1) }
        \\func main() { setup(empty) }
    );
}

test "callback provenance preserves repeated identity through nested loop branches" {
    try reject(
        box ++
            "func make() Box { return Box() } func empty() {} " ++
            "func main() { var slots:Box[] = []; for index in 0...2 { if index >= 0 { { var temporary:Box[] = [] } if index >= 0 { slots.append(make()) } } } " ++
            "var first = slots[0]; var second = slots[1]; { let value = 7; first.set(func() { print(value) }); second.set(empty) } }",
        "capturing function value cannot be stored beyond its lexical scope",
    );
}

test "callback provenance follows a loan through an owned callback with another signature" {
    try reject(
        \\class Slot { var callback:func(int) int }
        \\class Owner { var slot:Slot; func run() {} }
        \\func make() func() { let value = 7; var owner = Owner(slot:Slot(callback:func(index:int) int { return value + index })); return owner.run }
        \\func main() {}
    , "capturing function value cannot be returned from its lexical scope");
}

test "callback provenance keeps callable effects behind a different signature collection" {
    try reject(
        \\struct Registry { static var saved:(func(int) int)[] = []; static var writers:(func(func(int) int))[] = [save] }
        \\func save(callback:func(int) int) { Registry.saved.append(callback) }
        \\func setup() { let value = 7; let writer = Registry.writers[0]; writer(func(index:int) int { return value + index }) }
        \\func main() { setup() }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance keeps zero argument effects that change another callback signature" {
    try reject(
        \\struct Registry { static var writers:(func(func(int) int))[] = []; static var saved:(func(int) int)[] = [] }
        \\func run(callback:func(int) int) { let value = callback(1) }
        \\func save(callback:func(int) int) { Registry.saved.append(callback) }
        \\func change() { Registry.writers.clear(); Registry.writers.append(save) }
        \\func setup(notify:func()) { Registry.writers.clear(); Registry.writers.append(run); notify(); let value = 7; let writer = Registry.writers[0]; writer(func(index:int) int { return value + index }) }
        \\func main() { setup(change) }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves cleanup before storing another owned callback signature" {
    try accept(
        \\struct Registry { static var saved:(func())[] = [] }
        \\func empty(value:int) int { return value }
        \\class Slot { var callback:func(int) int }
        \\class Owner { var slot:Slot; func run() {} }
        \\func setup() { let value = 7; var owner = Owner(slot:Slot(callback:func(index:int) int { return value + index })); owner.slot.callback = empty; Registry.saved.append(owner.run) }
        \\func main() { setup(); let run = Registry.saved[0]; run() }
    );
}

test "callback provenance keeps connections through external protocol storage before a loan" {
    try reject(
        \\protocol Readable { func read() (func())? }
        \\class Slot:Readable { var callback:(func())? = null; func set(callback:func()) { self.callback = callback } func clear() { self.callback = null } func read() (func())? { return self.callback } }
        \\class Outer { var slot:Readable? = null }
        \\func link(outer:Outer, slot:Slot) { outer.slot = slot }
        \\func extract(outer:Outer, sink:Slot) { if var slot = outer.slot { if let callback = slot.read() { sink.set(callback) } } }
        \\func setup(slot:Slot, outer:Outer, sink:Slot) { link(outer,slot); let value = 7; slot.set(func() { print(value) }); extract(outer,sink); slot.clear() }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance keeps void projected calls when another external alias contains a loan" {
    try reject(box ++
        \\class Outer { var slot:Box }
        \\func invoke_alias(outer:Outer) { outer.slot.invoke() }
        \\func setup(first:Box, other:Outer, sink:Box) {
        \\    var callback:(func())? = null
        \\    callback = func() { if let retained = callback { sink.set(retained) } }
        \\    if let ready = callback { first.set(ready) }
        \\    invoke_alias(other)
        \\    first.callback = null
        \\    callback = null
        \\}
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance closes global effects through an indirect zero argument call" {
    try reject(
        \\struct Registry { static var writers:(func(func(int) int))[] = []; static var saved:(func(int) int)[] = [] }
        \\func run(callback:func(int) int) { let value = callback(1) }
        \\func save(callback:func(int) int) { Registry.saved.append(callback) }
        \\func change() { Registry.writers.clear(); Registry.writers.append(save) }
        \\func trampoline() { let action:func() = change; action() }
        \\func setup(notify:func()) { Registry.writers.clear(); Registry.writers.append(run); notify(); let value = 7; let writer = Registry.writers[0]; writer(func(index:int) int { return value + index }) }
        \\func main() { setup(trampoline) }
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance follows a returned mutable reference without loading its value" {
    try reject(box ++
        \\func borrow_slot(slot:&Box) &Box { return slot }
        \\func identity(callback:func()) func() { return callback }
        \\func setup(target:&Box) { let value = 7; var slot = borrow_slot(target); slot.set(identity(func() { print(value) })) }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves unknown boolean branches after a conditional external write" {
    try reject(
        \\class Box { var enabled:bool = true; var callback:(func())? = null }
        \\func setup(target:Box, change:bool) { if change { target.enabled = false } let value = 7; if target.enabled { target.callback = func() { print(value) } } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance observes boolean writes through a scalar reference helper" {
    try reject(box ++
        \\func enable(flag:&bool) { flag = true }
        \\func setup(target:Box) { var flag = false; enable(flag); let value = 7; if flag { target.set(func() { print(value) }) } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance observes scalar writes through a returned reference" {
    try reject(box ++
        \\func forward(flag:&bool) &bool { return flag }
        \\func setup(target:Box) { var flag = false; { var alias = forward(flag); alias = true } let value = 7; if flag { target.set(func() { print(value) }) } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance widens divergent boolean assignments" {
    try reject(box ++
        \\func setup(target:Box, change:bool) { var flag = false; if change { flag = true } let value = 7; if flag { target.set(func() { print(value) }) } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves an unknown boolean returned by an unrelated helper" {
    try reject(box ++
        \\func choose() bool { return true }
        \\func setup(target:Box) { let flag = choose(); let value = 7; if flag { target.set(func() { print(value) }) } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance can exclude a known false local branch" {
    try accept(box ++
        \\func setup(target:Box) { var flag = false; let value = 7; if flag { target.set(func() { print(value) }) } }
        \\func main() { var target = Box(); setup(target); target.invoke() }
    );
}

test "callback provenance can distinguish unit enumeration variants" {
    try accept(box ++
        \\enum Mode { draw; record }
        \\func setup(target:Box) { let mode = Mode.draw; let value = 7; if mode == Mode.record { target.set(func() { print(value) }) } }
        \\func main() { var target = Box(); setup(target); target.invoke() }
    );
}

test "callback provenance widens divergent enumeration variants" {
    try reject(box ++
        \\enum Mode { draw; record }
        \\func setup(target:Box, change:bool) { var mode = Mode.draw; if change { mode = Mode.record } let value = 7; if mode == Mode.record { target.set(func() { print(value) }) } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves unknown global booleans after a conditional write" {
    try reject(box ++
        \\struct Registry { static var enabled:bool = true }
        \\func setup(target:Box, change:bool) { if change { Registry.enabled = false } let value = 7; if Registry.enabled { target.set(func() { print(value) }) } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance invalidates known control facts across an opaque callback" {
    try reject(
        \\class Box { var enabled:bool = false; var callback:(func())? = null }
        \\struct Registry { static var box:Box? = null }
        \\func setup(notify:func(), target:Box) { var state = Box(); Registry.box = state; notify(); let value = 7; if state.enabled { target.callback = func() { print(value) } } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance follows unit enumeration writes through scalar references" {
    try reject(box ++
        \\enum Mode { draw; record }
        \\func enable(mode:&Mode) { mode = Mode.record }
        \\func setup(target:Box) { var mode = Mode.draw; enable(mode); let value = 7; if mode == Mode.record { target.set(func() { print(value) }) } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance preserves unknown unit variants after an external conditional write" {
    try reject(
        \\enum Mode { draw; record }
        \\class Box { var mode:Mode = Mode.record; var callback:(func())? = null }
        \\func setup(target:Box, change:bool) { if change { target.mode = Mode.draw } let value = 7; if target.mode == Mode.record { target.callback = func() { print(value) } } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}

test "callback provenance keeps an unknown payload enumeration beside a known unit variant" {
    try reject(box ++
        \\enum Mode { draw; record(func()) }
        \\func setup(mode:Mode, target:Box, change:bool) { var selected = mode; if change { selected = Mode.draw } let value = 7; if selected != Mode.draw { target.set(func() { print(value) }) } }
        \\func main() {}
    , "capturing function value cannot be stored beyond its lexical scope");
}
