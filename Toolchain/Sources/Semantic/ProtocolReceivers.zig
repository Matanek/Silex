const Ast = @import("../Ast.zig");
const Model = @import("Model.zig");
const ProtocolValues = @import("ProtocolValues.zig");
const Resources = @import("Resources.zig");

// Dispatch borrows the original receiver. Its class identity must survive an
// argument or callback replacing the storage that supplied the protocol value.
// Value conformers are deliberately untouched: an internal lifetime hold must
// not invoke their user-defined drop as if it were an ordinary value copy.
pub fn apply(self: anytype, builder: anytype, value: Model.TypedValue, retaining: bool) error{ InvalidSource, OutOfMemory }!void {
    const protocol_index = ProtocolValues.index(self, value.type) orelse return error.InvalidSource;
    const conformers = try ProtocolValues.conformers(self, protocol_index);
    var classes: usize = 0;
    for (conformers) |index| if (self.structures[index].is_class) {
        classes += 1;
    };
    if (classes == 0) return;
    if (classes == conformers.len) {
        if (retaining) try Resources.retainValue(self, builder, value.type, value.value) else try Resources.emitDrop(self, builder, value.type, value.value);
        return;
    }
    const merge = try self.newBlock(builder);
    for (conformers) |index| {
        if (!self.structures[index].is_class) continue;
        const matched = try ProtocolValues.emitTest(self, builder, value.value, index);
        const action = try self.newBlock(builder);
        const next = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{ .condition = matched, .then_block = action, .else_block = next } });
        builder.current_block = action;
        const receiver = try ProtocolValues.emitExtract(self, builder, value.value, index);
        const concrete = Ast.Type.structure(index);
        if (retaining) try Resources.retainValue(self, builder, concrete, receiver) else try Resources.emitDrop(self, builder, concrete, receiver);
        self.terminate(builder, .{ .jump = merge });
        builder.current_block = next;
    }
    self.terminate(builder, .{ .jump = merge });
    builder.current_block = merge;
}
