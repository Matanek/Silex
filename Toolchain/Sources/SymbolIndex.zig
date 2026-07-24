const std = @import("std");
const Ast = @import("Ast.zig");
const Lexer = @import("Lexer.zig");
const Modules = @import("Modules.zig");
const Project = @import("Project.zig");
const Semantic = @import("Semantic.zig");
const Source = @import("Source.zig");

const Allocator = std.mem.Allocator;

pub const Kind = enum {
    module,
    alias,
    type,
    enumeration,
    variant,
    protocol,
    requirement,
    field,
    constructor,
    function,
    method,
    type_parameter,
    parameter,
    variable,
    binding,
};

pub const Symbol = struct {
    id: usize,
    name: []const u8,
    key: []const u8,
    kind: Kind,
    definition: Source.Position,
    detail: []const u8,
    module_name: []const u8,
    origin: Project.ModuleOrigin,
    owner: []const u8 = "",
    is_static: bool = false,
    is_public: bool = false,
    is_internal: bool = false,
    visibility: ?Ast.MemberVisibility = null,
    alias_target_kind: ?Kind = null,
    rename_group: usize,
};

pub const Occurrence = struct {
    symbol: usize,
    position: Source.Position,
    length: usize,
    definition: bool = false,
};

pub const Index = struct {
    symbols: []const Symbol,
    occurrences: []const Occurrence,

    pub fn occurrenceAt(self: Index, file: usize, line: usize, byte_column: usize) ?Occurrence {
        for (self.occurrences) |occurrence| {
            if (occurrence.position.file != file or occurrence.position.line != line) continue;
            const start = occurrence.position.column;
            if (byte_column >= start and byte_column <= start + occurrence.length) return occurrence;
        }
        return null;
    }

    pub fn symbol(self: Index, id: usize) Symbol {
        return self.symbols[id];
    }
};

const Builder = struct {
    allocator: Allocator,
    project: Project.Project,
    files: []const Modules.File,
    source_contents: []const []const u8,
    symbols: std.ArrayList(Symbol) = .empty,
    occurrences: std.ArrayList(Occurrence) = .empty,

    fn addSymbol(
        self: *Builder,
        name: []const u8,
        key: []const u8,
        kind: Kind,
        position: Source.Position,
        detail: []const u8,
    ) !usize {
        const id = self.symbols.items.len;
        const module = self.moduleAt(position.file);
        try self.symbols.append(self.allocator, .{
            .id = id,
            .name = name,
            .key = key,
            .kind = kind,
            .definition = position,
            .detail = detail,
            .module_name = if (module) |value| value.name else "",
            .origin = if (module) |value| value.origin else .application,
            .rename_group = id,
        });
        try self.addOccurrence(id, position, true);
        return id;
    }

    fn moduleAt(self: *const Builder, file: usize) ?Project.Module {
        if (file >= self.files.len) return null;
        const module_index = self.files[file].module_index;
        return if (module_index < self.project.modules.len) self.project.modules[module_index] else null;
    }

    fn addOccurrence(self: *Builder, symbol: usize, position: Source.Position, definition: bool) !void {
        for (self.occurrences.items) |existing| {
            if (existing.position.file == position.file and existing.position.line == position.line and
                existing.position.column == position.column)
            {
                return;
            }
        }
        try self.occurrences.append(self.allocator, .{
            .symbol = symbol,
            .position = position,
            .length = self.identifierLength(position),
            .definition = definition,
        });
    }

    fn identifierLength(self: *const Builder, position: Source.Position) usize {
        if (position.file >= self.source_contents.len) return 1;
        const source = self.source_contents[position.file];
        const offset = byteOffset(source, position) orelse return 1;
        var end = offset;
        while (end < source.len and (std.ascii.isAlphanumeric(source[end]) or source[end] == '_')) end += 1;
        return @max(@as(usize, 1), end - offset);
    }

    fn symbolByKey(self: *const Builder, key: []const u8) ?usize {
        for (self.symbols.items) |symbol| if (std.mem.eql(u8, symbol.key, key)) return symbol.id;
        return null;
    }

    fn symbolAt(self: *const Builder, position: Source.Position, kind: Kind) ?usize {
        for (self.symbols.items) |symbol| {
            if (symbol.kind == kind and symbol.definition.file == position.file and
                symbol.definition.line == position.line and symbol.definition.column == position.column)
            {
                return symbol.id;
            }
        }
        return null;
    }

    fn recordKey(self: *Builder, key: []const u8, position: Source.Position) !void {
        if (self.symbolByResolvedKey(key)) |id| try self.addOccurrence(id, position, false);
    }

    fn recordKeyKind(self: *Builder, key: []const u8, position: Source.Position, kind: Kind) !void {
        if (self.symbolByResolvedKeyKind(key, kind)) |id| try self.addOccurrence(id, position, false);
    }

    fn symbolByResolvedKey(self: *const Builder, key: []const u8) ?usize {
        if (self.symbolByKey(key)) |id| return id;
        var match: ?usize = null;
        for (self.symbols.items) |symbol| {
            if (!std.mem.startsWith(u8, symbol.key, key) or symbol.key.len <= key.len or symbol.key[key.len] != '_') continue;
            if (match != null) return null;
            match = symbol.id;
        }
        return match;
    }

    fn symbolByResolvedKeyKind(self: *const Builder, key: []const u8, kind: Kind) ?usize {
        for (self.symbols.items) |symbol| {
            if (symbol.kind == kind and std.mem.eql(u8, symbol.key, key)) return symbol.id;
        }
        var match: ?usize = null;
        for (self.symbols.items) |symbol| {
            if (symbol.kind != kind or !std.mem.startsWith(u8, symbol.key, key) or
                symbol.key.len <= key.len or symbol.key[key.len] != '_')
            {
                continue;
            }
            if (match != null) return null;
            match = symbol.id;
        }
        return match;
    }

    fn addProgramDeclarations(self: *Builder, ast: Ast.Program, program: Semantic.Program) !void {
        for (ast.enums, program.enums) |ast_enum, enumeration| {
            const enum_id = try self.addSymbol(
                sourceSpelling(ast_enum.name),
                enumeration.generated_name,
                .enumeration,
                ast_enum.name_position,
                try typeHeader(self.allocator, ast_enum),
            );
            self.symbols.items[enum_id].is_public = ast_enum.is_public;
            self.symbols.items[enum_id].is_internal = ast_enum.is_internal;
            for (ast_enum.variants, 0..) |variant, variant_index| {
                const key = try std.fmt.allocPrint(self.allocator, "{s}#variant#{d}", .{ enumeration.generated_name, variant_index });
                const variant_id = try self.addSymbol(
                    variant.name,
                    key,
                    .variant,
                    variant.position,
                    try variantDetail(self.allocator, ast_enum, variant),
                );
                self.symbols.items[variant_id].is_public = ast_enum.is_public;
                self.symbols.items[variant_id].is_internal = ast_enum.is_internal;
            }
        }
        for (ast.protocols, program.protocols) |ast_protocol, protocol| {
            const protocol_id = try self.addSymbol(
                sourceSpelling(ast_protocol.name),
                protocol.generated_name,
                .protocol,
                ast_protocol.name_position,
                try std.fmt.allocPrint(self.allocator, "{s}protocol {s}", .{ declarationVisibilityPrefix(ast_protocol.is_public, ast_protocol.is_internal), sourceSpelling(ast_protocol.name) }),
            );
            self.symbols.items[protocol_id].is_public = ast_protocol.is_public;
            self.symbols.items[protocol_id].is_internal = ast_protocol.is_internal;
            for (ast_protocol.requirements, protocol.requirements) |requirement, semantic_requirement| {
                const requirement_id = try self.addSymbol(
                    requirement.name,
                    semantic_requirement.generated_name,
                    .requirement,
                    requirement.name_position,
                    try functionDetail(self.allocator, requirement),
                );
                self.symbols.items[requirement_id].is_public = ast_protocol.is_public;
                self.symbols.items[requirement_id].is_internal = ast_protocol.is_internal;
            }
        }
        for (ast.structures, program.structures) |ast_structure, structure| {
            const structure_id = try self.addSymbol(
                sourceSpelling(ast_structure.name),
                structure.generated_name,
                .type,
                ast_structure.name_position,
                try structureHeader(self.allocator, ast_structure),
            );
            self.symbols.items[structure_id].is_public = ast_structure.is_public;
            self.symbols.items[structure_id].is_internal = ast_structure.is_internal;
            if (ast_structure.owner_name) |owner_name| {
                for (program.structures) |candidate| {
                    if (!std.mem.eql(u8, candidate.source_name, owner_name)) continue;
                    self.symbols.items[structure_id].owner = candidate.generated_name;
                    self.symbols.items[structure_id].is_static = true;
                    self.symbols.items[structure_id].visibility = ast_structure.member_visibility;
                    break;
                }
            }
            for (ast_structure.fields) |ast_field| {
                const fields = if (ast_field.is_static) structure.static_fields else structure.fields;
                for (fields) |field| {
                    if (!std.mem.eql(u8, field.source_name, ast_field.name)) continue;
                    const field_key = try memberKey(self.allocator, structure.generated_name, field.generated_name);
                    const field_id = try self.addSymbol(
                        ast_field.name,
                        field_key,
                        .field,
                        ast_field.position,
                        try fieldDetail(self.allocator, ast_field, field.type),
                    );
                    self.symbols.items[field_id].owner = structure.generated_name;
                    self.symbols.items[field_id].is_static = ast_field.is_static;
                    self.symbols.items[field_id].visibility = field.visibility;
                    break;
                }
            }
            for (ast_structure.constructors, structure.constructors, 0..) |constructor, semantic_constructor, index| {
                const key = try std.fmt.allocPrint(self.allocator, "{s}#init#{d}", .{ structure.generated_name, index });
                const constructor_id = try self.addSymbol("init", key, .constructor, constructor.position, try constructorDetail(
                    self.allocator,
                    sourceSpelling(ast_structure.name),
                    constructor,
                    semantic_constructor,
                ));
                self.symbols.items[constructor_id].owner = structure.generated_name;
                self.symbols.items[constructor_id].is_static = true;
                self.symbols.items[constructor_id].visibility = semantic_constructor.visibility;
                try self.addParameters(constructor.parameters, semantic_constructor.parameters);
            }
            for (ast_structure.methods, structure.methods) |method, semantic_method| {
                const method_id = try self.addSymbol(
                    sourceSpelling(method.name),
                    semantic_method.generated_name,
                    .method,
                    method.name_position,
                    try functionDetail(self.allocator, method),
                );
                self.symbols.items[method_id].owner = structure.generated_name;
                self.symbols.items[method_id].is_static = method.is_static;
                self.symbols.items[method_id].visibility = semantic_method.visibility;
                try self.addParameters(method.parameters, semantic_method.parameters);
            }
        }
        for (ast.functions, program.functions) |function, semantic_function| {
            const function_id = try self.addSymbol(
                sourceSpelling(function.name),
                semantic_function.generated_name,
                .function,
                function.name_position,
                try functionDetail(self.allocator, function),
            );
            self.symbols.items[function_id].is_public = function.is_public;
            self.symbols.items[function_id].is_internal = function.is_internal;
            try self.addParameters(function.parameters, semantic_function.parameters);
        }
        try self.addUseSymbols();
    }

    fn addUseSymbols(self: *Builder) !void {
        for (self.files) |file| for (file.program.uses) |use_value| {
            const name: []const u8 = use_value.alias orelse switch (use_value.target) {
                .declaration => |path| if (self.moduleNamed(path)) sourceSpelling(path) else continue,
                .type => continue,
            };
            const position = use_value.alias_position orelse use_value.position;
            const kind: Kind = if (use_value.alias != null) .alias else .module;
            const key = try std.fmt.allocPrint(
                self.allocator,
                "use#{d}#{d}#{d}",
                .{ position.file, position.line, position.column },
            );
            const id = try self.addSymbol(name, key, kind, position, try useDetail(self.allocator, use_value, name));
            self.symbols.items[id].is_public = use_value.is_public;
            self.symbols.items[id].alias_target_kind = switch (use_value.target) {
                .type => .type,
                .declaration => |path| self.declarationKind(file.module_index, path) orelse if (self.moduleNamed(path)) .module else null,
            };
        };
    }

    fn declarationKind(self: *const Builder, current_module: usize, path: []const u8) ?Kind {
        var target_module = current_module;
        var name = path;
        var module_name_length: usize = 0;
        if (self.moduleIndexNamed(path)) |module_index| {
            target_module = module_index;
            name = sourceSpelling(path);
            module_name_length = path.len;
        } else for (self.project.modules, 0..) |module, module_index| {
            if (module.name.len <= module_name_length or path.len <= module.name.len or
                !std.mem.startsWith(u8, path, module.name) or path[module.name.len] != '.') continue;
            target_module = module_index;
            module_name_length = module.name.len;
            name = path[module.name.len + 1 ..];
        }
        var result: ?Kind = null;
        for (self.files) |file| {
            if (file.module_index != target_module) continue;
            if (astStructureAtPath(file.program.structures, name) != null)
                trySetDeclarationKind(&result, .type) catch return null;
            for (file.program.enums) |value| if (std.mem.eql(u8, sourceSpelling(value.name), name))
                trySetDeclarationKind(&result, .enumeration) catch return null;
            for (file.program.protocols) |value| if (std.mem.eql(u8, sourceSpelling(value.name), name))
                trySetDeclarationKind(&result, .protocol) catch return null;
            for (file.program.functions) |value| if (std.mem.eql(u8, sourceSpelling(value.name), name))
                trySetDeclarationKind(&result, .function) catch return null;
        }
        return result;
    }

    fn moduleIndexNamed(self: *const Builder, name: []const u8) ?usize {
        for (self.project.modules, 0..) |module, index| if (std.mem.eql(u8, module.name, name)) return index;
        return null;
    }

    fn moduleNamed(self: *const Builder, name: []const u8) bool {
        for (self.project.modules) |module| if (std.mem.eql(u8, module.name, name)) return true;
        return false;
    }

    fn linkRenameGroups(self: *Builder, ast: Ast.Program, program: Semantic.Program) void {
        for (ast.structures, program.structures) |ast_structure, structure| {
            for (ast_structure.methods, structure.methods) |method, semantic_method| {
                if (!semantic_method.is_override) continue;
                const derived = self.symbolAt(method.name_position, .method) orelse continue;
                var base_name = if (structure.base) |base| @as(?[]const u8, base.generated_name) else null;
                while (base_name) |name| {
                    const base_index = structureIndex(program.structures, name) orelse break;
                    const base_ast = ast.structures[base_index];
                    const base = program.structures[base_index];
                    var linked = false;
                    for (base_ast.methods, base.methods) |base_method, semantic_base_method| {
                        if (!std.mem.eql(u8, sourceSpelling(method.name), sourceSpelling(base_method.name)) or
                            method.parameters.len != base_method.parameters.len)
                        {
                            continue;
                        }
                        _ = semantic_base_method;
                        const ancestor = self.symbolAt(base_method.name_position, .method) orelse continue;
                        self.mergeRenameGroups(derived, ancestor);
                        linked = true;
                        break;
                    }
                    if (linked) break;
                    base_name = if (base.base) |next| next.generated_name else null;
                }
            }

            for (structure.protocol_conformances) |conformance| {
                if (conformance.protocol_index >= program.protocols.len) continue;
                const protocol = program.protocols[conformance.protocol_index];
                for (protocol.requirements, conformance.method_generated_names) |requirement, method_name| {
                    const requirement_id = self.symbolByResolvedKeyKind(requirement.generated_name, .requirement) orelse continue;
                    const method_id = self.symbolByResolvedKeyKind(method_name, .method) orelse continue;
                    self.mergeRenameGroups(requirement_id, method_id);
                }
            }
        }
    }

    fn mergeRenameGroups(self: *Builder, left: usize, right: usize) void {
        const left_group = self.symbols.items[left].rename_group;
        const right_group = self.symbols.items[right].rename_group;
        if (left_group == right_group) return;
        const retained = @min(left_group, right_group);
        const replaced = @max(left_group, right_group);
        for (self.symbols.items) |*symbol| {
            if (symbol.rename_group == replaced) symbol.rename_group = retained;
        }
    }

    fn addParameters(self: *Builder, ast: []const Ast.Parameter, semantic: []const Semantic.Parameter) !void {
        for (ast, semantic) |parameter, value| {
            _ = try self.addSymbol(
                parameter.name,
                value.generated_name,
                .parameter,
                parameter.position,
                try bindingDetail(self.allocator, parameter.name, value.type, null),
            );
        }
    }

    fn recordProgram(self: *Builder, program: Semantic.Program) !void {
        for (program.enums) |enumeration| for (enumeration.variants) |variant| {
            if (variant.raw_value) |value| try self.recordExpression(value);
        };
        for (program.structures) |structure| {
            for (structure.fields) |field| if (field.initializer) |value| try self.recordExpression(value);
            for (structure.static_fields) |field| if (field.initializer) |value| try self.recordExpression(value);
            for (structure.constructors) |constructor| {
                try self.recordParameters(constructor.parameters);
                if (constructor.base_initializer) |base| {
                    try self.recordKey(base.generated_name, .{ .line = 1, .column = 1 });
                    for (base.arguments) |argument| try self.recordExpression(argument);
                }
                try self.recordStatements(constructor.statements);
            }
            if (structure.drop) |drop| try self.recordStatements(drop.statements);
            for (structure.methods) |method| {
                try self.recordParameters(method.parameters);
                try self.recordStatements(method.statements);
            }
        }
        for (program.functions) |function| {
            try self.recordParameters(function.parameters);
            try self.recordStatements(function.statements);
        }
    }

    fn recordParameters(self: *Builder, parameters: []const Semantic.Parameter) !void {
        for (parameters) |parameter| {
            if (parameter.position.line != 1 or parameter.position.column != 1 or parameter.position.file != 0) {
                try self.recordKey(parameter.generated_name, parameter.position);
            }
        }
    }

    fn recordStatements(self: *Builder, statements: []const Semantic.Statement) Allocator.Error!void {
        for (statements) |statement| switch (statement) {
            .print => |value| try self.recordExpression(value),
            .assertion => |value| {
                try self.recordExpression(value.condition);
                try self.recordExpression(value.message);
            },
            .panic_statement => |value| try self.recordExpression(value.message),
            .variable_declaration => |value| {
                if (self.symbolByKey(value.generated_name) == null) _ = try self.addSymbol(
                    value.source_name,
                    value.generated_name,
                    .variable,
                    value.position,
                    try bindingDetail(self.allocator, value.source_name, value.type, value.mutability),
                );
                try self.recordExpression(value.initializer);
            },
            .assignment => |value| {
                try self.recordExpression(value.target);
                if (value.value) |assigned| try self.recordExpression(assigned);
            },
            .if_statement => |value| {
                try self.recordCondition(value.condition);
                try self.recordStatements(value.body);
                for (value.alternatives) |alternative| {
                    try self.recordCondition(alternative.condition);
                    try self.recordStatements(alternative.body);
                }
                if (value.else_body) |body| try self.recordStatements(body);
            },
            .while_statement => |value| {
                try self.recordCondition(value.condition);
                try self.recordStatements(value.body);
            },
            .mutex_statement => |body| try self.recordStatements(body),
            .for_statement => |value| {
                if (self.symbolByKey(value.generated_name) == null) _ = try self.addSymbol(
                    value.source_name,
                    value.generated_name,
                    .binding,
                    value.position,
                    try bindingDetail(self.allocator, value.source_name, value.element_type, null),
                );
                switch (value.source) {
                    .collection => |source| try self.recordExpression(source),
                    .integer_range => |range| {
                        try self.recordExpression(range.start);
                        try self.recordExpression(range.end);
                    },
                }
                try self.recordStatements(value.body);
            },
            .break_statement, .continue_statement => {},
            .return_statement => |value| if (value) |expression| try self.recordExpression(expression),
            .expression_statement => |value| try self.recordExpression(value),
        };
    }

    fn recordCondition(self: *Builder, condition: Semantic.Statement.Condition) Allocator.Error!void {
        switch (condition) {
            .expression => |value| try self.recordExpression(value),
            .binding => |value| {
                if (self.symbolByKey(value.generated_name) == null) _ = try self.addSymbol(
                    value.source_name,
                    value.generated_name,
                    .binding,
                    value.position,
                    try bindingDetail(self.allocator, value.source_name, value.type, value.mutability),
                );
                try self.recordExpression(value.source);
            },
        }
    }

    fn recordExpression(self: *Builder, expression: *const Semantic.Expression) Allocator.Error!void {
        switch (expression.value) {
            .integer, .floating, .boolean, .null, .string, .self, .owner_self, .cascade_target => {},
            .variable => |value| try self.recordKey(value.generated_name, expression.position),
            .optional_unwrap => |value| try self.recordKey(value.generated_name, expression.position),
            .static_field_access => |value| try self.recordKey(
                try memberKey(self.allocator, value.owner_generated_name, value.generated_name),
                expression.position,
            ),
            .call => |value| {
                try self.recordKeyKind(value.generated_name, expression.position, .function);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .function_reference => |generated_name| try self.recordKeyKind(generated_name, expression.position, .function),
            .method_call => |value| {
                try self.recordKeyKind(value.generated_name, value.position, .method);
                try self.recordExpression(value.object);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .protocol_method_call => |value| {
                try self.recordKeyKind(value.generated_name, value.position, .requirement);
                try self.recordExpression(value.object);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .static_method_call => |value| {
                try self.recordKeyKind(value.generated_name, expression.position, .method);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .super_method_call => |value| {
                try self.recordKeyKind(value.generated_name, expression.position, .method);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .member_access, .bound_function => |value| {
                if (expressionStructureName(value.object)) |owner| {
                    try self.recordKeyKind(try memberKey(self.allocator, owner, value.generated_name), expression.position, .field);
                }
                try self.recordExpression(value.object);
            },
            .class_initializer => |value| {
                try self.recordKey(value.generated_name, expression.position);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .structure_initializer => |value| {
                try self.recordKey(value.generated_name, expression.position);
                for (value.fields) |field| try self.recordExpression(field);
            },
            .enum_initializer => |value| {
                const key = try std.fmt.allocPrint(self.allocator, "{s}#variant#{d}", .{ value.enum_generated_name, value.variant_index });
                try self.recordKey(key, expression.position);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .string_length => |value| try self.recordExpression(value),
            .sequence_literal => |values| for (values) |value| try self.recordExpression(value),
            .collection_method => |value| {
                try self.recordExpression(value.object);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .value_call => |value| {
                try self.recordExpression(value.callee);
                if (value.owner) |owner| try self.recordExpression(owner);
                for (value.arguments) |argument| try self.recordExpression(argument);
            },
            .lambda => |value| {
                for (value.parameters) |parameter| if (self.symbolByKey(parameter.generated_name) == null) {
                    _ = try self.addSymbol(
                        parameter.source_name,
                        parameter.generated_name,
                        .parameter,
                        parameter.position,
                        try bindingDetail(self.allocator, parameter.source_name, parameter.type, null),
                    );
                };
                try self.recordStatements(value.statements);
            },
            .cascade => |value| {
                try self.recordExpression(value.object);
                for (value.operations) |operation| switch (operation) {
                    .method_call => |method| try self.recordExpression(method),
                    .field_assignment => |field| try self.recordExpression(field.value),
                };
            },
            .enum_raw_value, .optional_wrap, .adapt_function => |value| try self.recordExpression(value),
            .safe_access => |value| {
                try self.recordExpression(value.receiver);
                try self.recordExpression(value.end);
            },
            .match_expression => |value| {
                try self.recordExpression(value.subject);
                for (value.branches) |branch| {
                    for (branch.bindings) |binding| if (self.symbolByKey(binding.generated_name) == null) {
                        _ = try self.addSymbol(
                            binding.source_name,
                            binding.generated_name,
                            .binding,
                            binding.position,
                            try bindingDetail(self.allocator, binding.source_name, binding.type, binding.mutability),
                        );
                    };
                    switch (branch.body) {
                        .expression => |body| try self.recordExpression(body),
                        .statements => |body| try self.recordStatements(body),
                    }
                }
            },
            .index_access => |value| {
                try self.recordExpression(value.object);
                try self.recordExpression(value.index);
            },
            .slice_access => |value| {
                try self.recordExpression(value.object);
                try self.recordExpression(value.start);
                try self.recordExpression(value.end);
            },
            .try_expression => |value| try self.recordExpression(value.operand),
            .move_expression => |value| try self.recordExpression(value.operand),
            .borrow_expression => |value| try self.recordExpression(value.operand),
            .unary => |value| try self.recordExpression(value.operand),
            .binary => |value| {
                try self.recordExpression(value.left);
                try self.recordExpression(value.right);
            },
            .conversion => |value| try self.recordExpression(value.operand),
            .protocol_conversion => |value| try self.recordExpression(value.operand),
        }
    }

    fn addUniqueGlobalFallbacks(self: *Builder) !void {
        for (self.source_contents, 0..) |source, file| {
            var lexer = Lexer.Lexer.initFile(source, file);
            while (true) {
                const token = lexer.next() catch break;
                if (token.tag == .end) break;
                if (token.tag != .identifier or self.hasOccurrence(token.position)) continue;
                var local_alias: ?usize = null;
                var local_alias_ambiguous = false;
                for (self.symbols.items) |symbol| {
                    if ((symbol.kind != .alias and symbol.kind != .module) or symbol.definition.file != file or
                        !std.mem.eql(u8, sourceSpelling(symbol.name), token.lexeme))
                    {
                        continue;
                    }
                    if (local_alias != null and local_alias.? != symbol.id) {
                        local_alias_ambiguous = true;
                        break;
                    }
                    local_alias = symbol.id;
                }
                if (!local_alias_ambiguous) if (local_alias) |id| {
                    try self.addOccurrence(id, token.position, false);
                    continue;
                };
                var match: ?usize = null;
                var ambiguous = false;
                for (self.symbols.items) |symbol| {
                    if (!globalKind(symbol.kind) or !std.mem.eql(u8, sourceSpelling(symbol.name), token.lexeme)) continue;
                    if ((symbol.kind == .alias or symbol.kind == .module) and symbol.definition.file != file) continue;
                    if ((symbol.kind == .alias or symbol.kind == .module) and tokenPrecededByDot(source, token.position)) continue;
                    if (match != null and match.? != symbol.id) {
                        ambiguous = true;
                        break;
                    }
                    match = symbol.id;
                }
                if (!ambiguous) if (match) |id| try self.addOccurrence(id, token.position, false);
            }
        }
    }

    fn hasOccurrence(self: *const Builder, position: Source.Position) bool {
        for (self.occurrences.items) |occurrence| if (occurrence.position.file == position.file and
            occurrence.position.line == position.line and occurrence.position.column == position.column) return true;
        return false;
    }
};

fn trySetDeclarationKind(result: *?Kind, kind: Kind) error{Ambiguous}!void {
    if (result.* != null and result.*.? != kind) return error.Ambiguous;
    result.* = kind;
}

pub fn build(
    allocator: Allocator,
    project: Project.Project,
    files: []const Modules.File,
    source_contents: []const []const u8,
    ast: Ast.Program,
    program: Semantic.Program,
) !Index {
    var builder: Builder = .{
        .allocator = allocator,
        .project = project,
        .files = files,
        .source_contents = source_contents,
    };
    try builder.addProgramDeclarations(ast, program);
    builder.linkRenameGroups(ast, program);
    try builder.recordProgram(program);
    try builder.addUniqueGlobalFallbacks();
    return .{
        .symbols = try builder.symbols.toOwnedSlice(allocator),
        .occurrences = try builder.occurrences.toOwnedSlice(allocator),
    };
}

fn structureIndex(structures: []const Semantic.Structure, generated_name: []const u8) ?usize {
    for (structures, 0..) |structure, index| {
        if (std.mem.eql(u8, structure.generated_name, generated_name)) return index;
    }
    return null;
}

fn astStructureAtPath(structures: []const Ast.Structure, path: []const u8) ?*const Ast.Structure {
    const separator = std.mem.indexOfScalar(u8, path, '.');
    const name = if (separator) |index| path[0..index] else path;
    for (structures) |*structure| {
        if (!std.mem.eql(u8, structure.name, name)) continue;
        if (separator) |index| return astStructureAtPath(structure.structures, path[index + 1 ..]);
        return structure;
    }
    return null;
}

fn memberKey(allocator: Allocator, owner: []const u8, generated_name: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}#{s}", .{ owner, generated_name });
}

fn expressionStructureName(expression: *const Semantic.Expression) ?[]const u8 {
    const value = if (expression.type == .reference) expression.type.reference.target.* else expression.type;
    return if (value == .structure) value.structure.generated_name else null;
}

fn globalKind(kind: Kind) bool {
    return switch (kind) {
        .module, .alias, .type, .enumeration, .variant, .protocol, .requirement, .field, .constructor, .function, .method => true,
        else => false,
    };
}

fn tokenPrecededByDot(source: []const u8, position: Source.Position) bool {
    var offset = byteOffset(source, position) orelse return false;
    while (offset > 0 and std.ascii.isWhitespace(source[offset - 1])) offset -= 1;
    return offset > 0 and source[offset - 1] == '.';
}

fn byteOffset(source: []const u8, position: Source.Position) ?usize {
    var offset: usize = 0;
    var line: usize = 1;
    while (line < position.line) : (line += 1) {
        const newline = std.mem.indexOfScalarPos(u8, source, offset, '\n') orelse return null;
        offset = newline + 1;
    }
    const result = offset + position.column -| 1;
    return if (result <= source.len) result else null;
}

fn sourceSpelling(name: []const u8) []const u8 {
    const generic = std.mem.indexOfScalar(u8, name, '<') orelse name.len;
    const prefix = name[0..generic];
    const separator = std.mem.lastIndexOfScalar(u8, prefix, '.') orelse return prefix;
    return prefix[separator + 1 ..];
}

fn useDetail(allocator: Allocator, use_value: Ast.Use, name: []const u8) ![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    if (use_value.is_public) try output.appendSlice(allocator, "public ");
    try output.appendSlice(allocator, "use ");
    switch (use_value.target) {
        .declaration => |target| try output.appendSlice(allocator, target),
        .type => |target| try appendAstType(allocator, &output, target),
    }
    if (use_value.alias != null) {
        try output.appendSlice(allocator, " as ");
        try output.appendSlice(allocator, name);
    }
    return output.toOwnedSlice(allocator);
}

fn appendAstType(allocator: Allocator, output: *std.ArrayList(u8), value: Ast.TypeName) !void {
    switch (value) {
        .void => try output.appendSlice(allocator, "void"),
        .int => try output.appendSlice(allocator, "int"),
        .int8 => try output.appendSlice(allocator, "int8"),
        .int16 => try output.appendSlice(allocator, "int16"),
        .int32 => try output.appendSlice(allocator, "int32"),
        .int64 => try output.appendSlice(allocator, "int64"),
        .uint => try output.appendSlice(allocator, "uint"),
        .uint8 => try output.appendSlice(allocator, "uint8"),
        .uint16 => try output.appendSlice(allocator, "uint16"),
        .uint32 => try output.appendSlice(allocator, "uint32"),
        .uint64 => try output.appendSlice(allocator, "uint64"),
        .float => try output.appendSlice(allocator, "float"),
        .float32 => try output.appendSlice(allocator, "float32"),
        .float64 => try output.appendSlice(allocator, "float64"),
        .bool => try output.appendSlice(allocator, "bool"),
        .str => try output.appendSlice(allocator, "str"),
        .structure => |name| try output.appendSlice(allocator, sourceSpelling(name)),
        .type_parameter => |name| try output.appendSlice(allocator, name),
        .generic_structure => |generic| {
            try output.appendSlice(allocator, sourceSpelling(generic.name));
            try output.append(allocator, '<');
            for (generic.arguments, 0..) |argument, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try appendAstType(allocator, output, argument);
            }
            try output.append(allocator, '>');
        },
        .list => |element| {
            try appendAstType(allocator, output, element.*);
            try output.appendSlice(allocator, "[]");
        },
        .fixed_array => |array| {
            try appendAstType(allocator, output, array.element.*);
            try output.appendSlice(allocator, "[");
            try output.appendSlice(allocator, array.length);
            try output.append(allocator, ']');
        },
        .view => |element| {
            try appendAstType(allocator, output, element.*);
            try output.appendSlice(allocator, "[..]");
        },
        .reference => |reference| {
            try output.append(allocator, if (reference.mutable) '&' else '@');
            try appendAstType(allocator, output, reference.target.*);
        },
        .function => |function| {
            if (function.deferred) try output.appendSlice(allocator, "deferred ");
            if (function.isolated) try output.appendSlice(allocator, "isolated ");
            try output.appendSlice(allocator, "func(");
            for (function.parameters, 0..) |parameter, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                if (function.parameter_modes[index] == .borrow) try output.append(allocator, '@');
                if (function.parameter_modes[index] == .mutable_reference) try output.append(allocator, '&');
                try appendAstType(allocator, output, parameter);
            }
            try output.append(allocator, ')');
            if (function.return_type) |result| {
                try output.append(allocator, ':');
                try appendAstType(allocator, output, result.*);
            }
        },
        .optional => |wrapped| {
            try appendAstType(allocator, output, wrapped.*);
            try output.append(allocator, '?');
        },
    }
}

fn appendReturnType(allocator: Allocator, output: *std.ArrayList(u8), value: Ast.ReturnType) !void {
    if (value == .void) return;
    try output.append(allocator, ':');
    const name: Ast.TypeName = switch (value) {
        .void => unreachable,
        .int => .int,
        .int8 => .int8,
        .int16 => .int16,
        .int32 => .int32,
        .int64 => .int64,
        .uint => .uint,
        .uint8 => .uint8,
        .uint16 => .uint16,
        .uint32 => .uint32,
        .uint64 => .uint64,
        .float => .float,
        .float32 => .float32,
        .float64 => .float64,
        .bool => .bool,
        .str => .str,
        .structure => |name| .{ .structure = name },
        .generic_structure => |generic| .{ .generic_structure = generic },
        .type_parameter => |name| .{ .type_parameter = name },
        .list => |value_ptr| .{ .list = value_ptr },
        .fixed_array => |array| .{ .fixed_array = array },
        .view => |value_ptr| .{ .view = value_ptr },
        .reference => |reference| .{ .reference = reference },
        .function => |function| .{ .function = function },
        .optional => |value_ptr| .{ .optional = value_ptr },
    };
    try appendAstType(allocator, output, name);
}

pub fn functionDetail(allocator: Allocator, function: Ast.Function) ![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    try output.appendSlice(allocator, declarationVisibilityPrefix(function.is_public, function.is_internal));
    if (function.is_native) try output.appendSlice(allocator, "native ");
    if (function.is_static) try output.appendSlice(allocator, "static ");
    if (function.is_override) try output.appendSlice(allocator, "override ");
    try output.appendSlice(allocator, "func ");
    try output.appendSlice(allocator, sourceSpelling(function.name));
    if (function.type_parameters.len != 0) {
        try output.append(allocator, '<');
        for (function.type_parameters, 0..) |parameter, index| {
            if (index != 0) try output.appendSlice(allocator, ", ");
            try output.appendSlice(allocator, parameter.name);
        }
        try output.append(allocator, '>');
    }
    try output.append(allocator, '(');
    for (function.parameters, 0..) |parameter, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        if (parameter.mode == .borrow) try output.append(allocator, '@');
        if (parameter.mode == .mutable_reference) try output.append(allocator, '&');
        try output.appendSlice(allocator, parameter.name);
        try output.append(allocator, ':');
        try appendAstType(allocator, &output, parameter.type);
        if (parameter.default_value) |default_value| {
            try output.appendSlice(allocator, " = ");
            try appendAstDefaultExpression(allocator, &output, default_value);
        }
    }
    try output.append(allocator, ')');
    try appendReturnType(allocator, &output, function.return_type);
    return output.toOwnedSlice(allocator);
}

fn structureHeader(allocator: Allocator, value: Ast.Structure) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}{s}{s} {s}", .{
        declarationVisibilityPrefix(value.is_public, value.is_internal),
        if (value.is_static_class) "static " else "",
        if (value.is_class) "class" else "struct",
        sourceSpelling(value.name),
    });
}

fn typeHeader(allocator: Allocator, value: Ast.Enum) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}enum {s}", .{ declarationVisibilityPrefix(value.is_public, value.is_internal), sourceSpelling(value.name) });
}

fn declarationVisibilityPrefix(is_public: bool, is_internal: bool) []const u8 {
    return if (is_public) "public " else if (is_internal) "internal " else "";
}

fn variantDetail(allocator: Allocator, owner: Ast.Enum, variant: Ast.EnumVariant) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}.{s}", .{ sourceSpelling(owner.name), variant.name });
}

fn fieldDetail(allocator: Allocator, ast: Ast.StructureField, semantic_type: Semantic.Type) ![]const u8 {
    return bindingDetail(allocator, ast.name, semantic_type, ast.mutability);
}

fn constructorDetail(allocator: Allocator, owner: []const u8, ast: Ast.Constructor, semantic: Semantic.Constructor) ![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    try output.appendSlice(allocator, "init ");
    try output.appendSlice(allocator, owner);
    try output.append(allocator, '(');
    for (semantic.parameters, 0..) |parameter, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, parameter.source_name);
        try output.append(allocator, ':');
        try appendSemanticType(allocator, &output, parameter.type);
        if (ast.parameters[index].default_value) |default_value| {
            try output.appendSlice(allocator, " = ");
            try appendAstDefaultExpression(allocator, &output, default_value);
        }
    }
    try output.append(allocator, ')');
    return output.toOwnedSlice(allocator);
}

fn appendAstDefaultExpression(allocator: Allocator, output: *std.ArrayList(u8), expression: *const Ast.Expression) !void {
    switch (expression.value) {
        .integer => |value| try output.appendSlice(allocator, value),
        .floating => |value| try output.appendSlice(allocator, value),
        .boolean => |value| try output.appendSlice(allocator, if (value) "true" else "false"),
        .null => try output.appendSlice(allocator, "null"),
        .string => |value| {
            try output.append(allocator, '"');
            try output.appendSlice(allocator, value);
            try output.append(allocator, '"');
        },
        .identifier => |name| try output.appendSlice(allocator, sourceSpelling(name)),
        .self => try output.appendSlice(allocator, "self"),
        .static_field_access => |access| {
            try appendAstType(allocator, output, access.owner);
            try output.append(allocator, '.');
            try output.appendSlice(allocator, sourceSpelling(access.name));
        },
        .member_access => |access| {
            try appendAstDefaultExpression(allocator, output, access.object);
            try output.append(allocator, '.');
            try output.appendSlice(allocator, sourceSpelling(access.name));
        },
        else => try output.appendSlice(allocator, "..."),
    }
}

fn bindingDetail(allocator: Allocator, name: []const u8, semantic_type: Semantic.Type, mutability: ?Ast.Mutability) ![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    if (mutability) |value| try output.appendSlice(allocator, if (value == .mutable) "var " else "let ");
    try output.appendSlice(allocator, name);
    try output.append(allocator, ':');
    try appendSemanticType(allocator, &output, semantic_type);
    return output.toOwnedSlice(allocator);
}

fn appendSemanticType(allocator: Allocator, output: *std.ArrayList(u8), value: Semantic.Type) !void {
    switch (value) {
        .void => try output.appendSlice(allocator, "void"),
        .int => try output.appendSlice(allocator, "int"),
        .int8 => try output.appendSlice(allocator, "int8"),
        .int16 => try output.appendSlice(allocator, "int16"),
        .int32 => try output.appendSlice(allocator, "int32"),
        .uint8 => try output.appendSlice(allocator, "uint8"),
        .uint16 => try output.appendSlice(allocator, "uint16"),
        .uint32 => try output.appendSlice(allocator, "uint32"),
        .uint64 => try output.appendSlice(allocator, "uint64"),
        .float => try output.appendSlice(allocator, "float"),
        .float64 => try output.appendSlice(allocator, "float64"),
        .bool => try output.appendSlice(allocator, "bool"),
        .str => try output.appendSlice(allocator, "str"),
        .structure => |structure| try output.appendSlice(allocator, sourceSpelling(structure.source_name)),
        .protocol => |protocol| try output.appendSlice(allocator, sourceSpelling(protocol.source_name)),
        .enumeration => |enumeration| try output.appendSlice(allocator, sourceSpelling(enumeration.source_name)),
        .list => |element| {
            try appendSemanticType(allocator, output, element.*);
            try output.appendSlice(allocator, "[]");
        },
        .fixed_array => |array| {
            try appendSemanticType(allocator, output, array.element.*);
            try output.print(allocator, "[{d}]", .{array.length});
        },
        .view => |element| {
            try appendSemanticType(allocator, output, element.*);
            try output.appendSlice(allocator, "[..]");
        },
        .reference => |reference| {
            try output.append(allocator, if (reference.mutable) '&' else '@');
            try appendSemanticType(allocator, output, reference.target.*);
        },
        .function => |function| {
            if (function.deferred) try output.appendSlice(allocator, "deferred ");
            if (function.isolated) try output.appendSlice(allocator, "isolated ");
            try output.appendSlice(allocator, "func(");
            for (function.parameters, 0..) |parameter, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try appendSemanticType(allocator, output, parameter);
            }
            try output.append(allocator, ')');
            if (function.return_type.* != .void) {
                try output.append(allocator, ':');
                try appendSemanticType(allocator, output, function.return_type.*);
            }
        },
        .optional => |wrapped| {
            try appendSemanticType(allocator, output, wrapped.*);
            try output.append(allocator, '?');
        },
        .null => try output.appendSlice(allocator, "null"),
    }
}
