const Ir = @import("../Ir.zig");

pub fn isEligible(function: Ir.Function) bool {
    if (containsCalls(function)) return false;
    return hasRepeatedCollectionRead(function) or hasMultipleCollectionReferences(function);
}

fn hasMultipleCollectionReferences(function: Ir.Function) bool {
    for (function.blocks) |block| {
        var references: usize = 0;
        for (block.instructions) |instruction| {
            if (instruction == .collection_reference) {
                references += 1;
                if (references > 1) return true;
            }
        }
    }
    return false;
}

fn containsCalls(function: Ir.Function) bool {
    for (function.blocks) |block| {
        for (block.instructions) |instruction| switch (instruction) {
            .call, .indirect_call, .boundary_call, .boundary_indirect_call, .dynamic_call => return true,
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
    const left_origin = copyOrigin(instructions, left);
    const right_origin = copyOrigin(instructions, right);
    if (left_origin == right_origin) return true;
    const left_load = fieldLoadProducing(instructions, left_origin) orelse return false;
    const right_load = fieldLoadProducing(instructions, right_origin) orelse return false;
    return left_load.base == right_load.base and left_load.field == right_load.field;
}

fn sameCollectionIndex(instructions: []const Ir.Instruction, left: Ir.ValueId, right: Ir.ValueId) bool {
    const left_origin = copyOrigin(instructions, left);
    const right_origin = copyOrigin(instructions, right);
    if (left_origin == right_origin) return true;
    const left_load = localLoadProducing(instructions, left_origin) orelse return false;
    const right_load = localLoadProducing(instructions, right_origin) orelse return false;
    return left_load.local == right_load.local;
}

fn copyOrigin(instructions: []const Ir.Instruction, value: Ir.ValueId) Ir.ValueId {
    var current = value;
    var remaining = instructions.len;
    while (remaining != 0) : (remaining -= 1) {
        var found: ?Ir.ValueId = null;
        for (instructions) |instruction| switch (instruction) {
            .copy => |copy| if (copy.result == current) {
                if (found != null) return current;
                found = copy.operand;
            },
            else => {},
        };
        current = found orelse return current;
    }
    return current;
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
