const std = @import("std");
const Ast = @import("Ast.zig");
const Semantic = @import("Semantic.zig");

const Allocator = std.mem.Allocator;
const GenerateError = Allocator.Error;

pub fn generate(allocator: Allocator, program: Semantic.Program) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    try output.appendSlice(allocator,
        \\#include <cstdint>
        \\#include <iostream>
        \\#include <string>
        \\
    );
    try output.appendSlice(allocator,
        \\
        \\namespace SilexGenerated {
        \\
        \\// -----------------------------------------------------------------------------
        \\
    );
    try output.append(allocator, '\n');
    for (program.structures) |structure| {
        try output.appendSlice(allocator, "struct ");
        try output.appendSlice(allocator, structure.generated_name);
        try output.appendSlice(allocator, ";\n");
    }
    if (program.structures.len > 0) try output.append(allocator, '\n');
    for (program.structures) |structure| {
        try output.appendSlice(allocator, "struct ");
        try output.appendSlice(allocator, structure.generated_name);
        try output.appendSlice(allocator, " {\n");
        for (structure.fields) |field| {
            try output.appendSlice(allocator, "    ");
            try output.appendSlice(allocator, cppType(field.type));
            try output.append(allocator, ' ');
            try output.appendSlice(allocator, field.generated_name);
            try output.appendSlice(allocator, ";\n");
        }
        if (structure.fields.len > 0 and structure.methods.len > 0) try output.append(allocator, '\n');
        for (structure.methods) |method| {
            try output.appendSlice(allocator, "    ");
            try generateMethodSignature(allocator, &output, method, null, false);
            try output.appendSlice(allocator, ";\n");
        }
        try output.appendSlice(allocator, "};\n\n");
    }
    for (program.functions) |function| {
        if (function.is_main) continue;
        try generateFunctionSignature(allocator, &output, function, false);
        try output.appendSlice(allocator, ";\n");
    }
    if (program.functions.len > 1) try output.append(allocator, '\n');
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            try generateMethodSignature(allocator, &output, method, structure.generated_name, true);
            try output.appendSlice(allocator, " {\n");
            try generateStatements(allocator, &output, method.statements, 1, false);
            try output.appendSlice(allocator, "}\n\n");
        }
    }
    for (program.functions) |function| {
        try generateFunctionSignature(allocator, &output, function, true);
        try output.appendSlice(allocator, " {\n");
        try generateStatements(allocator, &output, function.statements, 1, function.is_main);
        if (function.is_main) try output.appendSlice(allocator, "    return 0;\n");
        try output.appendSlice(allocator, "}\n\n");
    }
    try output.appendSlice(allocator,
        \\// -----------------------------------------------------------------------------
        \\
        \\} // namespace SilexGenerated
        \\
        \\int main() {
        \\    return SilexGenerated::silexMain();
        \\}
        \\
    );
    return output.toOwnedSlice(allocator);
}

fn generateMethodSignature(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    method: Semantic.Method,
    owner_name: ?[]const u8,
    include_names: bool,
) !void {
    try output.appendSlice(allocator, cppType(method.return_type));
    try output.append(allocator, ' ');
    if (owner_name) |name| {
        try output.appendSlice(allocator, name);
        try output.appendSlice(allocator, "::");
    }
    try output.appendSlice(allocator, method.generated_name);
    try output.append(allocator, '(');
    for (method.parameters, 0..) |parameter, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, cppType(parameter.type));
        if (include_names) {
            try output.append(allocator, ' ');
            try output.appendSlice(allocator, parameter.generated_name);
        }
    }
    try output.append(allocator, ')');
    if (!method.is_mutating) try output.appendSlice(allocator, " const");
}

fn generateFunctionSignature(allocator: Allocator, output: *std.ArrayList(u8), function: Semantic.Function, include_names: bool) !void {
    try output.appendSlice(allocator, if (function.is_main) "int silexMain(" else cppType(function.return_type));
    if (!function.is_main) {
        try output.append(allocator, ' ');
        try output.appendSlice(allocator, function.generated_name);
        try output.append(allocator, '(');
    }
    for (function.parameters, 0..) |parameter, index| {
        if (index != 0) try output.appendSlice(allocator, ", ");
        try output.appendSlice(allocator, cppType(parameter.type));
        if (include_names) {
            try output.append(allocator, ' ');
            try output.appendSlice(allocator, parameter.generated_name);
        }
    }
    try output.append(allocator, ')');
}

fn generateStatements(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    statements: []const Semantic.Statement,
    indentation: usize,
    is_main: bool,
) GenerateError!void {
    for (statements) |statement| {
        try generateStatement(allocator, output, statement, indentation, is_main);
    }
}

fn generateStatement(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    statement: Semantic.Statement,
    indentation: usize,
    is_main: bool,
) GenerateError!void {
    switch (statement) {
        .print => |argument| {
            try indent(allocator, output, indentation);
            try output.appendSlice(allocator, "std::cout << ");
            if (argument.type == .bool) try output.append(allocator, '(');
            try generateExpression(allocator, output, argument);
            if (argument.type == .bool) try output.appendSlice(allocator, " ? \"true\" : \"false\")");
            try output.appendSlice(allocator, " << '\\n';\n");
        },
        .variable_declaration => |declaration| {
            try indent(allocator, output, indentation);
            if (declaration.mutability == .immutable) try output.appendSlice(allocator, "const ");
            try output.appendSlice(allocator, cppType(declaration.type));
            try output.append(allocator, ' ');
            try output.appendSlice(allocator, declaration.generated_name);
            try output.appendSlice(allocator, " = ");
            try generateExpression(allocator, output, declaration.initializer);
            try output.appendSlice(allocator, ";\n");
        },
        .assignment => |assignment| {
            try indent(allocator, output, indentation);
            try generateExpression(allocator, output, assignment.target);
            switch (assignment.operator) {
                .assign, .add, .subtract, .multiply, .divide => {
                    try output.appendSlice(allocator, assignmentOperatorText(assignment.operator));
                    try generateExpression(allocator, output, assignment.value.?);
                },
                .increment => try output.appendSlice(allocator, "++"),
                .decrement => try output.appendSlice(allocator, "--"),
            }
            try output.appendSlice(allocator, ";\n");
        },
        .if_statement => |if_statement| {
            try indent(allocator, output, indentation);
            try output.appendSlice(allocator, "if (");
            try generateExpression(allocator, output, if_statement.condition);
            try output.appendSlice(allocator, ") {\n");
            try generateStatements(allocator, output, if_statement.body, indentation + 1, is_main);
            try indent(allocator, output, indentation);
            if (if_statement.else_body) |else_body| {
                try output.appendSlice(allocator, "} else {\n");
                try generateStatements(allocator, output, else_body, indentation + 1, is_main);
                try indent(allocator, output, indentation);
            }
            try output.appendSlice(allocator, "}\n");
        },
        .while_statement => |while_statement| {
            try indent(allocator, output, indentation);
            try output.appendSlice(allocator, "while (");
            try generateExpression(allocator, output, while_statement.condition);
            try output.appendSlice(allocator, ") {\n");
            try generateStatements(allocator, output, while_statement.body, indentation + 1, is_main);
            try indent(allocator, output, indentation);
            try output.appendSlice(allocator, "}\n");
        },
        .return_statement => |value| {
            try indent(allocator, output, indentation);
            if (value) |expression| {
                try output.appendSlice(allocator, "return ");
                try generateExpression(allocator, output, expression);
                try output.appendSlice(allocator, ";\n");
            } else {
                try output.appendSlice(allocator, if (is_main) "return 0;\n" else "return;\n");
            }
        },
        .expression_statement => |expression| {
            try indent(allocator, output, indentation);
            try generateExpression(allocator, output, expression);
            try output.appendSlice(allocator, ";\n");
        },
    }
}

fn generateExpression(allocator: Allocator, output: *std.ArrayList(u8), expression: *const Semantic.Expression) !void {
    switch (expression.value) {
        .integer => |value| {
            const literal = try std.fmt.allocPrint(allocator, "std::int64_t{{{d}}}", .{value});
            try output.appendSlice(allocator, literal);
        },
        .boolean => |value| try output.appendSlice(allocator, if (value) "true" else "false"),
        .string => |value| {
            try output.appendSlice(allocator, "std::string{\"");
            try output.appendSlice(allocator, value);
            try output.appendSlice(allocator, "\"}");
        },
        .variable => |generated_name| try output.appendSlice(allocator, generated_name),
        .self => try output.appendSlice(allocator, "*this"),
        .call => |call| {
            try output.appendSlice(allocator, call.generated_name);
            try output.append(allocator, '(');
            for (call.arguments, 0..) |argument, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try generateExpression(allocator, output, argument);
            }
            try output.append(allocator, ')');
        },
        .method_call => |call| {
            if (call.object.value != .self) {
                try generateExpression(allocator, output, call.object);
                try output.append(allocator, '.');
            }
            try output.appendSlice(allocator, call.generated_name);
            try output.append(allocator, '(');
            for (call.arguments, 0..) |argument, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try generateExpression(allocator, output, argument);
            }
            try output.append(allocator, ')');
        },
        .structure_initializer => |initializer| {
            try output.appendSlice(allocator, initializer.generated_name);
            try output.append(allocator, '{');
            for (initializer.fields, 0..) |field, index| {
                if (index != 0) try output.appendSlice(allocator, ", ");
                try generateExpression(allocator, output, field);
            }
            try output.append(allocator, '}');
        },
        .member_access => |member| {
            if (member.object.value != .self) {
                try generateExpression(allocator, output, member.object);
                try output.append(allocator, '.');
            }
            try output.appendSlice(allocator, member.generated_name);
        },
        .unary => |unary| {
            try output.appendSlice(allocator, "(!");
            try generateExpression(allocator, output, unary.operand);
            try output.append(allocator, ')');
        },
        .binary => |binary| {
            try output.append(allocator, '(');
            try generateExpression(allocator, output, binary.left);
            try output.appendSlice(allocator, operatorText(binary.operator));
            try generateExpression(allocator, output, binary.right);
            try output.append(allocator, ')');
        },
    }
}

fn indent(allocator: Allocator, output: *std.ArrayList(u8), level: usize) !void {
    var index: usize = 0;
    while (index < level) : (index += 1) try output.appendSlice(allocator, "    ");
}

fn cppType(type_name: Semantic.Type) []const u8 {
    return switch (type_name) {
        .void => "void",
        .int => "std::int64_t",
        .bool => "bool",
        .string => "std::string",
        .structure => |structure_type| structure_type.generated_name,
    };
}

fn operatorText(operator: Ast.BinaryOperator) []const u8 {
    return switch (operator) {
        .logical_or => " || ",
        .logical_and => " && ",
        .equal => " == ",
        .not_equal => " != ",
        .less => " < ",
        .less_equal => " <= ",
        .greater => " > ",
        .greater_equal => " >= ",
        .add => " + ",
        .subtract => " - ",
        .multiply => " * ",
        .divide => " / ",
    };
}

fn assignmentOperatorText(operator: Ast.AssignmentOperator) []const u8 {
    return switch (operator) {
        .assign => " = ",
        .add => " += ",
        .subtract => " -= ",
        .multiply => " *= ",
        .divide => " /= ",
        .increment, .decrement => unreachable,
    };
}

test "generate typed variables and control flow" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(
        allocator,
        "func main() void { let count = 5; if (!(count < 3)) { print(\"yes\"); } else { print(\"no\"); } }",
    );
    var analyzer = Semantic.Analyzer.init(allocator);
    const cpp = try generate(allocator, try analyzer.analyze(try parser.parse()));

    try std.testing.expect(std.mem.indexOf(u8, cpp, "const std::int64_t silexValue0") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "if ((!(silexValue0 < std::int64_t{3})))") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "} else {") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "std::string{\"yes\"}") != null);
}

test "generate while loop" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(
        allocator,
        "func main() void { var count = 2; while (count > 0) { count = count - 1; } }",
    );
    var analyzer = Semantic.Analyzer.init(allocator);
    const cpp = try generate(allocator, try analyzer.analyze(try parser.parse()));

    try std.testing.expect(std.mem.indexOf(u8, cpp, "while ((silexValue0 > std::int64_t{0})) {") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "silexValue0 = (silexValue0 - std::int64_t{1});") != null);
}

test "generate function declarations calls and returns" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator,
        \\func main() void { print(double(5)) }
        \\func double(value:int) int { return value * 2 }
    );
    var analyzer = Semantic.Analyzer.init(allocator);
    const cpp = try generate(allocator, try analyzer.analyze(try parser.parse()));
    try std.testing.expect(std.mem.indexOf(u8, cpp, "std::int64_t silexFunction1(std::int64_t);") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "return (silexValue0 * std::int64_t{2});") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "silexFunction1(std::int64_t{5})") != null);
}

test "generate value structs and member access" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator,
        \\struct Position { x:int; y:int }
        \\func main() void { var position = Position { y:20, x:10 }; position.x = 12; print(position.x) }
    );
    var analyzer = Semantic.Analyzer.init(allocator);
    const cpp = try generate(allocator, try analyzer.analyze(try parser.parse()));

    try std.testing.expect(std.mem.indexOf(u8, cpp, "struct SilexStruct0 {") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "SilexStruct0{std::int64_t{10}, std::int64_t{20}}") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "silexValue0.field0 = std::int64_t{12};") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "namespace SilexGenerated {") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "int silexMain()") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "return SilexGenerated::silexMain();") != null);
}

test "generate inferred const and mutating methods" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(allocator,
        \\struct Counter {
        \\    value:int
        \\    func current() int { return self.value }
        \\    func increment() void { self.value = self.value + 1 }
        \\}
        \\func main() void { var counter = Counter { value:1 }; counter.increment(); print(counter.current()) }
    );
    var analyzer = Semantic.Analyzer.init(allocator);
    const cpp = try generate(allocator, try analyzer.analyze(try parser.parse()));

    try std.testing.expect(std.mem.indexOf(u8, cpp, "std::int64_t method0() const;") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "void method1();") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "SilexStruct0::method0() const") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "SilexStruct0::method1()") != null);
}
