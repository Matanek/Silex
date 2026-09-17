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
    incoming: u64 = 0,
    feedback: u64 = 0,
    active: bool = false,
    live: bool = false,
};
const Context = struct {
    visitor: Visitor,
    nodes: ?*Node = null,
    marking: bool = false,
    failed: bool = false,

    fn find(self: *Context, object: *Header) ?*Node {
        var current = self.nodes;
        while (current) |node| : (current = node.next) if (node.object == object) return node;
        return null;
    }

    fn add(self: *Context, object: *Header, incoming: bool) void {
        if (self.failed) return;
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
        const memory = malloc(@sizeOf(Node)) orelse {
            @atomicStore(u64, &object.state, 0, .release);
            self.failed = true;
            return;
        };
        const node: *Node = @ptrCast(@alignCast(memory));
        node.* = .{ .object = object, .next = self.nodes, .incoming = @intFromBool(incoming), .active = true };
        self.nodes = node;
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
