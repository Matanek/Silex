const std = @import("std");

pub fn same(roots: []const []const u8, left_value: []const u8, right_value: []const u8) bool {
    const left = logical(left_value);
    const right = logical(right_value);
    return std.mem.eql(u8, scope(roots, left), scope(roots, right));
}

pub fn sameProviders(providers: anytype, left_value: []const u8, right_value: []const u8) bool {
    const left = logical(left_value);
    const right = logical(right_value);
    return std.mem.eql(u8, providerScope(providers, left), providerScope(providers, right));
}

fn scope(roots: []const []const u8, module: []const u8) []const u8 {
    var result: ?[]const u8 = null;
    for (roots) |root| {
        if (root.len >= module.len) continue;
        if (!std.mem.startsWith(u8, module, root)) continue;
        if (module[root.len] != '.') continue;
        if (result == null or root.len > result.?.len) result = root;
    }
    return result orelse module;
}

fn providerScope(providers: anytype, module: []const u8) []const u8 {
    var result: ?[]const u8 = null;
    for (providers) |provider| {
        const basename = std.fs.path.basename(provider.path);
        if (!std.mem.eql(u8, basename, "@module.sx") and !std.mem.eql(u8, basename, "@Module.sx")) continue;
        const root = logical(provider.name);
        if (root.len >= module.len or !std.mem.startsWith(u8, module, root) or module[root.len] != '.') continue;
        if (result == null or root.len > result.?.len) result = root;
    }
    return result orelse module;
}

fn logical(module: []const u8) []const u8 {
    if (std.mem.endsWith(u8, module, ".$Platform")) return module[0 .. module.len - ".$Platform".len];
    if (std.mem.endsWith(u8, module, ".$Target")) return module[0 .. module.len - ".$Target".len];
    return module;
}

test "share module scope through a declared parent module only" {
    const roots = &.{ "STD.Regex", "STD.Text" };
    try std.testing.expect(same(roots, "STD.Regex.Engine", "STD.Regex.Regex"));
    try std.testing.expect(same(roots, "STD.Regex", "STD.Regex.Unicode"));
    try std.testing.expect(same(roots, "STD.Text", "STD.Text.$Platform"));
    try std.testing.expect(!same(roots, "STD.Regex.Engine", "STD.Text.Data"));
    try std.testing.expect(!same(roots, "Layer.A", "Layer.B"));
}
