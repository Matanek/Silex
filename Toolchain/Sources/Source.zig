pub const Position = struct {
    offset: usize,
    line: usize,
    column: usize,
};

pub const Diagnostic = struct {
    position: Position,
    message: []const u8,
};

pub const Error = error{InvalidSource};
