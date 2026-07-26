const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Numeric = @import("../Numeric.zig");
const Source = @import("../Source.zig");
const Mutation = @import("Mutation.zig");
const Optionals = @import("Optionals.zig");
const Constructors = @import("Constructors.zig");
const Model = @import("Model.zig");
const Methods = @import("Methods.zig");
const Control = @import("Control.zig");
const Enums = @import("Enums.zig");
const Support = @import("Support.zig");
const Types = @import("../Types.zig");

const Allocator = std.mem.Allocator;
const AnalyzeError = Source.Error || Allocator.Error;

pub const Binding = Model.Binding;
pub const TypedValue = Model.TypedValue;
pub const BlockBuilder = Model.BlockBuilder;

const StructureState = enum { unseen, visiting, complete };

pub const FunctionBuilder = Model.FunctionBuilder;

pub const Analyzer = struct {
    allocator: Allocator,
    program: Ast.Program = undefined,
    structures: []const Ir.Structure = &.{},
    enums: []const Ir.Enum = &.{},
    method_mutability: []const bool = &.{},
    default_expansions: std.ArrayList(*const Ast.Expression) = .empty,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: Allocator) Analyzer {
        return .{ .allocator = allocator };
    }

    pub fn analyze(self: *Analyzer, program: Ast.Program) AnalyzeError!Ir.Program {
        return self.analyzeProgram(program, true);
    }

    pub fn analyzeUnit(self: *Analyzer, program: Ast.Program) AnalyzeError!Ir.Program {
        return self.analyzeProgram(program, false);
    }

    fn analyzeProgram(self: *Analyzer, program: Ast.Program, require_entry: bool) AnalyzeError!Ir.Program {
        self.program = program;
        self.diagnostic = null;
        self.structures = try self.prepareStructures();
        self.enums = try Enums.prepare(self);
        self.method_mutability = try Methods.inferMutability(self.allocator, self.program);
        self.structures = try Methods.extendStructures(self.allocator, self.program, self.structures, self.method_mutability);
        try self.validateDeclarations(require_entry);
        try self.validateParameterDefaults();

        var functions: std.ArrayList(Ir.Function) = .empty;
        for (program.functions, 0..) |function, function_id| {
            try functions.append(self.allocator, try self.analyzeFunction(function_id, function));
        }
        for (program.structures, 0..) |structure, structure_index| {
            for (structure.constructors, 0..) |constructor, constructor_index| {
                try functions.append(
                    self.allocator,
                    try Constructors.analyze(self, structure_index, constructor_index, constructor),
                );
            }
        }
        for (program.structures, 0..) |structure, structure_index| {
            for (structure.methods, 0..) |method, method_index| {
                try functions.append(
                    self.allocator,
                    try Methods.analyze(self, structure_index, method_index, method),
                );
            }
        }
        return .{ .structures = self.structures, .enums = self.enums, .functions = try functions.toOwnedSlice(self.allocator) };
    }

    fn validateDeclarations(self: *Analyzer, require_entry: bool) AnalyzeError!void {
        var main: ?Ast.Function = null;
        for (self.program.functions) |function| {
            if (std.mem.eql(u8, function.name, "main")) {
                if (main != null) return self.fail(function.name_position, "'main' cannot be overloaded");
                main = function;
            }

            for (function.parameters, 0..) |parameter, index| {
                for (function.parameters[0..index]) |previous| {
                    if (std.mem.eql(u8, parameter.name, previous.name)) {
                        const message = try std.fmt.allocPrint(self.allocator, "parameter '{s}' is already declared", .{parameter.name});
                        return self.fail(parameter.position, message);
                    }
                }
            }
        }

        for (self.program.functions, 0..) |function, index| {
            for (self.program.functions[0..index]) |previous| {
                if (!std.mem.eql(u8, function.name, previous.name)) continue;
                const arity = Support.effectiveSignatureCollision(function.parameters, previous.parameters) orelse continue;
                if (Support.sameParameterTypes(function.parameters, previous.parameters) and
                    Support.requiredParameterCount(function.parameters) == function.parameters.len and
                    Support.requiredParameterCount(previous.parameters) == previous.parameters.len)
                {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "function '{s}' with these parameter types is already declared",
                        .{function.name},
                    );
                    return self.fail(function.name_position, message);
                }
                const signature = try self.effectiveSignature(function.name, function.parameters, arity);
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "function '{s}' is already exposed by the declaration at {d}:{d}",
                    .{ signature, previous.name_position.line, previous.name_position.column },
                );
                return self.fail(function.name_position, message);
            }
        }

        for (self.program.structures) |structure| {
            for (structure.constructors, 0..) |constructor, index| {
                for (constructor.parameters, 0..) |parameter, parameter_index| {
                    for (constructor.parameters[0..parameter_index]) |previous| {
                        if (std.mem.eql(u8, parameter.name, previous.name)) {
                            const message = try std.fmt.allocPrint(self.allocator, "parameter '{s}' is already declared", .{parameter.name});
                            return self.fail(parameter.position, message);
                        }
                    }
                }
                for (structure.constructors[0..index]) |previous| {
                    const arity = Support.effectiveSignatureCollision(constructor.parameters, previous.parameters) orelse continue;
                    if (Support.sameParameterTypes(constructor.parameters, previous.parameters) and
                        Support.requiredParameterCount(constructor.parameters) == constructor.parameters.len and
                        Support.requiredParameterCount(previous.parameters) == previous.parameters.len)
                    {
                        const message = try std.fmt.allocPrint(
                            self.allocator,
                            "constructor for '{s}' with these parameter types is already declared",
                            .{structure.name},
                        );
                        return self.fail(constructor.position, message);
                    }
                    const signature = try self.effectiveSignature("init", constructor.parameters, arity);
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "constructor '{s}' is already exposed by the declaration at {d}:{d}",
                        .{ signature, previous.position.line, previous.position.column },
                    );
                    return self.fail(constructor.position, message);
                }
            }
            for (structure.methods, 0..) |method, index| {
                for (method.parameters, 0..) |parameter, parameter_index| {
                    for (method.parameters[0..parameter_index]) |previous| {
                        if (std.mem.eql(u8, parameter.name, previous.name)) {
                            const message = try std.fmt.allocPrint(self.allocator, "parameter '{s}' is already declared", .{parameter.name});
                            return self.fail(parameter.position, message);
                        }
                    }
                }
                for (structure.methods[0..index]) |previous| {
                    if (!std.mem.eql(u8, method.name, previous.name)) continue;
                    const arity = Support.effectiveSignatureCollision(method.parameters, previous.parameters) orelse continue;
                    if (Support.sameParameterTypes(method.parameters, previous.parameters) and
                        Support.requiredParameterCount(method.parameters) == method.parameters.len and
                        Support.requiredParameterCount(previous.parameters) == previous.parameters.len)
                    {
                        const message = try std.fmt.allocPrint(
                            self.allocator,
                            "method '{s}' with these parameter types is already declared in '{s}'",
                            .{ method.name, structure.name },
                        );
                        return self.fail(method.name_position, message);
                    }
                    const signature = try self.effectiveSignature(method.name, method.parameters, arity);
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "method '{s}' is already exposed in '{s}' by the declaration at {d}:{d}",
                        .{ signature, structure.name, previous.name_position.line, previous.name_position.column },
                    );
                    return self.fail(method.name_position, message);
                }
            }
        }

        const entry = main orelse {
            if (require_entry) return self.fail(
                .{ .offset = 0, .line = 1, .column = 1 },
                "missing 'main' function",
            );
            return;
        };
        if (entry.parameters.len != 0) return self.fail(entry.name_position, "'main' must have no parameters");
        if (entry.return_type != .void) return self.fail(entry.name_position, "'main' must return 'void'");
    }

    fn validateParameterDefaults(self: *Analyzer) AnalyzeError!void {
        for (self.program.functions) |function| try self.validateDefaults(function.parameters);
        for (self.program.structures) |structure| {
            for (structure.constructors) |constructor| try self.validateDefaults(constructor.parameters);
            for (structure.methods) |method| try self.validateDefaults(method.parameters);
        }
    }

    fn validateDefaults(self: *Analyzer, parameters: []const Ast.Parameter) AnalyzeError!void {
        var builder: FunctionBuilder = .{};
        try builder.blocks.append(self.allocator, .{});
        for (parameters) |parameter| {
            if (parameter.default == null) continue;
            _ = try self.analyzeParameterDefault(&builder, parameter);
        }
    }

    fn effectiveSignature(
        self: *Analyzer,
        name: []const u8,
        parameters: []const Ast.Parameter,
        arity: usize,
    ) Allocator.Error![]const u8 {
        var signature = try std.fmt.allocPrint(self.allocator, "{s}(", .{name});
        for (parameters[0..arity], 0..) |parameter, index| {
            signature = try std.fmt.allocPrint(
                self.allocator,
                "{s}{s}{s}",
                .{ signature, if (index == 0) "" else ", ", self.typeName(parameter.type) },
            );
        }
        return std.fmt.allocPrint(self.allocator, "{s})", .{signature});
    }

    fn analyzeFunction(self: *Analyzer, function_id: Ir.FunctionId, function: Ast.Function) AnalyzeError!Ir.Function {
        _ = function_id;
        var builder: FunctionBuilder = .{};
        try builder.blocks.append(self.allocator, .{});
        var parameter_types: std.ArrayList(Types.Type) = .empty;
        for (function.parameters, 0..) |parameter, value| {
            try parameter_types.append(self.allocator, parameter.type);
            try builder.value_types.append(self.allocator, parameter.type);
            try builder.bindings.append(self.allocator, .{
                .name = parameter.name,
                .type = parameter.type,
                .value = value,
                .parameter = true,
            });
        }

        const ends_with_return = try self.analyzeStatements(&builder, function, function.statements);
        if (function.return_type == .void) {
            if (!ends_with_return) self.terminate(&builder, .return_void);
        } else if (!ends_with_return) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "function '{s}' must return '{s}' on every path",
                .{ function.name, self.typeName(function.return_type) },
            );
            return self.fail(function.name_position, message);
        }

        var blocks: std.ArrayList(Ir.Block) = .empty;
        for (builder.blocks.items) |*block| {
            try blocks.append(self.allocator, .{
                .instructions = try block.instructions.toOwnedSlice(self.allocator),
                .terminator = block.terminator orelse return error.InvalidSource,
            });
        }
        const owned_blocks = try blocks.toOwnedSlice(self.allocator);
        return .{
            .name = function.name,
            .parameter_types = try parameter_types.toOwnedSlice(self.allocator),
            .return_type = function.return_type,
            .value_types = try builder.value_types.toOwnedSlice(self.allocator),
            .local_types = try builder.local_types.toOwnedSlice(self.allocator),
            .blocks = owned_blocks,
        };
    }

    pub fn analyzeStatements(self: *Analyzer, builder: *FunctionBuilder, function: Ast.Function, statements: []const Ast.Statement) AnalyzeError!bool {
        for (statements) |statement| {
            if (try self.analyzeStatement(builder, function, statement)) return true;
        }
        return false;
    }

    pub fn analyzeParameterDefault(
        self: *Analyzer,
        builder: *FunctionBuilder,
        parameter: Ast.Parameter,
    ) AnalyzeError!TypedValue {
        const expression = parameter.default orelse return error.InvalidSource;
        for (self.default_expansions.items) |active| {
            if (active == expression) {
                return self.fail(expression.position, "default parameter expansion is recursive");
            }
        }
        try self.default_expansions.append(self.allocator, expression);
        defer _ = self.default_expansions.pop();
        const caller_bindings = builder.bindings;
        builder.bindings = .empty;
        defer builder.bindings = caller_bindings;
        var value = try self.analyzeExpressionExpected(
            builder,
            expression,
            Optionals.expectedContext(parameter.type, expression),
        );
        if (value.type != parameter.type and (Numeric.canWiden(value.type, parameter.type) or Optionals.canConvert(value.type, parameter.type))) {
            value = try self.coerce(builder, value, parameter.type, expression.position);
        }
        if (value.type != parameter.type) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "default for parameter '{s}' expects '{s}', found '{s}'",
                .{ parameter.name, self.typeName(parameter.type), self.typeName(value.type) },
            );
            return self.fail(expression.position, message);
        }
        return value;
    }

    fn analyzeStatement(self: *Analyzer, builder: *FunctionBuilder, function: Ast.Function, statement: Ast.Statement) AnalyzeError!bool {
        return switch (statement) {
            .variable_declaration => |declaration| variable: {
                try self.analyzeVariable(builder, declaration);
                break :variable false;
            },
            .assignment_statement => |assignment| assignment_statement: {
                try Mutation.analyzeAssignment(self, builder, assignment);
                break :assignment_statement false;
            },
            .return_statement => |return_statement| return_value: {
                try self.analyzeReturn(builder, function, return_statement);
                break :return_value true;
            },
            .expression_statement => |expression| switch (expression.value) {
                .call => |call| {
                    _ = try self.analyzeCall(builder, call);
                    return false;
                },
                else => unreachable,
            },
            .print_statement => |print_statement| effect: {
                try self.analyzePrint(builder, print_statement);
                break :effect false;
            },
            .assert_statement => |assert_statement| effect: {
                try self.analyzeAssert(builder, assert_statement);
                break :effect false;
            },
            .panic_statement => |panic_statement| fatal: {
                try self.analyzePanic(builder, panic_statement);
                break :fatal true;
            },
            .if_statement => |conditional| Control.analyzeIf(self, builder, function, conditional),
            .while_statement => |loop| Control.analyzeWhile(self, builder, function, loop),
            .break_statement => |position| Control.analyzeLoopControl(self, builder, position, false),
            .continue_statement => |position| Control.analyzeLoopControl(self, builder, position, true),
        };
    }

    fn analyzeVariable(self: *Analyzer, builder: *FunctionBuilder, declaration: Ast.VariableDeclaration) AnalyzeError!void {
        if (Support.findBinding(builder.bindings.items, declaration.name) != null) {
            const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{declaration.name});
            return self.fail(declaration.name_position, message);
        }

        var initializer: TypedValue = if (declaration.initializer) |expression|
            try self.analyzeExpressionExpected(
                builder,
                expression,
                if (declaration.annotation) |annotation| Optionals.expectedContext(annotation, expression) else null,
            )
        else intrinsic: {
            const annotation = declaration.annotation.?;
            break :intrinsic try self.emitIntrinsic(builder, annotation, declaration.name_position);
        };
        const declared_type = declaration.annotation orelse initializer.type;
        if (initializer.type != declared_type and (Numeric.canWiden(initializer.type, declared_type) or Optionals.canConvert(initializer.type, declared_type))) {
            initializer = try self.coerce(builder, initializer, declared_type, declaration.initializer.?.position);
        }
        if (initializer.type != declared_type) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "variable '{s}' expects '{s}', found '{s}'",
                .{ declaration.name, self.typeName(declared_type), self.typeName(initializer.type) },
            );
            return self.fail(if (declaration.initializer) |value| value.position else declaration.name_position, message);
        }
        if (declaration.mutable) {
            const local = builder.local_types.items.len;
            try builder.local_types.append(self.allocator, declared_type);
            try self.emit(builder, .{ .local_store = .{ .local = local, .operand = initializer.value } });
            try builder.bindings.append(self.allocator, .{
                .name = declaration.name,
                .type = declared_type,
                .local = local,
                .mutable = true,
            });
        } else try builder.bindings.append(self.allocator, .{
            .name = declaration.name,
            .type = declared_type,
            .value = initializer.value,
        });
    }

    fn analyzeReturn(self: *Analyzer, builder: *FunctionBuilder, function: Ast.Function, statement: Ast.ReturnStatement) AnalyzeError!void {
        if (statement.value) |expression| {
            if (function.return_type == .void) return self.fail(statement.position, "a void function cannot return a value");
            var value = try self.analyzeExpressionExpected(
                builder,
                expression,
                Optionals.expectedContext(function.return_type, expression),
            );
            if (value.type != function.return_type and (Numeric.canWiden(value.type, function.return_type) or Optionals.canConvert(value.type, function.return_type))) {
                value = try self.coerce(builder, value, function.return_type, expression.position);
            }
            if (value.type != function.return_type) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "return expects '{s}', found '{s}'",
                    .{ self.typeName(function.return_type), self.typeName(value.type) },
                );
                return self.fail(expression.position, message);
            }
            self.terminate(builder, .{ .return_value = value.value });
            return;
        }

        if (function.return_type != .void) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "expected return value of type '{s}'",
                .{self.typeName(function.return_type)},
            );
            return self.fail(statement.position, message);
        }
        self.terminate(builder, .return_void);
    }

    pub fn analyzeExpression(self: *Analyzer, builder: *FunctionBuilder, expression: *const Ast.Expression) AnalyzeError!TypedValue {
        return self.analyzeExpressionExpected(builder, expression, null);
    }

    pub fn analyzeExpressionExpected(
        self: *Analyzer,
        builder: *FunctionBuilder,
        expression: *const Ast.Expression,
        expected: ?Types.Type,
    ) AnalyzeError!TypedValue {
        const value = try switch (expression.value) {
            .integer => |lexeme| integer: {
                const target = if (expected != null and expected.?.isInteger()) expected.? else Types.Type.int;
                break :integer try self.emitIntegerLiteral(builder, lexeme, false, target, expression.position);
            },
            .floating => |lexeme| floating: {
                const target = if (expected != null and expected.?.isFloat()) expected.? else Types.Type.float32;
                break :floating try self.emitFloatingLiteral(builder, lexeme, target, expression.position);
            },
            .boolean => |value| self.emitBool(builder, value),
            .null_value => Optionals.analyzeNull(self, builder, expected, expression.position),
            .string => |value| self.emitString(builder, value),
            .interpolated_string => |value| self.analyzeInterpolatedString(builder, value),
            .identifier => |name| self.analyzeIdentifier(builder, expression.position, name),
            .field_access => |access| self.analyzeFieldAccess(builder, access),
            .call => |call| (try self.analyzeCall(builder, call)) orelse {
                const message = try std.fmt.allocPrint(self.allocator, "function '{s}' returns 'void' and cannot be used as a value", .{call.name});
                return self.fail(call.name_position, message);
            },
            .unary => |unary| self.analyzeUnary(builder, unary, expected),
            .binary => |binary| self.analyzeBinary(builder, binary, expected),
            .conversion => |conversion| self.analyzeConversion(builder, conversion),
            .string_count => |operand| self.analyzeStringCount(builder, operand),
        };
        if (expected) |target| return self.coerce(builder, value, target, expression.position);
        return value;
    }

    fn analyzeIdentifier(
        self: *Analyzer,
        builder: *FunctionBuilder,
        position: Source.Position,
        name: []const u8,
    ) AnalyzeError!TypedValue {
        const binding = Support.findBinding(builder.bindings.items, name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{name});
            return self.fail(position, message);
        };
        if (binding.refined_type) |type_value| return .{
            .type = type_value,
            .value = binding.refined_value.?,
        };
        if (!binding.type.hasRuntimeValue()) {
            const message = try std.fmt.allocPrint(self.allocator, "values of type '{s}' are not executable yet", .{binding.type.name()});
            return self.fail(position, message);
        }
        if (binding.local) |local| {
            const result = try self.newValue(builder, binding.type);
            try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
            return .{ .type = binding.type, .value = result };
        }
        return .{ .type = binding.type, .value = binding.value.? };
    }

    fn analyzeUnary(
        self: *Analyzer,
        builder: *FunctionBuilder,
        unary: Ast.Expression.Unary,
        expected: ?Types.Type,
    ) AnalyzeError!TypedValue {
        if (unary.operator == .logical_not) {
            const operand = try self.analyzeExpressionExpected(builder, unary.operand, .bool);
            if (operand.type != .bool) {
                const message = try std.fmt.allocPrint(self.allocator, "operator '!' expects 'bool', found '{s}'", .{operand.type.name()});
                return self.fail(unary.operator_position, message);
            }
            const false_value = try self.emitBool(builder, false);
            const result = try self.newValue(builder, .bool);
            try self.emit(builder, .{ .binary = .{
                .result = result,
                .operator = .equal,
                .left = operand.value,
                .right = false_value.value,
            } });
            return .{ .type = .bool, .value = result };
        }
        switch (unary.operand.value) {
            .integer => |lexeme| {
                const target = if (expected != null and expected.?.isInteger()) expected.? else Types.Type.int;
                if (target.isSignedInteger()) return self.emitIntegerLiteral(builder, lexeme, true, target, unary.operator_position);
            },
            else => {},
        }

        const operand = try self.analyzeExpressionExpected(builder, unary.operand, if (expected != null and expected.?.isNumeric()) expected else null);
        if (!operand.type.isNumeric()) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "operator '-' expects a numeric value, found '{s}'",
                .{operand.type.name()},
            );
            return self.fail(unary.operator_position, message);
        }
        const result = try self.newValue(builder, operand.type);
        try self.emit(builder, .{ .unary = .{
            .result = result,
            .operator = .negate,
            .operand = operand.value,
        } });
        return .{ .type = operand.type, .value = result };
    }

    fn analyzeBinary(
        self: *Analyzer,
        builder: *FunctionBuilder,
        binary: Ast.Expression.Binary,
        expected: ?Types.Type,
    ) AnalyzeError!TypedValue {
        if (binary.operator == .logical_and or binary.operator == .logical_or) {
            return self.analyzeLogical(builder, binary);
        }
        const equality = binary.operator == .equal or binary.operator == .not_equal;
        var left: TypedValue = undefined;
        var right: TypedValue = undefined;
        if (equality and binary.left.value == .null_value) {
            right = try self.analyzeExpression(builder, binary.right);
            left = try self.analyzeExpressionExpected(builder, binary.left, right.type);
        } else {
            const left_hint = if (expected != null and expected.?.isNumeric() and Support.isNumericLiteral(binary.left)) expected else null;
            left = try self.analyzeExpressionExpected(builder, binary.left, left_hint);
            if (equality and binary.right.value == .null_value) {
                right = try self.analyzeExpressionExpected(builder, binary.right, left.type);
            } else {
                const right_hint = if (Support.isNumericLiteral(binary.right))
                    (if (expected != null and expected.?.isNumeric()) expected else if (left.type.isNumeric()) left.type else null)
                else
                    null;
                right = try self.analyzeExpressionExpected(builder, binary.right, right_hint);
            }
        }
        if (binary.operator == .add and left.type == .str and right.type == .str) {
            const result = try self.newValue(builder, .str);
            try self.emit(builder, .{ .string_concat = .{
                .result = result,
                .left = left.value,
                .right = right.value,
            } });
            return .{ .type = .str, .value = result };
        }
        const ordering = binary.operator == .less or binary.operator == .less_equal or
            binary.operator == .greater or binary.operator == .greater_equal;
        const bitwise = binary.operator == .bit_and or binary.operator == .bit_xor;
        const shift = binary.operator == .shift_left or binary.operator == .shift_right;
        if (left.type.isNumeric() and right.type.isNumeric() and !shift) {
            if (Numeric.commonNumeric(left.type, right.type)) |common| {
                left = try self.coerce(builder, left, common, binary.left.position);
                right = try self.coerce(builder, right, common, binary.right.position);
            }
        }
        const same_numeric = left.type == right.type and left.type.isNumeric();
        const valid = if (bitwise)
            same_numeric and left.type.isInteger() and !left.type.isSignedInteger()
        else if (shift)
            left.type.isInteger() and !left.type.isSignedInteger() and right.type.isInteger()
        else if (equality)
            same_numeric or (left.type == right.type and self.isComparable(left.type))
        else
            same_numeric and (!left.type.isFloat() or binary.operator != .remainder);
        if (!valid) {
            const message = if (!equality)
                try std.fmt.allocPrint(
                    self.allocator,
                    "operator '{s}' does not accept '{s}' and '{s}'",
                    .{ Support.binaryOperatorText(binary.operator), self.typeName(left.type), self.typeName(right.type) },
                )
            else
                try std.fmt.allocPrint(
                    self.allocator,
                    "operator '{s}' does not accept '{s}' and '{s}'",
                    .{ Support.binaryOperatorText(binary.operator), self.typeName(left.type), self.typeName(right.type) },
                );
            return self.fail(binary.operator_position, message);
        }
        const result_type: Types.Type = if (equality or ordering) .bool else left.type;
        const result = try self.newValue(builder, result_type);
        try self.emit(builder, .{ .binary = .{
            .result = result,
            .operator = switch (binary.operator) {
                .add => .add,
                .subtract => .subtract,
                .multiply => .multiply,
                .divide => .divide,
                .remainder => .remainder,
                .less => .less,
                .less_equal => .less_equal,
                .greater => .greater,
                .greater_equal => .greater_equal,
                .equal => .equal,
                .not_equal => .not_equal,
                .logical_and, .logical_or => unreachable,
                .bit_and => .bit_and,
                .bit_xor => .bit_xor,
                .shift_left => .shift_left,
                .shift_right => .shift_right,
            },
            .left = left.value,
            .right = right.value,
        } });
        return .{ .type = result_type, .value = result };
    }

    fn analyzeLogical(self: *Analyzer, builder: *FunctionBuilder, binary: Ast.Expression.Binary) AnalyzeError!TypedValue {
        const left = try self.analyzeExpression(builder, binary.left);
        if (left.type != .bool) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "operator '{s}' expects 'bool' operands, found '{s}'",
                .{ Support.binaryOperatorText(binary.operator), left.type.name() },
            );
            return self.fail(binary.operator_position, message);
        }

        const result = try self.newValue(builder, .bool);
        const right_block = try self.newBlock(builder);
        const short_block = try self.newBlock(builder);
        const merge_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = if (binary.operator == .logical_and) .{
            .condition = left.value,
            .then_block = right_block,
            .else_block = short_block,
        } else .{
            .condition = left.value,
            .then_block = short_block,
            .else_block = right_block,
        } });

        builder.current_block = short_block;
        try self.emit(builder, .{ .constant_bool = .{
            .result = result,
            .value = binary.operator == .logical_or,
        } });
        self.terminate(builder, .{ .jump = merge_block });

        builder.current_block = right_block;
        const right = try self.analyzeExpression(builder, binary.right);
        if (right.type != .bool) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "operator '{s}' expects 'bool' operands, found '{s}'",
                .{ Support.binaryOperatorText(binary.operator), right.type.name() },
            );
            return self.fail(binary.operator_position, message);
        }
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = right.value } });
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = merge_block;
        return .{ .type = .bool, .value = result };
    }

    fn prepareStructures(self: *Analyzer) AnalyzeError![]const Ir.Structure {
        for (self.program.structures, 0..) |structure, index| {
            for (self.program.structures[0..index]) |previous| {
                if (std.mem.eql(u8, structure.name, previous.name)) {
                    const message = try std.fmt.allocPrint(self.allocator, "structure '{s}' is already declared", .{structure.name});
                    return self.fail(structure.name_position, message);
                }
            }
            for (self.program.functions) |function| {
                if (std.mem.eql(u8, structure.name, function.name)) {
                    const message = try std.fmt.allocPrint(self.allocator, "declaration name '{s}' is already used by a function", .{structure.name});
                    return self.fail(structure.name_position, message);
                }
            }
            for (structure.fields, 0..) |field, field_index| {
                if (field.type == .void) return self.fail(field.name_position, "a structure field cannot have type 'void'");
                for (structure.fields[0..field_index]) |previous| {
                    if (std.mem.eql(u8, field.name, previous.name)) {
                        const message = try std.fmt.allocPrint(self.allocator, "field '{s}' is already declared in this structure", .{field.name});
                        return self.fail(field.name_position, message);
                    }
                }
            }
        }

        const structures = try self.allocator.alloc(Ir.Structure, self.program.type_names.len);
        for (self.program.type_names, 0..) |name, type_index| {
            const declaration = self.findAstStructure(name) orelse {
                if (Enums.find(self, name) != null) {
                    structures[type_index] = .{ .name = name, .fields = &.{} };
                    continue;
                }
                const message = try std.fmt.allocPrint(self.allocator, "unknown nominal type '{s}'", .{name});
                return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, message);
            };
            const fields = try self.allocator.alloc(Ir.StructureField, declaration.fields.len);
            for (declaration.fields, 0..) |field, field_index| fields[field_index] = .{
                .name = field.name,
                .type = field.type,
                .mutable = field.mutable,
            };
            structures[type_index] = .{ .name = name, .fields = fields };
        }
        self.structures = structures;

        const states = try self.allocator.alloc(StructureState, structures.len);
        @memset(states, .unseen);
        for (structures, 0..) |_, index| try self.validateStructureCycle(index, states);

        for (self.program.structures) |structure| {
            for (structure.fields) |field| if (field.default) |default| {
                if (!restrictedFieldDefault(self, default)) {
                    return self.fail(default.position, "field default must be a fundamental literal or structure aggregate");
                }
                var builder: FunctionBuilder = .{};
                try builder.blocks.append(self.allocator, .{});
                var value = try self.analyzeExpressionExpected(
                    &builder,
                    default,
                    Optionals.expectedContext(field.type, default),
                );
                if (value.type != field.type and (Numeric.canWiden(value.type, field.type) or Optionals.canConvert(value.type, field.type))) {
                    value = try self.coerce(&builder, value, field.type, default.position);
                }
                if (value.type != field.type) {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "default for field '{s}' expects '{s}', found '{s}'",
                        .{ field.name, self.typeName(field.type), self.typeName(value.type) },
                    );
                    return self.fail(default.position, message);
                }
            };
        }
        return structures;
    }

    fn validateStructureCycle(
        self: *Analyzer,
        index: usize,
        states: []StructureState,
    ) AnalyzeError!void {
        switch (states[index]) {
            .complete => return,
            .visiting => {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "structure '{s}' has a recursive value representation",
                    .{self.structures[index].name},
                );
                const declaration = self.findAstStructure(self.structures[index].name).?;
                return self.fail(declaration.name_position, message);
            },
            .unseen => {},
        }
        states[index] = .visiting;
        for (self.structures[index].fields) |field| {
            const field_type = field.type.optionalChild() orelse field.type;
            if (field_type.structureIndex()) |nested| try self.validateStructureCycle(nested, states);
        }
        states[index] = .complete;
    }

    fn findAstStructure(self: *Analyzer, name: []const u8) ?Ast.Structure {
        for (self.program.structures) |structure| {
            if (std.mem.eql(u8, structure.name, name)) return structure;
        }
        return null;
    }

    pub fn structureIndex(self: *Analyzer, name: []const u8) ?usize {
        for (self.structures, 0..) |structure, index| {
            if (std.mem.eql(u8, structure.name, name)) return index;
        }
        return null;
    }

    pub fn typeName(self: *Analyzer, type_value: Types.Type) []const u8 {
        if (type_value.optionalChild()) |child| {
            return std.fmt.allocPrint(self.allocator, "{s}?", .{self.typeName(child)}) catch "optional";
        }
        if (type_value.structureIndex()) |index| {
            if (index < self.structures.len) return self.structures[index].name;
        }
        return type_value.name();
    }

    fn isComparable(self: *Analyzer, type_value: Types.Type) bool {
        if (type_value.optionalChild()) |child| return self.isComparable(child);
        if (type_value.structureIndex()) |index| {
            for (self.structures[index].fields) |field| {
                if (!self.isComparable(field.type)) return false;
            }
            return true;
        }
        return type_value != .void;
    }

    fn analyzeFieldAccess(self: *Analyzer, builder: *FunctionBuilder, access: Ast.Expression.FieldAccess) AnalyzeError!TypedValue {
        const base = try self.analyzeExpression(builder, access.base);
        if (access.safe) return self.analyzeSafeFieldAccess(builder, access, base);
        return self.analyzeFieldValue(builder, access, base);
    }

    fn analyzeSafeFieldAccess(
        self: *Analyzer,
        builder: *FunctionBuilder,
        access: Ast.Expression.FieldAccess,
        optional_base: TypedValue,
    ) AnalyzeError!TypedValue {
        if (optional_base.type.optionalChild() == null) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "safe access '?.' requires an optional receiver, found '{s}'",
                .{self.typeName(optional_base.type)},
            );
            return self.fail(access.name_position, message);
        }
        const presence = try Optionals.emitPresence(self, builder, optional_base);
        const present_block = try self.newBlock(builder);
        const absent_block = try self.newBlock(builder);
        const merge_block = try self.newBlock(builder);
        self.terminate(builder, .{ .branch = .{
            .condition = presence.value,
            .then_block = present_block,
            .else_block = absent_block,
        } });

        builder.current_block = present_block;
        const base = try Optionals.unwrap(self, builder, optional_base);
        const field = try self.analyzeFieldValue(builder, access, base);
        const result = if (field.type.optionalChild() != null)
            field
        else
            (try Optionals.promote(self, builder, field, .optional(field.type))).?;
        self.terminate(builder, .{ .jump = merge_block });

        builder.current_block = absent_block;
        try self.emit(builder, .{ .optional_null = .{ .result = result.value } });
        self.terminate(builder, .{ .jump = merge_block });
        builder.current_block = merge_block;
        return result;
    }

    fn analyzeFieldValue(
        self: *Analyzer,
        builder: *FunctionBuilder,
        access: Ast.Expression.FieldAccess,
        base: TypedValue,
    ) AnalyzeError!TypedValue {
        const structure_index = base.type.structureIndex() orelse {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no fields", .{self.typeName(base.type)});
            return self.fail(access.name_position, message);
        };
        const structure = self.structures[structure_index];
        const declaration = self.findAstStructure(structure.name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "type '{s}' has no fields", .{self.typeName(base.type)});
            return self.fail(access.name_position, message);
        };
        if (declaration.is_internal and access.name_position.file != declaration.position.file) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "members of internal structure '{s}' are unavailable outside its source file",
                .{structure.name},
            );
            return self.fail(access.name_position, message);
        }
        for (structure.fields, 0..) |field, field_index| {
            if (!std.mem.eql(u8, field.name, access.name)) continue;
            const source_field = declaration.fields[field_index];
            if (!Support.memberVisible(access.name_position, source_field.position, source_field.is_internal)) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "field '{s}' is internal to its source file",
                    .{field.name},
                );
                return self.fail(access.name_position, message);
            }
            const result = try self.newValue(builder, field.type);
            try self.emit(builder, .{ .field_load = .{ .result = result, .base = base.value, .field = field_index } });
            return .{ .type = field.type, .value = result };
        }
        const message = try std.fmt.allocPrint(
            self.allocator,
            "structure '{s}' has no field named '{s}'",
            .{ structure.name, access.name },
        );
        return self.fail(access.name_position, message);
    }

    fn analyzeStructureInitializer(
        self: *Analyzer,
        builder: *FunctionBuilder,
        call: Ast.Expression.Call,
        structure_index: usize,
    ) AnalyzeError!TypedValue {
        const structure = self.structures[structure_index];
        const declaration = self.findAstStructure(structure.name).?;
        if (declaration.constructors.len != 0) {
            return Constructors.analyzeCall(self, builder, structure_index, declaration, call);
        }
        if (call.arguments.len != 0) {
            const message = try std.fmt.allocPrint(self.allocator, "structure '{s}' uses named fields", .{structure.name});
            return self.fail(call.name_position, message);
        }
        for (call.named_arguments, 0..) |argument, index| {
            for (call.named_arguments[0..index]) |previous| {
                if (std.mem.eql(u8, argument.name, previous.name)) {
                    const message = try std.fmt.allocPrint(self.allocator, "field '{s}' is provided more than once", .{argument.name});
                    return self.fail(argument.position, message);
                }
            }
            var known = false;
            for (structure.fields, 0..) |field, field_index| if (std.mem.eql(u8, field.name, argument.name)) {
                const source_field = declaration.fields[field_index];
                if (!Support.memberVisible(argument.position, source_field.position, source_field.is_internal)) {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "field '{s}' is internal to its source file",
                        .{field.name},
                    );
                    return self.fail(argument.position, message);
                }
                known = true;
                break;
            };
            if (!known) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "structure '{s}' has no field named '{s}'",
                    .{ structure.name, argument.name },
                );
                return self.fail(argument.position, message);
            }
        }

        var field_values: std.ArrayList(Ir.ValueId) = .empty;
        for (declaration.fields) |field| {
            var provided: ?*Ast.Expression = null;
            for (call.named_arguments) |argument| {
                if (std.mem.eql(u8, field.name, argument.name)) provided = argument.value;
            }
            var value = if (provided orelse field.default) |expression|
                try self.analyzeExpressionExpected(
                    builder,
                    expression,
                    Optionals.expectedContext(field.type, expression),
                )
            else
                try self.emitIntrinsic(builder, field.type, call.name_position);
            if (value.type != field.type and (Numeric.canWiden(value.type, field.type) or Optionals.canConvert(value.type, field.type))) {
                value = try self.coerce(builder, value, field.type, if (provided) |expression| expression.position else call.name_position);
            }
            if (value.type != field.type) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "field '{s}' of '{s}' expects '{s}', found '{s}'",
                    .{ field.name, structure.name, self.typeName(field.type), self.typeName(value.type) },
                );
                return self.fail(if (provided) |expression| expression.position else call.name_position, message);
            }
            try field_values.append(self.allocator, value.value);
        }
        const result_type = Types.Type.structure(structure_index);
        const result = try self.newValue(builder, result_type);
        try self.emit(builder, .{ .structure_init = .{
            .result = result,
            .structure = structure_index,
            .fields = try field_values.toOwnedSlice(self.allocator),
        } });
        return .{ .type = result_type, .value = result };
    }

    pub fn emitIntrinsic(self: *Analyzer, builder: *FunctionBuilder, type_value: Types.Type, position: Source.Position) AnalyzeError!TypedValue {
        if (try Optionals.intrinsic(self, builder, type_value)) |value| return value;
        return switch (type_value) {
            .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint => self.emitInteger(builder, 0, type_value),
            .bool => self.emitBool(builder, false),
            .float32 => self.emitFloat32(builder, 0.0),
            .float64 => self.emitFloat64(builder, 0.0),
            .str => self.emitString(builder, ""),
            else => if (type_value.structureIndex()) |structure_index|
                self.analyzeStructureInitializer(builder, .{
                    .name = self.structures[structure_index].name,
                    .name_position = position,
                    .arguments = &.{},
                }, structure_index)
            else
                self.fail(position, "this type has no intrinsic value"),
        };
    }

    fn analyzeCall(self: *Analyzer, builder: *FunctionBuilder, call: Ast.Expression.Call) AnalyzeError!?TypedValue {
        if (call.receiver) |receiver_expression| {
            if (receiver_expression.value == .identifier) {
                if (Enums.find(self, receiver_expression.value.identifier)) |enum_index| {
                    return try Enums.analyzeInitializer(self, builder, call, enum_index);
                }
            }
            return Methods.analyzeCall(self, builder, call);
        }
        if (self.structureIndex(call.name)) |structure_index| {
            return try self.analyzeStructureInitializer(builder, call, structure_index);
        }
        if (call.named_arguments.len != 0) {
            return self.fail(call.name_position, "named fields require a structure initializer");
        }
        if (std.mem.endsWith(u8, call.name, ".count") and call.arguments.len == 0) {
            const receiver_name = call.name[0 .. call.name.len - ".count".len];
            if (Support.findBinding(builder.bindings.items, receiver_name)) |binding| {
                if (binding.type != .str) return self.fail(call.name_position, "count() expects 'str'");
                const value = if (binding.local) |local| load: {
                    const result = try self.newValue(builder, binding.type);
                    try self.emit(builder, .{ .local_load = .{ .result = result, .local = local } });
                    break :load result;
                } else binding.value.?;
                return try self.emitStringCount(builder, value);
            }
        }
        var total_named: usize = 0;
        var named_count: usize = 0;
        var arity_count: usize = 0;
        for (self.program.functions) |function| {
            if (!std.mem.eql(u8, function.name, call.name)) continue;
            total_named += 1;
            if (!Support.functionVisible(call, function)) continue;
            named_count += 1;
            if (Support.acceptsArity(function.parameters, call.arguments.len)) arity_count += 1;
        }
        if (total_named == 0) {
            const message = try std.fmt.allocPrint(self.allocator, "unknown function '{s}'", .{call.name});
            return self.fail(call.name_position, message);
        }
        if (named_count == 0) {
            var has_internal = false;
            for (self.program.functions) |function| {
                if (std.mem.eql(u8, function.name, call.name) and function.is_internal) has_internal = true;
            }
            const message = if (has_internal)
                try std.fmt.allocPrint(self.allocator, "function '{s}' is internal to its source file", .{call.name})
            else
                try std.fmt.allocPrint(self.allocator, "function '{s}' is private outside its package", .{call.name});
            return self.fail(call.name_position, message);
        }
        if (arity_count == 0) {
            const message = if (named_count == 1) single: {
                const function = Support.findVisibleFunctionByName(self.program, call).?;
                const required = Support.requiredParameterCount(function.parameters);
                break :single if (required == function.parameters.len)
                    try std.fmt.allocPrint(
                        self.allocator,
                        "function '{s}' expects {d} arguments, found {d}",
                        .{ call.name, function.parameters.len, call.arguments.len },
                    )
                else
                    try std.fmt.allocPrint(
                        self.allocator,
                        "function '{s}' expects between {d} and {d} arguments, found {d}",
                        .{ call.name, required, function.parameters.len, call.arguments.len },
                    );
            } else try std.fmt.allocPrint(
                self.allocator,
                "no overload of function '{s}' accepts {d} arguments",
                .{ call.name, call.arguments.len },
            );
            return self.fail(call.name_position, message);
        }

        var sole_candidate: ?Ir.FunctionId = null;
        if (arity_count == 1) {
            for (self.program.functions, 0..) |function, function_id| {
                if (std.mem.eql(u8, function.name, call.name) and Support.acceptsArity(function.parameters, call.arguments.len) and
                    Support.functionVisible(call, function))
                {
                    sole_candidate = function_id;
                    break;
                }
            }
        }

        var arguments: std.ArrayList(TypedValue) = .empty;
        for (call.arguments, 0..) |argument, index| {
            const expected = if (sole_candidate) |candidate| expected: {
                const parameter_type = self.program.functions[candidate].parameters[index].type;
                break :expected Optionals.expectedContext(parameter_type, argument);
            } else null;
            try arguments.append(self.allocator, try self.analyzeExpressionExpected(builder, argument, expected));
        }

        var resolved: ?Ir.FunctionId = sole_candidate;
        var ambiguous = false;
        if (sole_candidate == null) {
            var viable: std.ArrayList(Ir.FunctionId) = .empty;
            for (self.program.functions, 0..) |function, function_id| {
                if (!std.mem.eql(u8, function.name, call.name) or !Support.acceptsArity(function.parameters, arguments.items.len)) continue;
                if (!Support.functionVisible(call, function)) continue;
                var matches = true;
                for (function.parameters[0..arguments.items.len], arguments.items) |parameter, argument| {
                    if (conversionCost(argument.type, parameter.type) == null) {
                        matches = false;
                        break;
                    }
                }
                if (matches) try viable.append(self.allocator, function_id);
            }

            var nondominated: usize = 0;
            for (viable.items) |candidate_id| {
                var dominated = false;
                for (viable.items) |other_id| {
                    if (candidate_id == other_id) continue;
                    if (dominates(
                        self.program.functions[other_id].parameters[0..arguments.items.len],
                        self.program.functions[candidate_id].parameters[0..arguments.items.len],
                        arguments.items,
                    )) {
                        dominated = true;
                        break;
                    }
                }
                if (!dominated) {
                    resolved = candidate_id;
                    nondominated += 1;
                }
            }
            ambiguous = nondominated > 1;
        }

        if (ambiguous) {
            const message = try std.fmt.allocPrint(self.allocator, "call to '{s}' is ambiguous", .{call.name});
            return self.fail(call.name_position, message);
        }

        const function_id = resolved orelse {
            if (arity_count == 1) {
                for (self.program.functions) |function| {
                    if (!std.mem.eql(u8, function.name, call.name) or !Support.acceptsArity(function.parameters, arguments.items.len)) continue;
                    if (!Support.functionVisible(call, function)) continue;
                    for (function.parameters[0..arguments.items.len], arguments.items, 0..) |parameter, argument, index| {
                        if (parameter.type == argument.type) continue;
                        const message = try std.fmt.allocPrint(
                            self.allocator,
                            "argument {d} of '{s}' expects '{s}', found '{s}'",
                            .{ index + 1, call.name, self.typeName(parameter.type), self.typeName(argument.type) },
                        );
                        return self.fail(call.arguments[index].position, message);
                    }
                }
            }
            const message = try std.fmt.allocPrint(
                self.allocator,
                "no overload of function '{s}' matches the argument types",
                .{call.name},
            );
            return self.fail(call.name_position, message);
        };
        const function = self.program.functions[function_id];
        var argument_ids: std.ArrayList(Ir.ValueId) = .empty;
        for (arguments.items, function.parameters[0..arguments.items.len], 0..) |argument, parameter, index| {
            if (argument.type != parameter.type and !Numeric.canWiden(argument.type, parameter.type) and !Optionals.canConvert(argument.type, parameter.type)) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "argument {d} of '{s}' expects '{s}', found '{s}'",
                    .{ index + 1, call.name, self.typeName(parameter.type), self.typeName(argument.type) },
                );
                return self.fail(call.arguments[index].position, message);
            }
            const converted = try self.coerce(builder, argument, parameter.type, call.name_position);
            try argument_ids.append(self.allocator, converted.value);
        }
        for (function.parameters[arguments.items.len..]) |parameter| {
            const value = try self.analyzeParameterDefault(builder, parameter);
            try argument_ids.append(self.allocator, value.value);
        }
        const result: ?Ir.ValueId = if (function.return_type == .void)
            null
        else result: {
            if (!function.return_type.hasRuntimeValue()) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "values of type '{s}' are not executable yet",
                    .{self.typeName(function.return_type)},
                );
                return self.fail(call.name_position, message);
            }
            break :result try self.newValue(builder, function.return_type);
        };
        try self.emit(builder, .{ .call = .{
            .result = result,
            .function = function_id,
            .arguments = try argument_ids.toOwnedSlice(self.allocator),
        } });
        return if (result) |value| .{ .type = function.return_type, .value = value } else null;
    }

    fn emitInteger(self: *Analyzer, builder: *FunctionBuilder, bits: u64, type_value: Types.Type) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, type_value);
        try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = Numeric.normalize(bits, type_value) } });
        return .{ .type = type_value, .value = result };
    }

    fn emitIntegerLiteral(
        self: *Analyzer,
        builder: *FunctionBuilder,
        lexeme: []const u8,
        negative: bool,
        target: Types.Type,
        position: Source.Position,
    ) AnalyzeError!TypedValue {
        const magnitude = try self.parseIntegerMagnitude(lexeme, position);
        if (!Numeric.fitsMagnitude(magnitude, negative, target)) {
            const message = try std.fmt.allocPrint(self.allocator, "integer literal is outside the range of '{s}'", .{target.name()});
            return self.fail(position, message);
        }
        return self.emitInteger(builder, Numeric.fromMagnitude(magnitude, negative, target).bits, target);
    }

    fn emitFloatingLiteral(
        self: *Analyzer,
        builder: *FunctionBuilder,
        lexeme: []const u8,
        target: Types.Type,
        position: Source.Position,
    ) AnalyzeError!TypedValue {
        const normalized = try Support.removeSeparators(self.allocator, lexeme);
        return switch (target) {
            .float32 => self.emitFloat32(builder, std.fmt.parseFloat(f32, normalized) catch
                return self.fail(position, "floating literal is outside the range of 'float'")),
            .float64 => self.emitFloat64(builder, std.fmt.parseFloat(f64, normalized) catch
                return self.fail(position, "floating literal is outside the range of 'float64'")),
            else => unreachable,
        };
    }

    fn emitFloat32(self: *Analyzer, builder: *FunctionBuilder, value: f32) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .float32);
        try self.emit(builder, .{ .constant_float32 = .{ .result = result, .bits = @bitCast(value) } });
        return .{ .type = .float32, .value = result };
    }

    fn emitFloat64(self: *Analyzer, builder: *FunctionBuilder, value: f64) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .float64);
        try self.emit(builder, .{ .constant_float64 = .{ .result = result, .bits = @bitCast(value) } });
        return .{ .type = .float64, .value = result };
    }

    fn emitBool(self: *Analyzer, builder: *FunctionBuilder, value: bool) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .bool);
        try self.emit(builder, .{ .constant_bool = .{ .result = result, .value = value } });
        return .{ .type = .bool, .value = result };
    }

    fn emitString(self: *Analyzer, builder: *FunctionBuilder, value: []const u8) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .str);
        try self.emit(builder, .{ .constant_str = .{ .result = result, .value = value } });
        return .{ .type = .str, .value = result };
    }

    fn analyzePrint(self: *Analyzer, builder: *FunctionBuilder, statement: Ast.PrintStatement) AnalyzeError!void {
        const values = try self.allocator.alloc(TypedValue, statement.values.len);
        for (statement.values, 0..) |expression, index| {
            const value = try self.analyzeExpression(builder, expression);
            if (value.type != .str and !value.type.isNumeric() and value.type != .bool) {
                return self.fail(expression.position, "print expects 'str', a numeric value, or 'bool'");
            }
            values[index] = value;
        }
        for (values, 0..) |value, index| {
            try self.emit(builder, .{ .print = .{ .value = value.value, .newline = index + 1 == values.len } });
        }
    }

    fn analyzeInterpolatedString(
        self: *Analyzer,
        builder: *FunctionBuilder,
        interpolated: Ast.Expression.InterpolatedString,
    ) AnalyzeError!TypedValue {
        var result = try self.emitString(builder, "");
        for (interpolated.parts) |part| {
            const text: TypedValue = switch (part) {
                .text => |value| try self.emitString(builder, value),
                .expression => |expression| value: {
                    const value = try self.analyzeExpression(builder, expression);
                    if (value.type != .str and !value.type.isNumeric() and value.type != .bool) {
                        return self.fail(expression.position, "string interpolation expects 'str', a numeric value, or 'bool'");
                    }
                    if (value.type == .str) break :value value;
                    const formatted = try self.newValue(builder, .str);
                    try self.emit(builder, .{ .format_value = .{ .result = formatted, .operand = value.value } });
                    break :value .{ .type = .str, .value = formatted };
                },
            };
            const combined = try self.newValue(builder, .str);
            try self.emit(builder, .{ .string_concat = .{
                .result = combined,
                .left = result.value,
                .right = text.value,
            } });
            result = .{ .type = .str, .value = combined };
        }
        return result;
    }

    fn analyzeAssert(self: *Analyzer, builder: *FunctionBuilder, statement: Ast.AssertStatement) AnalyzeError!void {
        const condition = try self.analyzeExpression(builder, statement.condition);
        const message = try self.analyzeExpression(builder, statement.message);
        if (condition.type != .bool) return self.fail(statement.condition.position, "assert condition expects 'bool'");
        if (message.type != .str) return self.fail(statement.message.position, "assert message expects 'str'");
        try self.emit(builder, .{ .assert = .{
            .condition = condition.value,
            .message = message.value,
            .position = statement.position,
        } });
    }

    fn analyzePanic(self: *Analyzer, builder: *FunctionBuilder, statement: Ast.EffectStatement) AnalyzeError!void {
        const message = try self.analyzeExpression(builder, statement.value);
        if (message.type != .str) return self.fail(statement.value.position, "panic message expects 'str'");
        self.terminate(builder, .{ .panic = .{ .message = message.value, .position = statement.position } });
    }

    fn analyzeStringCount(self: *Analyzer, builder: *FunctionBuilder, operand: *const Ast.Expression) AnalyzeError!TypedValue {
        const value = try self.analyzeExpression(builder, operand);
        if (value.type != .str) return self.fail(operand.position, "count() expects 'str'");
        return self.emitStringCount(builder, value.value);
    }

    pub fn emitStringCount(self: *Analyzer, builder: *FunctionBuilder, operand: Ir.ValueId) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .int);
        try self.emit(builder, .{ .string_count = .{ .result = result, .operand = operand } });
        return .{ .type = .int, .value = result };
    }

    pub fn emit(self: *Analyzer, builder: *FunctionBuilder, instruction: Ir.Instruction) Allocator.Error!void {
        try builder.blocks.items[builder.current_block].instructions.append(self.allocator, instruction);
    }

    pub fn terminate(_: *Analyzer, builder: *FunctionBuilder, terminator: Ir.Terminator) void {
        std.debug.assert(builder.blocks.items[builder.current_block].terminator == null);
        builder.blocks.items[builder.current_block].terminator = terminator;
    }

    pub fn newBlock(self: *Analyzer, builder: *FunctionBuilder) Allocator.Error!Ir.BlockId {
        const block = builder.blocks.items.len;
        try builder.blocks.append(self.allocator, .{});
        return block;
    }

    fn analyzeConversion(
        self: *Analyzer,
        builder: *FunctionBuilder,
        conversion: Ast.Expression.Conversion,
    ) AnalyzeError!TypedValue {
        const operand = try self.analyzeExpression(builder, conversion.operand);
        if (!operand.type.isNumeric() or !conversion.target.isNumeric()) {
            return self.fail(conversion.operator_position, "'as' requires numeric source and target types");
        }
        return self.emitConversion(builder, operand, conversion.target, conversion.operator_position, true);
    }

    pub fn coerce(
        self: *Analyzer,
        builder: *FunctionBuilder,
        value: TypedValue,
        target: Types.Type,
        position: Source.Position,
    ) AnalyzeError!TypedValue {
        if (value.type == target) return value;
        if (try Optionals.promote(self, builder, value, target)) |promoted| return promoted;
        if (!Numeric.canWiden(value.type, target)) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "cannot implicitly convert '{s}' to '{s}'",
                .{ self.typeName(value.type), self.typeName(target) },
            );
            return self.fail(position, message);
        }
        return self.emitConversion(builder, value, target, position, false);
    }

    fn emitConversion(
        self: *Analyzer,
        builder: *FunctionBuilder,
        value: TypedValue,
        target: Types.Type,
        position: Source.Position,
        checked: bool,
    ) AnalyzeError!TypedValue {
        if (value.type == target) return value;
        const result = try self.newValue(builder, target);
        try self.emit(builder, .{ .convert = .{
            .result = result,
            .operand = value.value,
            .source = value.type,
            .target = target,
            .position = position,
            .checked = checked,
        } });
        return .{ .type = target, .value = result };
    }

    pub fn newValue(self: *Analyzer, builder: *FunctionBuilder, type_value: Types.Type) Allocator.Error!Ir.ValueId {
        const result = builder.value_types.items.len;
        try builder.value_types.append(self.allocator, type_value);
        return result;
    }

    fn parseIntegerMagnitude(self: *Analyzer, lexeme: []const u8, position: Source.Position) AnalyzeError!u64 {
        const literal = try Support.removeSeparators(self.allocator, lexeme);
        const base: u8 = if (literal.len > 2 and literal[0] == '0') switch (literal[1]) {
            'b', 'B' => 2,
            'o', 'O' => 8,
            'x', 'X' => 16,
            else => 10,
        } else 10;
        const digits = if (base == 10) literal else literal[2..];
        return std.fmt.parseInt(u64, digits, base) catch self.fail(position, "integer literal is outside the range of 'uint'");
    }

    pub fn fail(self: *Analyzer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn restrictedFieldDefault(self: *Analyzer, expression: *const Ast.Expression) bool {
    return switch (expression.value) {
        .integer, .floating, .boolean, .null_value, .string => true,
        .unary => |unary| unary.operator == .negate and switch (unary.operand.value) {
            .integer, .floating => true,
            else => false,
        },
        .call => |call| call.arguments.len == 0 and self.structureIndex(call.name) != null and blk: {
            for (call.named_arguments) |argument| {
                if (!restrictedFieldDefault(self, argument.value)) break :blk false;
            }
            break :blk true;
        },
        else => false,
    };
}

fn conversionCost(source: Types.Type, target: Types.Type) ?u8 {
    if (source == target) return 0;
    if (Optionals.conversionCost(source, target)) |cost| return cost;
    if (!Numeric.canWiden(source, target)) return null;
    return if (source.isInteger() and target.isFloat()) 2 else 1;
}

fn dominates(better: []const Ast.Parameter, worse: []const Ast.Parameter, arguments: []const TypedValue) bool {
    var strictly_better = false;
    for (better, worse, arguments) |better_parameter, worse_parameter, argument| {
        const better_cost = conversionCost(argument.type, better_parameter.type) orelse return false;
        const worse_cost = conversionCost(argument.type, worse_parameter.type) orelse return false;
        if (better_cost > worse_cost) return false;
        if (better_cost < worse_cost) strictly_better = true;
    }
    return strictly_better;
}
