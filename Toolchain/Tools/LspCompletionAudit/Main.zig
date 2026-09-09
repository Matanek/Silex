const std = @import("std");
const Lsp = @import("silex_lsp_audit");

pub fn main(init: std.process.Init) u8 {
    return run(init) catch |err| {
        std.debug.print("LSP completion corpus audit: {t}\n", .{err});
        return 1;
    };
}

fn run(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const arguments = try init.minimal.args.toSlice(allocator);
    if (arguments.len != 2) return error.InvalidArguments;
    const report = try Lsp.CorpusAudit.auditWorkspace(allocator, init.io, arguments[1]);
    try Lsp.CorpusAudit.requireRepresentative(report);

    const stdout = std.Io.File.stdout();
    try stdout.writeStreamingAll(init.io, try std.fmt.allocPrint(
        allocator,
        "source_files\t{d}\nsource_bytes\t{d}\nfingerprint\t{x:0>16}\n",
        .{ report.source_files, report.source_bytes, report.fingerprint },
    ));
    inline for (std.meta.fields(Lsp.CorpusAudit.Signal)) |field| {
        const signal: Lsp.CorpusAudit.Signal = @enumFromInt(field.value);
        try stdout.writeStreamingAll(init.io, try std.fmt.allocPrint(
            allocator,
            "signal\t{s}\t{d}\n",
            .{ Lsp.CorpusAudit.signalName(signal), report.count(signal) },
        ));
    }
    return 0;
}
