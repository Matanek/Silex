const std = @import("std");
const Differential = @import("Differential.zig");
const Native = @import("Native.zig");

const Case = struct {
    name: []const u8,
    source: []const u8,
    failure: anyerror,
};

// Each call takes typed dynamic operands so Debug reaches the machine operation;
// Release is independently checked against the interpreter before execution.
pub fn cases(allocator: std.mem.Allocator) ![]const Case {
    var result: std.ArrayList(Case) = .empty;
    for ([_]u7{ 8, 16, 32, 64 }) |width| {
        for ([_]bool{ true, false }) |signed| {
            const type_name = try std.fmt.allocPrint(allocator, "{s}{d}", .{ if (signed) "int" else "uint", width });
            const maximum: i128 = (@as(i128, 1) << @intCast(width - @intFromBool(signed))) - 1;
            const minimum: i128 = if (signed) -maximum - 1 else 0;
            try add(allocator, &result, type_name, "Add", "a + b", maximum, 1, type_name, error.IntegerOverflow);
            try add(allocator, &result, type_name, "Subtract", "a - b", minimum, 1, type_name, error.IntegerOverflow);
            try add(allocator, &result, type_name, "Multiply", "a * b", maximum, 2, type_name, error.IntegerOverflow);
            try add(allocator, &result, type_name, "DivideZero", "a / b", 7, 0, type_name, error.DivisionByZero);
            try add(allocator, &result, type_name, "RemainderZero", "a % b", 7, 0, type_name, error.DivisionByZero);
            try add(allocator, &result, type_name, "Negate", "-a", if (signed) minimum else 1, 0, type_name, error.IntegerOverflow);
            if (signed) {
                try add(allocator, &result, type_name, "DivideMinimum", "a / b", minimum, -1, type_name, error.IntegerOverflow);
                try add(allocator, &result, type_name, "RemainderMinimum", "a % b", minimum, -1, type_name, error.IntegerOverflow);
            } else {
                try add(allocator, &result, type_name, "ShiftLeftWidth", "a << b", 1, width, "uint8", error.InvalidShift);
                try add(allocator, &result, type_name, "ShiftRightWidth", "a >> b", maximum, width, "uint8", error.InvalidShift);
            }
        }
    }
    return result.toOwnedSlice(allocator);
}

fn add(allocator: std.mem.Allocator, result: *std.ArrayList(Case), type_name: []const u8, name: []const u8, expression: []const u8, left: i128, right: i128, right_type: []const u8, failure: anyerror) !void {
    try result.append(allocator, .{
        .name = try std.fmt.allocPrint(allocator, "{s}{s}", .{ type_name, name }),
        .source = try std.fmt.allocPrint(allocator, "func calculate(a:{s}, b:{s}) {s} {{ return {s} }}\n" ++
            "func main() {{ print(true); print(calculate({d}, {d})); print(false) }}\n", .{ type_name, right_type, type_name, expression, left, right }),
        .failure = failure,
    });
}

pub fn qualify(allocator: std.mem.Allocator, io: std.Io, compiler: []const u8, directory: []const u8) !usize {
    try std.Io.Dir.cwd().createDirPath(io, directory);
    const manifest = try std.fs.path.join(allocator, &.{ directory, "Package.json" });
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = manifest, .data = "{\"sources\":\".\"}\n" });
    const entries = try cases(allocator);
    for (entries) |entry| {
        const differential = try Differential.verify(allocator, entry.source);
        if (differential.execution != .failed or differential.execution.failed != entry.failure) {
            std.debug.print("integer failure interpreter mismatch: {s}\n", .{entry.name});
            return error.IntegerFailureMismatch;
        }
        const stem = try std.fs.path.join(allocator, &.{ directory, entry.name });
        const path = try std.fmt.allocPrint(allocator, "{s}.sx", .{stem});
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = entry.source });
        try Native.verifyFailure(allocator, io, compiler, path, stem, "true\n");
    }
    // Boundary successes exercise the same guards without allowing an
    // implementation that rejects every checked operation to pass.
    for ([_]u7{ 8, 16, 32, 64 }) |width| {
        for ([_]bool{ true, false }) |signed| {
            const type_name = try std.fmt.allocPrint(allocator, "{s}{d}", .{ if (signed) "int" else "uint", width });
            const maximum: i128 = (@as(i128, 1) << @intCast(width - @intFromBool(signed))) - 1;
            const source = try std.fmt.allocPrint(allocator, "func check(a:{s}, zero:{s}, one:{s}) bool {{ " ++
                "return a + zero == a && a - zero == a && a * one == a && a / one == a && a % one == zero && a >= zero && a > zero && zero < a && zero <= a && a != zero && -zero == zero }}\n" ++
                "func main() {{ print(check({d}, 0, 1)) }}\n", .{ type_name, type_name, type_name, maximum });
            const differential = try Differential.verify(allocator, source);
            if (differential.execution != .completed or !std.mem.eql(u8, differential.execution.completed.stdout, "true\n")) return error.IntegerSuccessMismatch;
            const stem = try std.fmt.allocPrint(allocator, "{s}/{s}Success", .{ directory, type_name });
            const path = try std.fmt.allocPrint(allocator, "{s}.sx", .{stem});
            try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = source });
            _ = try Native.verify(allocator, io, compiler, path, differential.execution, stem, true);
        }
    }
    return entries.len;
}

test "all integer widths preserve the precise arithmetic error through Release" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const entries = try cases(arena.allocator());
    try std.testing.expectEqual(@as(usize, 64), entries.len);
    for (entries) |entry| {
        const result = try Differential.verify(arena.allocator(), entry.source);
        try std.testing.expectEqual(entry.failure, result.execution.failed);
    }
}
