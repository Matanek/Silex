const std = @import("std");

pub const Mode = enum { debug, release };

pub const Diagnostic = struct {
    kind: Kind,
    argument: ?[]const u8 = null,

    pub const Kind = enum {
        missing_source,
        multiple_sources,
        missing_output,
        duplicate_output,
        conflicting_modes,
        option_unavailable,
        unknown_option,
    };
};

pub const RunOptions = struct {
    source_path: []const u8,
    emit_ir: bool,
    cache: bool,
};

pub const CompileOptions = struct {
    source_path: []const u8,
    output_path: []const u8,
    mode: Mode,
    cache: bool,
};

pub const RunResult = union(enum) {
    options: RunOptions,
    diagnostic: Diagnostic,
};

pub const CompileResult = union(enum) {
    options: CompileOptions,
    diagnostic: Diagnostic,
};

pub fn parseRun(args: []const []const u8) RunResult {
    var source_path: ?[]const u8 = null;
    var emit_ir = false;
    var cache = true;

    for (args) |argument| {
        if (std.mem.eql(u8, argument, "--emit-ir")) {
            emit_ir = true;
        } else if (isNoCacheOption(argument)) {
            cache = false;
        } else if (isNativeOption(argument)) {
            return failure(RunResult, .option_unavailable, argument);
        } else if (std.mem.startsWith(u8, argument, "-")) {
            return failure(RunResult, .unknown_option, argument);
        } else if (source_path != null) {
            return failure(RunResult, .multiple_sources, argument);
        } else {
            source_path = argument;
        }
    }

    return .{ .options = .{
        .source_path = source_path orelse return failure(RunResult, .missing_source, null),
        .emit_ir = emit_ir,
        .cache = cache,
    } };
}

pub fn parseCompile(args: []const []const u8) CompileResult {
    var source_path: ?[]const u8 = null;
    var output_path: ?[]const u8 = null;
    var mode: Mode = .debug;
    var explicit_mode: ?Mode = null;
    var cache = true;
    var index: usize = 0;

    while (index < args.len) : (index += 1) {
        const argument = args[index];
        if (modeFor(argument)) |selected| {
            if (explicit_mode) |previous| if (previous != selected) {
                return failure(CompileResult, .conflicting_modes, argument);
            };
            mode = selected;
            explicit_mode = selected;
        } else if (isNoCacheOption(argument)) {
            cache = false;
        } else if (isOutputOption(argument)) {
            if (output_path != null) return failure(CompileResult, .duplicate_output, argument);
            index += 1;
            if (index >= args.len) return failure(CompileResult, .missing_output, argument);
            output_path = args[index];
        } else if (std.mem.startsWith(u8, argument, "-")) {
            return failure(CompileResult, .unknown_option, argument);
        } else if (source_path != null) {
            return failure(CompileResult, .multiple_sources, argument);
        } else {
            source_path = argument;
        }
    }

    return .{ .options = .{
        .source_path = source_path orelse return failure(CompileResult, .missing_source, null),
        .output_path = output_path orelse return failure(CompileResult, .missing_output, null),
        .mode = mode,
        .cache = cache,
    } };
}

fn failure(comptime Result: type, kind: Diagnostic.Kind, argument: ?[]const u8) Result {
    return .{ .diagnostic = .{ .kind = kind, .argument = argument } };
}

fn modeFor(argument: []const u8) ?Mode {
    if (std.mem.eql(u8, argument, "-d") or std.mem.eql(u8, argument, "--debug")) return .debug;
    if (std.mem.eql(u8, argument, "-r") or std.mem.eql(u8, argument, "--release")) return .release;
    return null;
}

fn isOutputOption(argument: []const u8) bool {
    return std.mem.eql(u8, argument, "-o") or std.mem.eql(u8, argument, "--output");
}

fn isNativeOption(argument: []const u8) bool {
    return modeFor(argument) != null or isOutputOption(argument);
}

fn isNoCacheOption(argument: []const u8) bool {
    return std.mem.eql(u8, argument, "-n") or std.mem.eql(u8, argument, "--nocache");
}

test "compile accepts short and long aliases in any order" {
    const short = parseCompile(&.{ "Main.sx", "-r", "-o", "Application" }).options;
    try std.testing.expectEqualStrings("Main.sx", short.source_path);
    try std.testing.expectEqualStrings("Application", short.output_path);
    try std.testing.expectEqual(Mode.release, short.mode);

    const long = parseCompile(&.{ "--output", "Application", "--debug", "Main.sx" }).options;
    try std.testing.expectEqualStrings("Main.sx", long.source_path);
    try std.testing.expectEqualStrings("Application", long.output_path);
    try std.testing.expectEqual(Mode.debug, long.mode);
}

test "compile defaults to debug and accepts a repeated identical mode" {
    try std.testing.expectEqual(Mode.debug, parseCompile(&.{ "Main.sx", "-o", "Application" }).options.mode);
    try std.testing.expectEqual(
        Mode.release,
        parseCompile(&.{ "-r", "Main.sx", "--release", "--output", "Application" }).options.mode,
    );
}

test "compile rejects conflicting modes and grouped short options" {
    try expectDiagnostic(parseCompile(&.{ "Main.sx", "-d", "-r", "-o", "Application" }), .conflicting_modes, "-r");
    try expectDiagnostic(parseCompile(&.{ "Main.sx", "-dr", "-o", "Application" }), .unknown_option, "-dr");
}

test "compile diagnoses missing duplicate and unexpected arguments" {
    try expectDiagnostic(parseCompile(&.{ "-r", "-o", "Application" }), .missing_source, null);
    try expectDiagnostic(parseCompile(&.{"Main.sx"}), .missing_output, null);
    try expectDiagnostic(parseCompile(&.{ "Main.sx", "-o" }), .missing_output, "-o");
    try expectDiagnostic(parseCompile(&.{ "Main.sx", "-o", "A", "--output", "B" }), .duplicate_output, "--output");
    try expectDiagnostic(parseCompile(&.{ "Main.sx", "Other.sx", "-o", "A" }), .multiple_sources, "Other.sx");
}

test "run accepts emit ir but rejects native compilation options" {
    const options = parseRun(&.{ "--emit-ir", "Main.sx" }).options;
    try std.testing.expect(options.emit_ir);
    try std.testing.expectEqualStrings("Main.sx", options.source_path);
    try expectRunDiagnostic(parseRun(&.{ "Main.sx", "--release" }), .option_unavailable, "--release");
    try expectRunDiagnostic(parseRun(&.{ "Main.sx", "--output", "Application" }), .option_unavailable, "--output");
}

test "run and compile accept nocache aliases but reject grouped short forms" {
    try std.testing.expect(!parseRun(&.{ "Main.sx", "-n" }).options.cache);
    try std.testing.expect(!parseRun(&.{ "--nocache", "Main.sx" }).options.cache);
    try std.testing.expect(!parseCompile(&.{ "Main.sx", "-n", "-o", "App" }).options.cache);
    try expectRunDiagnostic(parseRun(&.{ "Main.sx", "-nc" }), .unknown_option, "-nc");
}

fn expectDiagnostic(result: CompileResult, kind: Diagnostic.Kind, argument: ?[]const u8) !void {
    const diagnostic = result.diagnostic;
    try std.testing.expectEqual(kind, diagnostic.kind);
    if (argument) |expected| try std.testing.expectEqualStrings(expected, diagnostic.argument.?);
}

fn expectRunDiagnostic(result: RunResult, kind: Diagnostic.Kind, argument: ?[]const u8) !void {
    const diagnostic = result.diagnostic;
    try std.testing.expectEqual(kind, diagnostic.kind);
    if (argument) |expected| try std.testing.expectEqualStrings(expected, diagnostic.argument.?);
}
