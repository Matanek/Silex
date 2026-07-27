const std = @import("std");
const builtin = @import("builtin");
const macho = std.macho;

const DynamicLink = @import("DynamicLink.zig");
const Machine = @import("../Arm64/Machine.zig");
const MachO = @import("MachO.zig");

const write_arguments = [_]Machine.AbiValue{ .int32, .read_address, .uint64 };
const call_arguments = [_]Machine.Slot{ 0, 2, 3 };
const message = "Silex appelle libSystem.\n";

fn writeFunction() Machine.ExternalFunction {
    return .{
        .provider = "Darwin.lib_system",
        .source_name = "write",
        .signature = .{ .arguments = &write_arguments, .result = .int64 },
    };
}

fn mainFunction(result: ?Machine.Slot, arguments: []const Machine.Slot) !Machine.Function {
    const instructions = try std.testing.allocator.alloc(Machine.Instruction, 8);
    instructions[0] = .{ .constant_int = .{ .result = 0, .bits = 1, .type = .int32 } };
    instructions[1] = .{ .constant_str = .{ .result = 1, .string = 0 } };
    instructions[2] = .{ .reference_offset = .{ .result = 2, .reference = 1, .byte_offset = 8 } };
    instructions[3] = .{ .constant_int = .{ .result = 3, .bits = message.len, .type = .uint } };
    instructions[4] = .{ .external_call = .{ .result = result, .function = 0, .arguments = arguments } };
    instructions[5] = .{ .binary = .{ .result = 5, .operator = .equal, .left = 4, .right = 3, .type = .int } };
    instructions[6] = .{ .assert = .{ .condition = 5, .message = 1, .header = 0 } };
    instructions[7] = .return_void;
    return .{
        .name = "main",
        .parameter_count = 0,
        .return_type = .void,
        .slot_count = 6,
        .frame_size = try Machine.frameSize(6),
        .instructions = instructions,
    };
}

test "validate the Darwin libSystem write machine contract" {
    const function = try mainFunction(4, &call_arguments);
    defer std.testing.allocator.free(function.instructions);
    var external = writeFunction();
    try Machine.validate(.{
        .functions = &.{function},
        .external_functions = &.{external},
        .strings = &.{message},
    });

    external.provider = "Unknown.provider";
    try std.testing.expectError(error.InvalidMachineProgram, Machine.validate(.{
        .functions = &.{function},
        .external_functions = &.{external},
        .strings = &.{message},
    }));
    external = writeFunction();
    const unsupported_arguments = [_]Machine.AbiValue{ .int32, .read_address, .int64 };
    external.signature.arguments = &unsupported_arguments;
    try std.testing.expectError(error.InvalidMachineProgram, Machine.validate(.{
        .functions = &.{function},
        .external_functions = &.{external},
        .strings = &.{message},
    }));
    external = writeFunction();
    external.signature.result = null;
    try std.testing.expectError(error.InvalidMachineProgram, Machine.validate(.{
        .functions = &.{function},
        .external_functions = &.{external},
        .strings = &.{message},
    }));

    const short_arguments = [_]Machine.Slot{ 0, 2 };
    const short_function = try mainFunction(4, &short_arguments);
    defer std.testing.allocator.free(short_function.instructions);
    external = writeFunction();
    try std.testing.expectError(error.InvalidMachineProgram, Machine.validate(.{
        .functions = &.{short_function},
        .external_functions = &.{external},
        .strings = &.{message},
    }));

    const absent_result = try mainFunction(null, &call_arguments);
    defer std.testing.allocator.free(absent_result.instructions);
    try std.testing.expectError(error.InvalidMachineProgram, Machine.validate(.{
        .functions = &.{absent_result},
        .external_functions = &.{external},
        .strings = &.{message},
    }));

    var code = [_]u8{0} ** 12;
    try std.testing.expectError(error.InvalidExternalFixup, DynamicLink.patchCalls(
        &code,
        &.{.{ .instruction_offset = 12, .function = 0 }},
        1,
        0x1_0000_4000,
        0x1_0000_8000,
    ));
}

test "emit and execute a direct libSystem write import" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const function = try mainFunction(4, &call_arguments);
    defer std.testing.allocator.free(function.instructions);
    const external = writeFunction();
    const bytes = try MachO.emit(allocator, .{
        .functions = &.{function},
        .external_functions = &.{external},
        .strings = &.{message},
    });

    var saw_dylib = false;
    var saw_dyld_info = false;
    var saw_symtab = false;
    var saw_got = false;
    const command_count = std.mem.readInt(u32, bytes[16..20], .little);
    var offset: usize = @sizeOf(macho.mach_header_64);
    for (0..command_count) |_| {
        const command: macho.LC = @enumFromInt(std.mem.readInt(u32, bytes[offset..][0..4], .little));
        const command_size = std.mem.readInt(u32, bytes[offset + 4 ..][0..4], .little);
        switch (command) {
            .LOAD_DYLIB => {
                const name_offset = std.mem.readInt(u32, bytes[offset + 8 ..][0..4], .little);
                const path = std.mem.sliceTo(bytes[offset + name_offset .. offset + command_size], 0);
                saw_dylib = std.mem.eql(u8, path, "/usr/lib/libSystem.B.dylib");
            },
            .DYLD_INFO_ONLY => {
                const bind_offset = std.mem.readInt(u32, bytes[offset + 16 ..][0..4], .little);
                const bind_size = std.mem.readInt(u32, bytes[offset + 20 ..][0..4], .little);
                saw_dyld_info = bind_size != 0 and std.mem.indexOf(u8, bytes[bind_offset..][0..bind_size], "_write\x00") != null;
            },
            .SYMTAB => {
                const symbol_count = std.mem.readInt(u32, bytes[offset + 12 ..][0..4], .little);
                const string_offset = std.mem.readInt(u32, bytes[offset + 16 ..][0..4], .little);
                const string_size = std.mem.readInt(u32, bytes[offset + 20 ..][0..4], .little);
                saw_symtab = symbol_count == 1 and std.mem.indexOf(u8, bytes[string_offset..][0..string_size], "_write\x00") != null;
            },
            .SEGMENT_64 => {
                saw_got = saw_got or std.mem.eql(u8, std.mem.sliceTo(bytes[offset + 8 ..][0..16], 0), "__DATA_CONST");
            },
            else => {},
        }
        offset += command_size;
    }
    try std.testing.expect(saw_dylib);
    try std.testing.expect(saw_dyld_info);
    try std.testing.expect(saw_symtab);
    try std.testing.expect(saw_got);

    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const executable = try std.fs.path.join(allocator, &.{ base, "external-write" });
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, executable, .{ .permissions = .executable_file });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, bytes);
    try file.setPermissions(std.testing.io, .executable_file);
    const result = try std.process.run(allocator, std.testing.io, .{ .argv = &.{executable} });
    try std.testing.expectEqual(@as(u8, 0), switch (result.term) {
        .exited => |code| code,
        else => 255,
    });
    try std.testing.expectEqualStrings(message, result.stdout);
    try std.testing.expectEqual(@as(usize, 0), result.stderr.len);
}
