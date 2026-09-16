const Model = @import("Model.zig");
const Resources = @import("Resources.zig");

/// A projection from an owned temporary must outlive the owner that supplied it.
/// Retain the selected value before releasing the complete temporary, including
/// sibling fields and its user-defined destructor.
pub fn finishLoad(self: anytype, builder: anytype, base: Model.TypedValue, field: Model.TypedValue) error{ InvalidSource, OutOfMemory }!Model.TypedValue {
    if (!base.transferred or !Resources.ownsValue(self, base.type)) return field;
    if (Resources.requiresRetain(self, field.type)) {
        try Resources.retainValue(self, builder, field.type, field.value);
    }
    try Resources.emitDrop(self, builder, base.type, base.value);
    var result = field;
    result.transferred = Resources.ownsValue(self, field.type);
    result.reference = null;
    return result;
}
