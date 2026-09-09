const std = @import("std");

pub const DemandKind = enum {
    value,
    callable,
    member,
    type_name,
    call_label,
    aggregate_field,
    iterable,
    condition,
    statement,
    declaration,
};

pub const ProducerKind = enum {
    intrinsic,
    lexical_local,
    parameter,
    self_value,
    field,
    property,
    constructor_result,
    function_result,
    method_result,
    callback_result,
    tuple_value,
    tuple_element,
    destructured_element,
    iteration_binding,
    ecs_query_binding,
    injected_dependency,
    imported_value,
    workspace_contribution,
    function_declaration,
    method_declaration,
    bound_method,
    callback_parameter,
    callback_field,
    returned_callback,
    tuple_callable,
    injected_callable,
    imported_callable,
};

pub const ConsumerKind = enum {
    initializer,
    assignment,
    field_default,
    property_default,
    return_value,
    match_subject,
    argument_value,
    argument_callable,
    cascade_argument_value,
    cascade_argument_callable,
    cascade_assignment,
    aggregate_value,
    condition,
    loop_source,
    interpolation,
    member_access,
    callable_invocation,
    type_position,
    call_label,
    aggregate_label,
    statement,
    declaration,
};

pub const TransformKind = enum {
    direct,
    borrowed,
    optional_access,
    generic_specialization,
    field_chain,
    call_chain,
    cascade,
    nested_cascade,
    destructured,
    captured,
    injected,
};

pub const EditingMutation = enum {
    empty_cursor,
    prefixed_cursor,
    delete_and_retype,
    missing_delimiter,
    missing_body,
    nested_expression,
    interpolation,
    unicode_before_cursor,
    error_before_cursor,
    error_at_cursor,
    error_after_cursor,
    error_in_neighbour_block,
};

pub const TopologyKind = enum {
    same_file,
    module_file,
    submodule,
    package,
    dependency,
    development_dependency,
    friend_dependency,
    alias,
    reexport,
    contribution,
    catalog,
    atom,
    extension,
    platform_fragment,
    unsaved_overlay,
};

pub const DeliveryPart = enum {
    producer_provenance,
    value_consumers,
    callable_composition,
};

pub const ExclusionReason = enum {
    consumer_requests_another_demand,
    producer_cannot_satisfy_demand,
    transform_cannot_follow_producer,
    transform_invalid_at_consumer,
};

pub const SchemaId = enum {
    receiver_member_surface,
    value_flow_surface,
};

pub const SchemaPredicate = enum {
    receiver_member_surface,
    value_flow_surface,
    none,
    all_applicable,
};

pub const OracleProjection = enum {
    declared_member_surface,
    typed_value_identity,
};

pub const PartialTransform = enum {
    member_cursor,
    value_cursor,
};

pub const AssertionMode = enum {
    exact_surface,
    compatible_ranked,
};

pub const RunnerTier = enum {
    local,
    server,
};

pub const Key = struct {
    demand: DemandKind,
    producer: ProducerKind,
    consumer: ConsumerKind,
    transform: TransformKind,
};

pub const ProofSchema = struct {
    id: SchemaId,
    predicate: SchemaPredicate,
    canonical_template: []const u8,
    oracle_projection: OracleProjection,
    partial_transform: PartialTransform,
    assertions: AssertionMode,
    runner_tier: RunnerTier,
    scenario_ids: []const []const u8,
};

pub const Status = union(enum) {
    proved: SchemaId,
    required: DeliveryPart,
    excluded: ExclusionReason,
};

pub const Statistics = struct {
    total: usize = 0,
    proved: usize = 0,
    required: usize = 0,
    excluded: usize = 0,
    schemas: usize = 0,
};

pub const schemas = [_]ProofSchema{
    .{
        .id = .receiver_member_surface,
        .predicate = .receiver_member_surface,
        .canonical_template = "typed receiver member access",
        .oracle_projection = .declared_member_surface,
        .partial_transform = .member_cursor,
        .assertions = .exact_surface,
        .runner_tier = .server,
        .scenario_ids = &.{
            "member-local-incomplete-if",
            "member-self-receiver",
            "member-named-tuple",
            "member-imported-field-chain",
            "cascade-local-incomplete",
        },
    },
    .{
        .id = .value_flow_surface,
        .predicate = .value_flow_surface,
        .canonical_template = "typed value in a compatible demand",
        .oracle_projection = .typed_value_identity,
        .partial_transform = .value_cursor,
        .assertions = .compatible_ranked,
        .runner_tier = .server,
        .scenario_ids = &.{
            "call-argument-expression",
            "lexical-query-destructuring",
            "expression-match-subject-parameter",
        },
    },
};

pub fn statusFor(key: Key) Status {
    if (!consumerRequests(key.consumer, key.demand)) {
        return .{ .excluded = .consumer_requests_another_demand };
    }
    if (!producerSatisfies(key.producer, key.demand)) {
        return .{ .excluded = .producer_cannot_satisfy_demand };
    }
    if (!transformFollows(key.transform, key.producer, key.demand)) {
        return .{ .excluded = .transform_cannot_follow_producer };
    }
    if (!transformFitsConsumer(key.transform, key.consumer)) {
        return .{ .excluded = .transform_invalid_at_consumer };
    }
    if (schemaOwnerForKey(&schemas, key) catch unreachable) |schema| return .{ .proved = schema };
    return .{ .required = deliveryPart(key) };
}

pub fn audit() !Statistics {
    try auditSchemaRegistry(&schemas);
    var statistics = Statistics{ .schemas = schemas.len };
    for (std.enums.values(DemandKind)) |demand| {
        for (std.enums.values(ProducerKind)) |producer| {
            for (std.enums.values(ConsumerKind)) |consumer| {
                for (std.enums.values(TransformKind)) |transform| {
                    statistics.total += 1;
                    switch (statusFor(.{
                        .demand = demand,
                        .producer = producer,
                        .consumer = consumer,
                        .transform = transform,
                    })) {
                        .proved => statistics.proved += 1,
                        .required => statistics.required += 1,
                        .excluded => statistics.excluded += 1,
                    }
                }
            }
        }
    }
    if (statistics.total != statistics.proved + statistics.required + statistics.excluded) {
        return error.UnclassifiedComposition;
    }
    return statistics;
}

pub fn auditRelease() !void {
    const statistics = try audit();
    if (statistics.required != 0) return error.MissingCompositionProof;
}

pub fn auditSchemaRegistry(registry: []const ProofSchema) !void {
    for (schemas) |declared| {
        var found = false;
        for (registry) |candidate| {
            if (candidate.id != declared.id) continue;
            if (found) return error.DuplicateSchema;
            if (candidate.predicate != declared.predicate) return error.SchemaPredicateMismatch;
            found = true;
        }
        if (!found) return error.MissingDeclaredSchema;
    }
    try auditSchemaCoverage(registry);
}

pub fn auditSchemaCoverage(registry: []const ProofSchema) !void {
    for (registry, 0..) |candidate, index| {
        if (candidate.canonical_template.len == 0) return error.MissingCanonicalTemplate;
        if (candidate.scenario_ids.len == 0) return error.MissingScenario;
        for (registry[index + 1 ..]) |other| {
            if (candidate.id == other.id) return error.DuplicateSchema;
        }
        var owned: usize = 0;
        for (std.enums.values(DemandKind)) |demand| {
            for (std.enums.values(ProducerKind)) |producer| {
                for (std.enums.values(ConsumerKind)) |consumer| {
                    for (std.enums.values(TransformKind)) |transform| {
                        const key: Key = .{
                            .demand = demand,
                            .producer = producer,
                            .consumer = consumer,
                            .transform = transform,
                        };
                        if (!isApplicable(key)) continue;
                        if (try schemaOwnerForKey(registry, key) == candidate.id) owned += 1;
                    }
                }
            }
        }
        if (owned == 0) return error.EmptySchema;
    }
}

fn schemaOwnerForKey(registry: []const ProofSchema, key: Key) !?SchemaId {
    var owner: ?SchemaId = null;
    for (registry) |schema| {
        if (!schemaOwns(schema.predicate, key)) continue;
        if (owner != null) return error.OverlappingSchemas;
        owner = schema.id;
    }
    return owner;
}

fn schemaOwns(predicate: SchemaPredicate, key: Key) bool {
    return switch (predicate) {
        .receiver_member_surface => key.demand == .member and
            key.consumer == .member_access and
            isProducerProvenanceProducer(key.producer),
        .value_flow_surface => isValueDemandKey(key),
        .none => false,
        .all_applicable => isApplicable(key),
    };
}

pub fn isProducerProvenanceProducer(producer: ProducerKind) bool {
    return switch (producer) {
        .lexical_local,
        .parameter,
        .self_value,
        .field,
        .property,
        .constructor_result,
        .function_result,
        .method_result,
        .callback_result,
        .tuple_value,
        .tuple_element,
        .destructured_element,
        .iteration_binding,
        .ecs_query_binding,
        .injected_dependency,
        => true,
        .intrinsic,
        .imported_value,
        .workspace_contribution,
        .function_declaration,
        .method_declaration,
        .bound_method,
        .callback_parameter,
        .callback_field,
        .returned_callback,
        .tuple_callable,
        .injected_callable,
        .imported_callable,
        => false,
    };
}

pub fn isValueDemandKey(key: Key) bool {
    return deliveryPart(key) == .value_consumers;
}

pub fn isValueDemandConsumer(consumer: ConsumerKind) bool {
    return switch (consumer) {
        .initializer,
        .assignment,
        .field_default,
        .property_default,
        .return_value,
        .match_subject,
        .argument_value,
        .cascade_argument_value,
        .cascade_assignment,
        .aggregate_value,
        .condition,
        .loop_source,
        .interpolation,
        => true,
        .argument_callable,
        .cascade_argument_callable,
        .member_access,
        .callable_invocation,
        .type_position,
        .call_label,
        .aggregate_label,
        .statement,
        .declaration,
        => false,
    };
}

fn isApplicable(key: Key) bool {
    return consumerRequests(key.consumer, key.demand) and
        producerSatisfies(key.producer, key.demand) and
        transformFollows(key.transform, key.producer, key.demand) and
        transformFitsConsumer(key.transform, key.consumer);
}

fn consumerRequests(consumer: ConsumerKind, demand: DemandKind) bool {
    return switch (consumer) {
        .initializer,
        .assignment,
        .field_default,
        .property_default,
        .return_value,
        .match_subject,
        .cascade_assignment,
        .aggregate_value,
        .interpolation,
        => demand == .value or demand == .callable,
        .argument_value, .cascade_argument_value => demand == .value,
        .argument_callable, .cascade_argument_callable => demand == .callable,
        .condition => demand == .condition,
        .loop_source => demand == .iterable,
        .member_access => demand == .member,
        .callable_invocation => demand == .callable,
        .type_position => demand == .type_name,
        .call_label => demand == .call_label,
        .aggregate_label => demand == .aggregate_field,
        .statement => demand == .statement,
        .declaration => demand == .declaration,
    };
}

fn producerSatisfies(producer: ProducerKind, demand: DemandKind) bool {
    return switch (demand) {
        .value => true,
        .callable => isCallableProducer(producer),
        .member, .iterable, .condition => !isCallableProducer(producer),
        .type_name, .call_label, .aggregate_field, .statement, .declaration => false,
    };
}

fn isCallableProducer(producer: ProducerKind) bool {
    return switch (producer) {
        .function_declaration,
        .method_declaration,
        .bound_method,
        .callback_parameter,
        .callback_field,
        .returned_callback,
        .tuple_callable,
        .injected_callable,
        .imported_callable,
        => true,
        .intrinsic,
        .lexical_local,
        .parameter,
        .self_value,
        .field,
        .property,
        .constructor_result,
        .function_result,
        .method_result,
        .callback_result,
        .tuple_value,
        .tuple_element,
        .destructured_element,
        .iteration_binding,
        .ecs_query_binding,
        .injected_dependency,
        .imported_value,
        .workspace_contribution,
        => false,
    };
}

fn transformFollows(transform: TransformKind, producer: ProducerKind, demand: DemandKind) bool {
    return switch (transform) {
        .direct => true,
        .borrowed => !isCallableProducer(producer),
        .optional_access => demand == .member and !isCallableProducer(producer),
        .generic_specialization => producer != .intrinsic,
        .field_chain, .call_chain => switch (demand) {
            .value, .callable, .member, .iterable, .condition => true,
            .type_name, .call_label, .aggregate_field, .statement, .declaration => false,
        },
        .cascade, .nested_cascade => switch (demand) {
            .value, .callable, .member => true,
            .type_name, .call_label, .aggregate_field, .iterable, .condition, .statement, .declaration => false,
        },
        .destructured => switch (producer) {
            .tuple_value, .destructured_element, .ecs_query_binding, .tuple_callable => true,
            .intrinsic,
            .lexical_local,
            .parameter,
            .self_value,
            .field,
            .property,
            .constructor_result,
            .function_result,
            .method_result,
            .callback_result,
            .tuple_element,
            .iteration_binding,
            .injected_dependency,
            .imported_value,
            .workspace_contribution,
            .function_declaration,
            .method_declaration,
            .bound_method,
            .callback_parameter,
            .callback_field,
            .returned_callback,
            .injected_callable,
            .imported_callable,
            => false,
        },
        .captured => switch (producer) {
            .lexical_local,
            .parameter,
            .self_value,
            .field,
            .property,
            .bound_method,
            .callback_parameter,
            .callback_field,
            => true,
            .intrinsic,
            .constructor_result,
            .function_result,
            .method_result,
            .callback_result,
            .tuple_value,
            .tuple_element,
            .destructured_element,
            .iteration_binding,
            .ecs_query_binding,
            .injected_dependency,
            .imported_value,
            .workspace_contribution,
            .function_declaration,
            .method_declaration,
            .returned_callback,
            .tuple_callable,
            .injected_callable,
            .imported_callable,
            => false,
        },
        .injected => switch (producer) {
            .injected_dependency, .injected_callable => true,
            .intrinsic,
            .lexical_local,
            .parameter,
            .self_value,
            .field,
            .property,
            .constructor_result,
            .function_result,
            .method_result,
            .callback_result,
            .tuple_value,
            .tuple_element,
            .destructured_element,
            .iteration_binding,
            .ecs_query_binding,
            .imported_value,
            .workspace_contribution,
            .function_declaration,
            .method_declaration,
            .bound_method,
            .callback_parameter,
            .callback_field,
            .returned_callback,
            .tuple_callable,
            .imported_callable,
            => false,
        },
    };
}

fn transformFitsConsumer(transform: TransformKind, consumer: ConsumerKind) bool {
    return switch (transform) {
        .direct, .borrowed, .generic_specialization, .field_chain, .call_chain, .destructured, .captured, .injected => true,
        .optional_access => consumer == .member_access,
        .cascade, .nested_cascade => switch (consumer) {
            .initializer,
            .assignment,
            .return_value,
            .match_subject,
            .argument_value,
            .argument_callable,
            .cascade_argument_value,
            .cascade_argument_callable,
            .cascade_assignment,
            .aggregate_value,
            .interpolation,
            .member_access,
            .callable_invocation,
            => true,
            .field_default,
            .property_default,
            .condition,
            .loop_source,
            .type_position,
            .call_label,
            .aggregate_label,
            .statement,
            .declaration,
            => false,
        },
    };
}

pub fn deliveryPart(key: Key) DeliveryPart {
    if (key.demand == .callable or isCallableProducer(key.producer) or
        key.consumer == .argument_callable or key.consumer == .cascade_argument_callable or
        key.consumer == .callable_invocation) return .callable_composition;
    return switch (key.consumer) {
        .member_access => .producer_provenance,
        .initializer,
        .assignment,
        .field_default,
        .property_default,
        .return_value,
        .match_subject,
        .argument_value,
        .cascade_argument_value,
        .cascade_assignment,
        .aggregate_value,
        .condition,
        .loop_source,
        .interpolation,
        => .value_consumers,
        .argument_callable, .cascade_argument_callable, .callable_invocation => .callable_composition,
        .type_position, .call_label, .aggregate_label, .statement, .declaration => .producer_provenance,
    };
}

test "semantic completion compositions are all classified" {
    const statistics = try audit();
    try std.testing.expect(statistics.proved > 8);
    try std.testing.expectEqual(schemas.len, statistics.schemas);
    try std.testing.expect(statistics.required != 0);
    try std.testing.expect(statistics.excluded != 0);
}

test "semantic completion release remains closed while compositions lack proof" {
    try std.testing.expectError(error.MissingCompositionProof, auditRelease());
}

test "removing a declared quantified schema is rejected" {
    try std.testing.expectError(error.MissingDeclaredSchema, auditSchemaRegistry(schemas[1..]));
}

test "empty and overlapping quantified schemas are rejected" {
    var empty = schemas;
    empty[0].predicate = .none;
    try std.testing.expectError(error.EmptySchema, auditSchemaCoverage(&empty));

    var overlapping = schemas;
    overlapping[0].predicate = .all_applicable;
    overlapping[1].predicate = .all_applicable;
    try std.testing.expectError(error.OverlappingSchemas, auditSchemaCoverage(&overlapping));
}

test "semantic domains require exhaustive policies" {
    inline for (@typeInfo(DemandKind).@"enum".fields) |field| {
        _ = producerSatisfies(.lexical_local, @enumFromInt(field.value));
    }
    inline for (@typeInfo(ProducerKind).@"enum".fields) |field| {
        const producer: ProducerKind = @enumFromInt(field.value);
        _ = isCallableProducer(producer);
        _ = transformFollows(.direct, producer, .value);
    }
    inline for (@typeInfo(ConsumerKind).@"enum".fields) |field| {
        const consumer: ConsumerKind = @enumFromInt(field.value);
        _ = consumerRequests(consumer, .value);
        _ = transformFitsConsumer(.direct, consumer);
    }
    inline for (@typeInfo(TransformKind).@"enum".fields) |field| {
        _ = transformFollows(@enumFromInt(field.value), .lexical_local, .value);
    }
    inline for (@typeInfo(EditingMutation).@"enum".fields) |field| {
        _ = editingMutationOwner(@enumFromInt(field.value));
    }
    inline for (@typeInfo(TopologyKind).@"enum".fields) |field| {
        _ = topologyOwner(@enumFromInt(field.value));
    }
}

fn editingMutationOwner(mutation: EditingMutation) enum { local, recovery } {
    return switch (mutation) {
        .empty_cursor, .prefixed_cursor, .delete_and_retype, .nested_expression, .interpolation, .unicode_before_cursor => .local,
        .missing_delimiter, .missing_body, .error_before_cursor, .error_at_cursor, .error_after_cursor, .error_in_neighbour_block => .recovery,
    };
}

fn topologyOwner(topology: TopologyKind) enum { local, workspace } {
    return switch (topology) {
        .same_file => .local,
        .module_file,
        .submodule,
        .package,
        .dependency,
        .development_dependency,
        .friend_dependency,
        .alias,
        .reexport,
        .contribution,
        .catalog,
        .atom,
        .extension,
        .platform_fragment,
        .unsaved_overlay,
        => .workspace,
    };
}
