const std = @import("std");
const Ir = @import("silex_optimizer_api").Ir;
const Coverage = @import("LlvmCoverage.zig");
const Allocator = std.mem.Allocator;
const Error = Allocator.Error || error{ InvalidProgram, UnsupportedInstruction };

// Portable IR uses virtual registers and edge copies, not LLVM SSA values.
// Give multiply-defined registers addressable homes, then let LLVM promote
// them itself. No Silex optimization is applied to the oracle's raw input.
pub fn lower(allocator: Allocator, original: Ir.Function) Error!Ir.Function {
    const definitions = try allocator.alloc(usize, original.value_types.len);
    @memset(definitions, 0);
    for (0..original.parameter_types.len) |index| definitions[index] = 1;
    for (original.blocks) |block| for (block.instructions) |instruction| {
        if (Coverage.classify(std.meta.activeTag(instruction)) == .unsupported)
            return error.UnsupportedInstruction;
        if (resultOf(instruction)) |result| {
            if (result >= definitions.len) return error.InvalidProgram;
            definitions[result] += 1;
        }
    };
    var state: State = .{ .allocator = allocator, .homes = try allocator.alloc(?Ir.LocalId, definitions.len) };
    defer state.types.deinit(allocator);
    try state.types.appendSlice(allocator, original.value_types);
    var locals: std.ArrayList(Ir.Type) = .empty;
    defer locals.deinit(allocator);
    try locals.appendSlice(allocator, original.local_types);
    for (definitions, 0..) |count, value| {
        state.homes[value] = if (count > 1) locals.items.len else null;
        if (count > 1) try locals.append(allocator, original.value_types[value]);
    }
    if (locals.items.len == original.local_types.len) return original;
    const blocks = try allocator.dupe(Ir.Block, original.blocks);
    for (blocks, 0..) |*block, index| {
        var instructions: std.ArrayList(Ir.Instruction) = .empty;
        if (index == 0) for (0..original.parameter_types.len) |parameter| {
            if (state.homes[parameter]) |local| try instructions.append(allocator, .{
                .local_store = .{ .local = local, .operand = parameter },
            });
        };
        for (block.instructions) |instruction| {
            var mapped = try state.operands(instruction, &instructions);
            const result = resultOf(instruction);
            if (result) |value| if (state.homes[value]) |_| {
                mapped = withResult(mapped, try state.fresh(value));
            };
            try instructions.append(allocator, mapped);
            if (result) |value| if (state.homes[value]) |local| {
                try instructions.append(allocator, .{ .local_store = .{ .local = local, .operand = resultOf(mapped).? } });
            };
        }
        switch (block.terminator) {
            .branch => |*branch| branch.condition = try state.read(branch.condition, &instructions),
            .return_value => |*value| value.* = try state.read(value.*, &instructions),
            else => {},
        }
        block.instructions = try instructions.toOwnedSlice(allocator);
    }
    var result = original;
    result.blocks = blocks;
    result.local_types = try locals.toOwnedSlice(allocator);
    result.value_types = try state.types.toOwnedSlice(allocator);
    return result;
}

const State = struct {
    allocator: Allocator,
    homes: []?Ir.LocalId,
    types: std.ArrayList(Ir.Type) = .empty,

    fn fresh(self: *State, original: Ir.ValueId) Error!Ir.ValueId {
        const id = self.types.items.len;
        try self.types.append(self.allocator, self.types.items[original]);
        return id;
    }

    fn read(self: *State, value: Ir.ValueId, instructions: *std.ArrayList(Ir.Instruction)) Error!Ir.ValueId {
        if (value >= self.homes.len) return error.InvalidProgram;
        const local = self.homes[value] orelse return value;
        const fresh_value = try self.fresh(value);
        try instructions.append(self.allocator, .{ .local_load = .{ .result = fresh_value, .local = local } });
        return fresh_value;
    }

    fn operands(self: *State, original: Ir.Instruction, instructions: *std.ArrayList(Ir.Instruction)) Error!Ir.Instruction {
        @setEvalBranchQuota(20000);
        switch (original) {
            inline else => |payload, tag| {
                if (@typeInfo(@TypeOf(payload)) != .@"struct") return original;
                var mapped = payload;
                inline for (@typeInfo(@TypeOf(payload)).@"struct".fields) |field| {
                    if (comptime operandField(field.name)) {
                        if (field.type == Ir.ValueId) {
                            @field(mapped, field.name) = try self.read(@field(payload, field.name), instructions);
                        } else if (field.type == ?Ir.ValueId) {
                            if (@field(payload, field.name)) |value|
                                @field(mapped, field.name) = try self.read(value, instructions);
                        }
                    } else if (comptime std.mem.eql(u8, field.name, "arguments") or
                        std.mem.eql(u8, field.name, "values") or std.mem.eql(u8, field.name, "fields"))
                    {
                        if (field.type == []const Ir.ValueId) {
                            const values = try self.allocator.dupe(Ir.ValueId, @field(payload, field.name));
                            for (values) |*value| value.* = try self.read(value.*, instructions);
                            @field(mapped, field.name) = values;
                        }
                    }
                }
                return @unionInit(Ir.Instruction, @tagName(tag), mapped);
            },
        }
    }
};

fn operandField(comptime name: []const u8) bool {
    inline for (.{ "operand", "left", "right", "value", "base", "index", "collection", "reference", "replacement", "start", "end" }) |candidate|
        if (std.mem.eql(u8, name, candidate)) return true;
    return false;
}

fn resultOf(instruction: Ir.Instruction) ?Ir.ValueId {
    return switch (instruction) {
        inline else => |payload| if (@typeInfo(@TypeOf(payload)) == .@"struct" and @hasField(@TypeOf(payload), "result")) payload.result else null,
    };
}

fn withResult(instruction: Ir.Instruction, value: Ir.ValueId) Ir.Instruction {
    switch (instruction) {
        inline else => |payload, tag| {
            var mapped = payload;
            if (@typeInfo(@TypeOf(payload)) == .@"struct" and @hasField(@TypeOf(payload), "result")) mapped.result = value;
            return @unionInit(Ir.Instruction, @tagName(tag), mapped);
        },
    }
}

test "virtual register homes preserve short circuit effects and loop edge copies" {
    const Silex = @import("silex_optimizer_api");
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const differential = try @import("Differential.zig").verify(a,
        \\struct Counter { var value:int }
        \\func touch(counter:&Counter, value:bool) bool { counter.value += 1; return value }
        \\func choose(first:bool, second:bool) int {
        \\    var counter = Counter()
        \\    let chosen = first && touch(counter, second)
        \\    var result = counter.value * 2
        \\    if chosen { result += 1 }
        \\    return result
        \\}
        \\func main() {
        \\    print(choose(false, false)); print(choose(false, true))
        \\    print(choose(true, false)); print(choose(true, true))
        \\    var left = 1; var right = 2; var index = 0
        \\    while index < 4 { let old = copy left; left = right; right = old + right; index++ }
        \\    print(left); print(right)
        \\}
    );
    try std.testing.expectEqualStrings("0\n0\n2\n3\n8\n13\n", differential.execution.completed.stdout);
    for ([_]Ir.Program{ differential.raw_ir, differential.optimized_ir }) |original| {
        var normalized = original;
        const functions = try a.dupe(Ir.Function, original.functions);
        for (functions) |*function| function.* = try lower(a, function.*);
        normalized.functions = functions;
        try Silex.ReleaseVerifier.verify(a, normalized);
        const actual = try Silex.Interpreter.runCaptureWithBoundaries(a, null, normalized, &.{});
        try std.testing.expectEqualStrings(differential.execution.completed.stdout, actual.stdout);
    }
}
