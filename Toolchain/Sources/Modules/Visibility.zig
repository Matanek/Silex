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
            if (self.hiddenInputTypeDeclaration(associated_type)) |declaration| {
                return self.failInternalInput("public enum", enumeration.name, declaration, variant.position);
            }
        };
    }
    for (program.protocols) |protocol| {
        if (!protocol.is_public) continue;
        for (protocol.requirements) |requirement| {
            try self.validateCallableInputs("public protocol method", requirement.name, requirement.parameters);
            if (self.hiddenInputReturnDeclaration(requirement.return_type)) |declaration| {
                return self.failInternalInput("public protocol method", requirement.name, declaration, requirement.position);
            }
        }
    }
    for (program.structures) |structure| {
        if (!structure.is_public) continue;
        for (structure.fields) |field| {
            if (field.visibility != .public_access) continue;
            if (self.hiddenInputTypeDeclaration(field.type)) |declaration| {
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
        if (self.hiddenInputTypeDeclaration(parameter.type)) |declaration| {
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
    const message = if (declaration.is_internal)
        try std.fmt.allocPrint(
            self.allocator,
            "{s} '{s}' cannot expose internal input type '{s}'",
            .{ callable_kind, callable_name, declaration.source_name },
        )
    else
        try std.fmt.allocPrint(
            self.allocator,
            "{s} '{s}' cannot expose non-public input type '{s}'",
            .{ callable_kind, callable_name, declaration.source_name },
        );
    return self.fail(position, message);
}

pub fn hiddenInputTypeDeclaration(self: anytype, value: Ast.TypeName) ?*const Declaration {
    return switch (value) {
        .structure => |name| self.hiddenInputNamedDeclaration(name),
        .generic_structure => |generic| hidden: {
            if (self.hiddenInputNamedDeclaration(generic.name)) |declaration| break :hidden declaration;
            for (generic.arguments) |argument| {
                if (self.hiddenInputTypeDeclaration(argument)) |declaration| break :hidden declaration;
            }
            break :hidden null;
        },
        .list, .view, .optional => |contained| self.hiddenInputTypeDeclaration(contained.*),
        .fixed_array => |array| self.hiddenInputTypeDeclaration(array.element.*),
        .reference => |reference| self.hiddenInputTypeDeclaration(reference.target.*),
        .function => |function| hidden: {
            for (function.parameters) |parameter| {
                if (self.hiddenInputTypeDeclaration(parameter)) |declaration| break :hidden declaration;
            }
            if (function.return_type) |return_type| {
                if (self.hiddenInputTypeDeclaration(return_type.*)) |declaration| break :hidden declaration;
            }
            break :hidden null;
        },
        else => null,
    };
}

pub fn hiddenInputReturnDeclaration(self: anytype, value: Ast.ReturnType) ?*const Declaration {
    return switch (value) {
        .structure => |name| self.hiddenInputNamedDeclaration(name),
        .generic_structure => |generic| self.hiddenInputTypeDeclaration(.{ .generic_structure = generic }),
        .list => |contained| self.hiddenInputTypeDeclaration(.{ .list = contained }),
        .view => |contained| self.hiddenInputTypeDeclaration(.{ .view = contained }),
        .optional => |contained| self.hiddenInputTypeDeclaration(.{ .optional = contained }),
        .fixed_array => |array| self.hiddenInputTypeDeclaration(.{ .fixed_array = array }),
        .reference => |reference| self.hiddenInputTypeDeclaration(.{ .reference = reference }),
        .function => |function| self.hiddenInputTypeDeclaration(.{ .function = function }),
        else => null,
    };
}

pub fn hiddenInputNamedDeclaration(self: anytype, name: []const u8) ?*const Declaration {
    if (self.findDeclarationByCanonicalName(name, .structure)) |declaration| {
        if (!self.declarationExternallyVisible(declaration)) return declaration;
    }
    if (self.findDeclarationByCanonicalName(name, .protocol)) |declaration| {
        if (!declaration.is_public or declaration.is_internal) return declaration;
    }
    return null;
}

pub fn declarationExternallyVisible(self: anytype, declaration: *const Declaration) bool {
    if (declaration.is_internal) return false;
    if (declaration.member_visibility) |visibility| {
        if (visibility != .public_access) return false;
        const owner_name = declaration.owner_source_name orelse return false;
        const owner = self.findDirect(declaration.module_index, owner_name, .structure) orelse return false;
        return self.declarationExternallyVisible(owner);
    }
    return declaration.is_public;
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
