const std = @import("std");
const Silex = @import("silex_optimizer_api");
const Emitter = @import("LlvmEvaluation/Emitter.zig");

pub fn main(init: std.process.Init) u8 {
    return run(init) catch |err| {
        std.debug.print("silex LLVM evaluation: {t}\n", .{err});
        return 1;
    };
}

fn run(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    if (args.len != 9 or
        !std.mem.eql(u8, args[1], "--backend") or
        !std.mem.eql(u8, args[2], "llvm") or
        !std.mem.eql(u8, args[3], "--shadercross") or
        !std.mem.eql(u8, args[5], "--silex-prefix"))
    {
        std.debug.print(
            "usage: silex-llvm-evaluation --backend llvm --shadercross PATH --silex-prefix none|PASS SOURCE OUTPUT.ll\n",
            .{},
        );
        return 1;
    }
    const started = std.Io.Clock.awake.now(init.io);
    var compiler = Silex.Project.Compiler.init(allocator, init.io);
    compiler.shadercross_path = args[4];
    const compiled = compiler.compile(args[7]) catch |err| {
        if (compiler.diagnostic) |diagnostic| std.debug.print("{s}:{d}:{d}: {s}\n", .{
            compiler.diagnosticPath(args[7]), diagnostic.position.line, diagnostic.position.column, diagnostic.message,
        });
        return err;
    };
    const composed_at = std.Io.Clock.awake.now(init.io);
    const closed = try Silex.ProgramScope.executable(allocator, compiled.ir);
    const closed_at = std.Io.Clock.awake.now(init.io);
    var program = closed.program;
    if (!std.mem.eql(u8, args[6], "none")) {
        const pass = Silex.ReleaseOptimizer.PassId.parse(args[6]) orelse {
            std.debug.print("silex LLVM evaluation: unknown Silex pass prefix '{s}'\n", .{args[6]});
            return 1;
        };
        program = try Silex.ReleaseOptimizer.optimizeWithOptions(
            allocator,
            program,
            .{ .stop_after = pass },
        );
    }
    const canonicalized_at = std.Io.Clock.awake.now(init.io);
    Silex.ReleaseVerifier.verify(allocator, program) catch |err| {
        for (program.functions) |function| {
            Silex.ReleaseVerifier.verifyFunction(allocator, program, function) catch |function_err| {
                std.debug.print(
                    "silex LLVM evaluation: verifier rejected function '{s}': {t}\n",
                    .{ function.name, function_err },
                );
                break;
            };
        }
        return err;
    };
    const verified_at = std.Io.Clock.awake.now(init.io);
    // Only the explicitly selected cumulative prefix may run before LLVM. No
    // native lowering or native implementation of a Silex function is mixed in.
    const llvm = try Emitter.emitWithBoundaries(allocator, program, compiled.boundaries);
    const emitted_at = std.Io.Clock.awake.now(init.io);
    const file = try std.Io.Dir.cwd().createFile(init.io, args[8], .{});
    defer file.close(init.io);
    try file.writeStreamingAll(init.io, llvm);
    const written_at = std.Io.Clock.awake.now(init.io);
    const metrics = try std.fmt.allocPrint(
        allocator,
        "{{\"silex_prefix\":\"{s}\",\"compose_ns\":{d},\"close_ns\":{d},\"canonicalize_ns\":{d},\"verify_ns\":{d},\"lower_serialize_ns\":{d},\"write_ns\":{d},\"functions\":{d},\"sources\":{d}}}\n",
        .{ args[6], started.durationTo(composed_at).toNanoseconds(), composed_at.durationTo(closed_at).toNanoseconds(), closed_at.durationTo(canonicalized_at).toNanoseconds(), canonicalized_at.durationTo(verified_at).toNanoseconds(), verified_at.durationTo(emitted_at).toNanoseconds(), emitted_at.durationTo(written_at).toNanoseconds(), program.functions.len, compiled.cache_files.len },
    );
    try std.Io.File.stdout().writeStreamingAll(init.io, metrics);
    return 0;
}
