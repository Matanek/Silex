const std = @import("std");
const FrontendModule = @import("../../Frontend.zig");
const Project = @import("../../Project.zig");
const Completion = @import("../Completion.zig");
const Composition = @import("../CompletionContract/Composition.zig");
const Oracle = @import("CompletionOracleSupport.zig");
const ServerModule = @import("../Server.zig");
const Support = @import("Support.zig");

const marker = "<|>";
const completion = "paint()";

const Case = struct {
    id: []const u8,
    producer: Composition.ProducerKind,
    transform: Composition.TransformKind,
    oracle_type: []const u8 = "Surface",
    partial_source: []const u8,
};

const surface =
    \\public struct Surface {
    \\    public func configure() Surface { return self }
    \\    public func paint() {}
    \\}
;

const cases = [_]Case{
    .{
        .id = "lexical-local",
        .producer = .lexical_local,
        .transform = .direct,
        .partial_source = surface ++ "\nfunc main() { let surface = Surface(); surface.<|> }",
    },
    .{
        .id = "parameter",
        .producer = .parameter,
        .transform = .direct,
        .partial_source = surface ++ "\nfunc inspect(surface:Surface) { surface.<|> }\nfunc main() {}",
    },
    .{
        .id = "borrowed-parameter",
        .producer = .parameter,
        .transform = .borrowed,
        .partial_source = surface ++ "\nfunc inspect(surface:@Surface) { surface.<|> }\nfunc main() {}",
    },
    .{
        .id = "mutable-parameter",
        .producer = .parameter,
        .transform = .borrowed,
        .partial_source = surface ++ "\nfunc inspect(surface:&Surface) { surface.<|> }\nfunc main() {}",
    },
    .{
        .id = "self",
        .producer = .self_value,
        .transform = .direct,
        .oracle_type = "Inspector",
        .partial_source =
        \\public struct Inspector {
        \\    public func paint() {}
        \\    func inspect() { self.<|> }
        \\}
        \\func main() {}
        ,
    },
    .{
        .id = "field-chain",
        .producer = .field,
        .transform = .field_chain,
        .partial_source = surface ++
            "\nclass Holder { var surface:Surface; func inspect() { self.surface.<|> } }\nfunc main() {}",
    },
    .{
        .id = "property-chain",
        .producer = .property,
        .transform = .field_chain,
        .partial_source = surface ++
            "\nclass Holder { let surface:Surface { get { return Surface() } } func inspect() { self.surface.<|> } }\nfunc main() {}",
    },
    .{
        .id = "constructor-result",
        .producer = .constructor_result,
        .transform = .direct,
        .partial_source = surface ++ "\nfunc main() { Surface().<|> }",
    },
    .{
        .id = "function-result",
        .producer = .function_result,
        .transform = .call_chain,
        .partial_source = surface ++
            "\nfunc make_surface() Surface { return Surface() }\nfunc main() { make_surface().<|> }",
    },
    .{
        .id = "method-result",
        .producer = .method_result,
        .transform = .call_chain,
        .partial_source = surface ++
            "\nclass Factory { func make() Surface { return Surface() } }\nfunc main() { Factory().make().<|> }",
    },
    .{
        .id = "callback-result",
        .producer = .callback_result,
        .transform = .call_chain,
        .partial_source = surface ++
            "\nfunc inspect(produce:func() Surface) { produce().<|> }\nfunc main() {}",
    },
    .{
        .id = "named-tuple-element",
        .producer = .tuple_element,
        .transform = .field_chain,
        .partial_source = surface ++
            "\nfunc pair() (surface:Surface, count:int) { return (surface:Surface(), count:1) }\nfunc main() { pair().surface.<|> }",
    },
    .{
        .id = "destructured-element",
        .producer = .destructured_element,
        .transform = .destructured,
        .partial_source = surface ++
            "\nfunc pair() (Surface, int) { return (Surface(), 1) }\nfunc main() { let (surface, count) = pair(); surface.<|> }",
    },
    .{
        .id = "iteration-binding",
        .producer = .iteration_binding,
        .transform = .direct,
        .partial_source = surface ++
            "\nfunc inspect(values:Surface[]) { for surface in values { surface.<|> } }\nfunc main() {}",
    },
    .{
        .id = "injected-dependency",
        .producer = .injected_dependency,
        .transform = .injected,
        .partial_source = surface ++ "\nfunc system(surface:Surface) { surface.<|> }\nfunc main() {}",
    },
    .{
        .id = "optional-access",
        .producer = .parameter,
        .transform = .optional_access,
        .partial_source = surface ++ "\nfunc inspect(surface:Surface?) { surface?.<|> }\nfunc main() {}",
    },
    .{
        .id = "generic-specialization",
        .producer = .field,
        .transform = .generic_specialization,
        .partial_source = surface ++
            "\nstruct Box<T> { let value:T }\nfunc main() { Box<Surface>(value:Surface()).value.<|> }",
    },
    .{
        .id = "captured-value",
        .producer = .lexical_local,
        .transform = .captured,
        .partial_source = surface ++
            "\nfunc main() { let surface = Surface(); let callback = func() { surface.<|> }; callback() }",
    },
    .{
        .id = "cascade",
        .producer = .constructor_result,
        .transform = .cascade,
        .partial_source = surface ++ "\nfunc main() { Surface()..<|> }",
    },
    .{
        .id = "nested-cascade",
        .producer = .method_result,
        .transform = .nested_cascade,
        .partial_source = surface ++ "\nfunc main() { Surface()..configure()..<|> }",
    },
};

const additional_producers = [_]Composition.ProducerKind{ .tuple_value, .ecs_query_binding };

fn canonicalSource(allocator: std.mem.Allocator, partial_source: []const u8) ![]const u8 {
    const cursor = std.mem.indexOf(u8, partial_source, marker) orelse return error.MissingCompletionMarker;
    if (std.mem.indexOf(u8, partial_source[cursor + marker.len ..], marker) != null) {
        return error.MultipleCompletionMarkers;
    }
    return std.fmt.allocPrint(
        allocator,
        "{s}{s}{s}",
        .{ partial_source[0..cursor], completion, partial_source[cursor + marker.len ..] },
    );
}

test "typed member surface is invariant across producer provenance" {
    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();

    for (cases, 0..) |case, index| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();
        const canonical = try canonicalSource(allocator, case.partial_source);
        var frontend = FrontendModule.Frontend.init(allocator);
        frontend.checkDocument(canonical) catch |err| {
            std.debug.print(
                "producer provenance '{s}' canonical source failed: {s}\n",
                .{ case.id, if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err) },
            );
            return err;
        };
        const expected = try Oracle.publicInstanceMember(allocator, canonical, case.oracle_type, "paint");
        const expected_labels = try Oracle.publicInstanceMembers(allocator, canonical, case.oracle_type);
        const uri = try std.fmt.allocPrint(allocator, "file:///Producer-Provenance-{d}.sx", .{index});
        const actual = try Support.serverCompletionAfterTrigger(&server, allocator, uri, case.partial_source, ".");
        Support.expectExactLabels(expected_labels, actual) catch |err| {
            std.debug.print("producer provenance '{s}' returned the wrong member surface\n", .{case.id});
            return err;
        };
        try Support.expectItem(.{
            .label = expected.name,
            .kind = expected.kind,
            .detail = expected.detail,
            .insert_text = expected.insert_text,
            .insert_text_format = expected.insert_text_format,
        }, actual);
        try Support.expectNoDuplicates(actual);
        const repeated = try Support.serverCompletionAfterTrigger(&server, allocator, uri, case.partial_source, ".");
        try Support.expectEqualItems(actual, repeated);
    }
}

test "named tuple value surface comes from its compiled return type" {
    const canonical =
        surface ++
        "\nfunc pair() (surface:Surface, count:int) { return (surface:Surface(), count:1) }" ++
        "\nfunc main() { pair().surface.paint() }";
    const partial =
        surface ++
        "\nfunc pair() (surface:Surface, count:int) { return (surface:Surface(), count:1) }" ++
        "\nfunc main() { pair().<|> }";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const expected = try Oracle.namedTupleFieldsFromFunction(allocator, canonical, "pair");
    const labels = try allocator.alloc([]const u8, expected.len);
    for (expected, 0..) |member, index| labels[index] = member.name;

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const actual = try Support.serverCompletionAfterTrigger(&server, allocator, "file:///Producer-Tuple-Value.sx", partial, ".");
    try Support.expectExactLabels(labels, actual);
    for (expected) |member| try Support.expectItem(.{
        .label = member.name,
        .kind = member.kind,
        .detail = member.detail,
        .insert_text = member.insert_text,
        .insert_text_format = member.insert_text_format,
    }, actual);
    try Support.expectNoDuplicates(actual);
}

test "ECS query binding uses the same compiler-backed member oracle" {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const files = [_]struct { path: []const u8, source: []const u8 }{
        .{ .path = "Package.json", .source = "{\"sources\":\".\",\"dependencies\":{\"GFX\":\"=1.0.0\"}}" },
        .{ .path = "GFX/Package.json", .source = "{\"name\":\"GFX\",\"version\":\"1.0.0\"}" },
        .{ .path = "GFX/Module/Application.sx", .source =
        \\public intrinsic class Resources {
        \\    func scope() Resources
        \\    func insert<T>(value:T)
        \\    module func retain_class<T>(value:T)
        \\    func has<T>() bool
        \\    func get<T>() @T
        \\    func get_mut<T>() &T
        \\    func try_get<T>() @T?
        \\    func try_get_mut<T>() &T?
        \\    func remove<T>() T?
        \\    func clear()
        \\    module func invalidate()
        \\}
        \\public class Application {
        \\    private var store:Resources
        \\    init() { self.store = Resources() }
        \\    func resources() Resources { return self.store }
        \\    module func __silex_system_resources() @Resources { return self.store }
        \\    func add_system<System>(schedule:int, callback:System) { panic("unspecialized system") }
        \\    package func __silex_add_system(schedule:int, callback:func(Application, int), after:bool, reads:str[], writes:str[], flags:uint) { callback(self, 0) }
        \\    drop { self.store.clear() }
        \\}
        },
        .{ .path = "GFX/Module/ECS/@Module.sx", .source =
        \\public use GFX.ECS.Entity.Entity
        \\public use GFX.ECS.Vec2.Vec2
        \\public use GFX.ECS.World.World
        \\public use GFX.ECS.Query.Query
        },
        .{ .path = "GFX/Module/ECS/Entity.sx", .source = "public struct Entity { let index:int }" },
        .{ .path = "GFX/Module/ECS/Vec2.sx", .source =
        \\public struct Vec2 {
        \\    public var x:float
        \\    public var y:float
        \\    public func length() float { return 0.0 }
        \\    private func storage() int { return 0 }
        \\}
        },
        .{ .path = "GFX/Module/ECS/ComponentPool.sx", .source =
        \\use GFX.ECS.Entity.Entity
        \\public struct ComponentPool<T> {
        \\    private var sparse:int[]
        \\    private var values:T[]
        \\    init() { self.sparse = []; self.values = [] }
        \\    func get_known(entity:Entity) @self:T { return @self.values[self.sparse[entity.index] - 1] }
        \\}
        },
        .{ .path = "GFX/Module/ECS/World.sx", .source =
        \\use GFX.ECS.Entity.Entity
        \\use GFX.ECS.ComponentPool.ComponentPool
        \\public class World {
        \\    package func query_count(required:int[]) int { return 0 }
        \\    package func query_archetype_count() int { return 0 }
        \\    package func query_entity_count(archetype:int) int { return 0 }
        \\    package func query_entity(archetype:int, row:int) Entity { return Entity(index:0) }
        \\    package func query_range_start(base:int, count:int, range_start:int) int { return 0 }
        \\    package func query_range_end(base:int, count:int, range_end:int) int { return 0 }
        \\    module func query_component_id<T>() int { return 0 }
        \\    package func query_archetype_has<T>(archetype:int) bool { return false }
        \\    module func query_pool<T>() ComponentPool<T> { return ComponentPool<T>() }
        \\}
        },
        .{ .path = "GFX/Module/ECS/Query.sx", .source =
        \\use GFX.ECS.World.World
        \\public class Query<Pattern> {
        \\    package var world:World
        \\    package let range_start:int
        \\    package let range_end:int
        \\    package init(world:World) { self.world = world; self.range_start = 0; self.range_end = -1 }
        \\    package init(world:World, range_start:int, range_end:int) { self.world = world; self.range_start = range_start; self.range_end = range_end }
        \\}
        },
    };
    for (files) |file| {
        if (std.fs.path.dirname(file.path)) |directory| {
            try temporary.dir.createDirPath(std.testing.io, directory);
        }
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = file.path, .data = file.source });
    }

    const canonical =
        \\use GFX.Application
        \\use GFX.ECS
        \\func inspect(query:ECS.Query<(ECS.Entity, @GFX.ECS.Vec2)>) {
        \\    for (entity, position) in query { print(position.x) }
        \\}
        \\func main() {
        \\    var application = Application()
        \\    application.resources().insert(ECS.World())
        \\    application.add_system(0, inspect)
        \\}
    ;
    const partial =
        \\use GFX.Application
        \\use GFX.ECS
        \\func inspect(query:ECS.Query<(ECS.Entity, @GFX.ECS.Vec2)>) {
        \\    for (entity, position) in query { position.<|> }
        \\}
        \\func main() {
        \\    var application = Application()
        \\    application.resources().insert(ECS.World())
        \\    application.add_system(0, inspect)
        \\}
    ;
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = canonical });

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const main_path = try std.fs.path.join(allocator, &.{ root, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(main_path);
    const expected_labels = try Oracle.publicInstanceMembersFromProgram(allocator, compilation.ast, "Vec2");

    var server = ServerModule.Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{main_path});
    try Support.initializeServer(&server, allocator, root_uri);
    const actual = try Support.serverCompletionAfterTrigger(&server, allocator, main_uri, partial, ".");
    if (actual.len == 0) {
        const marked = try Support.removeMarker(allocator, partial);
        const decision = try Completion.decisionAt(allocator, marked.text, marked.cursor, .trigger_character);
        const local_type = if (decision.program) |program|
            Completion.resolveReceiverTypeForAccess(
                allocator,
                marked.text,
                program,
                marked.cursor,
                decision.receiver orelse "",
                decision.safe_member_access,
            )
        else
            null;
        std.debug.print(
            "ECS query binding lost receiver '{s}' (local type: {s}, recovery: {s}, cascade: {}, type-position: {})\n",
            .{
                decision.receiver orelse "<none>",
                local_type orelse "<none>",
                @tagName(decision.recovery),
                decision.cascade,
                decision.qualified_type_position,
            },
        );
    }
    for (expected_labels) |label| {
        const member = try Oracle.publicInstanceMemberFromProgram(allocator, compilation.ast, "Vec2", label);
        try Support.expectItem(.{
            .label = member.name,
            .kind = member.kind,
            .detail = member.detail,
            .insert_text = member.insert_text,
            .insert_text_format = member.insert_text_format,
        }, actual);
    }
    try std.testing.expectEqual(expected_labels.len, actual.len);
    for (expected_labels) |label| try Support.expectPresent(label, actual);
    try Support.expectAbsent("storage", actual);
    try Support.expectNoDuplicates(actual);

    const recovery_mutations = [_][]const u8{
        try std.fmt.allocPrint(allocator, "// îlot ECS 🙂\n{s}", .{partial}),
        try std.fmt.allocPrint(allocator, "{s}\nfunc broken( {{ }}", .{partial}),
        try std.fmt.allocPrint(allocator, "func neighbour() {{ if }}\n{s}", .{partial}),
    };
    for (recovery_mutations, 0..) |mutation, mutation_index| {
        const marked = try Support.removeMarker(allocator, mutation);
        try Support.changeDocument(&server, allocator, main_uri, @intCast(mutation_index + 2), marked.text);
        const recovered = try Support.serverCompletionInOpenDocument(&server, allocator, main_uri, marked);
        try Support.expectEqualItems(actual, recovered);
        try Support.expectNoDuplicates(recovered);
    }
}

test "producer provenance campaign covers every declared local producer and transform family" {
    var producers = [_]bool{false} ** @typeInfo(Composition.ProducerKind).@"enum".fields.len;
    var transforms = [_]bool{false} ** @typeInfo(Composition.TransformKind).@"enum".fields.len;
    for (cases) |case| {
        producers[@intFromEnum(case.producer)] = true;
        transforms[@intFromEnum(case.transform)] = true;
    }
    for (additional_producers) |producer| producers[@intFromEnum(producer)] = true;
    const required_producers = [_]Composition.ProducerKind{
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
    };
    for (required_producers) |producer| try std.testing.expect(producers[@intFromEnum(producer)]);
    for ([_]Composition.TransformKind{
        .direct,
        .borrowed,
        .optional_access,
        .generic_specialization,
        .field_chain,
        .call_chain,
        .cascade,
        .nested_cascade,
        .destructured,
        .captured,
        .injected,
    }) |transform| try std.testing.expect(transforms[@intFromEnum(transform)]);
}

fn auditPropagationEdges(suppressed_producer: ?Composition.ProducerKind, suppressed_transform: ?Composition.TransformKind) !usize {
    var producers = [_]bool{false} ** @typeInfo(Composition.ProducerKind).@"enum".fields.len;
    var transforms = [_]bool{false} ** @typeInfo(Composition.TransformKind).@"enum".fields.len;
    for (cases) |case| {
        if (suppressed_producer == null or case.producer != suppressed_producer.?) {
            producers[@intFromEnum(case.producer)] = true;
        }
        if (suppressed_transform == null or case.transform != suppressed_transform.?) {
            transforms[@intFromEnum(case.transform)] = true;
        }
    }
    for (additional_producers) |producer| if (suppressed_producer == null or producer != suppressed_producer.?) {
        producers[@intFromEnum(producer)] = true;
    };

    var covered: usize = 0;
    for (std.enums.values(Composition.DemandKind)) |demand| {
        for (std.enums.values(Composition.ProducerKind)) |producer| {
            for (std.enums.values(Composition.ConsumerKind)) |consumer| {
                for (std.enums.values(Composition.TransformKind)) |transform| {
                    const status = Composition.statusFor(.{
                        .demand = demand,
                        .producer = producer,
                        .consumer = consumer,
                        .transform = transform,
                    });
                    const schema = switch (status) {
                        .proved => |owned| owned,
                        .required, .excluded => continue,
                    };
                    if (schema != .receiver_member_surface or !Composition.isProducerProvenanceProducer(producer)) continue;
                    if (!producers[@intFromEnum(producer)]) return error.MissingProducerPropagationEdge;
                    if (!transforms[@intFromEnum(transform)]) return error.MissingTransformPropagationEdge;
                    covered += 1;
                }
            }
        }
    }
    if (covered == 0) return error.EmptyProducerProvenanceCampaign;
    return covered;
}

test "every applicable producer proof key has generated edge coverage" {
    const covered = try auditPropagationEdges(null, null);
    try std.testing.expect(covered > cases.len);
}

test "suppressing any producer or transform propagation edge breaks its family" {
    for (std.enums.values(Composition.ProducerKind)) |producer| {
        if (!Composition.isProducerProvenanceProducer(producer)) continue;
        try std.testing.expectError(error.MissingProducerPropagationEdge, auditPropagationEdges(producer, null));
    }
    for (std.enums.values(Composition.TransformKind)) |transform| {
        var applicable = false;
        for (std.enums.values(Composition.ProducerKind)) |producer| {
            if (!Composition.isProducerProvenanceProducer(producer)) continue;
            const status = Composition.statusFor(.{
                .demand = .member,
                .producer = producer,
                .consumer = .member_access,
                .transform = transform,
            });
            const proved = switch (status) {
                .proved => true,
                .required, .excluded => false,
            };
            if (proved) {
                applicable = true;
                break;
            }
        }
        if (applicable) try std.testing.expectError(error.MissingTransformPropagationEdge, auditPropagationEdges(null, transform));
    }
}
