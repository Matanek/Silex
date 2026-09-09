const std = @import("std");
const MathBoundary = @import("Math/Boundary.zig");
const Types = @import("Types.zig");

pub const Function = struct {
    name: []const u8,
    provider: []const u8,
    source_name: []const u8,
    parameters: []const Types.Type,
    return_type: Types.Type,
    owner: usize = 0,
    package_private: bool = false,
    /// Proven standard math library, not a package archive with similar names.
    system_math: bool = false,
};

/// Returns whether a typed boundary is a proven scalar system-math operation.
/// These calls can produce NaN or infinity, but they cannot observe or mutate
/// Silex state and do not fail through the language runtime.
pub fn isPureScalarMath(function: Function) bool {
    const built_in = !function.package_private and
        (std.mem.eql(u8, function.provider, "MacOS.lib_system") or
            std.mem.eql(u8, function.provider, "Linux.kernel") or
            std.mem.eql(u8, function.provider, "Windows.ucrtbase"));
    if (!built_in and !function.system_math) return false;
    const math = MathBoundary.identify(function.source_name) orelse return false;
    const expected: Types.Type = if (math.precision == .float32) .float32 else .float64;
    const arity: usize = if (math.arity == .unary) 1 else 2;
    if (function.return_type != expected or function.parameters.len != arity) return false;
    for (function.parameters) |parameter| if (parameter != expected) return false;
    return true;
}

test "pure scalar math requires a trusted provider and exact signature" {
    const sqrt: Function = .{
        .name = "sqrt",
        .provider = "MacOS.lib_system",
        .source_name = "sqrtf",
        .parameters = &.{.float32},
        .return_type = .float32,
    };
    try std.testing.expect(isPureScalarMath(sqrt));

    var untrusted = sqrt;
    untrusted.provider = "Boundary.Custom";
    untrusted.package_private = true;
    try std.testing.expect(!isPureScalarMath(untrusted));
    untrusted.system_math = true;
    try std.testing.expect(isPureScalarMath(untrusted));

    var mismatched = sqrt;
    mismatched.return_type = .float64;
    try std.testing.expect(!isPureScalarMath(mismatched));
}
