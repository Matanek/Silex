const std = @import("std");
const Ir = @import("Ir.zig");
const M = @import("Semantic/CallbackFlow/Model.zig");
const Closed = @import("Semantic/CallbackFlow/ClosedRoot.zig");
const slot_type = Ir.Type.structure(0);
const callback_type = Ir.Type.function(0);
const first_alias = Ir.Type.function(1);
const second_alias = Ir.Type.function(2);

fn fixture(a: std.mem.Allocator, suffix: []const Ir.Instruction) !Ir.Program {
    var ops: std.ArrayList(Ir.Instruction) = .empty;
    try ops.appendSlice(a, &.{
        .{ .local_address = .{ .result = 0, .local = 0 } },
        .{ .function_reference = .{ .result = 1, .function = 1, .captures = &.{0} } },
    });
    try ops.appendSlice(a, suffix);
    const fs = try a.dupe(Ir.Function, &.{
        .{ .name = "root", .parameter_types = &.{}, .return_type = .void, .value_types = &.{ .address, callback_type, slot_type, .address, .address, .address, .int, .int, .int, first_alias, second_alias }, .local_types = &.{ slot_type, .address, second_alias }, .borrow_origins = &.{.{ .reference = 0, .lifetime = 0, .type = slot_type }}, .borrow_ends = try a.dupe(Ir.BorrowEnd, &.{.{ .block = 0, .instruction = suffix.len + 2, .lifetimes = &.{0}, .live = &.{} }}), .blocks = try a.dupe(Ir.Block, &.{.{ .instructions = ops.items, .terminator = .return_void }}) },
        .{ .name = "callback", .capture_types = &.{.address}, .parameter_types = &.{}, .return_type = .void, .value_types = &.{.address}, .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }} },
    });
    return .{ .functions = fs, .structures = &.{.{ .name = "Slot", .is_class = true, .fields = &.{.{ .name = "callback", .type = callback_type, .mutable = true }} }}, .function_types = &.{ .{ .parameter_types = &.{}, .return_type = .void }, .{ .parameter_types = &.{.address}, .logical_parameter_types = &.{slot_type}, .return_type = .void }, .{ .parameter_types = &.{.address}, .logical_parameter_types = &.{slot_type}, .return_type = .void } } };
}
fn check(p: Ir.Program, a: std.mem.Allocator) !bool {
    const capable = try M.emptyTypes(a, p);
    @memset(capable.structures, true);
    @memset(capable.functions, true);
    return Closed.proven(a, p, capable, 0);
}

test "closed roots admit a confined environment and unrelated native handles" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(try check(try fixture(a, &.{}), a));
    try std.testing.expect(try check(try fixture(a, &.{
        .{ .boundary_call = .{ .result = 3, .function = 0, .arguments = &.{} } },
        .{ .boundary_call = .{ .result = null, .function = 0, .arguments = &.{3} } },
    }), a));
}

test "closed roots reject an aliased native address written into a local" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(!try check(try fixture(a, &.{
        .{ .boundary_call = .{ .result = 3, .function = 0, .arguments = &.{} } },
        .{ .local_address = .{ .result = 4, .local = 1 } },
        .{ .reference_store = .{ .reference = 4, .operand = 3 } },
        .{ .local_load = .{ .result = 5, .local = 1 } },
        .{ .reference_load = .{ .result = 2, .reference = 5 } },
    }), a));
}

test "closed roots reject native loan recipients and opaque managed results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(!try check(try fixture(a, &.{.{ .boundary_call = .{ .result = null, .function = 0, .arguments = &.{0} } }}), a));
    try std.testing.expect(!try check(try fixture(a, &.{.{ .boundary_call = .{ .result = null, .function = 0, .arguments = &.{1} } }}), a));
    try std.testing.expect(!try check(try fixture(a, &.{.{ .boundary_call = .{ .result = 2, .function = 0, .arguments = &.{} } }}), a));
    try std.testing.expect(!try check(try fixture(a, &.{.{ .convert = .{ .result = 3, .operand = 1, .source = .function(0), .target = .address, .checked = false, .position = .{ .offset = 0, .line = 1, .column = 1 } } }}), a));
}

test "closed roots reject managed projections from opaque references" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(!try check(try fixture(a, &.{
        .{ .boundary_call = .{ .result = 3, .function = 0, .arguments = &.{} } },
        .{ .reference_load = .{ .result = 2, .reference = 3 } },
    }), a));
    try std.testing.expect(!try check(try fixture(a, &.{
        .{ .boundary_call = .{ .result = 3, .function = 0, .arguments = &.{} } },
        .{ .reference_field = .{ .result = 4, .reference = 3, .structure = 0, .field = 0 } },
    }), a));
}

test "closed roots retain the general solver for live bindings inputs and globals" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = try fixture(a, &.{});
    const fs = try a.dupe(Ir.Function, p.functions);
    p.functions = fs;
    fs[0].borrow_ends = &.{.{ .block = 0, .instruction = 2, .lifetimes = &.{0}, .live = &.{.{ .local = 0 }} }};
    try std.testing.expect(!try check(p, a));
    fs[0].borrow_ends = &.{};
    try std.testing.expect(!try check(p, a));
    p = try fixture(a, &.{});
    p.globals = &.{.{ .name = "saved", .type = .structure(0), .mutable = true }};
    try std.testing.expect(!try check(p, a));
}

test "closed roots reject loan pointer bits after arithmetic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(!try check(try fixture(a, &.{
        .{ .constant_int = .{ .result = 8, .bits = 0 } },
        .{ .address_load = .{ .result = 6, .address = 0, .byte_offset = 8, .type = .int } },
        .{ .binary = .{ .result = 7, .operator = .add, .left = 6, .right = 8, .checked = false } },
        .{ .boundary_call = .{ .result = null, .function = 0, .arguments = &.{7} } },
    }), a));
}

test "closed roots propagate pointer bits through a numeric return" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = try fixture(a, &.{
        .{ .constant_int = .{ .result = 8, .bits = 0 } },
        .{ .address_load = .{ .result = 6, .address = 0, .byte_offset = 8, .type = .int } },
        .{ .call = .{ .result = 7, .function = 2, .arguments = &.{6} } },
        .{ .boundary_call = .{ .result = null, .function = 0, .arguments = &.{7} } },
    });
    const fs = try a.alloc(Ir.Function, 3);
    @memcpy(fs[0..2], p.functions);
    fs[2] = .{ .name = "identity_bits", .parameter_types = &.{.int}, .return_type = .int, .value_types = &.{.int}, .blocks = &.{.{ .instructions = &.{}, .terminator = .{ .return_value = 0 } }} };
    p.functions = fs;
    try std.testing.expect(!try check(p, a));
}

test "closed roots preserve address taint through structurally equal callback aliases" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = try fixture(a, &.{
        .{ .function_reference = .{ .result = 9, .function = 2, .captures = &.{} } },
        .{ .local_store = .{ .local = 2, .operand = 9 } },
        .{ .local_load = .{ .result = 10, .local = 2 } },
        .{ .indirect_call = .{ .result = null, .callee = 10, .arguments = &.{0} } },
    });
    p.function_types = &.{
        .{ .parameter_types = &.{}, .return_type = .void },
        .{ .parameter_types = &.{.address}, .logical_parameter_types = &.{.structure(0)}, .return_type = .void },
        .{ .parameter_types = &.{.address}, .logical_parameter_types = &.{.structure(0)}, .return_type = .void },
    };
    const fs = try a.alloc(Ir.Function, 3);
    @memcpy(fs[0..2], p.functions);
    fs[2] = .{ .name = "export_reference", .parameter_types = &.{.address}, .return_type = .void, .value_types = &.{.address}, .blocks = &.{.{ .instructions = &.{.{ .boundary_call = .{ .result = null, .function = 0, .arguments = &.{0} } }}, .terminator = .return_void }} };
    p.functions = fs;
    try std.testing.expect(!try check(p, a));
}

test "closed root carrier capabilities close equivalent callback signatures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var p = try fixture(a, &.{});
    p.function_types = &.{ .{ .parameter_types = &.{}, .return_type = .void }, .{ .parameter_types = &.{}, .return_type = .void } };
    p.structures = &.{.{ .name = "AliasBox", .fields = &.{.{ .name = "callback", .type = .function(1), .mutable = true }} }};
    const capable = try M.emptyTypes(a, p);
    capable.functions[0] = true;
    M.expandTypes(capable, p);
    try std.testing.expect(capable.functions[1]);
    try std.testing.expect(capable.structures[0]);
}

test "closed root carrier closure keeps lowered reference modes distinct" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const p: Ir.Program = .{ .functions = &.{}, .function_types = &.{
        .{ .parameter_types = &.{.address}, .logical_parameter_types = &.{.int}, .return_type = .void },
        .{ .parameter_types = &.{.address}, .logical_parameter_types = &.{.int}, .return_type = .void },
    } };
    const capable = try M.emptyTypes(a, p);
    capable.functions[0] = true;
    M.expandTypes(capable, p);
    try std.testing.expect(!capable.functions[1]);
}

test "closed roots admit unrelated indirect native handles" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    try std.testing.expect(try check(try fixture(a, &.{
        .{ .boundary_call = .{ .result = 3, .function = 0, .arguments = &.{} } },
        .{ .boundary_indirect_call = .{ .result = 4, .callee = 3, .signature = 0, .arguments = &.{3} } },
        .{ .boundary_indirect_call = .{ .result = null, .callee = 4, .signature = 0, .arguments = &.{3} } },
    }), a));
}

test "closed roots reject indirect native loan recipients and opaque carrier results" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    for ([_]usize{ 0, 1 }) |arg| try std.testing.expect(!try check(try fixture(a, &.{
        .{ .boundary_call = .{ .result = 3, .function = 0, .arguments = &.{} } },
        .{ .boundary_indirect_call = .{ .result = null, .callee = 3, .signature = 0, .arguments = try a.dupe(usize, &.{arg}) } },
    }), a));
    for ([_]usize{ 1, 2 }) |result| try std.testing.expect(!try check(try fixture(a, &.{
        .{ .boundary_call = .{ .result = 3, .function = 0, .arguments = &.{} } },
        .{ .boundary_indirect_call = .{ .result = result, .callee = 3, .signature = 0, .arguments = &.{} } },
    }), a));
    try std.testing.expect(!try check(try fixture(a, &.{
        .{ .boundary_indirect_call = .{ .result = null, .callee = 0, .signature = 0, .arguments = &.{} } },
    }), a));
}
