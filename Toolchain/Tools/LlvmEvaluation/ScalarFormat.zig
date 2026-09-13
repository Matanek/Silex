const Ir = @import("silex_optimizer_api").Ir;

// Use the native scalar formatter for identical text in interpolation and print.
// Leaves %tN.format.output and %tN.format.length without a heap allocation.
pub fn emit(self: anytype, serial: usize, operand_type: Ir.Type, operand: Ir.ValueId) error{OutOfMemory}!void {
    try self.write("  %t{d}.format.scratch = alloca [384 x i8]\n", .{serial});
    try self.write(
        "  %t{d}.format.output = getelementptr [384 x i8], ptr %t{d}.format.scratch, i32 0, i32 0\n",
        .{ serial, serial },
    );
    if (operand_type.isInteger()) {
        if (operand_type.bitWidth() == 64) {
            try self.write("  %t{d}.format.bits = add i64 0, %v{d}\n", .{ serial, operand });
        } else {
            try self.write(
                "  %t{d}.format.bits = {s} i{d} %v{d} to i64\n",
                .{ serial, if (operand_type.isSignedInteger()) "sext" else "zext", operand_type.bitWidth(), operand },
            );
        }
        try self.write(
            "  %t{d}.format.length = call i64 @{s}(i64 %t{d}.format.bits, ptr %t{d}.format.output)\n",
            .{ serial, if (operand_type.isSignedInteger()) "silex_format_signed" else "silex_format_unsigned", serial, serial },
        );
    } else if (operand_type == .float32) {
        try self.write("  %t{d}.format.f32 = bitcast float %v{d} to i32\n", .{ serial, operand });
        try self.write("  %t{d}.format.bits = zext i32 %t{d}.format.f32 to i64\n", .{ serial, serial });
        try self.write(
            "  %t{d}.format.length = call i64 @silex_format_float(i64 %t{d}.format.bits, ptr %t{d}.format.output, i64 0)\n",
            .{ serial, serial, serial },
        );
    } else {
        try self.write("  %t{d}.format.bits = bitcast double %v{d} to i64\n", .{ serial, operand });
        try self.write(
            "  %t{d}.format.length = call i64 @silex_format_float(i64 %t{d}.format.bits, ptr %t{d}.format.output, i64 1)\n",
            .{ serial, serial, serial },
        );
    }
}
