//! Compatibility of declarations sharing one external LLVM symbol.
const std = @import("std");

pub fn compatible(previous: anytype, function: @TypeOf(previous)) bool {
    if (!std.mem.eql(u8, previous.provider, function.provider)) return false;
    const same_signature = previous.return_type == function.return_type and
        std.mem.eql(@TypeOf(function.return_type), previous.parameters, function.parameters);
    return same_signature or (objcMessage(previous) and objcMessage(function));
}

fn objcMessage(function: anytype) bool {
    return std.mem.eql(u8, function.source_name, "objc_msgSend") and
        function.parameters.len >= 2 and
        objcHandle(function.parameters[0]) and
        objcHandle(function.parameters[1]);
}

fn objcHandle(type_value: anytype) bool {
    // The C boundary can represent id/SEL as a pointer or as its full-width
    // bits. These fixed call signatures keep arguments in their ABI registers;
    // making objc_msgSend a C variadic call would change the ARM64 ABI.
    return switch (type_value) {
        .address, .uint, .int => true,
        else => false,
    };
}

const Ir = @import("../../Sources/Ir.zig");
const Boundary = @import("../../Sources/Boundary.zig");

fn message(parameters: []const Ir.Type) Boundary.Function {
    return .{ .name = "message", .provider = "Boundary.SystemMenu", .source_name = "objc_msgSend", .parameters = parameters, .return_type = .void };
}

test "Objective-C dispatch accepts pointer and full-width word handles" {
    for ([_]Ir.Type{ .address, .uint, .int }) |receiver| for ([_]Ir.Type{ .address, .uint, .int }) |selector| {
        const first = message(&.{ receiver, selector });
        var second = message(&.{ receiver, selector, .uint8 });
        try std.testing.expect(compatible(first, second));
        second = message(&.{ receiver, selector, .float64 });
        second.return_type = .float64;
        try std.testing.expect(compatible(first, second));
    };
}

test "Objective-C dispatch excludes narrow floating and missing handles" {
    for ([_]Ir.Type{ .uint8, .int32, .uint32, .float32, .float64, .bool }) |invalid| {
        for ([_][]const Ir.Type{ &.{ invalid, .uint }, &.{ .uint, invalid } }) |parameters| {
            const first = message(parameters);
            var second = first;
            second.return_type = .uint;
            try std.testing.expect(!compatible(first, second));
        }
    }
    const first = message(&.{.uint});
    var second = first;
    second.return_type = .uint;
    try std.testing.expect(!compatible(first, second));
}

test "LLVM boundary policy retains provider and ordinary C conflicts" {
    const first = message(&.{ .uint, .uint });
    var second = message(&.{ .uint, .uint, .uint8 });
    second.provider = "Boundary.Other";
    try std.testing.expect(!compatible(first, second));
    var ordinary = first;
    ordinary.source_name = "ordinary_c";
    second = ordinary;
    second.return_type = .uint;
    try std.testing.expect(!compatible(ordinary, second));
    second = ordinary;
    second.name = "identical_alias";
    try std.testing.expect(compatible(ordinary, second));
}
