const std = @import("std");
const M = @import("Model.zig");

// Each existing object keeps its finite identity independently. A fresh
// path or temporary argument must not merge other, already known receivers.
// Fresh identities still widen nominally to bound recursive allocation.
pub fn arguments(e: anytype, first: []const M.Value, second: []const M.Value, boundary: usize) bool {
    if (first.len != second.len) return false;
    for (first, second) |a, b| {
        if (a.reference_domain != b.reference_domain or a.presence != b.presence or a.unknown_callable != b.unknown_callable or !M.Scalar.eql(a.scalar, b.scalar)) return false;
        if (!subset(e, a.nodes, b.nodes, boundary) or !subset(e, b.nodes, a.nodes, boundary)) return false;
    }
    return true;
}
fn subset(e: anytype, first: []const usize, second: []const usize, boundary: usize) bool {
    for (first) |a| {
        var found = false;
        for (second) |b| if (node(e, a, b, boundary)) {
            found = true;
            break;
        };
        if (!found) return false;
    }
    return true;
}
fn node(e: anytype, first: usize, second: usize, boundary: usize) bool {
    const a = e.nodes.items[first];
    const b = e.nodes.items[second];
    if (existingNode(e, first, boundary) and existingNode(e, second, boundary)) return switch (a) {
        .address => b == .address and std.meta.eql(a.address, b.address),
        else => first == second,
    };
    if (std.meta.activeTag(a) != std.meta.activeTag(b)) return false;
    return switch (a) {
        .object => |o| std.meta.eql(o.type, b.object.type) and (o.unknown_parent == null) == (b.object.unknown_parent == null),
        .callable => |c| c.function == b.callable.function,
        .address => true,
    };
}

// Exact identities are finite when every argument belongs to the universe
// present at ancestor entry. A new identity restores nominal widening before
// it can create an unbounded chain of allocation contexts.
pub fn existing(e: anytype, arguments_value: []const M.Value, boundary: usize) bool {
    for (arguments_value) |value| for (value.nodes) |id| switch (e.nodes.items[id]) {
        .address => |cell| {
            if (cell.object >= boundary) return false;
        },
        else => {
            if (id >= boundary) return false;
        },
    };
    return true;
}

fn existingNode(e: anytype, id: usize, boundary: usize) bool {
    return switch (e.nodes.items[id]) {
        .address => |cell| cell.object < boundary,
        else => id < boundary,
    };
}
