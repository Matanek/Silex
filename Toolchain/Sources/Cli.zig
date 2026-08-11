const std = @import("std");
const TargetModule = @import("Target.zig");

pub const Mode = enum { debug, release };

pub const Diagnostic = struct {
    kind: Kind,
    argument: ?[]const u8 = null,

    pub const Kind = enum {
        missing_source,
        multiple_sources,
        missing_package,
        multiple_packages,
        missing_output,
        duplicate_output,
        missing_target,
        duplicate_target,
        unknown_target,
        conflicting_modes,
        option_unavailable,
        unknown_option,
    };
};

pub const RunOptions = struct {
    source_path: []const u8,
    emit_ir: bool,
    mode: Mode,
    cache: bool,
};

pub const InterpretOptions = struct {
    source_path: []const u8,
    emit_ir: bool,
    cache: bool,
};

pub const CompileOptions = struct {
    source_path: []const u8,
    output_path: []const u8,
    mode: Mode,
    cache: bool,
    target: ?TargetModule.Target,
};

pub const InstallOptions = struct {
    package_path: []const u8,
    target: ?TargetModule.Target,
};

pub const PackageOptions = struct {
    package: []const u8,
};

pub const RunResult = union(enum) {
    options: RunOptions,
    diagnostic: Diagnostic,
};

pub const CompileResult = union(enum) {
    options: CompileOptions,
    diagnostic: Diagnostic,
};

pub const InterpretResult = union(enum) {
    options: InterpretOptions,
    diagnostic: Diagnostic,
};

pub const InstallResult = union(enum) {
    options: InstallOptions,
    diagnostic: Diagnostic,
};

pub const PackageResult = union(enum) {
    options: PackageOptions,
    diagnostic: Diagnostic,
};

pub fn parseRun(args: []const []const u8) RunResult {
    var source_path: ?[]const u8 = null;
    var emit_ir = false;
    var mode: Mode = .debug;
    var explicit_mode: ?Mode = null;
    var cache = true;

    for (args) |argument| {
        if (std.mem.eql(u8, argument, "--emit-ir")) {
            emit_ir = true;
        } else if (modeFor(argument)) |selected| {
            if (explicit_mode) |previous| if (previous != selected) {
                return failure(RunResult, .conflicting_modes, argument);
            };
            mode = selected;
            explicit_mode = selected;
        } else if (isNoCacheOption(argument)) {
            cache = false;
        } else if (isOutputOption(argument)) {
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
        .mode = mode,
        .cache = cache,
    } };
}

pub fn parseInterpret(args: []const []const u8) InterpretResult {
    var source_path: ?[]const u8 = null;
    var emit_ir = false;
    var cache = true;

    for (args) |argument| {
        if (std.mem.eql(u8, argument, "--emit-ir")) {
            emit_ir = true;
        } else if (isNoCacheOption(argument)) {
            cache = false;
        } else if (isNativeOption(argument)) {
            return failure(InterpretResult, .option_unavailable, argument);
        } else if (std.mem.startsWith(u8, argument, "-")) {
            return failure(InterpretResult, .unknown_option, argument);
        } else if (source_path != null) {
            return failure(InterpretResult, .multiple_sources, argument);
        } else {
            source_path = argument;
        }
    }

    return .{ .options = .{
        .source_path = source_path orelse return failure(InterpretResult, .missing_source, null),
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
    var target: ?TargetModule.Target = null;
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
        } else if (std.mem.eql(u8, argument, "--target")) {
            if (target != null) return failure(CompileResult, .duplicate_target, argument);
            index += 1;
            if (index >= args.len or std.mem.startsWith(u8, args[index], "-")) {
                return failure(CompileResult, .missing_target, argument);
            }
            target = TargetModule.Target.parse(args[index]) catch
                return failure(CompileResult, .unknown_target, args[index]);
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
        .target = target,
    } };
}

pub fn parseInstall(args: []const []const u8) InstallResult {
    var package_path: ?[]const u8 = null;
    var target: ?TargetModule.Target = null;
    var index: usize = 0;

    while (index < args.len) : (index += 1) {
        const argument = args[index];
        if (std.mem.eql(u8, argument, "--target")) {
            if (target != null) return failure(InstallResult, .duplicate_target, argument);
            index += 1;
            if (index >= args.len or std.mem.startsWith(u8, args[index], "-")) {
                return failure(InstallResult, .missing_target, argument);
            }
            target = TargetModule.Target.parse(args[index]) catch
                return failure(InstallResult, .unknown_target, args[index]);
        } else if (std.mem.startsWith(u8, argument, "-")) {
            return failure(InstallResult, .unknown_option, argument);
        } else if (package_path != null) {
            return failure(InstallResult, .multiple_packages, argument);
        } else {
            package_path = argument;
        }
    }

    return .{ .options = .{
        .package_path = package_path orelse return failure(InstallResult, .missing_package, null),
        .target = target,
    } };
}

pub fn parsePackage(args: []const []const u8) PackageResult {
    var package: ?[]const u8 = null;
    for (args) |argument| {
        if (std.mem.startsWith(u8, argument, "-")) {
            return failure(PackageResult, .unknown_option, argument);
        } else if (package != null) {
            return failure(PackageResult, .multiple_packages, argument);
        } else {
            package = argument;
        }
    }
    return .{ .options = .{
        .package = package orelse return failure(PackageResult, .missing_package, null),
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

test "install accepts one package and an optional target" {
    const local = parseInstall(&.{"Sandbox/GFX"}).options;
    try std.testing.expectEqualStrings("Sandbox/GFX", local.package_path);
    try std.testing.expect(local.target == null);

    const cross = parseInstall(&.{ "--target", "windows-arm64", "Sandbox/GFX" }).options;
    try std.testing.expect(cross.target.?.eql(.windows_arm64));
    try expectInstallDiagnostic(parseInstall(&.{}), .missing_package, null);
    try expectInstallDiagnostic(parseInstall(&.{ "A", "B" }), .multiple_packages, "B");
    try expectInstallDiagnostic(parseInstall(&.{ "A", "--target" }), .missing_target, "--target");
    try expectInstallDiagnostic(parseInstall(&.{ "A", "--target", "other" }), .unknown_target, "other");
}

test "package commands accept exactly one path or name" {
    try std.testing.expectEqualStrings("Packages/STD", parsePackage(&.{"Packages/STD"}).options.package);
    try expectPackageDiagnostic(parsePackage(&.{}), .missing_package, null);
    try expectPackageDiagnostic(parsePackage(&.{ "STD", "GFX" }), .multiple_packages, "GFX");
    try expectPackageDiagnostic(parsePackage(&.{"--force"}), .unknown_option, "--force");
}

test "compile accepts recognized targets and diagnoses invalid selections" {
    const options = parseCompile(&.{ "Main.sx", "--target", "linux-x64", "-o", "Application" }).options;
    try std.testing.expect(options.target.?.eql(.linux_x64));
    try expectDiagnostic(parseCompile(&.{ "Main.sx", "--target", "unknown", "-o", "Application" }), .unknown_target, "unknown");
    try expectDiagnostic(parseCompile(&.{ "Main.sx", "--target", "-o", "Application" }), .missing_target, "--target");
    try expectDiagnostic(parseCompile(&.{ "Main.sx", "--target" }), .missing_target, "--target");
    try expectDiagnostic(
        parseCompile(&.{ "Main.sx", "--target", "macos-arm64", "--target", "linux-x64", "-o", "Application" }),
        .duplicate_target,
        "--target",
    );
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

test "run accepts native modes and emit ir but owns its output" {
    const options = parseRun(&.{ "--emit-ir", "--release", "Main.sx" }).options;
    try std.testing.expect(options.emit_ir);
    try std.testing.expectEqual(Mode.release, options.mode);
    try std.testing.expectEqualStrings("Main.sx", options.source_path);
    try expectRunDiagnostic(parseRun(&.{ "Main.sx", "--output", "Application" }), .option_unavailable, "--output");
    try expectRunDiagnostic(parseRun(&.{ "Main.sx", "--debug", "--release" }), .conflicting_modes, "--release");
}

test "run interpret and compile accept nocache aliases but reject grouped short forms" {
    try std.testing.expect(!parseRun(&.{ "Main.sx", "-n" }).options.cache);
    try std.testing.expect(!parseRun(&.{ "--nocache", "Main.sx" }).options.cache);
    try std.testing.expect(!parseInterpret(&.{ "Main.sx", "-n" }).options.cache);
    try std.testing.expect(!parseCompile(&.{ "Main.sx", "-n", "-o", "App" }).options.cache);
    try expectRunDiagnostic(parseRun(&.{ "Main.sx", "-nc" }), .unknown_option, "-nc");
}

test "interpret retains the explicit reference execution surface" {
    const options = parseInterpret(&.{ "--emit-ir", "Main.sx" }).options;
    try std.testing.expect(options.emit_ir);
    try std.testing.expectEqualStrings("Main.sx", options.source_path);
    try expectInterpretDiagnostic(parseInterpret(&.{ "Main.sx", "--release" }), .option_unavailable, "--release");
    try expectInterpretDiagnostic(parseInterpret(&.{ "Main.sx", "--output", "Application" }), .option_unavailable, "--output");
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

fn expectInterpretDiagnostic(result: InterpretResult, kind: Diagnostic.Kind, argument: ?[]const u8) !void {
    const diagnostic = result.diagnostic;
    try std.testing.expectEqual(kind, diagnostic.kind);
    if (argument) |expected| try std.testing.expectEqualStrings(expected, diagnostic.argument.?);
}

fn expectInstallDiagnostic(result: InstallResult, kind: Diagnostic.Kind, argument: ?[]const u8) !void {
    const diagnostic = result.diagnostic;
    try std.testing.expectEqual(kind, diagnostic.kind);
    if (argument) |expected| try std.testing.expectEqualStrings(expected, diagnostic.argument.?);
}

fn expectPackageDiagnostic(result: PackageResult, kind: Diagnostic.Kind, argument: ?[]const u8) !void {
    const diagnostic = result.diagnostic;
    try std.testing.expectEqual(kind, diagnostic.kind);
    if (argument) |expected| try std.testing.expectEqualStrings(expected, diagnostic.argument.?);
}
