pub const Position = struct {
    offset: usize,
    line: usize,
    column: usize,
    file: usize = 0,
};

pub const Diagnostic = struct {
    position: Position,
    message: []const u8,
    path: ?[]const u8 = null,
};

pub const Error = error{InvalidSource};
