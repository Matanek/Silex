const std = @import("std");
const Ir = @import("Ir.zig");
const M = @import("Semantic/CallbackFlow/Model.zig");
const Flow = @import("Semantic/CallbackProvenance.zig");
const Transfer = @import("Semantic/CallbackFlow/Transfer.zig");
const Shape = @import("Semantic/CallbackFlow/Shape.zig");
test "callback references preserve root edge and masked ownership through projections" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const types = &[_]Ir.Type{ .address, .bool, .address, .bool, .address, .bool, .address, .bool, .address, .bool, .address, .bool, .address, .bool, .address, .bool };
    const functions = &[_]Ir.Function{.{ .name = "projection", .parameter_types = &.{}, .return_type = .void, .value_types = types, .local_types = &.{ .structure(0), .structure(1) }, .blocks = &.{} }};
    const structures = &[_]Ir.Structure{
        .{ .name = "Owner", .is_class = true, .fields = &.{.{ .name = "nested", .mutable = true, .type = .structure(1) }} },
        .{ .name = "Nested", .fields = &.{.{ .name = "value", .mutable = true, .type = .int }} },
    };
    const program: Ir.Program = .{ .functions = functions, .structures = structures };
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = program, .capable = try M.emptyTypes(a, program), .relevant = &.{}, .borrowed = &.{}, .generators = &.{} };
    try e.nodes.append(a, .{ .object = .{ .type = null, .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(0), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    var frame: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0 };
    try e.frames.append(a, &frame);
    var state: M.State = .{ .memory = .empty };
    try state.memory.put(a, .{ .object = 0, .field = 0 }, try M.Value.one(a, 1));
    try state.memory.put(a, .{ .object = 0, .field = 1 }, try M.Value.one(a, 2));
    try state.memory.put(a, .{ .object = 1, .field = 0 }, try M.Value.one(a, 2));
    try Transfer.step(&e, 0, 0, 0, .{ .local_address = .{ .result = 0, .local = 0 } }, &state);
    try Transfer.step(&e, 0, 0, 1, .{ .unary = .{ .result = 1, .operand = 0, .operator = .reference_is_edge } }, &state);
    try std.testing.expect(!state.get(1).scalar.boolean);
    try Transfer.step(&e, 0, 0, 2, .{ .reference_field = .{ .result = 2, .reference = 0, .structure = 0, .field = 0 } }, &state);
    try Transfer.step(&e, 0, 0, 3, .{ .unary = .{ .result = 3, .operand = 2, .operator = .reference_is_edge } }, &state);
    try std.testing.expect(state.get(3).scalar.boolean);
    try Transfer.step(&e, 0, 0, 4, .{ .reference_field = .{ .result = 4, .reference = 2, .structure = 1, .field = 0 } }, &state);
    try Transfer.step(&e, 0, 0, 5, .{ .unary = .{ .result = 5, .operand = 4, .operator = .reference_is_edge } }, &state);
    try std.testing.expect(state.get(5).scalar.boolean);
    try Transfer.step(&e, 0, 0, 6, .{ .unary = .{ .result = 6, .operand = 2, .operator = .reference_address } }, &state);
    try Transfer.step(&e, 0, 0, 7, .{ .unary = .{ .result = 7, .operand = 6, .operator = .reference_is_edge } }, &state);
    try std.testing.expect(!state.get(7).scalar.boolean);
    try Transfer.step(&e, 0, 0, 8, .{ .local_address = .{ .result = 8, .local = 1 } }, &state);
    try Transfer.step(&e, 0, 0, 9, .{ .unary = .{ .result = 9, .operand = 8, .operator = .reference_is_edge } }, &state);
    try std.testing.expect(!state.get(9).scalar.boolean);
    try Transfer.step(&e, 0, 0, 10, .{ .reference_field = .{ .result = 10, .reference = 8, .structure = 1, .field = 0 } }, &state);
    try Transfer.step(&e, 0, 0, 11, .{ .unary = .{ .result = 11, .operand = 10, .operator = .reference_is_edge } }, &state);
    try std.testing.expect(!state.get(11).scalar.boolean);
    try std.testing.expectEqualSlices(usize, state.get(4).nodes, state.get(10).nodes);
    try std.testing.expect(!Shape.arguments(&e, &.{state.get(4)}, &.{state.get(10)}, e.nodes.items.len));
    try Transfer.step(&e, 0, 0, 12, .{ .reference_optional = .{ .result = 12, .reference = 4 } }, &state);
    try Transfer.step(&e, 0, 0, 13, .{ .unary = .{ .result = 13, .operand = 12, .operator = .reference_is_edge } }, &state);
    try std.testing.expect(state.get(13).scalar.boolean);
    try state.set(a, 14, try M.Value.join(state.get(4), state.get(10), a));
    try Transfer.step(&e, 0, 0, 15, .{ .unary = .{ .result = 15, .operand = 14, .operator = .reference_is_edge } }, &state);
    try std.testing.expect(state.get(15).scalar == .unknown);
}
test "callback references retain unknown ownership beside a known reference" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    var root = try M.Value.one(a, 0);
    root.reference_domain = .root;
    const unknown = M.unknownValue(.{ .functions = &.{} }, .address);
    try std.testing.expect((try M.Value.join(root, unknown, a)).reference_domain == .unknown);
    try std.testing.expect((try M.Value.join(.{}, root, a)).reference_domain == .root);
    var other = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer other.deinit();
    const owned = try root.own(other.allocator());
    try std.testing.expect(owned.reference_domain == .root);
    try std.testing.expect(M.Value.eql(owned, root));
}

test "callback class receiver disjunction preserves every returned identity" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const functions = &[_]Ir.Function{
        .{ .name = "root", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{} },
        .{ .name = "identity", .parameter_types = &.{.structure(0)}, .return_type = .structure(0), .value_types = &.{.structure(0)}, .blocks = &.{.{ .instructions = &.{}, .terminator = .{ .return_value = 0 } }} },
    };
    const program: Ir.Program = .{ .functions = functions, .structures = &.{.{ .name = "Item", .is_class = true, .fields = &.{} }} };
    var capable = try M.emptyTypes(a, program);
    capable.structures[0] = true;
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = program, .capable = capable, .relevant = &.{ true, true }, .borrowed = &.{ false, false }, .generators = &.{ true, true } };
    try e.nodes.append(a, .{ .object = .{ .type = null, .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(0), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(0), .many = false } });
    var root: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0, .active = true, .allocator = a };
    try e.frames.append(a, &root);
    const input = try M.Value.join(try M.Value.one(a, 1), try M.Value.one(a, 2), a);
    var memory: M.Memory = .empty;
    const returned = try e.invoke(0, 0, 1, &.{input}, &memory);
    try std.testing.expectEqualSlices(usize, &.{ 1, 2 }, returned.nodes);
}

test "callback local address privacy excludes captures forwarding and inline projections" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const instructions = &[_]Ir.Instruction{
        .{ .local_address = .{ .result = 0, .local = 0 } },
        .{ .reference_field = .{ .result = 1, .reference = 0, .structure = 0, .field = 0 } },
        .{ .local_address = .{ .result = 2, .local = 1 } },
        .{ .function_reference = .{ .result = 3, .function = 0, .captures = &.{2} } },
        .{ .local_address = .{ .result = 4, .local = 2 } },
        .{ .call = .{ .result = null, .function = 0, .arguments = &.{4} } },
        .{ .local_address = .{ .result = 5, .local = 3 } },
        .{ .reference_field = .{ .result = 6, .reference = 5, .structure = 1, .field = 0 } },
    };
    const f: Ir.Function = .{ .name = "privacy", .parameter_types = &.{}, .return_type = .void, .value_types = &.{ .address, .address, .address, .function(0), .address, .address, .address }, .local_types = &.{ .structure(0), .structure(0), .structure(0), .structure(1) }, .blocks = &.{.{ .instructions = instructions, .terminator = .return_void }} };
    const program: Ir.Program = .{ .functions = &.{f}, .structures = &.{
        .{ .name = "Class", .is_class = true, .fields = &.{.{ .name = "value", .mutable = true, .type = .int }} },
        .{ .name = "Value", .fields = &.{.{ .name = "value", .mutable = true, .type = .int }} },
    } };
    const flags = try @import("Semantic/CallbackFlow/Locals.zig").privateCells(a, program, 0);
    try std.testing.expectEqualSlices(bool, &.{ true, false, false, false }, flags);
}

test "callback private addressed cells stay in invocation state and shared cells remain visible" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const f: Ir.Function = .{ .name = "locals", .parameter_types = &.{}, .return_type = .void, .value_types = &.{ .structure(0), .structure(0), .address, .structure(0) }, .local_types = &.{ .structure(0), .structure(0) }, .blocks = &.{} };
    const program: Ir.Program = .{ .functions = &.{f}, .structures = &.{.{ .name = "Item", .is_class = true, .fields = &.{} }} };
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = program, .capable = try M.emptyTypes(a, program), .relevant = &.{}, .borrowed = &.{}, .generators = &.{} };
    try e.nodes.append(a, .{ .object = .{ .type = null, .many = true } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(0), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(0), .many = false } });
    var frame: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0, .unaliased_locals = &.{ true, false } };
    try e.frames.append(a, &frame);
    var state: M.State = .{ .memory = .empty };
    try state.set(a, 0, try M.Value.one(a, 1));
    try state.set(a, 1, try M.Value.one(a, 2));
    try Transfer.step(&e, 0, 0, 0, .{ .local_store = .{ .local = 0, .operand = 0 } }, &state);
    try Transfer.step(&e, 0, 0, 1, .{ .local_store = .{ .local = 1, .operand = 0 } }, &state);
    try Transfer.step(&e, 0, 0, 2, .{ .local_store = .{ .local = 0, .operand = 1 } }, &state);
    try Transfer.step(&e, 0, 0, 3, .{ .local_store = .{ .local = 1, .operand = 1 } }, &state);
    try std.testing.expect(state.memory.get(.{ .object = 0, .field = 0 }) == null);
    try std.testing.expectEqualSlices(usize, &.{ 1, 2 }, state.memory.get(.{ .object = 0, .field = 1 }).?.nodes);
    try Transfer.step(&e, 0, 0, 4, .{ .local_address = .{ .result = 2, .local = 0 } }, &state);
    try Transfer.step(&e, 0, 0, 5, .{ .reference_load = .{ .result = 3, .reference = 2 } }, &state);
    try std.testing.expectEqualSlices(usize, &.{2}, state.get(3).nodes);
    try Transfer.step(&e, 0, 0, 6, .{ .reference_store = .{ .reference = 2, .operand = 0 } }, &state);
    try Transfer.step(&e, 0, 0, 7, .{ .reference_load = .{ .result = 3, .reference = 2 } }, &state);
    try std.testing.expectEqualSlices(usize, &.{1}, state.get(3).nodes);
}

test "callback collection resource loops retain each fixed element exactly once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const body = &[_]Ir.Block{
        .{ .instructions = &.{ .{ .constant_int = .{ .result = 2, .bits = 0 } }, .{ .local_store = .{ .local = 0, .operand = 2 } }, .{ .constant_int = .{ .result = 1, .bits = 2 } } }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{ .{ .local_load = .{ .result = 3, .local = 0 } }, .{ .binary = .{ .result = 4, .operator = .less, .left = 3, .right = 1 } } }, .terminator = .{ .branch = .{ .condition = 4, .then_block = 2, .else_block = 3 } } },
        .{ .instructions = &.{ .{ .collection_load = .{ .result = 5, .collection = 0, .index = 3, .position = .{ .offset = 0, .line = 1, .column = 1 } } }, .{ .class_retain = .{ .operand = 5 } }, .{ .constant_int = .{ .result = 6, .bits = 1 } }, .{ .binary = .{ .result = 7, .operator = .add, .left = 3, .right = 6, .checked = false } }, .{ .local_store = .{ .local = 0, .operand = 7 } } }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .return_void },
    };
    const functions = &[_]Ir.Function{
        .{ .name = "root", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{} },
        .{ .name = "retain_elements", .parameter_types = &.{.structure(0)}, .return_type = .void, .value_types = &.{ .structure(0), .int, .int, .int, .bool, .structure(1), .int, .int }, .local_types = &.{.int}, .blocks = body },
    };
    const program: Ir.Program = .{ .functions = functions, .structures = &.{
        .{ .name = "Items", .fields = &.{}, .collection = .{ .element = .structure(1), .length = 2 } },
        .{ .name = "Item", .is_class = true, .fields = &.{} },
    } };
    var capable = try M.emptyTypes(a, program);
    capable.structures[0] = true;
    capable.structures[1] = true;
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = program, .capable = capable, .relevant = &.{ true, true }, .borrowed = &.{ false, false }, .generators = &.{ true, true }, .resource_loops = try @import("Semantic/CallbackFlow/ResourceLoops.zig").program(a, program) };
    try e.nodes.append(a, .{ .object = .{ .type = null, .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(0), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    var root: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0, .active = true, .allocator = a };
    try e.frames.append(a, &root);
    var memory: M.Memory = .empty;
    try memory.put(a, .{ .object = 1, .field = 0 }, try M.Value.one(a, 2));
    try memory.put(a, .{ .object = 1, .field = 1 }, try M.Value.one(a, 3));
    _ = try e.invoke(0, 0, 1, &.{try M.Value.one(a, 1)}, &memory);
    try std.testing.expectEqual(@as(usize, 1), memory.owners.get(2).?.roots.low);
    try std.testing.expectEqual(@as(usize, 1), memory.owners.get(3).?.roots.low);
}

test "callback collection loops retain fixed backing elements through a dynamic view" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const body = &[_]Ir.Block{
        .{ .instructions = &.{ .{ .constant_int = .{ .result = 2, .bits = 0 } }, .{ .local_store = .{ .local = 0, .operand = 2 } }, .{ .collection_count = .{ .result = 1, .collection = 0 } } }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{ .{ .local_load = .{ .result = 3, .local = 0 } }, .{ .binary = .{ .result = 4, .operator = .less, .left = 3, .right = 1 } } }, .terminator = .{ .branch = .{ .condition = 4, .then_block = 2, .else_block = 3 } } },
        .{ .instructions = &.{ .{ .collection_load = .{ .result = 5, .collection = 0, .index = 3, .position = .{ .offset = 0, .line = 1, .column = 1 } } }, .{ .class_retain = .{ .operand = 5 } }, .{ .constant_int = .{ .result = 6, .bits = 1 } }, .{ .binary = .{ .result = 7, .operator = .add, .left = 3, .right = 6, .checked = false } }, .{ .local_store = .{ .local = 0, .operand = 7 } } }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .return_void },
    };
    const functions = &[_]Ir.Function{
        .{ .name = "root", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{} },
        .{ .name = "retain_elements", .parameter_types = &.{.structure(0)}, .return_type = .void, .value_types = &.{ .structure(0), .int, .int, .int, .bool, .structure(1), .int, .int }, .local_types = &.{.int}, .blocks = body },
    };
    const program: Ir.Program = .{ .functions = functions, .structures = &.{
        .{ .name = "Items", .fields = &.{}, .collection = .{ .element = .structure(1), .length = null } },
        .{ .name = "Item", .is_class = true, .fields = &.{} },
        .{ .name = "Backing", .fields = &.{}, .collection = .{ .element = .structure(1), .length = 2 } },
    } };
    var capable = try M.emptyTypes(a, program);
    capable.structures[0] = true;
    capable.structures[1] = true;
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = program, .capable = capable, .relevant = &.{ true, true }, .borrowed = &.{ false, false }, .generators = &.{ true, true }, .resource_loops = try @import("Semantic/CallbackFlow/ResourceLoops.zig").program(a, program) };
    try e.nodes.append(a, .{ .object = .{ .type = null, .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(2), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    var root: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0, .active = true, .allocator = a };
    try e.frames.append(a, &root);
    var memory: M.Memory = .empty;
    try memory.put(a, .{ .object = 1, .field = 0 }, try M.Value.one(a, 2));
    try memory.put(a, .{ .object = 1, .field = 1 }, try M.Value.one(a, 3));
    _ = try e.invoke(0, 0, 1, &.{try M.Value.one(a, 1)}, &memory);
    try std.testing.expectEqual(@as(usize, 1), memory.owners.get(2).?.roots.low);
    try std.testing.expectEqual(@as(usize, 1), memory.owners.get(3).?.roots.low);
}

test "callback collection resource loops release each fixed element exactly once" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const body = &[_]Ir.Block{
        .{ .instructions = &.{ .{ .constant_int = .{ .result = 1, .bits = 2 } }, .{ .local_store = .{ .local = 0, .operand = 1 } } }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{ .{ .local_load = .{ .result = 3, .local = 0 } }, .{ .constant_int = .{ .result = 2, .bits = 0 } }, .{ .binary = .{ .result = 4, .operator = .not_equal, .left = 3, .right = 2 } } }, .terminator = .{ .branch = .{ .condition = 4, .then_block = 2, .else_block = 3 } } },
        .{ .instructions = &.{ .{ .constant_int = .{ .result = 6, .bits = 1 } }, .{ .binary = .{ .result = 7, .operator = .subtract, .left = 3, .right = 6, .checked = false } }, .{ .local_store = .{ .local = 0, .operand = 7 } }, .{ .collection_load = .{ .result = 5, .collection = 0, .index = 7, .position = .{ .offset = 0, .line = 1, .column = 1 } } }, .{ .class_drop = .{ .operand = 5, .static_type = 1, .plans = &.{.{ .structure = 1, .functions = &.{} }} } } }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .return_void },
    };
    const functions = &[_]Ir.Function{
        .{ .name = "root", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{} },
        .{ .name = "drop_elements", .parameter_types = &.{.structure(0)}, .return_type = .void, .value_types = &.{ .structure(0), .int, .int, .int, .bool, .structure(1), .int, .int }, .local_types = &.{.int}, .blocks = body },
    };
    const program: Ir.Program = .{ .functions = functions, .structures = &.{
        .{ .name = "Items", .fields = &.{}, .collection = .{ .element = .structure(1), .length = 2 } },
        .{ .name = "Item", .is_class = true, .fields = &.{} },
    } };
    var capable = try M.emptyTypes(a, program);
    capable.structures[0] = true;
    capable.structures[1] = true;
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = program, .capable = capable, .relevant = &.{ true, true }, .borrowed = &.{ false, false }, .generators = &.{ true, true }, .resource_loops = try @import("Semantic/CallbackFlow/ResourceLoops.zig").program(a, program) };
    try e.nodes.append(a, .{ .object = .{ .type = null, .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(0), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    var root: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0, .active = true, .allocator = a };
    try e.frames.append(a, &root);
    var memory: M.Memory = .empty;
    try memory.put(a, .{ .object = 1, .field = 0 }, try M.Value.one(a, 2));
    try memory.put(a, .{ .object = 1, .field = 1 }, try M.Value.one(a, 3));
    try memory.owners.put(a, 2, .{ .roots = .{ .low = 1, .high = 1 } });
    try memory.owners.put(a, 3, .{ .roots = .{ .low = 1, .high = 1 } });
    _ = try e.invoke(0, 0, 1, &.{try M.Value.one(a, 1)}, &memory);
    try std.testing.expectEqual(@as(usize, 0), memory.owners.get(2).?.roots.high);
    try std.testing.expect(memory.owners.get(2).?.lifetime == .finalized);
    try std.testing.expectEqual(@as(usize, 0), memory.owners.get(3).?.roots.high);
    try std.testing.expect(memory.owners.get(3).?.lifetime == .finalized);
}

test "callback collection loops keep unknown backing counts conservative" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const body = &[_]Ir.Block{
        .{ .instructions = &.{ .{ .constant_int = .{ .result = 2, .bits = 0 } }, .{ .local_store = .{ .local = 0, .operand = 2 } }, .{ .collection_count = .{ .result = 1, .collection = 0 } } }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{ .{ .local_load = .{ .result = 3, .local = 0 } }, .{ .binary = .{ .result = 4, .operator = .less, .left = 3, .right = 1 } } }, .terminator = .{ .branch = .{ .condition = 4, .then_block = 2, .else_block = 3 } } },
        .{ .instructions = &.{ .{ .collection_load = .{ .result = 5, .collection = 0, .index = 3, .position = .{ .offset = 0, .line = 1, .column = 1 } } }, .{ .class_retain = .{ .operand = 5 } }, .{ .constant_int = .{ .result = 6, .bits = 1 } }, .{ .binary = .{ .result = 7, .operator = .add, .left = 3, .right = 6, .checked = false } }, .{ .local_store = .{ .local = 0, .operand = 7 } } }, .terminator = .{ .jump = 1 } },
        .{ .instructions = &.{}, .terminator = .return_void },
    };
    const functions = &[_]Ir.Function{
        .{ .name = "root", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{} },
        .{ .name = "retain_elements", .parameter_types = &.{.structure(0)}, .return_type = .void, .value_types = &.{ .structure(0), .int, .int, .int, .bool, .structure(1), .int, .int }, .local_types = &.{.int}, .blocks = body },
    };
    const program: Ir.Program = .{ .functions = functions, .structures = &.{
        .{ .name = "Items", .fields = &.{}, .collection = .{ .element = .structure(1), .length = null } },
        .{ .name = "Item", .is_class = true, .fields = &.{} },
        .{ .name = "Backing", .fields = &.{}, .collection = .{ .element = .structure(1), .length = 2 } },
    } };
    var capable = try M.emptyTypes(a, program);
    capable.structures[0] = true;
    capable.structures[1] = true;
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = program, .capable = capable, .relevant = &.{ true, true }, .borrowed = &.{ false, false }, .generators = &.{ true, true }, .resource_loops = try @import("Semantic/CallbackFlow/ResourceLoops.zig").program(a, program) };
    try e.nodes.append(a, .{ .object = .{ .type = null, .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(0), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    try e.nodes.append(a, .{ .object = .{ .type = .structure(1), .many = false } });
    var root: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0, .active = true, .allocator = a };
    try e.frames.append(a, &root);
    var memory: M.Memory = .empty;
    try memory.put(a, .{ .object = 1, .field = 0 }, try M.Value.one(a, 2));
    try memory.put(a, .{ .object = 1, .field = 1 }, try M.Value.one(a, 3));
    _ = try e.invoke(0, 0, 1, &.{try M.Value.one(a, 1)}, &memory);
    try std.testing.expectEqual(@as(usize, 0), memory.owners.get(2).?.roots.low);
    try std.testing.expectEqual(@as(usize, 0), memory.owners.get(3).?.roots.low);
}

test "callback collection edits preserve exact positions and counts" {
    const Case = struct { kind: Ir.Instruction.ListEditKind, expected: []const usize, removed: ?usize = null };
    const cases = [_]Case{
        .{ .kind = .append, .expected = &.{ 2, 3, 5 } },
        .{ .kind = .prepend, .expected = &.{ 5, 2, 3 } },
        .{ .kind = .insert, .expected = &.{ 2, 5, 3 } },
        .{ .kind = .take, .expected = &.{2}, .removed = 3 },
        .{ .kind = .take_first, .expected = &.{3}, .removed = 2 },
        .{ .kind = .take_last, .expected = &.{2}, .removed = 3 },
        .{ .kind = .clear, .expected = &.{} },
        .{ .kind = .reverse, .expected = &.{ 3, 2 } },
        .{ .kind = .append_sequence, .expected = &.{ 2, 3, 5, 6 } },
    };
    for (cases) |case| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const a = arena.allocator();
        const f: Ir.Function = .{ .name = "edit", .parameter_types = &.{}, .return_type = .void, .value_types = &.{ .structure(0), if (case.kind == .append_sequence) .structure(0) else .structure(1), .structure(0), .structure(1), .int }, .blocks = &.{.{ .instructions = &.{.{ .constant_int = .{ .result = 4, .bits = 1 } }}, .terminator = .return_void }} };
        const p: Ir.Program = .{ .functions = &.{f}, .structures = &.{ .{ .name = "Items", .fields = &.{}, .collection = .{ .element = .structure(1), .length = null } }, .{ .name = "Item", .is_class = true, .fields = &.{} } } };
        var capable = try M.emptyTypes(a, p);
        capable.structures[0] = true;
        capable.structures[1] = true;
        var e: Flow.Engine = .{ .a = a, .storage = a, .program = p, .capable = capable, .relevant = &.{true}, .borrowed = &.{false}, .generators = &.{true} };
        for (0..7) |i| try e.nodes.append(a, .{ .object = .{ .type = if (i == 1 or i == 4) .structure(0) else .structure(1), .many = false, .length = if (i == 1 or i == 4) 2 else null } });
        var frame: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0, .unaliased_locals = &.{} };
        try e.frames.append(a, &frame);
        var state: M.State = .{ .memory = .empty };
        try state.memory.put(a, .{ .object = 1, .field = 0 }, try M.Value.one(a, 2));
        try state.memory.put(a, .{ .object = 1, .field = 1 }, try M.Value.one(a, 3));
        try state.memory.put(a, .{ .object = 4, .field = 0 }, try M.Value.one(a, 5));
        try state.memory.put(a, .{ .object = 4, .field = 1 }, try M.Value.one(a, 6));
        try state.set(a, 0, try M.Value.one(a, 1));
        try state.set(a, 1, try M.Value.one(a, if (case.kind == .append_sequence) 4 else 5));
        try Transfer.step(&e, 0, 0, 0, .{ .list_edit = .{ .result = 2, .collection = 0, .kind = case.kind, .index = if (case.kind == .insert or case.kind == .take) 4 else null, .argument = if (case.kind == .append or case.kind == .prepend or case.kind == .insert or case.kind == .append_sequence) 1 else null, .removed = if (case.removed != null) 3 else null, .position = .{ .offset = 0, .line = 1, .column = 1 } } }, &state);
        try std.testing.expectEqual(case.expected.len, e.collectionLength(state.get(2)).?);
        for (case.expected, 0..) |id, i| try std.testing.expectEqualSlices(usize, &.{id}, (try e.field(&state.memory, state.get(2), i, .structure(1))).nodes);
        if (case.removed) |id| try std.testing.expectEqualSlices(usize, &.{id}, state.get(3).nodes);
    }
}

test "callback unknown sequence append keeps elements instead of the array object" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const f: Ir.Function = .{ .name = "append", .parameter_types = &.{}, .return_type = .void, .value_types = &.{ .structure(0), .structure(0), .structure(0) }, .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }} };
    const p: Ir.Program = .{ .functions = &.{f}, .structures = &.{ .{ .name = "Items", .fields = &.{}, .collection = .{ .element = .structure(1), .length = null } }, .{ .name = "Item", .is_class = true, .fields = &.{} } } };
    var capable = try M.emptyTypes(a, p);
    capable.structures[0] = true;
    capable.structures[1] = true;
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = p, .capable = capable, .relevant = &.{true}, .borrowed = &.{false}, .generators = &.{true} };
    for (0..7) |i| try e.nodes.append(a, .{ .object = .{ .type = if (i == 1 or i == 4) .structure(0) else .structure(1), .many = false } });
    var frame: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = 0, .unaliased_locals = &.{} };
    try e.frames.append(a, &frame);
    var state: M.State = .{ .memory = .empty };
    try state.memory.put(a, .{ .object = 1, .field = 0 }, try M.Value.one(a, 2));
    try state.memory.put(a, .{ .object = 1, .field = 1 }, try M.Value.one(a, 3));
    try state.memory.put(a, .{ .object = 4, .field = 0 }, try M.Value.one(a, 5));
    try state.memory.put(a, .{ .object = 4, .field = 1 }, try M.Value.one(a, 6));
    try state.set(a, 0, try M.Value.one(a, 1));
    try state.set(a, 1, try M.Value.one(a, 4));
    try Transfer.step(&e, 0, 0, 0, .{ .list_edit = .{ .result = 2, .collection = 0, .kind = .append_sequence, .argument = 1, .position = .{ .offset = 0, .line = 1, .column = 1 } } }, &state);
    try std.testing.expect(e.collectionLength(state.get(2)) == null);
    try std.testing.expectEqualSlices(usize, &.{ 2, 3, 5, 6 }, (try e.elements(&state.memory, state.get(2))).nodes);
}

test "callback native mutations invalidate mutable controls and preserve immutable fields" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const p: Ir.Program = .{
        .structures = &.{.{ .name = "Control", .is_class = true, .fields = &.{
            .{ .name = "enabled", .type = .bool, .mutable = true },
            .{ .name = "fixed", .type = .bool, .mutable = false },
        } }},
        .functions = &.{.{ .name = "root", .parameter_types = &.{}, .return_type = .void, .value_types = &.{ .address, .int, .bool, .address }, .blocks = &.{} }},
    };
    var e: Flow.Engine = .{ .a = a, .storage = a, .program = p, .capable = try M.emptyTypes(a, p), .relevant = &.{}, .borrowed = &.{}, .generators = &.{} };
    const object = try e.object(0, .object, 1, .structure(0), false);
    var frame: M.Frame = .{ .function = 0, .parent = null, .site = 0, .locals = object };
    try e.frames.append(a, &frame);
    const cell: M.Cell = .{ .object = object, .field = 0 };
    const fixed: M.Cell = .{ .object = object, .field = 1 };
    const operations = [_]Ir.Instruction{
        .{ .boundary_call = .{ .result = 3, .function = 0, .arguments = &.{0} } },
        .{ .boundary_indirect_call = .{ .result = 3, .callee = 3, .signature = 0, .arguments = &.{0} } },
        .{ .address_store = .{ .address = 0, .byte_offset = 1, .operand = 2, .type = .bool } },
    };
    for (operations, 0..) |op, index| {
        var state: M.State = .{ .memory = .empty };
        try e.write(&state.memory, cell, .{ .scalar = .{ .boolean = false } }, true);
        try e.write(&state.memory, fixed, .{ .scalar = .{ .boolean = false } }, true);
        try state.set(a, 0, try e.address(cell));
        try Transfer.step(&e, 0, 0, index, op, &state);
        try std.testing.expect(state.memory.get(cell).?.scalar == .unknown);
        try std.testing.expectEqual(false, state.memory.get(fixed).?.scalar.boolean);
        if (op != .address_store) try std.testing.expectEqual(M.ReferenceDomain.unknown, state.get(3).reference_domain);
    }
}

test "callback native control effects propagate through helpers with erased scalar addresses" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const operations = [_]Ir.Instruction{
        .{ .boundary_call = .{ .result = null, .function = 0, .arguments = &.{0} } },
        .{ .boundary_indirect_call = .{ .result = null, .callee = 0, .signature = 0, .arguments = &.{0} } },
        .{ .address_store = .{ .address = 0, .byte_offset = 1, .operand = 2, .type = .bool } },
    };
    for (operations) |op| {
        const p: Ir.Program = .{ .functions = &.{
            .{ .name = "origin", .parameter_types = &.{}, .return_type = .void, .value_types = &.{}, .blocks = &.{.{ .instructions = &.{}, .terminator = .return_void }} },
            .{ .name = "forward", .parameter_types = &.{.address}, .return_type = .void, .value_types = &.{.address}, .blocks = &.{.{ .instructions = &.{.{ .call = .{ .result = null, .function = 2, .arguments = &.{0} } }}, .terminator = .return_void }} },
            .{ .name = "native_set", .parameter_types = &.{.address}, .return_type = .void, .value_types = &.{ .address, .int, .bool }, .blocks = &.{.{ .instructions = try a.dupe(Ir.Instruction, &.{op}), .terminator = .return_void }} },
        } };
        const domain = try @import("Semantic/CallbackFlow/Domain.zig").forOrigin(a, p, 0);
        for ([_]usize{ 1, 2 }) |id| {
            try std.testing.expect(domain.relevant[id]);
            try std.testing.expect(domain.generators[id]);
        }
    }
}
