const std = @import("std");
const Boundary = @import("Boundary.zig");
const Cli = @import("Cli.zig");
const CompilationCache = @import("CompilationCache.zig");
const Lower = @import("Arm64/Lower.zig");
const Arm64Encoder = @import("Arm64/Encoder.zig");
const Interpreter = @import("Interpreter.zig");
const Ir = @import("Ir.zig");
const Lsp = @import("Lsp/Server.zig");
const MachO = @import("MacOS/MachO.zig");
const Elf = @import("Linux/Elf.zig");
const X64Encoder = @import("X64/Encoder.zig");
const PE = @import("Windows/PE.zig");
const WindowsImports = @import("Windows/Imports.zig");
const ReleaseOptimizer = @import("Optimize/Release.zig");
const Project = @import("Project.zig");
const TargetModule = @import("Target.zig");

const Io = std.Io;

const usage =
    \\Usage: silex run <source.sx> [-d|--debug|-r|--release] [-n|--nocache] [--emit-ir]
    \\       silex interpret <source.sx> [-n|--nocache] [--emit-ir]
    \\       silex compile <source.sx> [--target <target>] [-d|--debug|-r|--release] [-n|--nocache] -o|--output <executable>
    \\       silex targets
    \\       silex lsp
    \\
    \\Builds and runs a native Silex program, executes portable IR through the
    \\reference interpreter, emits an executable, or serves editor requests.
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
    if (std.mem.eql(u8, args[1], "interpret")) return interpretSource(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "compile")) return compileNative(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "targets")) return listTargets(init, allocator, args[2..]);
    if (std.mem.eql(u8, args[1], "lsp")) return runLanguageServer(init, args[2..]);
    std.debug.print("silex: unknown command '{s}'\n\n{s}", .{ args[1], usage });
    return 1;
}

fn listTargets(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    if (args.len != 0) {
        std.debug.print("silex: 'targets' does not accept arguments\n", .{});
        return 1;
    }
    const host = TargetModule.Target.host();
    for (TargetModule.Target.supported) |target| {
        const line = if (host) |selected|
            if (selected.eql(target))
                try std.fmt.allocPrint(allocator, "{s} (host)\n", .{target.name()})
            else
                try std.fmt.allocPrint(allocator, "{s}\n", .{target.name()})
        else
            try std.fmt.allocPrint(allocator, "{s}\n", .{target.name()});
        try Io.File.stdout().writeStreamingAll(init.io, line);
    }
    return 0;
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
    const target = TargetModule.Target.host() orelse {
        std.debug.print("silex: 'run' requires a recognized host target\n", .{});
        return 1;
    };
    const output_path = try runArtifactPath(allocator, options, target);
    const status = try compileNativeOptions(init, allocator, .{
        .source_path = options.source_path,
        .output_path = output_path,
        .mode = options.mode,
        .cache = options.cache,
        .target = target,
    }, options.emit_ir);
    if (status != 0) return status;
    return executeNative(init, output_path);
}

fn interpretSource(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseInterpret(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("interpret", diagnostic);
            return 1;
        },
    };

    const target = TargetModule.Target.host() orelse {
        std.debug.print("silex: 'interpret' requires a recognized host target\n", .{});
        return 1;
    };
    var boundaries: []const Boundary.Function = &.{};
    const cached_ir = if (options.cache) CompilationCache.loadIr(allocator, init.io, options.source_path, target.name()) else null;
    const portable_ir = if (cached_ir) |cached| if (containsBoundaryCall(cached)) null else cached else null;
    const program = portable_ir orelse program: {
        var compiler = Project.Compiler.initWithPackagesAndCache(
            allocator,
            init.io,
            try globalPackagesRoot(allocator, init.environ_map),
            options.cache,
        );
        compiler.target = target;
        const compilation = compiler.compile(options.source_path) catch |err| switch (err) {
            error.InvalidSource => {
                printSourceDiagnostic(compiler, options.source_path);
                return 1;
            },
            else => return err,
        };
        boundaries = compilation.boundaries;
        // Portable IR deliberately omits provider metadata. Recompile programs
        // with boundaries until the cache owns that complete contract.
        if (options.cache and boundaries.len == 0) CompilationCache.storeIr(
            allocator,
            init.io,
            options.source_path,
            target.name(),
            compilation.files,
            compilation.ir,
        );
        break :program compilation.ir;
    };

    if (options.emit_ir) {
        const text = try Ir.writeText(allocator, program);
        try Io.File.stdout().writeStreamingAll(init.io, text);
    }
    for (boundaries) |boundary| {
        if (Interpreter.supportsBoundary(boundary)) continue;
        std.debug.print(
            "silex: 'interpret' cannot execute foreign function '{s}' from '{s}'; use 'silex run' for this platform boundary\n",
            .{ boundary.source_name, boundary.provider },
        );
        return 1;
    }
    const result = Interpreter.runCaptureWithBoundaries(allocator, init.io, program, boundaries) catch |err| {
        std.debug.print("silex: runtime error: {t}\n", .{err});
        return 1;
    };
    try Io.File.stdout().writeStreamingAll(init.io, result.stdout);
    try Io.File.stderr().writeStreamingAll(init.io, result.stderr);
    return result.exit_code;
}

fn containsBoundaryCall(program: Ir.Program) bool {
    for (program.functions) |function| {
        for (function.blocks) |block| {
            for (block.instructions) |instruction| switch (instruction) {
                .boundary_call => return true,
                else => {},
            };
        }
    }
    return false;
}

fn compileNative(init: std.process.Init, allocator: std.mem.Allocator, args: []const []const u8) !u8 {
    const options = switch (Cli.parseCompile(args)) {
        .options => |options| options,
        .diagnostic => |diagnostic| {
            printCliDiagnostic("compile", diagnostic);
            return 1;
        },
    };
    return compileNativeOptions(init, allocator, options, false);
}

fn compileNativeOptions(
    init: std.process.Init,
    allocator: std.mem.Allocator,
    options: Cli.CompileOptions,
    emit_ir: bool,
) !u8 {
    const target = options.target orelse TargetModule.Target.host() orelse {
        std.debug.print("silex: 'compile' requires --target on this host\n", .{});
        return 1;
    };
    var boundaries: []const Boundary.Function = &.{};
    const portable_ir = if (options.cache) CompilationCache.loadIr(allocator, init.io, options.source_path, target.name()) else null;
    const program = portable_ir orelse program: {
        var compiler = Project.Compiler.initWithPackagesAndCache(
            allocator,
            init.io,
            try globalPackagesRoot(allocator, init.environ_map),
            options.cache,
        );
        compiler.target = target;
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
            CompilationCache.storeIr(allocator, init.io, options.source_path, target.name(), compilation.files, compilation.ir);
        }
        break :program compilation.ir;
    };

    if (emit_ir) {
        const text = try Ir.writeText(allocator, program);
        try Io.File.stdout().writeStreamingAll(init.io, text);
    }

    if (!target.hasNativeEmitter()) {
        std.debug.print("silex: target '{s}' is recognized but its native backend is not implemented yet\n", .{target.name()});
        return 1;
    }

    const native_variant = try std.fmt.allocPrint(allocator, "{s}:{s}:{s}", .{ target.name(), @tagName(options.mode), options.source_path });
    const cache_key = if (options.cache)
        CompilationCache.key(allocator, init.io, program.files, "compile", native_variant) catch null
    else
        null;
    const executable_kind = if (target.eql(.macos_arm64)) "macho" else if (target.eql(.linux_x64)) "elf" else "pe";
    if (cache_key) |digest| if (CompilationCache.load(allocator, init.io, digest, executable_kind)) |cached| {
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
    const executable = executable: {
        if (target.eql(.macos_arm64)) break :executable MachO.emit(allocator, machine) catch |err| {
            std.debug.print("silex: cannot emit native executable: {t}\n", .{err});
            return 1;
        };
        if (target.eql(.linux_x64)) {
            var image = X64Encoder.encodeLinux(allocator, machine) catch |err| {
                std.debug.print("silex: Linux X64 encoder cannot emit this program yet: {t}\n", .{err});
                return 1;
            };
            defer image.deinit(allocator);
            break :executable Elf.emit(allocator, image.code, image.entry_offset) catch |err| {
                std.debug.print("silex: cannot emit Linux ELF executable: {t}\n", .{err});
                return 1;
            };
        }
        if (target.eql(.windows_x64)) {
            var image = X64Encoder.encodeWindows(allocator, machine) catch |err| {
                std.debug.print("silex: Windows X64 encoder cannot emit this program yet: {t}\n", .{err});
                return 1;
            };
            defer image.deinit(allocator);
            break :executable PE.emitX64(
                allocator,
                .x64,
                image.code,
                image.entry_offset,
                image.windows_import_sites,
            ) catch |err| {
                std.debug.print("silex: cannot emit Windows PE32+ executable: {t}\n", .{err});
                return 1;
            };
        }
        if (target.eql(.windows_arm64)) {
            const main_id = findMachineMain(machine) orelse {
                std.debug.print("silex: Windows ARM64 executable has no valid main function\n", .{});
                return 1;
            };
            var image = Arm64Encoder.encodeWindows(allocator, machine, .{ .executable_main = main_id }) catch |err| {
                std.debug.print("silex: Windows ARM64 encoder cannot emit this program yet: {t}\n", .{err});
                return 1;
            };
            defer image.deinit(allocator);
            const sites = try allocator.alloc(WindowsImports.Arm64Site, image.external_call_sites.len);
            defer allocator.free(sites);
            for (image.external_call_sites, 0..) |site, index| {
                const symbol = site.windows_symbol orelse symbol: {
                    if (site.function >= machine.external_functions.len) return error.InvalidProgram;
                    const external = machine.external_functions[site.function];
                    if (std.mem.eql(u8, external.provider, "Windows.bcrypt_primitives") and
                        std.mem.eql(u8, external.source_name, "ProcessPrng"))
                    {
                        break :symbol WindowsImports.Symbol.process_prng;
                    }
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and
                        std.mem.eql(u8, external.source_name, "QueryPerformanceCounter"))
                    {
                        break :symbol WindowsImports.Symbol.query_performance_counter;
                    }
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and
                        std.mem.eql(u8, external.source_name, "QueryPerformanceFrequency"))
                    {
                        break :symbol WindowsImports.Symbol.query_performance_frequency;
                    }
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_write")) break :symbol .crt_write;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_read")) break :symbol .crt_read;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_isatty")) break :symbol .crt_isatty;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_wopen")) break :symbol .crt_wopen;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_close")) break :symbol .crt_close;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_commit")) break :symbol .crt_commit;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_lseeki64")) break :symbol .crt_lseeki64;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_chsize_s")) break :symbol .crt_chsize_s;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "__p___argc")) break :symbol .crt_p_argc;
                    if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "__p___wargv")) break :symbol .crt_p_wargv;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetStdHandle")) break :symbol .get_std_handle;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleScreenBufferInfo")) break :symbol .get_console_screen_buffer_info;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleMode")) break :symbol .get_console_mode;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetConsoleMode")) break :symbol .set_console_mode;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleCP")) break :symbol .get_console_cp;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetConsoleCP")) break :symbol .set_console_cp;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "WaitForSingleObject")) break :symbol .wait_for_single_object;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetCurrentDirectoryW")) break :symbol .get_current_directory_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetCurrentDirectoryW")) break :symbol .set_current_directory_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetModuleFileNameW")) break :symbol .get_module_file_name_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetCurrentProcessId")) break :symbol .get_current_process_id;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetEnvironmentVariableW")) break :symbol .get_environment_variable_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetEnvironmentVariableW")) break :symbol .set_environment_variable_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetEnvironmentStringsW")) break :symbol .get_environment_strings_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FreeEnvironmentStringsW")) break :symbol .free_environment_strings_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetFileAttributesExW")) break :symbol .get_file_attributes_ex_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindFirstFileW")) break :symbol .find_first_file_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindNextFileW")) break :symbol .find_next_file_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindClose")) break :symbol .find_close;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreateDirectoryW")) break :symbol .create_directory_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "DeleteFileW")) break :symbol .delete_file_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "RemoveDirectoryW")) break :symbol .remove_directory_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "MoveFileExW")) break :symbol .move_file_ex_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CopyFileW")) break :symbol .copy_file_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetFileAttributesW")) break :symbol .set_file_attributes_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetFullPathNameW")) break :symbol .get_full_path_name_w;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "GetAddrInfoW")) break :symbol .get_addr_info_w;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "FreeAddrInfoW")) break :symbol .free_addr_info_w;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "WSAStartup")) break :symbol .wsa_startup;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "WSACleanup")) break :symbol .wsa_cleanup;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "socket")) break :symbol .wsa_socket;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "connect")) break :symbol .wsa_connect;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "bind")) break :symbol .wsa_bind;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "listen")) break :symbol .wsa_listen;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "accept")) break :symbol .wsa_accept;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "recv")) break :symbol .wsa_recv;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "send")) break :symbol .wsa_send;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "shutdown")) break :symbol .wsa_shutdown;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "closesocket")) break :symbol .wsa_close_socket;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "getsockname")) break :symbol .wsa_getsockname;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "getpeername")) break :symbol .wsa_getpeername;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "setsockopt")) break :symbol .wsa_setsockopt;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "sendto")) break :symbol .wsa_sendto;
                    if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "recvfrom")) break :symbol .wsa_recvfrom;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreatePipe")) break :symbol .create_pipe;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetHandleInformation")) break :symbol .set_handle_information;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreateProcessW")) break :symbol .create_process_w;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "ReadFile")) break :symbol .read_file;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "WriteFile")) break :symbol .write_file;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "PeekNamedPipe")) break :symbol .peek_named_pipe;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CloseHandle")) break :symbol .close_handle;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "TerminateProcess")) break :symbol .terminate_process;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetExitCodeProcess")) break :symbol .get_exit_code_process;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetLastError")) break :symbol .get_last_error;
                    if (std.mem.eql(u8, external.provider, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreateThread")) break :symbol .create_thread;
                    return error.InvalidProgram;
                };
                sites[index] = .{ .instruction_offset = site.instruction_offset, .symbol = symbol };
            }
            break :executable PE.emitArm64(allocator, image.code, image.entry_offset.?, sites) catch |err| {
                std.debug.print("silex: cannot emit Windows ARM64 PE32+ executable: {t}\n", .{err});
                return 1;
            };
        }
        unreachable;
    };

    if (cache_key) |digest| CompilationCache.store(allocator, init.io, digest, executable_kind, executable);
    return writeExecutable(init, options.output_path, executable);
}

fn findMachineMain(program: @import("Arm64/Machine.zig").Program) ?usize {
    for (program.functions, 0..) |function, index| {
        if (std.mem.eql(u8, function.name, "main") and function.parameter_count == 0) return index;
    }
    return null;
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
    if (std.fs.path.dirname(output_path)) |directory| Io.Dir.cwd().createDirPath(init.io, directory) catch |err| {
        std.debug.print("silex: unable to create directory '{s}': {t}\n", .{ directory, err });
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

fn runArtifactPath(allocator: std.mem.Allocator, options: Cli.RunOptions, target: TargetModule.Target) ![]const u8 {
    const digest = CompilationCache.artifactKey("run-executable", &.{ options.source_path, target.name(), @tagName(options.mode) });
    const hex = std.fmt.bytesToHex(digest, .lower);
    const extension = if (target.eql(.windows_x64) or target.eql(.windows_arm64)) ".exe" else "";
    return std.fmt.allocPrint(
        allocator,
        ".silex/run/{s}-{s}-{s}-{s}{s}",
        .{ std.fs.path.stem(options.source_path), target.name(), @tagName(options.mode), hex[0..16], extension },
    );
}

fn executeNative(init: std.process.Init, executable_path: []const u8) !u8 {
    var child = std.process.spawn(init.io, .{
        .argv = &.{executable_path},
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    }) catch |err| {
        std.debug.print("silex: unable to run '{s}': {t}\n", .{ executable_path, err });
        return 1;
    };
    defer child.kill(init.io);
    return switch (try child.wait(init.io)) {
        .exited => |code| code,
        .signal => |signal| terminated: {
            std.debug.print("silex: program terminated by signal {d}\n", .{@intFromEnum(signal)});
            break :terminated 1;
        },
        .stopped => |signal| stopped: {
            std.debug.print("silex: program stopped by signal {d}\n", .{@intFromEnum(signal)});
            break :stopped 1;
        },
        .unknown => |status| unknown: {
            std.debug.print("silex: program terminated with unknown status {d}\n", .{status});
            break :unknown 1;
        },
    };
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
        .missing_target => std.debug.print("silex: option '--target' expects a target name\n", .{}),
        .duplicate_target => std.debug.print("silex: target is specified more than once\n", .{}),
        .unknown_target => std.debug.print("silex: unknown target '{s}'; expected macos-arm64, linux-x64, windows-x64 or windows-arm64\n", .{diagnostic.argument.?}),
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

test "run owns a stable mode-specific artifact below .silex" {
    const debug = try runArtifactPath(std.testing.allocator, .{
        .source_path = "Sources/Main.sx",
        .emit_ir = false,
        .mode = .debug,
        .cache = true,
    }, .macos_arm64);
    defer std.testing.allocator.free(debug);
    const release = try runArtifactPath(std.testing.allocator, .{
        .source_path = "Sources/Main.sx",
        .emit_ir = false,
        .mode = .release,
        .cache = true,
    }, .macos_arm64);
    defer std.testing.allocator.free(release);
    try std.testing.expect(std.mem.startsWith(u8, debug, ".silex/run/Main-macos-arm64-debug-"));
    try std.testing.expect(std.mem.startsWith(u8, release, ".silex/run/Main-macos-arm64-release-"));
    try std.testing.expect(!std.mem.eql(u8, debug, release));
}

test {
    _ = @import("Target.zig");
    _ = @import("Cli.zig");
    _ = @import("Arm64/Differential.zig");
    _ = @import("Arm64/Encoder.zig");
    _ = @import("Arm64/Instructions.zig");
    _ = @import("Arm64/Lower.zig");
    _ = @import("Arm64/Machine.zig");
    _ = @import("Arm64/Runner.zig");
    _ = @import("BorrowedReturnTests.zig");
    _ = @import("CallbackTests.zig");
    _ = @import("MacOS/CodeSignature.zig");
    _ = @import("MacOS/MachO.zig");
    _ = @import("Linux/Elf.zig");
    _ = @import("X64/Encoder.zig");
    _ = @import("Windows/PE.zig");
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
    _ = @import("MutexTests.zig");
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
