const std = @import("std");
const Ast = @import("../Ast.zig");
const Support = @import("Support.zig");
const Borrowing = @import("Borrowing.zig");
const Collections = @import("Collections.zig");
const Inheritance = @import("Inheritance.zig");
const flatMethodIndex = @import("MethodLayout.zig").flatMethodIndex;

pub fn infer(allocator: std.mem.Allocator, program: Ast.Program) ![]const bool {
    const count = methodCount(program);
    const mutating = try allocator.alloc(bool, count);
    @memset(mutating, false);
    var flat: usize = 0;
    for (program.structures) |structure| {
        for (structure.methods) |method| {
            mutating[flat] = method.return_mode == .mutable or intrinsicMutates(method.intrinsic) or statementsWriteSelf(method.statements);
            flat += 1;
        }
    }

    var changed = true;
    while (changed) {
        changed = false;
        flat = 0;
        for (program.structures, 0..) |structure, structure_index| {
            for (structure.methods) |method| {
                if (method.protocol_witness) |origin| {
                    for (program.structures, 0..) |protocol, protocol_index| {
                        if (!std.mem.eql(u8, protocol.name, origin.protocol)) continue;
                        const source_flat = flatMethodIndex(program, protocol_index, origin.method);
                        if (mutating[source_flat] and !mutating[flat]) {
                            mutating[flat] = true;
                            changed = true;
                        }
                    }
                }
                if (!mutating[flat] and statementsCallMutatingSelf(program, structure_index, method.statements, mutating)) {
                    mutating[flat] = true;
                    changed = true;
                }
                flat += 1;
            }
        }
        flat = 0;
        for (program.structures, 0..) |structure, structure_index| {
            for (structure.methods) |method| {
                if (method.is_override) {
                    if (inheritedOverrideIndex(program, structure_index, method)) |base_flat| {
                        if (mutating[flat] and !mutating[base_flat]) {
                            mutating[base_flat] = true;
                            changed = true;
                        } else if (!mutating[flat] and mutating[base_flat]) {
                            mutating[flat] = true;
                            changed = true;
                        }
                    }
                }
                flat += 1;
            }
        }
    }
    return mutating;
}

fn inheritedOverrideIndex(
    program: Ast.Program,
    structure_index: usize,
    method: Ast.Function,
) ?usize {
    var current = program.structures[structure_index].base;
    while (current) |base_type| {
        const base_index = base_type.structureIndex() orelse return null;
        if (base_index >= program.structures.len) return null;
        const base = program.structures[base_index];
        for (base.methods, 0..) |candidate, method_index| {
            if (!candidate.is_static and Inheritance.sameSignature(candidate, method)) {
                return flatMethodIndex(program, base_index, method_index);
            }
        }
        current = base.base;
    }
    return null;
}

fn methodCount(program: Ast.Program) usize {
    var result: usize = 0;
    for (program.structures) |structure| result += structure.methods.len;
    return result;
}

fn intrinsicMutates(intrinsic: ?Ast.FunctionIntrinsic) bool {
    const value = intrinsic orelse return false;
    return switch (value) {
        .resource_insert, .resource_get_mut, .resource_try_get_mut, .resource_remove, .resource_clear, .component_get_mut, .world_component_get_mut => true,
        .resource_scope, .resource_discard, .resource_has, .resource_get, .resource_try_get, .system_adapter => false,
    };
}

fn statementsWriteSelf(statements: []const Ast.Statement) bool {
    for (statements) |statement| switch (statement) {
        .assignment_statement => |assignment| if (std.mem.eql(u8, assignment.target.name, "self")) return true,
        .expression_statement => |expression| {
            if (expressionMutatesSelfCollection(expression)) return true;
            if (expression.value == .match_expression) for (expression.value.match_expression.branches) |branch| {
                if (branch.statements) |nested| if (statementsWriteSelf(nested)) return true;
            };
        },
        .if_statement => |conditional| {
            for (conditional.branches) |branch| if (statementsWriteSelf(branch.statements)) return true;
            if (conditional.else_statements) |nested| if (statementsWriteSelf(nested)) return true;
        },
        .while_statement => |loop| if (statementsWriteSelf(loop.statements)) return true,
        .for_statement => |loop| if (statementsWriteSelf(loop.statements)) return true,
        .mutex_statement => |mutex| if (statementsWriteSelf(mutex.statements)) return true,
        else => {},
    };
    return false;
}

fn expressionMutatesSelfCollection(expression: *const Ast.Expression) bool {
    if (expression.value != .call) return false;
    const call = expression.value.call;
    if (!Collections.isMutation(call.name)) return false;
    var receiver = call.receiver orelse return false;
    while (receiver.value == .field_access) receiver = receiver.value.field_access.base;
    return receiver.value == .identifier and std.mem.eql(u8, receiver.value.identifier, "self");
}

fn statementsCallMutatingSelf(program: Ast.Program, structure_index: usize, statements: []const Ast.Statement, mutating: []const bool) bool {
    for (statements) |statement| switch (statement) {
        .variable_declaration => |declaration| if (declaration.initializer) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .assignment_statement => |assignment| if (assignment.value) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .return_statement => |returned| if (returned.value) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .yield_statement => |yielded| if (yielded.value) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .expression_statement => |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .print_statement => |printed| for (printed.values) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) return true,
        .assert_statement => |assertion| if (expressionCallsMutatingSelf(program, structure_index, assertion.condition, mutating) or expressionCallsMutatingSelf(program, structure_index, assertion.message, mutating)) return true,
        .panic_statement => |panic_statement| if (expressionCallsMutatingSelf(program, structure_index, panic_statement.value, mutating)) return true,
        .if_statement => |conditional| {
            for (conditional.branches) |branch| {
                if (expressionCallsMutatingSelf(program, structure_index, branch.condition.source(), mutating) or statementsCallMutatingSelf(program, structure_index, branch.statements, mutating)) return true;
            }
            if (conditional.else_statements) |nested| if (statementsCallMutatingSelf(program, structure_index, nested, mutating)) return true;
        },
        .while_statement => |loop| if (expressionCallsMutatingSelf(program, structure_index, loop.condition.source(), mutating) or statementsCallMutatingSelf(program, structure_index, loop.statements, mutating)) return true,
        .for_statement => |loop| {
            switch (loop.source) {
                .collection => |source| {
                    const collection_source = if (source.value == .call and std.mem.eql(u8, source.value.call.name, "indexed")) source.value.call.receiver orelse source else source;
                    if (loop.mode == .mutable) if (Borrowing.rootName(collection_source)) |root| if (std.mem.eql(u8, root, "self")) return true;
                    if (expressionCallsMutatingSelf(program, structure_index, source, mutating)) return true;
                },
                .range => |range| if (expressionCallsMutatingSelf(program, structure_index, range.start, mutating) or expressionCallsMutatingSelf(program, structure_index, range.end, mutating)) return true,
            }
            if (statementsCallMutatingSelf(program, structure_index, loop.statements, mutating)) return true;
        },
        .mutex_statement => |mutex| if (statementsCallMutatingSelf(program, structure_index, mutex.statements, mutating)) return true,
        else => {},
    };
    return false;
}

fn expressionCallsMutatingSelf(program: Ast.Program, structure_index: usize, expression: *const Ast.Expression, mutating: []const bool) bool {
    return switch (expression.value) {
        .call => |call| calls: {
            if (expressionMutatesSelfCollection(expression)) break :calls true;
            if (call.receiver) |receiver| {
                if (receiverStructure(program, structure_index, receiver)) |target| {
                    if (mutatingMethodInStructure(program, target, call.name, call.arguments.len + call.named_arguments.len, mutating)) break :calls true;
                }
                if (expressionCallsMutatingSelf(program, structure_index, receiver, mutating)) break :calls true;
            }
            for (call.arguments) |argument| if (expressionCallsMutatingSelf(program, structure_index, argument, mutating)) break :calls true;
            for (call.named_arguments) |argument| if (expressionCallsMutatingSelf(program, structure_index, argument.value, mutating)) break :calls true;
            break :calls false;
        },
        .cascade => |cascade| calls: {
            if (expressionCallsMutatingSelf(program, structure_index, cascade.receiver, mutating)) break :calls true;
            const receiver_structure = receiverStructure(program, structure_index, cascade.receiver);
            for (cascade.operations) |operation| switch (operation) {
                .method_call => |method| {
                    if (receiver_structure) |target| if (mutatingMethodInStructure(program, target, method.name, method.arguments.len + method.named_arguments.len, mutating)) break :calls true;
                    for (method.arguments) |argument| if (expressionCallsMutatingSelf(program, structure_index, argument, mutating)) break :calls true;
                    for (method.named_arguments) |argument| if (expressionCallsMutatingSelf(program, structure_index, argument.value, mutating)) break :calls true;
                },
                .field_assignment => |field| {
                    if (receiver_structure == structure_index) break :calls true;
                    if (expressionCallsMutatingSelf(program, structure_index, field.value, mutating)) break :calls true;
                },
            };
            break :calls false;
        },
        .field_access => |access| expressionCallsMutatingSelf(program, structure_index, access.base, mutating),
        .unary => |unary| calls: {
            if (unary.operator == .borrow_mutable) if (Borrowing.rootName(unary.operand)) |root| if (std.mem.eql(u8, root, "self")) break :calls true;
            if (expressionCallsMutatingSelf(program, structure_index, unary.operand, mutating)) break :calls true;
            if (unary.try_alternative) |alternative| {
                if (alternative.statements) |statements| if (statementsCallMutatingSelf(program, structure_index, statements, mutating)) break :calls true;
                if (alternative.message) |message| if (expressionCallsMutatingSelf(program, structure_index, message, mutating)) break :calls true;
            }
            break :calls false;
        },
        .binary => |binary| expressionCallsMutatingSelf(program, structure_index, binary.left, mutating) or expressionCallsMutatingSelf(program, structure_index, binary.right, mutating),
        .conversion => |conversion| expressionCallsMutatingSelf(program, structure_index, conversion.operand, mutating),
        .string_count => |operand| expressionCallsMutatingSelf(program, structure_index, operand, mutating),
        .interpolated_string => |interpolated| parts: {
            for (interpolated.parts) |part| switch (part) {
                .text => {},
                .expression => |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) break :parts true,
            };
            break :parts false;
        },
        .match_expression => |match_value| calls: {
            if (match_value.subject) |subject| if (expressionCallsMutatingSelf(program, structure_index, subject, mutating)) break :calls true;
            for (match_value.branches) |branch| {
                if (branch.condition) |condition| if (expressionCallsMutatingSelf(program, structure_index, condition, mutating)) break :calls true;
                if (branch.guard) |guard| if (expressionCallsMutatingSelf(program, structure_index, guard, mutating)) break :calls true;
                if (branch.value) |value| if (expressionCallsMutatingSelf(program, structure_index, value, mutating)) break :calls true;
                if (branch.statements) |statements| {
                    if (statementsWriteSelf(statements) or statementsCallMutatingSelf(program, structure_index, statements, mutating)) break :calls true;
                }
            }
            break :calls false;
        },
        else => false,
    };
}

fn receiverStructure(program: Ast.Program, root_structure: usize, expression: *const Ast.Expression) ?usize {
    return switch (expression.value) {
        .identifier => |name| if (std.mem.eql(u8, name, "self"))
            root_structure
        else if (std.mem.eql(u8, name, "super") and root_structure < program.structures.len)
            if (program.structures[root_structure].base) |base| base.structureIndex() else null
        else
            null,
        .field_access => |access| if (receiverStructure(program, root_structure, access.base)) |base| field: {
            if (base >= program.structures.len) break :field null;
            for (program.structures[base].fields) |field_value| {
                if (std.mem.eql(u8, field_value.name, access.name)) {
                    var field_type = field_value.type;
                    while (field_type.optionalChild()) |child| field_type = child;
                    return field_type.structureIndex();
                }
            }
            break :field null;
        } else null,
        else => null,
    };
}

fn mutatingMethodInStructure(program: Ast.Program, structure_index: usize, name: []const u8, arity: usize, mutating: []const bool) bool {
    if (structure_index >= program.structures.len) return false;
    const offset = flatMethodIndex(program, structure_index, 0);
    for (program.structures[structure_index].methods, 0..) |method, method_index| {
        const protocol_mutating = program.structures[structure_index].is_protocol and
            (if (method.accessor) |accessor| accessor.kind != .get else true);
        if ((mutating[offset + method_index] or protocol_mutating) and std.mem.eql(u8, method.name, name) and Support.acceptsArity(method.parameters, arity)) return true;
    }
    return false;
}
