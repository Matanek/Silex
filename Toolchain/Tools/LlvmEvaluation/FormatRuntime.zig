// Linkable view of the exact native formatter. Keeping FloatFormat.zig as an
// imported module avoids exporting its standalone executable entry point.
const formatter = @import("format_core");

comptime {
    _ = formatter.silex_format_float;
    _ = formatter.silex_format_signed;
    _ = formatter.silex_format_unsigned;
}
