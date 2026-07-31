const std = @import("std");
const Artifacts = @import("Artifacts.zig");
const TargetModule = @import("Target.zig");

const release = "https://github.com/Matanek/Silex-Toolchain-Assets/releases/download/shadercross-3.0.0-e55cf5e-silex.1/";

pub fn shadercross(host: TargetModule.Target) Artifacts.ToolSpec {
    if (host.eql(.macos_arm64)) return .{
        .name = "Shadercross",
        .path = "downloads/Shadercross-3.0.0-e55cf5e-macos-universal.tar.gz",
        .url = release ++ "Shadercross-3.0.0-e55cf5e-macos-universal.tar.gz",
        .sha256 = "a92bfbbdf10c3065976fb41d1b561a82f5c6f78203f9805aabf00b12dd517c2b",
        .archive = .{
            .format = .tar_gz,
            .into = "shadercross/3.0.0/macos-arm64",
            .provides = "bin/shadercross",
            .strip_components = 1,
        },
    };
    if (host.eql(.linux_x64)) return .{
        .name = "Shadercross",
        .path = "downloads/Shadercross-3.0.0-e55cf5e-linux-x64.tar.gz",
        .url = release ++ "Shadercross-3.0.0-e55cf5e-linux-x64.tar.gz",
        .sha256 = "252de380a0a4c6b5479419be3e4f00e419805fc99a41bae840096f0708ce3e15",
        .archive = .{
            .format = .tar_gz,
            .into = "shadercross/3.0.0/linux-x64",
            .provides = "bin/shadercross",
            .strip_components = 1,
        },
    };
    if (host.eql(.windows_x64) or host.eql(.windows_arm64)) {
        return .{
            .name = "Shadercross",
            .path = "downloads/Shadercross-3.0.0-e55cf5e-windows-x64.zip",
            .url = release ++ "Shadercross-3.0.0-e55cf5e-windows-x64.zip",
            .sha256 = "c11ce40504040237ee786d2a2406446881d6daaf3b34e1a08d90f7fa459d5f0d",
            .archive = .{
                .format = .zip,
                .into = if (host.eql(.windows_arm64))
                    "shadercross/3.0.0/windows-arm64"
                else
                    "shadercross/3.0.0/windows-x64",
                .provides = "SDL3_shadercross-3.0.0-windows-VC-x64/bin/shadercross.exe",
                .strip_components = 0,
            },
        };
    }
    unreachable;
}

pub fn executablePath(
    allocator: std.mem.Allocator,
    toolchain_root: []const u8,
    host: TargetModule.Target,
) ![]const u8 {
    const spec = shadercross(host);
    return std.fs.path.join(allocator, &.{ toolchain_root, spec.archive.into, spec.archive.provides });
}

test "Shadercross belongs to the host toolchain" {
    const macos = shadercross(.macos_arm64);
    try std.testing.expectEqualStrings("shadercross/3.0.0/macos-arm64", macos.archive.into);
    try std.testing.expectEqualStrings("bin/shadercross", macos.archive.provides);

    const windows_arm64 = shadercross(.windows_arm64);
    try std.testing.expectEqualStrings("shadercross/3.0.0/windows-arm64", windows_arm64.archive.into);
    try std.testing.expect(std.mem.endsWith(u8, windows_arm64.url, "windows-x64.zip"));
}
