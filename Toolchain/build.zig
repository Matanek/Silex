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

    const run_step = b.step("run", "Run the Silex toolchain");
    run_step.dependOn(&run_command.step);

    const tests = b.addTest(.{
        .root_module = module,
    });
    const test_command = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run the toolchain tests");
    test_step.dependOn(&test_command.step);

    const smoke_command = b.addRunArtifact(executable);
    smoke_command.addArgs(&.{ "run", "Smokes/Main.sx" });

    const smoke_step = b.step("smoke", "Compile and run the smoke program");
    smoke_step.dependOn(&smoke_command.step);
}
