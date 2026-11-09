const Callback = *const fn (i32) callconv(.c) i32;
extern "ucrtbase" fn __p___argc() callconv(.c) *c_int;
extern "ucrtbase" fn __p___wargv() callconv(.c) *?[*:null]?[*:0]u16;
extern "ucrtbase" fn getenv([*:0]const u8) callconv(.c) ?[*:0]const u8;
extern "ucrtbase" fn _write(c_int, [*]const u8, c_uint) callconv(.c) c_int;
extern fn atexit(*const fn () callconv(.c) void) callconv(.c) c_int;
extern "kernel32" fn CreateThread(?*anyopaque, usize, *const fn (?*anyopaque) callconv(.c) u32, ?*anyopaque, u32, ?*u32) callconv(.c) ?*anyopaque;
extern "kernel32" fn WaitForSingleObject(*anyopaque, u32) callconv(.c) u32;
extern "kernel32" fn GetExitCodeThread(*anyopaque, *u32) callconv(.c) c_int;
extern "kernel32" fn CloseHandle(*anyopaque) callconv(.c) c_int;

var initialized: i32 = 0;
threadlocal var thread_value: i32 = 21;

fn initialize() callconv(.c) void {
    initialized = 21;
    _ = atexit(finalize);
}

fn finalize() callconv(.c) void {
    if (getenv("SILEX_WINDOWS_STARTUP_PROBE") != null) {
        const message = "windows arm64 finalized\n";
        _ = _write(1, message, message.len);
    }
}

export const startup_initializer: *const fn () callconv(.c) void linksection(".CRT$XCU") = initialize;

fn threadProbe(_: ?*anyopaque) callconv(.c) u32 {
    const value: *volatile i32 = &thread_value;
    if (value.* != 21) return 1;
    value.* = 73;
    return 0;
}

export fn silex_boundary_answer() callconv(.c) i32 {
    if (__p___argc().* < 1 or __p___wargv().* == null) return -1;
    if (getenv("SILEX_WINDOWS_STARTUP_PROBE") != null) {
        if (__p___argc().* != 3) return -2;
        const argument = __p___wargv().*.?[2] orelse return -3;
        const expected = [_]u16{ 'm', 'o', 't', 'e', 'u', 'r', '-', 'é', 't', 'é', 0 };
        for (expected, 0..) |character, index| if (argument[index] != character) return -4;
    }
    const value: *volatile i32 = &thread_value;
    if (value.* != 21) return -5;
    value.* = 99;
    const thread = CreateThread(null, 0, threadProbe, null, 0, null) orelse return -6;
    defer _ = CloseHandle(thread);
    if (WaitForSingleObject(thread, 10_000) != 0) return -7;
    var code: u32 = 1;
    if (GetExitCodeThread(thread, &code) == 0 or code != 0 or value.* != 99) return -8;
    value.* = 21;
    return initialized + value.*;
}

export fn silex_boundary_apply(value: i32, address: usize) callconv(.c) i32 {
    const callback: Callback = @ptrFromInt(address);
    return callback(value);
}
