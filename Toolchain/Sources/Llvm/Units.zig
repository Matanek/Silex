//! Split the backend's generated LLVM dialect into independently reusable
//! function units. This is downstream of typed composition and Silex optimization.
const std = @import("std");
const Ir = @import("../Ir.zig");
const Identity = @import("Identity.zig");
const Allocator = std.mem.Allocator;

pub const Unit = struct { name: []const u8, text: []const u8, functions: usize };
const Kind = enum { function, declaration, constant, global, type };
const Atom = struct { symbol: []const u8, text: []const u8, kind: Kind, group: []const u8 = "runtime" };

pub fn split(allocator: Allocator, program: Ir.Program, text: []const u8, imports: bool) ![]Unit {
    var atoms: std.ArrayList(Atom) = .empty;
    var prefix: std.ArrayList(u8) = .empty;
    var cursor: usize = 0;
    while (cursor < text.len) {
        const line_end = if (std.mem.indexOfScalarPos(u8, text, cursor, '\n')) |end| end + 1 else text.len;
        const line = text[cursor..line_end];
        var end = line_end;
        const kind: ?Kind = if (std.mem.startsWith(u8, line, "define ")) .function else if (std.mem.startsWith(u8, line, "declare ")) .declaration else if (line[0] == '%') .type else if (line[0] == '@') (if (std.mem.indexOf(u8, line, " constant ") != null) .constant else .global) else null;
        if (kind == .function) {
            const close = std.mem.indexOfPos(u8, text, line_end, "\n}") orelse return error.InvalidLlvmUnit;
            end = close + 2;
            if (end < text.len and text[end] == '\n') end += 1;
        }
        if (kind) |selected| {
            const start = if (selected == .function or selected == .declaration)
                std.mem.indexOfScalar(u8, line, '@') orelse return error.InvalidLlvmUnit
            else
                0;
            const symbol_end = tokenEnd(line, start);
            try atoms.append(allocator, .{ .symbol = line[start..symbol_end], .text = text[cursor..end], .kind = selected });
        } else if (std.mem.startsWith(u8, line, "target ")) {
            try prefix.appendSlice(allocator, line);
        }
        cursor = end;
    }

    var names: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer names.deinit(allocator);
    var groups: std.StringHashMapUnmanaged([]const u8) = .empty;
    defer groups.deinit(allocator);
    for (program.functions, 0..) |function, index| {
        const canonical = try Identity.functionName(allocator, program, function);
        try names.put(allocator, try std.fmt.allocPrint(allocator, "@sx_{d}", .{index}), canonical);
        try names.put(allocator, try std.fmt.allocPrint(allocator, "@sx.c.callback.{d}", .{index}), try std.fmt.allocPrint(allocator, "{s}.callback", .{canonical}));
        try groups.put(allocator, canonical, canonical);
        try groups.put(allocator, try std.fmt.allocPrint(allocator, "{s}.callback", .{canonical}), canonical);
    }
    for (program.structures, 0..) |structure, index| {
        for ([_][]const u8{ "type", "class", "protocol" }) |kind| {
            const old = try std.fmt.allocPrint(allocator, "%sx.{s}.{d}", .{ kind, index });
            const namespace = try std.fmt.allocPrint(allocator, "%sx.{s}.", .{kind});
            try names.put(allocator, old, try Identity.name(allocator, namespace, structure.name));
        }
    }
    for (program.enums, 0..) |enumeration, index|
        try names.put(allocator, try std.fmt.allocPrint(allocator, "%sx.enum.{d}", .{index}), try Identity.name(allocator, "%sx.enum.", enumeration.name));
    for (program.globals, 0..) |global, index| {
        const identity = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ global.name, try Identity.typeName(allocator, program, global.type) });
        try names.put(allocator, try std.fmt.allocPrint(allocator, "@sx.global.{d}", .{index}), try Identity.name(allocator, "@sx.global.", identity));
    }
    // Literal identity is its descriptor, not its function/value numbering.
    for (atoms.items) |atom| if (atom.kind == .constant) {
        try names.put(allocator, atom.symbol, try Identity.name(allocator, "@sx.constant.", atom.text[atom.symbol.len..]));
    };

    var definitions: std.StringHashMapUnmanaged(usize) = .empty;
    defer definitions.deinit(allocator);
    var unique: std.ArrayList(Atom) = .empty;
    for (atoms.items) |original| {
        var atom = original;
        atom.symbol = names.get(atom.symbol) orelse atom.symbol;
        atom.text = try rename(allocator, atom.text, names);
        if (atom.kind == .function) {
            atom.text = try replace(allocator, atom.text, "define internal ", "define hidden ");
            atom.group = groups.get(atom.symbol) orelse if (std.mem.eql(u8, atom.symbol, "@main")) "entry" else "runtime";
        } else if (atom.kind == .global) {
            atom.text = try replace(allocator, atom.text, " = internal ", " = hidden ");
            atom.text = try replace(allocator, atom.text, " = private ", " = hidden ");
            atom.group = "state";
        }
        if (definitions.get(atom.symbol)) |previous| {
            // Equal constants and equal nominal layouts can be interned. A
            // conflicting symbol must never be satisfied by an arbitrary unit.
            if (!std.mem.eql(u8, unique.items[previous].text, atom.text)) return error.ConflictingLlvmIdentity;
            continue;
        }
        try definitions.put(allocator, atom.symbol, unique.items.len);
        try unique.append(allocator, atom);
    }
    var unit_groups: std.StringHashMapUnmanaged(void) = .empty;
    defer unit_groups.deinit(allocator);
    // Import selection must not depend on the consumer's function numbering.
    std.mem.sort(Atom, unique.items, {}, struct {
        fn less(_: void, a: Atom, b: Atom) bool {
            return std.mem.lessThan(u8, a.symbol, b.symbol);
        }
    }.less);
    definitions.clearRetainingCapacity();
    for (unique.items, 0..) |atom, index| try definitions.put(allocator, atom.symbol, index);
    for (unique.items) |atom| if (atom.kind == .function or atom.kind == .global) {
        try unit_groups.put(allocator, atom.group, {});
    };
    var result: std.ArrayList(Unit) = .empty;
    var iterator = unit_groups.keyIterator();
    while (iterator.next()) |group| {
        const selected = try allocator.alloc(bool, unique.items.len);
        defer allocator.free(selected);
        @memset(selected, false);
        var count: usize = 0;
        for (unique.items, 0..) |atom, index| if ((atom.kind == .function or atom.kind == .global) and std.mem.eql(u8, atom.group, group.*)) {
            selected[index] = true;
            count += @intFromBool(atom.kind == .function);
        };
        const roots = try allocator.dupe(bool, selected);
        defer allocator.free(roots);
        const imported = try allocator.alloc(bool, unique.items.len);
        defer allocator.free(imported);
        @memset(imported, false);
        const distance = try allocator.alloc(u8, unique.items.len);
        defer allocator.free(distance);
        for (roots, distance) |root, *depth| depth.* = if (root) 0 else 255;
        var import_budget: usize = if (imports and !std.mem.eql(u8, group.*, "entry")) 192 * 1024 else 0;
        // Reachability here follows LLVM declarations and layouts, not bodies
        // belonging to another source unit. The linker resolves those calls.
        var changed = true;
        while (changed) {
            changed = false;
            for (unique.items, 0..) |atom, index| if (selected[index]) {
                const body = if (!roots[index] and !imported[index] and atom.kind == .function)
                    try declaration(allocator, atom)
                else if (!roots[index] and atom.kind == .global)
                    try globalDeclaration(allocator, atom)
                else
                    atom.text;
                var at: usize = 0;
                while (nextToken(body, &at)) |token| if (definitions.get(token)) |dependency| {
                    if (!selected[dependency]) {
                        selected[dependency] = true;
                        changed = true;
                    }
                    const callee = unique.items[dependency];
                    if (!roots[dependency] and !imported[dependency] and atom.kind == .function and
                        distance[index] < 2 and callee.kind == .function and
                        callee.text.len <= 48 * 1024 and callee.text.len <= import_budget)
                    {
                        const start = at - token.len;
                        const line_start = if (std.mem.lastIndexOfScalar(u8, body[0..start], '\n')) |line| line + 1 else 0;
                        if (at < body.len and body[at] == '(' and
                            std.mem.indexOf(u8, body[line_start..start], "call ") != null)
                        {
                            imported[dependency] = true;
                            distance[dependency] = distance[index] + 1;
                            import_budget -= callee.text.len;
                            changed = true;
                        }
                    }
                };
            };
        }
        var chosen: std.ArrayList(usize) = .empty;
        for (selected, 0..) |include, index| if (include) {
            try chosen.append(allocator, index);
        };
        std.mem.sort(usize, chosen.items, unique.items, atomLessThan);
        var output: std.ArrayList(u8) = .empty;
        try output.appendSlice(allocator, prefix.items);
        for (chosen.items) |index| {
            const atom = unique.items[index];
            const body = if (imported[index])
                try replace(allocator, atom.text, "define hidden ", "define available_externally hidden ")
            else if (!roots[index] and atom.kind == .function)
                try declaration(allocator, atom)
            else if (!roots[index] and atom.kind == .global)
                try globalDeclaration(allocator, atom)
            else
                atom.text;
            try output.appendSlice(allocator, body);
            try output.append(allocator, '\n');
        }
        try result.append(allocator, .{ .name = group.*, .text = try output.toOwnedSlice(allocator), .functions = count });
    }
    std.mem.sort(Unit, result.items, {}, unitLessThan);
    return result.toOwnedSlice(allocator);
}

fn atomLessThan(atoms: []Atom, a: usize, b: usize) bool {
    return std.mem.lessThan(u8, atoms[a].symbol, atoms[b].symbol);
}
fn unitLessThan(_: void, a: Unit, b: Unit) bool {
    return std.mem.lessThan(u8, a.name, b.name);
}

fn declaration(allocator: Allocator, atom: Atom) ![]const u8 {
    const end = std.mem.indexOf(u8, atom.text, " {\n") orelse return error.InvalidLlvmUnit;
    const signature = atom.text["define ".len..end];
    return std.fmt.allocPrint(allocator, "declare {s}\n", .{signature});
}

fn globalDeclaration(allocator: Allocator, atom: Atom) ![]const u8 {
    const marker = " global ";
    const start = (std.mem.indexOf(u8, atom.text, marker) orelse return error.InvalidLlvmUnit) + marker.len;
    var end = start;
    var depth: usize = 0;
    while (end < atom.text.len) : (end += 1) {
        const byte = atom.text[end];
        if (byte == '[' or byte == '{' or byte == '<') depth += 1;
        if (byte == ']' or byte == '}' or byte == '>') depth -= 1;
        if (byte == ' ' and depth == 0) break;
    }
    return std.fmt.allocPrint(allocator, "{s} = external hidden global {s}\n", .{ atom.symbol, atom.text[start..end] });
}

fn replace(allocator: Allocator, text: []const u8, old: []const u8, new: []const u8) ![]const u8 {
    const index = std.mem.indexOf(u8, text, old) orelse return text;
    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ text[0..index], new, text[index + old.len ..] });
}

fn rename(allocator: Allocator, text: []const u8, names: std.StringHashMapUnmanaged([]const u8)) ![]const u8 {
    var output: std.ArrayList(u8) = .empty;
    var cursor: usize = 0;
    var copied: usize = 0;
    while (nextToken(text, &cursor)) |token| {
        const begin = cursor - token.len;
        if (names.get(token)) |replacement| {
            try output.appendSlice(allocator, text[copied..begin]);
            try output.appendSlice(allocator, replacement);
            copied = cursor;
        }
    }
    try output.appendSlice(allocator, text[copied..]);
    return output.toOwnedSlice(allocator);
}

fn tokenEnd(text: []const u8, start: usize) usize {
    var end = start + 1;
    while (end < text.len and (std.ascii.isAlphanumeric(text[end]) or std.mem.indexOfScalar(u8, "._$-", text[end]) != null)) : (end += 1) {}
    return end;
}

fn nextToken(text: []const u8, cursor: *usize) ?[]const u8 {
    while (cursor.* < text.len) {
        const byte = text[cursor.*];
        if (byte == '"') {
            cursor.* += 1;
            while (cursor.* < text.len and text[cursor.*] != '"') : (cursor.* += 1) {
                if (text[cursor.*] == '\\' and cursor.* + 1 < text.len) cursor.* += 1;
            }
            if (cursor.* < text.len) cursor.* += 1;
        } else if (byte == '@' or byte == '%') {
            const start = cursor.*;
            cursor.* = tokenEnd(text, start);
            return text[start..cursor.*];
        } else cursor.* += 1;
    }
    return null;
}

test "source units declare callees and retain only their referenced layouts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const program: Ir.Program = .{ .functions = &.{.{
        .name = "main",
        .parameter_types = &.{},
        .return_type = .void,
        .value_types = &.{},
        .blocks = &.{},
    }} };
    const units = try split(a, program,
        \\target triple = "arm64-apple-macosx26.0.0"
        \\define internal fastcc void @sx_0(ptr %env) {
        \\entry:
        \\  ret void
        \\}@unused = private constant i64 0
        \\define i32 @main() {
        \\entry:
        \\  call fastcc void @sx_0(ptr null)
        \\  ret i32 0
        \\}
        \\
    , false);
    try std.testing.expectEqual(@as(usize, 2), units.len);
    const entry = for (units) |unit| {
        if (std.mem.eql(u8, unit.name, "entry")) break unit;
    } else return error.TestUnexpectedResult;
    try std.testing.expect(std.mem.indexOf(u8, entry.text, "declare hidden fastcc void @sx.fn.") != null);
}

fn fixtureFunction(name: []const u8) Ir.Function {
    return .{ .name = name, .parameter_types = &.{}, .return_type = .int, .value_types = &.{}, .blocks = &.{} };
}

fn findUnit(units: []const Unit, name: []const u8) !Unit {
    for (units) |unit| if (std.mem.eql(u8, unit.name, name)) return unit;
    return error.TestUnexpectedResult;
}

test "consumer numbering preserves units while bodies and imported layouts invalidate" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const caller = fixtureFunction("caller");
    const helper = fixtureFunction("helper");
    const first: Ir.Program = .{ .functions = &.{ caller, helper }, .structures = &.{.{ .name = "Point", .fields = &.{} }} };
    const second: Ir.Program = .{ .functions = &.{ helper, caller }, .structures = &.{ .{ .name = "Unused", .fields = &.{} }, .{ .name = "Point", .fields = &.{} } } };
    const text =
        \\%sx.type.0 = type { i64 }
        \\define internal fastcc i64 @sx_0(ptr %env) {
        \\entry:
        \\  %result = call fastcc i64 @sx_1(ptr %env)
        \\  ret i64 %result
        \\}
        \\define internal fastcc i64 @sx_1(ptr %env) {
        \\entry:
        \\  %value = alloca %sx.type.0
        \\  ret i64 17
        \\}
        \\
    ;
    const renumbered =
        \\%sx.type.1 = type { i64 }
        \\define internal fastcc i64 @sx_0(ptr %env) {
        \\entry:
        \\  %value = alloca %sx.type.1
        \\  ret i64 17
        \\}
        \\define internal fastcc i64 @sx_1(ptr %env) {
        \\entry:
        \\  %result = call fastcc i64 @sx_0(ptr %env)
        \\  ret i64 %result
        \\}
        \\
    ;
    const caller_name = try Identity.functionName(a, first, caller);
    const helper_name = try Identity.functionName(a, first, helper);
    const original = try split(a, first, text, true);
    const relocated = try split(a, second, renumbered, true);
    for (original) |unit| try std.testing.expectEqualStrings(unit.text, (try findUnit(relocated, unit.name)).text);
    const caller_unit = try findUnit(original, caller_name);
    try std.testing.expect(std.mem.indexOf(u8, caller_unit.text, "define available_externally hidden") != null);
    for ([_][]const u8{
        try replace(a, text, "ret i64 17", "ret i64 18"),
        try replace(a, text, "type { i64 }", "type { i64, i64 }"),
    }) |changed| {
        const units = try split(a, first, changed, true);
        try std.testing.expect(!std.mem.eql(u8, caller_unit.text, (try findUnit(units, caller_name)).text));
        try std.testing.expect(!std.mem.eql(u8, (try findUnit(original, helper_name)).text, (try findUnit(units, helper_name)).text));
    }
    const independent = try split(a, first, text, false);
    const changed = try split(a, first, try replace(a, text, "ret i64 17", "ret i64 18"), false);
    try std.testing.expectEqualStrings((try findUnit(independent, caller_name)).text, (try findUnit(changed, caller_name)).text);
}

test "address references do not import bodies and quoted bytes are never renamed" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = arena.allocator();
    const program: Ir.Program = .{ .functions = &.{ fixtureFunction("caller"), fixtureFunction("callback") } };
    const units = try split(a, program,
        \\@literal = private constant [6 x i8] c"@sx_1\00"
        \\declare void @consume(ptr, ptr)
        \\define internal fastcc i64 @sx_0(ptr %env) {
        \\entry:
        \\  call void @consume(ptr @sx_1, ptr @literal)
        \\  ret i64 0
        \\}
        \\define internal fastcc i64 @sx_1(ptr %env) {
        \\entry:
        \\  ret i64 17
        \\}
        \\
    , true);
    const caller = try findUnit(units, try Identity.functionName(a, program, program.functions[0]));
    try std.testing.expect(std.mem.indexOf(u8, caller.text, "available_externally") == null);
    try std.testing.expect(std.mem.indexOf(u8, caller.text, "c\"@sx_1\\00\"") != null);
}
