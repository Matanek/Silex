pub const silex_compiler_api = @import("Sources/OptimizerOracleApi.zig");
pub const main = @import("Sources/Main.zig").main;

test {
    // The exported main is lazy in test builds. Keep these semantic
    // regression suites reachable from the actual build root.
    _ = @import("Sources/ClassTests.zig");
    _ = @import("Sources/ReflectionTests.zig");
    _ = @import("Sources/TypedResourceTests.zig");
    _ = @import("Sources/Project/CoreTests.zig");
    _ = @import("Sources/Interpreter.zig");
    _ = @import("Sources/Optimize/ValueRanges.zig");
    _ = @import("Sources/MacOS/Link.zig");
    _ = @import("Sources/Llvm/Units.zig");
    _ = @import("Sources/Llvm/Store.zig");
}
