// LLVM classes use the same roots/edges model as portable IR. Generated visitors
// describe LLVM's actual field layout; this runtime owns only graph reasoning.
const std = @import("std");
extern "c" fn malloc(usize) ?*anyopaque;
extern "c" fn free(?*anyopaque) void;

const Header = extern struct { tag: u64, roots: u64, edges: u64, state: u64 };
const Visitor = *const fn (*Context, *Header) callconv(.c) void;
const Node = struct {
    object: *Header,
    next: ?*Node,
    bucket_next: ?*Node = null,
    incoming: u64 = 0,
    feedback: u64 = 0,
    active: bool = false,
    live: bool = false,
};
const Context = struct {
    visitor: Visitor,
    nodes: ?*Node = null,
    buckets: []?*Node = &.{},
    count: usize = 0,
    marking: bool = false,
    failed: bool = false,

    fn find(self: *Context, object: *Header) ?*Node {
        if (self.buckets.len == 0) return null;
        var current = self.buckets[bucket(object, self.buckets.len)];
        while (current) |node| : (current = node.bucket_next) if (node.object == object) return node;
        return null;
    }

    fn bucket(object: *Header, capacity: usize) usize {
        const hash = (@as(u64, @intFromPtr(object)) >> 4) *% 0x9e3779b97f4a7c15;
        return @intCast((hash ^ (hash >> 32)) & (capacity - 1));
    }

    // Keep the traversal list stable: the index only accelerates identity lookup.
    fn reserve(self: *Context) bool {
        if (self.count < self.buckets.len) return true;
        const capacity = if (self.buckets.len == 0) 64 else std.math.mul(usize, self.buckets.len, 2) catch return false;
        const bytes = std.math.mul(usize, capacity, @sizeOf(?*Node)) catch return false;
        const memory = malloc(bytes) orelse return false;
        const buckets = @as([*]?*Node, @ptrCast(@alignCast(memory)))[0..capacity];
        @memset(buckets, null);
        var current = self.nodes;
        while (current) |node| : (current = node.next) {
            const slot = bucket(node.object, capacity);
            node.bucket_next = buckets[slot];
            buckets[slot] = node;
        }
        if (self.buckets.len != 0) free(@ptrCast(self.buckets.ptr));
        self.buckets = buckets;
        return true;
    }

    fn add(self: *Context, object: *Header, incoming: bool) void {
        if (self.failed) return;
        // A rooted object and everything reached through it are live. Leave
        // this boundary outside the trial graph: its outgoing edges remain
        // external counts on any nodes reached by another path. This also
        // preserves a candidate reached back through the rooted boundary,
        // without walking an application's entire retained scene on a drop.
        if (@atomicLoad(u64, &object.roots, .acquire) != 0 and self.find(object) == null) return;
        if (self.find(object)) |node| {
            if (self.marking) {
                if (node.live) return;
                node.live = true;
                self.visitor(self, object);
            } else if (incoming) {
                node.incoming += 1;
                if (node.active) node.feedback += 1;
            }
            return;
        }
        if (self.marking or @cmpxchgStrong(u64, &object.state, 0, 2, .acq_rel, .acquire) != null) {
            self.failed = true;
            return;
        }
        if (!self.reserve()) {
            @atomicStore(u64, &object.state, 0, .release);
            self.failed = true;
            return;
        }
        const memory = malloc(@sizeOf(Node)) orelse {
            @atomicStore(u64, &object.state, 0, .release);
            self.failed = true;
            return;
        };
        const node: *Node = @ptrCast(@alignCast(memory));
        node.* = .{ .object = object, .next = self.nodes, .incoming = @intFromBool(incoming), .active = true };
        self.nodes = node;
        const slot = bucket(object, self.buckets.len);
        node.bucket_next = self.buckets[slot];
        self.buckets[slot] = node;
        self.count += 1;
        self.visitor(self, object);
        node.active = false;
    }

    fn discard(self: *Context) void {
        var current = self.nodes;
        while (current) |node| {
            current = node.next;
            if (@atomicLoad(u64, &node.object.state, .acquire) == 2)
                @atomicStore(u64, &node.object.state, 0, .release);
            free(node);
        }
        if (self.buckets.len != 0) free(@ptrCast(self.buckets.ptr));
    }
};

pub export fn silex_llvm_cycle_edge(context: *Context, object: ?*Header) callconv(.c) void {
    context.add(object orelse {
        context.failed = true;
        return;
    }, true);
}

pub export fn silex_llvm_cycle_reject(context: *Context) callconv(.c) void {
    context.failed = true;
}

pub export fn silex_llvm_cycle_collect(object: *Header, visitor: Visitor) callconv(.c) u32 {
    if (@atomicLoad(u64, &object.roots, .acquire) != 0) return 0;
    var context: Context = .{ .visitor = visitor };
    defer context.discard();
    context.add(object, false);
    if (context.failed) return 0;
    var current = context.nodes;
    while (current) |node| : (current = node.next) {
        const roots = @atomicLoad(u64, &node.object.roots, .acquire);
        const edges = @atomicLoad(u64, &node.object.edges, .acquire);
        if (edges < node.incoming) return 0;
        if (roots != 0 or edges > node.incoming) {
            context.marking = true;
            context.add(node.object, false);
            if (context.failed) return 0;
        }
    }
    const root = context.find(object) orelse return 0;
    if (root.live) return 0;
    current = context.nodes;
    while (current) |node| : (current = node.next) {
        if (node.live) continue;
        if (node.feedback != 0) _ = @atomicRmw(u64, &node.object.edges, .Sub, node.feedback, .acq_rel);
        @atomicStore(u64, &node.object.state, if (node == root) 1 else 3, .release);
    }
    return 1;
}

const TestObject = extern struct {
    header: Header,
    children: [3]?*TestObject = .{ null, null, null },
    visits: usize = 0,

    fn init(roots: u64, edges: u64) TestObject {
        return .{ .header = .{ .tag = 0, .roots = roots, .edges = edges, .state = 0 } };
    }

    fn visit(context: *Context, header: *Header) callconv(.c) void {
        const object: *TestObject = @fieldParentPtr("header", header);
        object.visits += 1;
        for (object.children) |child| if (child) |value| silex_llvm_cycle_edge(context, &value.header);
    }
};

test "rooted scene is a constant-work boundary of an unreachable cycle" {
    var candidate = TestObject.init(0, 1);
    var scene = TestObject.init(1, 1);
    var branch = TestObject.init(0, 1);
    candidate.children = .{ &candidate, &scene, null };
    scene.children[0] = &branch;
    try std.testing.expectEqual(@as(u32, 1), silex_llvm_cycle_collect(&candidate.header, TestObject.visit));
    try std.testing.expectEqual(@as(usize, 1), candidate.visits);
    try std.testing.expectEqual(@as(usize, 0), scene.visits);
    try std.testing.expectEqual(@as(usize, 0), branch.visits);
    try std.testing.expectEqual(@as(u64, 1), candidate.header.state);
    try std.testing.expectEqual(@as(u64, 0), candidate.header.edges);
    try std.testing.expectEqual(@as(u64, 0), scene.header.state);
    try std.testing.expectEqual(@as(u64, 1), scene.header.edges);
}

test "a back edge from the rooted boundary preserves the candidate until root removal" {
    var candidate = TestObject.init(0, 2);
    var scene = TestObject.init(1, 1);
    candidate.children = .{ &candidate, &scene, null };
    scene.children[0] = &candidate;
    try std.testing.expectEqual(@as(u32, 0), silex_llvm_cycle_collect(&candidate.header, TestObject.visit));
    try std.testing.expectEqual(@as(usize, 0), scene.visits);
    try std.testing.expectEqual(@as(u64, 0), candidate.header.state);
    try std.testing.expectEqual(@as(u64, 2), candidate.header.edges);
    scene.header.roots = 0;
    try std.testing.expectEqual(@as(u32, 1), silex_llvm_cycle_collect(&candidate.header, TestObject.visit));
    try std.testing.expectEqual(@as(u64, 1), candidate.header.state);
    try std.testing.expectEqual(@as(u64, 3), scene.header.state);
    try std.testing.expectEqual(@as(u64, 0), candidate.header.edges);
}

test "an external edge preserves an unrooted descendant beside a rooted boundary" {
    var candidate = TestObject.init(0, 1);
    var live = TestObject.init(0, 2);
    var scene = TestObject.init(1, 1);
    candidate.children = .{ &candidate, &live, null };
    live.children[0] = &scene;
    try std.testing.expectEqual(@as(u32, 1), silex_llvm_cycle_collect(&candidate.header, TestObject.visit));
    try std.testing.expectEqual(@as(u64, 1), candidate.header.state);
    try std.testing.expectEqual(@as(u64, 0), live.header.state);
    try std.testing.expectEqual(@as(u64, 2), live.header.edges);
    try std.testing.expectEqual(@as(usize, 0), scene.visits);
}

test "root boundary pruning agrees with independent reachability on small graphs" {
    var random: u64 = 0x511e202d;
    for (0..256) |_| {
        var objects: [8]TestObject = undefined;
        var live: [8]bool = @splat(false);
        for (&objects, 0..) |*object, index| {
            random = random *% 6364136223846793005 +% 1;
            const roots: u64 = if (index != 0 and random >> 61 == 0) 1 else 0;
            object.* = TestObject.init(roots, 0);
            live[index] = roots != 0;
        }
        for (&objects) |*object| {
            for (&object.children) |*child| {
                random = random *% 6364136223846793005 +% 1;
                const target: usize = @intCast(random >> 60);
                if (target >= objects.len) continue;
                child.* = &objects[target];
                objects[target].header.edges += 1;
            }
        }
        // Root objects outside the candidate's reachable component. A local
        // trial collector conservatively treats their edges as external even
        // if an unrelated unreachable component could own them in a full GC.
        var reachable: [8]bool = @splat(false);
        reachable[0] = true;
        for (0..objects.len) |_| {
            for (&objects, 0..) |*object, index| {
                if (!reachable[index]) continue;
                for (object.children) |child| if (child) |value| {
                    for (&objects, 0..) |*target, target_index| {
                        if (value == target) reachable[target_index] = true;
                    }
                };
            }
        }
        for (&objects, 0..) |*object, index| {
            if (!reachable[index]) {
                object.header.roots = 1;
                live[index] = true;
            }
        }
        // An independent fixed-point oracle starts from all external roots.
        for (0..objects.len) |_| {
            for (&objects, 0..) |*object, index| {
                if (!live[index]) continue;
                for (object.children) |child| if (child) |value| {
                    for (&objects, 0..) |*target, target_index| {
                        if (value == target) live[target_index] = true;
                    }
                };
            }
        }
        const result = silex_llvm_cycle_collect(&objects[0].header, TestObject.visit);
        try std.testing.expectEqual(@as(u32, @intFromBool(!live[0])), result);
        for (objects, 0..) |object, index| {
            if (live[index]) try std.testing.expectEqual(@as(u64, 0), object.header.state);
        }
    }
}
