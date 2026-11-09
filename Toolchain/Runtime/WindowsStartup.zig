// Windows loads and initializes UCRT before this entry. Use its process state
// directly; Silex does not require the complete MinGW compatibility library.
const Initializer = ?*const fn () callconv(.c) void;
const CheckedInitializer = ?*const fn () callconv(.c) c_int;

extern "ucrtbase" fn _set_app_type(c_int) callconv(.c) void;
extern "ucrtbase" fn _configure_narrow_argv(c_int) callconv(.c) c_int;
extern "ucrtbase" fn _configure_wide_argv(c_int) callconv(.c) c_int;
extern "ucrtbase" fn _initialize_narrow_environment() callconv(.c) c_int;
extern "ucrtbase" fn _initialize_wide_environment() callconv(.c) c_int;
extern "ucrtbase" fn _initterm_e([*]const CheckedInitializer, [*]const CheckedInitializer) callconv(.c) c_int;
extern "ucrtbase" fn _initterm([*]const Initializer, [*]const Initializer) callconv(.c) void;
extern "ucrtbase" fn _crt_atexit(*const fn () callconv(.c) void) callconv(.c) c_int;
extern "ucrtbase" fn exit(c_int) callconv(.c) noreturn;
const InvalidParameterHandler = *const fn (?[*:0]const u16, ?[*:0]const u16, ?[*:0]const u16, c_uint, usize) callconv(.c) void;
extern "ucrtbase" fn _set_invalid_parameter_handler(InvalidParameterHandler) callconv(.c) ?InvalidParameterHandler;
extern fn main() callconv(.c) c_int;

extern var __CTOR_LIST__: usize;
extern var __DTOR_LIST__: usize;
extern var __RUNTIME_PSEUDO_RELOC_LIST__: u8;
extern var __RUNTIME_PSEUDO_RELOC_LIST_END__: u8;
// The linker owns these tables. NativeLink reads only this private marker and
// their first entries before choosing the startup, never executing an image
// which needs GNU constructors or runtime pseudo-relocation with this entry.
export const silex_link_requirements: [4]*const anyopaque linksection(".sxlink") = .{
    &__CTOR_LIST__, &__DTOR_LIST__, &__RUNTIME_PSEUDO_RELOC_LIST__, &__RUNTIME_PSEUDO_RELOC_LIST_END__,
};

// LLD merges and sorts .CRT contributions from native archives between these
// sentinels, including C/C++ initializers and TLS callbacks.
export var __xi_a: CheckedInitializer linksection(".CRT$XIA") = null;
export var __xi_z: CheckedInitializer linksection(".CRT$XIZ") = null;
export var __xc_a: Initializer linksection(".CRT$XCA") = null;
export var __xc_z: Initializer linksection(".CRT$XCZ") = null;
export var __xp_a: Initializer linksection(".CRT$XPA") = null;
export var __xp_z: Initializer linksection(".CRT$XPZ") = null;
export var __xt_a: Initializer linksection(".CRT$XTA") = null;
export var __xt_z: Initializer linksection(".CRT$XTZ") = null;

export var _tls_start: usize align(16) linksection(".tls") = 0;
export var _tls_end: usize linksection(".tls$ZZZ") = 0;
export var _tls_index: u32 = 0;
export var __xl_a: usize linksection(".CRT$XLA") = 0;
export var __xl_z: usize linksection(".CRT$XLZ") = 0;
const TlsDirectory = extern struct {
    start: *const usize,
    end: *const usize,
    index: *u32,
    callbacks: [*]const usize,
    zero_fill: u32,
    characteristics: u32,
};
export const _tls_used: TlsDirectory linksection(".rdata$T") = .{
    .start = &_tls_start,
    .end = &_tls_end,
    .index = &_tls_index,
    .callbacks = @as([*]const usize, @ptrCast(&__xl_a)) + 1,
    .zero_fill = 0,
    .characteristics = 0,
};

fn terminate() callconv(.c) void {
    _initterm(@ptrCast(&__xp_a), @ptrCast(&__xp_z));
    _initterm(@ptrCast(&__xt_a), @ptrCast(&__xt_z));
}

export fn atexit(callback: *const fn () callconv(.c) void) callconv(.c) c_int {
    return _crt_atexit(callback);
}

fn invalidParameter(_: ?[*:0]const u16, _: ?[*:0]const u16, _: ?[*:0]const u16, _: c_uint, _: usize) callconv(.c) void {}

export fn silex_windows_start() callconv(.c) noreturn {
    _set_app_type(1); // console application, as in the existing GNU link
    _ = _set_invalid_parameter_handler(invalidParameter);
    if (_configure_narrow_argv(1) != 0 or _configure_wide_argv(1) != 0 or
        _initialize_narrow_environment() != 0 or _initialize_wide_environment() != 0)
        exit(255);
    if (_initterm_e(@ptrCast(&__xi_a), @ptrCast(&__xi_z)) != 0) exit(255);
    if (atexit(terminate) != 0) exit(255);
    _initterm(@ptrCast(&__xc_a), @ptrCast(&__xc_z));
    // exit runs registered native finalizers and flushes CRT streams. Returning
    // directly to the loader would silently omit those effects.
    exit(main());
}
