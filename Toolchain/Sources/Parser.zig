const std = @import("std");
const Ast = @import("Ast.zig");
const LexerModule = @import("Lexer.zig");
const Source = @import("Source.zig");
const Strings = @import("Strings.zig");
const Matches = @import("Parser/Matches.zig");
const EnumParser = @import("Parser/Enums.zig");
const Generics = @import("Parser/Generics.zig");
const Uses = @import("Parser/Uses.zig");
const Collections = @import("Parser/Collections.zig");
const Iterations = @import("Parser/Iterations.zig");
const TypeSyntax = @import("Parser/TypeSyntax.zig");
const Nominals = @import("Parser/Nominals.zig");
const Protocols = @import("Parser/Protocols.zig");
const Extensions = @import("Parser/Extensions.zig");
const Interop = @import("Parser/Interop.zig");
const TestBlocks = @import("Parser/TestBlocks.zig");
const ControlFlow = @import("Parser/ControlFlow.zig");
const Cascades = @import("Parser/Cascades.zig");
const Tuples = @import("Parser/Tuples.zig");

const Allocator = std.mem.Allocator;
const Token = LexerModule.Token;
const TokenTag = LexerModule.TokenTag;
const ParseError = Source.Error || Allocator.Error;
pub const Parser = struct {
    allocator: Allocator,
    lexer: LexerModule.Lexer,
    current: Token = undefined,
    previous: Token = undefined,
    started: bool = false,
    diagnostic: ?Source.Diagnostic = null,
    type_names: std.ArrayList([]const u8) = .empty,
    test_only_type_names: std.ArrayList(bool) = .empty,
    generic_types: std.ArrayList(Ast.GenericType) = .empty,
    function_types: std.ArrayList(Ast.FunctionType) = .empty,
    collection_structures: std.ArrayList(Ast.Structure) = .empty,
    nested_structures: std.ArrayList(Ast.Structure) = .empty,
    anonymous_functions: std.ArrayList(Ast.Function) = .empty,
    test_local_functions: std.ArrayList(TestLocalFunction) = .empty,
    test_prefix: ?[]const u8 = null,
    tuple_literal_count: usize = 0,
    type_parameters: []const Ast.TypeParameter = &.{},
    nominal_prefix: ?[]const u8 = null,
    match_depth: usize = 0,
    pub const TestLocalFunction = struct {
        source: []const u8,
        generated: []const u8,
        position: Source.Position,
    };

    pub fn init(allocator: Allocator, source: []const u8) Parser {
        return .{ .allocator = allocator, .lexer = .init(source) };
    }

    pub fn initFile(allocator: Allocator, source: []const u8, file: usize) Parser {
        return .{ .allocator = allocator, .lexer = .initFile(source, file) };
    }

    pub fn parse(self: *Parser) ParseError!Ast.Program {
        try self.advance();
        var uses: std.ArrayList(Ast.Use) = .empty;
        var structures: std.ArrayList(Ast.Structure) = .empty;
        var enums: std.ArrayList(Ast.Enum) = .empty;
        var functions: std.ArrayList(Ast.Function) = .empty;
        var external_functions: std.ArrayList(Ast.ExternalFunction) = .empty;
        var extensions: std.ArrayList(Ast.Extension) = .empty;
        while (self.current.tag != .end) {
            switch (self.current.tag) {
                .keyword_use => try uses.append(self.allocator, try Uses.parse(self, false)),
                .keyword_struct => try structures.append(self.allocator, try Nominals.parse(self, false, false, false, false)),
                .keyword_class => try structures.append(self.allocator, try Nominals.parse(self, false, false, false, true)),
                .keyword_static => try structures.append(self.allocator, try Nominals.parseStaticClass(self, false, false, false)),
                .keyword_protocol => try structures.append(self.allocator, try Protocols.parse(self, false, false, false)),
                .keyword_enum => try enums.append(self.allocator, try EnumParser.parse(self, false, false, false)),
                .keyword_func => try functions.append(self.allocator, try self.parseFunction(false, false, false)),
                .identifier => if (std.mem.eql(u8, self.current.lexeme, "test"))
                    try functions.appendSlice(self.allocator, try TestBlocks.parse(self))
                else
                    return self.fail("expected use, enum, struct, class, protocol, function, or test declaration"),
                .keyword_let => try external_functions.append(self.allocator, try Interop.parseFunction(self)),
                .keyword_extend => try extensions.append(self.allocator, try Extensions.parse(self)),
                .keyword_public => {
                    try self.advance();
                    switch (self.current.tag) {
                        .keyword_use => try uses.append(self.allocator, try Uses.parse(self, true)),
                        .keyword_struct => try structures.append(self.allocator, try Nominals.parse(self, true, false, false, false)),
                        .keyword_class => try structures.append(self.allocator, try Nominals.parse(self, true, false, false, true)),
                        .keyword_static => try structures.append(self.allocator, try Nominals.parseStaticClass(self, true, false, false)),
                        .keyword_enum => try enums.append(self.allocator, try EnumParser.parse(self, true, false, false)),
                        .keyword_protocol => try structures.append(self.allocator, try Protocols.parse(self, true, false, false)),
                        .keyword_func => try functions.append(self.allocator, try self.parseFunction(true, false, false)),
                        else => return self.fail("expected use, enum, struct, class, protocol, or function declaration after 'public'"),
                    }
                },
                .keyword_internal, .keyword_local => {
                    const is_internal = self.current.tag == .keyword_internal;
                    const is_local = self.current.tag == .keyword_local;
                    try self.advance();
                    switch (self.current.tag) {
                        .keyword_struct => try structures.append(self.allocator, try Nominals.parse(self, false, is_internal, is_local, false)),
                        .keyword_class => try structures.append(self.allocator, try Nominals.parse(self, false, is_internal, is_local, true)),
                        .keyword_static => try structures.append(self.allocator, try Nominals.parseStaticClass(self, false, is_internal, is_local)),
                        .keyword_enum => try enums.append(self.allocator, try EnumParser.parse(self, false, is_internal, is_local)),
                        .keyword_protocol => try structures.append(self.allocator, try Protocols.parse(self, false, is_internal, is_local)),
                        .keyword_func => try functions.append(self.allocator, try self.parseFunction(false, is_internal, is_local)),
                        else => return self.fail(if (is_internal)
                            "expected enum, struct, class, protocol, or function declaration after 'internal'"
                        else
                            "expected enum, struct, class, protocol, or function declaration after 'local'"),
                    }
                },
                else => return self.fail("expected use, enum, struct, class, protocol, function, or test declaration"),
            }
        }
        try structures.appendSlice(self.allocator, self.nested_structures.items);
        try structures.appendSlice(self.allocator, self.collection_structures.items);
        try functions.appendSlice(self.allocator, self.anonymous_functions.items);
        if (external_functions.items.len != 0) {
            var has_c = false;
            var has_boundary = false;
            var has_macos = false;
            var has_linux = false;
            var has_windows = false;
            for (uses.items) |use| {
                has_c = has_c or std.mem.eql(u8, use.path, "Interop.C");
                has_boundary = has_boundary or std.mem.eql(u8, use.path, "Interop.Boundary");
                has_macos = has_macos or std.mem.eql(u8, use.path, "Interop.MacOS");
                has_linux = has_linux or std.mem.eql(u8, use.path, "Interop.Linux");
                has_windows = has_windows or std.mem.eql(u8, use.path, "Interop.Windows");
            }
            if (!has_c) return self.failAt(external_functions.items[0].position, "C.function requires 'use Interop.C'");
            for (external_functions.items) |external| {
                if (std.mem.startsWith(u8, external.library, "Boundary.") and !has_boundary) {
                    return self.failAt(external.position, "Boundary library requires 'use Interop.Boundary'");
                }
                if (std.mem.startsWith(u8, external.library, "MacOS.") and !has_macos) {
                    return self.failAt(external.position, "MacOS library requires 'use Interop.MacOS'");
                }
                if (std.mem.startsWith(u8, external.library, "Linux.") and !has_linux) {
                    return self.failAt(external.position, "Linux library requires 'use Interop.Linux'");
                }
                if (std.mem.startsWith(u8, external.library, "Windows.") and !has_windows) {
                    return self.failAt(external.position, "Windows library requires 'use Interop.Windows'");
                }
            }
        }
        var structure_index: usize = 1;
        while (structure_index < structures.items.len) : (structure_index += 1) {
            var insertion = structure_index;
            while (insertion != 0 and self.typeOrder(structures.items[insertion].name) < self.typeOrder(structures.items[insertion - 1].name)) {
                std.mem.swap(Ast.Structure, &structures.items[insertion], &structures.items[insertion - 1]);
                insertion -= 1;
            }
        }
        for (functions.items) |function| _ = try self.internFunctionType(function);
        return .{
            .uses = try uses.toOwnedSlice(self.allocator),
            .type_names = try self.type_names.toOwnedSlice(self.allocator),
            .test_only_type_names = try self.test_only_type_names.toOwnedSlice(self.allocator),
            .generic_types = try self.generic_types.toOwnedSlice(self.allocator),
            .function_types = try self.function_types.toOwnedSlice(self.allocator),
            .structures = try structures.toOwnedSlice(self.allocator),
            .enums = try enums.toOwnedSlice(self.allocator),
            .extensions = try extensions.toOwnedSlice(self.allocator),
            .external_functions = try external_functions.toOwnedSlice(self.allocator),
            .functions = try functions.toOwnedSlice(self.allocator),
        };
    }

    fn internFunctionType(self: *Parser, function: Ast.Function) ParseError!Ast.Type {
        const parameters = try self.allocator.alloc(Ast.FunctionType.ParameterType, function.parameters.len);
        for (function.parameters, 0..) |parameter, index| parameters[index] = .{ .type = parameter.type, .mode = parameter.mode };
        const candidate: Ast.FunctionType = .{
            .parameters = parameters,
            .return_type = function.return_type,
            .return_mode = function.return_mode,
        };
        for (self.function_types.items, 0..) |existing, index| {
            if (sameFunctionType(existing, candidate)) return .function(index);
        }
        const index = self.function_types.items.len;
        try self.function_types.append(self.allocator, candidate);
        return .function(index);
    }

    fn sameFunctionType(left: Ast.FunctionType, right: Ast.FunctionType) bool {
        if (left.return_type != right.return_type or left.return_mode != right.return_mode or left.parameters.len != right.parameters.len) return false;
        for (left.parameters, right.parameters) |left_parameter, right_parameter| {
            if (left_parameter.type != right_parameter.type or left_parameter.mode != right_parameter.mode) return false;
        }
        return true;
    }

    pub fn parseFunction(self: *Parser, is_public: bool, is_internal: bool, is_local: bool) ParseError!Ast.Function {
        const position = self.current.position;
        try self.expect(.keyword_func, "expected 'func'");
        if (self.current.tag != .identifier and self.current.tag != .keyword_copy) return self.fail("expected function name");
        const source_name = self.current.lexeme;
        const name = self.testLocalFunctionName(source_name) orelse source_name;
        const name_position = self.current.position;
        if (std.mem.eql(u8, source_name, "Result")) return self.failAt(name_position, "'Result' is a reserved intrinsic type name");
        if (std.mem.eql(u8, source_name, "map_error")) return self.failAt(name_position, "'map_error' is a reserved intrinsic function name");
        try self.advance();
        const type_parameters = try Generics.parseTypeParameters(self);
        const enclosing_type_parameters = self.type_parameters;
        if (type_parameters.len != 0 and enclosing_type_parameters.len != 0) {
            return self.failAt(name_position, "generic methods in generic structures are not supported");
        }
        self.type_parameters = if (type_parameters.len == 0) enclosing_type_parameters else type_parameters;
        defer self.type_parameters = enclosing_type_parameters;
        try self.expect(.left_parenthesis, "expected '(' after function name");

        var parameters: std.ArrayList(Ast.Parameter) = .empty;
        var has_default = false;
        if (self.current.tag != .right_parenthesis) {
            while (true) {
                const parameter = try self.parseParameter();
                if (has_default and parameter.default == null) {
                    return self.failAt(parameter.position, "a required parameter cannot follow a parameter with a default value");
                }
                has_default = has_default or parameter.default != null;
                try parameters.append(self.allocator, parameter);
                if (self.current.tag != .comma) break;
                try self.advance();
                if (self.current.tag == .right_parenthesis) break;
            }
        }
        try self.expect(.right_parenthesis, "expected ')' after parameters");

        var return_mode: Ast.Parameter.Mode = .value;
        var return_provenance: ?[]const u8 = null;
        if (self.current.tag == .at or self.current.tag == .amp) {
            return_mode = if (self.current.tag == .at) .read else .mutable;
            try self.advance();
            if (self.current.tag == .identifier or self.current.tag == .keyword_self) {
                var lexer = self.lexer;
                const next = try lexer.next();
                if (next.tag == .colon) {
                    return_provenance = self.current.lexeme;
                    try self.advance();
                    try self.expect(.colon, "expected ':' after borrowed return provenance");
                }
            }
        }
        const return_type: Ast.Type = if (self.current.tag == .left_brace) .void else try self.parseType();
        if (return_mode != .value and return_type == .void) return self.failAt(name_position, "a borrowed return cannot be 'void'");
        if (return_mode != .value and return_provenance == null) {
            var compatible: ?[]const u8 = null;
            var count: usize = 0;
            for (parameters.items) |parameter| {
                const accepts = if (return_mode == .read) parameter.mode != .value else parameter.mode == .mutable;
                if (!accepts) continue;
                compatible = parameter.name;
                count += 1;
            }
            if (count == 1) return_provenance = compatible;
        }
        return .{
            .is_test = self.test_prefix != null,
            .test_owner = self.test_prefix,
            .test_source_name = if (self.test_prefix != null) source_name else null,
            .is_public = is_public,
            .is_internal = is_internal,
            .is_local = is_local,
            .position = position,
            .name_position = name_position,
            .name = name,
            .type_parameters = type_parameters,
            .parameters = try parameters.toOwnedSlice(self.allocator),
            .return_type = return_type,
            .return_mode = return_mode,
            .return_provenance = return_provenance,
            .statements = try self.parseBlock(),
        };
    }

    fn parseAnonymousFunction(self: *Parser) ParseError!*Ast.Expression {
        const position = self.current.position;
        try self.expect(.keyword_func, "expected 'func'");
        try self.expect(.left_parenthesis, "expected '(' after 'func'");

        var parameters: std.ArrayList(Ast.Parameter) = .empty;
        if (self.current.tag != .right_parenthesis) {
            while (true) {
                const parameter = try self.parseParameter();
                if (parameter.default != null) {
                    return self.failAt(parameter.position, "anonymous function parameters cannot have default values");
                }
                try parameters.append(self.allocator, parameter);
                if (self.current.tag != .comma) break;
                try self.advance();
                if (self.current.tag == .right_parenthesis) break;
            }
        }
        try self.expect(.right_parenthesis, "expected ')' after anonymous function parameters");

        const return_type: Ast.Type = if (self.current.tag == .left_brace) .void else try self.parseType();
        const name = try std.fmt.allocPrint(self.allocator, "__silex_anonymous_{d}", .{position.offset});
        try self.anonymous_functions.append(self.allocator, .{
            .is_anonymous = true,
            .is_test = self.test_prefix != null,
            .test_owner = self.test_prefix,
            .is_local = true,
            .position = position,
            .name_position = position,
            .name = name,
            .parameters = try parameters.toOwnedSlice(self.allocator),
            .return_type = return_type,
            .statements = try self.parseBlock(),
        });
        return self.newExpression(.{
            .position = position,
            .value = .{ .identifier = name },
        });
    }

    pub fn parseParameter(self: *Parser) ParseError!Ast.Parameter {
        return TypeSyntax.parseParameter(self);
    }

    pub fn parseType(self: *Parser) ParseError!Ast.Type {
        return TypeSyntax.parseType(self);
    }

    pub fn internTypeName(self: *Parser, name: []const u8) Allocator.Error!Ast.Type {
        for (self.type_names.items, 0..) |existing, index| {
            if (!std.mem.eql(u8, existing, name)) continue;
            if (self.test_prefix == null) self.test_only_type_names.items[index] = false;
            return .structure(index);
        }
        const index = self.type_names.items.len;
        try self.type_names.append(self.allocator, name);
        try self.test_only_type_names.append(self.allocator, self.test_prefix != null);
        return .structure(index);
    }

    pub fn resolveTypeName(self: *Parser, name: []const u8) Allocator.Error![]const u8 {
        if (std.mem.indexOfScalar(u8, name, '.') != null) return name;
        var prefix = self.nominal_prefix;
        while (prefix) |candidate_prefix| {
            const candidate = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ candidate_prefix, name });
            for (self.type_names.items) |known| if (std.mem.eql(u8, known, candidate)) return candidate;
            prefix = if (std.mem.lastIndexOfScalar(u8, candidate_prefix, '.')) |dot| candidate_prefix[0..dot] else null;
        }
        if (self.nominal_prefix) |candidate_prefix| {
            const leaf = if (std.mem.lastIndexOfScalar(u8, candidate_prefix, '.')) |dot| candidate_prefix[dot + 1 ..] else candidate_prefix;
            if (std.mem.eql(u8, leaf, name)) return candidate_prefix;
        }
        return name;
    }

    fn typeOrder(self: *Parser, name: []const u8) usize {
        for (self.type_names.items, 0..) |candidate, index| if (std.mem.eql(u8, candidate, name)) return index;
        return std.math.maxInt(usize);
    }

    pub fn internGenericType(self: *Parser, position: Source.Position, base: Ast.Type, arguments: []const Ast.Type) Allocator.Error!Ast.Type {
        return Collections.internGenericType(self, position, base, arguments);
    }

    pub fn parseBlock(self: *Parser) ParseError![]const Ast.Statement {
        try self.expect(.left_brace, "expected '{' before function body");
        var statements: std.ArrayList(Ast.Statement) = .empty;
        while (self.current.tag != .right_brace and self.current.tag != .end) {
            try statements.append(self.allocator, try self.parseStatement());
        }
        try self.expect(.right_brace, "expected '}' after function body");
        return statements.toOwnedSlice(self.allocator);
    }

    pub fn parseStatement(self: *Parser) ParseError!Ast.Statement {
        return switch (self.current.tag) {
            .keyword_let => self.parseVariableDeclaration(false),
            .keyword_var => self.parseVariableDeclaration(true),
            .keyword_return => self.parseReturn(),
            .keyword_print => self.parsePrint(),
            .keyword_assert => self.parseAssert(),
            .keyword_panic => self.parseEffectStatement(.panic),
            .keyword_if => ControlFlow.parseIf(self),
            .keyword_while => ControlFlow.parseWhile(self),
            .keyword_for => Iterations.parseFor(self),
            .keyword_mutex => ControlFlow.parseMutex(self),
            .keyword_break => ControlFlow.parseLoopControl(self, false),
            .keyword_continue => ControlFlow.parseLoopControl(self, true),
            .keyword_match => self.parseMatchStatement(),
            .keyword_try => self.parseMatchStatement(),
            .identifier, .keyword_self, .keyword_super => self.parseIdentifierStatement(),
            else => self.fail("expected statement"),
        };
    }

    fn parseMatchStatement(self: *Parser) ParseError!Ast.Statement {
        const expression = try self.parseExpression(false);
        try self.expectStatementTerminator();
        return .{ .expression_statement = expression };
    }

    fn parsePrint(self: *Parser) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        try self.expect(.left_parenthesis, "expected '(' after 'print'");
        if (self.current.tag == .right_parenthesis) return self.fail("print expects at least one value");
        var values: std.ArrayList(*Ast.Expression) = .empty;
        while (true) {
            try values.append(self.allocator, try self.parseExpression(true));
            if (self.current.tag != .comma) break;
            try self.advance();
            if (self.current.tag == .right_parenthesis) return self.fail("expected value after ','");
        }
        try self.expect(.right_parenthesis, "expected ')' after print values");
        try self.expectStatementTerminator();
        return .{ .print_statement = .{ .position = position, .values = try values.toOwnedSlice(self.allocator) } };
    }

    fn parseEffectStatement(self: *Parser, effect: enum { panic }) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        try self.expect(.left_parenthesis, "expected '(' after effect name");
        const value = try self.parseExpression(true);
        try self.expect(.right_parenthesis, "expected ')' after effect value");
        try self.expectStatementTerminator();
        return switch (effect) {
            .panic => .{ .panic_statement = .{ .position = position, .value = value } },
        };
    }

    fn parseAssert(self: *Parser) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        try self.expect(.left_parenthesis, "expected '(' after 'assert'");
        const condition = try self.parseExpression(true);
        const message = if (self.current.tag == .comma) message: {
            try self.advance();
            break :message try self.parseExpression(true);
        } else try self.newExpression(.{
            .position = position,
            .value = .{ .string = "condition is false" },
        });
        try self.expect(.right_parenthesis, "expected ')' after assert message");
        try self.expectStatementTerminator();
        return .{ .assert_statement = .{ .position = position, .condition = condition, .message = message } };
    }

    fn parseVariableDeclaration(self: *Parser, mutable: bool) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        if (self.current.tag == .left_parenthesis) return Tuples.parseDestructuring(self, position, mutable);
        if (self.current.tag != .identifier) return self.fail("expected variable name");
        const name = self.current.lexeme;
        const name_position = self.current.position;
        if (std.mem.eql(u8, name, "map_error")) return self.failAt(name_position, "'map_error' is a reserved intrinsic function name");
        try self.advance();

        var annotation: ?Ast.Type = null;
        var annotation_mode: Ast.Parameter.Mode = .value;
        if (self.current.tag == .colon) {
            try self.advance();
            if (self.current.tag == .at or self.current.tag == .amp) {
                annotation_mode = if (self.current.tag == .at) .read else .mutable;
                try self.advance();
            }
            annotation = try self.parseType();
        }

        var initializer: ?*Ast.Expression = null;
        if (self.current.tag == .equal) {
            try self.advance();
            initializer = try self.parseExpression(false);
        } else if (annotation == null) {
            return self.failAt(name_position, "variable declaration requires a type or initializer");
        }
        try self.expectStatementTerminator();
        return .{ .variable_declaration = .{
            .position = position,
            .name_position = name_position,
            .name = name,
            .mutable = mutable,
            .annotation = annotation,
            .annotation_mode = annotation_mode,
            .initializer = initializer,
        } };
    }

    fn parseReturn(self: *Parser) ParseError!Ast.Statement {
        const position = self.current.position;
        try self.advance();
        var value: ?*Ast.Expression = null;
        if (self.current.tag != .semicolon and self.current.tag != .right_brace and
            self.current.tag != .end and self.current.position.line == position.line)
        {
            value = try self.parseExpression(false);
        }
        try self.expectStatementTerminator();
        return .{ .return_statement = .{ .position = position, .value = value } };
    }

    fn parseIdentifierStatement(self: *Parser) ParseError!Ast.Statement {
        const expression = try self.parseExpression(false);
        const assignment_operator: ?Ast.AssignmentOperator = switch (self.current.tag) {
            .equal => .assign,
            .plus_equal => .add,
            .minus_equal => .subtract,
            .star_equal => .multiply,
            .slash_equal => .divide,
            .plus_plus => .increment,
            .minus_minus => .decrement,
            else => null,
        };
        if (assignment_operator) |operator| {
            const target = try self.assignmentTarget(expression);
            const position = self.current.position;
            try self.advance();
            const value = switch (operator) {
                .increment, .decrement => null,
                else => try self.parseExpression(false),
            };
            try self.expectStatementTerminator();
            return .{ .assignment_statement = .{
                .position = position,
                .target = target,
                .operator = operator,
                .value = value,
            } };
        }
        switch (expression.value) {
            .call, .cascade => {},
            else => return self.failAt(expression.position, "expected assignment or function call"),
        }
        try self.expectStatementTerminator();
        return .{ .expression_statement = expression };
    }

    fn assignmentTarget(self: *Parser, expression: *Ast.Expression) ParseError!Ast.AssignmentTarget {
        var fields: std.ArrayList(Ast.AssignmentTarget.Field) = .empty;
        var indices: std.ArrayList(Ast.AssignmentTarget.Index) = .empty;
        var indexed_fields: []const Ast.AssignmentTarget.Field = &.{};
        var current = expression;
        while (true) switch (current.value) {
            .identifier => |name| {
                std.mem.reverse(Ast.AssignmentTarget.Field, fields.items);
                std.mem.reverse(Ast.AssignmentTarget.Index, indices.items);
                return .{
                    .name_position = current.position,
                    .name = name,
                    .fields = try fields.toOwnedSlice(self.allocator),
                    .indices = try indices.toOwnedSlice(self.allocator),
                    .indexed_fields = indexed_fields,
                };
            },
            .generic_reference => |reference| {
                std.mem.reverse(Ast.AssignmentTarget.Field, fields.items);
                std.mem.reverse(Ast.AssignmentTarget.Index, indices.items);
                return .{
                    .name_position = current.position,
                    .name = reference.name,
                    .type_arguments = reference.type_arguments,
                    .fields = try fields.toOwnedSlice(self.allocator),
                    .indices = try indices.toOwnedSlice(self.allocator),
                    .indexed_fields = indexed_fields,
                };
            },
            .field_access => |access| {
                try fields.append(self.allocator, .{
                    .name_position = access.name_position,
                    .name = access.name,
                });
                current = access.base;
            },
            .index_access => |access| {
                if (fields.items.len != 0) {
                    if (indexed_fields.len != 0) return self.failAt(access.bracket_position, "assignment paths cannot alternate collection and field access more than once");
                    std.mem.reverse(Ast.AssignmentTarget.Field, fields.items);
                    indexed_fields = try fields.toOwnedSlice(self.allocator);
                }
                try indices.append(self.allocator, .{ .position = access.bracket_position, .value = access.index });
                current = access.base;
            },
            else => return self.failAt(expression.position, "assignment target must be a variable or field path"),
        };
    }

    pub fn parseExpression(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        return Cascades.parse(self, try self.parseLogicalOr(allow_line_breaks));
    }

    pub fn parseLogicalOr(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseLogicalAnd(allow_line_breaks);
        while (self.current.tag == .pipe_pipe and self.canContinueExpression(allow_line_breaks)) {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseLogicalAnd(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseLogicalAnd(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseEquality(allow_line_breaks);
        while (self.current.tag == .amp_amp and self.canContinueExpression(allow_line_breaks)) {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseEquality(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseEquality(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseComparison(allow_line_breaks);
        while ((self.current.tag == .equal_equal or self.current.tag == .bang_equal) and
            self.canContinueExpression(allow_line_breaks))
        {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseComparison(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseComparison(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseBitXor(allow_line_breaks);
        while ((self.current.tag == .less or self.current.tag == .less_equal or
            self.current.tag == .greater or self.current.tag == .greater_equal) and
            self.canContinueExpression(allow_line_breaks))
        {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseBitXor(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseBitXor(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseBitAnd(allow_line_breaks);
        while (self.current.tag == .caret and self.canContinueExpression(allow_line_breaks)) {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseBitAnd(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseBitAnd(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseShift(allow_line_breaks);
        while (self.current.tag == .amp and self.canContinueExpression(allow_line_breaks)) {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseShift(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseShift(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseAdditive(allow_line_breaks);
        while ((self.current.tag == .shift_left or self.current.tag == .shift_right) and
            self.canContinueExpression(allow_line_breaks))
        {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseAdditive(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseAdditive(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseMultiplicative(allow_line_breaks);
        while ((self.current.tag == .plus or self.current.tag == .minus) and
            self.canContinueExpression(allow_line_breaks))
        {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseMultiplicative(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseMultiplicative(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        var expression = try self.parseUnary(allow_line_breaks);
        while ((self.current.tag == .star or self.current.tag == .slash or self.current.tag == .percent) and
            self.canContinueExpression(allow_line_breaks))
        {
            const operator = self.current;
            try self.advance();
            expression = try self.newBinary(expression, try self.parseUnary(allow_line_breaks), operator);
        }
        return expression;
    }

    fn parseUnary(self: *Parser, allow_line_breaks: bool) ParseError!*Ast.Expression {
        if (self.current.tag != .minus and self.current.tag != .bang and self.current.tag != .keyword_try and self.current.tag != .keyword_move and self.current.tag != .keyword_copy and self.current.tag != .at and self.current.tag != .amp) return self.parseConversion();
        const operator = self.current;
        try self.advance();
        return self.newExpression(.{
            .position = operator.position,
            .value = .{ .unary = .{
                .operator = switch (operator.tag) {
                    .minus => .negate,
                    .bang => .logical_not,
                    .keyword_try => .propagate,
                    .keyword_move => .move,
                    .keyword_copy => .copy,
                    .at => .borrow_read,
                    .amp => .borrow_mutable,
                    else => unreachable,
                },
                .operator_position = operator.position,
                .operand = try self.parseUnary(allow_line_breaks),
            } },
        });
    }

    fn parseConversion(self: *Parser) ParseError!*Ast.Expression {
        return self.parsePostfix(try self.parsePrimary());
    }

    pub fn parsePostfix(self: *Parser, initial: *Ast.Expression) ParseError!*Ast.Expression {
        var expression = initial;
        while (true) {
            if (self.current.tag == .less and expression.value == .identifier and try Generics.memberFollows(self)) {
                const generic_name = expression.value.identifier;
                const type_arguments = try Generics.parseTypeArguments(self);
                expression.value = .{ .generic_reference = .{
                    .name = generic_name,
                    .type_arguments = type_arguments,
                } };
                continue;
            }
            if (self.current.tag == .less and expression.value == .identifier and try Generics.callArgumentsFollow(self)) {
                const type_arguments = try Generics.parseTypeArguments(self);
                const name = Token{
                    .tag = .identifier,
                    .lexeme = expression.value.identifier,
                    .position = expression.position,
                    .start = 0,
                    .end = 0,
                };
                expression = try self.parseCallAfterName(name, null, false, type_arguments);
                continue;
            }
            if (self.current.tag == .left_parenthesis) {
                const name = switch (expression.value) {
                    .identifier => |value| Token{
                        .tag = .identifier,
                        .lexeme = value,
                        .position = expression.position,
                        .start = 0,
                        .end = 0,
                    },
                    else => return self.fail("only a named declaration can be called directly"),
                };
                expression = try self.parseCallAfterName(name, null, false, &.{});
                continue;
            }
            if (self.current.tag == .left_bracket) {
                const position = self.current.position;
                expression = try Collections.parsePostfix(self, expression, position);
                continue;
            }
            if (self.current.tag == .dot or self.current.tag == .question_dot) {
                const safe = self.current.tag == .question_dot;
                try self.advance();
                if (self.current.tag != .identifier and self.current.tag != .keyword_copy) return self.fail(if (safe)
                    "expected member name after '?.'"
                else
                    "expected member name after '.'");
                const member = self.current;
                try self.advance();
                if (self.current.tag == .less and try Generics.memberFollows(self)) {
                    const prefix = try Generics.qualifiedName(self.allocator, expression) orelse return self.fail("generic type owner must be a qualified name");
                    expression = try self.newExpression(.{
                        .position = expression.position,
                        .value = .{ .generic_reference = .{
                            .name = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ prefix, member.lexeme }),
                            .type_arguments = try Generics.parseTypeArguments(self),
                        } },
                    });
                    continue;
                }
                const type_arguments = if (self.current.tag == .less and try Generics.callArgumentsFollow(self))
                    try Generics.parseTypeArguments(self)
                else
                    &.{};
                if (self.current.tag == .left_parenthesis) {
                    expression = try self.parseCallAfterName(member, expression, safe, type_arguments);
                } else if (type_arguments.len != 0) {
                    return self.fail("expected '(' after method type arguments");
                } else expression = try self.newExpression(.{
                    .position = expression.position,
                    .value = .{ .field_access = .{
                        .base = expression,
                        .name_position = member.position,
                        .name = member.lexeme,
                        .safe = safe,
                    } },
                });
                continue;
            }
            if (self.current.tag != .keyword_as) break;
            const position = self.current.position;
            try self.advance();
            const target = try self.parseType();
            expression = try self.newExpression(.{
                .position = expression.position,
                .value = .{ .conversion = .{
                    .operand = expression,
                    .target = target,
                    .operator_position = position,
                } },
            });
        }
        return expression;
    }

    fn parsePrimary(self: *Parser) ParseError!*Ast.Expression {
        var token = self.current;
        if (token.tag == .identifier) token.lexeme = self.testLocalFunctionName(token.lexeme) orelse token.lexeme;
        switch (token.tag) {
            .integer => {
                try self.advance();
                return self.newExpression(.{ .position = token.position, .value = .{ .integer = token.lexeme } });
            },
            .floating => {
                try self.advance();
                return self.newExpression(.{ .position = token.position, .value = .{ .floating = token.lexeme } });
            },
            .keyword_true, .keyword_false => {
                try self.advance();
                return self.newExpression(.{
                    .position = token.position,
                    .value = .{ .boolean = token.tag == .keyword_true },
                });
            },
            .keyword_null => {
                try self.advance();
                return self.newExpression(.{ .position = token.position, .value = .null_value });
            },
            .string => {
                try self.advance();
                return self.newExpression(.{
                    .position = token.position,
                    .value = .{ .string = try Strings.decode(self.allocator, token.lexeme) },
                });
            },
            .string_start => return self.parseInterpolatedString(token),
            .identifier, .keyword_self, .keyword_super => {
                try self.advance();
                return self.newExpression(.{
                    .position = token.position,
                    .value = .{ .identifier = token.lexeme },
                });
            },
            .left_parenthesis => {
                return Tuples.parseExpression(self);
            },
            .left_bracket => return Collections.parseLiteral(self, token.position),
            .keyword_match => return Matches.parse(self),
            .keyword_func => return self.parseAnonymousFunction(),
            else => return self.fail("expected expression"),
        }
    }

    fn parseInterpolatedString(self: *Parser, token: Token) ParseError!*Ast.Expression {
        try self.advance();
        var parts: std.ArrayList(Ast.Expression.StringPart) = .empty;
        while (self.current.tag != .string_end) {
            switch (self.current.tag) {
                .string_text => {
                    try parts.append(self.allocator, .{ .text = try Strings.decode(self.allocator, self.current.lexeme) });
                    try self.advance();
                },
                .interpolation_start => {
                    try self.advance();
                    if (self.current.tag == .interpolation_end) return self.fail("expected expression inside string interpolation");
                    const expression = try self.parseExpression(true);
                    try self.expect(.interpolation_end, "expected ')' after string interpolation");
                    try parts.append(self.allocator, .{ .expression = expression });
                },
                .end => return self.fail("unterminated string literal"),
                else => return self.fail("expected text or interpolation in string literal"),
            }
        }
        try self.advance();
        return self.newExpression(.{
            .position = token.position,
            .value = .{ .interpolated_string = .{ .parts = try parts.toOwnedSlice(self.allocator) } },
        });
    }

    fn parseCallAfterName(self: *Parser, name: Token, receiver: ?*Ast.Expression, safe: bool, type_arguments: []const Ast.Type) ParseError!*Ast.Expression {
        try self.expect(.left_parenthesis, "expected '(' after function name");
        var arguments: std.ArrayList(*Ast.Expression) = .empty;
        var named_arguments: std.ArrayList(Ast.Expression.NamedArgument) = .empty;
        if (self.current.tag != .right_parenthesis) {
            while (true) {
                if (try self.startsNamedArgument()) {
                    if (arguments.items.len != 0) return self.fail("named fields cannot follow positional arguments");
                    const position = self.current.position;
                    const field_name = self.current.lexeme;
                    try self.advance();
                    try self.expect(.colon, "expected ':' after field name");
                    try named_arguments.append(self.allocator, .{
                        .position = position,
                        .name = field_name,
                        .value = try self.parseExpression(true),
                    });
                } else {
                    if (named_arguments.items.len != 0) return self.fail("positional arguments cannot follow named fields");
                    try arguments.append(self.allocator, try self.parseExpression(true));
                }
                if (self.current.tag == .right_parenthesis) break;
                if (self.current.tag != .comma) return self.fail("expected ',' or ')' after argument");
                try self.advance();
                if (self.current.tag == .right_parenthesis) {
                    if (named_arguments.items.len == 0) return self.fail("expected argument after ','");
                    break;
                }
            }
        }
        try self.expect(.right_parenthesis, "expected ')' after arguments");
        return self.newExpression(.{
            .position = name.position,
            .value = .{ .call = .{
                .name = name.lexeme,
                .name_position = name.position,
                .receiver = receiver,
                .safe = safe,
                .arguments = try arguments.toOwnedSlice(self.allocator),
                .named_arguments = try named_arguments.toOwnedSlice(self.allocator),
                .type_arguments = type_arguments,
            } },
        });
    }

    fn startsNamedArgument(self: *Parser) ParseError!bool {
        if (self.current.tag != .identifier) return false;
        var lexer = self.lexer;
        const next = lexer.next() catch |err| {
            self.diagnostic = lexer.diagnostic;
            return err;
        };
        return next.tag == .colon;
    }

    fn newBinary(self: *Parser, left: *Ast.Expression, right: *Ast.Expression, token: Token) Allocator.Error!*Ast.Expression {
        const operator: Ast.BinaryOperator = switch (token.tag) {
            .plus => .add,
            .minus => .subtract,
            .star => .multiply,
            .slash => .divide,
            .percent => .remainder,
            .less => .less,
            .less_equal => .less_equal,
            .greater => .greater,
            .greater_equal => .greater_equal,
            .equal_equal => .equal,
            .bang_equal => .not_equal,
            .amp_amp => .logical_and,
            .pipe_pipe => .logical_or,
            .amp => .bit_and,
            .caret => .bit_xor,
            .shift_left => .shift_left,
            .shift_right => .shift_right,
            else => unreachable,
        };
        return self.newExpression(.{
            .position = left.position,
            .value = .{ .binary = .{
                .left = left,
                .operator = operator,
                .operator_position = token.position,
                .right = right,
            } },
        });
    }

    pub fn newExpression(self: *Parser, expression: Ast.Expression) Allocator.Error!*Ast.Expression {
        const result = try self.allocator.create(Ast.Expression);
        result.* = expression;
        return result;
    }

    pub fn testLocalFunctionName(self: *const Parser, source: []const u8) ?[]const u8 {
        var index = self.test_local_functions.items.len;
        while (index != 0) {
            index -= 1;
            const candidate = self.test_local_functions.items[index];
            if (std.mem.eql(u8, candidate.source, source)) return candidate.generated;
        }
        return null;
    }

    pub fn expectStatementTerminator(self: *Parser) ParseError!void {
        if (self.current.tag == .semicolon and self.current.position.line == self.previous.position.line) {
            try self.advance();
            return;
        }
        if (self.current.tag == .right_brace or self.current.tag == .end) return;
        if (self.current.position.line > self.previous.position.line) return;
        return self.fail("expected ';' or line break");
    }

    fn canContinueExpression(self: *const Parser, allow_line_breaks: bool) bool {
        return allow_line_breaks or self.current.position.line == self.previous.position.line;
    }

    pub fn expect(self: *Parser, tag: TokenTag, message: []const u8) ParseError!void {
        if (self.current.tag != tag) return self.fail(message);
        try self.advance();
    }

    pub fn advance(self: *Parser) ParseError!void {
        const next = self.lexer.next() catch |err| {
            self.diagnostic = self.lexer.diagnostic;
            return err;
        };
        if (self.started) {
            self.previous = self.current;
        } else {
            self.started = true;
        }
        self.current = next;
    }

    pub fn fail(self: *Parser, message: []const u8) Source.Error {
        return self.failAt(self.current.position, message);
    }

    pub fn failAt(self: *Parser, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn expectParseError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), source);
    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqualStrings(message, parser.diagnostic.?.message);
}

test "parse user-defined function signatures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {}
        \\func add(left:int, right:int) int {}
        \\func enabled() bool {}
        \\func pow(value:float) float32 {}
        \\func get_name() str {}
        \\func explicit_void() void {}
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 6), program.functions.len);
    try std.testing.expectEqual(Ast.Type.int, program.functions[1].parameters[0].type);
    try std.testing.expectEqual(Ast.Type.int, program.functions[1].return_type);
    try std.testing.expectEqual(Ast.Type.bool, program.functions[2].return_type);
    try std.testing.expectEqual(Ast.Type.float32, program.functions[3].return_type);
    try std.testing.expectEqual(Ast.Type.str, program.functions[4].return_type);
    try std.testing.expectEqual(Ast.Type.void, program.functions[5].return_type);
}

test "parse let literals and arithmetic precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func calculate() int {
        \\    let inferred = 20
        \\    let explicit:int = -2 + 3 * 4 - 5 / 6 % 7
        \\    let intrinsic:bool
        \\    return explicit
        \\}
        \\func main() {}
    );
    const program = try parser.parse();
    const statements = program.functions[0].statements;
    try std.testing.expectEqual(@as(usize, 4), statements.len);
    try std.testing.expectEqualStrings("20", statements[0].variable_declaration.initializer.?.value.integer);
    try std.testing.expectEqual(Ast.Type.int, statements[1].variable_declaration.annotation.?);
    try std.testing.expectEqual(Ast.Type.bool, statements[2].variable_declaration.annotation.?);

    const outer = statements[1].variable_declaration.initializer.?.value.binary;
    try std.testing.expectEqual(Ast.BinaryOperator.subtract, outer.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.add, outer.left.value.binary.operator);
    try std.testing.expectEqual(Ast.UnaryOperator.negate, outer.left.value.binary.left.value.unary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.multiply, outer.left.value.binary.right.value.binary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.remainder, outer.right.value.binary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.divide, outer.right.value.binary.left.value.binary.operator);
}

test "parse booleans nested calls and call statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func enabled() bool { return true }
        \\func main() {
        \\    choose(enabled(), false)
        \\}
    );
    const program = try parser.parse();
    try std.testing.expect(program.functions[0].statements[0].return_statement.value.?.value.boolean);
    const call = program.functions[1].statements[0].expression_statement.value.call;
    try std.testing.expectEqualStrings("choose", call.name);
    try std.testing.expectEqual(@as(usize, 2), call.arguments.len);
    try std.testing.expectEqualStrings("enabled", call.arguments[0].value.call.name);
    try std.testing.expect(!call.arguments[1].value.boolean);
}

test "parse strings comparisons and observable statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {
        \\    print("é\n")
        \\    assert(1 + 2 * 3 < 8 == true, "valid")
        \\    panic("stop")
        \\}
    );
    const program = try parser.parse();
    const statements = program.functions[0].statements;
    try std.testing.expectEqualSlices(u8, "é\n", statements[0].print_statement.values[0].value.string);
    const equality = statements[1].assert_statement.condition.value.binary;
    try std.testing.expectEqual(Ast.BinaryOperator.equal, equality.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.less, equality.left.value.binary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.add, equality.left.value.binary.left.value.binary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.multiply, equality.left.value.binary.left.value.binary.right.value.binary.operator);
    try std.testing.expectEqualSlices(u8, "stop", statements[2].panic_statement.value.value.string);
}

test "parse interpolated strings and variadic print" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {
        \\    let value = 21
        \\    let message = "Value: $(value * 2)"
        \\    print(message, " / ", "$$(value)")
        \\}
    );
    const program = try parser.parse();
    const statements = program.functions[0].statements;
    try std.testing.expectEqual(@as(usize, 3), statements.len);
    const interpolated = statements[1].variable_declaration.initializer.?.value.interpolated_string;
    try std.testing.expectEqual(@as(usize, 2), interpolated.parts.len);
    try std.testing.expectEqualSlices(u8, "Value: ", interpolated.parts[0].text);
    try std.testing.expectEqual(@as(usize, 3), statements[2].print_statement.values.len);
    try std.testing.expectEqualSlices(u8, "$(value)", statements[2].print_statement.values[2].value.string);
}

test "parse conditional alternatives and logical precedence" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {
        \\    if !false && true || false { print("first") }
        \\    elif false { print("second") }
        \\    else if true { print("third") }
        \\    else { print("last") }
        \\}
    );
    const program = try parser.parse();
    const conditional = program.functions[0].statements[0].if_statement;
    try std.testing.expectEqual(@as(usize, 3), conditional.branches.len);
    try std.testing.expect(conditional.else_statements != null);
    const logical_or = conditional.branches[0].condition.expression.value.binary;
    try std.testing.expectEqual(Ast.BinaryOperator.logical_or, logical_or.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.logical_and, logical_or.left.value.binary.operator);
    try std.testing.expectEqual(Ast.UnaryOperator.logical_not, logical_or.left.value.binary.left.value.unary.operator);
}

test "parse mutable declarations and simple assignment statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {
        \\    var value:int = 1
        \\    value = 2
        \\}
    );
    const statements = (try parser.parse()).functions[0].statements;
    try std.testing.expect(statements[0].variable_declaration.mutable);
    try std.testing.expectEqualStrings("value", statements[1].assignment_statement.target.name);
    try std.testing.expectEqual(Ast.AssignmentOperator.assign, statements[1].assignment_statement.operator);
    try std.testing.expectEqualStrings("2", statements[1].assignment_statement.value.?.value.integer);
}

test "parse every arithmetic assignment statement" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {
        \\    var value = 1
        \\    value += 2
        \\    value -= 3
        \\    value *= 4
        \\    value /= 5
        \\    value++
        \\    value--
        \\}
    );
    const statements = (try parser.parse()).functions[0].statements;
    const expected = [_]Ast.AssignmentOperator{ .add, .subtract, .multiply, .divide, .increment, .decrement };
    for (expected, statements[1..]) |operator, statement| {
        try std.testing.expectEqual(operator, statement.assignment_statement.operator);
    }
    try std.testing.expect(statements[5].assignment_statement.value == null);
    try std.testing.expect(statements[6].assignment_statement.value == null);
}

test "parse simple and nested field assignment targets" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {
        \\    var entity:int
        \\    entity.position.x += 2
        \\}
    );
    const assignment = (try parser.parse()).functions[0].statements[1].assignment_statement;
    try std.testing.expectEqualStrings("entity", assignment.target.name);
    try std.testing.expectEqual(@as(usize, 2), assignment.target.fields.len);
    try std.testing.expectEqualStrings("position", assignment.target.fields[0].name);
    try std.testing.expectEqualStrings("x", assignment.target.fields[1].name);
    try std.testing.expectEqual(Ast.AssignmentOperator.add, assignment.operator);
}

test "parse field assignment after collection indexing" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {
        \\    var vertices:int[] = []
        \\    vertices[0].position.x = 2
        \\}
    );
    const assignment = (try parser.parse()).functions[0].statements[1].assignment_statement;
    try std.testing.expectEqualStrings("vertices", assignment.target.name);
    try std.testing.expectEqual(@as(usize, 1), assignment.target.indices.len);
    try std.testing.expectEqual(@as(usize, 2), assignment.target.indexed_fields.len);
    try std.testing.expectEqualStrings("position", assignment.target.indexed_fields[0].name);
    try std.testing.expectEqualStrings("x", assignment.target.indexed_fields[1].name);
}

test "parse while loops and their control statements" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func main() {
        \\    var value = 0
        \\    while (value < 3) {
        \\        if value == 1 { continue }
        \\        break
        \\    }
        \\}
    );
    const statements = (try parser.parse()).functions[0].statements;
    const loop = statements[1].while_statement;
    try std.testing.expectEqual(Ast.BinaryOperator.less, loop.condition.expression.value.binary.operator);
    try std.testing.expectEqual(@as(usize, 2), loop.statements.len);
    try std.testing.expect(loop.statements[0].if_statement.branches[0].statements[0] == .continue_statement);
    try std.testing.expect(loop.statements[1] == .break_statement);
}

test "parse module uses aliases and qualified calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\use Math.Operations
        \\use Math.Integer.Checked as Checked
        \\public use Math.Geometry.Vector
        \\public use Math.Geometry.length as magnitude
        \\func main() { Operations.add(Checked.value(), 2) }
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 4), program.uses.len);
    try std.testing.expectEqualStrings("Math.Operations", program.uses[0].path);
    try std.testing.expect(program.uses[0].alias == null);
    try std.testing.expectEqualStrings("Checked", program.uses[1].alias.?);
    try std.testing.expectEqualStrings("Vector", program.uses[2].alias.?);
    try std.testing.expectEqualStrings("magnitude", program.uses[3].alias.?);
    const call = program.functions[0].statements[0].expression_statement.value.call;
    try std.testing.expectEqualStrings("add", call.name);
    try std.testing.expectEqualStrings("Operations", call.receiver.?.value.identifier);
    try std.testing.expectEqualStrings("value", call.arguments[0].value.call.name);
    try std.testing.expectEqualStrings("Checked", call.arguments[0].value.call.receiver.?.value.identifier);
}

test "parse structure declarations named aggregates and field paths" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\struct Position {
        \\    let layer:int = 2
        \\    var x:int
        \\}
        \\struct Entity { var position:Position }
        \\func main() {
        \\    let entity = Entity(position:Position(x:1,))
        \\    print(entity.position.x)
        \\}
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 2), program.structures.len);
    try std.testing.expect(!program.structures[0].fields[0].mutable);
    try std.testing.expect(program.structures[0].fields[0].default.?.value == .integer);
    try std.testing.expectEqual(@as(usize, 1), program.functions[0].statements[0].variable_declaration.initializer.?.value.call.named_arguments.len);
    const outer = program.functions[0].statements[1].print_statement.values[0].value.field_access;
    try std.testing.expectEqualStrings("x", outer.name);
    try std.testing.expectEqualStrings("position", outer.base.value.field_access.name);
}

test "parse overloaded constructors and self field initialization" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\struct Position {
        \\    let x:int
        \\    let y:int
        \\    init(x:int, y:int) { self.x = x; self.y = y }
        \\    init(enabled:bool) { if enabled { self.x = 1 } else { self.x = 0 } self.y = 2 }
        \\}
        \\func main() { let point = Position(10, 5) }
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 2), program.structures[0].constructors.len);
    try std.testing.expectEqual(@as(usize, 2), program.structures[0].constructors[0].parameters.len);
    const assignment = program.structures[0].constructors[0].statements[0].assignment_statement;
    try std.testing.expectEqualStrings("self", assignment.target.name);
    try std.testing.expectEqualStrings("x", assignment.target.fields[0].name);
    try std.testing.expectEqual(@as(usize, 2), program.functions[0].statements[0].variable_declaration.initializer.?.value.call.arguments.len);
}

test "parse trailing parameter defaults for functions constructors and methods" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\struct Box {
        \\    init(value:int = 40) {}
        \\    func plus(value:int = 2) int { return value }
        \\}
        \\func selected(value:int = 1, other:int = 2) int { return value + other }
        \\func main() {}
    );
    const program = try parser.parse();
    try std.testing.expectEqualStrings("40", program.structures[0].constructors[0].parameters[0].default.?.value.integer);
    try std.testing.expectEqualStrings("2", program.structures[0].methods[0].parameters[0].default.?.value.integer);
    try std.testing.expectEqualStrings("1", program.functions[0].parameters[0].default.?.value.integer);
    try std.testing.expectEqualStrings("2", program.functions[0].parameters[1].default.?.value.integer);
}

test "reject a required parameter after a default" {
    try expectParseError(
        "func invalid(first:int = 1, second:int) {} func main() {}",
        "a required parameter cannot follow a parameter with a default value",
    );
    try expectParseError(
        "struct Invalid { init(first:int = 1, second:int) {} } func main() {}",
        "a required parameter cannot follow a parameter with a default value",
    );
}

test "parse methods and chained member calls" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\struct Counter {
        \\    var value:int
        \\    func increment() { self.value++ }
        \\    public func current() int { return self.value }
        \\}
        \\func make() Counter { return Counter(value:1) }
        \\func main() {
        \\    var counter = Counter()
        \\    counter.increment()
        \\    print(make().current())
        \\}
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 2), program.structures[0].methods.len);
    const mutation = program.functions[1].statements[1].expression_statement.value.call;
    try std.testing.expectEqualStrings("increment", mutation.name);
    try std.testing.expectEqualStrings("counter", mutation.receiver.?.value.identifier);
    const chained = program.functions[1].statements[2].print_statement.values[0].value.call;
    try std.testing.expectEqualStrings("current", chained.name);
    try std.testing.expect(chained.receiver.?.value == .call);
}

test "reject legacy and malformed structure syntax" {
    try expectParseError("struct Position { x:int } func main() {}", "structure field must start with 'let' or 'var'");
    try expectParseError("struct Position { var x:int } func main() { let value = Position { x:1 } }", "expected ';' or line break");
}

test "parse public functions and keep functions private by default" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\public func exposed(value:int) int { return value }
        \\func hidden() {}
    );
    const program = try parser.parse();
    try std.testing.expect(program.functions[0].is_public);
    try std.testing.expect(!program.functions[1].is_public);
}

test "parse public default internal local and private structure members" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\public struct Vec2 {
        \\    public var x:int
        \\    let y:int
        \\    internal func packageOnly() {}
        \\    local func fileOnly() {}
        \\    private init() {}
        \\    private struct Storage {}
        \\}
        \\func read(value:Geometry.Point) int { return value.x }
        \\func main() {}
    );
    const program = try parser.parse();
    try std.testing.expect(program.structures[0].is_public);
    try std.testing.expect(program.structures[0].fields[0].is_public);
    try std.testing.expect(program.structures[0].fields[1].is_public);
    try std.testing.expect(program.structures[0].methods[0].is_internal);
    try std.testing.expect(program.structures[0].methods[1].is_local);
    try std.testing.expect(program.structures[0].constructors[0].is_private);
    try std.testing.expect(program.structures[1].is_private);
    const type_index = program.functions[0].parameters[0].type.structureIndex().?;
    try std.testing.expectEqualStrings("Geometry.Point", program.type_names[type_index]);
}

test "apply optional and collection type suffixes from left to right" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\struct Iterator<T> { private var values:T?[] }
        \\struct State {
        \\    let optional_values:int?[]
        \\    let optional_list:int[]?
        \\    let fixed_optionals:int?[3]
        \\}
        \\func main() {}
    );
    const program = try parser.parse();
    var iterator: ?Ast.Structure = null;
    var state: ?Ast.Structure = null;
    for (program.structures) |structure| {
        if (std.mem.eql(u8, structure.name, "Iterator")) iterator = structure;
        if (std.mem.eql(u8, structure.name, "State")) state = structure;
    }
    try std.testing.expectEqualStrings("T?[]", program.type_names[iterator.?.fields[0].type.structureIndex().?]);
    try std.testing.expectEqualStrings("int?[]", program.type_names[state.?.fields[0].type.structureIndex().?]);
    try std.testing.expectEqualStrings("int[]", program.type_names[state.?.fields[1].type.optionalChild().?.structureIndex().?]);
    try std.testing.expectEqualStrings("int?[3]", program.type_names[state.?.fields[2].type.structureIndex().?]);
}

test "reject protected structure members" {
    try expectParseError(
        "struct Value { protected var value:int } func main() {}",
        "structures only support public, internal, local, or private members",
    );
}

test "continue expressions after operators and inside parentheses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func value() int {
        \\    return (1
        \\        + 2) *
        \\        3
        \\}
        \\func main() {}
    );
    const program = try parser.parse();
    const expression = program.functions[0].statements[0].return_statement.value.?;
    try std.testing.expectEqual(Ast.BinaryOperator.multiply, expression.value.binary.operator);
    try std.testing.expectEqual(Ast.BinaryOperator.add, expression.value.binary.left.value.binary.operator);
}

test "semicolon separates statements on one line" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), "func main() { let first = 1; let second = 2 }");
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 2), program.functions[0].statements.len);
}

test "report malformed parameter at its source position" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(), "func main(value float) {}");
    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqual(@as(usize, 1), parser.diagnostic.?.position.line);
    try std.testing.expectEqual(@as(usize, 17), parser.diagnostic.?.position.column);
    try std.testing.expectEqualStrings("expected ':' after parameter name", parser.diagnostic.?.message);
}

test "parse anonymous function expressions" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = Parser.init(arena.allocator(),
        \\func apply(callback:func(int) bool) {}
        \\func main() {
        \\    apply(func(value:int) bool { return value > 0 })
        \\}
    );
    const program = try parser.parse();
    try std.testing.expectEqual(@as(usize, 3), program.functions.len);
    try std.testing.expect(std.mem.startsWith(u8, program.functions[2].name, "__silex_anonymous_"));
    try std.testing.expectEqual(Ast.Type.bool, program.functions[2].return_type);
    try std.testing.expectEqual(@as(usize, 1), program.functions[2].parameters.len);
    const argument = program.functions[1].statements[0].expression_statement.value.call.arguments[0];
    try std.testing.expectEqualStrings(program.functions[2].name, argument.value.identifier);
}

test "reject defaults in anonymous function parameters" {
    try expectParseError(
        "func main() { let callback = func(value:int = 1) {} }",
        "anonymous function parameters cannot have default values",
    );
}

test "report malformed fundamental statements and expressions" {
    try expectParseError("func main() { let value\n}", "variable declaration requires a type or initializer");
    try expectParseError("func main() { return 1 +\n}", "expected expression");
    try expectParseError("func main() { call(1 2) }", "expected ',' or ')' after argument");
    try expectParseError("func main() { return 1 return }", "expected ';' or line break");
    try expectParseError("func main() { let first = 1 let second = 2 }", "expected ';' or line break");
    try expectParseError("func main() { print() }", "print expects at least one value");
    try expectParseError(
        "func main() { let message = \"$()\" }",
        "expected expression inside string interpolation",
    );
    try expectParseError("func main() { assert(true,) }", "expected expression");
    try expectParseError("func main() { assert(true, \"message\" }", "expected ')' after assert message");
    try expectParseError("func main() { panic(\"message\", \"extra\") }", "expected ')' after effect value");
    try expectParseError("func main() { value = }", "expected expression");
    try expectParseError("func main() { while true break }", "expected '{' before function body");
    try expectParseError("func main() { break value() }", "expected ';' or line break");
    try expectParseError("func main() { var value = 1; value++ 2 }", "expected ';' or line break");
}
