const std = @import("std");
const Ast = @import("../Ast.zig");
const GenericTypes = @import("GenericTypes.zig");

pub fn compose(
    self: anytype,
    module: usize,
    provider: anytype,
    source: Ast.Extension,
    type_map: []const Ast.Type,
    generic_map: []const Ast.Type,
) !Ast.Extension {
    var result = source;
    result.target = GenericTypes.remap(source.target, type_map, generic_map);
    result.provider = provider.name;
    result.visible_files = try visibleFiles(self, module);
    const conformances = try self.allocator.alloc(Ast.Type, source.conformances.len);
    for (source.conformances, 0..) |conformance, index| conformances[index] = GenericTypes.remap(conformance, type_map, generic_map);
    result.conformances = conformances;
    const methods = try self.allocator.alloc(Ast.Function, source.methods.len);
    for (source.methods, 0..) |method, method_index| {
        methods[method_index] = method;
        methods[method_index].owner = provider.owner;
        methods[method_index].type_parameters = try GenericTypes.remapParameters(self.allocator, method.type_parameters, type_map, generic_map);
        const parameters = try self.allocator.alloc(Ast.Parameter, method.parameters.len);
        for (method.parameters, 0..) |parameter, parameter_index| {
            parameters[parameter_index] = parameter;
            parameters[parameter_index].type = GenericTypes.remap(parameter.type, type_map, generic_map);
            if (parameter.default) |value| try self.rewriteExpression(module, value, type_map);
        }
        methods[method_index].parameters = parameters;
        methods[method_index].return_type = GenericTypes.remap(method.return_type, type_map, generic_map);
        methods[method_index].statements = try self.rewriteStatements(module, method.statements, type_map);
    }
    result.methods = methods;
    return result;
}

fn visibleFiles(self: anytype, provider: usize) ![]const usize {
    var result: std.ArrayList(usize) = .empty;
    for (self.units, 0..) |unit, consumer| {
        if (unit.state != .loaded) continue;
        const visited = try self.allocator.alloc(bool, self.units.len);
        @memset(visited, false);
        if (dependsOn(self.units, consumer, provider, visited)) try result.append(self.allocator, self.index.providers[consumer].file);
    }
    return result.toOwnedSlice(self.allocator);
}

fn dependsOn(units: anytype, source: usize, target: usize, visited: []bool) bool {
    if (source == target) return true;
    if (visited[source]) return false;
    visited[source] = true;
    for (units[source].bindings) |binding| if (binding.module) |dependency| {
        if (dependsOn(units, dependency, target, visited)) return true;
    };
    return false;
}
