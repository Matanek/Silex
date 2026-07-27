const std = @import("std");
const Ast = @import("../Ast.zig");
const GenericSyntax = @import("../Parser/Generics.zig");

pub fn specializeCall(self: anytype, copy: *Ast.Expression.Call, arguments: []const Ast.Type) !void {
    if (copy.receiver) |receiver| if (receiver.value == .generic_reference) {
        const reference = receiver.value.generic_reference;
        const nested_name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ reference.name, copy.name });
        if (self.typeForName(nested_name)) |base| if (self.structureTemplateForType(base) != null) {
            const type_arguments = try self.allocator.alloc(Ast.Type, reference.type_arguments.len + copy.type_arguments.len);
            for (reference.type_arguments, 0..) |argument, index| {
                type_arguments[index] = try self.rewriteType(argument, arguments, receiver.position);
            }
            for (copy.type_arguments, 0..) |argument, index| {
                type_arguments[reference.type_arguments.len + index] = try self.rewriteType(argument, arguments, copy.name_position);
            }
            copy.name = self.typeName(try self.instantiateStructure(base, type_arguments, copy.name_position));
            copy.receiver = null;
            copy.type_arguments = &.{};
        };
    };
    if (copy.receiver) |receiver| if (try GenericSyntax.qualifiedName(self.allocator, receiver)) |owner_name| {
        const nested_name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ owner_name, copy.name });
        if (self.typeForName(nested_name)) |base| if (self.structureTemplateForType(base) != null) {
            const type_arguments = try self.allocator.alloc(Ast.Type, copy.type_arguments.len);
            for (copy.type_arguments, 0..) |argument, index| {
                type_arguments[index] = try self.rewriteType(argument, arguments, copy.name_position);
            }
            copy.name = self.typeName(try self.instantiateStructure(base, type_arguments, copy.name_position));
            copy.receiver = null;
            copy.type_arguments = &.{};
        };
    };
}

pub fn concreteEnclosing(self: anytype, template: Ast.Structure, arguments: []const Ast.Type, position: @import("../Source.zig").Position) !?[]const u8 {
    const owner_name = template.enclosing orelse return null;
    const owner_type = self.typeForName(owner_name) orelse return error.InvalidSource;
    const owner_template = self.structureTemplateForType(owner_type) orelse return owner_name;
    if (owner_template.type_parameters.len > arguments.len) return error.InvalidSource;
    const concrete_owner = try self.instantiateStructure(
        owner_type,
        arguments[0..owner_template.type_parameters.len],
        position,
    );
    return self.typeName(concrete_owner);
}
