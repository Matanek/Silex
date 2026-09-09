pub const Position = enum {
    module,
    structure,
    modifier,
    type_name,
    statement,
    expression,
    member,
    argument,
    call_label,
    aggregate_field,
    nominal_relation,
    use_path,
};

pub const Origin = enum {
    intrinsic,
    lexical,
    self_member,
    local,
    current_module,
    dependency,
    extension,
    protocol_member,
    alias,
    reexport,
    contribution,
    catalog,
    atom,
};

pub const Receiver = enum {
    value,
    reference,
    optional,
    static_type,
    module,
    principal_type,
    generic,
    tuple,
    dynamic_protocol,
    call_result,
    field_result,
    chain,
    cascade,
};

pub const Topology = enum {
    loose,
    same_file,
    module_file,
    package,
    dependency,
    development_dependency,
    friend,
    submodule,
    merged_extension,
    suite_extension,
    catalog,
    overlay,
    platform_fragment,
};

pub const Visibility = enum {
    public,
    package,
    module,
    local,
    protected,
    private,
    friend,
};

pub const Symbol = enum {
    keyword,
    variable,
    parameter,
    function,
    field,
    method,
    constructor,
    type,
    module,
    enum_case,
    alias,
};

pub const Editing = enum {
    empty,
    prefixed,
    deleted,
    delimiter_missing,
    body_missing,
    nested,
    interpolation,
    unicode_before_cursor,
    syntax_error_before_cursor,
    syntax_error_at_cursor,
    syntax_error_after_cursor,
    syntax_error_neighbour_block,
};

pub const Trigger = enum {
    invoked,
    dot,
    colon,
    less,
    comma,
    space,
    closing_parenthesis,
    else_prefix,
};

pub const Observable = enum {
    labels,
    order,
    kind,
    detail,
    filter_text,
    sort_text,
    insertion,
    snippet,
    duplicates,
    deterministic,
};

pub fn positionWitness(value: Position) []const u8 {
    return switch (value) {
        .module, .modifier => "declaration-module-empty",
        .structure => "declaration-structure-member",
        .type_name => "type-qualified-import",
        .statement => "statement-loop-control",
        .expression => "expression-typed-prefix",
        .member => "member-local-incomplete-if",
        .argument => "call-argument-expression",
        .call_label => "call-label-middle",
        .aggregate_field => "aggregate-remaining-field",
        .nominal_relation => "nominal-relation-type",
        .use_path => "use-path-qualified",
    };
}

pub fn originWitness(value: Origin) []const u8 {
    return switch (value) {
        .intrinsic => "intrinsic-expression-root",
        .lexical => "lexical-query-destructuring",
        .self_member => "member-self-receiver",
        .local => "member-local-incomplete-if",
        .current_module => "origin-current-module",
        .dependency => "member-imported-field-chain",
        .extension => "member-local-extension",
        .protocol_member => "member-dynamic-protocol",
        .alias => "member-imported-alias",
        .reexport => "cascade-imported-principal-reexport",
        .contribution, .catalog => "topology-catalog-fragment-field-chain",
        .atom => "member-imported-atom",
    };
}

pub fn receiverWitness(value: Receiver) []const u8 {
    return switch (value) {
        .value => "member-local-incomplete-if",
        .reference => "member-imported-field-chain",
        .optional => "member-optional-safe-access",
        .static_type => "member-static-type",
        .module => "type-qualified-import",
        .principal_type, .call_result => "cascade-imported-principal-reexport",
        .generic => "member-specialized-generic",
        .tuple => "member-named-tuple",
        .dynamic_protocol => "member-dynamic-protocol",
        .field_result, .chain => "member-imported-field-chain",
        .cascade => "cascade-local-incomplete",
    };
}

pub fn topologyWitness(value: Topology) []const u8 {
    return switch (value) {
        .loose => "editing-empty-expression",
        .same_file => "member-local-incomplete-if",
        .module_file => "origin-current-module",
        .package => "visibility-imported-private-negative",
        .dependency => "cascade-imported-principal-reexport",
        .development_dependency => "topology-development-dependency",
        .friend => "topology-friend-package",
        .submodule => "topology-submodule",
        .merged_extension => "topology-merged-extension",
        .suite_extension => "cascade-imported-principal-reexport",
        .catalog => "topology-catalog-fragment-field-chain",
        .overlay => "overlay-unsaved-import",
        .platform_fragment => "topology-platform-fragment",
    };
}

pub fn visibilityWitness(value: Visibility) []const u8 {
    return switch (value) {
        .public, .private => "visibility-imported-private-negative",
        .package => "visibility-package-member",
        .module => "visibility-module-member",
        .local => "visibility-local-member",
        .protected => "visibility-protected-member",
        .friend => "topology-friend-package",
    };
}

pub fn symbolWitness(value: Symbol) []const u8 {
    return switch (value) {
        .keyword => "declaration-module-empty",
        .variable => "lexical-query-destructuring",
        .parameter => "symbol-parameter-binding",
        .function => "expression-typed-prefix",
        .field => "member-named-tuple",
        .method => "member-local-incomplete-if",
        .constructor => "symbol-constructor-root",
        .type => "type-qualified-import",
        .module => "use-path-qualified",
        .enum_case => "symbol-enum-case",
        .alias => "member-imported-alias",
    };
}

pub fn editingWitness(value: Editing) []const u8 {
    return switch (value) {
        .empty => "editing-empty-expression",
        .prefixed => "expression-typed-prefix",
        .deleted => "editing-delete-and-retype",
        .delimiter_missing => "recovery-error-at-cursor",
        .body_missing, .nested => "member-local-incomplete-if",
        .interpolation => "editing-interpolation-expression",
        .unicode_before_cursor => "lsp-utf16-trigger-metadata",
        .syntax_error_before_cursor => "recovery-error-before-cursor",
        .syntax_error_at_cursor => "recovery-error-at-cursor",
        .syntax_error_after_cursor => "recovery-error-after-cursor",
        .syntax_error_neighbour_block => "recovery-error-neighbour-block",
    };
}

pub fn triggerWitness(value: Trigger) []const u8 {
    return switch (value) {
        .invoked => "editing-empty-expression",
        .dot => "member-local-incomplete-if",
        .colon => "trigger-type-colon",
        .less => "trigger-generic-less",
        .comma => "trigger-argument-comma",
        .space => "trigger-try-space",
        .closing_parenthesis => "trigger-try-closing-parenthesis",
        .else_prefix => "trigger-try-else-prefix",
    };
}

pub fn observableWitness(value: Observable) []const u8 {
    return switch (value) {
        .labels => "member-local-incomplete-if",
        .order, .duplicates, .deterministic => "invariant-deterministic-no-duplicates",
        .kind, .detail, .insertion, .snippet => "observable-kind-detail-snippet",
        .filter_text, .sort_text => "observable-metadata-and-insertion",
    };
}
