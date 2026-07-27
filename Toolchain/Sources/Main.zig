const std = @import("std");
const Boundary = @import("Boundary.zig");
const Cli = @import("Cli.zig");
const CompilationCache = @import("CompilationCache.zig");
const Lower = @import("Arm64/Lower.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Lsp = @import("Lsp/Server.zig");
const MachO = @import("MacOS/MachO.zig");
const ReleaseOptimizer = @import("Optimize/Release.zig");
const Project = @import("Project.zig");

const Io = std.Io;

const usage =
    \\Usage: silex run <source.sx> [-n|--nocache] [--emit-ir]
    \\       silex compile <source.sx> [-d|--debug|-r|--release] [-n|--nocache] -o|--output <executable>
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
    const options = switch (Cli.parseRun(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("run", diagnostic);
            return 1;
        },
    };

    const portable_ir = if (options.cache) CompilationCache.loadIr(allocator, init.io, options.source_path) else null;
    const program = portable_ir orelse program: {
        var compiler = Project.Compiler.initWithPackagesAndCache(
            allocator,
            init.io,
            try globalPackagesRoot(allocator, init.environ_map),
            options.cache,
        );
        const compilation = compiler.compile(options.source_path) catch |err| switch (err) {
            error.InvalidSource => {
                printSourceDiagnostic(compiler, options.source_path);
                return 1;
            },
            else => return err,
        };
        if (options.cache) CompilationCache.storeIr(
            allocator,
            init.io,
            options.source_path,
            compilation.files,
            compilation.ir,
        );
        break :program compilation.ir;
    };

    if (options.emit_ir) {
        const text = try Ir.writeText(allocator, program);
        try Io.File.stdout().writeStreamingAll(init.io, text);
    }
    const result = Interpreter.runCapture(allocator, program) catch |err| {
        std.debug.print("silex: runtime error: {t}\n", .{err});
        return 1;
    };
    try Io.File.stdout().writeStreamingAll(init.io, result.stdout);
    try Io.File.stderr().writeStreamingAll(init.io, result.stderr);
    return result.exit_code;
}

fn compileNative(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseCompile(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("compile", diagnostic);
            return 1;
        },
    };
    var boundaries: []const Boundary.Function = &.{};
    const portable_ir = if (options.cache) CompilationCache.loadIr(allocator, init.io, options.source_path) else null;
    const program = portable_ir orelse program: {
        var compiler = Project.Compiler.initWithPackagesAndCache(
            allocator,
            init.io,
            try globalPackagesRoot(allocator, init.environ_map),
            options.cache,
        );
        const compilation = compiler.compile(options.source_path) catch |err| switch (err) {
            error.InvalidSource => {
                printSourceDiagnostic(compiler, options.source_path);
                return 1;
            },
            else => return err,
        };
        boundaries = compilation.boundaries;
        // A portable-IR cache entry deliberately contains no target provider or ABI
        // information. Boundary-bearing programs are therefore cached only after
        // target lowering, where their complete native contract is represented.
        if (options.cache and boundaries.len == 0) {
            CompilationCache.storeIr(allocator, init.io, options.source_path, compilation.files, compilation.ir);
        }
        break :program compilation.ir;
    };

    const native_variant = try std.fmt.allocPrint(allocator, "{s}:{s}", .{ @tagName(options.mode), options.source_path });
    const cache_key = if (options.cache)
        CompilationCache.key(allocator, init.io, program.files, "compile", native_variant) catch null
    else
        null;
    if (cache_key) |digest| if (CompilationCache.load(allocator, init.io, digest, "macho")) |cached| {
        return writeExecutable(init, options.output_path, cached);
    };

    const native_ir = switch (options.mode) {
        .debug => program,
        .release => (if (options.cache)
            ReleaseOptimizer.optimizeCached(allocator, init.io, program)
        else
            ReleaseOptimizer.optimize(allocator, program)) catch |err| {
            std.debug.print("silex: optimizer rejected the portable IR: {t}\n", .{err});
            return 1;
        },
    };
    const lower_mode: Lower.Mode = switch (options.mode) {
        .debug => .debug,
        .release => .release,
    };
    const machine = (if (options.cache)
        Lower.lowerCachedWithBoundaries(allocator, init.io, native_ir, boundaries, lower_mode)
    else
        Lower.lowerWithModeAndBoundaries(allocator, native_ir, boundaries, lower_mode)) catch |err| {
        std.debug.print("silex: native backend cannot lower this program: {t}\n", .{err});
        return 1;
    };
    const executable = MachO.emit(allocator, machine) catch |err| {
        std.debug.print("silex: cannot emit native executable: {t}\n", .{err});
        return 1;
    };

    if (cache_key) |digest| CompilationCache.store(allocator, init.io, digest, "macho", executable);
    return writeExecutable(init, options.output_path, executable);
}

fn printSourceDiagnostic(compiler: Project.Compiler, source_path: []const u8) void {
    const diagnostic = compiler.diagnostic.?;
    std.debug.print("{s}:{d}:{d}: error: {s}\n", .{
        compiler.diagnosticPath(source_path),
        diagnostic.position.line,
        diagnostic.position.column,
        diagnostic.message,
    });
}

fn writeExecutable(init: std.process.Init, output_path: []const u8, executable: []const u8) u8 {
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

fn printCliDiagnostic(command: []const u8, diagnostic: Cli.Diagnostic) void {
    switch (diagnostic.kind) {
        .missing_source => std.debug.print("silex: '{s}' expects one source file\n", .{command}),
        .multiple_sources => std.debug.print("silex: '{s}' accepts only one source file, found '{s}'\n", .{ command, diagnostic.argument.? }),
        .missing_output => if (diagnostic.argument) |argument|
            std.debug.print("silex: option '{s}' expects an output path\n", .{argument})
        else
            std.debug.print("silex: 'compile' expects -o or --output followed by an executable path\n", .{}),
        .duplicate_output => std.debug.print("silex: output is specified more than once by '{s}'\n", .{diagnostic.argument.?}),
        .conflicting_modes => std.debug.print("silex: Debug and Release modes are mutually exclusive near '{s}'\n", .{diagnostic.argument.?}),
        .option_unavailable => std.debug.print("silex: option '{s}' is unavailable for '{s}'\n", .{ diagnostic.argument.?, command }),
        .unknown_option => std.debug.print("silex: unknown option '{s}'\n", .{diagnostic.argument.?}),
    }
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
    _ = @import("Cli.zig");
    _ = @import("Arm64/Differential.zig");
    _ = @import("Arm64/Encoder.zig");
    _ = @import("Arm64/Instructions.zig");
    _ = @import("Arm64/Lower.zig");
    _ = @import("Arm64/Machine.zig");
    _ = @import("Arm64/Runner.zig");
    _ = @import("BorrowedReturnTests.zig");
    _ = @import("MacOS/CodeSignature.zig");
    _ = @import("MacOS/MachO.zig");
    _ = @import("Optimize/Release.zig");
    _ = @import("Arm64/RegisterAllocation.zig");
    _ = @import("CompilationCache.zig");
    _ = @import("Composition.zig");
    _ = @import("CopyTests.zig");
    _ = @import("SnapshotTests.zig");
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
    _ = @import("DropCollectionTests.zig");
    _ = @import("NativeComposition.zig");
    _ = @import("NativeEffects.zig");
    _ = @import("Modules.zig");
    _ = @import("Numeric.zig");
    _ = @import("OptionalTests.zig");
    _ = @import("ResultTests.zig");
    _ = @import("TryTests.zig");
    _ = @import("ViewTests.zig");
    _ = @import("ClassTests.zig");
    _ = @import("ProtocolTests.zig");
    _ = @import("ExtensionTests.zig");
    _ = @import("Packages.zig");
    _ = @import("ReadReferenceTests.zig");
    _ = @import("RecursiveResourceTests.zig");
    _ = @import("ResourceTests.zig");
    _ = @import("Lexer.zig");
    _ = @import("Lsp/Completion.zig");
    _ = @import("Lsp/Diagnostics.zig");
    _ = @import("Lsp/ExtensionCompletionTests.zig");
    _ = @import("Lsp/Protocol.zig");
    _ = @import("Lsp/Server.zig");
    _ = @import("Lsp/Workspace.zig");
    _ = @import("MacOS/ExternalCallTests.zig");
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
    _ = @import("InteropTests.zig");
    _ = @import("Frontend.zig");
}
