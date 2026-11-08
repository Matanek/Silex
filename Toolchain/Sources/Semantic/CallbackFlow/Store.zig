const std = @import("std");
const A = std.mem.Allocator;

/// Immutable AVL map. Abstract branch/call snapshots share unchanged storage;
/// a write replaces only the search path and never mutates another snapshot.
pub fn Store(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();
        const tracks_controls = K != usize and @hasDecl(V, "hasKnownControl");
        const Node = struct {
            key: K,
            value: V,
            left: ?*const Node,
            right: ?*const Node,
            height: usize,
            region: *anyopaque,
            known_controls: if (tracks_controls) bool else void,
        };
        root: ?*const Node = null,
        pub const empty: Self = .{};

        fn order(a: K, b: K) std.math.Order {
            if (K == usize) return std.math.order(a, b);
            const object = std.math.order(a.object, b.object);
            return if (object == .eq) std.math.order(a.field, b.field) else object;
        }
        fn equal(a: V, b: V) bool {
            if (@hasDecl(V, "eql")) return V.eql(a, b);
            return std.meta.eql(a, b);
        }
        fn height(node: ?*const Node) usize {
            return if (node) |n| n.height else 0;
        }
        fn hasKnown(root: ?*const Node) bool {
            if (comptime tracks_controls) return if (root) |node| node.known_controls else false;
            return false;
        }
        fn make(a: A, key: K, value: V, left: ?*const Node, right: ?*const Node) A.Error!*const Node {
            const node = try a.create(Node);
            node.* = .{ .key = key, .value = value, .left = left, .right = right, .height = 1 + @max(height(left), height(right)), .region = a.ptr, .known_controls = if (tracks_controls) value.hasKnownControl() or hasKnown(left) or hasKnown(right) else {} };
            return node;
        }
        fn balanced(a: A, key: K, value: V, left: ?*const Node, right: ?*const Node) A.Error!*const Node {
            if (height(left) > height(right) + 1) {
                const l = left.?;
                if (height(l.left) >= height(l.right)) return make(a, l.key, l.value, l.left, try make(a, key, value, l.right, right));
                const m = l.right.?;
                return make(a, m.key, m.value, try make(a, l.key, l.value, l.left, m.left), try make(a, key, value, m.right, right));
            }
            if (height(right) > height(left) + 1) {
                const r = right.?;
                if (height(r.right) >= height(r.left)) return make(a, r.key, r.value, try make(a, key, value, left, r.left), r.right);
                const m = r.left.?;
                return make(a, m.key, m.value, try make(a, key, value, left, m.left), try make(a, r.key, r.value, m.right, r.right));
            }
            return make(a, key, value, left, right);
        }
        fn inserted(a: A, root: ?*const Node, key: K, value: V) A.Error!*const Node {
            const n = root orelse return make(a, key, value, null, null);
            switch (order(key, n.key)) {
                .eq => return if (equal(value, n.value)) n else make(a, key, value, n.left, n.right),
                .lt => {
                    const child = try inserted(a, n.left, key, value);
                    return if (child == n.left) n else balanced(a, n.key, n.value, child, n.right);
                },
                .gt => {
                    const child = try inserted(a, n.right, key, value);
                    return if (child == n.right) n else balanced(a, n.key, n.value, n.left, child);
                },
            }
        }
        fn find(self: Self, key: K) ?*const Node {
            var current = self.root;
            while (current) |node| switch (order(key, node.key)) {
                .eq => return node,
                .lt => current = node.left,
                .gt => current = node.right,
            };
            return null;
        }
        pub fn get(self: Self, key: K) ?V {
            return if (self.find(key)) |node| node.value else null;
        }
        pub fn put(self: *Self, a: A, key: K, value: V) A.Error!void {
            self.root = try inserted(a, self.root, key, value);
        }
        fn promoted(root: ?*const Node, from: A, to: A) A.Error!?*const Node {
            const n = root orelse return null;
            if (n.region != from.ptr) return n;
            const value = if (@hasDecl(V, "promote")) try n.value.promote(from, to) else n.value;
            return try make(to, n.key, value, try promoted(n.left, from, to), try promoted(n.right, from, to));
        }
        pub fn promote(self: Self, from: A, to: A) A.Error!Self {
            return .{ .root = try promoted(self.root, from, to) };
        }
        pub const Iterator = struct {
            // An AVL tree with at most maxInt(usize) nodes has height below
            // twice the bit width. This is a structural bound, not a budget.
            stack: [2 * @bitSizeOf(usize)]*const Node = undefined,
            depth: usize = 0,
            current: ?*const Node,
            baseline: Self = .empty,
            known_only: bool = false,
            pub const Entry = struct { key_ptr: *const K, value_ptr: *const V };
            pub fn next(self: *Iterator) ?Entry {
                while (true) {
                    while (self.current) |node| {
                        if (comptime tracks_controls) if (self.known_only and !node.known_controls) {
                            self.current = null;
                            break;
                        };
                        // Shared immutable subtrees are already present in the
                        // target; comparing their contents again adds no facts.
                        if (self.baseline.root != null and self.baseline.find(node.key) == node) {
                            self.current = null;
                            break;
                        }
                        self.stack[self.depth] = node;
                        self.depth += 1;
                        self.current = node.left;
                    }
                    if (self.depth == 0) return null;
                    self.depth -= 1;
                    const node = self.stack[self.depth];
                    self.current = node.right;
                    if (comptime tracks_controls) if (self.known_only and !node.value.hasKnownControl()) continue;
                    return .{ .key_ptr = &node.key, .value_ptr = &node.value };
                }
            }
        };
        pub fn iterator(self: Self) Iterator {
            return .{ .current = self.root };
        }
        pub fn knownControls(self: Self) Iterator {
            return .{ .current = self.root, .known_only = true };
        }
        pub fn changedSince(self: Self, baseline: Self) Iterator {
            return .{ .current = self.root, .baseline = baseline };
        }
        pub fn iteratorFrom(self: Self, key: K) Iterator {
            var result: Iterator = .{ .current = null };
            var current = self.root;
            while (current) |node| {
                if (order(node.key, key) == .lt) {
                    current = node.right;
                } else {
                    result.stack[result.depth] = node;
                    result.depth += 1;
                    current = node.left;
                }
            }
            return result;
        }
    };
}
