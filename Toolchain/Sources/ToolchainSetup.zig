const std = @import("std");
const Artifacts = @import("Artifacts.zig");
const TargetModule = @import("Target.zig");

const release = "https://github.com/Matanek/Silex-Toolchain-Assets/releases/download/shadercross-3.0.0-e55cf5e-silex.1/";
const zig_release = "https://ziglang.org/download/0.16.0/";

pub fn shadercross(host: TargetModule.Target) Artifacts.ToolSpec {
    if (host.eql(.macos_arm64) or host.eql(.macos_x64)) return .{
        .name = "Shadercross",
        .path = "downloads/Shadercross-3.0.0-e55cf5e-macos-universal.tar.gz",
        .url = release ++ "Shadercross-3.0.0-e55cf5e-macos-universal.tar.gz",
        .sha256 = "a92bfbbdf10c3065976fb41d1b561a82f5c6f78203f9805aabf00b12dd517c2b",
        .archive = .{
            .format = .tar_gz,
            .into = if (host.eql(.macos_arm64)) "shadercross/3.0.0/macos-arm64" else "shadercross/3.0.0/macos-x64",
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

pub fn linker(host: TargetModule.Target) Artifacts.ToolSpec {
    if (host.eql(.macos_arm64)) return .{
        .name = "Native linker",
        .path = "downloads/zig-aarch64-macos-0.16.0.tar.xz",
        .url = zig_release ++ "zig-aarch64-macos-0.16.0.tar.xz",
        .sha256 = "b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489",
        .archive = .{
            .format = .tar_xz,
            .into = "zig/0.16.0/macos-arm64",
            .provides = "zig",
            .strip_components = 1,
        },
    };
    if (host.eql(.macos_x64)) return .{
        .name = "Native linker",
        .path = "downloads/zig-x86_64-macos-0.16.0.tar.xz",
        .url = zig_release ++ "zig-x86_64-macos-0.16.0.tar.xz",
        .sha256 = "0387557ed1877bc6a2e1802c8391953baddba76081876301c522f52977b52ba7",
        .archive = .{
            .format = .tar_xz,
            .into = "zig/0.16.0/macos-x64",
            .provides = "zig",
            .strip_components = 1,
        },
    };
    if (host.eql(.linux_x64)) return .{
        .name = "Native linker",
        .path = "downloads/zig-x86_64-linux-0.16.0.tar.xz",
        .url = zig_release ++ "zig-x86_64-linux-0.16.0.tar.xz",
        .sha256 = "70e49664a74374b48b51e6f3fdfbf437f6395d42509050588bd49abe52ba3d00",
        .archive = .{
            .format = .tar_xz,
            .into = "zig/0.16.0/linux-x64",
            .provides = "zig",
            .strip_components = 1,
        },
    };
    if (host.eql(.windows_x64)) return .{
        .name = "Native linker",
        .path = "downloads/zig-x86_64-windows-0.16.0.zip",
        .url = zig_release ++ "zig-x86_64-windows-0.16.0.zip",
        .sha256 = "68659eb5f1e4eb1437a722f1dd889c5a322c9954607f5edcf337bc3684a75a7e",
        .archive = .{
            .format = .zip,
            .into = "zig/0.16.0/windows-x64",
            .provides = "zig-x86_64-windows-0.16.0/zig.exe",
            .strip_components = 0,
        },
    };
    if (host.eql(.windows_arm64)) return linker(.windows_x64);
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

pub fn linkerExecutablePath(
    allocator: std.mem.Allocator,
    toolchain_root: []const u8,
    host: TargetModule.Target,
) ![]const u8 {
    const spec = linker(host);
    return std.fs.path.join(allocator, &.{ toolchain_root, spec.archive.into, spec.archive.provides });
}

test "Shadercross belongs to the host toolchain" {
    const macos = shadercross(.macos_arm64);
    try std.testing.expectEqualStrings("shadercross/3.0.0/macos-arm64", macos.archive.into);
    try std.testing.expectEqualStrings("bin/shadercross", macos.archive.provides);
    const macos_x64 = shadercross(.macos_x64);
    try std.testing.expectEqualStrings("shadercross/3.0.0/macos-x64", macos_x64.archive.into);
    try std.testing.expectEqualStrings(macos.url, macos_x64.url);

    const windows_arm64 = shadercross(.windows_arm64);
    try std.testing.expectEqualStrings("shadercross/3.0.0/windows-arm64", windows_arm64.archive.into);
    try std.testing.expect(std.mem.endsWith(u8, windows_arm64.url, "windows-x64.zip"));

    const linux_linker = linker(.linux_x64);
    try std.testing.expectEqual(.tar_xz, linux_linker.archive.format);
    try std.testing.expectEqualStrings("zig", linux_linker.archive.provides);
    const macos_x64_linker = linker(.macos_x64);
    try std.testing.expect(std.mem.endsWith(u8, macos_x64_linker.url, "zig-x86_64-macos-0.16.0.tar.xz"));

    const windows_linker = linker(.windows_x64);
    try std.testing.expectEqual(.zip, windows_linker.archive.format);
    try std.testing.expect(std.mem.endsWith(u8, windows_linker.archive.provides, "zig.exe"));

    const windows_arm64_linker = linker(.windows_arm64);
    try std.testing.expectEqualStrings("zig/0.16.0/windows-x64", windows_arm64_linker.archive.into);
    try std.testing.expect(std.mem.endsWith(u8, windows_arm64_linker.url, "zig-x86_64-windows-0.16.0.zip"));
}
