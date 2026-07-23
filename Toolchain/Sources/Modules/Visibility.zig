const Types = @import("Types.zig");
const std = Types.std;
const Ast = Types.Ast;
const Source = Types.Source;
const Declaration = Types.Declaration;
const Allocator = Types.Allocator;

pub fn validatePublicInputs(self: anytype, program: Ast.Program) !void {
    for (program.enums) |enumeration| {
        if (!enumeration.is_public) continue;
        for (enumeration.variants) |variant| for (variant.associated_types) |associated_type| {
            if (self.internalTypeDeclaration(associated_type)) |declaration| {
                return self.failInternalInput("public enum", enumeration.name, declaration, variant.position);
            }
        };
    }
    for (program.protocols) |protocol| {
        if (!protocol.is_public) continue;
        for (protocol.requirements) |requirement| {
            try self.validateCallableInputs("public protocol method", requirement.name, requirement.parameters);
            if (self.internalReturnDeclaration(requirement.return_type)) |declaration| {
                return self.failInternalInput("public protocol method", requirement.name, declaration, requirement.position);
            }
        }
    }
    for (program.structures) |structure| {
        if (!structure.is_public) continue;
        for (structure.fields) |field| {
            if (field.visibility != .public_access) continue;
            if (self.internalTypeDeclaration(field.type)) |declaration| {
                return self.failInternalInput("public field", field.name, declaration, field.position);
            }
        }
        for (structure.constructors) |constructor| {
            if (constructor.visibility != .public_access) continue;
            try self.validateCallableInputs("public constructor", structure.name, constructor.parameters);
        }
        for (structure.methods) |method| {
            if (method.member_visibility != .public_access) continue;
            try self.validateCallableInputs("public method", method.name, method.parameters);
        }
    }
    for (program.functions) |function| {
        if (!function.is_public) continue;
        try self.validateCallableInputs("public function", function.name, function.parameters);
    }
}

pub fn validateCallableInputs(
    self: anytype,
    callable_kind: []const u8,
    callable_name: []const u8,
    parameters: []const Ast.Parameter,
) !void {
    for (parameters) |parameter| {
        if (self.internalTypeDeclaration(parameter.type)) |declaration| {
            return self.failInternalInput(callable_kind, callable_name, declaration, parameter.position);
        }
    }
}

pub fn failInternalInput(
    self: anytype,
    callable_kind: []const u8,
    callable_name: []const u8,
    declaration: *const Declaration,
    position: Source.Position,
) (Source.Error || Allocator.Error) {
    const message = try std.fmt.allocPrint(
        self.allocator,
        "{s} '{s}' cannot expose internal input type '{s}'",
        .{ callable_kind, callable_name, declaration.source_name },
    );
    return self.fail(position, message);
}

pub fn internalTypeDeclaration(self: anytype, value: Ast.TypeName) ?*const Declaration {
    return switch (value) {
        .structure => |name| self.internalNamedDeclaration(name),
        .generic_structure => |generic| internal: {
            if (self.internalNamedDeclaration(generic.name)) |declaration| break :internal declaration;
            for (generic.arguments) |argument| {
                if (self.internalTypeDeclaration(argument)) |declaration| break :internal declaration;
            }
            break :internal null;
        },
        .list, .view, .optional => |contained| self.internalTypeDeclaration(contained.*),
        .fixed_array => |array| self.internalTypeDeclaration(array.element.*),
        .reference => |reference| self.internalTypeDeclaration(reference.target.*),
        .function => |function| internal: {
            for (function.parameters) |parameter| {
                if (self.internalTypeDeclaration(parameter)) |declaration| break :internal declaration;
            }
            if (function.return_type) |return_type| {
                if (self.internalTypeDeclaration(return_type.*)) |declaration| break :internal declaration;
            }
            break :internal null;
        },
        else => null,
    };
}

pub fn internalReturnDeclaration(self: anytype, value: Ast.ReturnType) ?*const Declaration {
    return switch (value) {
        .structure => |name| self.internalNamedDeclaration(name),
        .generic_structure => |generic| self.internalTypeDeclaration(.{ .generic_structure = generic }),
        .list => |contained| self.internalTypeDeclaration(.{ .list = contained }),
        .view => |contained| self.internalTypeDeclaration(.{ .view = contained }),
        .optional => |contained| self.internalTypeDeclaration(.{ .optional = contained }),
        .fixed_array => |array| self.internalTypeDeclaration(.{ .fixed_array = array }),
        .reference => |reference| self.internalTypeDeclaration(.{ .reference = reference }),
        .function => |function| self.internalTypeDeclaration(.{ .function = function }),
        else => null,
    };
}

pub fn internalNamedDeclaration(self: anytype, name: []const u8) ?*const Declaration {
    if (self.findDeclarationByCanonicalName(name, .structure)) |declaration| {
        if (declaration.is_internal) return declaration;
    }
    if (self.findDeclarationByCanonicalName(name, .protocol)) |declaration| {
        if (declaration.is_internal) return declaration;
    }
    return null;
}
