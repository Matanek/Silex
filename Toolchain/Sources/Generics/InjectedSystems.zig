const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");
const WorkerSafety = @import("WorkerSafety.zig");
const QueryParallel = @import("QueryParallel.zig");

const application_name = "GFX.Application";
const resources_name = "GFX.Application.Resources";
const world_name = "GFX.ECS.World";

pub fn rewriteRegistration(self: anytype, call: *Ast.Expression.Call, locals: anytype) !bool {
    if (call.receiver == null) return false;
    if (!std.mem.eql(u8, call.name, "add_system") and !std.mem.eql(u8, call.name, "add_after_system")) return false;
    const ordered = try registrationArguments(self.allocator, call.*) orelse return false;
    call.arguments = ordered;
    call.named_arguments = &.{};
    const receiver_type = self.inferExpressionType(call.receiver.?, locals) orelse return false;
    const receiver = self.structureForType(receiver_type) orelse return false;
    if (!std.mem.eql(u8, receiver.name, application_name)) return false;

    const callback = call.arguments[1];
    const target_name = try systemTargetName(self.allocator, callback) orelse null;
    const instance_method = if (target_name) |name| findInstanceSystemMethod(self, name) else null;
    var callback_type: ?Ast.Type = null;
    if (instance_method) |target| {
        callback_type = try self.internFunctionType(target.method);
    } else if (target_name) |name| {
        callback_type = try self.inferConcreteFunctionType(name);
    }
    if (callback_type == null) callback_type = self.inferExpressionType(callback, locals);
    const concrete_callback_type = callback_type orelse
        return self.fail(callback.position, "system callback must be a named or captureless function");
    const function_index = concrete_callback_type.functionIndex() orelse {
        return self.fail(callback.position, "system callback must be a function");
    };
    if (function_index >= self.function_types.items.len) return error.InvalidSource;
    const signature = self.function_types.items[function_index];
    if (signature.return_type != .void or signature.return_mode != .value) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "system function must return 'void', found '{s}'",
            .{self.typeName(signature.return_type)},
        );
        return self.fail(callback.position, message);
    }
    const application_type = self.typeForName(application_name) orelse return false;
    if (signature.parameters.len == 1 and signature.parameters[0].type == application_type and signature.parameters[0].mode == .value) {
        return false;
    }
    for (signature.parameters) |parameter| if (parameter.type == application_type) {
        return self.fail(callback.position, "Application must be the sole system parameter");
    };
    if (target_name == null) {
        return self.fail(callback.position, "system callback must be a named or captureless function");
    }

    var receiver_dependency: ?Ast.SystemDependency = null;
    if (instance_method) |target| {
        if (!target.structure.is_class) {
            return self.fail(callback.position, "instance system methods require a class receiver");
        }
        const resources_type = self.typeForName(resources_name) orelse return error.InvalidSource;
        const resource_source = self.sourceStructureForType(resources_type) orelse return error.InvalidSource;
        const has_template = findGenericMethod(resource_source, "has") orelse return error.InvalidSource;
        const get_template = findGenericMethod(resource_source, "get") orelse return error.InvalidSource;
        receiver_dependency = .{
            .type = target.type,
            .source_type = target.type,
            .mode = .read,
            .has_method = try self.instantiateMethod(resources_type, has_template, &.{target.type}, callback.position),
            .get_method = try self.instantiateMethod(resources_type, get_template, &.{target.type}, callback.position),
        };
    }

    const resources_type = self.typeForName(resources_name) orelse return error.InvalidSource;
    const resource_source = self.sourceStructureForType(resources_type) orelse return error.InvalidSource;
    const dependencies = try self.allocator.alloc(Ast.SystemDependency, signature.parameters.len);
    for (signature.parameters, 0..) |parameter, index| {
        const dependency_type = try self.rewriteType(parameter.type, &.{}, callback.position);
        const dependency_structure = self.structureForType(dependency_type);
        const is_query = dependency_structure != null and dependency_structure.?.query_pattern != null;
        const world_type = if (is_query) self.typeForName(world_name) orelse return error.InvalidSource else null;
        const world_source = if (world_type) |value| self.sourceStructureForType(value) orelse return error.InvalidSource else null;
        if (parameter.mode == .value and !is_query) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "system parameter {d} must use '@{s}' or '&{s}'",
                .{ index + 1, self.typeName(dependency_type), self.typeName(dependency_type) },
            );
            return self.fail(callback.position, message);
        }
        if (is_query and parameter.mode != .value) {
            return self.fail(callback.position, "ECS.Query is a derived value parameter and does not use '@' or '&'");
        }
        for (signature.parameters[0..index]) |previous| {
            const previous_type = try self.rewriteType(previous.type, &.{}, callback.position);
            if (previous_type != dependency_type) continue;
            if (previous.mode == .mutable or parameter.mode == .mutable) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "system has conflicting mutable access to resource '{s}'",
                    .{self.typeName(dependency_type)},
                );
                return self.fail(callback.position, message);
            }
        }
        const source_type = world_type orelse dependency_type;
        for (dependencies[0..index]) |previous| {
            if ((is_query and previous.source_type == source_type and previous.mode == .mutable) or
                (!is_query and parameter.mode == .mutable and previous.kind == .query and previous.source_type == dependency_type))
            {
                return self.fail(callback.position, "a system cannot combine an ECS.Query with mutable World access");
            }
            if (is_query and previous.kind == .query and try queryPatternsConflict(self, previous.type, dependency_type)) {
                return self.fail(callback.position, "system ECS queries have conflicting mutable component access");
            }
        }
        if (is_query) {
            const pattern_type = dependency_structure.?.query_pattern.?;
            const pattern = self.structureForType(pattern_type) orelse return error.InvalidSource;
            if (!pattern.is_tuple) return self.fail(callback.position, "ECS.Query expects a tuple access pattern");
            const has_component = findGenericMethod(resource_source, "has") orelse return error.InvalidSource;
            const get_component = findGenericMethod(resource_source, "get") orelse return error.InvalidSource;
            const get_mut_component = findGenericMethod(resource_source, "get_mut") orelse return error.InvalidSource;
            for (pattern.fields, 0..) |field, field_index| {
                const is_entity = std.mem.eql(u8, self.typeName(field.type), "GFX.ECS.Entity");
                if (is_entity) {
                    if (field.access_mode != .value) return self.fail(field.name_position, "ECS.Entity query access does not use '@' or '&'");
                    continue;
                }
                if (field.access_mode == .value) {
                    return self.fail(field.name_position, "ECS.Query components must use '@' or '&'");
                }
                for (pattern.fields[0..field_index]) |previous| if (previous.type == field.type and
                    (previous.access_mode == .mutable or field.access_mode == .mutable))
                {
                    const message = try std.fmt.allocPrint(self.allocator, "ECS.Query has conflicting mutable access to component '{s}'", .{self.typeName(field.type)});
                    return self.fail(field.name_position, message);
                };
                _ = try self.instantiateMethod(resources_type, has_component, &.{field.type}, callback.position);
                _ = try self.instantiateMethod(
                    resources_type,
                    if (field.access_mode == .mutable) get_mut_component else get_component,
                    &.{field.type},
                    callback.position,
                );
                const type_id_template = findGenericMethod(world_source.?, "query_component_id") orelse return error.InvalidSource;
                const archetype_has_template = findGenericMethod(world_source.?, "query_archetype_has") orelse return error.InvalidSource;
                const query_get_template = findGenericMethod(world_source.?, if (field.access_mode == .mutable) "query_get_mut" else "query_pool") orelse return error.InvalidSource;
                _ = try self.instantiateMethod(world_type.?, type_id_template, &.{field.type}, callback.position);
                _ = try self.instantiateMethod(world_type.?, archetype_has_template, &.{field.type}, callback.position);
                _ = try self.instantiateMethod(world_type.?, query_get_template, &.{field.type}, callback.position);
            }
        }
        const has_template = findGenericMethod(resource_source, "has") orelse return error.InvalidSource;
        const get_template = findGenericMethod(resource_source, if (parameter.mode == .mutable) "get_mut" else "get") orelse return error.InvalidSource;
        dependencies[index] = .{
            .kind = if (is_query) .query else .resource,
            .type = dependency_type,
            .source_type = source_type,
            .mode = parameter.mode,
            .has_method = try self.instantiateMethod(resources_type, has_template, &.{source_type}, callback.position),
            .get_method = try self.instantiateMethod(resources_type, get_template, &.{source_type}, callback.position),
        };
    }

    var resource_reads: std.ArrayList([]const u8) = .empty;
    var resource_writes: std.ArrayList([]const u8) = .empty;
    var component_reads: std.ArrayList([]const u8) = .empty;
    var component_writes: std.ArrayList([]const u8) = .empty;
    var ecs_access = false;
    var world_mutable = false;
    var platform_access = false;
    if (instance_method) |target| {
        try appendUnique(self.allocator, &resource_writes, self.typeName(target.type));
    }
    for (dependencies) |dependency| switch (dependency.kind) {
        .resource => {
            const name = self.typeName(dependency.source_type);
            if (mainThreadType(name)) platform_access = true;
            if (std.mem.eql(u8, name, "GFX.ECS.Commands") and dependency.mode == .mutable) continue;
            if (dependency.mode == .mutable) {
                try appendUnique(self.allocator, &resource_writes, name);
                if (std.mem.eql(u8, name, world_name)) world_mutable = true;
            } else try appendUnique(self.allocator, &resource_reads, name);
        },
        .query => {
            ecs_access = true;
            const query = self.structureForType(dependency.type) orelse return error.InvalidSource;
            const pattern = self.structureForType(query.query_pattern orelse return error.InvalidSource) orelse return error.InvalidSource;
            for (pattern.fields) |field| {
                const name = self.typeName(field.type);
                if (mainThreadType(name)) platform_access = true;
                if (std.mem.eql(u8, name, "GFX.ECS.Entity")) continue;
                if (field.access_mode == .mutable)
                    try appendUnique(self.allocator, &component_writes, name)
                else
                    try appendUnique(self.allocator, &component_reads, name);
            }
        },
    };

    const worker_safe = instance_method == null and !platform_access and
        try WorkerSafety.systemIsWorkerSafe(self, target_name.?, callback.position);

    const parallel_dependency = if (instance_method == null)
        QueryParallel.independentQuery(self, target_name.?, dependencies)
    else
        null;
    const adapter_name = try std.fmt.allocPrint(self.allocator, "__silex_system_adapter_{d}", .{self.functions.items.len});
    const worker_name = if (parallel_dependency != null)
        try std.fmt.allocPrint(self.allocator, "{s}_range", .{adapter_name})
    else
        "";
    try self.functions.append(self.allocator, .{
        .is_local = true,
        .specialization_file = callback.position.file,
        .position = callback.position,
        .name_position = callback.position,
        .name = adapter_name,
        .parameters = try adapterParameters(self, callback.position, application_type, false),
        .return_type = .void,
        .intrinsic = .{ .system_adapter = .{
            .target = target_name.?,
            .target_position = callback.position,
            .receiver = receiver_dependency,
            .receiver_type = if (instance_method) |target| target.type else null,
            .dependencies = try self.allocator.dupe(Ast.SystemDependency, dependencies),
            .mode = if (parallel_dependency) |dependency| .{ .query_dispatch = .{
                .dependency = dependency,
                .worker = worker_name,
            } } else .direct,
        } },
        .statements = &.{},
    });
    if (parallel_dependency) |dependency| try self.functions.append(self.allocator, .{
        .is_local = true,
        .specialization_file = callback.position.file,
        .position = callback.position,
        .name_position = callback.position,
        .name = worker_name,
        .parameters = try adapterParameters(self, callback.position, application_type, true),
        .return_type = .void,
        .intrinsic = .{ .system_adapter = .{
            .target = target_name.?,
            .target_position = callback.position,
            .receiver = receiver_dependency,
            .receiver_type = if (instance_method) |target| target.type else null,
            .dependencies = dependencies,
            .mode = .{ .query_range = .{ .dependency = dependency } },
        } },
        .statements = &.{},
    });
    call.arguments[1].value = .{ .identifier = adapter_name };
    if (world_mutable) ecs_access = true;
    const arguments = try self.allocator.alloc(*Ast.Expression, 6);
    arguments[0] = call.arguments[0];
    arguments[1] = call.arguments[1];
    arguments[2] = try booleanExpression(self, std.mem.eql(u8, call.name, "add_after_system"), callback.position);
    arguments[3] = try accessSequence(self, resource_reads.items, component_reads.items, callback.position);
    arguments[4] = try accessSequence(self, resource_writes.items, component_writes.items, callback.position);
    const flags: usize = (if (ecs_access) @as(usize, 1) else 0) |
        (if (world_mutable) @as(usize, 2) else 0) |
        (if (worker_safe) @as(usize, 4) else 0) |
        (if (parallel_dependency != null) @as(usize, 32) else 0);
    arguments[5] = try integerExpression(self, flags, callback.position);
    call.name = "__silex_add_system";
    call.compiler_generated = true;
    call.arguments = arguments;
    return true;
}

fn systemTargetName(allocator: std.mem.Allocator, expression: *const Ast.Expression) !?[]const u8 {
    return switch (expression.value) {
        .identifier => |name| name,
        .field_access => |access| if (access.base.value == .identifier)
            try std.fmt.allocPrint(allocator, "{s}.{s}", .{ access.base.value.identifier, access.name })
        else
            null,
        else => null,
    };
}

const InstanceSystemMethod = struct {
    type: Ast.Type,
    structure: Ast.Structure,
    method: Ast.Function,
};

fn findInstanceSystemMethod(self: anytype, requested: []const u8) ?InstanceSystemMethod {
    const dot = std.mem.lastIndexOfScalar(u8, requested, '.') orelse return null;
    const owner_name = requested[0..dot];
    const method_name = requested[dot + 1 ..];
    var found: ?InstanceSystemMethod = null;
    for (self.structures.items) |structure| {
        if (!typeNameMatches(structure.name, owner_name)) continue;
        for (structure.methods) |method| {
            if (method.is_static or method.type_parameters.len != 0 or !std.mem.eql(u8, method.name, method_name)) continue;
            if (found != null) return null;
            const type_value = self.typeForName(structure.name) orelse return null;
            found = .{ .type = type_value, .structure = structure, .method = method };
        }
    }
    return found;
}

fn typeNameMatches(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    if (!std.mem.endsWith(u8, candidate, requested) or candidate.len == requested.len) return false;
    return candidate[candidate.len - requested.len - 1] == '.';
}

fn registrationArguments(allocator: std.mem.Allocator, call: Ast.Expression.Call) !?[]const *Ast.Expression {
    if (call.arguments.len + call.named_arguments.len != 2 or call.arguments.len > 2) return null;
    var ordered = [_]?*Ast.Expression{ null, null };
    for (call.arguments, 0..) |argument, index| ordered[index] = argument;
    for (call.named_arguments) |argument| {
        const index: usize = if (std.mem.eql(u8, argument.name, "schedule"))
            0
        else if (std.mem.eql(u8, argument.name, "callback"))
            1
        else
            return null;
        if (ordered[index] != null) return null;
        ordered[index] = argument.value;
    }
    if (ordered[0] == null or ordered[1] == null) return null;
    const result = try allocator.alloc(*Ast.Expression, 2);
    result[0] = ordered[0].?;
    result[1] = ordered[1].?;
    return result;
}

fn adapterParameters(self: anytype, position: Source.Position, application_type: Ast.Type, range: bool) ![]const Ast.Parameter {
    const count: usize = if (range) 5 else 2;
    const parameters = try self.allocator.alloc(Ast.Parameter, count);
    parameters[0] = .{ .position = position, .name = "application", .type = application_type };
    parameters[1] = .{ .position = position, .name = "system_order", .type = .int };
    if (range) {
        parameters[2] = .{ .position = position, .name = "range_start", .type = .int };
        parameters[3] = .{ .position = position, .name = "range_end", .type = .int };
        parameters[4] = .{ .position = position, .name = "commands_address", .type = .uint };
    }
    return parameters;
}

fn appendUnique(allocator: std.mem.Allocator, values: *std.ArrayList([]const u8), value: []const u8) !void {
    for (values.items) |existing| if (std.mem.eql(u8, existing, value)) return;
    try values.append(allocator, value);
}

fn mainThreadType(name: []const u8) bool {
    return std.mem.eql(u8, name, "GFX.Window") or
        std.mem.eql(u8, name, "GFX.GPU") or
        std.mem.startsWith(u8, name, "GFX.Window.") or
        std.mem.startsWith(u8, name, "GFX.GPU.");
}

fn stringSequence(self: anytype, values: []const []const u8, position: Source.Position) !*Ast.Expression {
    const expressions = try self.allocator.alloc(*Ast.Expression, values.len);
    for (values, 0..) |value, index| {
        expressions[index] = try self.allocator.create(Ast.Expression);
        expressions[index].* = .{ .position = position, .value = .{ .string = value } };
    }
    const collection_type = for (self.structures.items, 0..) |structure, index| {
        if (structure.collection) |collection| if (collection.element == .str and collection.length == null and !collection.view) {
            break Ast.Type.structure(index);
        };
    } else return error.InvalidSource;
    const expression = try self.allocator.create(Ast.Expression);
    expression.* = .{ .position = position, .value = .{ .sequence_literal = .{
        .values = expressions,
        .inferred_type = collection_type,
    } } };
    return expression;
}

fn accessSequence(
    self: anytype,
    resources: []const []const u8,
    components: []const []const u8,
    position: Source.Position,
) !*Ast.Expression {
    const values = try self.allocator.alloc([]const u8, resources.len + components.len);
    for (resources, 0..) |value, index| {
        values[index] = try std.fmt.allocPrint(self.allocator, "resource:{s}", .{value});
    }
    for (components, 0..) |value, index| {
        values[resources.len + index] = try std.fmt.allocPrint(self.allocator, "component:{s}", .{value});
    }
    return stringSequence(self, values, position);
}

fn booleanExpression(self: anytype, value: bool, position: Source.Position) !*Ast.Expression {
    const expression = try self.allocator.create(Ast.Expression);
    expression.* = .{ .position = position, .value = .{ .boolean = value } };
    return expression;
}

fn integerExpression(self: anytype, value: usize, position: Source.Position) !*Ast.Expression {
    const expression = try self.allocator.create(Ast.Expression);
    expression.* = .{
        .position = position,
        .value = .{ .integer = try std.fmt.allocPrint(self.allocator, "{d}", .{value}) },
    };
    return expression;
}

fn findGenericMethod(structure: Ast.Structure, name: []const u8) ?Ast.Function {
    for (structure.methods) |method| {
        if (method.type_parameters.len == 1 and std.mem.eql(u8, method.name, name)) return method;
    }
    return null;
}

fn queryPatternsConflict(self: anytype, left_type: Ast.Type, right_type: Ast.Type) !bool {
    const left_query = self.structureForType(left_type) orelse return error.InvalidSource;
    const right_query = self.structureForType(right_type) orelse return error.InvalidSource;
    const left = self.structureForType(left_query.query_pattern orelse return error.InvalidSource) orelse return error.InvalidSource;
    const right = self.structureForType(right_query.query_pattern orelse return error.InvalidSource) orelse return error.InvalidSource;
    for (left.fields) |left_field| for (right.fields) |right_field| {
        if (left_field.type == right_field.type and
            (left_field.access_mode == .mutable or right_field.access_mode == .mutable)) return true;
    };
    return false;
}
