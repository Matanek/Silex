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

    const invalid_logical_command = b.addRunArtifact(executable);
    invalid_logical_command.addArgs(&.{ "compile", "Tests/InvalidLogical.sx" });
    invalid_logical_command.expectExitCode(1);
    invalid_logical_command.expectStdErrEqual(
        "Tests/InvalidLogical.sx:2:11: error: logical operator requires 'bool' operands, found 'int' and 'bool'\n",
    );

    const invalid_while_command = b.addRunArtifact(executable);
    invalid_while_command.addArgs(&.{ "compile", "Tests/InvalidWhileCondition.sx" });
    invalid_while_command.expectExitCode(1);
    invalid_while_command.expectStdErrEqual(
        "Tests/InvalidWhileCondition.sx:2:12: error: expected 'bool', found 'int'\n",
    );

    const missing_separator_command = b.addRunArtifact(executable);
    missing_separator_command.addArgs(&.{ "compile", "Tests/MissingStatementSeparator.sx" });
    missing_separator_command.expectExitCode(1);
    missing_separator_command.expectStdErrEqual(
        "Tests/MissingStatementSeparator.sx:2:15: error: expected ';' or line break\n",
    );

    const missing_type_command = b.addRunArtifact(executable);
    missing_type_command.addArgs(&.{ "compile", "Tests/MissingTypeAnnotation.sx" });
    missing_type_command.expectExitCode(1);
    missing_type_command.expectStdErrEqual(
        "Tests/MissingTypeAnnotation.sx:2:17: error: expected type name after ':'\n",
    );

    const missing_return_command = b.addRunArtifact(executable);
    missing_return_command.addArgs(&.{ "compile", "Tests/MissingReturn.sx" });
    missing_return_command.expectExitCode(1);
    missing_return_command.expectStdErrEqual(
        "Tests/MissingReturn.sx:1:6: error: function 'value' must return 'int' on every path\n",
    );

    const invalid_arguments_command = b.addRunArtifact(executable);
    invalid_arguments_command.addArgs(&.{ "compile", "Tests/InvalidArguments.sx" });
    invalid_arguments_command.expectExitCode(1);
    invalid_arguments_command.expectStdErrEqual(
        "Tests/InvalidArguments.sx:2:18: error: argument 2 of 'add' expects 'int', found 'bool'\n",
    );

    const unknown_struct_field_command = b.addRunArtifact(executable);
    unknown_struct_field_command.addArgs(&.{ "compile", "Tests/UnknownStructField.sx" });
    unknown_struct_field_command.expectExitCode(1);
    unknown_struct_field_command.expectStdErrEqual(
        "Tests/UnknownStructField.sx:7:37: error: unknown field 'depth' in struct 'Position'\n",
    );

    const immutable_struct_field_command = b.addRunArtifact(executable);
    immutable_struct_field_command.addArgs(&.{ "compile", "Tests/ImmutableStructField.sx" });
    immutable_struct_field_command.expectExitCode(1);
    immutable_struct_field_command.expectStdErrEqual(
        "Tests/ImmutableStructField.sx:8:5: error: cannot assign to immutable variable 'position'\n",
    );

    const duplicate_struct_field_command = b.addRunArtifact(executable);
    duplicate_struct_field_command.addArgs(&.{ "compile", "Tests/DuplicateStructField.sx" });
    duplicate_struct_field_command.expectExitCode(1);
    duplicate_struct_field_command.expectStdErrEqual(
        "Tests/DuplicateStructField.sx:7:37: error: field 'x' is initialized more than once\n",
    );

    const invalid_struct_field_type_command = b.addRunArtifact(executable);
    invalid_struct_field_type_command.addArgs(&.{ "compile", "Tests/InvalidStructFieldType.sx" });
    invalid_struct_field_type_command.expectExitCode(1);
    invalid_struct_field_type_command.expectStdErrEqual(
        "Tests/InvalidStructFieldType.sx:7:33: error: expected 'int', found 'string'\n",
    );

    const immutable_method_call_command = b.addRunArtifact(executable);
    immutable_method_call_command.addArgs(&.{ "compile", "Tests/ImmutableMethodCall.sx" });
    immutable_method_call_command.expectExitCode(1);
    immutable_method_call_command.expectStdErrEqual(
        "Tests/ImmutableMethodCall.sx:15:13: error: cannot call mutating method 'increment' on immutable value 'counter'\n",
    );

    const untyped_declaration_command = b.addRunArtifact(executable);
    untyped_declaration_command.addArgs(&.{ "compile", "Tests/UntypedDeclaration.sx" });
    untyped_declaration_command.expectExitCode(1);
    untyped_declaration_command.expectStdErrEqual(
        "Tests/UntypedDeclaration.sx:2:9: error: variable declaration requires a type or initializer\n",
    );

    const invalid_field_default_command = b.addRunArtifact(executable);
    invalid_field_default_command.addArgs(&.{ "compile", "Tests/InvalidFieldDefault.sx" });
    invalid_field_default_command.expectExitCode(1);
    invalid_field_default_command.expectStdErrEqual(
        "Tests/InvalidFieldDefault.sx:2:18: error: default field value must be a literal or struct initializer of type 'int'\n",
    );

    const invalid_compound_assignment_command = b.addRunArtifact(executable);
    invalid_compound_assignment_command.addArgs(&.{ "compile", "Tests/InvalidCompoundAssignment.sx" });
    invalid_compound_assignment_command.expectExitCode(1);
    invalid_compound_assignment_command.expectStdErrEqual(
        "Tests/InvalidCompoundAssignment.sx:3:5: error: operator '+=' requires an 'int' target and value, found 'string' and 'string'\n",
    );

    const test_step = b.step("test", "Run the toolchain tests");
    test_step.dependOn(&test_command.step);
    test_step.dependOn(&invalid_command.step);
    test_step.dependOn(&immutable_assignment_command.step);
    test_step.dependOn(&invalid_condition_command.step);
    test_step.dependOn(&invalid_logical_command.step);
    test_step.dependOn(&invalid_while_command.step);
    test_step.dependOn(&missing_separator_command.step);
    test_step.dependOn(&missing_type_command.step);
    test_step.dependOn(&missing_return_command.step);
    test_step.dependOn(&invalid_arguments_command.step);
    test_step.dependOn(&unknown_struct_field_command.step);
    test_step.dependOn(&immutable_struct_field_command.step);
    test_step.dependOn(&duplicate_struct_field_command.step);
    test_step.dependOn(&invalid_struct_field_type_command.step);
    test_step.dependOn(&immutable_method_call_command.step);
    test_step.dependOn(&untyped_declaration_command.step);
    test_step.dependOn(&invalid_field_default_command.step);
    test_step.dependOn(&invalid_compound_assignment_command.step);

    const smoke_command = b.addRunArtifact(executable);
    smoke_command.addArgs(&.{ "run", "Smokes/Main.sx" });
    smoke_command.expectStdOutEqual("Hello from Silex smoke test\n50\nlogic works\ntrue\nfalse\n2\n1\n");

    const boolean_condition_command = b.addRunArtifact(executable);
    boolean_condition_command.addArgs(&.{ "run", "Smokes/BooleanCondition.sx" });
    boolean_condition_command.expectStdOutEqual("true branch\n");

    const compact_command = b.addRunArtifact(executable);
    compact_command.addArgs(&.{ "run", "Smokes/Compact.sx" });
    compact_command.expectStdOutEqual("50\n");

    const structures_command = b.addRunArtifact(executable);
    structures_command.addArgs(&.{ "run", "Smokes/Structures.sx" });
    structures_command.expectStdOutEqual("Ada\n32\n0\n");

    const defaults_command = b.addRunArtifact(executable);
    defaults_command.addArgs(&.{ "run", "Smokes/Defaults.sx" });
    defaults_command.expectStdOutEqual("Ada\nfalse\n1\n7\n0\n\nBob\ntrue\n4\n5\n");

    const smoke_step = b.step("smoke", "Compile and run the smoke program");
    smoke_step.dependOn(&smoke_command.step);
    smoke_step.dependOn(&boolean_condition_command.step);
    smoke_step.dependOn(&compact_command.step);
    smoke_step.dependOn(&structures_command.step);
    smoke_step.dependOn(&defaults_command.step);
}
