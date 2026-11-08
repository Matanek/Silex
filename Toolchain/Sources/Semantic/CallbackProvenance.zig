const std = @import("std");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");
const CompilationTrace = @import("../CompilationTrace.zig");
const M = @import("CallbackFlow/Model.zig");
const Finalization = @import("CallbackFlow/Finalization.zig");
const Refine = @import("CallbackFlow/Refine.zig");
const Machine = @import("CallbackFlow/Transfer.zig");
const ResourceLoops = @import("CallbackFlow/ResourceLoops.zig");
const A = std.mem.Allocator;
const Value = M.Value;

/// Interpret callback ownership on the complete typed graph, after package
/// restoration. This does not rewrite the program used by either backend.
pub fn check(allocator: A, program: Ir.Program) !?Source.Diagnostic {
    return checkWithTrace(allocator, program, null);
}

pub fn checkWithTrace(allocator: A, program: Ir.Program, trace: ?*CompilationTrace.Reporter) !?Source.Diagnostic {
    _ = allocator;
    const active_trace: ?*CompilationTrace.Reporter = if (trace) |reporter| (if (reporter.enabled()) reporter else null) else null;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const borrowed = try a.alloc(bool, program.functions.len);
    @memset(borrowed, false);
    var any = false;
    for (program.functions, 0..) |f, root| for (f.blocks) |b| for (b.instructions) |op| if (op == .function_reference) {
        for (op.function_reference.captures) |capture| borrowed[root] = borrowed[root] or f.value_types[capture] == .address;
        any = any or borrowed[root];
    };
    // No lexical loan can originate in this program. Protocols and object
    // cycles alone do not require callback ownership interpretation.
    if (!any) return null;
    const predicates = try Refine.program(a, program);
    const looping_blocks = try @import("CallbackFlow/Loops.zig").program(a, program);
    const resource_loops = try ResourceLoops.program(a, program);
    const cleanup_functions = try @import("CallbackFlow/Cleanup.zig").program(a, program);
    const immediate = try @import("CallbackFlow/Immediate.zig").origins(a, program);
    for (program.functions, 0..) |_, source| {
        if (!borrowed[source] or immediate[source]) continue;
        if (active_trace) |reporter| reporter.metrics.callback_origins +|= 1;
        var partition = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer partition.deinit();
        const owned = partition.allocator();
        if (@import("CallbackFlow/ClosedRoot.zig").eligible(program, source)) {
            const loans = try @import("CallbackFlow/Domain.zig").loanCapabilities(owned, program, source);
            if (try @import("CallbackFlow/ClosedRoot.zig").proven(owned, program, loans, source)) {
                continue;
            }
        }
        const domain = try @import("CallbackFlow/Domain.zig").forOrigin(owned, program, source);
        const capable = domain.capable;
        const relevant = domain.relevant;
        const generators = domain.generators;
        // Each origin needs only carriers and callable effects connected to its
        // loan signatures. Unrelated UI/event callbacks cannot carry this loan.
        var needs_context = false;
        for (0..2) |pass| {
            if (pass == 1 and !needs_context) break;
            for (program.functions, 0..) |f, root| {
                if (pass == 0 and root != source) continue;
                if (pass == 1 and (root == source or (!f.is_test_entry and !std.mem.eql(u8, f.name, "main")))) continue;
                var local = std.heap.ArenaAllocator.init(std.heap.page_allocator);
                defer local.deinit();
                var engine = Engine{ .a = local.allocator(), .storage = local.allocator(), .program = program, .capable = capable, .relevant = relevant, .borrowed = borrowed, .generators = generators, .looping_blocks = looping_blocks, .predicates = predicates, .cleanup_functions = cleanup_functions, .resource_loops = resource_loops, .trace = active_trace };
                const globals = try engine.object(0, .local, M.wildcard, null, false);
                engine.globals = globals;
                var state: M.Memory = .empty;
                const frame = try engine.newFrame(root, null, 0);
                const inputs = f.capture_types.len + f.parameter_types.len;
                const arguments = try engine.a.alloc(Value, inputs);
                for (f.value_types[0..inputs], 0..) |t, i| arguments[i] = try engine.unknown(&state, .{ .object = globals, .field = program.globals.len + i }, t);
                _ = try engine.evaluate(frame, arguments, &state);
                if (engine.diagnostic) |d| return d;
                needs_context = needs_context or engine.needs_context;
            }
        }
    }
    return null;
}

pub const Engine = struct {
    trace: ?*CompilationTrace.Reporter = null,
    a: A,
    storage: A,
    program: Ir.Program,
    capable: M.Capabilities,
    relevant: []const bool,
    borrowed: []const bool,
    generators: []const bool,
    nodes: std.ArrayList(M.Node) = .empty,
    sites: std.AutoHashMapUnmanaged(M.Site, usize) = .empty,
    frames: std.ArrayList(*M.Frame) = .empty,
    globals: usize = 0,
    diagnostic: ?Source.Diagnostic = null,
    needs_context: bool = false,
    predicates: []const []const ?Refine.Predicate = &.{},
    looping_blocks: []const []const bool = &.{},

    cleanup_functions: []const bool = &.{},
    resource_loops: []const []const ?ResourceLoops.Plan = &.{},

    pub fn node(self: *Engine, site: M.Site, node_value: M.Node) A.Error!usize {
        if (self.sites.get(site)) |id| {
            switch (self.nodes.items[id]) {
                .object => |*o| {
                    o.many = o.many or node_value.object.many;
                    if (o.length != node_value.object.length) o.length = null;
                    if (o.unknown_parent == null) o.unknown_parent = node_value.object.unknown_parent;
                },
                .callable => |*c| {
                    c.many = c.many or node_value.callable.many;
                    var joined: std.ArrayList(M.Loan) = .empty;
                    try joined.appendSlice(self.storage, c.loans);
                    for (node_value.callable.loans) |loan| {
                        var found = false;
                        for (joined.items) |item| found = found or (item.frame == loan.frame and item.lifetime == loan.lifetime);
                        if (!found) try joined.append(self.storage, loan);
                    }
                    if (joined.items.len != c.loans.len) c.loans = try joined.toOwnedSlice(self.storage);
                },
                else => {},
            }
            return id;
        }
        const id = self.nodes.items.len;
        var durable = node_value;
        if (durable == .callable) durable.callable.loans = try self.storage.dupe(M.Loan, durable.callable.loans);
        try self.nodes.append(self.storage, durable);
        try self.sites.put(self.storage, site, id);
        return id;
    }
    pub fn object(self: *Engine, frame: usize, category: M.Category, site: usize, t: ?Ir.Type, repeated: bool) A.Error!usize {
        return self.objectWithLength(frame, category, site, t, repeated, null);
    }
    pub fn objectWithLength(self: *Engine, frame: usize, category: M.Category, site: usize, t: ?Ir.Type, repeated: bool, length: ?usize) A.Error!usize {
        return self.node(.{ .frame = frame, .category = category, .value = site }, .{ .object = .{ .type = t, .many = repeated, .length = length } });
    }
    pub fn collectionLength(self: *Engine, value: Value) ?usize {
        if (value.nodes.len == 0) return null;
        var length: ?usize = null;
        for (value.nodes) |id| {
            const n = self.nodes.items[id];
            if (n != .object) return null;
            var current = n.object.length;
            if (current == null) if (n.object.type) |t| if (t.structureIndex()) |i| if (self.program.structures[i].collection) |collection| {
                current = collection.length;
            };
            const known = current orelse return null;
            if (length != null and length.? != known) return null;
            length = known;
        }
        return length;
    }
    pub fn address(self: *Engine, cell: M.Cell) A.Error!Value {
        const id = try self.node(.{ .frame = cell.object, .category = .address, .value = cell.field }, .{ .address = cell });
        var result = try Value.one(self.a, id);
        result.reference_domain = .unknown;
        return result;
    }
    pub fn many(self: *Engine, id: usize) bool {
        var current = id;
        for (0..self.nodes.items.len + 1) |_| {
            switch (self.nodes.items[current]) {
                .object => |o| {
                    if (o.many) return true;
                    current = o.unknown_parent orelse return false;
                },
                .callable => |c| return c.many,
                .address => return false,
            }
        }
        return true; // A cyclic unknown shape is a summary, never a unique instance.
    }
    pub fn write(self: *Engine, memory: *M.Memory, cell: M.Cell, input: Value, strong: bool) A.Error!void {
        var value = input;
        const destination = self.nodes.items[cell.object];
        // Immutable environments and concrete internal objects retain known
        // controls. Unknown aliases remain conservative; opaque notifications
        // invalidate mutable facts before subsequent reads.
        var immutable = destination == .callable;
        if (destination == .object and !destination.object.external) {
            if (destination.object.type) |t| if (t.structureIndex()) |index| {
                const fields = self.program.structures[index].fields;
                if (cell.field < fields.len) {
                    immutable = !fields[cell.field].mutable;
                    if (value.scalar.isProtocol() and destination.object.unknown_parent == null and self.program.structures[index].is_class and M.protocolType(self.program, fields[cell.field].type)) immutable = true;
                }
            };
        }
        if (!immutable and destination == .object and !destination.object.external and value.scalar.isProtocol()) {
            if (destination.object.type) |t| if (t.structureIndex()) |index| {
                if (self.program.structures[index].collection) |collection| {
                    immutable = M.protocolType(self.program, collection.element) and M.capable(self.capable, collection.element);
                }
            };
        }
        var keep_presence = immutable;
        if (destination == .object and !destination.object.external and destination.object.type != null) keep_presence = true;
        if (cell.object == self.globals and cell.field < self.program.globals.len and M.capable(self.capable, self.program.globals[cell.field].type)) keep_presence = true;
        if (!keep_presence and value.presence != .bottom) value.presence = .unknown;
        const concrete_control = destination == .object and !destination.object.external and destination.object.type != null;
        if (!immutable and !concrete_control and value.scalar != .bottom) value.scalar = .unknown;
        if (strong and !self.many(cell.object)) try memory.put(self.a, cell, value) else try memory.put(self.a, cell, try Value.join(memory.get(cell) orelse .{}, value, self.a));
        // Distinct unconstrained class inputs may denote the same instance.
        // A write through one input is therefore a possible write through each
        // compatible unknown alias; only the selected place is a strong write.
        const base = self.nodes.items[cell.object];
        if (base != .object or base.object.unknown_parent == null) return;
        const t = (base.object.type orelse return).structureIndex() orelse return;
        if (!self.program.structures[t].is_class) return;
        for (self.nodes.items, 0..) |other, id| {
            if (id == cell.object or other != .object or other.object.unknown_parent == null) continue;
            const u = (other.object.type orelse continue).structureIndex() orelse continue;
            if (!self.compatible(t, u)) continue;
            const alias: M.Cell = .{ .object = id, .field = cell.field };
            try memory.put(self.a, alias, try Value.join(memory.get(alias) orelse .{}, value, self.a));
        }
    }
    fn compatible(self: *Engine, first: usize, second: usize) bool {
        var current: ?usize = first;
        while (current) |id| : (current = self.program.structures[id].base) if (id == second) return true;
        current = second;
        while (current) |id| : (current = self.program.structures[id].base) if (id == first) return true;
        return false;
    }
    pub fn unknown(self: *Engine, memory: *M.Memory, cell: M.Cell, t: Ir.Type) A.Error!Value {
        if (memory.get(cell)) |value| return value;
        // Only external objects have undiscovered fields. A missing cell of a
        // concrete allocation (notably an empty collection) is bottom, not a
        // fresh unknown object with arbitrary aliases and finalizers.
        const owner = self.nodes.items[cell.object];
        if (cell.object != self.globals and (owner != .object or owner.object.unknown_parent == null)) return .{};
        if (t.optionalChild()) |child| {
            var value = try self.unknown(memory, cell, child);
            value.presence = .unknown;
            try memory.put(self.a, cell, value);
            return value;
        }
        var value: Value = M.unknownValue(self.program, t);
        if (t == .address) {
            const holder = try self.node(.{ .frame = cell.object, .category = .unknown, .value = cell.field }, .{ .object = .{ .type = null, .many = cell.field == M.wildcard or self.many(cell.object), .unknown_parent = cell.object, .external = true } });
            value = try self.address(.{ .object = holder, .field = 0 });
        } else if (t.structureIndex() != null and M.capable(self.capable, t)) {
            // Unknown recursive object graphs fold back only at a repeated type.
            // Such summary nodes never receive a destructive strong update.
            var parent: ?usize = cell.object;
            while (parent) |id| {
                const n = self.nodes.items[id];
                if (n != .object) break;
                if (n.object.type == t) {
                    self.nodes.items[id].object.many = true;
                    value = try Value.one(self.a, id);
                    break;
                }
                parent = n.object.unknown_parent;
            }
            if (value.nodes.len == 0) {
                const id = try self.node(.{ .frame = cell.object, .category = .unknown, .value = cell.field }, .{ .object = .{ .type = t, .many = cell.field == M.wildcard or self.many(cell.object), .unknown_parent = cell.object, .external = true } });
                value = try Value.one(self.a, id);
                try Finalization.initializeUnknown(self, memory, id, cell.object == self.globals);
                // A lazily discovered external field may alias an input that
                // was already modified before this projection was evaluated.
                const structure = t.structureIndex().?;
                if (self.program.structures[structure].is_class) {
                    var aliases: std.ArrayList(struct { field: usize, value: Value }) = .empty;
                    var it = memory.iterator();
                    while (it.next()) |entry| {
                        const other = self.nodes.items[entry.key_ptr.object];
                        if (other != .object or other.object.unknown_parent == null) continue;
                        const index = (other.object.type orelse continue).structureIndex() orelse continue;
                        if (self.compatible(structure, index)) try aliases.append(self.a, .{ .field = entry.key_ptr.field, .value = entry.value_ptr.* });
                    }
                    for (aliases.items) |alias| {
                        const destination: M.Cell = .{ .object = id, .field = alias.field };
                        try memory.put(self.a, destination, try Value.join(memory.get(destination) orelse .{}, alias.value, self.a));
                    }
                }
            }
        }
        if (M.scalarType(self.program, t)) value.scalar = .unknown;
        try memory.put(self.a, cell, value);
        return value;
    }
    pub fn field(self: *Engine, memory: *M.Memory, base: Value, index: usize, t: Ir.Type) A.Error!Value {
        var result: Value = .{};
        for (base.nodes) |id| {
            if (self.nodes.items[id] != .object) continue;
            const cell: M.Cell = .{ .object = id, .field = index };
            result = try Value.join(result, try self.unknown(memory, cell, t), self.a);
            if (index != M.wildcard) result = try Value.join(result, memory.get(.{ .object = id, .field = M.wildcard }) orelse .{}, self.a);
        }
        return result;
    }
    pub fn elements(self: *Engine, memory: *M.Memory, base: Value) A.Error!Value {
        var result: Value = .{};
        for (base.nodes) |object_value| {
            const node_value = self.nodes.items[object_value];
            if (node_value == .object and node_value.object.unknown_parent != null) {
                if (node_value.object.type) |t| if (t.structureIndex()) |index| {
                    if (self.program.structures[index].collection) |collection| _ = try self.unknown(memory, .{ .object = object_value, .field = M.wildcard }, collection.element);
                };
            }
            var it = memory.fields(object_value);
            while (it.next()) |entry| result = try Value.join(result, entry.value_ptr.*, self.a);
        }
        return result;
    }
    pub fn dereference(self: *Engine, memory: *M.Memory, reference: Value, t: Ir.Type) A.Error!Value {
        var result: Value = .{};
        for (reference.nodes) |id| if (self.nodes.items[id] == .address) {
            result = try Value.join(result, try self.unknown(memory, self.nodes.items[id].address, t), self.a);
        };
        return result;
    }
    pub fn store(self: *Engine, memory: *M.Memory, reference: Value, value: Value) A.Error!void {
        for (reference.nodes) |id| if (self.nodes.items[id] == .address) {
            try self.write(memory, self.nodes.items[id].address, value, reference.nodes.len == 1 and self.nodes.items[id].address.field != M.wildcard);
        };
    }
    fn newFrame(self: *Engine, function: usize, parent: ?usize, site: usize) A.Error!usize {
        if (self.trace) |trace| trace.metrics.callback_frames +|= 1;
        const id = self.frames.items.len;
        const frame = try self.storage.create(M.Frame);
        const repeated = if (parent) |caller| self.repeatedCall(caller, site) else false;
        frame.* = .{ .function = function, .parent = parent, .site = site, .repeated = repeated, .locals = try self.object(id, .local, 0, null, repeated) };
        frame.unaliased_locals = try @import("CallbackFlow/Locals.zig").privateCells(self.storage, self.program, function);
        try self.frames.append(self.storage, frame);
        return id;
    }
    pub fn invoke(self: *Engine, parent: usize, site: usize, function: usize, arguments: []const Value, memory: *M.Memory) A.Error!Value {
        if (!self.callReachable(function, arguments)) return .{ .no_return = true };
        if (!self.relevant[function]) return self.unknownReturn(function);
        // A non-generating transfer cannot manufacture relevant state from
        // empty inputs. External shape alone is not data; a known callable or
        // concrete owner anywhere in external storage still prevents skipping
        // lazy aliases. Returned capabilities and observable writes generate.
        if (!self.generators[function]) {
            var data = false;
            for (arguments) |argument| {
                var visited: std.AutoHashMapUnmanaged(usize, void) = .empty;
                data = data or try self.hasData(argument, memory.*, &visited);
            }
            if (!data) {
                var visited: std.AutoHashMapUnmanaged(usize, void) = .empty;
                data = try self.hasConcrete(try Value.one(self.a, self.globals), memory.*, &visited);
            }
            if (!data) return self.unknownReturn(function);
        }
        // Recursive SCCs share a summary frame and monotonically join their
        // incoming values/memory. No unbounded stack of abstract environments.
        var ancestor: ?usize = parent;
        while (ancestor) |id| {
            const frame = self.frames.items[id];
            if (frame.function == function and frame.active and @import("CallbackFlow/Shape.zig").arguments(self, frame.arguments, arguments, if (self.cleanup_functions.len == self.program.functions.len and self.cleanup_functions[function]) 0 else frame.context_boundary)) {
                if (!frame.recursive) {
                    frame.recursive = true;
                    var sites = self.sites.iterator();
                    while (sites.next()) |entry| {
                        const key = entry.key_ptr.*;
                        if (key.frame != id or key.category == .address or key.category == .unknown or
                            (key.category == .local and key.value == M.wildcard)) continue;
                        switch (self.nodes.items[entry.value_ptr.*]) {
                            .object => |*object_value| object_value.many = true,
                            .callable => |*callable_value| callable_value.many = true,
                            else => {},
                        }
                    }
                    frame.changed = true;
                }
                for (frame.arguments, arguments) |*value, input| {
                    const joined = try Value.join(value.*, try input.own(frame.allocator), frame.allocator);
                    if (!Value.eql(joined, value.*)) {
                        frame.changed = true;
                    }
                    value.* = joined;
                }
                const input_changed = try M.joinMemoryOwned(frame.allocator, &frame.incoming, memory.*);
                frame.changed = input_changed or frame.changed;
                _ = try M.joinMemory(self.a, memory, frame.output);
                return frame.returned;
            }
            ancestor = frame.parent;
        }
        for (self.frames.items, 0..) |frame, id| {
            if (self.trace) |trace| trace.metrics.callback_frame_lookup_visits +|= 1;
            if (frame.parent == parent and frame.site == site and frame.function == function) {
                if (self.repeatedCall(parent, site) and !frame.repeated) self.repeatFrame(id);
                return self.evaluate(id, arguments, memory);
            }
        }
        return self.evaluate(try self.newFrame(function, parent, site), arguments, memory);
    }
    pub fn callReachable(self: *Engine, function: usize, arguments: []const Value) bool {
        const f = self.program.functions[function];
        for (arguments, 0..) |argument, i| {
            if (argument.no_return) return false;
            const t = f.value_types[i];
            if (t.optionalChild() != null or !M.capable(self.capable, t)) continue;
            const index = t.structureIndex() orelse continue;
            if (self.program.structures[index].is_class and argument.nodes.len == 0) return false;
        }
        return true;
    }
    pub fn unknownResult(self: *Engine, parent: usize, site: usize, t: Ir.Type, memory: *M.Memory) A.Error!Value {
        if (t != .address and !M.capable(self.capable, t)) return M.unknownValue(self.program, t);
        const marker = try self.object(parent, .call_result, site, t, true);
        var max_inputs: usize = 0;
        for (self.program.functions) |f| max_inputs = @max(max_inputs, f.capture_types.len + f.parameter_types.len);
        const cell: M.Cell = .{ .object = self.globals, .field = self.program.globals.len + max_inputs + marker + 1 };
        const value = try self.unknown(memory, cell, t);
        for (value.nodes) |id| switch (self.nodes.items[id]) {
            .object => |*o| o.many = true,
            else => {},
        };
        return value;
    }
    fn unknownReturn(self: *Engine, function: usize) Value {
        // A skipped transfer is not an unreachable return. In a union of
        // callable targets, it must not become the identity for a known fact.
        return M.unknownValue(self.program, self.program.functions[function].return_type);
    }
    pub fn inLoop(self: *Engine, function: usize, block: usize) bool {
        if (self.looping_blocks.len == self.program.functions.len) return self.looping_blocks[function][block];
        return Machine.inLoop(self.program.functions[function], block);
    }
    fn repeatedCall(self: *Engine, parent: usize, site: usize) bool {
        const caller = self.frames.items[parent];
        return caller.recursive or caller.repeated or self.inLoop(caller.function, site >> 32);
    }
    fn repeatFrame(self: *Engine, id: usize) void {
        self.frames.items[id].repeated = true;
        var sites = self.sites.iterator();
        while (sites.next()) |entry| {
            const key = entry.key_ptr.*;
            if (key.frame != id or key.category == .address or key.category == .unknown or
                (key.category == .local and key.value == M.wildcard)) continue;
            switch (self.nodes.items[entry.value_ptr.*]) {
                .object => |*object_value| object_value.many = true,
                .callable => |*callable_value| callable_value.many = true,
                else => {},
            }
        }
    }
    fn hasData(self: *Engine, value: Value, memory: M.Memory, visited: *std.AutoHashMapUnmanaged(usize, void)) A.Error!bool {
        if (value.presence == .absent or value.presence == .present or (value.scalar != .bottom and value.scalar != .unknown)) return true;
        for (value.nodes) |id| {
            if (visited.contains(id)) continue;
            try visited.put(self.a, id, {});
            switch (self.nodes.items[id]) {
                .callable => return true,
                .object => |object_value| {
                    if (!object_value.external) return true;
                    var fields = memory.fields(id);
                    while (fields.next()) |entry| if (try self.hasData(entry.value_ptr.*, memory, visited)) return true;
                },
                .address => |cell| if (try self.hasData(memory.get(cell) orelse .{}, memory, visited)) return true,
            }
        }
        return false;
    }
    pub fn invalidateMutableFacts(self: *Engine, memory: *M.Memory) A.Error!void {
        if (self.trace) |trace| trace.metrics.callback_fact_invalidations +|= 1;
        var it = memory.iterator();
        while (it.next()) |entry| {
            if (self.trace) |trace| trace.metrics.callback_fact_cells_scanned +|= 1;
            if ((entry.value_ptr.scalar == .bottom or entry.value_ptr.scalar == .unknown) and entry.value_ptr.presence != .absent and entry.value_ptr.presence != .present) continue;
            const owner = self.nodes.items[entry.key_ptr.object];
            if (owner == .callable) continue;
            if (owner == .object) {
                if (owner.object.type) |t| if (t.structureIndex()) |index| {
                    const fields = self.program.structures[index].fields;
                    if (self.program.structures[index].collection == null and entry.key_ptr.field < fields.len and !fields[entry.key_ptr.field].mutable) continue;
                };
            }
            if (entry.key_ptr.object == self.globals and entry.key_ptr.field < self.program.globals.len and !self.program.globals[entry.key_ptr.field].mutable) continue;
            var value = entry.value_ptr.*;
            if (value.scalar != .bottom) value.scalar = .unknown;
            if (value.presence != .bottom) value.presence = .unknown;
            try memory.put(self.a, entry.key_ptr.*, value);
        }
    }
    pub fn indirect(self: *Engine, parent: usize, site: usize, callee: Value, arguments: []const Value, return_type: Ir.Type, memory: *M.Memory) A.Error!Value {
        var returned: Value = .{ .no_return = true };
        var merged: M.Memory = .empty;
        const incoming = memory.*;
        var any = false;
        for (callee.nodes) |id| {
            const node_value = self.nodes.items[id];
            if (node_value != .callable) continue;
            any = true;
            var branch = try M.cloneMemory(self.a, memory.*);
            const function = self.program.functions[node_value.callable.function];
            const inputs = try self.a.alloc(Value, function.capture_types.len + arguments.len);
            for (0..function.capture_types.len) |index| inputs[index] = branch.get(.{ .object = id, .field = index }) orelse .{};
            @memcpy(inputs[function.capture_types.len..], arguments);
            const output = try self.invoke(parent, site, node_value.callable.function, inputs, &branch);
            returned = try Value.join(returned, output, self.a);
            if (!output.no_return) _ = try M.joinMemory(self.a, &merged, branch);
        }
        if (any) {
            memory.* = merged;
        }
        if (callee.unknown_callable) {
            if (any) {
                _ = try M.joinMemory(self.a, &merged, incoming);
                memory.* = merged;
            }
            try self.invalidateMutableFacts(memory);
            returned = try Value.join(returned, try self.unknownResult(parent, site, return_type, memory), self.a);
            // An opaque call can expose its inputs or produce a capability
            // used later. Even a zero-argument void call can observe a live
            // loan through globals or a creator's external inputs.
            self.needs_context = self.needs_context or return_type == .address or M.capable(self.capable, return_type);
            for (arguments) |argument| self.needs_context = self.needs_context or argument.nodes.len != 0;
            if (!self.needs_context) {
                var visited: std.AutoHashMapUnmanaged(usize, void) = .empty;
                self.needs_context = try self.hasConcrete(try Value.one(self.a, self.globals), memory.*, &visited);
                for (self.frames.items) |frame| {
                    if (!frame.active or !self.borrowed[frame.function]) continue;
                    for (frame.arguments) |argument| {
                        visited = .empty;
                        self.needs_context = try self.hasConcrete(argument, memory.*, &visited) or self.needs_context;
                    }
                }
            }
        }
        return returned;
    }
    // An opaque callback can change known callable state or retain a concrete
    // instance exposed by the creator, including before a loan is created.
    // Original external objects already have unconstrained ownership/fields.
    fn hasConcrete(self: *Engine, value: Value, memory: M.Memory, visited: *std.AutoHashMapUnmanaged(usize, void)) A.Error!bool {
        for (value.nodes) |id| {
            if (visited.contains(id)) continue;
            try visited.put(self.a, id, {});
            switch (self.nodes.items[id]) {
                .callable => return true,
                .object => |o| if (!o.external and o.type != null) {
                    return true;
                },
                .address => |cell| if (try self.hasConcrete(memory.get(cell) orelse .{}, memory, visited)) {
                    return true;
                },
            }
            var it = memory.fields(id);
            while (it.next()) |entry| if (try self.hasConcrete(entry.value_ptr.*, memory, visited)) return true;
        }
        return false;
    }
    fn evaluate(self: *Engine, id: usize, arguments: []const Value, memory: *M.Memory) A.Error!Value {
        if (self.trace) |trace| trace.metrics.callback_evaluations +|= 1;
        const frame = self.frames.items[id];
        frame.context_boundary = self.nodes.items.len;
        var scratch = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer scratch.deinit();
        const caller_allocator = self.a;
        self.a = scratch.allocator();
        defer self.a = caller_allocator;

        frame.allocator = self.a;
        defer {
            frame.arguments = &.{};
            frame.incoming = .empty;
            frame.output = .empty;
            frame.returned = .{};
            frame.allocator = undefined;
        }
        frame.arguments = try self.a.dupe(Value, arguments);
        frame.incoming = try M.cloneMemory(self.a, memory.*);
        frame.output = .empty;
        frame.returned = .{ .no_return = true };
        frame.active = true;
        defer frame.active = false;
        while (true) {
            frame.changed = false;
            const f = self.program.functions[frame.function];
            var receivers: []const usize = &.{};
            if (frame.arguments.len != 0 and frame.arguments[0].nodes.len > 1 and
                !(self.cleanup_functions.len == self.program.functions.len and self.cleanup_functions[frame.function]))
            {
                if (f.value_types[0].structureIndex()) |receiver_type| if (self.program.structures[receiver_type].is_class) {
                    receivers = frame.arguments[0].nodes;
                };
            }
            const partitions = if (receivers.len == 0) 1 else receivers.len;
            for (0..partitions) |partition| {
                const entries = try self.a.alloc(?M.State, f.blocks.len);
                @memset(entries, null);
                var initial: M.State = .{ .memory = try M.cloneMemory(self.a, frame.incoming) };
                for (frame.arguments, 0..) |argument, index| try initial.set(self.a, index, argument);
                if (receivers.len != 0) {
                    var receiver = frame.arguments[0];
                    receiver.nodes = try self.a.dupe(usize, &.{receivers[partition]});
                    receiver.region = self.a.ptr;
                    try initial.set(self.a, 0, receiver);
                }
                entries[0] = initial;
                const pending = try self.a.alloc(bool, f.blocks.len);
                @memset(pending, false);
                pending[0] = true;
                while (true) {
                    var processed = false;
                    for (f.blocks, 0..) |block, block_id| {
                        if (!pending[block_id]) continue;
                        pending[block_id] = false;
                        processed = true;
                        const entry = entries[block_id].?;
                        var state = try entry.clone(self.a);
                        if (self.resource_loops.len == self.program.functions.len) if (self.resource_loops[frame.function][block_id]) |plan| {
                            const type_index = f.value_types[plan.collection].structureIndex() orelse unreachable;
                            const collection = self.program.structures[type_index].collection orelse unreachable;
                            const length: ?usize = if (collection.length) |n| n else self.collectionLength(state.get(plan.collection));
                            if (length) |count| if (count <= std.math.maxInt(i32)) {
                                for (0..count) |iteration| {
                                    try self.transferBlock(id, block_id, &state, null);
                                    if (self.diagnostic != null) return .{};
                                    if (!state.reachable) break;
                                    try state.set(self.a, plan.condition, .{ .scalar = .{ .boolean = true } });
                                    try self.transferBlock(id, plan.body, &state, .{ .instruction = plan.load, .element = if (plan.reverse) count - iteration - 1 else iteration });
                                    if (self.diagnostic != null) return .{};
                                    if (!state.reachable) break;
                                }
                                if (state.reachable) {
                                    try self.transferBlock(id, block_id, &state, null);
                                    if (self.diagnostic != null) return .{};
                                    if (state.reachable) {
                                        try state.set(self.a, plan.condition, .{ .scalar = .{ .boolean = false } });
                                        if (try self.joinEntry(&entries[plan.exit], state)) pending[plan.exit] = true;
                                    }
                                }
                                continue;
                            };
                        };
                        try self.transferBlock(id, block_id, &state, null);
                        if (self.diagnostic != null) return .{};
                        if (!state.reachable) continue;
                        switch (block.terminator) {
                            .return_value, .return_void => {
                                const output: Value = if (block.terminator == .return_value) state.get(block.terminator.return_value) else .{};
                                if (block.terminator == .return_value and M.capable(self.capable, f.return_type)) try self.escape(id, null, output, state.memory, block.terminator_position, true);
                                try self.externals(id, null, &state, block.terminator_position);
                                const joined = try Value.join(frame.returned, output, self.a);
                                const returned_changed = !Value.eql(joined, frame.returned);
                                frame.returned = joined;
                                const output_changed = try M.joinMemory(self.a, &frame.output, state.memory);
                                frame.changed = returned_changed or output_changed or frame.changed;
                            },
                            .jump => |target| if (try self.joinEntry(&entries[target], state)) {
                                pending[target] = true;
                            },
                            .branch => |branch| {
                                const condition = state.get(branch.condition).scalar;
                                if (condition != .boolean or condition.boolean) {
                                    var next = state;
                                    if (try Refine.apply(self, id, block_id, true, &next) and try self.joinEntry(&entries[branch.then_block], next)) pending[branch.then_block] = true;
                                }
                                if (condition != .boolean or !condition.boolean) {
                                    var next = state;
                                    if (try Refine.apply(self, id, block_id, false, &next) and try self.joinEntry(&entries[branch.else_block], next)) pending[branch.else_block] = true;
                                }
                            },
                            else => {},
                        }
                    }
                    if (!processed) break;
                }
            }
            if (!frame.recursive or !frame.changed) break;
        }
        const output = try frame.output.promote(self.a, caller_allocator);
        memory.* = output;
        return frame.returned.promote(self.a, caller_allocator);
    }
    const ElementOverride = struct { instruction: usize, element: usize };
    fn transferBlock(self: *Engine, frame_id: usize, block_id: usize, state: *M.State, override: ?ElementOverride) A.Error!void {
        const f = self.program.functions[self.frames.items[frame_id].function];
        const block = f.blocks[block_id];
        for (0..block.instructions.len + 1) |index| {
            for (f.borrow_ends) |end| if (end.block == block_id and end.instruction == index) try self.scopeEnd(frame_id, end, state);
            if (self.diagnostic != null) return;
            if (index < block.instructions.len) {
                if (override != null and override.?.instruction == index) {
                    const access = block.instructions[index].collection_load;
                    try state.set(self.a, access.result, try self.field(&state.memory, state.get(access.collection), override.?.element, f.value_types[access.result]));
                } else try Machine.step(self, frame_id, block_id, index, block.instructions[index], state);
                if (self.diagnostic != null or !state.reachable) return;
            }
        }
    }
    fn joinEntry(self: *Engine, target: *?M.State, state: M.State) A.Error!bool {
        if (target.*) |*entry| return entry.join(self.a, state);
        target.* = try state.clone(self.a);
        return true;
    }
    fn scopeEnd(self: *Engine, frame: usize, end: Ir.BorrowEnd, state: *M.State) A.Error!void {
        if (!self.borrowed[self.frames.items[frame].function]) return;
        try self.externals(frame, end.lifetimes, state, end.position);
        for (end.live) |binding| {
            const caller = self.frames.items[frame];
            const f = self.program.functions[caller.function];
            const value: Value = if (binding.local) |local| (if (caller.unaliased_locals[local]) state.get(f.value_types.len + local) else state.memory.get(.{ .object = caller.locals, .field = local }) orelse .{}) else if (binding.value) |v| state.get(v) else .{};
            try self.escape(frame, end.lifetimes, value, state.memory, end.position, false);
        }
    }
    fn externals(self: *Engine, frame: usize, lifetimes: ?[]const usize, state: *M.State, position: ?Source.Position) A.Error!void {
        if (!self.borrowed[self.frames.items[frame].function]) return;
        const f = self.program.functions[self.frames.items[frame].function];
        for (0..f.capture_types.len + f.parameter_types.len) |input| try self.escape(frame, lifetimes, state.get(input), state.memory, position, false);
        try self.escape(frame, lifetimes, try Value.one(self.a, self.globals), state.memory, position, false);
    }
    fn escape(self: *Engine, frame: usize, lifetimes: ?[]const usize, value: Value, memory: M.Memory, position: ?Source.Position, returned: bool) A.Error!void {
        if (self.diagnostic != null or !self.borrowed[self.frames.items[frame].function]) return;
        var visited: std.AutoHashMapUnmanaged(usize, void) = .empty;
        if (try self.hasLoan(frame, lifetimes, value, memory, &visited)) {
            self.diagnostic = .{ .position = position orelse self.program.functions[self.frames.items[frame].function].source_position orelse return, .message = if (returned) "capturing function value cannot be returned from its lexical scope" else "capturing function value cannot be stored beyond its lexical scope" };
        }
    }
    fn hasLoan(self: *Engine, frame: usize, lifetimes: ?[]const usize, value: Value, memory: M.Memory, visited: *std.AutoHashMapUnmanaged(usize, void)) A.Error!bool {
        for (value.nodes) |id| {
            if ((memory.owners.get(id) orelse M.Owner{}).lifetime == .finalized) continue;
            if (visited.contains(id)) continue;
            try visited.put(self.a, id, {});
            switch (self.nodes.items[id]) {
                .callable => |callable| for (callable.loans) |loan| {
                    if (loan.frame == frame and (lifetimes == null or std.mem.indexOfScalar(usize, lifetimes.?, loan.lifetime) != null)) return true;
                },
                .address => |cell| if (try self.hasLoan(frame, lifetimes, memory.get(cell) orelse .{}, memory, visited)) return true,
                else => {},
            }
            var it = memory.fields(id);
            while (it.next()) |entry| if (try self.hasLoan(frame, lifetimes, entry.value_ptr.*, memory, visited)) return true;
        }
        return false;
    }
};
