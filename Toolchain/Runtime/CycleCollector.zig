const std = @import("std");
const builtin = @import("builtin");

const TestState = if (builtin.is_test) struct {
    var traced_values: usize = 0;
    var field_plans: usize = 0;
} else struct {};

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
const field_plan_capacity = 64;
const field_step_capacity = 512;

const FieldPlan = struct {
    key: usize = 0,
    field_count: usize = 0,
    first_step: usize = 0,
    step_count: usize = 0,
};

const FieldStep = struct { offset: usize, type_value: u64 };

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
    internal: usize,
    feedback_internal: usize,
    active: bool,
    live: bool,
};

// Type-only proofs must not reserve the traversal cache on the native stack.
const TypeModel = struct {
    model: [*]const u64,

    fn entry(self: *const TypeModel, type_value: u64) [*]const u64 {
        return self.model + 1 + @as(usize, @intCast(type_value - structure_base)) * entry_words;
    }

    fn width(self: *const TypeModel, type_value: u64) usize {
        const depth: usize = @intCast(type_value >> optional_depth_shift);
        const base = type_value & type_base_mask;
        const payload: usize = if (base <= scalar_limit)
            @intFromBool(base != 0)
        else if (base >= function_base and base < function_end)
            3
        else
            @intCast(self.entry(base)[1]);
        return depth + payload;
    }

    fn data(self: *const TypeModel, entry_value: [*]const u64) [*]const u64 {
        return self.model + @as(usize, @intCast(entry_value[2]));
    }
};

const Context = struct {
    types: TypeModel,
    nodes: [*]Node,
    count: usize,
    capacity: usize,
    node_byte_count: usize,
    marking: bool,
    allocate_function: AllocateFunction,
    release_function: ReleaseFunction,
    field_plans: [field_plan_capacity]FieldPlan,
    occupied_field_plans: u64,
    field_steps: [field_step_capacity]FieldStep,
    field_step_count: usize,

    fn resetFieldPlans(self: *Context) void {
        // Unoccupied entries are never read. Besides avoiding cold clearing,
        // this keeps payload initialization independent of libc zeroing stubs.
        self.occupied_field_plans = 0;
        self.field_step_count = 0;
    }

    fn entry(self: *const Context, type_value: u64) [*]const u64 {
        return self.types.entry(type_value);
    }

    fn width(self: *const Context, type_value: u64) usize {
        return self.types.width(type_value);
    }

    fn data(self: *const Context, entry_value: [*]const u64) [*]const u64 {
        return self.types.data(entry_value);
    }

    fn allocate(self: *const Context, byte_count: usize) ?[*]u8 {
        return @ptrCast(self.allocate_function(byte_count) orelse return null);
    }

    fn release(self: *const Context, address: [*]u8, byte_count: usize) void {
        self.release_function(address, byte_count);
    }
};

comptime {
    if (@sizeOf(Context) > page_bytes) @compileError("cycle context must fit its allocation page");
}

const AddResult = enum { added, existing, failed };

pub fn main() void {}

/// Operation 0 proves that the candidate's type may cycle and then proves that
/// the candidate belongs to an unreachable component. Operation 2 reuses the
/// compiler's conservative type proof and performs only the reachability
/// trial. Both claim the candidate as the component's finalization entry point.
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
    if (operation == 1) {
        finish(@ptrFromInt(value));
        return 0;
    }
    return @intFromPtr(prepare(@ptrFromInt(value), model, type_value, operation == 2, allocate_function, release_function) orelse return 0);
}

fn prepare(
    candidate: [*]u64,
    model: [*]const u64,
    type_value: u64,
    cycle_prechecked: bool,
    allocate_function: AllocateFunction,
    release_function: ReleaseFunction,
) ?*Context {
    const state: *u64 = @ptrCast(candidate + 3);
    if (@cmpxchgStrong(u64, state, 0, 2, .acq_rel, .acquire) != null) return null;
    const candidate_roots: *u64 = @ptrCast(candidate + 1);
    // A retain may race the drop that selected this candidate. Reject it
    // before tracing so pooled objects can safely mutate after retaining a root.
    if (@atomicLoad(u64, candidate_roots, .acquire) != 0) return reject(candidate, null, 4);
    if (!cycle_prechecked) {
        const probe: TypeModel = .{ .model = model };
        const graph_kind = classGraphKind(&probe, candidate, type_value, 0);
        if (graph_kind != .class_graph) return reject(candidate, null, if (graph_kind == .none) 4 else 0);
    }
    const context_mapping: [*]u8 = @ptrCast(allocate_function(page_bytes) orelse return reject(candidate, null, 0));
    const context: *Context = @ptrCast(@alignCast(context_mapping));
    const node_mapping: [*]u8 = @ptrCast(allocate_function(page_bytes) orelse {
        release_function(context_mapping, page_bytes);
        return reject(candidate, null, 0);
    });
    context.types = .{ .model = model };
    context.nodes = @ptrCast(@alignCast(node_mapping));
    context.count = 0;
    context.capacity = page_bytes / @sizeOf(Node);
    context.node_byte_count = page_bytes;
    context.marking = false;
    context.allocate_function = allocate_function;
    context.release_function = release_function;
    context.resetFieldPlans();
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
        if (edge_count < node.internal) {
            releaseClaims(context);
            discard(context);
            // A concurrent retain or topology mutation invalidates the proof.
            // Cache the rejection until an edge retain/drop marks it dirty.
            return reject(candidate, null, 4);
        }
        if (root_count != 0 or edge_count > node.internal) {
            context.marking = true;
            const marked = traceClassEdge(context, node.address, node.type_value);
            if (!marked) {
                releaseClaims(context);
                discard(context);
                return reject(candidate, null, 0);
            }
        }
    }
    if (context.nodes[0].live) {
        releaseClaims(context);
        discard(context);
        return reject(candidate, null, 4);
    }
    // The entry object is finalized by the generated drop that requested the
    // trace. Other classes become cycle members (3): their cascading edge drop
    // may claim ordinary finalization once their count reaches zero. Value
    // containers keep their ordinary ownership counts during this cascade.
    for (context.nodes[0..context.count]) |node| {
        if (node.live) {
            @atomicStore(u64, statePointer(node.address), 0, .release);
            continue;
        }
        if (node.feedback_internal != 0) {
            const edges: *u64 = @ptrCast(node.address + 2);
            _ = @atomicRmw(u64, edges, .Sub, node.feedback_internal, .acq_rel);
        }
        const node_state = statePointer(node.address);
        const committed: u64 = if (node.address == candidate) 1 else 3;
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

fn classGraphKind(context: *const TypeModel, object: [*]u64, type_value: u64, depth: usize) GraphKind {
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

fn fieldsGraphKind(context: *const TypeModel, fields: [*]const u64, count: usize, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
    var result: GraphKind = .none;
    for (0..count) |index| switch (typeGraphKind(context, fields[index], target_structure, path, depth + 1)) {
        .none => {},
        .class_graph => result = .class_graph,
        .unsupported => return .unsupported,
    };
    return result;
}

fn typeGraphKind(context: *const TypeModel, type_value: u64, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
    if (depth > path.values.len) return .unsupported;
    if (optionalChild(type_value)) |child| return typeGraphKind(context, child, target_structure, path, depth + 1);
    if (type_value <= scalar_limit) return .none;
    if (type_value >= function_base and type_value < function_end) return .class_graph;
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

fn classTypeGraphKind(context: *const TypeModel, data: [*]const u64, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
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

fn protocolGraphKind(context: *const TypeModel, data: [*]const u64, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
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

fn enumerationGraphKind(context: *const TypeModel, data: [*]const u64, target_structure: u64, path: *TypePath, depth: usize) GraphKind {
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
            if (context.marking) {
                if (node.live) return .existing;
                node.live = true;
                return .added;
            }
            if (incoming) {
                node.internal += 1;
                if (node.active) node.feedback_internal += 1;
            }
            return .existing;
        }
    }
    // A rooted boundary and everything beyond it are live. Keep it outside
    // the trial graph, matching the generated-visitor LLVM collector, so a
    // local drop never walks the application's entire retained scene.
    const roots: *u64 = @ptrCast(address + 1);
    if (@atomicLoad(u64, roots, .acquire) != 0) return .existing;
    if (context.marking) return .failed;
    const entry_value = context.entry(type_value);
    const kind: Kind = @enumFromInt(entry_value[0]);
    if (kind != .class) return .failed;
    const state = statePointer(address);
    const already_claimed_candidate = context.count == 0;
    if (!already_claimed_candidate and !claimMember(state)) return .failed;
    if (context.count == context.capacity and !grow(context)) {
        if (!already_claimed_candidate) @atomicStore(u64, state, 0, .release);
        return .failed;
    }
    const node = &context.nodes[context.count];
    node.address = address;
    node.type_value = type_value;
    node.internal = @intFromBool(incoming);
    node.feedback_internal = 0;
    node.active = false;
    node.live = false;
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

fn statePointer(address: [*]u64) *u64 {
    return @ptrCast(address + 3);
}

fn releaseClaims(context: *Context) void {
    for (context.nodes[0..context.count]) |node| {
        const state = statePointer(node.address);
        if (@atomicLoad(u64, state, .acquire) == 2) @atomicStore(u64, state, 0, .release);
    }
}

fn grow(context: *Context) bool {
    const new_byte_count = context.node_byte_count * 2;
    const new_capacity = new_byte_count / @sizeOf(Node);
    const mapping = context.allocate(new_byte_count) orelse return false;
    const nodes: [*]Node = @ptrCast(@alignCast(mapping));
    for (context.nodes[0..context.count], 0..) |node, index| copyNode(&nodes[index], node);
    context.release(@ptrCast(context.nodes), context.node_byte_count);
    context.nodes = nodes;
    context.capacity = new_capacity;
    context.node_byte_count = new_byte_count;
    return true;
}

fn copyNode(destination: *Node, source: Node) void {
    destination.address = source.address;
    destination.type_value = source.type_value;
    destination.internal = source.internal;
    destination.feedback_internal = source.feedback_internal;
    destination.active = source.active;
    destination.live = source.live;
}

fn traceValue(context: *Context, value: [*]u64, type_value: u64) bool {
    if (builtin.is_test) TestState.traced_values += 1;
    if (optionalChild(type_value)) |child| {
        if (value[0] == 0) return true;
        return traceValue(context, value + 1, child);
    }
    if (type_value <= scalar_limit) return true;
    if (type_value >= function_base and type_value < function_end) {
        if (value[2] == 0) return true;
        const receiver: [*]u64 = @ptrFromInt(value[2]);
        return traceClassEdge(context, receiver, structure_base + receiver[0]);
    }
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
    _ = type_value;
    // Portable ownership retains every element once per list value, including
    // copies sharing their backing storage. The list allocation does not own
    // an additional class edge. Trace each value's elements; deduplicating the
    // storage would undercount edges and cutting its counts could free storage
    // while another finalizer is still iterating it.
    return traceArray(context, list + list_header_words, element_type, @intCast(list[0]));
}

fn traceFields(context: *Context, value: [*]u64, fields: [*]const u64, count: usize) bool {
    if (count == 0) return true;
    if (fieldPlan(context, fields, count)) |plan| {
        // Plans contain metadata offsets, never object addresses. Recursive
        // visits may append other plans but cannot move or replace these steps.
        for (plan.first_step..plan.first_step + plan.step_count) |index| {
            const step = context.field_steps[index];
            if (!traceValue(context, value + step.offset, step.type_value)) return false;
        }
        return true;
    }
    return traceFieldsUncached(context, value, fields, count);
}

fn fieldPlan(context: *Context, fields: [*]const u64, count: usize) ?FieldPlan {
    const key = @intFromPtr(fields);
    var slot = ((key >> 3) ^ (key >> 11)) & (field_plan_capacity - 1);
    var probes: usize = 0;
    while (probes < field_plan_capacity) : (probes += 1) {
        const bit = @as(u64, 1) << @intCast(slot);
        if (context.occupied_field_plans & bit == 0) break;
        const plan = context.field_plans[slot];
        if (plan.key == key and plan.field_count == count) return plan;
        slot = (slot + 1) & (field_plan_capacity - 1);
    }
    if (probes == field_plan_capacity) return null;
    const first = context.field_step_count;
    var offset: usize = 0;
    for (fields[0..count]) |field| {
        var path: TypePath = undefined;
        path.count = 0;
        if (mayOwnClassEdge(context, field, &path)) {
            if (context.field_step_count == field_step_capacity) {
                context.field_step_count = first;
                return null;
            }
            context.field_steps[context.field_step_count] = .{ .offset = offset, .type_value = field };
            context.field_step_count += 1;
        }
        offset += context.width(field);
    }
    const plan: FieldPlan = .{ .key = key, .field_count = count, .first_step = first, .step_count = context.field_step_count - first };
    context.field_plans[slot] = plan;
    context.occupied_field_plans |= @as(u64, 1) << @intCast(slot);
    if (builtin.is_test) TestState.field_plans += 1;
    return plan;
}

fn traceFieldsUncached(context: *Context, value: [*]u64, fields: [*]const u64, count: usize) bool {
    var offset: usize = 0;
    for (0..count) |index| {
        const field = fields[index];
        // Like scalar collection elements, scalar fields cannot carry class
        // edges. Preserve their full optional storage width without visiting
        // each tag and payload during every reachability trial.
        if (field & type_base_mask > scalar_limit) {
            if (!traceValue(context, value + offset, field)) return false;
        }
        offset += context.width(field);
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
    // Scalars (including strings and optionals) cannot own class edges.
    // Their storage length must not become work for a reachability trial.
    if (element_type & type_base_mask <= scalar_limit) return true;
    var path: TypePath = undefined;
    path.count = 0;
    if (!mayOwnClassEdge(context, element_type, &path)) return true;
    const width = context.width(element_type);
    for (0..count) |index| if (!traceValue(context, value + index * width, element_type)) return false;
    return true;
}

// Inspect the element's type once, rather than every value in its storage.
// Unknown/recursive shapes remain conservative; classes and callbacks must
// always be traced, even when their own fields cannot form a cycle.
fn mayOwnClassEdge(context: *const Context, type_value: u64, path: *TypePath) bool {
    const base = type_value & type_base_mask;
    if (base <= scalar_limit) return false;
    if (base >= function_base) return true;
    if (base < structure_base or path.count == path.values.len or path.contains(base)) return true;
    path.push(base);
    defer path.pop();
    const entry_value = context.entry(base);
    const data = context.data(entry_value);
    const kind: Kind = @enumFromInt(entry_value[0]);
    if (kind == .class or kind == .protocol) return true;
    if (kind == .list or kind == .array) return mayOwnClassEdge(context, data[0], path);
    if (kind == .value) {
        for (0..@as(usize, @intCast(entry_value[3]))) |index| {
            if (mayOwnClassEdge(context, data[index], path)) return true;
        }
        return false;
    }
    var cursor: usize = 1;
    for (0..@as(usize, @intCast(data[0]))) |_| {
        const count: usize = @intCast(data[cursor]);
        cursor += 1;
        for (0..count) |index| {
            if (mayOwnClassEdge(context, data[cursor + index], path)) return true;
        }
        cursor += count;
    }
    return false;
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

fn systemAllocate(byte_count: usize) callconv(.c) ?[*]u64 {
    if (comptime builtin.cpu.arch != .aarch64 or (builtin.os.tag != .macos and builtin.os.tag != .linux)) return null;
    var result: usize = 0;
    if (comptime builtin.os.tag == .macos) {
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
    } else {
        asm volatile ("svc #0"
            : [result] "={x0}" (result),
            : [address] "{x0}" (@as(usize, 0)),
              [size] "{x1}" (byte_count),
              [protection] "{x2}" (@as(usize, 3)),
              [flags] "{x3}" (@as(usize, 0x22)),
              [descriptor] "{x4}" (~@as(usize, 0)),
              [offset] "{x5}" (@as(usize, 0)),
              [number] "{x8}" (@as(usize, 222)),
            : .{ .memory = true });
    }
    if (@as(isize, @bitCast(result)) < 0) return null;
    return @ptrFromInt(result);
}

fn systemRelease(address: [*]u8, byte_count: usize) callconv(.c) void {
    if (comptime builtin.cpu.arch != .aarch64 or (builtin.os.tag != .macos and builtin.os.tag != .linux)) return;
    if (comptime builtin.os.tag == .macos) {
        _ = asm volatile ("svc #0x80"
            : [result] "={x0}" (-> usize),
            : [address] "{x0}" (@intFromPtr(address)),
              [size] "{x1}" (byte_count),
              [number] "{x16}" (@as(usize, 73)),
            : .{ .memory = true });
    } else {
        _ = asm volatile ("svc #0"
            : [result] "={x0}" (-> usize),
            : [address] "{x0}" (@intFromPtr(address)),
              [size] "{x1}" (byte_count),
              [number] "{x8}" (@as(usize, 215)),
            : .{ .memory = true });
    }
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

test "cycle tracing does not visit scalar array elements" {
    const values = try std.testing.allocator.alloc(u64, 50000);
    defer std.testing.allocator.free(values);
    @memset(values, 0);
    var context: Context = undefined;
    context.resetFieldPlans();
    TestState.traced_values = 0;
    try std.testing.expect(traceArray(&context, values.ptr, 12, values.len));
    try std.testing.expectEqual(@as(usize, 0), TestState.traced_values);
}

test "cycle tracing skips scalar fields while preserving optional storage widths" {
    var context: Context = undefined;
    context.resetFieldPlans();
    const optional_int = (@as(u64, 1) << optional_depth_shift) | 6;
    const nested_string = (@as(u64, 3) << optional_depth_shift) | 12;
    var values = [_]u64{ 7, 1, 42, 0, 0, 0, 0 };
    const fields = [_]u64{ 6, optional_int, nested_string };
    TestState.traced_values = 0;
    try std.testing.expect(traceFields(&context, &values, &fields, fields.len));
    try std.testing.expectEqual(@as(usize, 0), TestState.traced_values);
    try std.testing.expectEqual(@as(usize, 0), context.width(0));
    try std.testing.expectEqual(@as(usize, 2), context.width(optional_int));
    try std.testing.expectEqual(@as(usize, 4), context.width(nested_string));
    try std.testing.expectEqual(@as(usize, 5), context.width((@as(u64, 2) << optional_depth_shift) | function_base));
}

test "optional scalar fields keep following class and callback edges at their exact offsets" {
    var context: Context = undefined;
    context.resetFieldPlans();
    const model = [_]u64{ 1, @intFromEnum(Kind.class), 1, 5, 0, 1, 42, 0, 0 };
    var rooted = [_]u64{ 42, 1, 0, 0 };
    const nested_scalar = (@as(u64, 2) << optional_depth_shift) | 12;
    const optional_class = (@as(u64, 1) << optional_depth_shift) | structure_base;
    const fields = [_]u64{ nested_scalar, optional_class, 6, function_base };
    // The outer optional scalar is absent; its entire reserved storage still
    // precedes the live class and callback. Bogus tag/payload words catch an
    // incorrect compacted offset without relying on elapsed time.
    var values = [_]u64{ 0, 99, 99, 1, @intFromPtr(&rooted), 42, 0, 0, @intFromPtr(&rooted) };
    context.types = .{ .model = &model };
    context.count = 0;
    context.marking = false;
    TestState.traced_values = 0;
    try std.testing.expect(traceFields(&context, &values, &fields, fields.len));
    try std.testing.expectEqual(@as(usize, 3), TestState.traced_values);
    try std.testing.expectEqual(@as(u64, 1), rooted[1]);
    try std.testing.expectEqual(@as(usize, 3), context.width((@as(u64, 2) << optional_depth_shift) | structure_base));
}

test "cycle tracing skips optional scalars but still visits class array edges" {
    var context: Context = undefined;
    context.resetFieldPlans();
    var values = [_]u64{ 1, 12, 0, 0 };
    TestState.traced_values = 0;
    const optional_scalar = (@as(u64, 1) << optional_depth_shift) | 12;
    try std.testing.expect(traceArray(&context, &values, optional_scalar, 2));
    try std.testing.expectEqual(@as(usize, 0), TestState.traced_values);

    const model = [_]u64{ 1, @intFromEnum(Kind.class), 1, 5, 0, 1, 42, 0, 0 };
    var rooted = [_]u64{ 42, 1, 0, 0 };
    var edges = [_]u64{ @intFromPtr(&rooted), @intFromPtr(&rooted) };
    context.types = .{ .model = &model };
    context.count = 0;
    context.marking = false;
    try std.testing.expect(traceArray(&context, &edges, structure_base, 2));
    try std.testing.expectEqual(@as(usize, 2), TestState.traced_values);
}

test "cycle tracing does not visit arrays of scalar-only structures" {
    // SelectOption<int>: value, label, disabled and stable key.
    const model = [_]u64{ 1, @intFromEnum(Kind.value), 4, 5, 4, 6, 12, 1, 12 };
    const values = try std.testing.allocator.alloc(u64, 50000 * 4);
    defer std.testing.allocator.free(values);
    @memset(values, 0);
    var context: Context = undefined;
    context.resetFieldPlans();
    context.types = .{ .model = &model };
    TestState.traced_values = 0;
    try std.testing.expect(traceArray(&context, values.ptr, structure_base, 50000));
    try std.testing.expectEqual(@as(usize, 0), TestState.traced_values);
}

test "cycle tracing skips optional and nested scalar aggregates" {
    const model = [_]u64{
        4,
        @intFromEnum(Kind.value),
        4,
        17,
        4,
        @intFromEnum(Kind.list),
        1,
        21,
        0,
        @intFromEnum(Kind.enumeration),
        7,
        22,
        0,
        @intFromEnum(Kind.value),
        7,
        27,
        1,
        6,
        12,
        1,
        12,
        structure_base,
        2,
        0,
        2,
        (@as(u64, 1) << optional_depth_shift) | structure_base,
        structure_base + 1,
        structure_base + 2,
    };
    var context: Context = undefined;
    context.resetFieldPlans();
    context.types = .{ .model = &model };
    var values = [_]u64{0} ** 14;
    TestState.traced_values = 0;
    try std.testing.expect(traceArray(&context, &values, (@as(u64, 1) << optional_depth_shift) | structure_base, 2));
    try std.testing.expect(traceArray(&context, &values, structure_base + 3, 2));
    try std.testing.expectEqual(@as(usize, 0), TestState.traced_values);
}

test "scalar fields do not hide class and callback edges in aggregate arrays" {
    const model = [_]u64{
        3,
        @intFromEnum(Kind.class),
        1,
        13,
        0,
        @intFromEnum(Kind.value),
        2,
        17,
        2,
        @intFromEnum(Kind.value),
        4,
        19,
        2,
        1,
        42,
        0,
        0,
        6,
        structure_base,
        12,
        function_base,
    };
    var rooted = [_]u64{ 42, 1, 0, 0 };
    var classes = [_]u64{ 7, @intFromPtr(&rooted) };
    var callbacks = [_]u64{ 0, 0, 0, @intFromPtr(&rooted) };
    var context: Context = undefined;
    context.resetFieldPlans();
    context.types = .{ .model = &model };
    context.count = 0;
    context.marking = false;
    TestState.traced_values = 0;
    try std.testing.expect(traceArray(&context, &classes, structure_base + 1, 1));
    try std.testing.expect(traceArray(&context, &callbacks, structure_base + 2, 1));
    try std.testing.expectEqual(@as(usize, 4), TestState.traced_values);
}

test "field plans skip scalar aggregates once and preserve callback offsets" {
    const optional_string = (@as(u64, 1) << optional_depth_shift) | 12;
    const model = [_]u64{
        2,
        @intFromEnum(Kind.value),
        3,
        9,
        2,
        @intFromEnum(Kind.class),
        1,
        11,
        0,
        6,
        optional_string,
        1,
        1,
        0,
        0,
    };
    var rooted = [_]u64{ 1, 1, 0, 0 };
    var values = [_]u64{ 7, 0, 99, 0, 0, @intFromPtr(&rooted) };
    const fields = [_]u64{ structure_base, function_base };
    var context: Context = undefined;
    context.resetFieldPlans();
    context.types = .{ .model = &model };
    context.count = 0;
    context.marking = false;
    TestState.traced_values = 0;
    TestState.field_plans = 0;
    try std.testing.expect(traceFields(&context, &values, &fields, fields.len));
    try std.testing.expect(traceFields(&context, &values, &fields, fields.len));
    try std.testing.expectEqual(@as(usize, 2), TestState.traced_values);
    try std.testing.expectEqual(@as(usize, 1), TestState.field_plans);
    try std.testing.expectEqual(@as(usize, 3), context.field_steps[0].offset);
    try std.testing.expectEqual(@as(u64, 1), rooted[1]);
}

test "field plans distinguish descriptor prefixes by their field count" {
    const model = [_]u64{ 1, @intFromEnum(Kind.class), 1, 5, 0, 1, 0, 0, 0 };
    var rooted = [_]u64{ 0, 1, 0, 0 };
    var values = [_]u64{ 7, @intFromPtr(&rooted) };
    const fields = [_]u64{ 6, structure_base };
    var context: Context = undefined;
    context.resetFieldPlans();
    context.types = .{ .model = &model };
    context.count = 0;
    context.marking = false;
    TestState.traced_values = 0;
    TestState.field_plans = 0;
    try std.testing.expect(traceFields(&context, &values, &fields, 1));
    try std.testing.expect(traceFields(&context, &values, &fields, 2));
    try std.testing.expectEqual(@as(usize, 1), TestState.traced_values);
    try std.testing.expectEqual(@as(usize, 2), TestState.field_plans);
}

test "field plan capacity exhaustion falls back without losing class edges" {
    const model = [_]u64{ 1, @intFromEnum(Kind.class), 1, 5, 0, 1, 0, 0, 0 };
    var rooted = [_]u64{ 0, 1, 0, 0 };
    var values = [_]u64{ @intFromPtr(&rooted), @intFromPtr(&rooted) };
    const fields = [_]u64{ structure_base, structure_base };
    var context: Context = undefined;
    context.resetFieldPlans();
    context.types = .{ .model = &model };
    context.count = 0;
    context.marking = false;
    context.field_step_count = field_step_capacity - 1;
    TestState.traced_values = 0;
    try std.testing.expect(traceFields(&context, &values, &fields, fields.len));
    try std.testing.expectEqual(@as(usize, 2), TestState.traced_values);
    try std.testing.expectEqual(field_step_capacity - 1, context.field_step_count);
    context.field_step_count = 0;
    for (&context.field_plans, 0..) |*plan, index| plan.* = .{ .key = index + 1 };
    context.occupied_field_plans = std.math.maxInt(u64);
    TestState.traced_values = 0;
    try std.testing.expect(traceFields(&context, &values, &fields, fields.len));
    try std.testing.expectEqual(@as(usize, 2), TestState.traced_values);
    try std.testing.expectEqual(@as(usize, 0), context.field_step_count);
    try std.testing.expectEqual(@as(u64, 1), rooted[1]);
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

test "a compiler-prechecked class cycle skips only the type proof" {
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
        2,
        @intFromPtr(&first),
        &model,
        class_type,
        testAllocate,
        testRelease,
    );
    try std.testing.expect(context != 0);
    try std.testing.expectEqual(@as(u64, 1), first[3]);
    try std.testing.expectEqual(@as(u64, 3), second[3]);
    _ = silex_cycle_x64(1, context, &model, class_type, testAllocate, testRelease);
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

fn checkLiveBoundary(root_count: u64, edge_count: u64, back_edge: bool) !void {
    const class_type = structure_base;
    const optional_class = (@as(u64, 1) << optional_depth_shift) | class_type;
    const tag: u64 = 42;
    const model = [_]u64{ 1, @intFromEnum(Kind.class), 1, 5, 0, 1, tag, 4, 2, optional_class, optional_class };
    var first = [_]u64{ tag, 0, if (back_edge) 2 else 1, 0, 1, 0, 1, 0 };
    var second = [_]u64{ tag, 0, 1, 0, 1, 0, 1, 0 };
    var leaf = [_]u64{ tag, root_count, edge_count, 0, @intFromBool(back_edge), 0, 0, 0 };
    first[5] = @intFromPtr(&second);
    first[7] = @intFromPtr(&leaf);
    second[5] = @intFromPtr(&first);
    second[7] = @intFromPtr(&leaf);
    leaf[5] = @intFromPtr(&first);
    const context = silex_cycle_x64(0, @intFromPtr(&first), &model, class_type, testAllocate, testRelease);
    if (back_edge) {
        try std.testing.expectEqual(@as(u64, 0), context);
        try std.testing.expectEqual(@as(u64, 4), first[3]);
        try std.testing.expectEqual(@as(u64, 0), second[3]);
        try std.testing.expectEqual(@as(u64, 2), first[2]);
    } else {
        try std.testing.expect(context != 0);
        defer _ = silex_cycle_x64(1, context, &model, class_type, testAllocate, testRelease);
        try std.testing.expectEqual(@as(u64, 1), first[3]);
        try std.testing.expectEqual(@as(u64, 3), second[3]);
        try std.testing.expectEqual(@as(u64, 0), first[2]);
    }
    try std.testing.expectEqual(@as(u64, 1), second[2]);
    try std.testing.expectEqual(@as(u64, 0), leaf[3]);
    try std.testing.expectEqual(root_count, leaf[1]);
    try std.testing.expectEqual(edge_count, leaf[2]);
}

test "unreachable cycle preserves an externally rooted descendant" {
    try checkLiveBoundary(1, 2, false);
}

test "unreachable cycle preserves a descendant with an external incoming edge" {
    try checkLiveBoundary(0, 3, false);
}

test "a rooted descendant pointing back preserves the whole cycle" {
    try checkLiveBoundary(1, 2, true);
}

test "an externally owned descendant pointing back preserves the whole cycle" {
    try checkLiveBoundary(0, 3, true);
}
