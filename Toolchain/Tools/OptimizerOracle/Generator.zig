const std = @import("std");

pub const CorpusEntry = struct {
    name: []const u8,
    timing: bool,
};

pub const StructuralContract = union(enum) {
    none,
    reduces_blocks: []const u8,
    removes_collection_bounds: []const u8,
    scalarizes_dense_loop: []const u8,
    slp_width: struct {
        function: []const u8,
        minimum: u3,
        native_pair: bool = false,
    },
};

pub const RegressionEntry = struct {
    name: []const u8,
    concern: []const u8,
    contract: StructuralContract = .none,
};

pub const corpus = [_]CorpusEntry{
    .{ .name = "IntegerArithmetic.sx", .timing = true },
    .{ .name = "BranchingLoop.sx", .timing = true },
    .{ .name = "FloatArithmetic.sx", .timing = true },
    .{ .name = "IntegerControlFlow.sx", .timing = false },
    .{ .name = "IntegerWidths.sx", .timing = false },
    .{ .name = "UnsignedBitwise.sx", .timing = false },
};

pub const regressions = [_]RegressionEntry{
    .{
        .name = "Regressions/AggregateFieldStores.sx",
        .concern = "narrow reference and view field writes preserve stale snapshots, sibling mutations and owning collection copies",
    },
    .{
        .name = "Regressions/CheckedMemoryLanes.sx",
        .concern = "checked aggregate loads, independent arithmetic lanes, branches and borrowed writes",
    },
    .{
        .name = "Regressions/AggregateControlFlow.sx",
        .concern = "immutable aggregate projections across branches and loops preserve snapshots and joined returns",
    },
    .{
        .name = "Regressions/BooleanSharedChain.sx",
        .concern = "shared boolean-chain blocks and reused branch values",
        .contract = .{ .reduces_blocks = "hot_chain" },
    },
    .{
        .name = "Regressions/ArrayStorageAccess.sx",
        .concern = "fixed, dynamic, nested, and aggregate collection storage",
    },
    .{
        .name = "Regressions/BoundedCollectionLoop.sx",
        .concern = "proven zero-origin collection traversal without weakening other bounds checks",
        .contract = .{ .removes_collection_bounds = "sum" },
    },
    .{
        .name = "Regressions/DenseScalarLoop.sx",
        .concern = "class count accessor inlining and redundant scalar loads inside a dense loop",
        .contract = .{ .scalarizes_dense_loop = "integrate" },
    },
    .{
        .name = "Regressions/FloatLaneXYZ.sx",
        .concern = "portable XYZ lane grouping through loads and arithmetic",
        .contract = .{ .slp_width = .{ .function = "transform", .minimum = 3 } },
    },
    .{
        .name = "Regressions/TextOutputIntegrity.sx",
        .concern = "complete text output through branches and collection iteration",
    },
    .{
        .name = "Regressions/BoidsKernel.sx",
        .concern = "boids-like arrays, shared boolean chains, and native XY/Z realization",
        .contract = .{ .slp_width = .{ .function = "steer", .minimum = 3, .native_pair = true } },
    },
};

const IntegerKind = struct {
    name: []const u8,
    signed: bool,
};

const integer_kinds = [_]IntegerKind{
    .{ .name = "int8", .signed = true },
    .{ .name = "int16", .signed = true },
    .{ .name = "int32", .signed = true },
    .{ .name = "int", .signed = true },
    .{ .name = "uint8", .signed = false },
    .{ .name = "uint16", .signed = false },
    .{ .name = "uint32", .signed = false },
    .{ .name = "uint", .signed = false },
};

const Generator = struct {
    state: u64,

    fn next(self: *Generator) u64 {
        self.state = self.state *% 6364136223846793005 +% 1442695040888963407;
        return self.state;
    }

    fn choose(self: *Generator, values: []const []const u8) []const u8 {
        return values[@intCast(self.next() % values.len)];
    }

    fn smallInteger(self: *Generator) i64 {
        return @as(i64, @intCast(self.next() % 17)) - 8;
    }

    fn smallPositiveInteger(self: *Generator) u64 {
        return self.next() % 9;
    }
};

pub fn source(allocator: std.mem.Allocator, seed: u64) ![]u8 {
    var generator: Generator = .{ .state = seed };
    const kind = integer_kinds[@intCast(seed % integer_kinds.len)];
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    try output.writer.print(
        \\func calculate(a:{s}, b:{s}, c:{s}) {s} {{
        \\    var value = a
        \\
    , .{ kind.name, kind.name, kind.name, kind.name });
    const signed_operators = [_][]const u8{ "+", "-" };
    const unsigned_operators = [_][]const u8{ "+", "^", "&" };
    const operators: []const []const u8 = if (kind.signed) &signed_operators else &unsigned_operators;
    const operands = [_][]const u8{ "a", "b", "c" };
    for (0..12) |_| {
        const operator = generator.choose(operators);
        if ((generator.next() & 1) == 0) {
            const operand = generator.choose(&operands);
            try output.writer.print(
                "    value = value {s} {s}\n",
                .{ operator, operand },
            );
        } else {
            try output.writer.print(
                "    value = value {s} ({d} as {s})\n",
                .{ operator, generator.smallPositiveInteger(), kind.name },
            );
        }
    }
    const first = if (kind.signed) generator.smallInteger() else @as(i64, @intCast(generator.smallPositiveInteger()));
    const second = if (kind.signed) generator.smallInteger() else @as(i64, @intCast(generator.smallPositiveInteger()));
    const third = if (kind.signed) generator.smallInteger() else @as(i64, @intCast(generator.smallPositiveInteger()));
    try output.writer.print(
        \\    return value
        \\}}
        \\func main() {{
        \\    print(calculate({d}, {d}, {d}))
        \\}}
        \\
    , .{ first, second, third });
    return output.toOwnedSlice();
}

test "generated sources are deterministic and seed-sensitive" {
    const first = try source(std.testing.allocator, 42);
    defer std.testing.allocator.free(first);
    const repeated = try source(std.testing.allocator, 42);
    defer std.testing.allocator.free(repeated);
    const different = try source(std.testing.allocator, 43);
    defer std.testing.allocator.free(different);
    try std.testing.expectEqualStrings(first, repeated);
    try std.testing.expect(!std.mem.eql(u8, first, different));
}

test "successive seeds cover every integer width and signedness" {
    for (integer_kinds, 0..) |kind, seed| {
        const generated = try source(std.testing.allocator, seed);
        defer std.testing.allocator.free(generated);
        const signature = try std.fmt.allocPrint(std.testing.allocator, "a:{s}", .{kind.name});
        defer std.testing.allocator.free(signature);
        try std.testing.expect(std.mem.containsAtLeast(u8, generated, 1, signature));
    }
}
