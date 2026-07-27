const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .root_source_file = b.path("Sources/Main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const runtime_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
    });
    const float_runtime_module = b.createModule(.{
        .root_source_file = b.path("Runtime/FloatFormat.zig"),
        .target = runtime_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
    });
    const float_runtime = b.addExecutable(.{
        .name = "silex-float-runtime",
        .root_module = float_runtime_module,
    });
    float_runtime.entry = .{ .symbol_name = "_silex_format_float" };
    const runtime_files = b.addWriteFiles();
    _ = runtime_files.addCopyFile(float_runtime.getEmittedBin(), "silex-float-runtime.macho");
    const runtime_module = runtime_files.add(
        "FloatRuntimeObject.zig",
        "pub const object_bytes = @embedFile(\"silex-float-runtime.macho\");\n",
    );
    module.addAnonymousImport("float_runtime_object", .{ .root_source_file = runtime_module });
    const deep_copy_runtime_module = b.createModule(.{
        .root_source_file = b.path("Runtime/DeepCopy.zig"),
        .target = runtime_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
    });
    const deep_copy_runtime = b.addExecutable(.{
        .name = "silex-deep-copy-runtime",
        .root_module = deep_copy_runtime_module,
    });
    deep_copy_runtime.entry = .{ .symbol_name = "_silex_deep_copy" };
    const deep_copy_runtime_files = b.addWriteFiles();
    _ = deep_copy_runtime_files.addCopyFile(deep_copy_runtime.getEmittedBin(), "silex-deep-copy-runtime.macho");
    const deep_copy_runtime_import = deep_copy_runtime_files.add(
        "DeepCopyRuntimeObject.zig",
        "pub const object_bytes = @embedFile(\"silex-deep-copy-runtime.macho\");\n",
    );
    module.addAnonymousImport("deep_copy_runtime_object", .{ .root_source_file = deep_copy_runtime_import });
    const executable = b.addExecutable(.{
        .name = "silex",
        .root_module = module,
    });
    b.installArtifact(executable);

    const run_command = b.addRunArtifact(executable);
    run_command.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_command.addArgs(args);
    const run_step = b.step("run", "Interpret a Silex source file");
    run_step.dependOn(&run_command.step);

    const tests = b.addTest(.{ .root_module = module });
    const test_command = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run compiler tests");
    test_step.dependOn(&test_command.step);

    const check_step = b.step("check", "Build and test the toolchain");
    check_step.dependOn(b.getInstallStep());
    check_step.dependOn(&test_command.step);
}
