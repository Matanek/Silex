const std = @import("std");
const Frontend = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const declarations =
    \\struct Registry { static var saved:(func())[] = [] }
    \\protocol Handler { func apply(callback:func()) }
    \\func dispatch(handler:Handler, callback:func()) { handler.apply(callback) }
    \\struct Run:Handler { func apply(callback:func()) { callback() } }
    \\struct Keep:Handler { func apply(callback:func()) { Registry.saved.append(callback) } }
    \\class Branch:Handler { let marker:func(); func apply(callback:func()) { dispatch(Run(),callback) } }
    \\class Choice:Handler { let marker:func(); let enabled:bool; func apply(callback:func()) { if self.enabled { dispatch(Run(),callback) } else { dispatch(Keep(),callback) } } }
    \\func empty() {}
;
test "callback contexts known leaf remains synchronous" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = frontend.compile(declarations ++
        \\func setup() { var branch=Branch(marker:empty); let value=7; dispatch(branch,func() { print(value) }) }
        \\func main() { setup() }
    ) catch |err| {
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
test "callback contexts actual retaining leaf remains rejected" {
    try rejected(
        \\func setup() { var branch=Choice(marker:empty,enabled:false); let value=7; dispatch(branch,func() { print(value) }) }
        \\func main() {}
    );
}
test "callback contexts unknown leaf keeps retaining alternatives" {
    try rejected(
        \\func setup(enabled:bool) { var branch=Choice(marker:empty,enabled:enabled); let value=7; dispatch(branch,func() { print(value) }) }
        \\func main() {}
    );
}

test "callback contexts finite mutual protocol contexts terminate during compilation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(declarations ++
        \\struct First:Handler { func apply(callback:func()) { dispatch(Second(),callback) } }
        \\struct Second:Handler { func apply(callback:func()) { dispatch(First(),callback) } }
        \\func setup() { let value = 7; dispatch(First(),func() { print(value) }) }
        \\func main() {}
    );
}
test "callback contexts scalar contexts preserve the synchronous base case" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\func route(enabled:bool, callback:func()) { if enabled { route(false,callback) } else { callback() } }
        \\func setup() { let value = 7; route(true,func() { print(value) }) }
        \\func main() { setup() }
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
test "callback contexts scalar contexts keep a retaining base case" {
    try rejected(
        \\func route(enabled:bool, callback:func()) { if enabled { route(false,callback) } else { Registry.saved.append(callback) } }
        \\func setup() { let value = 7; route(true,func() { print(value) }) }
        \\func main() {}
    );
}

const tree =
    \\enum Mode {branch;leaf;retain}
    \\class Tree {let mode:Mode;let marker:func();func visit(callback:func()){if self.mode==Mode.branch {var child=Tree(mode:Mode.leaf,marker:empty);child.visit(callback)} else if self.mode==Mode.retain {Registry.saved.append(callback)} else {callback()}}}
;
test "callback contexts immutable discriminator separates recursive class instances" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++ tree ++
        \\func setup(){let value=7;var root=Tree(mode:Mode.branch,marker:empty);root.visit(func(){print(value)})}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
test "callback contexts immutable discriminator retains an unknown storing alternative" {
    try rejected(tree ++
        \\func setup(mode:Mode){let value=7;var root=Tree(mode:mode,marker:empty);root.visit(func(){print(value)})}
        \\func main(){}
    );
}
test "callback contexts a mixed class collection excludes impossible enum branches" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++ tree ++
        \\func setup(){let value=7;var roots:Tree[]=[Tree(mode:Mode.branch,marker:empty),Tree(mode:Mode.leaf,marker:empty)];for root in roots {root.visit(func(){print(value)})}}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
test "callback contexts a mixed class collection keeps a real retaining branch" {
    try rejected(tree ++
        \\func setup(){let value=7;var roots:Tree[]=[Tree(mode:Mode.leaf,marker:empty),Tree(mode:Mode.retain,marker:empty)];for root in roots {root.visit(func(){print(value)})}}
        \\func main(){}
    );
}

test "callback contexts fresh paths preserve existing receiver correlations" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\class Tree {
        \\ let branch:bool;let retain:bool;let marker:func();var next:Tree?=null
        \\ func visit(callback:func(),path:Tree[]){
        \\  if self.branch {if var child=self.next {var trail=path;trail.append(self);child.visit(callback,trail)}}
        \\  else if self.retain {Registry.saved.append(callback)}else{callback()}
        \\ }
        \\}
        \\func setup(){var leaf=Tree(branch:false,retain:false,marker:empty);var root=Tree(branch:true,retain:true,marker:empty,next:leaf);let value=7;root.visit(func(){print(value)},[])}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback contexts fresh paths preserve a real retaining receiver" {
    try rejected(
        \\class Tree {
        \\ let branch:bool;let retain:bool;let marker:func();var next:Tree?=null
        \\ func visit(callback:func(),path:Tree[]){
        \\  if self.branch {if var child=self.next {var trail=path;trail.append(self);child.visit(callback,trail)}}
        \\  else if self.retain {Registry.saved.append(callback)}else{callback()}
        \\ }
        \\}
        \\func setup(){var leaf=Tree(branch:false,retain:true,marker:empty);var root=Tree(branch:true,retain:true,marker:empty,next:leaf);let value=7;root.visit(func(){print(value)},[])}
        \\func main(){setup()}
    );
}

test "callback contexts fresh recursive local references widen finitely" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(declarations ++
        \\func recur(slot:&(func())?,callback:func()){var next:(func())?=null;recur(next,callback)}
        \\func setup(){let value=7;var slot:(func())?=null;recur(slot,func(){print(value)})}
        \\func main(){}
    );
}
test "callback contexts fresh recursive references retain an unknown escaping branch" {
    try rejected(
        \\func recur(slot:&(func())?,callback:func(),retain:bool){var next:(func())?=null;if retain {Registry.saved.append(callback)}else{recur(next,callback,retain)}}
        \\func setup(retain:bool){let value=7;var slot:(func())?=null;recur(slot,func(){print(value)},retain)}
        \\func main(){}
    );
}

test "callback contexts class receiver choices preserve correlated controls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\class ReceiverChoice{let skip:bool;let retain:bool;let marker:func();func visit(callback:func()){if self.skip{callback()}else if self.retain{Registry.saved.append(callback)}else{callback()}}}
        \\func setup(){var choices:ReceiverChoice[]=[ReceiverChoice(skip:true,retain:true,marker:empty),ReceiverChoice(skip:false,retain:false,marker:empty)];let value=7;for item in choices {item.visit(func(){print(value)})}}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback contexts class receiver choices keep a real storing branch" {
    try rejected(
        \\class ReceiverChoice{let skip:bool;let retain:bool;let marker:func();func visit(callback:func()){if self.skip{callback()}else if self.retain{Registry.saved.append(callback)}else{callback()}}}
        \\func setup(){var choices:ReceiverChoice[]=[ReceiverChoice(skip:true,retain:true,marker:empty),ReceiverChoice(skip:false,retain:true,marker:empty)];let value=7;for item in choices {item.visit(func(){print(value)})}}
        \\func main(){setup()}
    );
}

test "callback contexts value destructors keep their controlling receiver identities" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    _ = try frontend.compile(declarations ++
        \\struct Payload {let enabled:bool;let callback:func();drop{if self.enabled {Registry.saved.append(self.callback)}}}
        \\class Link {let payload:Payload;var next:Link?=null}
        \\func setup(){let value=7;var tail=Link(payload:Payload(enabled:false,callback:func(){print(value)}));var root=Link(payload:Payload(enabled:true,callback:empty),next:tail)}
        \\func main(){setup()}
    );
}
test "callback contexts value destructors retain a real storing receiver" {
    try rejected(
        \\struct Payload {let enabled:bool;let callback:func();drop{if self.enabled {Registry.saved.append(self.callback)}}}
        \\class Link {let payload:Payload;var next:Link?=null}
        \\func setup(){let value=7;var tail=Link(payload:Payload(enabled:true,callback:func(){print(value)}));var root=Link(payload:Payload(enabled:false,callback:empty),next:tail)}
        \\func main(){}
    );
}

test "callback contexts recursive fresh receiver partitions retain correlated controls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\class RecursiveChoice {let branch:bool;let retain:bool;let marker:func();func visit(callback:func()){if self.branch {var child=RecursiveChoice(branch:false,retain:false,marker:empty);child.visit(callback)}else if self.retain{Registry.saved.append(callback)}else{callback()}}}
        \\func setup(){let value=7;var root=RecursiveChoice(branch:true,retain:true,marker:empty);root.visit(func(){print(value)})}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback contexts recursive fresh receiver partitions retain a real escape" {
    try rejected(
        \\class RecursiveChoice {let branch:bool;let retain:bool;let marker:func();func visit(callback:func()){if self.branch {var child=RecursiveChoice(branch:false,retain:true,marker:empty);child.visit(callback)}else if self.retain{Registry.saved.append(callback)}else{callback()}}}
        \\func setup(){let value=7;var root=RecursiveChoice(branch:true,retain:true,marker:empty);root.visit(func(){print(value)})}
        \\func main(){setup()}
    );
}

test "callback contexts private projected receiver slots preserve loop choices" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\class AddressedChoice{let skip:bool;let retain:bool;let marker:func();var notes:int[]=[];func visit(callback:func()){self.notes.append(1);if self.skip{callback()}else if self.retain{Registry.saved.append(callback)}else{callback()}}}
        \\func setup(){var choices:AddressedChoice[]=[AddressedChoice(skip:true,retain:true,marker:empty),AddressedChoice(skip:false,retain:false,marker:empty)];let value=7;for item in choices {item.visit(func(){print(value)})}}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback contexts private projected receiver slots retain a real escape" {
    try rejected(
        \\class AddressedChoice{let skip:bool;let retain:bool;let marker:func();var notes:int[]=[];func visit(callback:func()){self.notes.append(1);if self.skip{callback()}else if self.retain{Registry.saved.append(callback)}else{callback()}}}
        \\func setup(){var choices:AddressedChoice[]=[AddressedChoice(skip:true,retain:true,marker:empty),AddressedChoice(skip:false,retain:true,marker:empty)];let value=7;for item in choices {item.visit(func(){print(value)})}}
        \\func main(){setup()}
    );
}

test "callback contexts private projections stay isolated after recursive returns" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\class RecursiveSlot {let branch:bool;let retain:bool;let marker:func();var notes:int[]=[];func visit(callback:func()){self.notes.append(1);if self.branch{var child=RecursiveSlot(branch:false,retain:false,marker:empty);child.visit(callback)}if !self.branch && self.retain{Registry.saved.append(callback)}callback()}}
        \\func setup(){let value=7;var root=RecursiveSlot(branch:true,retain:true,marker:empty);root.visit(func(){print(value)})}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback contexts private projections preserve a recursive escape" {
    try rejected(
        \\class RecursiveSlot {let branch:bool;let retain:bool;let marker:func();var notes:int[]=[];func visit(callback:func()){self.notes.append(1);if self.branch{var child=RecursiveSlot(branch:false,retain:true,marker:empty);child.visit(callback)}if !self.branch && self.retain{Registry.saved.append(callback)}callback()}}
        \\func setup(){let value=7;var root=RecursiveSlot(branch:true,retain:true,marker:empty);root.visit(func(){print(value)})}
        \\func main(){setup()}
    );
}

test "callback zero numeric guards eliminate an empty viewport branch" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\class NumericGate{var width:float=0.0;let marker:func()}
        \\func setup(){var gate=NumericGate(marker:empty);let value=7;if gate.width>0.0{Registry.saved.append(func(){print(value)})} var first=0;var last=0;while first<last{Registry.saved.append(func(){print(value)});first++}}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback nonzero numeric guards retain real escaping alternatives" {
    try rejected(
        \\class NumericGate{var width:float=0.0;let marker:func()}
        \\func setup(){var gate=NumericGate(marker:empty);gate.width=1.0;let value=7;if gate.width>0.0{Registry.saved.append(func(){print(value)})}}
        \\func main(){}
    );
}

test "callback opaque notifications invalidate mutable zero guards" {
    try rejected(
        \\class NumericGate{var width:float=0.0;let marker:func()}
        \\struct NumericRegistry{static var gate:NumericGate?=null}
        \\func setup(notify:func()){var gate=NumericGate(marker:empty);NumericRegistry.gate=gate;notify();let value=7;if gate.width>0.0{Registry.saved.append(func(){print(value)})}NumericRegistry.gate=null}
        \\func main(){}
    );
}

test "callback zero numeric recursion widens to the unknown alternative" {
    try rejected(
        \\func route(index:int,callback:func()){if index==0{route(index+1,callback)}else{Registry.saved.append(callback)}}
        \\func setup(){let value=7;route(0,func(){print(value)})}
        \\func main(){}
    );
}

test "callback control records preserve a false returned invalidation flag" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\struct Invalidation{var paint:bool=false;var measure:bool=false}
        \\func idle() Invalidation{return Invalidation()}
        \\func setup(){let changes=idle();let value=7;if changes.paint || changes.measure{Registry.saved.append(func(){print(value)})}}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback control records preserve a true returning guard" {
    try rejected(
        \\struct Invalidation{var paint:bool=false}
        \\func changed() Invalidation{var result=Invalidation();result.paint=true;return result}
        \\func setup(){let changes=changed();let value=7;if changes.paint{Registry.saved.append(func(){print(value)})}}
        \\func main(){}
    );
}

test "callback opaque notifications invalidate mutable boolean guards" {
    try rejected(
        \\class Flag{var enabled:bool=false}
        \\struct Flags{static var current:Flag?=null}
        \\func setup(notify:func()){var flag=Flag();Flags.current=flag;notify();let value=7;if flag.enabled{Registry.saved.append(func(){print(value)})}Flags.current=null}
        \\func main(){}
    );
}

test "callback control aliases preserve an indirect numeric write" {
    try rejected(
        \\func change(number:&float){number=1.0}
        \\func forward(writer:func(&float),number:&float){writer(number)}
        \\func setup(){var number=0.0;forward(change,number);let value=7;if number>0.0{Registry.saved.append(func(){print(value)})}}
        \\func main(){}
    );
}

test "callback control records keep unrelated flags through a value edit" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(declarations ++
        \\struct Invalidation{var paint:bool=false;var watches:bool=false}
        \\func changed() Invalidation{var result=Invalidation();result.watches=true;return result}
        \\func setup(){let changes=changed();let value=7;if changes.paint{Registry.saved.append(func(){print(value)})}}
        \\func main(){setup()}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

const confined_owner =
    \\class LocalOwner{var callback:(func())?=null;func set(callback:func()){self.callback=callback}func run(){if let work=self.callback{work()}}func clear(){self.callback=null}}
;
test "callback closed roots execute locally retained environments without globals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    const p = try frontend.compile(confined_owner ++
        \\func main(){var total=0;var owner=LocalOwner();owner.set(func(){total+=17});owner.run();owner.clear();assert(total==17)}
    );
    const result = try Interpreter.runCapture(arena.allocator(), p.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "callback closed roots keep an inner lexical scope alive only until its end" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(confined_owner ++
        \\func main(){var owner=LocalOwner();{let value=7;owner.set(func(){print(value)})}owner.run()}
    ));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}

test "callback closed roots do not discharge external owner parameters" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.Frontend.init(arena.allocator());
    try std.testing.expectError(error.InvalidSource, frontend.compile(confined_owner ++
        \\func setup(owner:LocalOwner){let value=7;owner.set(func(){print(value)})}
        \\func main(){}
    ));
    try std.testing.expectEqualStrings("capturing function value cannot be stored beyond its lexical scope", frontend.diagnostic.?.message);
}
