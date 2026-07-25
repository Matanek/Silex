const std = @import("std");
const Ast = @import("Ast.zig");
const Ir = @import("Ir.zig");
const Source = @import("Source.zig");
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

const FunctionBuilder = struct {
    value_types: std.ArrayList(Types.Type) = .empty,
    instructions: std.ArrayList(Ir.Instruction) = .empty,
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
        self.program = program;
        self.diagnostic = null;
        try self.validateDeclarations();

        var functions: std.ArrayList(Ir.Function) = .empty;
        for (program.functions, 0..) |function, function_id| {
            try functions.append(self.allocator, try self.analyzeFunction(function_id, function));
        }
        return .{ .functions = try functions.toOwnedSlice(self.allocator) };
    }

    fn validateDeclarations(self: *Analyzer) AnalyzeError!void {
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
                if (!sameParameterTypes(function.parameters, previous.parameters)) continue;
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "function '{s}' with these parameter types is already declared",
                    .{function.name},
                );
                return self.fail(function.name_position, message);
            }
        }

        const entry = main orelse return self.fail(
            .{ .offset = 0, .line = 1, .column = 1 },
            "missing 'main' function",
        );
        if (entry.parameters.len != 0) return self.fail(entry.name_position, "'main' must have no parameters");
        if (entry.return_type != .void) return self.fail(entry.name_position, "'main' must return 'void'");
    }

    fn analyzeFunction(self: *Analyzer, function_id: Ir.FunctionId, function: Ast.Function) AnalyzeError!Ir.Function {
        _ = function_id;
        var builder: FunctionBuilder = .{};
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

        for (function.statements) |statement| try self.analyzeStatement(&builder, function, statement);

        const ends_with_return = if (function.statements.len == 0)
            false
        else switch (function.statements[function.statements.len - 1]) {
            .return_statement => true,
            else => false,
        };
        if (function.return_type == .void) {
            if (!ends_with_return) try builder.instructions.append(self.allocator, .return_void);
        } else if (!ends_with_return) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "function '{s}' must return '{s}' on every path",
                .{ function.name, function.return_type.name() },
            );
            return self.fail(function.name_position, message);
        }

        return .{
            .name = function.name,
            .parameter_types = try parameter_types.toOwnedSlice(self.allocator),
            .return_type = function.return_type,
            .value_types = try builder.value_types.toOwnedSlice(self.allocator),
            .instructions = try builder.instructions.toOwnedSlice(self.allocator),
        };
    }

    fn analyzeStatement(self: *Analyzer, builder: *FunctionBuilder, function: Ast.Function, statement: Ast.Statement) AnalyzeError!void {
        switch (statement) {
            .variable_declaration => |declaration| try self.analyzeVariable(builder, declaration),
            .return_statement => |return_statement| try self.analyzeReturn(builder, function, return_statement),
            .expression_statement => |expression| switch (expression.value) {
                .call => |call| {
                    _ = try self.analyzeCall(builder, call);
                },
                else => unreachable,
            },
        }
    }

    fn analyzeVariable(self: *Analyzer, builder: *FunctionBuilder, declaration: Ast.VariableDeclaration) AnalyzeError!void {
        if (findBinding(builder.bindings.items, declaration.name) != null) {
            const message = try std.fmt.allocPrint(self.allocator, "variable '{s}' is already declared in this scope", .{declaration.name});
            return self.fail(declaration.name_position, message);
        }

        const initializer: TypedValue = if (declaration.initializer) |expression|
            try self.analyzeExpression(builder, expression)
        else intrinsic: {
            const annotation = declaration.annotation.?;
            break :intrinsic switch (annotation) {
                .int => try self.emitInt(builder, 0),
                .bool => try self.emitBool(builder, false),
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
            const value = try self.analyzeExpression(builder, expression);
            if (value.type != function.return_type) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "return expects '{s}', found '{s}'",
                    .{ function.return_type.name(), value.type.name() },
                );
                return self.fail(expression.position, message);
            }
            try builder.instructions.append(self.allocator, .{ .return_value = value.value });
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
        try builder.instructions.append(self.allocator, .return_void);
    }

    fn analyzeExpression(self: *Analyzer, builder: *FunctionBuilder, expression: *const Ast.Expression) AnalyzeError!TypedValue {
        return switch (expression.value) {
            .integer => |lexeme| self.emitInt(builder, try self.parseInteger(lexeme, expression.position, false)),
            .boolean => |value| self.emitBool(builder, value),
            .identifier => |name| self.analyzeIdentifier(builder, expression.position, name),
            .call => |call| (try self.analyzeCall(builder, call)) orelse {
                const message = try std.fmt.allocPrint(self.allocator, "function '{s}' returns 'void' and cannot be used as a value", .{call.name});
                return self.fail(call.name_position, message);
            },
            .unary => |unary| self.analyzeUnary(builder, unary),
            .binary => |binary| self.analyzeBinary(builder, binary),
        };
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

    fn analyzeUnary(self: *Analyzer, builder: *FunctionBuilder, unary: Ast.Expression.Unary) AnalyzeError!TypedValue {
        switch (unary.operand.value) {
            .integer => |lexeme| {
                const value = try self.parseInteger(lexeme, unary.operand.position, true);
                return self.emitInt(builder, if (value == std.math.minInt(i64)) value else -value);
            },
            else => {},
        }

        const operand = try self.analyzeExpression(builder, unary.operand);
        if (operand.type != .int) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "operator '-' expects 'int', found '{s}'",
                .{operand.type.name()},
            );
            return self.fail(unary.operator_position, message);
        }
        const result = try self.newValue(builder, .int);
        try builder.instructions.append(self.allocator, .{ .unary = .{
            .result = result,
            .operator = .negate,
            .operand = operand.value,
        } });
        return .{ .type = .int, .value = result };
    }

    fn analyzeBinary(self: *Analyzer, builder: *FunctionBuilder, binary: Ast.Expression.Binary) AnalyzeError!TypedValue {
        const left = try self.analyzeExpression(builder, binary.left);
        const right = try self.analyzeExpression(builder, binary.right);
        if (left.type != .int or right.type != .int) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "operator '{s}' expects 'int' operands, found '{s}' and '{s}'",
                .{ binaryOperatorText(binary.operator), left.type.name(), right.type.name() },
            );
            return self.fail(binary.operator_position, message);
        }
        const result = try self.newValue(builder, .int);
        try builder.instructions.append(self.allocator, .{ .binary = .{
            .result = result,
            .operator = switch (binary.operator) {
                .add => .add,
                .subtract => .subtract,
                .multiply => .multiply,
                .divide => .divide,
                .remainder => .remainder,
            },
            .left = left.value,
            .right = right.value,
        } });
        return .{ .type = .int, .value = result };
    }

    fn analyzeCall(self: *Analyzer, builder: *FunctionBuilder, call: Ast.Expression.Call) AnalyzeError!?TypedValue {
        var total_named: usize = 0;
        var named_count: usize = 0;
        var arity_count: usize = 0;
        for (self.program.functions) |function| {
            if (!std.mem.eql(u8, function.name, call.name)) continue;
            total_named += 1;
            if (!functionVisible(call, function)) continue;
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
                const function = findVisibleFunctionByName(self.program, call).?;
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

        var arguments: std.ArrayList(TypedValue) = .empty;
        var argument_ids: std.ArrayList(Ir.ValueId) = .empty;
        for (call.arguments) |argument| {
            const value = try self.analyzeExpression(builder, argument);
            try arguments.append(self.allocator, value);
            try argument_ids.append(self.allocator, value.value);
        }

        var resolved: ?Ir.FunctionId = null;
        for (self.program.functions, 0..) |function, function_id| {
            if (!std.mem.eql(u8, function.name, call.name) or function.parameters.len != arguments.items.len) continue;
            if (!functionVisible(call, function)) continue;
            var matches = true;
            for (function.parameters, arguments.items) |parameter, argument| {
                if (parameter.type != argument.type) {
                    matches = false;
                    break;
                }
            }
            if (matches) {
                resolved = function_id;
                break;
            }
        }

        const function_id = resolved orelse {
            if (arity_count == 1) {
                for (self.program.functions) |function| {
                    if (!std.mem.eql(u8, function.name, call.name) or function.parameters.len != arguments.items.len) continue;
                    if (!functionVisible(call, function)) continue;
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
        try builder.instructions.append(self.allocator, .{ .call = .{
            .result = result,
            .function = function_id,
            .arguments = try argument_ids.toOwnedSlice(self.allocator),
        } });
        return if (result) |value| .{ .type = function.return_type, .value = value } else null;
    }

    fn emitInt(self: *Analyzer, builder: *FunctionBuilder, value: i64) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .int);
        try builder.instructions.append(self.allocator, .{ .constant_int = .{ .result = result, .value = value } });
        return .{ .type = .int, .value = result };
    }

    fn emitBool(self: *Analyzer, builder: *FunctionBuilder, value: bool) AnalyzeError!TypedValue {
        const result = try self.newValue(builder, .bool);
        try builder.instructions.append(self.allocator, .{ .constant_bool = .{ .result = result, .value = value } });
        return .{ .type = .bool, .value = result };
    }

    fn newValue(self: *Analyzer, builder: *FunctionBuilder, type_value: Types.Type) Allocator.Error!Ir.ValueId {
        const result = builder.value_types.items.len;
        try builder.value_types.append(self.allocator, type_value);
        return result;
    }

    fn parseInteger(self: *Analyzer, lexeme: []const u8, position: Source.Position, negative: bool) AnalyzeError!i64 {
        const normalized = try self.allocator.alloc(u8, lexeme.len);
        var length: usize = 0;
        for (lexeme) |character| {
            if (character == '_') continue;
            normalized[length] = character;
            length += 1;
        }
        const literal = normalized[0..length];
        const base: u8 = if (literal.len > 2 and literal[0] == '0') switch (literal[1]) {
            'b', 'B' => 2,
            'o', 'O' => 8,
            'x', 'X' => 16,
            else => 10,
        } else 10;
        const digits = if (base == 10) literal else literal[2..];
        const magnitude = std.fmt.parseInt(u64, digits, base) catch {
            return self.fail(position, "integer literal is outside the range of 'int'");
        };
        const positive_limit: u64 = @intCast(std.math.maxInt(i64));
        if (!negative) {
            if (magnitude > positive_limit) return self.fail(position, "integer literal is outside the range of 'int'");
            return @intCast(magnitude);
        }
        if (magnitude > positive_limit + 1) return self.fail(position, "integer literal is outside the range of 'int'");
        if (magnitude == positive_limit + 1) return std.math.minInt(i64);
        return @intCast(magnitude);
    }

    fn fail(self: *Analyzer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

fn sameParameterTypes(left: []const Ast.Parameter, right: []const Ast.Parameter) bool {
    if (left.len != right.len) return false;
    for (left, right) |left_parameter, right_parameter| {
        if (left_parameter.type != right_parameter.type) return false;
    }
    return true;
}

fn findBinding(bindings: []const Binding, name: []const u8) ?Binding {
    var index = bindings.len;
    while (index != 0) {
        index -= 1;
        if (std.mem.eql(u8, bindings[index].name, name)) return bindings[index];
    }
    return null;
}

fn findVisibleFunctionByName(program: Ast.Program, call: Ast.Expression.Call) ?Ast.Function {
    for (program.functions) |function| {
        if (std.mem.eql(u8, function.name, call.name) and functionVisible(call, function)) return function;
    }
    return null;
}

fn functionVisible(call: Ast.Expression.Call, function: Ast.Function) bool {
    return call.owner == function.owner or function.is_public;
}

fn binaryOperatorText(operator: Ast.BinaryOperator) []const u8 {
    return switch (operator) {
        .add => "+",
        .subtract => "-",
        .multiply => "*",
        .divide => "/",
        .remainder => "%",
    };
}

fn expectSemanticError(source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator, source);
    var analyzer = Analyzer.init(allocator);
    try std.testing.expectError(error.InvalidSource, analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(message, analyzer.diagnostic.?.message);
}

test "lower empty main to an explicit void return" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator, "func main() {}");
    var analyzer = Analyzer.init(allocator);
    const text = try Ir.writeText(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @main() -> void {
        \\entry:
        \\    return
        \\}
        \\
    , text);
}

test "resolve forward calls overloads locals and intrinsic values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator,
        \\func main() {
        \\    answer()
        \\    choose(true)
        \\}
        \\func choose(value:int) int { return value }
        \\func choose(value:bool) bool { return value }
        \\func answer() int {
        \\    let left:int = 40
        \\    let right:int = 2
        \\    let ready:bool
        \\    return left + right
        \\}
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(@as(usize, 4), program.functions.len);
    try std.testing.expectEqual(Types.Type.bool, program.functions[0].value_types[1]);
    try std.testing.expectEqual(@as(Ir.FunctionId, 3), program.functions[0].instructions[0].call.function);
    try std.testing.expectEqual(@as(i64, 2), program.functions[3].instructions[1].constant_int.value);
    try std.testing.expect(!program.functions[3].instructions[2].constant_bool.value);
}

test "lower fundamental calculation to deterministic IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(allocator,
        \\func add(left:int, right:int) int {
        \\    let result = left + right
        \\    return result
        \\}
        \\func answer() int { return add(40, 2) }
        \\func main() { answer() }
    );
    var analyzer = Analyzer.init(allocator);
    const text = try Ir.writeText(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expectEqualStrings(
        \\func @add(%0:int, %1:int) -> int {
        \\entry:
        \\    %2:int = add %0, %1
        \\    return %2
        \\}
        \\
        \\func @answer() -> int {
        \\entry:
        \\    %0:int = const 40
        \\    %1:int = const 2
        \\    %2:int = call @add(%0, %1)
        \\    return %2
        \\}
        \\
        \\func @main() -> void {
        \\entry:
        \\    %0:int = call @answer()
        \\    return
        \\}
        \\
    , text);
}

test "accept the minimum signed integer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = @import("Parser.zig").Parser.init(
        allocator,
        "func minimum() int { return -9223372036854775808 } func main() {}",
    );
    var analyzer = Analyzer.init(allocator);
    const program = try analyzer.analyze(try parser.parse());
    try std.testing.expectEqual(std.math.minInt(i64), program.functions[0].instructions[0].constant_int.value);
}

test "report declaration and resolution errors" {
    try expectSemanticError(
        "func value(input:int) int { return input } func value(other:int) bool { return true } func main() {}",
        "function 'value' with these parameter types is already declared",
    );
    try expectSemanticError(
        "func value(input:int, input:int) int { return input } func main() {}",
        "parameter 'input' is already declared",
    );
    try expectSemanticError(
        "func main() { let value = 1; let value = 2 }",
        "variable 'value' is already declared in this scope",
    );
    try expectSemanticError("func value() int { return missing } func main() {}", "unknown variable 'missing'");
    try expectSemanticError("func main() { missing() }", "unknown function 'missing'");
    try expectSemanticError(
        "func add(left:int, right:int) int { return left + right } func main() { add(1) }",
        "function 'add' expects 2 arguments, found 1",
    );
    try expectSemanticError(
        "func enabled(value:bool) bool { return value } func main() { enabled(1) }",
        "argument 1 of 'enabled' expects 'bool', found 'int'",
    );
    try expectSemanticError(
        "func choose(left:int, right:int) int { return left } func choose(left:bool, right:bool) bool { return left } func main() { choose(1, true) }",
        "no overload of function 'choose' matches the argument types",
    );
}

test "report fundamental type and return errors" {
    try expectSemanticError(
        "func value() int { return true + 1 } func main() {}",
        "operator '+' expects 'int' operands, found 'bool' and 'int'",
    );
    try expectSemanticError(
        "func main() { let ready:bool = 1 }",
        "variable 'ready' expects 'bool', found 'int'",
    );
    try expectSemanticError(
        "func value() int { return 9223372036854775808 } func main() {}",
        "integer literal is outside the range of 'int'",
    );
    try expectSemanticError(
        "func value() int {} func main() {}",
        "function 'value' must return 'int' on every path",
    );
    try expectSemanticError(
        "func value() int { return } func main() {}",
        "expected return value of type 'int'",
    );
    try expectSemanticError(
        "func value() int { return false } func main() {}",
        "return expects 'int', found 'bool'",
    );
    try expectSemanticError("func main() { return 1 }", "a void function cannot return a value");
}
