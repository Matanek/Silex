const std = @import("std");
const builtin = @import("builtin");

/// Keep package, toolchain and registry identity storage under one user root.
/// A dedicated absolute root is useful for isolated package-registry tests.
pub fn get(allocator: std.mem.Allocator, environment: *const std.process.Environ.Map) !?[]const u8 {
    if (environment.get("SILEX_DATA_ROOT")) |root| {
        if (!std.fs.path.isAbsolute(root) or std.mem.eql(u8, root, std.fs.path.sep_str))
            return error.InvalidSilexDataRoot;
        return root;
    }
    const home = (if (builtin.os.tag == .windows) environment.get("USERPROFILE") else environment.get("HOME")) orelse
        environment.get("HOME") orelse environment.get("USERPROFILE") orelse return null;
    if (!std.fs.path.isAbsolute(home)) return error.UserHomeUnavailable;
    return try std.fs.path.join(allocator, &.{ home, ".silex" });
}
