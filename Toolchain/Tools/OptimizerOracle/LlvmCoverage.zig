const std = @import("std");
const Silex = @import("silex_optimizer_api");

// A modeled opcode can still reject unsupported types, operators or effects.
// Plain-value collection retains/drops model value semantics, not runtime cost.
pub const Support = enum { conditional, abstract_lifetime, unsupported };

pub fn classify(tag: std.meta.Tag(Silex.Ir.Instruction)) Support {
    return switch (tag) {
        .constant_int, .constant_bool, .constant_float32, .constant_float64, .copy, .deep_copy, .structure_init, .list_init, .field_load, .collection_load, .collection_reference, .collection_replace, .collection_count, .collection_view, .local_load, .local_store, .local_address, .reference_load, .reference_store, .reference_field, .unary, .binary, .convert, .call, .print => .conditional,
        .list_retain, .list_drop => .abstract_lifetime,
        .constant_str, .constant_bytes, .optional_null, .optional_some, .optional_unwrap, .class_cast, .class_test, .class_retain, .class_drop, .string_retain, .string_drop, .global_load, .global_store, .storage_init, .protocol_init, .protocol_test, .protocol_extract, .enum_init, .enum_test, .enum_payload, .enum_raw, .field_store, .list_edit, .collection_slice, .string_address, .string_byte_count, .string_byte_at, .string_from_bytes, .function_reference, .address_load, .address_store, .reference_optional, .format_value, .string_concat, .string_count, .indirect_call, .boundary_call, .boundary_indirect_call, .dynamic_call, .assert, .mutex_lock, .mutex_unlock => .unsupported,
    };
}

test "LLVM coverage explicitly separates value modeling from lifetime cost" {
    try std.testing.expectEqual(Support.abstract_lifetime, classify(.list_drop));
    try std.testing.expectEqual(Support.unsupported, classify(.class_drop));
    try std.testing.expectEqual(Support.unsupported, classify(.indirect_call));
    try std.testing.expectEqual(Support.conditional, classify(.collection_load));
}
