const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Parser = @import("../Parser.zig").Parser;
const Analyzer = @import("Analyzer.zig").Analyzer;
const Declarations = @import("Declarations.zig");
const Inheritance = @import("Inheritance.zig");

test "source declaration lookup follows nominal IDs rather than declaration order" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var parser = Parser.init(allocator,
        \\enum Mode { idle; busy }
        \\struct First { let value:int }
        \\struct Second { let flag:bool }
        \\func main() {}
    );
    var source = try parser.parse();
    const declarations = try allocator.dupe(Ast.Structure, source.structures);
    std.mem.reverse(Ast.Structure, declarations);
    source.structures = declarations;
    var analyzer = Analyzer.init(allocator);
    analyzer.program = source;
    analyzer.structures = try Declarations.prepareStructures(&analyzer);
    for (source.type_names, 0..) |name, index| {
        if (std.mem.eql(u8, name, "Mode")) {
            try std.testing.expect(Inheritance.findDeclaration(&analyzer, index) == null);
        } else {
            const declaration = Inheritance.findDeclaration(&analyzer, index).?;
            try std.testing.expectEqualStrings(name, declaration.name);
        }
    }

    // Later preparation changes the source methods in place. The lookup must
    // read the current declaration, not a snapshot taken during preparation.
    declarations[0].is_internal = true;
    const changed = analyzer.structureIndex(declarations[0].name).?;
    try std.testing.expect(Inheritance.findDeclaration(&analyzer, changed).?.is_internal);

    // Tuple inference renames IR placeholders, sometimes to an existing source
    // tuple name and sometimes to a name without a declaration.
    @constCast(&analyzer.structures[changed]).name = declarations[1].name;
    try std.testing.expectEqualStrings(declarations[1].name, Inheritance.findDeclaration(&analyzer, changed).?.name);
    @constCast(&analyzer.structures[changed]).name = "(inferred:int)";
    try std.testing.expect(Inheritance.findDeclaration(&analyzer, changed) == null);

    const extended = try allocator.alloc(Ir.Structure, analyzer.structures.len + 1);
    @memcpy(extended[0..analyzer.structures.len], analyzer.structures);
    extended[extended.len - 1] = .{ .name = "First.method#result0", .fields = &.{} };
    analyzer.structures = extended;
    try std.testing.expect(Inheritance.findDeclaration(&analyzer, extended.len - 1) == null);
    try std.testing.expect(Inheritance.findDeclaration(&analyzer, extended.len) == null);
}

test "source declaration lookup is rebuilt when the analyzer receives a new program" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var analyzer = Analyzer.init(allocator);
    var first = Parser.init(allocator, "struct First {} struct Extra {} func main() {}");
    _ = try analyzer.analyze(try first.parse());
    try std.testing.expectEqual(@as(usize, 2), analyzer.structure_declarations.count());
    var second = Parser.init(allocator, "struct Second {} func main() {}");
    _ = try analyzer.analyze(try second.parse());
    try std.testing.expectEqual(@as(usize, 1), analyzer.structure_declarations.count());
    try std.testing.expectEqualStrings("Second", Inheritance.findDeclaration(&analyzer, 0).?.name);
    try std.testing.expect(Inheritance.findDeclaration(&analyzer, 1) == null);
}
