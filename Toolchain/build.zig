const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module = b.createModule(.{
        .root_source_file = b.path("Sources/Main.zig"),
        .target = target,
        .optimize = optimize,
    });
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
