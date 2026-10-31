const std = @import("std");
const Machine = @import("Arm64/Machine.zig");
const Arm64Registers = @import("Arm64/RegisterAllocation.zig");
const X64Registers = @import("X64/RegisterAllocation.zig");
const Target = @import("Target.zig").Target;

// Register placement is independent of source-level Debug information.
// Existing target allocators pin addressed storage and values crossing calls;
// unsupported functions retain their stack form and all safety operations.
pub fn allocate(allocator: std.mem.Allocator, program: Machine.Program, target: Target) !Machine.Program {
    if (target.architecture == .x64) return X64Registers.allocateProgram(allocator, program);
    const functions = try allocator.alloc(Machine.Function, program.functions.len);
    for (program.functions, 0..) |function, index| {
        var current = function;
        const allocation = try Arm64Registers.allocateWithExternals(allocator, current, program.external_functions);
        current.register_slots = allocation.residences;
        current.float_register_slots = allocation.float_residences;
        current.float_lane_slots = allocation.float_lane_residences;
        current.frame_size = allocation.frame_size;
        functions[index] = current;
    }
    var result = program;
    result.functions = functions;
    try Machine.validate(result);
    return result;
}
