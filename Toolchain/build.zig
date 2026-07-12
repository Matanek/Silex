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

    const invalid_command = b.addRunArtifact(executable);
    invalid_command.addArgs(&.{ "compile", "Tests/InvalidArithmetic.sx" });
    invalid_command.expectExitCode(1);
    invalid_command.expectStdErrEqual(
        "Tests/InvalidArithmetic.sx:2:19: error: arithmetic operator requires 'int' operands, found 'string' and 'int'\n",
    );

    const immutable_assignment_command = b.addRunArtifact(executable);
    immutable_assignment_command.addArgs(&.{ "compile", "Tests/InvalidImmutableAssignment.sx" });
    immutable_assignment_command.expectExitCode(1);
    immutable_assignment_command.expectStdErrEqual(
        "Tests/InvalidImmutableAssignment.sx:3:5: error: cannot assign to immutable variable 'count'\n",
    );

    const invalid_condition_command = b.addRunArtifact(executable);
    invalid_condition_command.addArgs(&.{ "compile", "Tests/InvalidCondition.sx" });
    invalid_condition_command.expectExitCode(1);
    invalid_condition_command.expectStdErrEqual(
        "Tests/InvalidCondition.sx:2:9: error: expected 'bool', found 'int'\n",
    );

    const test_step = b.step("test", "Run the toolchain tests");
    test_step.dependOn(&test_command.step);
    test_step.dependOn(&invalid_command.step);
    test_step.dependOn(&immutable_assignment_command.step);
    test_step.dependOn(&invalid_condition_command.step);

    const smoke_command = b.addRunArtifact(executable);
    smoke_command.addArgs(&.{ "run", "Smokes/Main.sx" });
    smoke_command.expectStdOutEqual("Hello from Silex smoke test\n50\nfalse\n");

    const boolean_condition_command = b.addRunArtifact(executable);
    boolean_condition_command.addArgs(&.{ "run", "Smokes/BooleanCondition.sx" });
    boolean_condition_command.expectStdOutEqual("true branch\n");

    const smoke_step = b.step("smoke", "Compile and run the smoke program");
    smoke_step.dependOn(&smoke_command.step);
    smoke_step.dependOn(&boolean_condition_command.step);
}
