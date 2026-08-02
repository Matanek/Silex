const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

const application_name = "GFX.Bootstrap.Application";
const resources_name = "GFX.Bootstrap.Resources";
const world_name = "GFX.ECS.World";

pub fn rewriteRegistration(self: anytype, call: *Ast.Expression.Call, locals: anytype) !bool {
    if (call.receiver == null or call.arguments.len != 2 or call.named_arguments.len != 0) return false;
    if (!std.mem.eql(u8, call.name, "add_system") and !std.mem.eql(u8, call.name, "add_after_system")) return false;
    const receiver_type = self.inferExpressionType(call.receiver.?, locals) orelse return false;
    const receiver = self.structureForType(receiver_type) orelse return false;
    if (!std.mem.eql(u8, receiver.name, application_name)) return false;

    const callback = call.arguments[1];
    const callback_type = self.inferExpressionType(callback, locals) orelse {
        return self.fail(callback.position, "system callback must be a named or captureless function");
    };
    const function_index = callback_type.functionIndex() orelse {
        return self.fail(callback.position, "system callback must be a function");
    };
    if (function_index >= self.source.function_types.len) return error.InvalidSource;
    const signature = self.source.function_types[function_index];
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
    if (callback.value != .identifier) {
        return self.fail(callback.position, "system callback must be a named or captureless function");
    }

    const resources_type = self.typeForName(resources_name) orelse return error.InvalidSource;
    const resource_source = self.sourceStructureForType(resources_type) orelse return error.InvalidSource;
    const dependencies = try self.allocator.alloc(Ast.SystemDependency, signature.parameters.len);
    for (signature.parameters, 0..) |parameter, index| {
        const dependency_type = try self.rewriteType(parameter.type, &.{}, callback.position);
        const dependency_structure = self.structureForType(dependency_type);
        const is_query = dependency_structure != null and dependency_structure.?.query_pattern != null;
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
        const source_type = if (is_query)
            self.typeForName(world_name) orelse return error.InvalidSource
        else
            dependency_type;
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

    const adapter_name = try std.fmt.allocPrint(self.allocator, "__silex_system_adapter_{d}", .{self.functions.items.len});
    try self.functions.append(self.allocator, .{
        .is_local = true,
        .specialization_file = callback.position.file,
        .position = callback.position,
        .name_position = callback.position,
        .name = adapter_name,
        .parameters = try self.allocator.dupe(Ast.Parameter, &.{.{
            .position = callback.position,
            .name = "application",
            .type = application_type,
        }}),
        .return_type = .void,
        .intrinsic = .{ .system_adapter = .{
            .target = callback.value.identifier,
            .target_position = callback.position,
            .dependencies = dependencies,
        } },
        .statements = &.{},
    });
    call.arguments[1].value.identifier = adapter_name;
    return true;
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
