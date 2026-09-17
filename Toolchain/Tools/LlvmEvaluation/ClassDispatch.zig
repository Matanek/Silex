const std = @import("std");
const Ir = @import("root").silex_compiler_api.Ir;
const Emitter = @import("Emitter.zig");
const Error = Emitter.Error;

fn requireClass(self: anytype, value: Ir.ValueId) Error!usize {
    const index = (try self.valueType(value)).structureIndex() orelse return error.InvalidProgram;
    if (!Emitter.materialClassStorage(self.program, index)) return error.UnsupportedType;
    return index;
}

// Inherited fields are a prefix of the derived allocation in portable IR.
// A cast changes the static view only, never the allocation or dynamic tag.
pub fn emitCast(self: anytype, value: Ir.Instruction.Copy) Error!void {
    _ = try requireClass(self, value.operand);
    _ = try requireClass(self, value.result);
    try self.write("  %v{d} = getelementptr i8, ptr %v{d}, i64 0\n", .{ value.result, value.operand });
}

// Each class_test instruction tests one exact dynamic type. The frontend
// composes the tests for descendants when the source asks for a base type.
pub fn emitTest(self: anytype, value: Ir.Instruction.ClassTest) Error!void {
    _ = try requireClass(self, value.operand);
    if (!Emitter.materialClassStorage(self.program, value.structure) or
        try self.valueType(value.result) != .bool) return error.InvalidProgram;
    const serial = self.nextTemporary();
    try self.write("  %t{d}.class.tag = load i64, ptr %v{d}\n", .{ serial, value.operand });
    try self.write("  %v{d} = icmp eq i64 %t{d}.class.tag, {d}\n", .{ value.result, serial, self.typeTag(value.structure) });
}

pub fn emitCall(self: anytype, block_id: usize, instruction_index: usize, value: Ir.Instruction.DynamicCall) Error!void {
    _ = try requireClass(self, value.receiver);
    if (value.function >= self.program.functions.len) return error.InvalidProgram;
    const fallback = self.program.functions[value.function];
    const serial = self.nextTemporary();
    try self.write("  %t{d}.dispatch.tag = load i64, ptr %v{d}\n", .{ serial, value.receiver });
    var selected = try std.fmt.allocPrint(self.allocator, "@sx_{d}", .{value.function});
    for (value.implementations, 0..) |implementation, index| {
        if (!Emitter.materialClassStorage(self.program, implementation.structure) or
            implementation.function >= self.program.functions.len) return error.InvalidProgram;
        const target = self.program.functions[implementation.function];
        if (target.capture_types.len != 0 or target.parameter_types.len != fallback.parameter_types.len)
            return error.InvalidProgram;
        // Receiver static types may differ; their LLVM representation is ptr.
        // Every other argument and the result must retain the same call ABI.
        for (target.parameter_types, fallback.parameter_types) |actual, expected| {
            if (!std.mem.eql(u8, try Emitter.llvmType(self.allocator, self.program, actual), try Emitter.llvmType(self.allocator, self.program, expected))) return error.InvalidProgram;
        }
        const symbol = try targetSymbol(self.allocator, self.program, value.function, implementation.function);
        try self.write("  %t{d}.dispatch.is{d} = icmp eq i64 %t{d}.dispatch.tag, {d}\n", .{
            serial, index, serial, self.typeTag(implementation.structure),
        });
        try self.write("  %t{d}.dispatch.target{d} = select i1 %t{d}.dispatch.is{d}, ptr {s}, ptr {s}\n", .{
            serial, index, serial, index, symbol, selected,
        });
        selected = try std.fmt.allocPrint(self.allocator, "%t{d}.dispatch.target{d}", .{ serial, index });
    }
    try self.emitCallTo(block_id, instruction_index, .{
        .result = value.result,
        .function = value.function,
        .arguments = value.arguments,
    }, selected);
}

pub fn isAncestor(program: Ir.Program, ancestor: usize, derived: usize) bool {
    var current: ?usize = derived;
    var visited: usize = 0;
    while (current) |index| {
        if (index >= program.structures.len or visited >= program.structures.len) return false;
        if (index == ancestor) return true;
        current = program.structures[index].base;
        visited += 1;
    }
    return false;
}

fn needsAdapter(allocator: std.mem.Allocator, program: Ir.Program, fallback: usize, target: usize) Error!bool {
    if (fallback >= program.functions.len or target >= program.functions.len) return error.InvalidProgram;
    return !std.mem.eql(u8, try Emitter.llvmType(allocator, program, program.functions[fallback].return_type), try Emitter.llvmType(allocator, program, program.functions[target].return_type));
}

fn targetSymbol(allocator: std.mem.Allocator, program: Ir.Program, fallback: usize, target: usize) Error![]const u8 {
    return if (try needsAdapter(allocator, program, fallback, target))
        std.fmt.allocPrint(allocator, "@sx.dispatch.adapter.{d}.{d}", .{ fallback, target })
    else
        std.fmt.allocPrint(allocator, "@sx_{d}", .{target});
}

// Mutable virtual methods return a synthetic { self, value } structure. An
// override names a different structure with a derived self field. Rebuild that
// result explicitly instead of calling through a mismatched LLVM function type.
pub fn emitAdapters(output: *std.ArrayList(u8), allocator: std.mem.Allocator, program: Ir.Program, functions: []const ?Ir.Function) Error!void {
    var emitted: std.AutoHashMap([2]usize, void) = .init(allocator);
    defer emitted.deinit();
    var writer: AdapterWriter = .{ .output = output, .allocator = allocator, .program = program };
    for (functions) |maybe_function| {
        const function = maybe_function orelse continue;
        for (function.blocks) |block| for (block.instructions) |instruction| {
            if (instruction != .dynamic_call) continue;
            const call = instruction.dynamic_call;
            for (call.implementations) |implementation| {
                const key = [2]usize{ call.function, implementation.function };
                if (!try needsAdapter(allocator, program, key[0], key[1])) continue;
                const entry = try emitted.getOrPut(key);
                if (entry.found_existing) continue;
                try writer.emit(key[0], key[1]);
            }
        };
    }
}

const AdapterWriter = struct {
    output: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    program: Ir.Program,
    serial: usize = 0,

    fn write(self: *AdapterWriter, comptime format: []const u8, arguments: anytype) Error!void {
        const text = try std.fmt.allocPrint(self.allocator, format, arguments);
        defer self.allocator.free(text);
        try self.output.appendSlice(self.allocator, text);
    }

    fn emit(self: *AdapterWriter, fallback_index: usize, target_index: usize) Error!void {
        const fallback = self.program.functions[fallback_index];
        const target = self.program.functions[target_index];
        if (fallback.capture_types.len != 0 or target.capture_types.len != 0 or
            fallback.parameter_types.len != target.parameter_types.len) return error.InvalidProgram;
        const expected = try Emitter.llvmType(self.allocator, self.program, fallback.return_type);
        const actual = try Emitter.llvmType(self.allocator, self.program, target.return_type);
        try self.write("define internal fastcc {s} {s}(ptr %environment", .{
            expected, try targetSymbol(self.allocator, self.program, fallback_index, target_index),
        });
        for (fallback.parameter_types, target.parameter_types, 0..) |parameter, target_parameter, index| {
            const name = try Emitter.llvmType(self.allocator, self.program, parameter);
            if (!std.mem.eql(u8, name, try Emitter.llvmType(self.allocator, self.program, target_parameter))) return error.InvalidProgram;
            try self.write(", {s} %argument{d}", .{
                if (try Emitter.indirectSilexParameter(self.program, parameter)) "ptr" else name, index,
            });
        }
        try self.write(") {{\nentry:\n  %result = call fastcc {s} @sx_{d}(ptr null", .{ actual, target_index });
        for (target.parameter_types, 0..) |parameter, index|
            try self.write(", {s} %argument{d}", .{
                if (try Emitter.indirectSilexParameter(self.program, parameter)) "ptr" else try Emitter.llvmType(self.allocator, self.program, parameter), index,
            });
        try self.write(")\n", .{});
        const result = try self.retype(target.return_type, fallback.return_type, "%result");
        try self.write("  ret {s} {s}\n}}\n", .{ expected, result });
    }

    fn retype(self: *AdapterWriter, source: Ir.Type, destination: Ir.Type, value: []const u8) Error![]const u8 {
        const source_name = try Emitter.llvmType(self.allocator, self.program, source);
        const destination_name = try Emitter.llvmType(self.allocator, self.program, destination);
        if (std.mem.eql(u8, source_name, destination_name)) return value;
        const source_index = source.structureIndex() orelse return error.InvalidProgram;
        const destination_index = destination.structureIndex() orelse return error.InvalidProgram;
        const from = self.program.structures[source_index];
        const to = self.program.structures[destination_index];
        if (from.is_class or to.is_class or from.fields.len != to.fields.len or from.fields.len == 0)
            return error.InvalidProgram;
        var result: []const u8 = "undef";
        for (from.fields, to.fields, 0..) |field, target_field, index| {
            const serial = self.serial;
            self.serial += 1;
            const element = try std.fmt.allocPrint(self.allocator, "%cast.field{d}", .{serial});
            try self.write("  {s} = extractvalue {s} {s}, {d}\n", .{ element, source_name, value, index });
            const converted = try self.retype(field.type, target_field.type, element);
            const inserted = try std.fmt.allocPrint(self.allocator, "%cast.result{d}", .{serial});
            try self.write("  {s} = insertvalue {s} {s}, {s} {s}, {d}\n", .{
                inserted,                                                              destination_name, result,
                try Emitter.llvmType(self.allocator, self.program, target_field.type), converted,        index,
            });
            result = inserted;
        }
        return result;
    }
};
