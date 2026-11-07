const std = @import("std");
const Ir = @import("../Ir.zig");
const Source = @import("../Source.zig");
const M = @import("CallbackFlow/Model.zig");
const Finalization = @import("CallbackFlow/Finalization.zig");
const Machine = @import("CallbackFlow/Transfer.zig");
const A = std.mem.Allocator;
const Value = M.Value;

/// Interpret callback ownership on the complete typed graph, after package
/// restoration. This does not rewrite the program used by either backend.
pub fn check(allocator: A, program: Ir.Program) !?Source.Diagnostic {
    _ = allocator;
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
    for (program.functions, 0..) |_, source| {
        if (!borrowed[source]) continue;
        var partition = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer partition.deinit();
        const owned = partition.allocator();
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
                var engine = Engine{ .a = local.allocator(), .storage = local.allocator(), .program = program, .capable = capable, .relevant = relevant, .borrowed = borrowed, .generators = generators };
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

    pub fn node(self: *Engine, site: M.Site, node_value: M.Node) A.Error!usize {
        if (self.sites.get(site)) |id| {
            switch (self.nodes.items[id]) {
                .object => |*o| {
                    o.many = o.many or node_value.object.many;
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
        return self.node(.{ .frame = frame, .category = category, .value = site }, .{ .object = .{ .type = t, .many = repeated } });
    }
    pub fn address(self: *Engine, cell: M.Cell) A.Error!Value {
        const id = try self.node(.{ .frame = cell.object, .category = .address, .value = cell.field }, .{ .address = cell });
        return Value.one(self.a, id);
    }
    pub fn many(self: *Engine, id: usize) bool {
        return switch (self.nodes.items[id]) {
            .object => |o| o.many,
            .callable => |c| c.many,
            .address => false,
        };
    }
    pub fn write(self: *Engine, memory: *M.Memory, cell: M.Cell, value: Value, strong: bool) A.Error!void {
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
        if (t.optionalChild()) |child| return self.unknown(memory, cell, child);
        var value: Value = .{};
        if (t == .address) {
            const holder = try self.node(.{ .frame = cell.object, .category = .unknown, .value = cell.field }, .{ .object = .{ .type = null, .many = false, .unknown_parent = cell.object, .external = true } });
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
                const id = try self.node(.{ .frame = cell.object, .category = .unknown, .value = cell.field }, .{ .object = .{ .type = t, .many = false, .unknown_parent = cell.object, .external = true } });
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
    pub fn elements(self: *Engine, memory: M.Memory, base: Value) A.Error!Value {
        var result: Value = .{};
        for (base.nodes) |object_value| {
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
        const id = self.frames.items.len;
        const frame = try self.storage.create(M.Frame);
        const repeated = if (parent) |caller| self.repeatedCall(caller, site) else false;
        frame.* = .{ .function = function, .parent = parent, .site = site, .repeated = repeated, .locals = try self.object(id, .local, 0, null, repeated) };
        try self.frames.append(self.storage, frame);
        return id;
    }
    pub fn invoke(self: *Engine, parent: usize, site: usize, function: usize, arguments: []const Value, memory: *M.Memory) A.Error!Value {
        if (!self.relevant[function]) return .{};
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
            if (!data) return .{};
        }
        // Recursive SCCs share a summary frame and monotonically join their
        // incoming values/memory. No unbounded stack of abstract environments.
        var ancestor: ?usize = parent;
        while (ancestor) |id| {
            const frame = self.frames.items[id];
            if (frame.function == function and frame.active) {
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
                    frame.changed = !Value.eql(joined, value.*) or frame.changed;
                    value.* = joined;
                }
                frame.changed = try M.joinMemoryOwned(frame.allocator, &frame.incoming, memory.*) or frame.changed;
                _ = try M.joinMemory(self.a, memory, frame.output);
                return frame.returned;
            }
            ancestor = frame.parent;
        }
        for (self.frames.items, 0..) |frame, id| if (frame.parent == parent and frame.site == site and frame.function == function) {
            if (self.repeatedCall(parent, site) and !frame.repeated) self.repeatFrame(id);
            return self.evaluate(id, arguments, memory);
        };
        return self.evaluate(try self.newFrame(function, parent, site), arguments, memory);
    }
    fn repeatedCall(self: *Engine, parent: usize, site: usize) bool {
        const caller = self.frames.items[parent];
        return caller.recursive or caller.repeated or Machine.inLoop(self.program.functions[caller.function], site >> 32);
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
    pub fn indirect(self: *Engine, parent: usize, site: usize, callee: Value, arguments: []const Value, return_type: Ir.Type, memory: *M.Memory) A.Error!Value {
        var returned: Value = .{};
        var merged: M.Memory = .empty;
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
            returned = try Value.join(returned, try self.invoke(parent, site, node_value.callable.function, inputs, &branch), self.a);
            _ = try M.joinMemory(self.a, &merged, branch);
        }
        if (any) {
            memory.* = merged;
        } else {
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
        var scratch = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer scratch.deinit();
        const caller_allocator = self.a;
        self.a = scratch.allocator();
        defer self.a = caller_allocator;
        const frame = self.frames.items[id];
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
        frame.returned = .{};
        frame.active = true;
        defer frame.active = false;
        while (true) {
            frame.changed = false;
            const f = self.program.functions[frame.function];
            const entries = try self.a.alloc(?M.State, f.blocks.len);
            @memset(entries, null);
            var initial: M.State = .{ .memory = try M.cloneMemory(self.a, frame.incoming) };
            for (frame.arguments, 0..) |argument, index| try initial.set(self.a, index, argument);
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
                    for (0..block.instructions.len + 1) |index| {
                        for (f.borrow_ends) |end| if (end.block == block_id and end.instruction == index) try self.scopeEnd(id, end, &state);
                        if (self.diagnostic != null) return .{};
                        if (index < block.instructions.len) try Machine.step(self, id, block_id, index, block.instructions[index], &state);
                        if (self.diagnostic != null) return .{};
                    }
                    switch (block.terminator) {
                        .return_value, .return_void => {
                            const output: Value = if (block.terminator == .return_value) state.get(block.terminator.return_value) else .{};
                            if (block.terminator == .return_value and M.capable(self.capable, f.return_type)) try self.escape(id, null, output, state.memory, block.terminator_position, true);
                            try self.externals(id, null, &state, block.terminator_position);
                            const joined = try Value.join(frame.returned, output, self.a);
                            frame.changed = !Value.eql(joined, frame.returned) or frame.changed;
                            frame.returned = joined;
                            frame.changed = try M.joinMemory(self.a, &frame.output, state.memory) or frame.changed;
                        },
                        .jump => |target| if (try self.joinEntry(&entries[target], state)) {
                            pending[target] = true;
                        },
                        .branch => |branch| {
                            if (try self.joinEntry(&entries[branch.then_block], state)) pending[branch.then_block] = true;
                            if (try self.joinEntry(&entries[branch.else_block], state)) pending[branch.else_block] = true;
                        },
                        else => {},
                    }
                }
                if (!processed) break;
            }
            if (!frame.recursive or !frame.changed) break;
        }
        memory.* = try frame.output.promote(self.a, caller_allocator);
        return frame.returned.promote(self.a, caller_allocator);
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
            const value: Value = if (binding.local) |local| state.memory.get(.{ .object = self.frames.items[frame].locals, .field = local }) orelse .{} else if (binding.value) |v| state.get(v) else .{};
            try self.escape(frame, end.lifetimes, value, state.memory, end.position, false);
        }
    }
    fn externals(self: *Engine, frame: usize, lifetimes: ?[]const usize, state: *M.State, position: ?Source.Position) A.Error!void {
        if (!self.borrowed[self.frames.items[frame].function]) return;
        for (self.frames.items[frame].arguments) |argument| try self.escape(frame, lifetimes, argument, state.memory, position, false);
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
