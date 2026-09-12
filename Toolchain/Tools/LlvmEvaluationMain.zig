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
    if (args.len != 7 or
        !std.mem.eql(u8, args[1], "--backend") or
        !std.mem.eql(u8, args[2], "llvm") or
        !std.mem.eql(u8, args[3], "--shadercross"))
    {
        std.debug.print(
            "usage: silex-llvm-evaluation --backend llvm --shadercross PATH SOURCE OUTPUT.ll\n",
            .{},
        );
        return 1;
    }
    const started = std.Io.Clock.awake.now(init.io);
    var compiler = Silex.Project.Compiler.init(allocator, init.io);
    compiler.shadercross_path = args[4];
    const compiled = compiler.compile(args[5]) catch |err| {
        if (compiler.diagnostic) |diagnostic| std.debug.print("{s}:{d}:{d}: {s}\n", .{
            compiler.diagnosticPath(args[5]), diagnostic.position.line, diagnostic.position.column, diagnostic.message,
        });
        return err;
    };
    const composed_at = std.Io.Clock.awake.now(init.io);
    const closed = try Silex.ProgramScope.executable(allocator, compiled.ir);
    Silex.ReleaseVerifier.verify(allocator, closed.program) catch |err| {
        for (closed.program.functions) |function| {
            Silex.ReleaseVerifier.verifyFunction(allocator, closed.program, function) catch |function_err| {
                std.debug.print(
                    "silex LLVM evaluation: verifier rejected function '{s}': {t}\n",
                    .{ function.name, function_err },
                );
                break;
            };
        }
        return err;
    };
    const closed_at = std.Io.Clock.awake.now(init.io);
    // No Release optimization, native lowering, or native implementation of a Silex function.
    const llvm = try Emitter.emitWithBoundaries(allocator, closed.program, compiled.boundaries);
    const emitted_at = std.Io.Clock.awake.now(init.io);
    const file = try std.Io.Dir.cwd().createFile(init.io, args[6], .{});
    defer file.close(init.io);
    try file.writeStreamingAll(init.io, llvm);
    const written_at = std.Io.Clock.awake.now(init.io);
    const metrics = try std.fmt.allocPrint(
        allocator,
        "{{\"compose_ns\":{d},\"close_verify_ns\":{d},\"lower_serialize_ns\":{d},\"write_ns\":{d},\"functions\":{d},\"sources\":{d}}}\n",
        .{ started.durationTo(composed_at).toNanoseconds(), composed_at.durationTo(closed_at).toNanoseconds(), closed_at.durationTo(emitted_at).toNanoseconds(), emitted_at.durationTo(written_at).toNanoseconds(), closed.program.functions.len, compiled.cache_files.len },
    );
    try std.Io.File.stdout().writeStreamingAll(init.io, metrics);
    return 0;
}
