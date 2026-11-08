const std = @import("std");
const Ir = @import("../../Ir.zig");
const M = @import("Model.zig");

// Preserve the positional structure of edits whose input cardinalities and
// insertion/removal index are known. Unknown edits retain the may-element
// fallback; they must not acquire a fabricated element count.
pub fn precise(e: anytype, frame_id: usize, block: usize, v: Ir.Instruction.ListEdit, state: *M.State, index: ?usize) !bool {
    const frame = e.frames.items[frame_id];
    const f = e.program.functions[frame.function];
    const old = state.get(v.collection);
    const count = if (v.kind == .clear) 0 else e.collectionLength(old) orelse return false;
    const argument: M.Value = if (v.argument) |id| state.get(id) else .{};
    const added = if (v.kind == .append_sequence) e.collectionLength(argument) orelse return false else 1;
    const removal = v.kind == .take or v.kind == .take_first or v.kind == .take_last;
    const at: usize = switch (v.kind) {
        .prepend, .take_first => 0,
        .append => count,
        .take_last => if (count != 0) count - 1 else return false,
        .insert, .take => index orelse return false,
        else => 0,
    };
    if (removal and (count == 0 or at >= count)) return false;
    if (v.kind == .insert and at > count) return false;
    const length = switch (v.kind) {
        .append, .prepend, .insert, .append_sequence => std.math.add(usize, count, added) catch return false,
        .take, .take_first, .take_last => count - 1,
        .reverse => count,
        .clear => 0,
    };
    const t = e.program.structures[f.value_types[v.collection].structureIndex().?].collection.?.element;
    const values = try e.a.alloc(M.Value, length);
    for (values, 0..) |*value, i| {
        value.* = switch (v.kind) {
            .append, .prepend, .insert => if (i == at) argument else try e.field(&state.memory, old, if (i < at) i else i - 1, t),
            .append_sequence => if (i < count) try e.field(&state.memory, old, i, t) else try e.field(&state.memory, argument, i - count, t),
            .take, .take_first, .take_last => try e.field(&state.memory, old, if (i < at) i else i + 1, t),
            .reverse => try e.field(&state.memory, old, count - 1 - i, t),
            .clear => unreachable,
        };
    }
    if (v.removed) |removed| try state.set(e.a, removed, try e.field(&state.memory, old, at, f.value_types[removed]));
    const object = try e.objectWithLength(frame_id, .object, v.result, f.value_types[v.result], frame.recursive or frame.repeated or e.inLoop(frame.function, block), length);
    for (values, 0..) |value, i| try e.write(&state.memory, .{ .object = object, .field = i }, value, true);
    try state.set(e.a, v.result, try M.Value.one(e.a, object));
    return true;
}
