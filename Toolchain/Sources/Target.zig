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

pub const NativeCapabilities = struct {
    machine_backend: bool = false,
    system_abi: bool = false,
    object_emitter: bool = false,
    executable_emitter: bool = false,
    runtime: bool = false,
    boundary_linker: bool = false,

    pub fn hasExecutableEmitter(self: NativeCapabilities) bool {
        return self.machine_backend and self.system_abi and self.executable_emitter and self.runtime;
    }

    pub fn hasBoundaryEmitter(self: NativeCapabilities) bool {
        return self.hasExecutableEmitter() and self.object_emitter and self.boundary_linker;
    }
};

pub const Target = struct {
    platform: Platform,
    architecture: Architecture,

    pub const macos_arm64: Target = .{ .platform = .macos, .architecture = .arm64 };
    pub const macos_x64: Target = .{ .platform = .macos, .architecture = .x64 };
    pub const linux_arm64: Target = .{ .platform = .linux, .architecture = .arm64 };
    pub const linux_x64: Target = .{ .platform = .linux, .architecture = .x64 };
    pub const windows_arm64: Target = .{ .platform = .windows, .architecture = .arm64 };
    pub const windows_x64: Target = .{ .platform = .windows, .architecture = .x64 };
    pub const recognized = [_]Target{
        macos_arm64,
        macos_x64,
        linux_arm64,
        linux_x64,
        windows_arm64,
        windows_x64,
    };

    pub fn parse(text: []const u8) error{UnknownTarget}!Target {
        if (std.mem.eql(u8, text, "macos-arm64")) return macos_arm64;
        if (std.mem.eql(u8, text, "macos-x64")) return macos_x64;
        if (std.mem.eql(u8, text, "linux-arm64")) return linux_arm64;
        if (std.mem.eql(u8, text, "linux-x64")) return linux_x64;
        if (std.mem.eql(u8, text, "windows-arm64")) return windows_arm64;
        if (std.mem.eql(u8, text, "windows-x64")) return windows_x64;
        return error.UnknownTarget;
    }

    pub fn name(self: Target) []const u8 {
        if (self.eql(macos_arm64)) return "macos-arm64";
        if (self.eql(macos_x64)) return "macos-x64";
        if (self.eql(linux_arm64)) return "linux-arm64";
        if (self.eql(linux_x64)) return "linux-x64";
        if (self.eql(windows_arm64)) return "windows-arm64";
        if (self.eql(windows_x64)) return "windows-x64";
        unreachable;
    }

    pub fn eql(self: Target, other: Target) bool {
        return self.platform == other.platform and self.architecture == other.architecture;
    }

    pub fn executableKind(self: Target) []const u8 {
        return switch (self.platform) {
            .macos => "macho",
            .linux => "elf",
            .windows => "pe",
        };
    }

    pub fn executableExtension(self: Target) []const u8 {
        return if (self.platform == .windows) ".exe" else "";
    }

    pub fn nativeCapabilities(self: Target) NativeCapabilities {
        for (recognized) |target| {
            if (self.eql(target)) return .{
                .machine_backend = true,
                .system_abi = true,
                .object_emitter = true,
                .executable_emitter = true,
                .runtime = true,
                .boundary_linker = true,
            };
        }
        return .{};
    }

    pub fn hasNativeEmitter(self: Target) bool {
        return self.nativeCapabilities().hasExecutableEmitter();
    }

    pub fn host() ?Target {
        return switch (builtin.os.tag) {
            .macos => switch (builtin.cpu.arch) {
                .aarch64 => macos_arm64,
                .x86_64 => macos_x64,
                else => null,
            },
            .linux => switch (builtin.cpu.arch) {
                .aarch64 => linux_arm64,
                .x86_64 => linux_x64,
                else => null,
            },
            .windows => switch (builtin.cpu.arch) {
                .aarch64 => windows_arm64,
                .x86_64 => windows_x64,
                else => null,
            },
            else => null,
        };
    }
};

test "parse the recognized portability matrix" {
    try std.testing.expect((try Target.parse("macos-arm64")).eql(.macos_arm64));
    try std.testing.expect((try Target.parse("macos-x64")).eql(.macos_x64));
    try std.testing.expect((try Target.parse("linux-arm64")).eql(.linux_arm64));
    try std.testing.expect((try Target.parse("linux-x64")).eql(.linux_x64));
    try std.testing.expect((try Target.parse("windows-arm64")).eql(.windows_arm64));
    try std.testing.expect((try Target.parse("windows-x64")).eql(.windows_x64));
    try std.testing.expectError(error.UnknownTarget, Target.parse("linux-x86"));
    try std.testing.expect(Target.macos_arm64.hasNativeEmitter());
    try std.testing.expect(Target.macos_x64.hasNativeEmitter());
    try std.testing.expect(Target.linux_arm64.hasNativeEmitter());
    try std.testing.expect(Target.linux_x64.hasNativeEmitter());
    try std.testing.expect(Target.windows_arm64.hasNativeEmitter());
    try std.testing.expect(Target.windows_x64.hasNativeEmitter());
    for (Target.recognized) |target| try std.testing.expect((try Target.parse(target.name())).eql(target));
}

test "separate shared machine backends from complete native targets" {
    const macos_x64 = Target.macos_x64.nativeCapabilities();
    try std.testing.expect(macos_x64.machine_backend);
    try std.testing.expect(macos_x64.system_abi);
    try std.testing.expect(macos_x64.object_emitter);
    try std.testing.expect(macos_x64.executable_emitter);
    try std.testing.expect(macos_x64.runtime);
    try std.testing.expect(macos_x64.boundary_linker);
    try std.testing.expect(macos_x64.hasExecutableEmitter());
    try std.testing.expect(macos_x64.hasBoundaryEmitter());

    const linux_arm64 = Target.linux_arm64.nativeCapabilities();
    try std.testing.expect(linux_arm64.machine_backend);
    try std.testing.expect(linux_arm64.system_abi);
    try std.testing.expect(linux_arm64.object_emitter);
    try std.testing.expect(linux_arm64.executable_emitter);
    try std.testing.expect(linux_arm64.runtime);
    try std.testing.expect(linux_arm64.boundary_linker);
    try std.testing.expect(linux_arm64.hasExecutableEmitter());
    try std.testing.expect(linux_arm64.hasBoundaryEmitter());

    for (Target.recognized) |target| {
        const capabilities = target.nativeCapabilities();
        try std.testing.expect(capabilities.hasExecutableEmitter());
        try std.testing.expect(capabilities.hasBoundaryEmitter());
    }
}

test "derive executable containers and extensions from the target platform" {
    for ([_]Target{ .macos_arm64, .macos_x64 }) |target| {
        try std.testing.expectEqualStrings("macho", target.executableKind());
        try std.testing.expectEqualStrings("", target.executableExtension());
    }
    for ([_]Target{ .linux_arm64, .linux_x64 }) |target| {
        try std.testing.expectEqualStrings("elf", target.executableKind());
        try std.testing.expectEqualStrings("", target.executableExtension());
    }
    for ([_]Target{ .windows_arm64, .windows_x64 }) |target| {
        try std.testing.expectEqualStrings("pe", target.executableKind());
        try std.testing.expectEqualStrings(".exe", target.executableExtension());
    }
}
