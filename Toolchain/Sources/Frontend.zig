const std = @import("std");
const Ast = @import("Ast.zig");
const Ir = @import("Ir.zig");
const ParserModule = @import("Parser.zig");
const Semantic = @import("Semantic.zig");
const Source = @import("Source.zig");

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
        const ast = parser.parse() catch |err| {
            self.diagnostic = parser.diagnostic;
            return err;
        };
        var analyzer: Semantic.Analyzer = .{};
        analyzer.validate(ast) catch |err| {
            self.diagnostic = analyzer.diagnostic;
            return err;
        };
        return .{ .ast = ast, .ir = try Ir.lower(self.allocator, ast) };
    }
};

test "compile the first Silex program through typed IR" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var frontend = Frontend.init(arena.allocator());
    const compilation = try frontend.compile("func main() {}");
    try std.testing.expectEqual(@as(usize, 1), compilation.ast.functions.len);
    try std.testing.expectEqual(@as(usize, 1), compilation.ir.functions.len);
}
