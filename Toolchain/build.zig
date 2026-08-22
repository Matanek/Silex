const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize: std.builtin.OptimizeMode = b.option(
        std.builtin.OptimizeMode,
        "optimize",
        "Prioritize performance, safety, or binary size",
    ) orelse switch (b.release_mode) {
        .fast => .ReleaseFast,
        .safe => .ReleaseSafe,
        .small => .ReleaseSmall,
        .off, .any => .ReleaseFast,
    };

    const package_version = manifestVersion();
    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", package_version);

    const module = b.createModule(.{
        .root_source_file = b.path("Sources/Main.zig"),
        .target = target,
        .optimize = optimize,
    });
    module.addOptions("build_options", build_options);
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
    const float_runtime_x64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    });
    const float_runtime_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/FloatFormat.zig"),
        .target = float_runtime_x64_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
    });
    const float_runtime_x64 = b.addExecutable(.{
        .name = "silex-float-runtime-x64",
        .root_module = float_runtime_x64_module,
    });
    float_runtime_x64.entry = .{ .symbol_name = "silex_format_float" };
    const runtime_x64_files = b.addWriteFiles();
    _ = runtime_x64_files.addCopyFile(float_runtime_x64.getEmittedBin(), "silex-float-runtime-x64.elf");
    const runtime_x64_module = runtime_x64_files.add(
        "FloatRuntimeX64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-float-runtime-x64.elf\");\n",
    );
    module.addAnonymousImport("float_runtime_x64_object", .{ .root_source_file = runtime_x64_module });
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
    const deep_copy_runtime_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/DeepCopy.zig"),
        .target = float_runtime_x64_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
    });
    const deep_copy_runtime_x64 = b.addExecutable(.{
        .name = "silex-deep-copy-runtime-x64",
        .root_module = deep_copy_runtime_x64_module,
    });
    deep_copy_runtime_x64.entry = .{ .symbol_name = "silex_deep_copy_x64" };
    const deep_copy_runtime_x64_files = b.addWriteFiles();
    _ = deep_copy_runtime_x64_files.addCopyFile(deep_copy_runtime_x64.getEmittedBin(), "silex-deep-copy-runtime-x64.elf");
    const deep_copy_runtime_x64_import = deep_copy_runtime_x64_files.add(
        "DeepCopyRuntimeX64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-deep-copy-runtime-x64.elf\");\n",
    );
    module.addAnonymousImport("deep_copy_runtime_x64_object", .{ .root_source_file = deep_copy_runtime_x64_import });
    const cycle_runtime_module = b.createModule(.{
        .root_source_file = b.path("Runtime/CycleCollector.zig"),
        .target = runtime_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
    });
    const cycle_runtime = b.addExecutable(.{
        .name = "silex-cycle-runtime",
        .root_module = cycle_runtime_module,
    });
    cycle_runtime.entry = .{ .symbol_name = "_silex_cycle" };
    const cycle_runtime_files = b.addWriteFiles();
    _ = cycle_runtime_files.addCopyFile(cycle_runtime.getEmittedBin(), "silex-cycle-runtime.macho");
    const cycle_runtime_import = cycle_runtime_files.add(
        "CycleRuntimeObject.zig",
        "pub const object_bytes = @embedFile(\"silex-cycle-runtime.macho\");\n",
    );
    module.addAnonymousImport("cycle_runtime_object", .{ .root_source_file = cycle_runtime_import });
    const cycle_runtime_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/CycleCollector.zig"),
        .target = float_runtime_x64_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
    });
    const cycle_runtime_x64 = b.addExecutable(.{
        .name = "silex-cycle-runtime-x64",
        .root_module = cycle_runtime_x64_module,
    });
    cycle_runtime_x64.entry = .{ .symbol_name = "silex_cycle_x64" };
    const cycle_runtime_x64_files = b.addWriteFiles();
    _ = cycle_runtime_x64_files.addCopyFile(cycle_runtime_x64.getEmittedBin(), "silex-cycle-runtime-x64.elf");
    const cycle_runtime_x64_import = cycle_runtime_x64_files.add(
        "CycleRuntimeX64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-cycle-runtime-x64.elf\");\n",
    );
    module.addAnonymousImport("cycle_runtime_x64_object", .{ .root_source_file = cycle_runtime_x64_import });
    const executable = b.addExecutable(.{
        .name = "silex",
        .root_module = module,
        .version = std.SemanticVersion.parse(package_version) catch unreachable,
    });
    b.installArtifact(executable);

    const run_command = b.addRunArtifact(executable);
    run_command.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_command.addArgs(args);
    const run_step = b.step("run", "Interpret a Silex source file");
    run_step.dependOn(&run_command.step);

    const benchmark_command = b.addSystemCommand(&.{"sh"});
    benchmark_command.addFileArg(b.path("Benchmarks/Native/run.sh"));
    benchmark_command.addArtifactArg(executable);
    benchmark_command.addDirectoryArg(b.path("Benchmarks/Native"));
    const benchmark_step = b.step("benchmark-native", "Compare Debug and Release native code with clang++ -O2");
    benchmark_step.dependOn(&benchmark_command.step);

    const optimizer_oracle_module = b.createModule(.{
        .root_source_file = b.path("Tools/OptimizerOracle/Main.zig"),
        .target = target,
        .optimize = optimize,
    });
    optimizer_oracle_module.addAnonymousImport("silex_optimizer_api", .{
        .root_source_file = b.path("Sources/OptimizerOracleApi.zig"),
    });
    const optimizer_oracle = b.addExecutable(.{
        .name = "silex-optimizer-oracle",
        .root_module = optimizer_oracle_module,
    });
    const optimizer_oracle_command = b.addRunArtifact(optimizer_oracle);
    optimizer_oracle_command.addArtifactArg(executable);
    optimizer_oracle_command.addDirectoryArg(b.path("Benchmarks/Optimizer"));
    if (b.args) |args| optimizer_oracle_command.addArgs(args);
    const optimizer_oracle_step = b.step(
        "optimizer-oracle",
        "Verify, fuzz, or compare Silex optimization with LLVM",
    );
    optimizer_oracle_step.dependOn(&optimizer_oracle_command.step);

    const optimizer_gate_command = b.addRunArtifact(optimizer_oracle);
    optimizer_gate_command.addArtifactArg(executable);
    optimizer_gate_command.addDirectoryArg(b.path("Benchmarks/Optimizer"));
    optimizer_gate_command.addArg("gate");
    const optimizer_gate_step = b.step(
        "optimizer-gate",
        "Run the complete semantic, native, LLVM, and benchmark optimizer gate",
    );
    optimizer_gate_step.dependOn(&optimizer_gate_command.step);

    const optimizer_oracle_tests = b.addTest(.{ .root_module = optimizer_oracle_module });
    const optimizer_oracle_test_command = b.addRunArtifact(optimizer_oracle_tests);
    const optimizer_oracle_test_step = b.step(
        "test-optimizer-oracle",
        "Run optimizer-oracle unit and differential tests",
    );
    optimizer_oracle_test_step.dependOn(&optimizer_oracle_test_command.step);
    optimizer_gate_step.dependOn(&optimizer_oracle_test_command.step);

    const tests = b.addTest(.{ .root_module = module });
    const test_command = b.addRunArtifact(tests);
    const deep_copy_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("Runtime/DeepCopy.zig"),
            .target = runtime_target,
            .optimize = .Debug,
        }),
    });
    const deep_copy_test_command = b.addRunArtifact(deep_copy_tests);
    const cycle_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("Runtime/CycleCollector.zig"),
            .target = runtime_target,
            .optimize = .Debug,
        }),
    });
    const cycle_test_command = b.addRunArtifact(cycle_tests);
    const language_test_command = b.addRunArtifact(executable);
    language_test_command.addArg("test");
    language_test_command.addDirectoryArg(b.path("../Tests"));
    const language_test_step = b.step("test-language", "Run executable Silex language tests");
    language_test_step.dependOn(&language_test_command.step);

    const test_step = b.step("test", "Run compiler and Silex language tests");
    test_step.dependOn(&test_command.step);
    test_step.dependOn(&deep_copy_test_command.step);
    test_step.dependOn(&cycle_test_command.step);
    test_step.dependOn(&language_test_command.step);

    const lsp_test_module = b.createModule(.{
        .root_source_file = b.path("Sources/LspTests.zig"),
        .target = target,
        .optimize = optimize,
    });
    lsp_test_module.addOptions("build_options", build_options);
    const lsp_tests = b.addTest(.{ .root_module = lsp_test_module });
    const lsp_test_command = b.addRunArtifact(lsp_tests);
    const lsp_test_step = b.step("test-lsp", "Run the language-server contract tests");
    lsp_test_step.dependOn(&lsp_test_command.step);

    const check_step = b.step("check", "Build and test the toolchain");
    // Validation must never replace the compiler used by `silex` or Zed.
    // The language-test command already builds this executable in the
    // requested mode without installing it into zig-out/bin.
    check_step.dependOn(&test_command.step);
    check_step.dependOn(&deep_copy_test_command.step);
    check_step.dependOn(&cycle_test_command.step);
    check_step.dependOn(&language_test_command.step);
    check_step.dependOn(&lsp_test_command.step);
    check_step.dependOn(&optimizer_oracle_test_command.step);
}

fn manifestVersion() []const u8 {
    const manifest = @embedFile("build.zig.zon");
    const prefix = ".version = \"";
    const start = (std.mem.indexOf(u8, manifest, prefix) orelse
        @panic("build.zig.zon must declare .version")) + prefix.len;
    const end = std.mem.indexOfScalarPos(u8, manifest, start, '"') orelse
        @panic("build.zig.zon contains an invalid .version");
    return manifest[start..end];
}
