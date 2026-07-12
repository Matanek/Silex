const std = @import("std");
const builtin = @import("builtin");

const Allocator = std.mem.Allocator;
const Io = std.Io;

const Diagnostic = struct {
    line: usize,
    column: usize,
    message: []const u8,
};

const TokenTag = enum {
    keyword_void,
    identifier,
    string,
    left_parenthesis,
    right_parenthesis,
    left_brace,
    right_brace,
    semicolon,
    end,
};

const Token = struct {
    tag: TokenTag,
    lexeme: []const u8,
    line: usize,
    column: usize,
};

const Lexer = struct {
    source: []const u8,
    index: usize = 0,
    line: usize = 1,
    column: usize = 1,
    diagnostic: ?Diagnostic = null,

    fn next(self: *Lexer) error{InvalidSource}!Token {
        self.skipWhitespace();

        if (self.index == self.source.len) {
            return self.token(.end, self.index, self.line, self.column);
        }

        const start = self.index;
        const line = self.line;
        const column = self.column;
        const character = self.source[self.index];

        if (isIdentifierStart(character)) {
            self.advance();
            while (self.index < self.source.len and isIdentifierContinue(self.source[self.index])) {
                self.advance();
            }

            const lexeme = self.source[start..self.index];
            const tag: TokenTag = if (std.mem.eql(u8, lexeme, "void"))
                .keyword_void
            else
                .identifier;
            return .{ .tag = tag, .lexeme = lexeme, .line = line, .column = column };
        }

        if (character == '"') {
            self.advance();
            const contents_start = self.index;
            while (self.index < self.source.len) {
                switch (self.source[self.index]) {
                    '"' => {
                        const lexeme = self.source[contents_start..self.index];
                        self.advance();
                        return .{ .tag = .string, .lexeme = lexeme, .line = line, .column = column };
                    },
                    '\n', '\r' => return self.fail(line, column, "unterminated string literal"),
                    '\\' => {
                        self.advance();
                        if (self.index == self.source.len) {
                            return self.fail(line, column, "unterminated string literal");
                        }
                        self.advance();
                    },
                    else => self.advance(),
                }
            }
            return self.fail(line, column, "unterminated string literal");
        }

        self.advance();
        return switch (character) {
            '(' => self.token(.left_parenthesis, start, line, column),
            ')' => self.token(.right_parenthesis, start, line, column),
            '{' => self.token(.left_brace, start, line, column),
            '}' => self.token(.right_brace, start, line, column),
            ';' => self.token(.semicolon, start, line, column),
            else => self.fail(line, column, "invalid character"),
        };
    }

    fn skipWhitespace(self: *Lexer) void {
        while (self.index < self.source.len) {
            switch (self.source[self.index]) {
                ' ', '\t', '\r' => self.advance(),
                '\n' => {
                    self.index += 1;
                    self.line += 1;
                    self.column = 1;
                },
                else => return,
            }
        }
    }

    fn advance(self: *Lexer) void {
        self.index += 1;
        self.column += 1;
    }

    fn token(self: *const Lexer, tag: TokenTag, start: usize, line: usize, column: usize) Token {
        return .{
            .tag = tag,
            .lexeme = self.source[start..self.index],
            .line = line,
            .column = column,
        };
    }

    fn fail(self: *Lexer, line: usize, column: usize, message: []const u8) error{InvalidSource} {
        self.diagnostic = .{ .line = line, .column = column, .message = message };
        return error.InvalidSource;
    }
};

const Program = struct {
    print_arguments: std.ArrayList([]const u8) = .empty,

    fn deinit(self: *Program, allocator: Allocator) void {
        self.print_arguments.deinit(allocator);
    }
};

const Parser = struct {
    allocator: Allocator,
    lexer: Lexer,
    current: Token = undefined,
    diagnostic: ?Diagnostic = null,

    fn init(allocator: Allocator, source: []const u8) Parser {
        return .{
            .allocator = allocator,
            .lexer = .{ .source = source },
        };
    }

    fn parse(self: *Parser) !Program {
        try self.advance();

        var program: Program = .{};
        errdefer program.deinit(self.allocator);

        try self.expect(.keyword_void, "expected 'void'");
        try self.expectIdentifier("main", "expected 'main'");
        try self.expect(.left_parenthesis, "expected '('");
        try self.expect(.right_parenthesis, "expected ')'");
        try self.expect(.left_brace, "expected '{'");

        while (self.current.tag != .right_brace and self.current.tag != .end) {
            try self.parsePrint(&program);
        }

        try self.expect(.right_brace, "expected '}'");
        try self.expect(.end, "expected end of file");
        return program;
    }

    fn parsePrint(self: *Parser, program: *Program) !void {
        try self.expectIdentifier("print", "expected 'print'");
        try self.expect(.left_parenthesis, "expected '('");

        if (self.current.tag != .string) {
            return self.fail("expected string literal");
        }
        try program.print_arguments.append(self.allocator, self.current.lexeme);
        try self.advance();

        try self.expect(.right_parenthesis, "expected ')'");
        try self.expect(.semicolon, "expected ';'");
    }

    fn expect(self: *Parser, tag: TokenTag, message: []const u8) !void {
        if (self.current.tag != tag) return self.fail(message);
        try self.advance();
    }

    fn expectIdentifier(self: *Parser, expected: []const u8, message: []const u8) !void {
        if (self.current.tag != .identifier or !std.mem.eql(u8, self.current.lexeme, expected)) {
            return self.fail(message);
        }
        try self.advance();
    }

    fn advance(self: *Parser) !void {
        self.current = self.lexer.next() catch |err| {
            self.diagnostic = self.lexer.diagnostic;
            return err;
        };
    }

    fn fail(self: *Parser, message: []const u8) error{InvalidSource} {
        self.diagnostic = .{
            .line = self.current.line,
            .column = self.current.column,
            .message = message,
        };
        return error.InvalidSource;
    }
};

const Compilation = struct {
    executable_path: []const u8,
    cpp_path: []const u8,
    project_path: []const u8,
    program_name: []const u8,
    cache_hit: bool,
};

pub fn main(init: std.process.Init) u8 {
    return runCli(init) catch |err| {
        if (err != error.Reported) {
            std.debug.print("silex: error: {t}\n", .{err});
        }
        return 1;
    };
}

fn runCli(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);

    if (args.len == 1 or (args.len == 2 and isHelp(args[1]))) {
        try Io.File.stdout().writeStreamingAll(init.io, usage);
        return 0;
    }

    if (args.len == 2 and std.mem.eql(u8, args[1], "--version")) {
        try Io.File.stdout().writeStreamingAll(init.io, "Silex 0.1.0\n");
        return 0;
    }

    if (std.mem.eql(u8, args[1], "compile")) {
        return compileCommand(allocator, init.io, args[2..]);
    }

    if (std.mem.eql(u8, args[1], "run")) {
        return runCommand(allocator, init.io, args[2..]);
    }

    std.debug.print("silex: unknown command '{s}'\n\n{s}", .{ args[1], usage });
    return 1;
}

fn compileCommand(allocator: Allocator, io: Io, args: []const []const u8) !u8 {
    if (args.len == 0) {
        std.debug.print("silex: missing source file\n\n{s}", .{usage});
        return 1;
    }

    const source_path = args[0];
    var output_path: ?[]const u8 = null;
    var emit_cpp = false;
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--emit-cpp")) {
            emit_cpp = true;
        } else if (std.mem.eql(u8, args[index], "-o")) {
            index += 1;
            if (index == args.len) {
                std.debug.print("silex: expected an executable path after '-o'\n", .{});
                return 1;
            }
            output_path = args[index];
        } else {
            std.debug.print("silex: unknown option '{s}'\n", .{args[index]});
            return 1;
        }
    }

    const compilation = try compileSource(allocator, io, source_path);
    const output = output_path orelse try defaultOutputPath(allocator, compilation.project_path, compilation.program_name);
    try copyArtifact(io, compilation.executable_path, output);

    if (emit_cpp) {
        const generated_dir = try std.fs.path.join(allocator, &.{ compilation.project_path, ".silex", "generated" });
        try Io.Dir.cwd().createDirPath(io, generated_dir);
        const generated_name = try std.fmt.allocPrint(allocator, "{s}.cpp", .{compilation.program_name});
        const generated_path = try std.fs.path.join(allocator, &.{ generated_dir, generated_name });
        try copyArtifact(io, compilation.cpp_path, generated_path);
        std.debug.print("Generated C++: {s}\n", .{generated_path});
    }

    const status = if (compilation.cache_hit) "Up to date" else "Compiled";
    std.debug.print("{s} {s} -> {s}\n", .{ status, source_path, output });
    return 0;
}

fn runCommand(allocator: Allocator, io: Io, args: []const []const u8) !u8 {
    if (args.len != 1) {
        std.debug.print("silex: run expects exactly one source file\n\n{s}", .{usage});
        return 1;
    }

    const compilation = try compileSource(allocator, io, args[0]);
    const term = try runProcess(io, &.{compilation.executable_path});
    return exitCode(term);
}

fn compileSource(
    allocator: Allocator,
    io: Io,
    source_path: []const u8,
) !Compilation {
    if (!std.mem.endsWith(u8, source_path, ".sx")) {
        std.debug.print("silex: source file must use the .sx extension\n", .{});
        return error.Reported;
    }

    const source = Io.Dir.cwd().readFileAlloc(io, source_path, allocator, .limited(16 * 1024 * 1024)) catch |err| {
        std.debug.print("silex: unable to read '{s}': {t}\n", .{ source_path, err });
        return error.Reported;
    };

    var parser = Parser.init(allocator, source);
    var program = parser.parse() catch |err| switch (err) {
        error.InvalidSource => {
            const diagnostic = parser.diagnostic.?;
            std.debug.print("{s}:{d}:{d}: error: {s}\n", .{
                source_path,
                diagnostic.line,
                diagnostic.column,
                diagnostic.message,
            });
            return error.Reported;
        },
        else => |other| return other,
    };
    defer program.deinit(allocator);

    const cpp = try generateCpp(allocator, &program);
    const project_path = "";
    const source_name = std.fs.path.basename(source_path);
    const program_name = source_name[0 .. source_name.len - 3];
    const cache_key = cacheKey(cpp);
    const cache_dir = try std.fs.path.join(allocator, &.{ project_path, ".silex", "cache", &cache_key });
    try Io.Dir.cwd().createDirPath(io, cache_dir);

    const cpp_path = try std.fs.path.join(allocator, &.{ cache_dir, "Generated.cpp" });
    const executable_path = try std.fs.path.join(allocator, &.{ cache_dir, program_name });
    const cache_hit = try fileExists(io, executable_path);

    if (!cache_hit) {
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = cpp_path, .data = cpp });
        const term = try runProcess(io, &.{ "c++", "-std=c++23", cpp_path, "-o", executable_path });
        if (exitCode(term) != 0) return error.NativeCompilationFailed;
    }

    return .{
        .executable_path = executable_path,
        .cpp_path = cpp_path,
        .project_path = project_path,
        .program_name = program_name,
        .cache_hit = cache_hit,
    };
}

fn generateCpp(allocator: Allocator, program: *const Program) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    try output.appendSlice(allocator,
        \\#include <iostream>
        \\
        \\int main() {
        \\
    );

    for (program.print_arguments.items) |argument| {
        try output.appendSlice(allocator, "    std::cout << \"");
        try output.appendSlice(allocator, argument);
        try output.appendSlice(allocator, "\" << '\\n';\n");
    }

    try output.appendSlice(allocator,
        \\    return 0;
        \\}
        \\
    );
    return output.toOwnedSlice(allocator);
}

fn runProcess(io: Io, arguments: []const []const u8) !std.process.Child.Term {
    var child = try std.process.spawn(io, .{
        .argv = arguments,
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    });
    defer child.kill(io);
    return child.wait(io);
}

fn exitCode(term: std.process.Child.Term) u8 {
    return switch (term) {
        .exited => |code| code,
        else => 1,
    };
}

fn defaultOutputPath(
    allocator: Allocator,
    project_path: []const u8,
    program_name: []const u8,
) ![]const u8 {
    return std.fs.path.join(allocator, &.{ project_path, ".silex", "bin", program_name });
}

fn cacheKey(cpp: []const u8) [64]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update("silex-cache-v1\x00");
    hasher.update(@tagName(builtin.target.cpu.arch));
    hasher.update("\x00");
    hasher.update(@tagName(builtin.target.os.tag));
    hasher.update("\x00");
    hasher.update(cpp);

    var digest: [std.crypto.hash.sha2.Sha256.digest_length]u8 = undefined;
    hasher.final(&digest);
    return std.fmt.bytesToHex(digest, .lower);
}

fn fileExists(io: Io, path: []const u8) !bool {
    Io.Dir.cwd().access(io, path, .{ .execute = true }) catch |err| switch (err) {
        error.FileNotFound => return false,
        else => |other| return other,
    };
    return true;
}

fn copyArtifact(io: Io, source_path: []const u8, destination_path: []const u8) !void {
    if (std.fs.path.dirname(destination_path)) |directory| {
        if (directory.len > 0) try Io.Dir.cwd().createDirPath(io, directory);
    }
    try Io.Dir.copyFile(.cwd(), source_path, .cwd(), destination_path, io, .{ .make_path = true });
}

fn isHelp(argument: []const u8) bool {
    return std.mem.eql(u8, argument, "--help") or std.mem.eql(u8, argument, "-h");
}

fn isIdentifierStart(character: u8) bool {
    return std.ascii.isAlphabetic(character) or character == '_';
}

fn isIdentifierContinue(character: u8) bool {
    return isIdentifierStart(character) or std.ascii.isDigit(character);
}

const usage =
    \\Usage:
    \\  silex compile <source.sx> [-o <executable>] [--emit-cpp]
    \\  silex run <source.sx>
    \\  silex --help
    \\  silex --version
    \\
;

test "parse minimal program" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator,
        \\void main() {
        \\    print("Hello World");
        \\}
    );

    var program = try parser.parse();
    defer program.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 1), program.print_arguments.items.len);
    try std.testing.expectEqualStrings("Hello World", program.print_arguments.items[0]);
}

test "reject missing semicolon" {
    const allocator = std.testing.allocator;
    var parser = Parser.init(allocator,
        \\void main() {
        \\    print("Hello World")
        \\}
    );

    try std.testing.expectError(error.InvalidSource, parser.parse());
    try std.testing.expectEqualStrings("expected ';'", parser.diagnostic.?.message);
}

test "cache key follows generated content" {
    const first = cacheKey("first");
    const repeated = cacheKey("first");
    const changed = cacheKey("second");

    try std.testing.expectEqualSlices(u8, &first, &repeated);
    try std.testing.expect(!std.mem.eql(u8, &first, &changed));
}

test "default output belongs to current project" {
    const allocator = std.testing.allocator;
    const output = try defaultOutputPath(allocator, "", "Main");
    defer allocator.free(output);

    try std.testing.expectEqualStrings(".silex/bin/Main", output);
}
