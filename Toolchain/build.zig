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
    // These Mach-O payloads are embedded by both ARM64 backends. Keep their
    // instructions and ABI inside the common macOS/Windows baseline.
    const runtime_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .macos,
        .cpu_model = .baseline,
        .cpu_features_add = std.Target.aarch64.featureSet(&.{.reserve_x18}),
        .cpu_features_sub = std.Target.aarch64.featureSet(&.{
            .lse,
            .lse128,
            .lse2,
            .outline_atomics,
            .rcpc,
            .rcpc3,
            .rcpc_immo,
        }),
    });
    const runtime_linux_arm64_target = b.resolveTargetQuery(.{
        .cpu_arch = .aarch64,
        .os_tag = .linux,
    });
    const float_runtime_module = b.createModule(.{
        .root_source_file = b.path("Runtime/FloatFormat.zig"),
        .target = runtime_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
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
    const float_runtime_linux_arm64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/FloatFormat.zig"),
        .target = runtime_linux_arm64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
        .strip = true,
        .unwind_tables = .none,
    });
    const float_runtime_linux_arm64 = b.addExecutable(.{
        .name = "silex-float-runtime-linux-arm64",
        .root_module = float_runtime_linux_arm64_module,
    });
    float_runtime_linux_arm64.entry = .{ .symbol_name = "silex_format_float" };
    const float_runtime_linux_arm64_files = b.addWriteFiles();
    _ = float_runtime_linux_arm64_files.addCopyFile(float_runtime_linux_arm64.getEmittedBin(), "silex-float-runtime-linux-arm64.elf");
    const float_runtime_linux_arm64_import = float_runtime_linux_arm64_files.add(
        "FloatRuntimeLinuxArm64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-float-runtime-linux-arm64.elf\");\n",
    );
    module.addAnonymousImport("float_runtime_linux_arm64_object", .{ .root_source_file = float_runtime_linux_arm64_import });
    const float_runtime_x64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
    });
    const float_runtime_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/FloatFormat.zig"),
        .target = float_runtime_x64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
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
    const runtime_macos_x64_target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .macos,
    });
    const float_runtime_macos_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/FloatFormat.zig"),
        .target = runtime_macos_x64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
    });
    const float_runtime_macos_x64 = b.addExecutable(.{
        .name = "silex-float-runtime-macos-x64",
        .root_module = float_runtime_macos_x64_module,
    });
    float_runtime_macos_x64.entry = .{ .symbol_name = "_silex_format_float" };
    const float_runtime_macos_x64_files = b.addWriteFiles();
    _ = float_runtime_macos_x64_files.addCopyFile(float_runtime_macos_x64.getEmittedBin(), "silex-float-runtime-macos-x64.macho");
    const float_runtime_macos_x64_import = float_runtime_macos_x64_files.add(
        "FloatRuntimeMacOSX64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-float-runtime-macos-x64.macho\");\n",
    );
    module.addAnonymousImport("float_runtime_macos_x64_object", .{ .root_source_file = float_runtime_macos_x64_import });
    const deep_copy_runtime_module = b.createModule(.{
        .root_source_file = b.path("Runtime/DeepCopy.zig"),
        .target = runtime_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
    });
    const deep_copy_runtime = b.addExecutable(.{
        .name = "silex-deep-copy-runtime",
        .root_module = deep_copy_runtime_module,
    });
    deep_copy_runtime.entry = .{ .symbol_name = "_silex_deep_copy_arm64" };
    const deep_copy_runtime_files = b.addWriteFiles();
    _ = deep_copy_runtime_files.addCopyFile(deep_copy_runtime.getEmittedBin(), "silex-deep-copy-runtime.macho");
    const deep_copy_runtime_import = deep_copy_runtime_files.add(
        "DeepCopyRuntimeObject.zig",
        "pub const object_bytes = @embedFile(\"silex-deep-copy-runtime.macho\");\n",
    );
    module.addAnonymousImport("deep_copy_runtime_object", .{ .root_source_file = deep_copy_runtime_import });
    const deep_copy_runtime_linux_arm64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/DeepCopy.zig"),
        .target = runtime_linux_arm64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
        .strip = true,
        .unwind_tables = .none,
    });
    const deep_copy_runtime_linux_arm64 = b.addExecutable(.{
        .name = "silex-deep-copy-runtime-linux-arm64",
        .root_module = deep_copy_runtime_linux_arm64_module,
    });
    deep_copy_runtime_linux_arm64.entry = .{ .symbol_name = "silex_deep_copy_with_allocator" };
    const deep_copy_runtime_linux_arm64_files = b.addWriteFiles();
    _ = deep_copy_runtime_linux_arm64_files.addCopyFile(deep_copy_runtime_linux_arm64.getEmittedBin(), "silex-deep-copy-runtime-linux-arm64.elf");
    const deep_copy_runtime_linux_arm64_import = deep_copy_runtime_linux_arm64_files.add(
        "DeepCopyRuntimeLinuxArm64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-deep-copy-runtime-linux-arm64.elf\");\n",
    );
    module.addAnonymousImport("deep_copy_runtime_linux_arm64_object", .{ .root_source_file = deep_copy_runtime_linux_arm64_import });
    const deep_copy_runtime_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/DeepCopy.zig"),
        .target = float_runtime_x64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
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
    const deep_copy_runtime_macos_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/DeepCopy.zig"),
        .target = runtime_macos_x64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
    });
    const deep_copy_runtime_macos_x64 = b.addExecutable(.{
        .name = "silex-deep-copy-runtime-macos-x64",
        .root_module = deep_copy_runtime_macos_x64_module,
    });
    deep_copy_runtime_macos_x64.entry = .{ .symbol_name = "_silex_deep_copy_x64" };
    const deep_copy_runtime_macos_x64_files = b.addWriteFiles();
    _ = deep_copy_runtime_macos_x64_files.addCopyFile(deep_copy_runtime_macos_x64.getEmittedBin(), "silex-deep-copy-runtime-macos-x64.macho");
    const deep_copy_runtime_macos_x64_import = deep_copy_runtime_macos_x64_files.add(
        "DeepCopyRuntimeMacOSX64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-deep-copy-runtime-macos-x64.macho\");\n",
    );
    module.addAnonymousImport("deep_copy_runtime_macos_x64_object", .{ .root_source_file = deep_copy_runtime_macos_x64_import });
    const cycle_runtime_module = b.createModule(.{
        .root_source_file = b.path("Runtime/CycleCollector.zig"),
        .target = runtime_target,
        .optimize = .ReleaseSmall,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
    });
    const cycle_runtime = b.addExecutable(.{
        .name = "silex-cycle-runtime",
        .root_module = cycle_runtime_module,
    });
    cycle_runtime.entry = .{ .symbol_name = "_silex_cycle_arm64" };
    const cycle_runtime_files = b.addWriteFiles();
    _ = cycle_runtime_files.addCopyFile(cycle_runtime.getEmittedBin(), "silex-cycle-runtime.macho");
    const cycle_runtime_import = cycle_runtime_files.add(
        "CycleRuntimeObject.zig",
        "pub const object_bytes = @embedFile(\"silex-cycle-runtime.macho\");\n",
    );
    module.addAnonymousImport("cycle_runtime_object", .{ .root_source_file = cycle_runtime_import });
    const cycle_runtime_linux_arm64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/CycleCollector.zig"),
        .target = runtime_linux_arm64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
        .strip = true,
        .unwind_tables = .none,
    });
    const cycle_runtime_linux_arm64 = b.addExecutable(.{
        .name = "silex-cycle-runtime-linux-arm64",
        .root_module = cycle_runtime_linux_arm64_module,
    });
    cycle_runtime_linux_arm64.entry = .{ .symbol_name = "silex_cycle" };
    const cycle_runtime_linux_arm64_files = b.addWriteFiles();
    _ = cycle_runtime_linux_arm64_files.addCopyFile(cycle_runtime_linux_arm64.getEmittedBin(), "silex-cycle-runtime-linux-arm64.elf");
    const cycle_runtime_linux_arm64_import = cycle_runtime_linux_arm64_files.add(
        "CycleRuntimeLinuxArm64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-cycle-runtime-linux-arm64.elf\");\n",
    );
    module.addAnonymousImport("cycle_runtime_linux_arm64_object", .{ .root_source_file = cycle_runtime_linux_arm64_import });
    const cycle_runtime_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/CycleCollector.zig"),
        .target = float_runtime_x64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
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
    const cycle_runtime_macos_x64_module = b.createModule(.{
        .root_source_file = b.path("Runtime/CycleCollector.zig"),
        .target = runtime_macos_x64_target,
        .optimize = .ReleaseSmall,
        .pic = true,
        .strip = true,
        .unwind_tables = .none,
        .red_zone = false,
    });
    const cycle_runtime_macos_x64 = b.addExecutable(.{
        .name = "silex-cycle-runtime-macos-x64",
        .root_module = cycle_runtime_macos_x64_module,
    });
    cycle_runtime_macos_x64.entry = .{ .symbol_name = "_silex_cycle_x64" };
    const cycle_runtime_macos_x64_files = b.addWriteFiles();
    _ = cycle_runtime_macos_x64_files.addCopyFile(cycle_runtime_macos_x64.getEmittedBin(), "silex-cycle-runtime-macos-x64.macho");
    const cycle_runtime_macos_x64_import = cycle_runtime_macos_x64_files.add(
        "CycleRuntimeMacOSX64Object.zig",
        "pub const object_bytes = @embedFile(\"silex-cycle-runtime-macos-x64.macho\");\n",
    );
    module.addAnonymousImport("cycle_runtime_macos_x64_object", .{ .root_source_file = cycle_runtime_macos_x64_import });
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
    const optimizer_api_module = b.createModule(.{
        .root_source_file = b.path("Sources/OptimizerOracleApi.zig"),
        .target = target,
        .optimize = optimize,
    });
    optimizer_api_module.addOptions("build_options", build_options);
    optimizer_oracle_module.addImport("silex_optimizer_api", optimizer_api_module);
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

    const optimizer_admission_command = b.addRunArtifact(optimizer_oracle);
    optimizer_admission_command.addArtifactArg(executable);
    optimizer_admission_command.addDirectoryArg(b.path("Benchmarks/Optimizer"));
    if (b.args) |args| optimizer_admission_command.addArgs(args);
    const optimizer_admission_step = b.step(
        "optimizer-admission",
        "Audit or classify changes with the permanent optimizer admission matrix",
    );
    optimizer_admission_step.dependOn(&optimizer_oracle_test_command.step);
    optimizer_admission_step.dependOn(&optimizer_admission_command.step);

    const optimizer_admission_quick_command = b.addRunArtifact(optimizer_oracle);
    optimizer_admission_quick_command.addArtifactArg(executable);
    optimizer_admission_quick_command.addDirectoryArg(b.path("Benchmarks/Optimizer"));
    optimizer_admission_quick_command.addArg("admission-quick");
    const optimizer_admission_quick_step = b.step(
        "optimizer-admission-quick",
        "Run the autonomous per-commit optimizer correctness and structure gate",
    );
    optimizer_admission_quick_step.dependOn(&optimizer_oracle_test_command.step);
    optimizer_admission_quick_step.dependOn(&optimizer_admission_quick_command.step);

    const optimizer_parity_gate_command = b.addRunArtifact(optimizer_oracle);
    optimizer_parity_gate_command.addArtifactArg(executable);
    optimizer_parity_gate_command.addDirectoryArg(b.path("Benchmarks/Optimizer"));
    optimizer_parity_gate_command.addArg("parity-gate");
    const optimizer_parity_gate_step = b.step(
        "optimizer-parity-gate",
        "Run the blocking optimizer parity closure and qualified comparison",
    );
    optimizer_parity_gate_step.dependOn(&optimizer_oracle_test_command.step);
    optimizer_parity_gate_step.dependOn(&optimizer_parity_gate_command.step);

    const optimizer_robustness_quick_command = b.addRunArtifact(optimizer_oracle);
    optimizer_robustness_quick_command.addArtifactArg(executable);
    optimizer_robustness_quick_command.addDirectoryArg(b.path("Benchmarks/Optimizer"));
    optimizer_robustness_quick_command.addArg("robustness-quick");
    const optimizer_robustness_quick_step = b.step(
        "optimizer-robustness-quick",
        "Run deterministic pairwise, triplet, negative, and sampled native robustness cases",
    );
    optimizer_robustness_quick_step.dependOn(&optimizer_oracle_test_command.step);
    optimizer_robustness_quick_step.dependOn(&optimizer_robustness_quick_command.step);

    const optimizer_robustness_qualified_command = b.addRunArtifact(optimizer_oracle);
    optimizer_robustness_qualified_command.addArtifactArg(executable);
    optimizer_robustness_qualified_command.addDirectoryArg(b.path("Benchmarks/Optimizer"));
    optimizer_robustness_qualified_command.addArg("robustness-qualified");
    const optimizer_robustness_qualified_step = b.step(
        "optimizer-robustness-qualified",
        "Run the qualified adversarial optimizer robustness campaign",
    );
    optimizer_robustness_qualified_step.dependOn(&optimizer_oracle_test_command.step);
    optimizer_robustness_qualified_step.dependOn(&optimizer_robustness_qualified_command.step);

    const optimizer_robustness_soak_command = b.addRunArtifact(optimizer_oracle);
    optimizer_robustness_soak_command.addArtifactArg(executable);
    optimizer_robustness_soak_command.addDirectoryArg(b.path("Benchmarks/Optimizer"));
    optimizer_robustness_soak_command.addArg("robustness-soak");
    const optimizer_robustness_soak_step = b.step(
        "optimizer-robustness-soak",
        "Repeat the adversarial optimizer plan across deterministic seed windows",
    );
    optimizer_robustness_soak_step.dependOn(&optimizer_oracle_test_command.step);
    optimizer_robustness_soak_step.dependOn(&optimizer_robustness_soak_command.step);

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
    // Toolchain-owned language tests are hermetic: a user's live package links
    // must not extend their package graph or make the same commit nondeterministic.
    language_test_command.setEnvironmentVariable("SILEX_USER_PACKAGE_ALLOWLIST", "STD");
    language_test_command.setCwd(b.path("../.."));
    language_test_command.addArg("test");
    language_test_command.addDirectoryArg(b.path("../Tests"));
    // Language validation shares the Spec/workspace-root package graph and
    // must not create a second project cache under Silex/Toolchain.
    language_test_command.addArg("--nocache");
    const language_test_step = b.step("test-language", "Run executable Silex language tests");
    language_test_step.dependOn(&language_test_command.step);

    const test_step = b.step("test", "Run compiler and Silex language tests");
    test_step.dependOn(&test_command.step);
    test_step.dependOn(&deep_copy_test_command.step);
    test_step.dependOn(&cycle_test_command.step);
    test_step.dependOn(&language_test_command.step);

    var native_math_validation: ?*std.Build.Step = null;
    if (target.result.os.tag == .macos and target.result.cpu.arch == .aarch64 and
        b.graph.host.result.os.tag == .macos and b.graph.host.result.cpu.arch == .aarch64)
    {
        // This fixture needs the real Mach-O import linker; Runner.invoke
        // intentionally executes images without resolving external call sites.
        const native_math_debug = b.addRunArtifact(executable);
        native_math_debug.setEnvironmentVariable("SILEX_USER_PACKAGE_ALLOWLIST", "STD");
        native_math_debug.setCwd(b.path("../.."));
        native_math_debug.addArg("run");
        native_math_debug.addFileArg(b.path("Benchmarks/Native/MathCallResidence.sx"));
        native_math_debug.addArgs(&.{ "--debug", "--nocache" });
        const native_math_release = b.addRunArtifact(executable);
        native_math_release.setEnvironmentVariable("SILEX_USER_PACKAGE_ALLOWLIST", "STD");
        native_math_release.setCwd(b.path("../.."));
        native_math_release.addArg("run");
        native_math_release.addFileArg(b.path("Benchmarks/Native/MathCallResidence.sx"));
        native_math_release.addArgs(&.{ "--release", "--nocache" });
        native_math_release.step.dependOn(&native_math_debug.step);
        const native_math_step = b.step("test-native-math-calls", "Verify linked ARM64 math calls in Debug and Release");
        native_math_step.dependOn(&native_math_release.step);
        native_math_validation = &native_math_release.step;
        test_step.dependOn(&native_math_release.step);
    }

    const lsp_test_module = b.createModule(.{
        .root_source_file = b.path("Sources/LspTests.zig"),
        .target = target,
        .optimize = optimize,
    });
    lsp_test_module.addOptions("build_options", build_options);

    const lsp_admission_module = b.createModule(.{
        .root_source_file = b.path("Sources/LspAdmissionTests.zig"),
        .target = target,
        .optimize = optimize,
    });
    lsp_admission_module.addOptions("build_options", build_options);
    const lsp_admission_tests = b.addTest(.{ .root_module = lsp_admission_module });
    const lsp_admission_command = b.addRunArtifact(lsp_admission_tests);
    // Default builds must reject structural or clean-matrix completion gaps.
    // The heavier deterministic mutation campaign remains in LspTests and is
    // therefore mandatory in the ordinary `check`/`silex-dev test` portal.
    b.getInstallStep().dependOn(&lsp_admission_command.step);

    const lsp_tests = b.addTest(.{ .root_module = lsp_test_module });
    const lsp_test_command = b.addRunArtifact(lsp_tests);
    const lsp_test_step = b.step("test-lsp", "Run the language-server contract tests");
    lsp_test_step.dependOn(&lsp_test_command.step);
    const lsp_completion_gate_step = b.step(
        "check-lsp-completion",
        "Run the autonomous exhaustive completion admission gate",
    );
    lsp_completion_gate_step.dependOn(&lsp_test_command.step);

    const lsp_completion_audit_module = b.createModule(.{
        .root_source_file = b.path("Tools/LspCompletionAudit/Main.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    const lsp_audit_api_module = b.createModule(.{
        .root_source_file = b.path("Sources/LspAuditApi.zig"),
    });
    lsp_audit_api_module.addOptions("build_options", build_options);
    lsp_completion_audit_module.addImport("silex_lsp_audit", lsp_audit_api_module);
    const lsp_completion_audit = b.addExecutable(.{
        .name = "silex-lsp-completion-audit",
        .root_module = lsp_completion_audit_module,
    });
    const lsp_completion_audit_command = b.addRunArtifact(lsp_completion_audit);
    if (b.args) |args| lsp_completion_audit_command.addArgs(args);
    const lsp_completion_audit_step = b.step(
        "audit-lsp-completion",
        "Qualify the completion corpus in a Silex workspace",
    );
    lsp_completion_audit_step.dependOn(&lsp_completion_audit_command.step);

    const lsp_completion_benchmark_module = b.createModule(.{
        .root_source_file = b.path("Tools/LspCompletionBenchmark/Main.zig"),
        .target = target,
        .optimize = .ReleaseSafe,
    });
    lsp_completion_benchmark_module.addOptions("build_options", build_options);
    const lsp_benchmark_api_module = b.createModule(.{
        .root_source_file = b.path("Sources/LspBenchmarkApi.zig"),
    });
    lsp_benchmark_api_module.addOptions("build_options", build_options);
    lsp_completion_benchmark_module.addImport("silex_lsp", lsp_benchmark_api_module);
    const lsp_completion_benchmark = b.addExecutable(.{
        .name = "silex-lsp-completion-benchmark",
        .root_module = lsp_completion_benchmark_module,
    });
    const lsp_completion_benchmark_command = b.addRunArtifact(lsp_completion_benchmark);
    lsp_completion_benchmark_command.addDirectoryArg(b.path("Benchmarks/LspCompletion/Fixture"));
    if (b.args) |args| lsp_completion_benchmark_command.addArgs(args);
    const lsp_completion_benchmark_step = b.step(
        "benchmark-lsp-completion",
        "Measure fresh, warm, and edited-overlay completion requests",
    );
    lsp_completion_benchmark_step.dependOn(&lsp_completion_benchmark_command.step);

    const check_step = b.step("check", "Build and test the toolchain");
    // Validation must never replace the compiler used by `silex` or Zed.
    // The language-test command already builds this executable in the
    // requested mode without installing it into zig-out/bin.
    check_step.dependOn(&test_command.step);
    check_step.dependOn(&deep_copy_test_command.step);
    check_step.dependOn(&cycle_test_command.step);
    check_step.dependOn(&language_test_command.step);
    check_step.dependOn(lsp_completion_gate_step);
    check_step.dependOn(optimizer_admission_quick_step);
    if (native_math_validation) |validation| check_step.dependOn(validation);
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
