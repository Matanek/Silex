pub const silex_compiler_api = @import("Sources/OptimizerOracleApi.zig");
pub const main = @import("Sources/Main.zig").main;

test {
    _ = @import("Sources/PackageArchive.zig");
    _ = @import("Sources/PackageDescriptor.zig");
    _ = @import("Sources/PackageResources.zig");
    _ = @import("Sources/PackageSnapshot.zig");
    _ = @import("Sources/MacOS/Link.zig");
    _ = @import("Sources/Llvm/Units.zig");
    _ = @import("Sources/Llvm/Store.zig");
}
