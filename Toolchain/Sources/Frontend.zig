const std = @import("std");
const Ast = @import("Ast.zig");
const GenericSpecializer = @import("Generics/Specializer.zig").Specializer;
const Result = @import("Intrinsics/Result.zig");
const Ir = @import("Ir.zig");
const ParserModule = @import("Parser.zig");
const Semantic = @import("Semantic/Analyzer.zig");
const Source = @import("Source.zig");
const Extensions = @import("Extensions.zig");

const Allocator = std.mem.Allocator;
const CompileError = Source.Error || Allocator.Error;

pub const Compilation = struct {
    ast: Ast.Program,
    ir: Ir.Program,
};

pub const Frontend = struct {
    allocator: Allocator,
    diagnostic: ?Source.Diagnostic = null,

    pub fn init(allocator: Allocator) Frontend {
        return .{ .allocator = allocator };
    }

    pub fn compile(self: *Frontend, source: []const u8) CompileError!Compilation {
        var parser = ParserModule.Parser.init(self.allocator, source);
        var ast = parser.parse() catch |err| {
            self.diagnostic = parser.diagnostic;
            return err;
        };
        ast = try withoutTests(self.allocator, ast);
        ast = try Result.install(self.allocator, ast);
        var extensions = Extensions.Merger.init(self.allocator);
        ast = extensions.merge(ast, true, true) catch |err| {
            self.diagnostic = extensions.diagnostic;
            return err;
        };
        var specializer = GenericSpecializer.init(self.allocator);
        ast = specializer.specialize(ast) catch |err| {
            self.diagnostic = specializer.diagnostic;
            return err;
        };
        var analyzer = Semantic.Analyzer.init(self.allocator);
        var ir = analyzer.analyze(ast) catch |err| {
            self.diagnostic = analyzer.diagnostic;
            return err;
        };
        ir.files = &.{"<source>"};
        return .{ .ast = ast, .ir = ir };
    }

    pub fn compileTests(self: *Frontend, source: []const u8) CompileError!Compilation {
        var parser = ParserModule.Parser.init(self.allocator, source);
        var ast = parser.parse() catch |err| {
            self.diagnostic = parser.diagnostic;
            return err;
        };
        ast = try Result.install(self.allocator, ast);
        var extensions = Extensions.Merger.init(self.allocator);
        ast = extensions.merge(ast, true, true) catch |err| {
            self.diagnostic = extensions.diagnostic;
            return err;
        };
        var specializer = GenericSpecializer.init(self.allocator);
        ast = specializer.specialize(ast) catch |err| {
            self.diagnostic = specializer.diagnostic;
            return err;
        };
        var analyzer = Semantic.Analyzer.init(self.allocator);
        var ir = analyzer.analyzeUnit(ast) catch |err| {
            self.diagnostic = analyzer.diagnostic;
            return err;
        };
        ir.files = &.{"<source>"};
        return .{ .ast = ast, .ir = ir };
    }

    pub fn checkDocument(self: *Frontend, source: []const u8) CompileError!void {
        return self.checkDocumentInProject(source, false);
    }

    pub fn checkDocumentInProject(
        self: *Frontend,
        source: []const u8,
        has_unresolved_project_context: bool,
    ) CompileError!void {
        var parser = ParserModule.Parser.init(self.allocator, source);
        var ast = parser.parse() catch |err| {
            self.diagnostic = parser.diagnostic;
            return err;
        };
        if (ast.uses.len != 0 or has_unresolved_project_context) return;
        ast = try Result.install(self.allocator, ast);
        var extensions = Extensions.Merger.init(self.allocator);
        ast = extensions.merge(ast, true, true) catch |err| {
            self.diagnostic = extensions.diagnostic;
            return err;
        };
        var specializer = GenericSpecializer.init(self.allocator);
        ast = specializer.specialize(ast) catch |err| {
            self.diagnostic = specializer.diagnostic;
            return err;
        };
        var analyzer = Semantic.Analyzer.init(self.allocator);
        _ = analyzer.analyzeUnit(ast) catch |err| {
            self.diagnostic = analyzer.diagnostic;
            return err;
        };
    }
};

fn withoutTests(allocator: Allocator, program: Ast.Program) Allocator.Error!Ast.Program {
    var filtered = program;
    var structures: std.ArrayList(Ast.Structure) = .empty;
    for (program.structures) |structure| {
        if (!structure.is_test) try structures.append(allocator, structure);
    }
    filtered.structures = try structures.toOwnedSlice(allocator);
    var functions: std.ArrayList(Ast.Function) = .empty;
    for (program.functions) |function| {
        if (!function.is_test) try functions.append(allocator, function);
    }
    filtered.functions = try functions.toOwnedSlice(allocator);
    return filtered;
}

test "compile the first Silex program through typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.init(arena.allocator());
    const compilation = try frontend.compile("func main() {}");
    try std.testing.expectEqual(@as(usize, 1), compilation.ast.functions.len);
    try std.testing.expectEqual(@as(usize, 1), compilation.ir.functions.len);
}

test "compile parsed statements to typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.init(arena.allocator());
    const compilation = try frontend.compile("func answer() int { return 40 + 2 } func main() { answer() }");
    try std.testing.expectEqual(@as(usize, 2), compilation.ir.functions.len);
    try std.testing.expectEqual(@as(Ir.FunctionId, 0), compilation.ir.functions[1].blocks[0].instructions[0].call.function);
}

test "check a library document without requiring an entry point" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.init(arena.allocator());
    try frontend.checkDocument("public func add(left:int, right:int) int { return left + right }");
}
