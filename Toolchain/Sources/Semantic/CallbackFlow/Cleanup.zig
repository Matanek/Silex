const std = @import("std");
const Ir = @import("../../Ir.zig");
fn generated(name: []const u8) bool {
    if (std.mem.endsWith(u8, name, ".$fields")) return true;
    const start = std.mem.lastIndexOf(u8, name, ".$resource") orelse return false;
    const digits = name[start + 10 ..];
    if (digits.len == 0) return false;
    for (digits) |c| if (c < '0' or c > '9') return false;
    return true;
}
// These transfers only project storage and release/retain its resources.
// Class destruction still invokes every ordinary finalizer for each identity.
// A direct call to a user value destructor excludes the containing helper.
pub fn program(a: std.mem.Allocator, p: Ir.Program) ![]const bool {
    const result = try a.alloc(bool, p.functions.len);
    for (p.functions, 0..) |f, i| {
        result[i] = generated(f.name) and f.return_type == .void and f.capture_types.len == 0 and f.borrow_origins.len == 0;
        for (f.blocks) |b| for (b.instructions) |op| switch (op) {
            .constant_int, .constant_bool, .optional_null, .optional_unwrap, .copy, .class_cast, .class_retain, .class_drop, .list_retain, .list_drop, .string_retain, .string_drop, .protocol_test, .protocol_extract, .enum_test, .enum_payload, .field_load, .collection_load, .collection_count, .local_store, .local_load, .binary, .call => {},
            else => result[i] = false,
        };
    }
    var changed = true;
    while (changed) {
        changed = false;
        for (p.functions, 0..) |f, i| {
            if (!result[i]) continue;
            for (f.blocks) |b| for (b.instructions) |op| if (op == .call and !result[op.call.function]) {
                result[i] = false;
                changed = true;
            };
        }
    }
    return result;
}
