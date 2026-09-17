// Linkable support for the LLVM backend: the exact native formatter and the
// layout-independent cycle graph runtime. The formatter import avoids exporting
// its standalone executable entry point.
const formatter = @import("format_core");

comptime {
    _ = @import("CycleRuntime.zig").silex_llvm_cycle_collect;
    _ = @import("CycleRuntime.zig").silex_llvm_cycle_edge;
    _ = @import("CycleRuntime.zig").silex_llvm_cycle_reject;
    _ = formatter.silex_format_float;
    _ = formatter.silex_format_signed;
    _ = formatter.silex_format_unsigned;
}
