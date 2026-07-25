const std = @import("std");
const Ast = @import("Ast.zig");
const Source = @import("Source.zig");

pub const Analyzer = struct {
    diagnostic: ?Source.Diagnostic = null,

    pub fn validate(self: *Analyzer, program: Ast.Program) Source.Error!void {
        var main: ?Ast.Function = null;
        for (program.functions) |function| {
            if (!std.mem.eql(u8, function.name, "main")) continue;
            if (main != null) return self.fail(function.name_position, "'main' cannot be overloaded");
            main = function;
        }

        const entry = main orelse return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, "missing 'main' function");
        if (entry.parameters.len != 0) return self.fail(entry.name_position, "'main' must have no parameters");
        if (entry.return_type != .void) return self.fail(entry.name_position, "'main' must return 'void' in language v0");

        for (program.functions) |function| {
            if (function.return_type != .void) {
                return self.fail(function.name_position, "non-void functions require return statements, which are not implemented yet");
            }
        }
    }

    fn fail(self: *Analyzer, position: Source.Position, message: []const u8) Source.Error {
        self.diagnostic = .{ .position = position, .message = message };
        return error.InvalidSource;
    }
};

test "accept empty main" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = @import("Parser.zig").Parser.init(arena.allocator(), "func main() {}");
    var analyzer: Analyzer = .{};
    try analyzer.validate(try parser.parse());
}

test "reject a missing main" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var parser = @import("Parser.zig").Parser.init(arena.allocator(), "func helper() {}");
    var analyzer: Analyzer = .{};
    try std.testing.expectError(error.InvalidSource, analyzer.validate(try parser.parse()));
    try std.testing.expectEqualStrings("missing 'main' function", analyzer.diagnostic.?.message);
}
