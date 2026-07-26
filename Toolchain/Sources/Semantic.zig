const std = @import("std");
const Ast = @import("Ast.zig");
const Ir = @import("Ir.zig");
const Numeric = @import("Numeric.zig");
const Source = @import("Source.zig");
const Support = @import("SemanticSupport.zig");
const Types = @import("Types.zig");

const Allocator = std.mem.Allocator;
const AnalyzeError = Source.Error || Allocator.Error;

const Binding = struct {
    name: []const u8,
    type: Types.Type,
    value: Ir.ValueId,
};

const TypedValue = struct {
    type: Types.Type,
    value: Ir.ValueId,
};

const BlockBuilder = struct {
    instructions: std.ArrayList(Ir.Instruction) = .empty,
    terminator: ?Ir.Terminator = null,
};

const FunctionBuilder = struct {
    value_types: std.ArrayList(Types.Type) = .empty,
    blocks: std.ArrayList(BlockBuilder) = .empty,
    current_block: Ir.BlockId = 0,
    bindings: std.ArrayList(Binding) = .empty,
};

pub const Analyzer = struct {
    allocator: Allocator,
    program: Ast.Program = undefined,
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
        try self.validateDeclarations(require_entry);

        var functions: std.ArrayList(Ir.Function) = .empty;
        for (program.functions, 0..) |function, function_id| {
            try functions.append(self.allocator, try self.analyzeFunction(function_id, function));
        }
        return .{ .functions = try functions.toOwnedSlice(self.allocator) };
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
                if (!Support.sameParameterTypes(function.parameters, previous.parameters)) continue;
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "function '{s}' with these parameter types is already declared",
                    .{function.name},
                );
                return self.fail(function.name_position, message);
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
            });
        }

        const ends_with_return = try self.analyzeStatements(&builder, function, function.statements);
        if (function.return_type == .void) {
            if (!ends_with_return) self.terminate(&builder, .return_void);
        } else if (!ends_with_return) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "function '{s}' must return '{s}' on every path",
                .{ function.name, function.return_type.name() },
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
            .blocks = owned_blocks,
        };
    }

    fn analyzeStatements(self: *Analyzer, builder: *FunctionBuilder, function: Ast.Function, statements: []const Ast.Statement) AnalyzeError!bool {
        for (statements) |statement| {
            if (try self.analyzeStatement(builder, function, statement)) return true;
        }
        return false;
    }

    fn analyzeStatement(self: *Analyzer, builder: *FunctionBuilder, function: Ast.Function, statement: Ast.Statement) AnalyzeError!bool {
        return switch (statement) {
            .variable_declaration => |declaration| variable: {
                try self.analyzeVariable(builder, declaration);
                break :variable false;
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
            .if_statement => |conditional| self.analyzeIf(builder, function, conditional),
        };
    }

    fn analyzeVariable(self: *Analyzer, builder: *FunctionBuilder, declaration: Ast.VariableDeclaration) AnalyzeError!void {
        if (findBinding(builder.bindings.items, declaration.name) != null) {
            const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{declaration.name});
            return self.fail(declaration.name_position, message);
        }

        var initializer: TypedValue = if (declaration.initializer) |expression|
            try self.analyzeExpressionExpected(
                builder,
                expression,
                if (declaration.annotation != null and declaration.annotation.?.isNumeric() and Support.acceptsNumericContext(expression))
                    declaration.annotation
                else
                    null,
            )
        else intrinsic: {
            const annotation = declaration.annotation.?;
            break :intrinsic switch (annotation) {
                .int8, .int16, .int32, .int, .uint8, .uint16, .uint32, .uint => try self.emitInteger(builder, 0, annotation),
                .bool => try self.emitBool(builder, false),
                .float32 => try self.emitFloat32(builder, 0.0),
                .float64 => try self.emitFloat64(builder, 0.0),
                .str => try self.emitString(builder, ""),
                else => {
                    const message = try std.fmt.allocPrint(
                        self.allocator,
                        "intrinsic values of type '{s}' are not executable yet",
                        .{annotation.name()},
                    );
                    return self.fail(declaration.name_position, message);
                },
            };
        };
        const declared_type = declaration.annotation orelse initializer.type;
        if (initializer.type != declared_type and Numeric.canWiden(initializer.type, declared_type)) {
            initializer = try self.coerce(builder, initializer, declared_type, declaration.initializer.?.position);
        }
        if (initializer.type != declared_type) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "variable '{s}' expects '{s}', found '{s}'",
                .{ declaration.name, declared_type.name(), initializer.type.name() },
            );
            return self.fail(if (declaration.initializer) |value| value.position else declaration.name_position, message);
        }
        try builder.bindings.append(self.allocator, .{
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
                if (function.return_type.isNumeric() and Support.acceptsNumericContext(expression)) function.return_type else null,
            );
            if (value.type != function.return_type and Numeric.canWiden(value.type, function.return_type)) {
                value = try self.coerce(builder, value, function.return_type, expression.position);
            }
            if (value.type != function.return_type) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "return expects '{s}', found '{s}'",
                    .{ function.return_type.name(), value.type.name() },
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
                .{function.return_type.name()},
            );
            return self.fail(statement.position, message);
        }
        self.terminate(builder, .return_void);
    }

    fn analyzeExpression(self: *Analyzer, builder: *FunctionBuilder, expression: *const Ast.Expression) AnalyzeError!TypedValue {
        return self.analyzeExpressionExpected(builder, expression, null);
    }

    fn analyzeExpressionExpected(
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
            .string => |value| self.emitString(builder, value),
            .interpolated_string => |value| self.analyzeInterpolatedString(builder, value),
            .identifier => |name| self.analyzeIdentifier(builder, expression.position, name),
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
        const binding = findBinding(builder.bindings.items, name) orelse {
            const message = try std.fmt.allocPrint(self.allocator, "unknown variable '{s}'", .{name});
            return self.fail(position, message);
        };
        if (!binding.type.hasRuntimeValue()) {
            const message = try std.fmt.allocPrint(self.allocator, "values of type '{s}' are not executable yet", .{binding.type.name()});
            return self.fail(position, message);
        }
        return .{ .type = binding.type, .value = binding.value };
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
        const left_hint = if (expected != null and expected.?.isNumeric() and Support.isNumericLiteral(binary.left)) expected else null;
        var left = try self.analyzeExpressionExpected(builder, binary.left, left_hint);
        const right_hint = if (Support.isNumericLiteral(binary.right))
            (if (expected != null and expected.?.isNumeric()) expected else if (left.type.isNumeric()) left.type else null)
        else
            null;
        var right = try self.analyzeExpressionExpected(builder, binary.right, right_hint);
        if (binary.operator == .add and left.type == .str and right.type == .str) {
            const result = try self.newValue(builder, .str);
            try self.emit(builder, .{ .string_concat = .{
                .result = result,
                .left = left.value,
                .right = right.value,
            } });
            return .{ .type = .str, .value = result };
        }
        const equality = binary.operator == .equal or binary.operator == .not_equal;
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
            same_numeric or (left.type == right.type and (left.type == .bool or left.type == .str))
        else
            same_numeric and (!left.type.isFloat() or binary.operator != .remainder);
        if (!valid) {
            const message = if (!equality)
                try std.fmt.allocPrint(
                    self.allocator,
                    "operator '{s}' does not accept '{s}' and '{s}'",
                    .{ Support.binaryOperatorText(binary.operator), left.type.name(), right.type.name() },
                )
            else
                try std.fmt.allocPrint(
                    self.allocator,
                    "operator '{s}' does not accept '{s}' and '{s}'",
                    .{ Support.binaryOperatorText(binary.operator), left.type.name(), right.type.name() },
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

    fn analyzeIf(
        self: *Analyzer,
        builder: *FunctionBuilder,
        function: Ast.Function,
        conditional: Ast.IfStatement,
    ) AnalyzeError!bool {
        var exits: std.ArrayList(Ir.BlockId) = .empty;
        for (conditional.branches) |branch| {
            const condition = try self.analyzeExpression(builder, branch.condition);
            if (condition.type != .bool) return self.fail(branch.condition.position, "if condition expects 'bool'");

            const body_block = try self.newBlock(builder);
            const next_block = try self.newBlock(builder);
            self.terminate(builder, .{ .branch = .{
                .condition = condition.value,
                .then_block = body_block,
                .else_block = next_block,
            } });

            builder.current_block = body_block;
            const binding_count = builder.bindings.items.len;
            const terminated = try self.analyzeStatements(builder, function, branch.statements);
            builder.bindings.shrinkRetainingCapacity(binding_count);
            if (!terminated) try exits.append(self.allocator, builder.current_block);
            builder.current_block = next_block;
        }

        if (conditional.else_statements) |statements| {
            const binding_count = builder.bindings.items.len;
            const terminated = try self.analyzeStatements(builder, function, statements);
            builder.bindings.shrinkRetainingCapacity(binding_count);
            if (!terminated) try exits.append(self.allocator, builder.current_block);
        } else {
            try exits.append(self.allocator, builder.current_block);
        }

        if (exits.items.len == 0) return true;
        const merge_block = try self.newBlock(builder);
        for (exits.items) |block_id| {
            builder.blocks.items[block_id].terminator = .{ .jump = merge_block };
        }
        builder.current_block = merge_block;
        return false;
    }

    fn analyzeCall(self: *Analyzer, builder: *FunctionBuilder, call: Ast.Expression.Call) AnalyzeError!?TypedValue {
        if (std.mem.endsWith(u8, call.name, ".count") and call.arguments.len == 0) {
            const receiver_name = call.name[0 .. call.name.len - ".count".len];
            if (findBinding(builder.bindings.items, receiver_name)) |binding| {
                if (binding.type != .str) return self.fail(call.name_position, "count() expects 'str'");
                return try self.emitStringCount(builder, binding.value);
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
            if (function.parameters.len == call.arguments.len) arity_count += 1;
        }
        if (total_named == 0) {
            const message = try std.fmt.allocPrint(self.allocator, "unknown function '{s}'", .{call.name});
            return self.fail(call.name_position, message);
        }
        if (named_count == 0) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "function '{s}' is private outside its package",
                .{call.name},
            );
            return self.fail(call.name_position, message);
        }
        if (arity_count == 0) {
            const message = if (named_count == 1) single: {
                const function = Support.findVisibleFunctionByName(self.program, call).?;
                break :single try std.fmt.allocPrint(
                    self.allocator,
                    "function '{s}' expects {d} arguments, found {d}",
                    .{ call.name, function.parameters.len, call.arguments.len },
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
                if (std.mem.eql(u8, function.name, call.name) and function.parameters.len == call.arguments.len and
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
                break :expected if (parameter_type.isNumeric() and Support.acceptsNumericContext(argument)) parameter_type else null;
            } else null;
            try arguments.append(self.allocator, try self.analyzeExpressionExpected(builder, argument, expected));
        }

        var resolved: ?Ir.FunctionId = sole_candidate;
        var ambiguous = false;
        if (sole_candidate == null) {
            var viable: std.ArrayList(Ir.FunctionId) = .empty;
            for (self.program.functions, 0..) |function, function_id| {
                if (!std.mem.eql(u8, function.name, call.name) or function.parameters.len != arguments.items.len) continue;
                if (!Support.functionVisible(call, function)) continue;
                var matches = true;
                for (function.parameters, arguments.items) |parameter, argument| {
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
                        self.program.functions[other_id],
                        self.program.functions[candidate_id],
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
                    if (!std.mem.eql(u8, function.name, call.name) or function.parameters.len != arguments.items.len) continue;
                    if (!Support.functionVisible(call, function)) continue;
                    for (function.parameters, arguments.items, 0..) |parameter, argument, index| {
                        if (parameter.type == argument.type) continue;
                        const message = try std.fmt.allocPrint(
                            self.allocator,
                            "argument {d} of '{s}' expects '{s}', found '{s}'",
                            .{ index + 1, call.name, parameter.type.name(), argument.type.name() },
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
        for (arguments.items, function.parameters, 0..) |argument, parameter, index| {
            if (argument.type != parameter.type and !Numeric.canWiden(argument.type, parameter.type)) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "argument {d} of '{s}' expects '{s}', found '{s}'",
                    .{ index + 1, call.name, parameter.type.name(), argument.type.name() },
                );
                return self.fail(call.arguments[index].position, message);
            }
            const converted = try self.coerce(builder, argument, parameter.type, call.name_position);
            try argument_ids.append(self.allocator, converted.value);
        }
        const result: ?Ir.ValueId = if (function.return_type == .void)
            null
        else result: {
            if (!function.return_type.hasRuntimeValue()) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "values of type '{s}' are not executable yet",
                    .{function.return_type.name()},
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

    fn emitStringCount(self: *Analyzer, builder: *FunctionBuilder, operand: Ir.ValueId) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .int);
        try self.emit(builder, .{ .string_count = .{ .result = result, .operand = operand } });
        return .{ .type = .int, .value = result };
    }

    fn emit(self: *Analyzer, builder: *FunctionBuilder, instruction: Ir.Instruction) Allocator.Error!void {
        try builder.blocks.items[builder.current_block].instructions.append(self.allocator, instruction);
    }

    fn terminate(_: *Analyzer, builder: *FunctionBuilder, terminator: Ir.Terminator) void {
        std.debug.assert(builder.blocks.items[builder.current_block].terminator == null);
        builder.blocks.items[builder.current_block].terminator = terminator;
    }

    fn newBlock(self: *Analyzer, builder: *FunctionBuilder) Allocator.Error!Ir.BlockId {
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

    fn coerce(
        self: *Analyzer,
        builder: *FunctionBuilder,
        value: TypedValue,
        target: Types.Type,
        position: Source.Position,
    ) AnalyzeError!TypedValue {
        if (value.type == target) return value;
        if (!Numeric.canWiden(value.type, target)) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "cannot implicitly convert '{s}' to '{s}'",
                .{ value.type.name(), target.name() },
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

    fn newValue(self: *Analyzer, builder: *FunctionBuilder, type_value: Types.Type) Allocator.Error!Ir.ValueId {
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

    fn fail(self: *Analyzer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn findBinding(bindings: []const Binding, name: []const u8) ?Binding {
    var index = bindings.len;
    while (index != 0) {
        index -= 1;
        if (std.mem.eql(u8, bindings[index].name, name)) return bindings[index];
    }
    return null;
}

fn conversionCost(source: Types.Type, target: Types.Type) ?u8 {
    if (source == target) return 0;
    if (!Numeric.canWiden(source, target)) return null;
    return if (source.isInteger() and target.isFloat()) 2 else 1;
}

fn dominates(better: Ast.Function, worse: Ast.Function, arguments: []const TypedValue) bool {
    var strictly_better = false;
    for (better.parameters, worse.parameters, arguments) |better_parameter, worse_parameter, argument| {
        const better_cost = conversionCost(argument.type, better_parameter.type) orelse return false;
        const worse_cost = conversionCost(argument.type, worse_parameter.type) orelse return false;
        if (better_cost > worse_cost) return false;
        if (better_cost < worse_cost) strictly_better = true;
    }
    return strictly_better;
}
