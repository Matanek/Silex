const std = @import("std");
const Silex = @import("silex_optimizer_api");

// A modeled opcode can still reject unsupported types, operators or effects.
// Plain-value collection retains/drops model value semantics, not runtime cost.
pub const Support = enum { conditional, abstract_lifetime, unsupported };

pub fn classify(tag: std.meta.Tag(Silex.Ir.Instruction)) Support {
    return switch (tag) {
        .constant_int, .constant_bool, .constant_str, .constant_float32, .constant_float64, .optional_null, .optional_some, .optional_unwrap, .copy, .deep_copy, .structure_init, .storage_init, .class_retain, .class_drop, .string_retain, .string_drop, .list_init, .list_edit, .protocol_init, .protocol_test, .protocol_extract, .enum_init, .enum_test, .enum_payload, .enum_raw, .field_load, .field_store, .collection_load, .collection_reference, .collection_replace, .collection_count, .collection_slice, .collection_view, .function_reference, .local_load, .local_store, .global_load, .global_store, .local_address, .reference_load, .address_load, .address_store, .reference_store, .reference_field, .reference_optional, .string_address, .string_byte_count, .string_byte_at, .string_from_bytes, .string_count, .string_concat, .format_value, .unary, .binary, .convert, .call, .indirect_call, .boundary_call, .print, .assert, .mutex_lock, .mutex_unlock => .conditional,
        .list_retain, .list_drop => .abstract_lifetime,
        .constant_bytes, .class_cast, .class_test, .boundary_indirect_call, .dynamic_call => .unsupported,
    };
}

test "LLVM coverage explicitly separates value modeling from lifetime cost" {
    try std.testing.expectEqual(Support.abstract_lifetime, classify(.list_drop));
    try std.testing.expectEqual(Support.conditional, classify(.list_edit));
    try std.testing.expectEqual(Support.conditional, classify(.indirect_call));
    try std.testing.expectEqual(Support.conditional, classify(.boundary_call));
    try std.testing.expectEqual(Support.conditional, classify(.collection_load));
    try std.testing.expectEqual(Support.conditional, classify(.global_store));
    try std.testing.expectEqual(Support.conditional, classify(.optional_unwrap));
    try std.testing.expectEqual(Support.conditional, classify(.class_drop));
    try std.testing.expectEqual(Support.conditional, classify(.constant_str));
    try std.testing.expectEqual(Support.conditional, classify(.string_drop));
    try std.testing.expectEqual(Support.conditional, classify(.string_count));
    try std.testing.expectEqual(Support.conditional, classify(.string_address));
    try std.testing.expectEqual(Support.conditional, classify(.string_byte_count));
    try std.testing.expectEqual(Support.conditional, classify(.string_byte_at));
    try std.testing.expectEqual(Support.conditional, classify(.string_concat));
    try std.testing.expectEqual(Support.conditional, classify(.field_store));
    try std.testing.expectEqual(Support.conditional, classify(.function_reference));
    try std.testing.expectEqual(Support.conditional, classify(.enum_init));
    try std.testing.expectEqual(Support.conditional, classify(.enum_test));
    try std.testing.expectEqual(Support.conditional, classify(.enum_payload));
    try std.testing.expectEqual(Support.conditional, classify(.protocol_init));
    try std.testing.expectEqual(Support.conditional, classify(.protocol_test));
    try std.testing.expectEqual(Support.conditional, classify(.protocol_extract));
    try std.testing.expectEqual(Support.conditional, classify(.storage_init));
    try std.testing.expectEqual(Support.conditional, classify(.reference_optional));
    try std.testing.expectEqual(Support.conditional, classify(.mutex_lock));
    try std.testing.expectEqual(Support.conditional, classify(.mutex_unlock));
    try std.testing.expectEqual(Support.conditional, classify(.assert));
}
