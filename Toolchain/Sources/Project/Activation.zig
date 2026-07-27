pub fn activate(self: anytype, module: usize) !void {
    const program = self.units[module].program.?;
    for (program.structures) |structure| {
        if (structure.base) |base| try self.activateType(module, base);
        for (structure.conformances) |conformance| try self.activateType(module, conformance);
        for (structure.fields) |field| try self.activateType(module, field.type);
        for (structure.static_fields) |field| try self.activateType(module, field.type);
        for (structure.constructors) |constructor| {
            for (constructor.parameters) |parameter| try self.activateType(module, parameter.type);
            for (constructor.super_arguments) |argument| try self.activateExpression(module, argument);
            for (constructor.statements) |statement| try self.activateStatement(module, statement);
        }
        for (structure.methods) |method| {
            for (method.parameters) |parameter| try self.activateType(module, parameter.type);
            try self.activateType(module, method.return_type);
            for (method.statements) |statement| try self.activateStatement(module, statement);
        }
    }
    for (program.enums) |enumeration| for (enumeration.variants) |variant| {
        for (variant.associated_types) |associated_type| try self.activateType(module, associated_type);
    };
    for (program.enums) |enumeration| {
        if (!enumeration.is_public) continue;
        for (enumeration.variants) |variant| for (variant.associated_types) |associated_type| {
            try self.requirePublicType(module, associated_type, variant.position, "public enum", enumeration.name);
        };
    }
    for (program.functions) |function| {
        for (function.parameters) |parameter| try self.activateType(module, parameter.type);
        try self.activateType(module, function.return_type);
        for (function.statements) |statement| try self.activateStatement(module, statement);
    }
}
