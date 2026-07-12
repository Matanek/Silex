pub const Position = struct {
    line: usize,
    column: usize,
};

pub const Diagnostic = struct {
    position: Position,
    message: []const u8,
};

pub const Error = error{InvalidSource};
