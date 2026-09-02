const std = @import("std");
const Ir = @import("Ir.zig");

const Allocator = std.mem.Allocator;

pub const Scope = struct {
    program: Ir.Program,
    old_to_new: []const ?Ir.FunctionId,

    pub fn function(self: Scope, original: Ir.FunctionId) ?Ir.FunctionId {
        if (original >= self.old_to_new.len) return null;
        return self.old_to_new[original];
    }
};

/// Closes an executable program from its unique semantic entry point. The
/// resulting function order follows the original IR order so diagnostics and
/// native emission remain deterministic across hosts.
pub fn executable(allocator: Allocator, program: Ir.Program) Ir.Error!Scope {
    var entry: ?Ir.FunctionId = null;
    for (program.functions, 0..) |function, function_id| {
        if (!std.mem.eql(u8, function.name, "main")) continue;
        if (entry != null) return error.InvalidProgram;
        entry = function_id;
    }
    const root = entry orelse return error.InvalidProgram;
    return close(allocator, program, &.{root});
}

/// Retains every function that can be observed from the explicit roots. All
/// function-bearing IR operations are followed conservatively, including
/// callbacks, dynamic implementations and class finalizers.
pub fn close(allocator: Allocator, program: Ir.Program, roots: []const Ir.FunctionId) Ir.Error!Scope {
    const reachable = try allocator.alloc(bool, program.functions.len);
    @memset(reachable, false);
    var pending: std.ArrayList(Ir.FunctionId) = .empty;
    for (roots) |root| try mark(allocator, program, reachable, &pending, root);

    var cursor: usize = 0;
    while (cursor < pending.items.len) : (cursor += 1) {
        const function = program.functions[pending.items[cursor]];
        for (function.blocks) |block| {
            for (block.instructions) |instruction| {
                try markInstructionTargets(allocator, program, reachable, &pending, instruction);
            }
        }
    }

    const old_to_new = try allocator.alloc(?Ir.FunctionId, program.functions.len);
    @memset(old_to_new, null);
    var function_count: usize = 0;
    for (reachable, 0..) |retained, old_id| if (retained) {
        old_to_new[old_id] = function_count;
        function_count += 1;
    };

    const functions = try allocator.alloc(Ir.Function, function_count);
    var next: usize = 0;
    for (program.functions, 0..) |function, old_id| {
        if (!reachable[old_id]) continue;
        functions[next] = try rewriteFunction(allocator, function, old_to_new);
        next += 1;
    }
    var scoped = program;
    scoped.functions = functions;
    return .{ .program = scoped, .old_to_new = old_to_new };
}

fn mark(
    allocator: Allocator,
    program: Ir.Program,
    reachable: []bool,
    pending: *std.ArrayList(Ir.FunctionId),
    function: Ir.FunctionId,
) Ir.Error!void {
    if (function >= program.functions.len) return error.InvalidProgram;
    if (reachable[function]) return;
    reachable[function] = true;
    try pending.append(allocator, function);
}

fn markInstructionTargets(
    allocator: Allocator,
    program: Ir.Program,
    reachable: []bool,
    pending: *std.ArrayList(Ir.FunctionId),
    instruction: Ir.Instruction,
) Ir.Error!void {
    switch (instruction) {
        .call => |call| try mark(allocator, program, reachable, pending, call.function),
        .function_reference => |reference| try mark(allocator, program, reachable, pending, reference.function),
        .dynamic_call => |call| {
            try mark(allocator, program, reachable, pending, call.function);
            for (call.implementations) |implementation| {
                try mark(allocator, program, reachable, pending, implementation.function);
            }
        },
        .class_drop => |drop| for (drop.plans) |plan| for (plan.functions) |finalizer| {
            try mark(allocator, program, reachable, pending, finalizer.function);
        },
        else => {},
    }
}

fn rewriteFunction(allocator: Allocator, function: Ir.Function, old_to_new: []const ?Ir.FunctionId) Ir.Error!Ir.Function {
    const blocks = try allocator.alloc(Ir.Block, function.blocks.len);
    for (function.blocks, 0..) |block, block_id| {
        const instructions = try allocator.alloc(Ir.Instruction, block.instructions.len);
        for (block.instructions, 0..) |instruction, instruction_id| {
            instructions[instruction_id] = try rewriteInstruction(allocator, instruction, old_to_new);
        }
        blocks[block_id] = block;
        blocks[block_id].instructions = instructions;
    }
    var rewritten = function;
    rewritten.blocks = blocks;
    return rewritten;
}

fn rewriteInstruction(allocator: Allocator, instruction: Ir.Instruction, old_to_new: []const ?Ir.FunctionId) Ir.Error!Ir.Instruction {
    return switch (instruction) {
        .call => |call| .{ .call = .{
            .result = call.result,
            .function = try remap(old_to_new, call.function),
            .arguments = call.arguments,
        } },
        .function_reference => |reference| .{ .function_reference = .{
            .result = reference.result,
            .function = try remap(old_to_new, reference.function),
            .captures = reference.captures,
        } },
        .dynamic_call => |call| dynamic: {
            const implementations = try allocator.alloc(Ir.Instruction.DynamicCall.Implementation, call.implementations.len);
            for (call.implementations, 0..) |implementation, index| {
                implementations[index] = .{
                    .structure = implementation.structure,
                    .function = try remap(old_to_new, implementation.function),
                };
            }
            break :dynamic .{ .dynamic_call = .{
                .result = call.result,
                .function = try remap(old_to_new, call.function),
                .receiver = call.receiver,
                .arguments = call.arguments,
                .implementations = implementations,
            } };
        },
        .class_drop => |drop| class_drop: {
            const plans = try allocator.alloc(Ir.Instruction.ClassDrop.Plan, drop.plans.len);
            for (drop.plans, 0..) |plan, plan_index| {
                const finalizers = try allocator.alloc(Ir.Instruction.ClassDrop.Finalizer, plan.functions.len);
                for (plan.functions, 0..) |finalizer, finalizer_index| {
                    finalizers[finalizer_index] = .{
                        .structure = finalizer.structure,
                        .function = try remap(old_to_new, finalizer.function),
                    };
                }
                plans[plan_index] = .{ .structure = plan.structure, .functions = finalizers };
            }
            break :class_drop .{ .class_drop = .{
                .operand = drop.operand,
                .ownership = drop.ownership,
                .skip_cycle = drop.skip_cycle,
                .static_type = drop.static_type,
                .plans = plans,
            } };
        },
        else => instruction,
    };
}

fn remap(old_to_new: []const ?Ir.FunctionId, original: Ir.FunctionId) Ir.Error!Ir.FunctionId {
    if (original >= old_to_new.len) return error.InvalidProgram;
    return old_to_new[original] orelse error.InvalidProgram;
}

fn testFunction(name: []const u8, instructions: []const Ir.Instruction) Ir.Function {
    const blocks = [_]Ir.Block{.{ .instructions = instructions, .terminator = .return_void }};
    return .{
        .name = name,
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{},
        .blocks = &blocks,
    };
}

test "close executable removes unreachable functions and remaps direct recursion" {
    const main_instructions = [_]Ir.Instruction{.{ .call = .{ .result = null, .function = 2, .arguments = &.{} } }};
    const dead_instructions = [_]Ir.Instruction{};
    const recursive_instructions = [_]Ir.Instruction{.{ .call = .{ .result = null, .function = 2, .arguments = &.{} } }};
    const functions = [_]Ir.Function{
        testFunction("main", &main_instructions),
        testFunction("backend_sentinel", &dead_instructions),
        testFunction("reachable", &recursive_instructions),
    };
    const scope = try executable(std.testing.allocator, .{ .functions = &functions });
    defer std.testing.allocator.free(scope.old_to_new);
    try std.testing.expectEqual(@as(usize, 2), scope.program.functions.len);
    try std.testing.expectEqualStrings("main", scope.program.functions[0].name);
    try std.testing.expectEqualStrings("reachable", scope.program.functions[1].name);
    try std.testing.expectEqual(@as(Ir.FunctionId, 1), scope.program.functions[0].blocks[0].instructions[0].call.function);
    try std.testing.expectEqual(@as(Ir.FunctionId, 1), scope.program.functions[1].blocks[0].instructions[0].call.function);
}

test "close follows callback dynamic and finalizer targets" {
    const implementations = [_]Ir.Instruction.DynamicCall.Implementation{.{ .structure = 0, .function = 3 }};
    const finalizers = [_]Ir.Instruction.ClassDrop.Finalizer{.{ .structure = 0, .function = 4 }};
    const plans = [_]Ir.Instruction.ClassDrop.Plan{.{ .structure = 0, .functions = &finalizers }};
    const root_instructions = [_]Ir.Instruction{
        .{ .function_reference = .{ .result = 0, .function = 1 } },
        .{ .dynamic_call = .{ .result = null, .function = 2, .receiver = 0, .arguments = &.{}, .implementations = &implementations } },
        .{ .class_drop = .{ .operand = 0, .static_type = 0, .plans = &plans } },
    };
    const empty = [_]Ir.Instruction{};
    const functions = [_]Ir.Function{
        testFunction("root", &root_instructions),
        testFunction("callback", &empty),
        testFunction("method", &empty),
        testFunction("override", &empty),
        testFunction("drop", &empty),
        testFunction("backend_sentinel", &empty),
    };
    const scope = try close(std.testing.allocator, .{ .functions = &functions }, &.{0});
    defer std.testing.allocator.free(scope.old_to_new);
    try std.testing.expectEqual(@as(usize, 5), scope.program.functions.len);
    try std.testing.expect(scope.function(5) == null);
    try std.testing.expectEqual(@as(Ir.FunctionId, 4), scope.function(4).?);
}

test "ARM64 and X64 consume the same closed portable program" {
    var frontend = @import("Frontend.zig").Frontend.init(std.testing.allocator);
    const compilation = try frontend.compile(
        \\func unreachable_backend_sentinel() {
        \\    print("SILEX_UNREACHABLE_BACKEND_SENTINEL")
        \\}
        \\func main() {
        \\    print("reachable")
        \\}
    );
    const scope = try executable(std.testing.allocator, compilation.ir);
    const machine = try @import("Arm64/Lower.zig").lowerWithMode(std.testing.allocator, scope.program, .release);
    try std.testing.expectEqual(scope.program.functions.len, machine.functions.len);
    for (machine.functions) |function| {
        try std.testing.expect(!std.mem.eql(u8, function.name, "unreachable_backend_sentinel"));
    }
    for (machine.strings) |string| {
        try std.testing.expect(!std.mem.eql(u8, string, "SILEX_UNREACHABLE_BACKEND_SENTINEL"));
    }

    var main_id: ?usize = null;
    for (machine.functions, 0..) |function, function_id| {
        if (std.mem.eql(u8, function.name, "main")) main_id = function_id;
    }
    var arm64 = try @import("Arm64/Encoder.zig").encode(std.testing.allocator, machine, .{ .executable_main = main_id.? });
    defer arm64.deinit(std.testing.allocator);
    var linux_x64 = try @import("X64/Encoder.zig").encodeLinux(std.testing.allocator, machine);
    defer linux_x64.deinit(std.testing.allocator);
    var windows_x64 = try @import("X64/Encoder.zig").encodeWindows(std.testing.allocator, machine);
    defer windows_x64.deinit(std.testing.allocator);
    try std.testing.expect(arm64.code.len != 0);
    try std.testing.expect(linux_x64.code.len != 0);
    try std.testing.expect(windows_x64.code.len != 0);
}
