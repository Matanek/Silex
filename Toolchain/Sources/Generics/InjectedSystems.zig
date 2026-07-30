const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

const application_name = "GFX.Bootstrap.Application";
const resources_name = "GFX.Bootstrap.Resources";

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
        if (parameter.mode == .value) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "system parameter {d} must use '@{s}' or '&{s}'",
                .{ index + 1, self.typeName(dependency_type), self.typeName(dependency_type) },
            );
            return self.fail(callback.position, message);
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
        const has_template = findGenericMethod(resource_source, "has") orelse return error.InvalidSource;
        const get_template = findGenericMethod(resource_source, if (parameter.mode == .mutable) "get_mut" else "get") orelse return error.InvalidSource;
        dependencies[index] = .{
            .type = dependency_type,
            .mode = parameter.mode,
            .has_method = try self.instantiateMethod(resources_type, has_template, &.{dependency_type}, callback.position),
            .get_method = try self.instantiateMethod(resources_type, get_template, &.{dependency_type}, callback.position),
        };
    }

    const adapter_name = try std.fmt.allocPrint(self.allocator, "__silex_system_adapter_{d}", .{self.functions.items.len});
    try self.functions.append(self.allocator, .{
        .is_internal = true,
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
