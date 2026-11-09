const std = @import("std");
const Ir = @import("Ir.zig");
const C = @import("Semantic/CallbackFlow/Confinement.zig");
const callback = Ir.Type.function(0);
const box = Ir.Type.structure(0);
const array = Ir.Type.structure(1);
const seed = [_]Ir.Instruction{
    .{ .constant_int = .{ .result = 2, .bits = 7 } },
    .{ .local_store = .{ .local = 0, .operand = 2 } },
    .{ .local_address = .{ .result = 3, .local = 0 } },
    .{ .function_reference = .{ .result = 4, .function = 1, .captures = &.{3} } },
};
fn program(a: std.mem.Allocator, params: []const Ir.Type, ops: []const Ir.Instruction, live: []const Ir.LiveBinding, extra: []const Ir.Function, globals: []const Ir.Global) !Ir.Program {
    const functions = try a.alloc(Ir.Function, 2 + extra.len);
    functions[0] = .{ .name = "origin", .parameter_types = params, .return_type = .void, .value_types = &.{ box, array, .int, .address, callback, box, .uint, array, callback, .address }, .local_types = &.{ .int, callback, array }, .borrow_origins = &.{.{ .reference = 3, .lifetime = 0, .type = .int }}, .borrow_ends = try a.dupe(Ir.BorrowEnd, &.{.{ .block = 0, .instruction = ops.len, .lifetimes = &.{0}, .live = live }}), .blocks = try a.dupe(Ir.Block, &.{.{ .instructions = ops, .terminator = .return_void }}) };
    functions[1] = .{ .name = "closure", .capture_types = &.{.address}, .parameter_types = &.{}, .return_type = .void, .value_types = &.{.address}, .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }} };
    @memcpy(functions[2..], extra);
    return .{ .functions = functions, .globals = globals, .function_types = &.{.{ .parameter_types = &.{}, .return_type = .void }}, .structures = &.{ .{ .name = "Box", .is_class = true, .fields = &.{.{ .name = "callback", .type = callback, .mutable = true }} }, .{ .name = "Array", .fields = &.{}, .collection = .{ .element = callback, .length = null } } } };
}
fn proof(a: std.mem.Allocator, p: Ir.Program, expected: bool) !void {
    const g = try C.Graph.init(a, p);
    try std.testing.expectEqual(expected, try g.proven(a, 0));
}
test "callback confinement sees global and live lexical environments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try proof(a, try program(a, &.{}, &(seed ++ [_]Ir.Instruction{.{ .global_store = .{ .global = 0, .operand = 4 } }}), &.{}, &.{}, &.{.{ .name = "saved", .type = callback, .mutable = true }}), false);
    try proof(a, try program(a, &.{}, &(seed ++ [_]Ir.Instruction{.{ .local_store = .{ .local = 1, .operand = 4 } }}), &.{.{ .local = 1 }}, &.{}, &.{}), false);
}
test "callback confinement follows an external class and its uint address alias" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try proof(a, try program(a, &.{box}, &(seed ++ [_]Ir.Instruction{ .{ .copy = .{ .result = 6, .operand = 0 } }, .{ .copy = .{ .result = 5, .operand = 6 } }, .{ .field_store = .{ .result = 5, .base = 5, .field = 0, .replacement = 4 } } }), &.{}, &.{}, &.{}), false);
}
test "callback confinement keeps mutable collection aliases across a call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const target: Ir.Function = .{ .name = "set", .parameter_types = &.{ array, callback }, .return_type = .void, .value_types = &.{ array, callback, .int, .address }, .blocks = &.{.{ .instructions = &.{ .{ .constant_int = .{ .result = 2, .bits = 0 } }, .{ .collection_reference = .{ .result = 3, .collection = 0, .reference = null, .index = 2, .position = .{ .offset = 0, .line = 1, .column = 1 } } }, .{ .reference_store = .{ .reference = 3, .operand = 1 } } }, .terminator = .return_void }} };
    // The source's second parameter is the collection; only the first is unused.
    try proof(a, try program(a, &.{ box, array }, &(seed ++ [_]Ir.Instruction{.{ .call = .{ .result = null, .function = 2, .arguments = &.{ 1, 4 } } }}), &.{}, &.{target}, &.{}), false);
}
test "callback confinement follows a callback written through a copied reference" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try proof(a, try program(a, &.{}, &(seed ++ [_]Ir.Instruction{ .{ .local_store = .{ .local = 1, .operand = 4 } }, .{ .local_address = .{ .result = 9, .local = 1 } }, .{ .copy = .{ .result = 3, .operand = 9 } } }), &.{.{ .local = 1 }}, &.{}, &.{}), false);
}
test "callback confinement accepts a local owner dropped before all scope ends" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try proof(a, try program(a, &.{}, &(seed ++ [_]Ir.Instruction{.{ .structure_init = .{ .result = 0, .structure = 0, .fields = &.{4} } }}), &.{}, &.{}, &.{}), true);
}

test "callback confinement retains opaque factories through local copies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = try program(a, &.{}, &(seed ++ [_]Ir.Instruction{ .{ .local_store = .{ .local = 1, .operand = 0 } }, .{ .local_load = .{ .result = 8, .local = 1 } }, .{ .indirect_call = .{ .result = 5, .callee = 8, .arguments = &.{} } }, .{ .field_store = .{ .result = 5, .base = 5, .field = 0, .replacement = 4 } } }), &.{}, &.{}, &.{});
    const fs = try a.dupe(Ir.Function, p.functions);
    p.functions = fs;
    const factory = Ir.Type.function(1);
    const values = try a.dupe(Ir.Type, fs[0].value_types);
    values[0] = factory;
    values[8] = factory;
    fs[0].value_types = values;
    fs[0].parameter_types = try a.dupe(Ir.Type, &.{factory});
    const locals = try a.dupe(Ir.Type, fs[0].local_types);
    locals[1] = factory;
    fs[0].local_types = locals;
    p.function_types = try a.dupe(Ir.FunctionType, &.{ p.function_types[0], .{ .parameter_types = &.{}, .return_type = box } });
    try proof(a, p, false);
}
test "callback confinement rejects unproven higher order retaining inputs" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = try program(a, &.{}, &(seed ++ [_]Ir.Instruction{.{ .indirect_call = .{ .result = null, .callee = 0, .arguments = &.{4} } }}), &.{}, &.{}, &.{});
    const fs = try a.dupe(Ir.Function, p.functions);
    p.functions = fs;
    const writer = Ir.Type.function(1);
    const values = try a.dupe(Ir.Type, fs[0].value_types);
    values[0] = writer;
    fs[0].value_types = values;
    fs[0].parameter_types = try a.dupe(Ir.Type, &.{writer});
    p.function_types = try a.dupe(Ir.FunctionType, &.{ p.function_types[0], .{ .parameter_types = &.{callback}, .return_type = .void } });
    try proof(a, p, false);
}
test "callback confinement retains opaque native references and function pointers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try proof(a, try program(a, &.{}, &(seed ++ [_]Ir.Instruction{ .{ .boundary_call = .{ .result = 9, .function = 0, .arguments = &.{} } }, .{ .reference_store = .{ .reference = 9, .operand = 4 } } }), &.{}, &.{}, &.{}), false);
    try proof(a, try program(a, &.{}, &(seed ++ [_]Ir.Instruction{.{ .boundary_call = .{ .result = null, .function = 0, .arguments = &.{4} } }}), &.{}, &.{}, &.{}), false);
}
test "callback confinement keeps numeric collection values distinct from an unrelated global" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const words = Ir.Type.structure(2);
    var p = try program(a, &.{}, &(seed ++ [_]Ir.Instruction{ .{ .structure_init = .{ .result = 0, .structure = 0, .fields = &.{4} } }, .{ .copy = .{ .result = 6, .operand = 0 } }, .{ .list_init = .{ .result = 7, .values = &.{6} } } }), &.{}, &.{}, try a.dupe(Ir.Global, &.{.{ .name = "hashes", .type = words, .mutable = true }}));
    const structures = try a.alloc(Ir.Structure, 3);
    @memcpy(structures[0..2], p.structures);
    structures[2] = .{ .name = "Words", .fields = &.{}, .collection = .{ .element = .uint, .length = null } };
    p.structures = structures;
    const fs = try a.dupe(Ir.Function, p.functions);
    p.functions = fs;
    const values = try a.dupe(Ir.Type, fs[0].value_types);
    values[7] = words;
    fs[0].value_types = values;
    try proof(a, p, true);
}

test "callback confinement keeps unproven callable word projections in the general solver" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try proof(a, try program(a, &.{}, &(seed ++ [_]Ir.Instruction{.{ .copy = .{ .result = 6, .operand = 4 } }}), &.{}, &.{}, &.{}), false);
}
