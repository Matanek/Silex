//! Current-user DPAPI envelope; never use CRYPTPROTECT_LOCAL_MACHINE.
const std = @import("std");
const windows = std.os.windows;
const Blob = extern struct { len: u32, data: [*]u8 };
const ui_forbidden = 1;
const context = "Silex registry credential v1";

extern "crypt32" fn CryptProtectData(*Blob, ?[*:0]const u16, ?*Blob, ?*anyopaque, ?*anyopaque, u32, *Blob) callconv(.winapi) windows.BOOL;
extern "crypt32" fn CryptUnprotectData(*Blob, ?*?[*:0]u16, ?*Blob, ?*anyopaque, ?*anyopaque, u32, *Blob) callconv(.winapi) windows.BOOL;
extern "kernel32" fn LocalFree(?*anyopaque) callconv(.winapi) ?*anyopaque;
extern "shell32" fn ShellExecuteW(?*anyopaque, ?[*:0]const u16, [*:0]const u16, ?[*:0]const u16, ?[*:0]const u16, i32) callconv(.winapi) isize;

pub fn protect(allocator: std.mem.Allocator, plain: []const u8) ![]u8 {
    if (plain.len > 4096) return error.InvalidRegistryCredential;
    var input: Blob = .{ .len = @intCast(plain.len), .data = @constCast(plain.ptr) };
    var entropy: Blob = .{ .len = context.len, .data = @constCast(context.ptr) };
    var output: Blob = undefined;
    if (CryptProtectData(&input, null, &entropy, null, null, ui_forbidden, &output) == .FALSE)
        return error.RegistryCredentialProtectionFailed;
    defer _ = LocalFree(output.data);
    if (output.len > 16384) return error.InvalidRegistryCredential;
    return allocator.dupe(u8, output.data[0..output.len]);
}

pub fn unprotect(allocator: std.mem.Allocator, encrypted: []const u8) ![]u8 {
    if (encrypted.len == 0 or encrypted.len > 16384) return error.InvalidRegistryCredential;
    var input: Blob = .{ .len = @intCast(encrypted.len), .data = @constCast(encrypted.ptr) };
    var entropy: Blob = .{ .len = context.len, .data = @constCast(context.ptr) };
    var output: Blob = undefined;
    if (CryptUnprotectData(&input, null, &entropy, null, null, ui_forbidden, &output) == .FALSE)
        return error.RegistryCredentialProtectionFailed;
    defer {
        std.crypto.secureZero(u8, output.data[0..output.len]);
        _ = LocalFree(output.data);
    }
    if (output.len > 4096) return error.InvalidRegistryCredential;
    return allocator.dupe(u8, output.data[0..output.len]);
}

pub fn openBrowser() bool {
    // Fixed URL, no command line, no registry-supplied navigation target.
    return ShellExecuteW(null, std.unicode.utf8ToUtf16LeStringLiteral("open"), std.unicode.utf8ToUtf16LeStringLiteral("https://github.com/login/device"), null, null, 1) > 32;
}

test "DPAPI round trip and integrity use the current Windows user" {
    if (@import("builtin").os.tag != .windows) return error.SkipZigTest;
    const allocator = std.testing.allocator;
    const plain = "offline-registry-credential-fixture";
    const protected = try protect(allocator, plain);
    defer allocator.free(protected);
    try std.testing.expect(std.mem.indexOf(u8, protected, plain) == null);
    const restored = try unprotect(allocator, protected);
    defer allocator.free(restored);
    try std.testing.expectEqualStrings(plain, restored);
    protected[protected.len - 1] ^= 1;
    try std.testing.expectError(error.RegistryCredentialProtectionFailed, unprotect(allocator, protected));
    try std.testing.expectError(error.RegistryCredentialProtectionFailed, unprotect(allocator, plain));
}
