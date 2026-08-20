const std = @import("std");

pub const Profile = struct {
    functions: usize = 0,
    blocks: usize = 0,
    instructions: usize = 0,
    allocas: usize = 0,
    loads: usize = 0,
    stores: usize = 0,
    phis: usize = 0,
    selects: usize = 0,
    branches: usize = 0,
    conditional_branches: usize = 0,
    returns: usize = 0,
    calls: usize = 0,
    internal_calls: usize = 0,
    integer_arithmetic: usize = 0,
    additions: usize = 0,
    multiplies: usize = 0,
    divisions: usize = 0,
    signed_remainders: usize = 0,
    unsigned_remainders: usize = 0,
    shifts: usize = 0,
    bitwise: usize = 0,
    floating_arithmetic: usize = 0,
    comparisons: usize = 0,
    conversions: usize = 0,
    aggregate_operations: usize = 0,
    vector_operations: usize = 0,
    overflow_intrinsics: usize = 0,
    trap_calls: usize = 0,
    trap_branches: usize = 0,
    literal_materializations: usize = 0,
    arithmetic_proofs: usize = 0,
    range_attributes: usize = 0,
    constant_prints: usize = 0,

    pub fn memoryOperations(self: Profile) usize {
        return self.allocas + self.loads + self.stores;
    }

    pub fn safetyOperations(self: Profile) usize {
        return self.overflow_intrinsics + self.trap_calls + self.trap_branches;
    }

    pub fn computationalOperations(self: Profile) usize {
        return self.integer_arithmetic + self.floating_arithmetic + self.comparisons + self.conversions;
    }
};

pub const MatchedDeltas = struct {
    memory_removed: usize = 0,
    phis_added: usize = 0,
    safety_removed: usize = 0,
    internal_calls_removed: usize = 0,
    compute_removed: usize = 0,
    blocks_removed: usize = 0,
    multiplies_removed: usize = 0,
    shifts_added: usize = 0,
    signed_remainders_removed: usize = 0,
    unsigned_remainders_added: usize = 0,
    conversions_removed: usize = 0,
    vector_operations_added: usize = 0,
    range_attributes_added: usize = 0,
};

pub const Comparison = struct {
    raw: Profile,
    optimized: Profile,
    matched: MatchedDeltas,
};

pub fn profile(text: []const u8) Profile {
    return profileFiltered(text, null);
}

pub fn profileNamed(text: []const u8, name: []const u8) Profile {
    return profileFiltered(text, name);
}

pub fn compare(raw_text: []const u8, optimized_text: []const u8, silex_function_count: usize) Comparison {
    var result: Comparison = .{
        .raw = profile(raw_text),
        .optimized = profile(optimized_text),
        .matched = .{},
    };
    var name_buffer: [64]u8 = undefined;
    for (0..silex_function_count) |index| {
        const name = std.fmt.bufPrint(&name_buffer, "sx_{d}", .{index}) catch unreachable;
        const raw_function = profileNamed(raw_text, name);
        const optimized_function = profileNamed(optimized_text, name);
        result.matched.memory_removed += removed(raw_function.memoryOperations(), optimized_function.memoryOperations());
        result.matched.phis_added += added(raw_function.phis, optimized_function.phis);
        result.matched.safety_removed += removed(raw_function.safetyOperations(), optimized_function.safetyOperations());
        result.matched.internal_calls_removed += removed(raw_function.internal_calls, optimized_function.internal_calls);
        result.matched.compute_removed += removed(raw_function.computationalOperations(), optimized_function.computationalOperations());
        result.matched.blocks_removed += removed(raw_function.blocks, optimized_function.blocks);
        result.matched.multiplies_removed += removed(raw_function.multiplies, optimized_function.multiplies);
        result.matched.shifts_added += added(raw_function.shifts, optimized_function.shifts);
        result.matched.signed_remainders_removed += removed(raw_function.signed_remainders, optimized_function.signed_remainders);
        result.matched.unsigned_remainders_added += added(raw_function.unsigned_remainders, optimized_function.unsigned_remainders);
        result.matched.conversions_removed += removed(raw_function.conversions, optimized_function.conversions);
        result.matched.vector_operations_added += added(raw_function.vector_operations, optimized_function.vector_operations);
        result.matched.range_attributes_added += added(raw_function.range_attributes, optimized_function.range_attributes);
    }
    return result;
}

fn profileFiltered(text: []const u8, selected_name: ?[]const u8) Profile {
    var result: Profile = .{};
    var in_function = false;
    var lines = std.mem.splitScalar(u8, text, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \t\r");
        if (std.mem.startsWith(u8, line, "define ")) {
            const name = functionName(line);
            in_function = selected_name == null or (name != null and std.mem.eql(u8, selected_name.?, name.?));
            if (!in_function) continue;
            result.functions += 1;
            if (std.mem.indexOf(u8, line, " range(") != null) result.range_attributes += 1;
            continue;
        }
        if (!in_function) continue;
        if (std.mem.eql(u8, line, "}")) {
            in_function = false;
            continue;
        }
        if (line.len == 0 or line[0] == ';') continue;
        if (isBlockLabel(line)) {
            result.blocks += 1;
            continue;
        }
        const opcode = opcodeOf(line) orelse continue;
        result.instructions += 1;
        if (std.mem.indexOf(u8, line, " nsw ") != null or std.mem.indexOf(u8, line, " nuw ") != null)
            result.arithmetic_proofs += 1;
        if (isVectorLine(line, opcode)) result.vector_operations += 1;
        if (std.mem.indexOf(u8, line, "@llvm.") != null and
            std.mem.indexOf(u8, line, ".with.overflow") != null)
            result.overflow_intrinsics += 1;
        if (std.mem.indexOf(u8, line, "@llvm.trap") != null) result.trap_calls += 1;
        if (std.mem.eql(u8, opcode, "br") and std.mem.indexOf(u8, line, "label %trap") != null)
            result.trap_branches += 1;
        if (std.mem.eql(u8, opcode, "call")) {
            result.calls += 1;
            if (std.mem.indexOf(u8, line, "@sx_") != null) result.internal_calls += 1;
            if (std.mem.indexOf(u8, line, "@printf") != null and printArgumentIsConstant(line))
                result.constant_prints += 1;
            if (std.mem.indexOf(u8, line, ".with.overflow") != null) {
                result.integer_arithmetic += 1;
                if (std.mem.indexOf(u8, line, "mul.with.overflow") != null) result.multiplies += 1;
                if (std.mem.indexOf(u8, line, "add.with.overflow") != null or
                    std.mem.indexOf(u8, line, "sub.with.overflow") != null)
                    result.additions += 1;
            }
        }
        if (std.mem.eql(u8, opcode, "alloca")) result.allocas += 1;
        if (std.mem.eql(u8, opcode, "load")) result.loads += 1;
        if (std.mem.eql(u8, opcode, "store")) result.stores += 1;
        if (std.mem.eql(u8, opcode, "phi")) result.phis += 1;
        if (std.mem.eql(u8, opcode, "select")) result.selects += 1;
        if (std.mem.eql(u8, opcode, "br")) {
            result.branches += 1;
            if (std.mem.startsWith(u8, bodyOf(line), "br i1 ")) result.conditional_branches += 1;
        }
        if (std.mem.eql(u8, opcode, "ret")) result.returns += 1;
        classifyComputation(&result, opcode, line);
    }
    return result;
}

fn classifyComputation(result: *Profile, opcode: []const u8, line: []const u8) void {
    if (oneOf(opcode, &.{ "add", "sub", "mul", "sdiv", "udiv", "srem", "urem", "shl", "lshr", "ashr", "and", "or", "xor" })) {
        result.integer_arithmetic += 1;
        if (std.mem.eql(u8, opcode, "add") or std.mem.eql(u8, opcode, "sub")) result.additions += 1;
        if (std.mem.eql(u8, opcode, "mul")) result.multiplies += 1;
        if (std.mem.eql(u8, opcode, "sdiv") or std.mem.eql(u8, opcode, "udiv")) result.divisions += 1;
        if (std.mem.eql(u8, opcode, "srem")) result.signed_remainders += 1;
        if (std.mem.eql(u8, opcode, "urem")) result.unsigned_remainders += 1;
        if (oneOf(opcode, &.{ "shl", "lshr", "ashr" })) result.shifts += 1;
        if (oneOf(opcode, &.{ "and", "or", "xor" })) result.bitwise += 1;
        if (std.mem.eql(u8, opcode, "add") and std.mem.indexOf(u8, line, " 0, ") != null)
            result.literal_materializations += 1;
        return;
    }
    if (oneOf(opcode, &.{ "fadd", "fsub", "fmul", "fdiv", "frem", "fneg" })) {
        result.floating_arithmetic += 1;
        return;
    }
    if (std.mem.eql(u8, opcode, "icmp") or std.mem.eql(u8, opcode, "fcmp")) {
        result.comparisons += 1;
        return;
    }
    if (oneOf(opcode, &.{ "trunc", "zext", "sext", "fptrunc", "fpext", "fptoui", "fptosi", "uitofp", "sitofp", "ptrtoint", "inttoptr", "bitcast" })) {
        result.conversions += 1;
        return;
    }
    if (oneOf(opcode, &.{ "extractvalue", "insertvalue", "getelementptr" }))
        result.aggregate_operations += 1;
}

fn isBlockLabel(line: []const u8) bool {
    const colon = std.mem.indexOfScalar(u8, line, ':') orelse return false;
    return colon != 0 and line[0] != '%';
}

fn functionName(line: []const u8) ?[]const u8 {
    const at = std.mem.indexOfScalar(u8, line, '@') orelse return null;
    const suffix = line[at + 1 ..];
    const opening = std.mem.indexOfScalar(u8, suffix, '(') orelse return null;
    if (opening == 0) return null;
    return suffix[0..opening];
}

fn opcodeOf(line: []const u8) ?[]const u8 {
    var body = bodyOf(line);
    if (std.mem.startsWith(u8, body, "tail ")) body = body[5..];
    if (std.mem.startsWith(u8, body, "musttail ")) body = body[9..];
    if (std.mem.startsWith(u8, body, "notail ")) body = body[7..];
    const end = std.mem.indexOfAny(u8, body, " \t") orelse body.len;
    if (end == 0) return null;
    return body[0..end];
}

fn bodyOf(line: []const u8) []const u8 {
    if (std.mem.indexOf(u8, line, " = ")) |equals| return line[equals + 3 ..];
    return line;
}

fn isVectorLine(line: []const u8, opcode: []const u8) bool {
    return oneOf(opcode, &.{ "shufflevector", "insertelement", "extractelement" }) or
        (std.mem.indexOfScalar(u8, line, '<') != null and std.mem.indexOf(u8, line, " x ") != null);
}

fn printArgumentIsConstant(line: []const u8) bool {
    const format = std.mem.indexOf(u8, line, "@.fmt.") orelse return false;
    const suffix = line[format..];
    const comma = std.mem.indexOfScalar(u8, suffix, ',') orelse return false;
    return std.mem.indexOfScalar(u8, suffix[comma..], '%') == null;
}

fn oneOf(value: []const u8, candidates: []const []const u8) bool {
    for (candidates) |candidate| if (std.mem.eql(u8, value, candidate)) return true;
    return false;
}

fn removed(before: usize, after: usize) usize {
    return before -| after;
}

fn added(before: usize, after: usize) usize {
    return after -| before;
}

test "profile recognizes memory promotion in optimized LLVM IR" {
    const raw = profile(
        \\define i64 @sx_0(i64 %v0) {
        \\b0:
        \\  %local0 = alloca i64
        \\  store i64 %v0, ptr %local0
        \\  %v1 = load i64, ptr %local0
        \\  %v2 = mul i64 %v1, 2
        \\  br i1 true, label %b1, label %trap
        \\b1:
        \\  ret i64 %v2
        \\trap:
        \\  call void @llvm.trap()
        \\  unreachable
        \\}
    );
    const optimized = profile(
        \\define i64 @sx_0(i64 %v0) {
        \\b0:
        \\  %v2 = shl nsw i64 %v0, 1
        \\  ret i64 %v2
        \\}
    );
    try std.testing.expectEqual(@as(usize, 3), raw.memoryOperations());
    try std.testing.expectEqual(@as(usize, 0), optimized.memoryOperations());
    try std.testing.expectEqual(@as(usize, 1), raw.multiplies);
    try std.testing.expectEqual(@as(usize, 1), optimized.shifts);
    try std.testing.expectEqual(@as(usize, 1), raw.trap_calls);
    try std.testing.expectEqual(@as(usize, 0), optimized.trap_calls);
}

test "matched comparison ignores blocks duplicated into callers by inlining" {
    const raw =
        \\define i64 @sx_0(i64 %v0) {
        \\b0:
        \\  %local0 = alloca i64
        \\  store i64 %v0, ptr %local0
        \\  br label %b1
        \\b1:
        \\  %v1 = load i64, ptr %local0
        \\  ret i64 %v1
        \\}
        \\define void @sx_1() {
        \\b0:
        \\  %v0 = call i64 @sx_0(i64 1)
        \\  ret void
        \\}
    ;
    const optimized =
        \\define i64 @sx_0(i64 %v0) {
        \\b0:
        \\  ret i64 %v0
        \\}
        \\define void @sx_1() {
        \\b0:
        \\  br label %inlined
        \\inlined: ; duplicated body
        \\  ret void
        \\}
    ;
    const result = compare(raw, optimized, 2);
    try std.testing.expectEqual(@as(usize, 3), result.matched.memory_removed);
    try std.testing.expectEqual(@as(usize, 1), result.matched.blocks_removed);
    try std.testing.expectEqual(@as(usize, 1), result.matched.internal_calls_removed);
}

test "named profiles recognize LLVM range attributes before a function name" {
    const ranged = profileNamed(
        \\define range(i64 -100, 101) i64 @sx_0(i64 %v0) {
        \\b0: ; entry
        \\  ret i64 %v0
        \\}
    , "sx_0");
    try std.testing.expectEqual(@as(usize, 1), ranged.functions);
    try std.testing.expectEqual(@as(usize, 1), ranged.blocks);
    try std.testing.expectEqual(@as(usize, 1), ranged.range_attributes);
}
