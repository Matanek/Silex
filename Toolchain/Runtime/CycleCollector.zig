const std = @import("std");
const builtin = @import("builtin");

const type_base_mask: u64 = 0x00ffffff;
const optional_depth_shift: u6 = 24;
const structure_base: u64 = 0x100;
const function_base: u64 = 0x00400000;
const function_end: u64 = 0x00800000;
const scalar_limit: u64 = 13;
const entry_words: usize = 4;
const class_header_words: usize = 4;
const list_header_words: usize = 5;
const page_bytes: usize = 0x4000;

const AllocateFunction = *const fn (usize) callconv(.c) ?[*]u64;
const ReleaseFunction = *const fn ([*]u8, usize) callconv(.c) void;

fn optionalChild(type_value: u64) ?u64 {
    const depth = type_value >> optional_depth_shift;
    return if (depth == 0) null else ((depth - 1) << optional_depth_shift) | (type_value & type_base_mask);
}

const Kind = enum(u64) { value, class, protocol, list, array, enumeration };

const Node = struct {
    address: [*]u64,
    type_value: u64,
    byte_count: usize,
    internal: usize,
    feedback_internal: usize,
    active: bool,
    kind: Kind,
};

const Context = struct {
    model: [*]const u64,
    nodes: [*]Node,
    count: usize,
    capacity: usize,
    node_byte_count: usize,
    allocate_function: AllocateFunction,
    release_function: ReleaseFunction,

    fn entry(self: *const Context, type_value: u64) [*]const u64 {
        return self.model + 1 + @as(usize, @intCast(type_value - structure_base)) * entry_words;
    }

    fn width(self: *const Context, type_value: u64) usize {
        if (optionalChild(type_value)) |child| return 1 + self.width(child);
        if (type_value <= scalar_limit) return if (type_value == 0) 0 else 1;
        if (type_value >= function_base and type_value < function_end) return 2;
        return @intCast(self.entry(type_value)[1]);
    }

    fn data(self: *const Context, entry_value: [*]const u64) [*]const u64 {
        return self.model + @as(usize, @intCast(entry_value[2]));
    }

    fn allocate(self: *const Context, byte_count: usize) ?[*]u8 {
        return @ptrCast(self.allocate_function(byte_count) orelse return null);
    }

    fn release(self: *const Context, address: [*]u8, byte_count: usize) void {
        self.release_function(address, byte_count);
    }
};

const AddResult = enum { added, existing, failed };

pub fn main() void {}

/// Operation 0 proves that the candidate belongs to a closed unreachable
/// component and claims it as the component's finalization entry point.
/// Operation 1 releases the temporary tracing context after ordinary generated
/// finalizers have cascaded through the component.
export fn silex_cycle(operation: u64, value: u64, model: [*]const u64, type_value: u64) callconv(.c) u64 {
    return cycle(operation, value, model, type_value, systemAllocate, systemRelease);
}

export fn silex_cycle_x64(
    operation: u64,
    value: u64,
    model: [*]const u64,
    type_value: u64,
    allocate_function: AllocateFunction,
    release_function: ReleaseFunction,
) callconv(.c) u64 {
    return cycle(operation, value, model, type_value, allocate_function, release_function);
}

export fn silex_cycle_arm64(
    operation: u64,
    value: u64,
    model: [*]const u64,
    type_value: u64,
    allocate_function: AllocateFunction,
    release_function: ReleaseFunction,
) callconv(.c) u64 {
    return cycle(operation, value, model, type_value, allocate_function, release_function);
}

fn cycle(
    operation: u64,
    value: u64,
    model: [*]const u64,
    type_value: u64,
    allocate_function: AllocateFunction,
    release_function: ReleaseFunction,
) u64 {
    if (operation != 0) {
        finish(@ptrFromInt(value));
        return 0;
    }
    return @intFromPtr(prepare(@ptrFromInt(value), model, type_value, allocate_function, release_function) orelse return 0);
}

fn prepare(
    candidate: [*]u64,
    model: [*]const u64,
    type_value: u64,
    allocate_function: AllocateFunction,
    release_function: ReleaseFunction,
) ?*Context {
    const state: *u64 = @ptrCast(candidate + 3);
    if (@cmpxchgStrong(u64, state, 0, 2, .acq_rel, .acquire) != null) return null;
    const candidate_roots: *u64 = @ptrCast(candidate + 1);
    // A retain may race the drop that selected this candidate. Reject it
    // before tracing so pooled objects can safely mutate after retaining a root.
    if (@atomicLoad(u64, candidate_roots, .acquire) != 0) return reject(candidate, null, 4);
    var probe: Context = undefined;
    probe.model = model;
    probe.nodes = undefined;
    probe.count = 0;
    probe.capacity = 0;
    probe.node_byte_count = 0;
    probe.allocate_function = allocate_function;
    probe.release_function = release_function;
    const graph_kind = classGraphKind(&probe, candidate, type_value, 0);
    if (graph_kind != .class_graph) return reject(candidate, null, if (graph_kind == .none) 4 else 0);
    const context_mapping: [*]u8 = @ptrCast(allocate_function(page_bytes) orelse return reject(candidate, null, 0));
    const context: *Context = @ptrCast(@alignCast(context_mapping));
    const node_mapping: [*]u8 = @ptrCast(allocate_function(page_bytes) orelse {
        release_function(context_mapping, page_bytes);
        return reject(candidate, null, 0);
    });
    context.model = model;
    context.nodes = @ptrCast(@alignCast(node_mapping));
    context.count = 0;
    context.capacity = page_bytes / @sizeOf(Node);
    context.node_byte_count = page_bytes;
    context.allocate_function = allocate_function;
    context.release_function = release_function;
    if (addNode(context, candidate, type_value, false) != .added or !traceClass(context, candidate, type_value)) {
        releaseClaims(context);
        discard(context);
        return reject(candidate, null, 0);
    }
    for (context.nodes[0..context.count]) |node| {
        const roots: *u64 = @ptrCast(node.address + 1);
        const edges: *u64 = @ptrCast(node.address + 2);
        const root_count: usize = @intCast(@atomicLoad(u64, roots, .acquire));
        const edge_count: usize = @intCast(@atomicLoad(u64, edges, .acquire));
        if (root_count != 0 or edge_count != node.internal) {
            releaseClaims(context);
            discard(context);
            // A concurrent retain or topology mutation invalidates the proof.
            // Cache the rejection until an edge retain/drop marks it dirty.
            return reject(candidate, null, 4);
        }
    }
    // The entry object is finalized by the generated drop that requested the
    // trace. Other classes become cycle members (3): their cascading edge drop
    // may claim ordinary finalization once their count reaches zero. Lists are
    // released back to state 0 so their normal cascading drop can unmap them.
    for (context.nodes[0..context.count]) |node| {
        if (node.feedback_internal != 0) {
            const edges: *u64 = @ptrCast(node.address + 2);
            _ = @atomicRmw(u64, edges, .Sub, node.feedback_internal, .acq_rel);
        }
        const node_state = statePointer(node.address, node.kind);
        const committed: u64 = if (node.address == candidate) 1 else if (node.kind == .class) 3 else 0;
        @atomicStore(u64, node_state, committed, .release);
    }
    return context;
}

fn reject(candidate: [*]u64, result: ?*Context, state_value: u64) ?*Context {
    const state: *u64 = @ptrCast(candidate + 3);
    @atomicStore(u64, state, state_value, .release);
    return result;
}

const GraphKind = enum { none, class_graph, unsupported };

const TypePath = struct {
    values: [256]u64 = undefined,
    count: usize = 0,

    fn contains(self: *const TypePath, value: u64) bool {
        for (self.values[0..self.count]) |current| if (current == value) return true;
        return false;
    }

    fn push(self: *TypePath, value: u64) void {
        self.values[self.count] = value;
        self.count += 1;
    }

    fn pop(self: *TypePath) void {
        self.count -= 1;
    }
};

fn classGraphKind(context: *const Context, object: [*]u64, type_value: u64, depth: usize) GraphKind {
    if (depth > 64) return .unsupported;
    const data = context.data(context.entry(type_value));
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const field_count: usize = @intCast(data[cursor + 2]);
        cursor += 3;
        if (structure == object[0]) {
            var path: TypePath = undefined;
            path.count = 0;
            return fieldsGraphKind(context, data + cursor, field_count, object[0], &path, depth + 1);
        }
        cursor += field_count;
    }
    return .unsupported;
}

fn fieldsGraphKind(context: *const Context, fields: [*]const u64, count: usize, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
    var result: GraphKind = .none;
    for (0..count) |index| switch (typeGraphKind(context, fields[index], target_structure, path, depth + 1)) {
        .none => {},
        .class_graph => result = .class_graph,
        .unsupported => return .unsupported,
    };
    return result;
}

fn typeGraphKind(context: *const Context, type_value: u64, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
    if (depth > path.values.len) return .unsupported;
    if (optionalChild(type_value)) |child| return typeGraphKind(context, child, target_structure, path, depth + 1);
    if (type_value <= scalar_limit) return .none;
    if (type_value >= function_base and type_value < function_end) return .none;
    if (type_value < structure_base or type_value >= function_base) return .unsupported;
    if (path.contains(type_value)) return .none;
    if (path.count == path.values.len) return .unsupported;
    path.push(type_value);
    defer path.pop();
    const entry_value = context.entry(type_value);
    const data = context.data(entry_value);
    const kind: Kind = @enumFromInt(entry_value[0]);
    if (kind == .class) return classTypeGraphKind(context, data, target_structure, path, depth + 1);
    if (kind == .list) return typeGraphKind(context, data[0], target_structure, path, depth + 1);
    if (kind == .protocol) return protocolGraphKind(context, data, target_structure, path, depth + 1);
    if (kind == .value) return fieldsGraphKind(context, data, @intCast(entry_value[3]), target_structure, path, depth + 1);
    if (kind == .array) return typeGraphKind(context, data[0], target_structure, path, depth + 1);
    return enumerationGraphKind(context, data, target_structure, path, depth + 1);
}

fn finish(context: *Context) void {
    discard(context);
}

fn classTypeGraphKind(context: *const Context, data: [*]const u64, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
    var result: GraphKind = .none;
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const field_count: usize = @intCast(data[cursor + 2]);
        cursor += 3;
        if (structure == target_structure) return .class_graph;
        result = mergeGraphKind(result, fieldsGraphKind(context, data + cursor, field_count, target_structure, path, depth + 1));
        if (result == .unsupported) return result;
        cursor += field_count;
    }
    return result;
}

fn protocolGraphKind(context: *const Context, data: [*]const u64, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
    var result: GraphKind = .none;
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        cursor += 1;
        result = mergeGraphKind(result, typeGraphKind(context, data[cursor], target_structure, path, depth + 1));
        if (result == .unsupported) return result;
        cursor += 1;
    }
    return result;
}

fn enumerationGraphKind(context: *const Context, data: [*]const u64, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
    var result: GraphKind = .none;
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const count: usize = @intCast(data[cursor]);
        cursor += 1;
        result = mergeGraphKind(result, fieldsGraphKind(context, data + cursor, count, target_structure, path, depth + 1));
        if (result == .unsupported) return result;
        cursor += count;
    }
    return result;
}

fn mergeGraphKind(left: GraphKind, right: GraphKind) GraphKind {
    if (left == .unsupported or right == .unsupported) return .unsupported;
    if (left == .class_graph or right == .class_graph) return .class_graph;
    return .none;
}

fn discard(context: *Context) void {
    context.release(@ptrCast(context.nodes), context.node_byte_count);
    context.release(@ptrCast(context), page_bytes);
}

fn addNode(context: *Context, address: [*]u64, type_value: u64, incoming: bool) AddResult {
    for (context.nodes[0..context.count]) |*node| {
        if (node.address == address) {
            if (incoming) {
                node.internal += 1;
                if (node.active) node.feedback_internal += 1;
            }
            return .existing;
        }
    }
    const entry_value = context.entry(type_value);
    const kind: Kind = @enumFromInt(entry_value[0]);
    if (kind != .class and kind != .list) return .failed;
    const state = statePointer(address, kind);
    const already_claimed_candidate = context.count == 0 and kind == .class;
    if (!already_claimed_candidate and !claimMember(state)) return .failed;
    if (context.count == context.capacity and !grow(context)) {
        if (!already_claimed_candidate) @atomicStore(u64, state, 0, .release);
        return .failed;
    }
    const byte_count = if (kind == .class)
        classBytes(address, context.data(entry_value)) orelse {
            if (!already_claimed_candidate) @atomicStore(u64, state, 0, .release);
            return .failed;
        }
    else
        @as(usize, @intCast(address[3]));
    const node = &context.nodes[context.count];
    node.address = address;
    node.type_value = type_value;
    node.byte_count = byte_count;
    node.internal = @intFromBool(incoming);
    node.feedback_internal = 0;
    node.active = false;
    node.kind = kind;
    context.count += 1;
    return .added;
}

fn claimMember(state: *u64) bool {
    var expected: u64 = 0;
    while (true) {
        const observed = @cmpxchgWeak(u64, state, expected, 2, .acq_rel, .acquire) orelse return true;
        if (observed != 0 and observed != 4) return false;
        expected = observed;
    }
}

fn statePointer(address: [*]u64, kind: Kind) *u64 {
    const offset: usize = if (kind == .class) 3 else 4;
    return @ptrCast(address + offset);
}

fn releaseClaims(context: *Context) void {
    for (context.nodes[0..context.count]) |node| {
        const state = statePointer(node.address, node.kind);
        if (@atomicLoad(u64, state, .acquire) == 2) @atomicStore(u64, state, 0, .release);
    }
}

fn grow(context: *Context) bool {
    const new_byte_count = context.node_byte_count * 2;
    const new_capacity = new_byte_count / @sizeOf(Node);
    const mapping = context.allocate(new_byte_count) orelse return false;
    const nodes: [*]Node = @ptrCast(@alignCast(mapping));
    for (context.nodes[0..context.count], 0..) |node, index| nodes[index] = node;
    context.release(@ptrCast(context.nodes), context.node_byte_count);
    context.nodes = nodes;
    context.capacity = new_capacity;
    context.node_byte_count = new_byte_count;
    return true;
}

fn traceValue(context: *Context, value: [*]u64, type_value: u64) bool {
    if (optionalChild(type_value)) |child| {
        if (value[0] == 0) return true;
        return traceValue(context, value + 1, child);
    }
    if (type_value <= scalar_limit) return true;
    if (type_value >= function_base and type_value < function_end) return true;
    if (type_value < structure_base or type_value >= function_base) return false;
    const entry_value = context.entry(type_value);
    const data = context.data(entry_value);
    const kind: Kind = @enumFromInt(entry_value[0]);
    if (kind == .value) return traceFields(context, value, data, @intCast(entry_value[3]));
    if (kind == .class) {
        // Concurrent publication may expose the aggregate tag before its payload.
        const address = value[0];
        if (address == 0) return false;
        return traceClassEdge(context, @ptrFromInt(address), type_value);
    }
    if (kind == .protocol) return traceProtocol(context, value, data);
    if (kind == .list) {
        // Read once so a concurrent clear cannot invalidate a checked address.
        const address = value[0];
        if (address == 0) return false;
        return traceListEdge(context, @ptrFromInt(address), type_value, data[0]);
    }
    if (kind == .array) return traceArray(context, value, data[0], @intCast(data[1]));
    return traceEnumeration(context, value, data);
}

fn traceClassEdge(context: *Context, object: [*]u64, type_value: u64) bool {
    return switch (addNode(context, object, type_value, true)) {
        .existing => true,
        .failed => false,
        .added => traceClass(context, object, type_value),
    };
}

fn traceClass(context: *Context, object: [*]u64, type_value: u64) bool {
    const node = findNode(context, object) orelse return false;
    node.active = true;
    // Recursive tracing may grow the node mapping. Never retain a pointer into
    // that mapping across recursion: grow() deliberately unmaps the old one.
    defer {
        if (findNode(context, object)) |current| current.active = false;
    }
    const data = context.data(context.entry(type_value));
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const field_count: usize = @intCast(data[cursor + 2]);
        cursor += 3;
        if (structure == object[0]) return traceFields(context, object + class_header_words, data + cursor, field_count);
        cursor += field_count;
    }
    return false;
}

fn traceListEdge(context: *Context, list: [*]u64, type_value: u64, element_type: u64) bool {
    switch (addNode(context, list, type_value, true)) {
        .existing => return true,
        .failed => return false,
        .added => {},
    }
    const node = findNode(context, list) orelse return false;
    node.active = true;
    // traceValue() can discover enough nodes to grow and relocate the mapping.
    defer {
        if (findNode(context, list)) |current| current.active = false;
    }
    const width = context.width(element_type);
    for (0..@as(usize, @intCast(list[0]))) |index| {
        if (!traceValue(context, list + list_header_words + index * width, element_type)) return false;
    }
    return true;
}

fn traceFields(context: *Context, value: [*]u64, fields: [*]const u64, count: usize) bool {
    var offset: usize = 0;
    for (0..count) |index| {
        if (!traceValue(context, value + offset, fields[index])) return false;
        offset += context.width(fields[index]);
    }
    return true;
}

fn findNode(context: *Context, address: [*]u64) ?*Node {
    for (context.nodes[0..context.count]) |*node| if (node.address == address) return node;
    return null;
}

fn traceProtocol(context: *Context, value: [*]u64, data: [*]const u64) bool {
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const concrete = data[cursor + 1];
        cursor += 2;
        if (structure == value[0]) return traceValue(context, value + 1, concrete);
    }
    return false;
}

fn traceArray(context: *Context, value: [*]u64, element_type: u64, count: usize) bool {
    const width = context.width(element_type);
    for (0..count) |index| if (!traceValue(context, value + index * width, element_type)) return false;
    return true;
}

fn traceEnumeration(context: *Context, value: [*]u64, data: [*]const u64) bool {
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |variant| {
        const count: usize = @intCast(data[cursor]);
        cursor += 1;
        if (variant == value[0]) return traceFields(context, value + 1, data + cursor, count);
        cursor += count;
    }
    return false;
}

fn classBytes(object: [*]u64, data: [*]const u64) ?usize {
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const structure = data[cursor];
        const width: usize = @intCast(data[cursor + 1]);
        const field_count: usize = @intCast(data[cursor + 2]);
        cursor += 3;
        if (structure == object[0]) return (class_header_words + width) * @sizeOf(u64);
        cursor += field_count;
    }
    return null;
}

fn systemAllocate(byte_count: usize) callconv(.c) ?[*]u64 {
    if (comptime builtin.cpu.arch != .aarch64 or builtin.os.tag != .macos) return null;
    var result: usize = 0;
    asm volatile ("svc #0x80"
        : [result] "={x0}" (result),
        : [address] "{x0}" (@as(usize, 0)),
          [size] "{x1}" (byte_count),
          [protection] "{x2}" (@as(usize, 3)),
          [flags] "{x3}" (@as(usize, 0x1002)),
          [descriptor] "{x4}" (~@as(usize, 0)),
          [offset] "{x5}" (@as(usize, 0)),
          [number] "{x16}" (@as(usize, 197)),
        : .{ .memory = true });
    if (@as(isize, @bitCast(result)) < 0) return null;
    return @ptrFromInt(result);
}

fn systemRelease(address: [*]u8, byte_count: usize) callconv(.c) void {
    if (comptime builtin.cpu.arch != .aarch64 or builtin.os.tag != .macos) return;
    _ = asm volatile ("svc #0x80"
        : [result] "={x0}" (-> usize),
        : [address] "{x0}" (@intFromPtr(address)),
          [size] "{x1}" (byte_count),
          [number] "{x16}" (@as(usize, 73)),
        : .{ .memory = true });
}

fn testAllocate(byte_count: usize) callconv(.c) ?[*]u64 {
    if (!builtin.is_test) return null;
    const words = std.testing.allocator.alloc(u64, byte_count / @sizeOf(u64)) catch return null;
    return words.ptr;
}

fn testRelease(address: [*]u8, byte_count: usize) callconv(.c) void {
    if (!builtin.is_test) return;
    const words: [*]u64 = @ptrCast(@alignCast(address));
    std.testing.allocator.free(words[0 .. byte_count / @sizeOf(u64)]);
}

test "X64 callbacks prove and commit a direct class cycle" {
    const class_type = structure_base;
    const optional_class_type = (@as(u64, 1) << optional_depth_shift) | class_type;
    const structure: u64 = 42;
    const model = [_]u64{
        1,
        @intFromEnum(Kind.class),
        1,
        5,
        0,
        1,
        structure,
        2,
        1,
        optional_class_type,
    };
    var first = [_]u64{ structure, 0, 1, 0, 1, 0 };
    var second = [_]u64{ structure, 0, 1, 0, 1, 0 };
    first[5] = @intFromPtr(&second);
    second[5] = @intFromPtr(&first);

    const context = silex_cycle_x64(
        0,
        @intFromPtr(&first),
        &model,
        class_type,
        testAllocate,
        testRelease,
    );
    try std.testing.expect(context != 0);
    try std.testing.expectEqual(@as(u64, 1), first[3]);
    try std.testing.expectEqual(@as(u64, 3), second[3]);
    try std.testing.expectEqual(@as(u64, 0), first[2]);
    try std.testing.expectEqual(@as(u64, 1), second[2]);
    _ = silex_cycle_x64(1, context, &model, class_type, testAllocate, testRelease);
}

test "X64 callbacks reject a candidate retained before tracing" {
    const class_type = structure_base;
    const optional_class_type = (@as(u64, 1) << optional_depth_shift) | class_type;
    const structure: u64 = 42;
    const model = [_]u64{
        1,
        @intFromEnum(Kind.class),
        1,
        5,
        0,
        1,
        structure,
        2,
        1,
        optional_class_type,
    };
    var candidate = [_]u64{ structure, 1, 1, 0, 1, 0 };
    candidate[5] = @intFromPtr(&candidate);

    try std.testing.expectEqual(@as(u64, 0), silex_cycle_x64(
        0,
        @intFromPtr(&candidate),
        &model,
        class_type,
        testAllocate,
        testRelease,
    ));
    try std.testing.expectEqual(@as(u64, 4), candidate[3]);
    try std.testing.expectEqual(@as(u64, 1), candidate[2]);
}

test "X64 callbacks reject a transient null class edge" {
    const class_type = structure_base;
    const optional_class_type = (@as(u64, 1) << optional_depth_shift) | class_type;
    const structure: u64 = 42;
    const model = [_]u64{
        1,
        @intFromEnum(Kind.class),
        1,
        5,
        0,
        1,
        structure,
        2,
        1,
        optional_class_type,
    };
    // The optional tag is visible while its class payload is still null.
    var candidate = [_]u64{ structure, 0, 1, 0, 1, 0 };

    try std.testing.expectEqual(@as(u64, 0), silex_cycle_x64(
        0,
        @intFromPtr(&candidate),
        &model,
        class_type,
        testAllocate,
        testRelease,
    ));
    try std.testing.expectEqual(@as(u64, 0), candidate[3]);
    try std.testing.expectEqual(@as(u64, 1), candidate[2]);
}

test "X64 callbacks reject an edge removed during tracing" {
    const class_type = structure_base;
    const optional_class_type = (@as(u64, 1) << optional_depth_shift) | class_type;
    const structure: u64 = 42;
    const model = [_]u64{
        1,
        @intFromEnum(Kind.class),
        1,
        5,
        0,
        1,
        structure,
        2,
        1,
        optional_class_type,
    };
    var candidate = [_]u64{ structure, 0, 0, 0, 1, 0 };
    var detached = [_]u64{ structure, 0, 0, 0, 0, 0 };
    candidate[5] = @intFromPtr(&detached);

    try std.testing.expectEqual(@as(u64, 0), silex_cycle_x64(
        0,
        @intFromPtr(&candidate),
        &model,
        class_type,
        testAllocate,
        testRelease,
    ));
    try std.testing.expectEqual(@as(u64, 4), candidate[3]);
    try std.testing.expectEqual(@as(u64, 0), detached[3]);
}

test "X64 callbacks cache a negative proof for an externally reached cycle" {
    const class_type = structure_base;
    const optional_class_type = (@as(u64, 1) << optional_depth_shift) | class_type;
    const structure: u64 = 42;
    const model = [_]u64{
        1,
        @intFromEnum(Kind.class),
        1,
        5,
        0,
        1,
        structure,
        2,
        1,
        optional_class_type,
    };
    var first = [_]u64{ structure, 0, 1, 0, 1, 0 };
    var second = [_]u64{ structure, 1, 1, 0, 1, 0 };
    first[5] = @intFromPtr(&second);
    second[5] = @intFromPtr(&first);

    try std.testing.expectEqual(@as(u64, 0), silex_cycle_x64(
        0,
        @intFromPtr(&first),
        &model,
        class_type,
        testAllocate,
        testRelease,
    ));
    try std.testing.expectEqual(@as(u64, 4), first[3]);
    try std.testing.expectEqual(@as(u64, 0), second[3]);
}
