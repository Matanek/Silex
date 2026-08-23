const Ir = @import("../Ir.zig");

pub fn isEligible(function: Ir.Function) bool {
    if (containsCalls(function)) return false;
    return hasRepeatedCollectionRead(function);
}

fn containsCalls(function: Ir.Function) bool {
    for (function.blocks) |block| {
        for (block.instructions) |instruction| switch (instruction) {
            .call, .indirect_call, .boundary_call, .dynamic_call => return true,
            else => {},
        };
    }
    return false;
}

fn hasRepeatedCollectionRead(function: Ir.Function) bool {
    for (function.blocks) |block| {
        for (block.instructions, 0..) |instruction, index| {
            const candidate = switch (instruction) {
                .collection_load => |load| load,
                else => continue,
            };
            for (block.instructions[0..index]) |previous_instruction| {
                const previous = switch (previous_instruction) {
                    .collection_load => |load| load,
                    else => continue,
                };
                if (sameCollectionSource(block.instructions, previous.collection, candidate.collection) and
                    sameCollectionIndex(block.instructions, previous.index, candidate.index)) return true;
            }
        }
    }
    return false;
}

fn sameCollectionSource(instructions: []const Ir.Instruction, left: Ir.ValueId, right: Ir.ValueId) bool {
    if (left == right) return true;
    const left_load = fieldLoadProducing(instructions, left) orelse return false;
    const right_load = fieldLoadProducing(instructions, right) orelse return false;
    return left_load.base == right_load.base and left_load.field == right_load.field;
}

fn sameCollectionIndex(instructions: []const Ir.Instruction, left: Ir.ValueId, right: Ir.ValueId) bool {
    if (left == right) return true;
    const left_load = localLoadProducing(instructions, left) orelse return false;
    const right_load = localLoadProducing(instructions, right) orelse return false;
    return left_load.local == right_load.local;
}

fn fieldLoadProducing(instructions: []const Ir.Instruction, value: Ir.ValueId) ?Ir.Instruction.FieldLoad {
    for (instructions) |instruction| switch (instruction) {
        .field_load => |load| if (load.result == value) return load,
        else => {},
    };
    return null;
}

fn localLoadProducing(instructions: []const Ir.Instruction, value: Ir.ValueId) ?Ir.Instruction.LocalLoad {
    for (instructions) |instruction| switch (instruction) {
        .local_load => |load| if (load.result == value) return load,
        else => {},
    };
    return null;
}
