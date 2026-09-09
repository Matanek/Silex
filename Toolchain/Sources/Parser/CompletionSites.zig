const std = @import("std");

/// Closed catalogue of public grammar sites where editing can require a
/// completion decision. The parser owns this list; the LSP contract owns the
/// policy and proofs attached to every entry.
pub const Production = enum {
    use_path,
    use_alias,
    module_declaration,
    structure_declaration,
    modifier,
    type_annotation,
    generic_parameter,
    generic_argument,
    nominal_relation,
    parameter,
    return_type,
    statement,
    expression,
    member_access,
    cascade_operation,
    call_argument,
    call_label,
    aggregate_field,
    interpolation_expression,
    match_branch,
    try_alternative,
    for_source,
};

pub const CompletionPolicy = enum {
    required,
    context_only,
};

pub fn policy(production: Production) CompletionPolicy {
    return switch (production) {
        .use_path,
        .use_alias,
        .module_declaration,
        .structure_declaration,
        .modifier,
        .type_annotation,
        .generic_parameter,
        .generic_argument,
        .nominal_relation,
        .parameter,
        .return_type,
        .statement,
        .expression,
        .member_access,
        .cascade_operation,
        .call_argument,
        .call_label,
        .aggregate_field,
        .interpolation_expression,
        .match_branch,
        .try_alternative,
        .for_source,
        => .required,
    };
}

test "every parser completion production has an explicit policy" {
    inline for (std.meta.fields(Production)) |field| {
        try std.testing.expectEqual(
            CompletionPolicy.required,
            policy(@enumFromInt(field.value)),
        );
    }
}
