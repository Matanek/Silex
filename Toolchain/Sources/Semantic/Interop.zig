const std = @import("std");
const Ast = @import("../Ast.zig");
const Boundary = @import("../Boundary.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Types = @import("../Types.zig");

pub fn prepare(self: anytype) ![]const Boundary.Function {
    var result: std.ArrayList(Boundary.Function) = .empty;
    for (self.program.external_functions, 0..) |external, index| {
        for (self.program.external_functions[0..index]) |previous| {
            if (std.mem.eql(u8, external.name, previous.name)) {
                return self.fail(external.name_position, "foreign function binding is already declared");
            }
        }
        for (self.program.functions) |function| {
            if (std.mem.eql(u8, external.name, function.name)) {
                return self.fail(external.name_position, "foreign function binding collides with a function declaration");
            }
        }
        if (!std.mem.eql(u8, external.library, "MacOS.lib_system")) {
            return self.fail(external.position, "unknown macOS interop library");
        }
        if (!std.mem.eql(u8, external.source_name, "write")) {
            return self.fail(external.position, "MacOS.lib_system function is not supported yet");
        }
        const parameters = try self.allocator.alloc(Types.Type, external.parameters.len);
        for (external.parameters, 0..) |parameter, parameter_index| {
            parameters[parameter_index] = try externalType(self, parameter, external.position);
        }
        const return_type = try externalType(self, external.return_type, external.position);
        if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or
            parameters[2] != .uint or return_type != .int)
        {
            return self.fail(external.position, "write expects func(int32, C.Pointer<uint8>, C.Size) C.SignedSize");
        }
        try result.append(self.allocator, .{
            .name = external.name,
            .provider = external.library,
            .source_name = external.source_name,
            .parameters = parameters,
            .return_type = return_type,
        });
    }
    return result.toOwnedSlice(self.allocator);
}

fn externalType(self: anytype, value: Ast.ExternalType, position: anytype) !Types.Type {
    return switch (value) {
        .int32 => .int32,
        .size => .uint,
        .signed_size => .int,
        .read_pointer => |child| if (child == .uint8)
            .address
        else
            self.fail(position, "C.Pointer currently supports only uint8"),
    };
}

pub fn analyzeIntrinsic(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.pointer")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.pointer expects one string");
        }
        const source = try self.analyzeExpression(builder, call.arguments[0]);
        if (source.type != .str) return self.fail(call.arguments[0].position, "C.pointer expects a string");
        const result = try self.newValue(builder, .address);
        try self.emit(builder, .{ .string_address = .{ .result = result, .operand = source.value } });
        return .{ .type = .address, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.byte_count")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.byte_count expects one string");
        }
        const source = try self.analyzeExpression(builder, call.arguments[0]);
        if (source.type != .str) return self.fail(call.arguments[0].position, "C.byte_count expects a string");
        const result = try self.newValue(builder, .uint);
        try self.emit(builder, .{ .string_byte_count = .{ .result = result, .operand = source.value } });
        return .{ .type = .uint, .value = result };
    }
    return null;
}

pub fn analyzeCall(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    for (self.external_functions, 0..) |external, external_index| {
        if (!std.mem.eql(u8, external.name, call.name)) continue;
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0) {
            return self.fail(call.name_position, "foreign function calls use positional arguments");
        }
        if (call.arguments.len != external.parameters.len) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "foreign function '{s}' expects {d} arguments, found {d}",
                .{ call.name, external.parameters.len, call.arguments.len },
            );
            return self.fail(call.name_position, message);
        }
        var arguments: std.ArrayList(Ir.ValueId) = .empty;
        for (call.arguments, external.parameters, 0..) |argument_expression, expected, argument_index| {
            var argument = try self.analyzeExpressionExpected(builder, argument_expression, expected);
            if (argument.type != expected and self.canImplicitlyConvert(argument.type, expected)) {
                argument = try self.coerce(builder, argument, expected, argument_expression.position);
            }
            if (argument.type != expected) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "argument {d} of foreign function '{s}' expects '{s}', found '{s}'",
                    .{ argument_index + 1, call.name, self.typeName(expected), self.typeName(argument.type) },
                );
                return self.fail(argument_expression.position, message);
            }
            try arguments.append(self.allocator, argument.value);
        }
        const result = try self.newValue(builder, external.return_type);
        try self.emit(builder, .{ .boundary_call = .{
            .result = result,
            .function = external_index,
            .arguments = try arguments.toOwnedSlice(self.allocator),
        } });
        return .{ .type = external.return_type, .value = result };
    }
    return null;
}
