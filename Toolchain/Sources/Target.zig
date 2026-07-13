const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;

pub const Target = struct {
    cpu_arch: std.Target.Cpu.Arch,
    os_tag: std.Target.Os.Tag,
    abi: std.Target.Abi,
    is_native: bool,
    zig_triple: ?[]const u8,

    pub fn native() Target {
        return .{
            .cpu_arch = builtin.target.cpu.arch,
            .os_tag = builtin.target.os.tag,
            .abi = builtin.target.abi,
            .is_native = true,
            .zig_triple = null,
        };
    }

    pub fn parse(allocator: Allocator, io: std.Io, text: []const u8) !Target {
        if (std.mem.eql(u8, text, "native")) return native();

        const query = try std.Target.Query.parse(.{ .arch_os_abi = text });
        const resolved = try std.zig.system.resolveTargetQuery(io, query);
        return .{
            .cpu_arch = resolved.cpu.arch,
            .os_tag = resolved.os.tag,
            .abi = resolved.abi,
            .is_native = false,
            .zig_triple = try query.zigTriple(allocator),
        };
    }

    pub fn cacheName(self: Target, allocator: Allocator) ![]const u8 {
        if (self.zig_triple) |triple| return allocator.dupe(u8, triple);
        return std.fmt.allocPrint(allocator, "{s}-{s}-{s}", .{
            @tagName(self.cpu_arch),
            @tagName(self.os_tag),
            @tagName(self.abi),
        });
    }

    pub fn canRunOnHost(self: Target) bool {
        return self.cpu_arch == builtin.target.cpu.arch and
            self.os_tag == builtin.target.os.tag and
            self.abi == builtin.target.abi;
    }

    pub fn cppBackendUnavailableReason(self: Target) ?[]const u8 {
        return switch (self.os_tag) {
            .freestanding, .uefi => "Silex programs require a hosted operating system with a C++ standard library",
            else => null,
        };
    }
};

test "native target has a stable cache name" {
    const target = Target.native();
    const name = try target.cacheName(std.testing.allocator);
    defer std.testing.allocator.free(name);

    try std.testing.expect(std.mem.startsWith(u8, name, @tagName(builtin.target.cpu.arch)));
    try std.testing.expect(std.mem.indexOf(u8, name, @tagName(builtin.target.os.tag)) != null);
}

test "explicit target is normalized" {
    const target = try Target.parse(std.testing.allocator, std.testing.io, "x86_64-linux-musl");
    defer std.testing.allocator.free(target.zig_triple.?);

    try std.testing.expectEqual(std.Target.Cpu.Arch.x86_64, target.cpu_arch);
    try std.testing.expectEqual(std.Target.Os.Tag.linux, target.os_tag);
    try std.testing.expectEqual(std.Target.Abi.musl, target.abi);
    try std.testing.expectEqualStrings("x86_64-linux-musl", target.zig_triple.?);
}

test "freestanding target is unavailable to the C++ backend" {
    const target = try Target.parse(std.testing.allocator, std.testing.io, "x86_64-freestanding-none");
    defer std.testing.allocator.free(target.zig_triple.?);

    try std.testing.expectEqualStrings(
        "Silex programs require a hosted operating system with a C++ standard library",
        target.cppBackendUnavailableReason().?,
    );
}
