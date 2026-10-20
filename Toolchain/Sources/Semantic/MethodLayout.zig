const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");

pub fn extendStructures(
    allocator: std.mem.Allocator,
    program: Ast.Program,
    base: []const Ir.Structure,
    mutating: []const bool,
) ![]const Ir.Structure {
    var extra: usize = 0;
    var flat: usize = 0;
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable and method.protocol_result == null) extra += 1;
            flat += 1;
        }
    }
    const structures = try allocator.alloc(Ir.Structure, base.len + extra);
    @memcpy(structures[0..base.len], base);
    var next = base.len;
    flat = 0;
    for (program.structures, 0..) |structure, structure_index| {
        for (structure.methods, 0..) |method, method_index| {
            if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable and method.protocol_result == null) {
                const fields = try allocator.alloc(Ir.StructureField, 2);
                fields[0] = .{ .name = "self", .type = .structure(structure_index), .mutable = false };
                fields[1] = .{ .name = "value", .type = method.return_type, .mutable = false };
                structures[next] = .{
                    .name = try std.fmt.allocPrint(allocator, "{s}.{s}#result{d}", .{ structure.name, method.name, method_index }),
                    .fields = fields,
                };
                next += 1;
            }
            flat += 1;
        }
    }
    return structures;
}

pub fn methodIrReturnType(self: anytype, structure_index: usize, flat: usize, method: Ast.Function) Ast.Type {
    if (method.return_mode == .mutable) return .address;
    if (!self.method_mutability[flat]) return method.return_type;
    if (method.return_type == .void) return .structure(structure_index);
    return methodResultType(self.program, self.method_mutability, self.program.type_names.len, flat).?;
}

pub fn methodResultType(program: Ast.Program, mutating: []const bool, base_count: usize, target_flat: usize) ?Ast.Type {
    var result = base_count;
    var flat: usize = 0;
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            if (flat == target_flat) return if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable)
                method.protocol_result orelse Ast.Type.structure(result)
            else
                null;
            if (mutating[flat] and method.return_type != .void and method.return_mode != .mutable and method.protocol_result == null) result += 1;
            flat += 1;
        }
    }
    return null;
}

pub fn methodFunctionId(program: Ast.Program, structure_index: usize, method_index: usize) Ir.FunctionId {
    var result = program.functions.len;
    for (program.structures) |structure| result += structure.constructors.len;
    for (program.structures[0..structure_index]) |structure| if (!structure.is_protocol) {
        result += structure.methods.len;
    };
    return result + method_index;
}

pub fn flatMethodIndex(program: Ast.Program, structure_index: usize, method_index: usize) usize {
    var result: usize = 0;
    for (program.structures[0..structure_index]) |structure| result += structure.methods.len;
    return result + method_index;
}
