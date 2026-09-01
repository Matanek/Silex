const Callback = *const fn (i32) callconv(.c) i32;

export fn silex_boundary_answer() callconv(.c) i32 {
    return 42;
}

export fn silex_boundary_apply(value: i32, address: usize) callconv(.c) i32 {
    const callback: Callback = @ptrFromInt(address);
    return callback(value);
}
