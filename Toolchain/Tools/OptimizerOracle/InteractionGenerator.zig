const std = @import("std");

pub const Request = struct {
    seed: u64,
    first_axis: []const u8,
    first_state: bool,
    second_axis: ?[]const u8 = null,
    second_state: bool = false,
    risk_triplet: ?[]const u8 = null,
};

pub const Sources = struct {
    main: []const u8,
    support: ?[]const u8,
};

pub fn source(allocator: std.mem.Allocator, request: Request) !Sources {
    const package_shape = state(request, "package");
    const aggregate_memory = state(request, "memory") or containsRisk(request, "aggregate");
    const aliased = state(request, "alias") or containsRisk(request, "alias");
    const helper_call = state(request, "call") or containsRisk(request, "call");
    const for_loop = state(request, "loop");
    const branching = state(request, "control") or containsRisk(request, "branch");
    const unsigned_width = state(request, "type");
    const guarded_error = state(request, "error") or containsRisk(request, "bounds");
    const target_pressure = state(request, "target") or containsRisk(request, "spill");

    const first = @as(i64, @intCast(request.seed % 17)) + 3;
    const second = @as(i64, @intCast((request.seed >> 8) % 13)) + 2;
    var output: std.Io.Writer.Allocating = .init(allocator);
    errdefer output.deinit();
    if (package_shape) {
        try output.writer.writeAll("use Support\n");
    } else {
        try output.writer.writeAll("func apply(value:int) int { return value * 2 + 1 }\n");
    }
    try output.writer.writeAll(
        \\struct Pair { var x:int; var y:int }
        \\func bump(value:&Pair, delta:int) int {
        \\    value.x += delta
        \\    return value.x + value.y
        \\}
        \\func guarded_div(value:int, denominator:int) int {
        \\    if denominator == 0 { return value }
        \\    return value / denominator
        \\}
    );
    try output.writer.writeByte('\n');
    if (unsigned_width) {
        try output.writer.writeAll(
            \\func typed(value:int) int {
            \\    let narrowed = value as uint32
            \\    return narrowed as int
            \\}
        );
        try output.writer.writeByte('\n');
    } else {
        try output.writer.writeAll(
            \\func typed(value:int) int {
            \\    let narrowed = value as int32
            \\    return narrowed as int
            \\}
        );
        try output.writer.writeByte('\n');
    }
    try output.writer.print(
        \\func scenario() int {{
        \\    var pair = Pair(x:{d}, y:{d})
        \\    let snapshot = copy pair
        \\    var total = typed(pair.x + pair.y)
        \\    let values = [1, 2, 3, 4]
        \\
    , .{ first, second });
    if (aggregate_memory) {
        try output.writer.writeAll("    total += snapshot.x + snapshot.y\n");
    } else {
        try output.writer.writeAll("    let scalar_x = snapshot.x\n    let scalar_y = snapshot.y\n    total += scalar_x + scalar_y\n");
    }
    if (aliased) {
        try output.writer.writeAll("    total += bump(pair, 3)\n");
    } else {
        try output.writer.writeAll("    pair.x += 3\n    total += pair.x + pair.y\n");
    }
    if (for_loop) {
        try output.writer.writeAll("    for value in values { total += value }\n");
    } else {
        try output.writer.writeAll("    var index = 0\n    while index < values.count() { total += values[index]; index++ }\n");
    }
    if (branching) {
        try output.writer.writeAll("    if pair.x > pair.y && total > 0 { total += 7 } else { total -= 5 }\n");
    } else {
        try output.writer.writeAll("    if total > 0 { total += 7 }\n");
    }
    if (guarded_error) {
        try output.writer.writeAll("    total += guarded_div(18, 2)\n");
    } else {
        try output.writer.writeAll("    total += guarded_div(9, 1)\n");
    }
    if (target_pressure) {
        try output.writer.writeAll(
            "    let p0 = total + 1\n    let p1 = total + 2\n    let p2 = total + 3\n" ++
                "    let p3 = total + 4\n    let p4 = total + 5\n    let p5 = total + 6\n" ++
                "    total += p0 + p1 + p2 + p3 + p4 + p5\n",
        );
    }
    if (helper_call) {
        if (package_shape) {
            try output.writer.writeAll("    return Support.apply(total)\n");
        } else {
            try output.writer.writeAll("    return apply(total)\n");
        }
    } else {
        try output.writer.writeAll("    return total * 2 + 1\n");
    }
    try output.writer.writeAll("}\nfunc main() { print(scenario()) }\n");
    return .{
        .main = try output.toOwnedSlice(),
        .support = if (package_shape)
            "public func apply(value:int) int { return value * 2 + 1 }\n"
        else
            null,
    };
}

fn state(request: Request, axis: []const u8) bool {
    if (std.mem.eql(u8, request.first_axis, axis)) return request.first_state;
    if (request.second_axis) |second| if (std.mem.eql(u8, second, axis)) return request.second_state;
    return containsRisk(request, axis);
}

fn containsRisk(request: Request, token: []const u8) bool {
    const risk = request.risk_triplet orelse return false;
    return std.mem.indexOf(u8, risk, token) != null;
}

test "interaction sources are deterministic and exercise selected shapes" {
    const request: Request = .{
        .seed = 42,
        .first_axis = "package",
        .first_state = true,
        .second_axis = "loop",
        .second_state = true,
    };
    const first = try source(std.testing.allocator, request);
    defer std.testing.allocator.free(first.main);
    const repeated = try source(std.testing.allocator, request);
    defer std.testing.allocator.free(repeated.main);
    try std.testing.expectEqualStrings(first.main, repeated.main);
    try std.testing.expect(first.support != null);
    try std.testing.expect(std.mem.indexOf(u8, first.main, "use Support") != null);
    try std.testing.expect(std.mem.indexOf(u8, first.main, "for value in values") != null);
}

test "risk triplets materialize their named mechanisms" {
    const generated = try source(std.testing.allocator, .{
        .seed = 7,
        .first_axis = "risk",
        .first_state = true,
        .risk_triplet = "alias+call+loop",
    });
    defer std.testing.allocator.free(generated.main);
    try std.testing.expect(std.mem.indexOf(u8, generated.main, "bump(pair") != null);
    try std.testing.expect(std.mem.indexOf(u8, generated.main, "return apply(total)") != null);
}
