const std = @import("std");
const builtin = @import("builtin");

pub const Platform = enum {
    macos,
    linux,
    windows,

    pub fn directoryName(self: Platform) []const u8 {
        return switch (self) {
            .macos => "MacOS",
            .linux => "Linux",
            .windows => "Windows",
        };
    }
};

pub const Architecture = enum { arm64, x64 };

pub const Target = struct {
    platform: Platform,
    architecture: Architecture,

    pub const macos_arm64: Target = .{ .platform = .macos, .architecture = .arm64 };
    pub const linux_x64: Target = .{ .platform = .linux, .architecture = .x64 };
    pub const windows_x64: Target = .{ .platform = .windows, .architecture = .x64 };
    pub const windows_arm64: Target = .{ .platform = .windows, .architecture = .arm64 };
    pub const supported = [_]Target{ macos_arm64, linux_x64, windows_x64, windows_arm64 };

    pub fn parse(text: []const u8) error{UnknownTarget}!Target {
        if (std.mem.eql(u8, text, "macos-arm64")) return macos_arm64;
        if (std.mem.eql(u8, text, "linux-x64")) return linux_x64;
        if (std.mem.eql(u8, text, "windows-x64")) return windows_x64;
        if (std.mem.eql(u8, text, "windows-arm64")) return windows_arm64;
        return error.UnknownTarget;
    }

    pub fn name(self: Target) []const u8 {
        if (self.eql(macos_arm64)) return "macos-arm64";
        if (self.eql(linux_x64)) return "linux-x64";
        if (self.eql(windows_x64)) return "windows-x64";
        if (self.eql(windows_arm64)) return "windows-arm64";
        unreachable;
    }

    pub fn eql(self: Target, other: Target) bool {
        return self.platform == other.platform and self.architecture == other.architecture;
    }

    pub fn hasNativeEmitter(self: Target) bool {
        return self.eql(macos_arm64) or self.eql(linux_x64) or self.eql(windows_x64) or self.eql(windows_arm64);
    }

    pub fn host() ?Target {
        return switch (builtin.os.tag) {
            .macos => if (builtin.cpu.arch == .aarch64) macos_arm64 else null,
            .linux => if (builtin.cpu.arch == .x86_64) linux_x64 else null,
            .windows => switch (builtin.cpu.arch) {
                .x86_64 => windows_x64,
                .aarch64 => windows_arm64,
                else => null,
            },
            else => null,
        };
    }
};

test "parse the recognized portability matrix" {
    try std.testing.expect((try Target.parse("macos-arm64")).eql(.macos_arm64));
    try std.testing.expect((try Target.parse("linux-x64")).eql(.linux_x64));
    try std.testing.expect((try Target.parse("windows-x64")).eql(.windows_x64));
    try std.testing.expect((try Target.parse("windows-arm64")).eql(.windows_arm64));
    try std.testing.expectError(error.UnknownTarget, Target.parse("linux-arm64"));
    try std.testing.expect(Target.macos_arm64.hasNativeEmitter());
    try std.testing.expect(Target.linux_x64.hasNativeEmitter());
    try std.testing.expect(Target.windows_x64.hasNativeEmitter());
    try std.testing.expect(Target.windows_arm64.hasNativeEmitter());
    for (Target.supported) |target| try std.testing.expect((try Target.parse(target.name())).eql(target));
}
