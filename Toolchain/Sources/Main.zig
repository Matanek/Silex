const std = @import("std");
const Lower = @import("Arm64/Lower.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Lsp = @import("Lsp/Server.zig");
const MachO = @import("MacOS/MachO.zig");
const Project = @import("Project.zig");

const Io = std.Io;

const usage =
    \\Usage: silex run <source.sx> [--emit-ir]
    \\       silex compile <source.sx> -o <executable>
    \\       silex lsp
    \\
    \\Runs a Silex source file, emits a native macos-arm64 executable,
    \\or serves editor requests over standard input and output.
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
    if (std.mem.eql(u8, args[1], "run")) return runSource(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "compile")) return compileNative(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "lsp")) return runLanguageServer(init, args[2..]);
    std.debug.print("silex: unknown command '{s}'\n\n{s}", .{ args[1], usage });
    return 1;
}

fn runLanguageServer(init: std.process.Init, args: []const []const u8) !u8 {
    if (args.len != 0) {
        std.debug.print("silex: 'lsp' does not accept arguments\n", .{});
        return 1;
    }
    var server = Lsp.Server.initWithPackages(
        init.gpa,
        init.io,
        try globalPackagesRoot(init.arena.allocator(), init.environ_map),
    );
    defer server.deinit();
    try server.run();
    return 0;
}

fn runSource(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len < 1 or args.len > 2) {
        std.debug.print("silex: expected 'run <source.sx> [--emit-ir]'\n\n{s}", .{usage});
        return 1;
    }

    const emit_ir = args.len == 2 and std.mem.eql(u8, args[1], "--emit-ir");
    if (args.len == 2 and !emit_ir) {
        std.debug.print("silex: unknown option '{s}'\n", .{args[1]});
        return 1;
    }

    var compiler = Project.Compiler.initWithPackages(
        allocator,
        init.io,
        try globalPackagesRoot(allocator, init.environ_map),
    );
    const compilation = compiler.compile(args[0]) catch |err| switch (err) {
        error.InvalidSource => {
            const diagnostic = compiler.diagnostic.?;
            std.debug.print("{s}:{d}:{d}: error: {s}\n", .{
                compiler.diagnosticPath(args[0]),
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
    const result = Interpreter.runCapture(allocator, compilation.ir) catch |err| {
        std.debug.print("silex: runtime error: {t}\n", .{err});
        return 1;
    };
    try Io.File.stdout().writeStreamingAll(init.io, result.stdout);
    try Io.File.stderr().writeStreamingAll(init.io, result.stderr);
    return result.exit_code;
}

fn compileNative(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len != 3 or !std.mem.eql(u8, args[1], "-o")) {
        std.debug.print("silex: expected 'compile <source.sx> -o <executable>'\n\n{s}", .{usage});
        return 1;
    }

    const source_path = args[0];
    const output_path = args[2];
    var compiler = Project.Compiler.initWithPackages(
        allocator,
        init.io,
        try globalPackagesRoot(allocator, init.environ_map),
    );
    const compilation = compiler.compile(source_path) catch |err| switch (err) {
        error.InvalidSource => {
            const diagnostic = compiler.diagnostic.?;
            std.debug.print("{s}:{d}:{d}: error: {s}\n", .{
                compiler.diagnosticPath(source_path),
                diagnostic.position.line,
                diagnostic.position.column,
                diagnostic.message,
            });
            return 1;
        },
        else => return err,
    };

    const machine = Lower.lower(allocator, compilation.ir) catch |err| {
        std.debug.print("silex: native backend cannot lower this program: {t}\n", .{err});
        return 1;
    };
    const executable = MachO.emit(allocator, machine) catch |err| {
        std.debug.print("silex: cannot emit native executable: {t}\n", .{err});
        return 1;
    };

    const file = Io.Dir.cwd().createFile(init.io, output_path, .{
        .permissions = .executable_file,
    }) catch |err| {
        std.debug.print("silex: unable to create '{s}': {t}\n", .{ output_path, err });
        return 1;
    };
    defer file.close(init.io);
    file.writeStreamingAll(init.io, executable) catch |err| {
        std.debug.print("silex: unable to write '{s}': {t}\n", .{ output_path, err });
        return 1;
    };
    file.setPermissions(init.io, .executable_file) catch |err| {
        std.debug.print("silex: unable to make '{s}' executable: {t}\n", .{ output_path, err });
        return 1;
    };
    return 0;
}

fn isHelp(argument: []const u8) bool {
    return std.mem.eql(u8, argument, "--help") or std.mem.eql(u8, argument, "-h");
}

fn globalPackagesRoot(
    allocator: std.mem.Allocator,
    environment: *const std.process.Environ.Map,
) !?[]const u8 {
    const home = environment.get("HOME") orelse return null;
    return try std.fs.path.join(allocator, &.{ home, ".silex", "packages" });
}

test {
    _ = @import("Arm64/Differential.zig");
    _ = @import("Arm64/Encoder.zig");
    _ = @import("Arm64/Instructions.zig");
    _ = @import("Arm64/Lower.zig");
    _ = @import("Arm64/Machine.zig");
    _ = @import("Arm64/Runner.zig");
    _ = @import("MacOS/CodeSignature.zig");
    _ = @import("MacOS/MachO.zig");
    _ = @import("Composition.zig");
    _ = @import("EnumTests.zig");
    _ = @import("FixedArrayTests.zig");
    _ = @import("DynamicListTests.zig");
    _ = @import("CollectionMutationTests.zig");
    _ = @import("CollectionSliceTests.zig");
    _ = @import("ForIterationTests.zig");
    _ = @import("GenericTests.zig");
    _ = @import("MatchTests.zig");
    _ = @import("MapErrorTests.zig");
    _ = @import("MainResultTests.zig");
    _ = @import("MoveTests.zig");
    _ = @import("MutableReferenceTests.zig");
    _ = @import("NativeComposition.zig");
    _ = @import("NativeEffects.zig");
    _ = @import("Modules.zig");
    _ = @import("Numeric.zig");
    _ = @import("OptionalTests.zig");
    _ = @import("ResultTests.zig");
    _ = @import("TryTests.zig");
    _ = @import("Packages.zig");
    _ = @import("ReadReferenceTests.zig");
    _ = @import("Lexer.zig");
    _ = @import("Lsp/Completion.zig");
    _ = @import("Lsp/Diagnostics.zig");
    _ = @import("Lsp/Protocol.zig");
    _ = @import("Lsp/Server.zig");
    _ = @import("Lsp/Workspace.zig");
    _ = @import("Parser.zig");
    _ = @import("Project.zig");
    _ = @import("Project/CoreTests.zig");
    _ = @import("ProjectMigrationTests.zig");
    _ = @import("ProjectStructureTests.zig");
    _ = @import("Semantic/Analyzer.zig");
    _ = @import("Semantic/Tests.zig");
    _ = @import("Ir.zig");
    _ = @import("Interpreter.zig");
    _ = @import("Interface.zig");
    _ = @import("Frontend.zig");
}
