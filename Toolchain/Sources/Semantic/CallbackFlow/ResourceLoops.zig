const std = @import("std");
const Ir = @import("../../Ir.zig");
pub const Plan = struct { body: usize, exit: usize, collection: usize, load: usize, condition: usize, reverse: bool };
pub fn program(a: std.mem.Allocator, p: Ir.Program) ![]const []const ?Plan {
    const result = try a.alloc([]const ?Plan, p.functions.len);
    for (p.functions, 0..) |f, i| {
        const plans = try a.alloc(?Plan, f.blocks.len);
        for (plans, 0..) |*slot, b| slot.* = find(p, f, b);
        result[i] = plans;
    }
    return result;
}
fn constant(block: Ir.Block, value: usize, bits: u64) bool {
    for (block.instructions) |op| if (op == .constant_int and op.constant_int.result == value and op.constant_int.bits == bits) return true;
    return false;
}
fn countOf(p: Ir.Program, f: Ir.Function, block: Ir.Block, value: usize, collection: usize) bool {
    for (block.instructions) |op| switch (op) {
        .collection_count => |v| if (v.result == value and v.collection == collection) return true,
        .constant_int => |v| if (v.result == value) {
            const t = f.value_types[collection].structureIndex() orelse return false;
            const c = p.structures[t].collection orelse return false;
            return c.length != null and c.length.? == v.bits;
        },
        else => {},
    };
    return false;
}
fn reaches(t: Ir.Terminator, target: usize) bool {
    return switch (t) {
        .jump => |v| v == target,
        .branch => |v| v.then_block == target or v.else_block == target,
        else => false,
    };
}
fn find(p: Ir.Program, f: Ir.Function, header: usize) ?Plan {
    const h = f.blocks[header];
    if (h.terminator != .branch or h.instructions.len < 2 or h.instructions.len > 3) return null;
    const branch = h.terminator.branch;
    if (branch.then_block >= f.blocks.len or branch.else_block >= f.blocks.len) return null;
    const body = f.blocks[branch.then_block];
    if (body.terminator != .jump or body.terminator.jump != header or body.instructions.len != 5) return null;
    var load_index: ?usize = null;
    var resource: ?usize = null;
    var increment: ?usize = null;
    var store: ?usize = null;
    var one: ?usize = null;
    for (body.instructions, 0..) |op, i| switch (op) {
        .collection_load => {
            if (load_index != null) return null;
            load_index = i;
        },
        .class_retain, .class_drop => {
            if (resource != null) return null;
            resource = i;
        },
        .binary => {
            if (increment != null) return null;
            increment = i;
        },
        .local_store => {
            if (store != null) return null;
            store = i;
        },
        .constant_int => |v| {
            if (one != null or v.bits != 1) return null;
            one = i;
        },
        else => return null,
    };
    const li = load_index orelse return null;
    const ri = resource orelse return null;
    const ii = increment orelse return null;
    const si = store orelse return null;
    const oi = one orelse return null;
    const access = body.instructions[li].collection_load;
    const update = body.instructions[ii].binary;
    const assignment = body.instructions[si].local_store;
    if (f.local_types[assignment.local] != .int or update.right != body.instructions[oi].constant_int.result or assignment.operand != update.result) return null;
    if (ri <= li or oi >= ii or ii >= si) return null;
    const operand = switch (body.instructions[ri]) {
        .class_retain => |v| v.operand,
        .class_drop => |v| v.operand,
        else => unreachable,
    };
    if (operand != access.result) return null;
    if (h.instructions[0] != .local_load or h.instructions[h.instructions.len - 1] != .binary) return null;
    const index = h.instructions[0].local_load;
    const compare = h.instructions[h.instructions.len - 1].binary;
    if (index.local != assignment.local or compare.result != branch.condition or compare.left != index.result or update.left != index.result) return null;
    const reverse = compare.operator == .not_equal;
    if (reverse) {
        if (h.instructions.len != 3 or !constant(h, compare.right, 0) or update.operator != .subtract or access.index != update.result or si >= li) return null;
    } else {
        if (h.instructions.len != 2 or compare.operator != .less or update.operator != .add or access.index != index.result or ri >= oi) return null;
    }
    var preheader: ?usize = null;
    for (f.blocks, 0..) |b, i| {
        if (reaches(b.terminator, branch.then_block) and i != header) return null;
        if (reaches(b.terminator, header) and i != branch.then_block) {
            if (preheader != null or b.terminator != .jump) return null;
            preheader = i;
        }
    }
    const pre = preheader orelse return null;
    var stores: usize = 0;
    var initialized = false;
    for (f.blocks, 0..) |b, i| for (b.instructions) |op| {
        if (op == .local_address and op.local_address.local == index.local) return null;
        if (op != .local_store or op.local_store.local != index.local) continue;
        stores += 1;
        if (i == pre) initialized = if (reverse) countOf(p, f, b, op.local_store.operand, access.collection) else constant(b, op.local_store.operand, 0);
        if (i != pre and i != branch.then_block) return null;
    };
    if (stores != 2 or !initialized or (!reverse and !countOf(p, f, f.blocks[pre], compare.right, access.collection))) return null;
    return .{ .body = branch.then_block, .exit = branch.else_block, .collection = access.collection, .load = li, .condition = branch.condition, .reverse = reverse };
}
