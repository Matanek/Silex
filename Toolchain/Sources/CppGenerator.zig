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
        \\int main() {
        \\
    );

    try generateStatements(allocator, &output, program.statements, 1);

    try output.appendSlice(allocator,
        \\    return 0;
        \\}
        \\
    );
    return output.toOwnedSlice(allocator);
}

fn generateStatements(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    statements: []const Semantic.Statement,
    indentation: usize,
) GenerateError!void {
    for (statements) |statement| {
        try generateStatement(allocator, output, statement, indentation);
    }
}

fn generateStatement(
    allocator: Allocator,
    output: *std.ArrayList(u8),
    statement: Semantic.Statement,
    indentation: usize,
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
            try output.appendSlice(allocator, assignment.generated_name);
            try output.appendSlice(allocator, " = ");
            try generateExpression(allocator, output, assignment.value);
            try output.appendSlice(allocator, ";\n");
        },
        .if_statement => |if_statement| {
            try indent(allocator, output, indentation);
            try output.appendSlice(allocator, "if (");
            try generateExpression(allocator, output, if_statement.condition);
            try output.appendSlice(allocator, ") {\n");
            try generateStatements(allocator, output, if_statement.body, indentation + 1);
            try indent(allocator, output, indentation);
            if (if_statement.else_body) |else_body| {
                try output.appendSlice(allocator, "} else {\n");
                try generateStatements(allocator, output, else_body, indentation + 1);
                try indent(allocator, output, indentation);
            }
            try output.appendSlice(allocator, "}\n");
        },
        .while_statement => |while_statement| {
            try indent(allocator, output, indentation);
            try output.appendSlice(allocator, "while (");
            try generateExpression(allocator, output, while_statement.condition);
            try output.appendSlice(allocator, ") {\n");
            try generateStatements(allocator, output, while_statement.body, indentation + 1);
            try indent(allocator, output, indentation);
            try output.appendSlice(allocator, "}\n");
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
        .int => "std::int64_t",
        .bool => "bool",
        .string => "std::string",
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

test "generate typed variables and control flow" {
    const Parser = @import("Parser.zig").Parser;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var parser = Parser.init(
        allocator,
        "void main() { let count = 5; if (!(count < 3)) { print(\"yes\"); } else { print(\"no\"); } }",
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
        "void main() { var count = 2; while (count > 0) { count = count - 1; } }",
    );
    var analyzer = Semantic.Analyzer.init(allocator);
    const cpp = try generate(allocator, try analyzer.analyze(try parser.parse()));

    try std.testing.expect(std.mem.indexOf(u8, cpp, "while ((silexValue0 > std::int64_t{0})) {") != null);
    try std.testing.expect(std.mem.indexOf(u8, cpp, "silexValue0 = (silexValue0 - std::int64_t{1});") != null);
}
