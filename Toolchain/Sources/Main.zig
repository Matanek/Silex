const std = @import("std");
const FrontendModule = @import("Frontend.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");

const Io = std.Io;

const usage =
    \\Usage: silex <source.sx> [--emit-ir]
    \\
    \\Parses, validates, lowers, and interprets a Silex source file.
    \\
;

pub fn main(init: std.process.Init) u8 {
    return runCli(init) catch |err| {
        std.debug.print("silex: error: {t}\n", .{err});
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
    if (args.len < 2 or args.len > 3) {
        std.debug.print("silex: expected one source file\n\n{s}", .{usage});
        return 1;
    }

    const emit_ir = args.len == 3 and std.mem.eql(u8, args[2], "--emit-ir");
    if (args.len == 3 and !emit_ir) {
        std.debug.print("silex: unknown option '{s}'\n", .{args[2]});
        return 1;
    }

    const source = Io.Dir.cwd().readFileAlloc(init.io, args[1], allocator, .limited(1024 * 1024)) catch |err| {
        std.debug.print("silex: unable to read '{s}': {t}\n", .{ args[1], err });
        return 1;
    };

    var frontend = FrontendModule.Frontend.init(allocator);
    const compilation = frontend.compile(source) catch |err| switch (err) {
        error.InvalidSource => {
            const diagnostic = frontend.diagnostic.?;
            std.debug.print("{s}:{d}:{d}: error: {s}\n", .{
                args[1],
                diagnostic.position.line,
                diagnostic.position.column,
                diagnostic.message,
            });
            return 1;
        },
        else => return err,
    };

    if (emit_ir) {
        const text = try Ir.writeText(allocator, compilation.ir);
        try Io.File.stdout().writeStreamingAll(init.io, text);
    }
    return Interpreter.run(compilation.ir) catch |err| {
        std.debug.print("silex: invalid IR: {t}\n", .{err});
        return 1;
    };
}

fn isHelp(argument: []const u8) bool {
    return std.mem.eql(u8, argument, "--help") or std.mem.eql(u8, argument, "-h");
}

test {
    _ = @import("Lexer.zig");
    _ = @import("Parser.zig");
    _ = @import("Semantic.zig");
    _ = @import("Ir.zig");
    _ = @import("Interpreter.zig");
    _ = @import("Frontend.zig");
}
