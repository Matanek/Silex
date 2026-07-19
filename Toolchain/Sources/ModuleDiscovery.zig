const std = @import("std");

pub fn isDirectoryName(name: []const u8) bool {
    return name.len > 0 and name[0] != '.' and name[0] != '@';
}

pub fn isModuleName(name: []const u8) bool {
    var starts_segment = true;
    for (name) |character| {
        if (starts_segment and character == '@') return false;
        starts_segment = character == '.';
    }
    return true;
}

test "at-prefixed directories are infrastructure while underscore stays discoverable" {
    try std.testing.expect(!isDirectoryName("@Native"));
    try std.testing.expect(isDirectoryName("_Private"));
    try std.testing.expect(!isModuleName("Library.@Native.Console"));
    try std.testing.expect(isModuleName("Library._Private.Console"));
}
