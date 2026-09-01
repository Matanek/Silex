const std = @import("std");
const Ast = @import("Ast.zig");
const Ir = @import("Ir.zig");
const Model = @import("Semantic/Model.zig");
const Optionals = @import("Semantic/Optionals.zig");
const Source = @import("Source.zig");
const Target = @import("Target.zig").Target;

const graphics_program = "GFX.GPU.Pipelines.ShaderProgram";
const compute_program = "GFX.GPU.Pipelines.ComputeProgram";

const Stage = enum { vertex, fragment, compute };
const Format = enum { msl, spirv, dxil };

const GraphicsReflection = struct {
    samplers: i64 = 0,
    storage_textures: i64 = 0,
    storage_buffers: i64 = 0,
    uniform_buffers: i64 = 0,
};

const ComputeReflection = struct {
    samplers: i64 = 0,
    readonly_storage_textures: i64 = 0,
    readonly_storage_buffers: i64 = 0,
    readwrite_storage_textures: i64 = 0,
    readwrite_storage_buffers: i64 = 0,
    uniform_buffers: i64 = 0,
    threadcount_x: i64 = 1,
    threadcount_y: i64 = 1,
    threadcount_z: i64 = 1,
};

const Origin = struct {
    path: []const u8,
    position: Source.Position,
    is_inline: bool,
};

const Input = struct {
    bytes: []const u8,
    path: []const u8,
    include_directory: []const u8,
    origin: Origin,
};

const GraphicsBuild = struct {
    vertex_msl: ?[]const u8 = null,
    fragment_msl: ?[]const u8 = null,
    vertex_spirv: ?[]const u8 = null,
    fragment_spirv: ?[]const u8 = null,
    vertex_dxil: ?[]const u8 = null,
    fragment_dxil: ?[]const u8 = null,
    vertex_entry: []const u8,
    fragment_entry: []const u8,
    vertex: GraphicsReflection,
    fragment: GraphicsReflection,
};

const ComputeBuild = struct {
    msl: ?[]const u8 = null,
    spirv: ?[]const u8 = null,
    dxil: ?[]const u8 = null,
    entry: []const u8,
    reflection: ComputeReflection,
};

pub fn analyze(self: anytype, builder: anytype, structure_index: usize, call: Ast.Expression.Call) !?Model.TypedValue {
    if (!std.mem.eql(u8, call.name, "hlsl")) return null;
    const name = self.program.structures[structure_index].name;
    if (std.mem.eql(u8, name, graphics_program)) {
        return try analyzeGraphics(self, builder, structure_index, call);
    }
    if (std.mem.eql(u8, name, compute_program)) {
        return try analyzeCompute(self, builder, structure_index, call);
    }
    return null;
}

fn analyzeGraphics(self: anytype, builder: anytype, structure_index: usize, call: Ast.Expression.Call) !Model.TypedValue {
    try validateArguments(self, call, &.{ "source", "file", "vertex", "fragment" });
    const input = try loadInput(self, builder, call, 0);
    const vertex_entry = try stringArgument(self, builder, call, "vertex", 2, "vertex_main");
    const fragment_entry = try stringArgument(self, builder, call, "fragment", 3, "fragment_main");
    if (vertex_entry.len == 0) return self.fail(call.name_position, "HLSL vertex entry point cannot be empty");
    if (fragment_entry.len == 0) return self.fail(call.name_position, "HLSL fragment entry point cannot be empty");

    const vertex_reflection = try reflectGraphics(self, input, .vertex, vertex_entry);
    const fragment_reflection = try reflectGraphics(self, input, .fragment, fragment_entry);
    var build = GraphicsBuild{
        .vertex_entry = vertex_entry,
        .fragment_entry = fragment_entry,
        .vertex = vertex_reflection,
        .fragment = fragment_reflection,
    };
    const target = self.target orelse Target.macos_arm64;
    switch (target.platform) {
        .macos => {
            build.vertex_msl = try compileStage(self, input, .vertex, vertex_entry, .msl);
            build.fragment_msl = try compileStage(self, input, .fragment, fragment_entry, .msl);
        },
        .linux => {
            build.vertex_spirv = try compileStage(self, input, .vertex, vertex_entry, .spirv);
            build.fragment_spirv = try compileStage(self, input, .fragment, fragment_entry, .spirv);
        },
        .windows => {
            build.vertex_dxil = try compileStage(self, input, .vertex, vertex_entry, .dxil);
            build.fragment_dxil = try compileStage(self, input, .fragment, fragment_entry, .dxil);
            build.vertex_spirv = try compileStage(self, input, .vertex, vertex_entry, .spirv);
            build.fragment_spirv = try compileStage(self, input, .fragment, fragment_entry, .spirv);
        },
    }
    return emitGraphics(self, builder, structure_index, build);
}

fn analyzeCompute(self: anytype, builder: anytype, structure_index: usize, call: Ast.Expression.Call) !Model.TypedValue {
    try validateArguments(self, call, &.{ "source", "file", "entry" });
    const input = try loadInput(self, builder, call, 0);
    const entry = try stringArgument(self, builder, call, "entry", 2, "compute_main");
    if (entry.len == 0) return self.fail(call.name_position, "HLSL compute entry point cannot be empty");
    const reflection = try reflectCompute(self, input, entry);
    var build = ComputeBuild{ .entry = entry, .reflection = reflection };
    const target = self.target orelse Target.macos_arm64;
    switch (target.platform) {
        .macos => build.msl = try compileStage(self, input, .compute, entry, .msl),
        .linux => build.spirv = try compileStage(self, input, .compute, entry, .spirv),
        .windows => {
            build.dxil = try compileStage(self, input, .compute, entry, .dxil);
            build.spirv = try compileStage(self, input, .compute, entry, .spirv);
        },
    }
    return emitCompute(self, builder, structure_index, build);
}

fn validateArguments(self: anytype, call: Ast.Expression.Call, names: []const []const u8) !void {
    if (call.arguments.len > names.len) return self.fail(call.name_position, "too many arguments for HLSL program");
    for (call.named_arguments, 0..) |argument, index| {
        var known_index: ?usize = null;
        for (names, 0..) |name, name_index| if (std.mem.eql(u8, argument.name, name)) {
            known_index = name_index;
            break;
        };
        if (known_index == null) {
            const message = try std.fmt.allocPrint(self.allocator, "unknown HLSL option '{s}'", .{argument.name});
            return self.fail(argument.position, message);
        }
        if (known_index.? < call.arguments.len) {
            const message = try std.fmt.allocPrint(self.allocator, "HLSL option '{s}' is provided more than once", .{argument.name});
            return self.fail(argument.position, message);
        }
        for (call.named_arguments[0..index]) |previous| if (std.mem.eql(u8, previous.name, argument.name)) {
            const message = try std.fmt.allocPrint(self.allocator, "HLSL option '{s}' is provided more than once", .{argument.name});
            return self.fail(argument.position, message);
        };
    }
}

fn loadInput(self: anytype, builder: anytype, call: Ast.Expression.Call, source_index: usize) !Input {
    const source_expression = findArgument(call, "source", source_index);
    const file_expression = findArgument(call, "file", source_index + 1);
    if (source_expression != null and file_expression != null) {
        return self.fail(file_expression.?.position, "HLSL program accepts either 'source' or 'file', not both");
    }
    if (source_expression) |expression| {
        const bytes = try compileTimeString(self, builder, expression, "HLSL source");
        if (bytes.len == 0) return self.fail(expression.position, "HLSL source cannot be empty");
        const source_path = sourcePath(self, expression.position);
        const directory = std.fs.path.dirname(source_path) orelse ".";
        const input_path = try temporaryPath(self, bytes, "inline.hlsl");
        writeFile(self, input_path, bytes) catch |err| {
            const message = try std.fmt.allocPrint(self.allocator, "cannot prepare inline HLSL source: {t}", .{err});
            return self.fail(expression.position, message);
        };
        try rememberIncludes(self, bytes, directory, 0);
        return .{
            .bytes = bytes,
            .path = input_path,
            .include_directory = directory,
            .origin = .{ .path = source_path, .position = expression.position, .is_inline = true },
        };
    }
    if (file_expression) |expression| {
        const requested = try compileTimeString(self, builder, expression, "HLSL file path");
        if (requested.len == 0) return self.fail(expression.position, "HLSL file path cannot be empty");
        const owner_path = sourcePath(self, expression.position);
        const directory = std.fs.path.dirname(owner_path) orelse ".";
        const path = if (std.fs.path.isAbsolute(requested))
            try self.allocator.dupe(u8, requested)
        else
            try std.fs.path.resolve(self.allocator, &.{ directory, requested });
        const io = self.io orelse return self.fail(expression.position, "HLSL compilation is unavailable in this compiler context");
        const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, self.allocator, .limited(16 * 1024 * 1024)) catch |err| {
            const message = try std.fmt.allocPrint(self.allocator, "cannot read HLSL file '{s}': {t}", .{ path, err });
            return self.fail(expression.position, message);
        };
        try rememberShaderFile(self, path);
        try rememberIncludes(self, bytes, std.fs.path.dirname(path) orelse ".", 0);
        return .{
            .bytes = bytes,
            .path = path,
            .include_directory = std.fs.path.dirname(path) orelse ".",
            .origin = .{ .path = path, .position = expression.position, .is_inline = false },
        };
    }
    return self.fail(call.name_position, "HLSL program requires either 'source' or 'file'");
}

fn findArgument(call: Ast.Expression.Call, name: []const u8, positional: usize) ?*Ast.Expression {
    for (call.named_arguments) |candidate| if (std.mem.eql(u8, candidate.name, name)) return candidate.value;
    if (positional < call.arguments.len) return call.arguments[positional];
    return null;
}

fn stringArgument(
    self: anytype,
    builder: anytype,
    call: Ast.Expression.Call,
    name: []const u8,
    positional: usize,
    default: []const u8,
) ![]const u8 {
    const expression = findArgument(call, name, positional) orelse return default;
    return compileTimeString(self, builder, expression, name);
}

fn compileTimeString(self: anytype, builder: anytype, expression: *Ast.Expression, label: []const u8) ![]const u8 {
    switch (expression.value) {
        .string => |value| return value,
        .identifier => |name| {
            for (builder.bindings.items) |binding| {
                if (!std.mem.eql(u8, binding.name, name) or binding.mutable or binding.value == null) continue;
                const value = binding.value.?;
                for (builder.blocks.items) |block| for (block.instructions.items) |instruction| switch (instruction) {
                    .constant_str => |constant| if (constant.result == value) return constant.value,
                    else => {},
                };
            }
        },
        else => {},
    }
    const message = try std.fmt.allocPrint(self.allocator, "{s} must be a string known at compile time", .{label});
    return self.fail(expression.position, message);
}

fn reflectGraphics(self: anytype, input: Input, stage: Stage, entry: []const u8) !GraphicsReflection {
    const bytes = try runShadercross(self, input, stage, entry, "JSON", "reflection.json");
    return std.json.parseFromSliceLeaky(GraphicsReflection, self.allocator, bytes, .{ .ignore_unknown_fields = true }) catch {
        return self.fail(input.origin.position, "Shadercross returned invalid graphics reflection data");
    };
}

fn reflectCompute(self: anytype, input: Input, entry: []const u8) !ComputeReflection {
    const bytes = try runShadercross(self, input, .compute, entry, "JSON", "reflection.json");
    return std.json.parseFromSliceLeaky(ComputeReflection, self.allocator, bytes, .{ .ignore_unknown_fields = true }) catch {
        return self.fail(input.origin.position, "Shadercross returned invalid compute reflection data");
    };
}

fn compileStage(self: anytype, input: Input, stage: Stage, entry: []const u8, format: Format) ![]const u8 {
    const destination = switch (format) {
        .msl => "MSL",
        .spirv => "SPIRV",
        .dxil => "DXIL",
    };
    const filename = switch (format) {
        .msl => "shader.msl",
        .spirv => "shader.spv",
        .dxil => "shader.dxil",
    };
    return hex(self.allocator, try runShadercross(self, input, stage, entry, destination, filename));
}

fn runShadercross(
    self: anytype,
    input: Input,
    stage: Stage,
    entry: []const u8,
    destination: []const u8,
    filename: []const u8,
) ![]const u8 {
    const io = self.io orelse return self.fail(input.origin.position, "HLSL compilation is unavailable in this compiler context");
    const tool = self.shadercross_path orelse return self.fail(
        input.origin.position,
        "Shadercross is not configured; run 'silex setup' before compiling HLSL",
    );
    _ = std.Io.Dir.cwd().statFile(io, tool, .{}) catch return self.fail(
        input.origin.position,
        "Shadercross is not installed; run 'silex setup' before compiling HLSL",
    );
    const output = try temporaryPath(self, input.bytes, try std.fmt.allocPrint(
        self.allocator,
        "{s}-{s}-{s}",
        .{ @tagName(stage), entry, filename },
    ));
    if (std.fs.path.dirname(output)) |directory| {
        std.Io.Dir.cwd().createDirPath(io, directory) catch |err| {
            const message = try std.fmt.allocPrint(self.allocator, "cannot prepare Shadercross output: {t}", .{err});
            return self.fail(input.origin.position, message);
        };
    }
    const result = std.process.run(self.allocator, io, .{ .argv = &.{
        tool,
        input.path,
        "-s",
        "HLSL",
        "-d",
        destination,
        "-t",
        @tagName(stage),
        "-e",
        entry,
        "-I",
        input.include_directory,
        "-o",
        output,
    } }) catch |err| {
        const message = try std.fmt.allocPrint(self.allocator, "cannot start Shadercross: {t}", .{err});
        return self.fail(input.origin.position, message);
    };
    const succeeded = switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
    if (!succeeded) return failShadercross(self, input.origin, result.stderr);
    return std.Io.Dir.cwd().readFileAlloc(io, output, self.allocator, .limited(64 * 1024 * 1024)) catch |err| {
        const message = try std.fmt.allocPrint(self.allocator, "cannot read Shadercross output: {t}", .{err});
        return self.fail(input.origin.position, message);
    };
}

fn failShadercross(self: anytype, origin: Origin, stderr: []const u8) Source.Error {
    const parsed = parseDiagnostic(stderr);
    if (parsed) |diagnostic| {
        const external_path = !std.mem.eql(u8, diagnostic.path, "hlsl.hlsl");
        if (origin.is_inline and !external_path) {
            self.diagnostic = .{
                .position = origin.position,
                .message = std.fmt.allocPrint(
                    self.allocator,
                    "HLSL {d}:{d}: {s}",
                    .{ diagnostic.line, diagnostic.column, diagnostic.message },
                ) catch "HLSL compilation failed",
            };
        } else {
            self.diagnostic = .{
                .position = .{ .offset = 0, .line = diagnostic.line, .column = diagnostic.column },
                .message = diagnostic.message,
                .path = if (external_path) diagnostic.path else origin.path,
            };
        }
    } else {
        self.diagnostic = .{
            .position = origin.position,
            .message = if (stderr.len == 0) "Shadercross failed without a diagnostic" else stderr,
            .path = if (origin.is_inline) null else origin.path,
        };
    }
    return error.InvalidSource;
}

const ParsedDiagnostic = struct {
    path: []const u8,
    line: usize,
    column: usize,
    message: []const u8,
};

pub fn parseDiagnostic(stderr: []const u8) ?ParsedDiagnostic {
    const regular_marker = ": error:";
    const fatal_marker = ": fatal error:";
    const marker, const error_at = if (std.mem.indexOf(u8, stderr, regular_marker)) |at|
        .{ regular_marker, at }
    else if (std.mem.indexOf(u8, stderr, fatal_marker)) |at|
        .{ fatal_marker, at }
    else
        return null;
    const before_error = stderr[0..error_at];
    const column_separator = std.mem.lastIndexOfScalar(u8, before_error, ':') orelse return null;
    const line_separator = std.mem.lastIndexOfScalar(u8, before_error[0..column_separator], ':') orelse return null;
    const line_start = if (std.mem.lastIndexOfScalar(u8, before_error[0..line_separator], '\n')) |newline| newline + 1 else 0;
    const raw_path = std.mem.trim(u8, before_error[line_start..line_separator], " \t\r");
    const path = if (std.mem.indexOf(u8, raw_path, "hlsl.hlsl")) |at| raw_path[at .. at + "hlsl.hlsl".len] else raw_path;
    const line = std.fmt.parseInt(usize, before_error[line_separator + 1 .. column_separator], 10) catch return null;
    const column = std.fmt.parseInt(usize, before_error[column_separator + 1 ..], 10) catch return null;
    var cursor = error_at + marker.len;
    while (cursor < stderr.len and stderr[cursor] == ' ') cursor += 1;
    const end = std.mem.indexOfScalarPos(u8, stderr, cursor, '\n') orelse stderr.len;
    return .{ .path = path, .line = line, .column = column, .message = stderr[cursor..end] };
}

fn emitGraphics(self: anytype, builder: anytype, structure_index: usize, build: GraphicsBuild) !Model.TypedValue {
    var fields: std.ArrayList(Ir.ValueId) = .empty;
    for (self.structures[structure_index].fields) |field| {
        const value = if (std.mem.eql(u8, field.name, "vertex_msl"))
            try optionalString(self, builder, field.type, build.vertex_msl)
        else if (std.mem.eql(u8, field.name, "fragment_msl"))
            try optionalString(self, builder, field.type, build.fragment_msl)
        else if (std.mem.eql(u8, field.name, "vertex_spirv"))
            try optionalString(self, builder, field.type, build.vertex_spirv)
        else if (std.mem.eql(u8, field.name, "fragment_spirv"))
            try optionalString(self, builder, field.type, build.fragment_spirv)
        else if (std.mem.eql(u8, field.name, "vertex_dxil"))
            try optionalString(self, builder, field.type, build.vertex_dxil)
        else if (std.mem.eql(u8, field.name, "fragment_dxil"))
            try optionalString(self, builder, field.type, build.fragment_dxil)
        else if (std.mem.eql(u8, field.name, "vertex_entry"))
            try stringValue(self, builder, build.vertex_entry)
        else if (std.mem.eql(u8, field.name, "fragment_entry"))
            try stringValue(self, builder, build.fragment_entry)
        else if (std.mem.eql(u8, field.name, "vertex_samplers"))
            try integerValue(self, builder, build.vertex.samplers)
        else if (std.mem.eql(u8, field.name, "vertex_storage_textures"))
            try integerValue(self, builder, build.vertex.storage_textures)
        else if (std.mem.eql(u8, field.name, "vertex_storage_buffers"))
            try integerValue(self, builder, build.vertex.storage_buffers)
        else if (std.mem.eql(u8, field.name, "vertex_uniform_buffers"))
            try integerValue(self, builder, build.vertex.uniform_buffers)
        else if (std.mem.eql(u8, field.name, "fragment_samplers"))
            try integerValue(self, builder, build.fragment.samplers)
        else if (std.mem.eql(u8, field.name, "fragment_storage_textures"))
            try integerValue(self, builder, build.fragment.storage_textures)
        else if (std.mem.eql(u8, field.name, "fragment_storage_buffers"))
            try integerValue(self, builder, build.fragment.storage_buffers)
        else if (std.mem.eql(u8, field.name, "fragment_uniform_buffers"))
            try integerValue(self, builder, build.fragment.uniform_buffers)
        else
            return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, "invalid GFX ShaderProgram contract");
        try fields.append(self.allocator, value.value);
    }
    return structureValue(self, builder, structure_index, try fields.toOwnedSlice(self.allocator));
}

fn emitCompute(self: anytype, builder: anytype, structure_index: usize, build: ComputeBuild) !Model.TypedValue {
    var fields: std.ArrayList(Ir.ValueId) = .empty;
    for (self.structures[structure_index].fields) |field| {
        const value = if (std.mem.eql(u8, field.name, "msl"))
            try optionalString(self, builder, field.type, build.msl)
        else if (std.mem.eql(u8, field.name, "spirv"))
            try optionalString(self, builder, field.type, build.spirv)
        else if (std.mem.eql(u8, field.name, "dxil"))
            try optionalString(self, builder, field.type, build.dxil)
        else if (std.mem.eql(u8, field.name, "entry"))
            try stringValue(self, builder, build.entry)
        else if (std.mem.eql(u8, field.name, "samplers"))
            try integerValue(self, builder, build.reflection.samplers)
        else if (std.mem.eql(u8, field.name, "read_only_storage_textures"))
            try integerValue(self, builder, build.reflection.readonly_storage_textures)
        else if (std.mem.eql(u8, field.name, "read_only_storage_buffers"))
            try integerValue(self, builder, build.reflection.readonly_storage_buffers)
        else if (std.mem.eql(u8, field.name, "read_write_storage_textures"))
            try integerValue(self, builder, build.reflection.readwrite_storage_textures)
        else if (std.mem.eql(u8, field.name, "read_write_storage_buffers"))
            try integerValue(self, builder, build.reflection.readwrite_storage_buffers)
        else if (std.mem.eql(u8, field.name, "uniform_buffers"))
            try integerValue(self, builder, build.reflection.uniform_buffers)
        else if (std.mem.eql(u8, field.name, "threads_x"))
            try integerValue(self, builder, build.reflection.threadcount_x)
        else if (std.mem.eql(u8, field.name, "threads_y"))
            try integerValue(self, builder, build.reflection.threadcount_y)
        else if (std.mem.eql(u8, field.name, "threads_z"))
            try integerValue(self, builder, build.reflection.threadcount_z)
        else
            return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, "invalid GFX ComputeProgram contract");
        try fields.append(self.allocator, value.value);
    }
    return structureValue(self, builder, structure_index, try fields.toOwnedSlice(self.allocator));
}

fn stringValue(self: anytype, builder: anytype, value: []const u8) !Model.TypedValue {
    const result = try self.newValue(builder, .str);
    try self.emit(builder, .{ .constant_str = .{ .result = result, .value = value } });
    return .{ .type = .str, .value = result };
}

fn integerValue(self: anytype, builder: anytype, value: i64) !Model.TypedValue {
    if (value < 0) return self.fail(.{ .offset = 0, .line = 1, .column = 1 }, "Shadercross returned a negative resource count");
    const result = try self.newValue(builder, .int);
    try self.emit(builder, .{ .constant_int = .{ .result = result, .bits = @intCast(value) } });
    return .{ .type = .int, .value = result };
}

fn optionalString(self: anytype, builder: anytype, type_value: Ast.Type, value: ?[]const u8) !Model.TypedValue {
    if (value) |bytes| return (try Optionals.promote(self, builder, try stringValue(self, builder, bytes), type_value)).?;
    return (try Optionals.intrinsic(self, builder, type_value)).?;
}

fn structureValue(self: anytype, builder: anytype, structure_index: usize, fields: []const Ir.ValueId) !Model.TypedValue {
    const type_value = Ast.Type.structure(structure_index);
    const result = try self.newValue(builder, type_value);
    try self.emit(builder, .{ .structure_init = .{ .result = result, .structure = structure_index, .fields = fields } });
    return .{ .type = type_value, .value = result };
}

fn sourcePath(self: anytype, position: Source.Position) []const u8 {
    if (position.file < self.source_files.len) return self.source_files[position.file];
    return "<source>";
}

fn rememberShaderFile(self: anytype, path: []const u8) !void {
    for (self.shader_files.items) |existing| if (std.mem.eql(u8, existing, path)) return;
    try self.shader_files.append(self.allocator, path);
}

fn rememberIncludes(self: anytype, source: []const u8, directory: []const u8, depth: usize) !void {
    if (depth == 32) return;
    const io = self.io orelse return;
    var remaining = source;
    while (std.mem.indexOf(u8, remaining, "#include")) |include_at| {
        remaining = remaining[include_at + "#include".len ..];
        const quote = std.mem.indexOfScalar(u8, remaining, '"') orelse continue;
        const after_quote = remaining[quote + 1 ..];
        const end_quote = std.mem.indexOfScalar(u8, after_quote, '"') orelse continue;
        const requested = after_quote[0..end_quote];
        remaining = after_quote[end_quote + 1 ..];
        const path = std.fs.path.resolve(self.allocator, &.{ directory, requested }) catch continue;
        const bytes = std.Io.Dir.cwd().readFileAlloc(io, path, self.allocator, .limited(16 * 1024 * 1024)) catch continue;
        try rememberShaderFile(self, path);
        try rememberIncludes(self, bytes, std.fs.path.dirname(path) orelse directory, depth + 1);
    }
}

fn temporaryPath(self: anytype, source: []const u8, filename: []const u8) ![]const u8 {
    var hasher = std.crypto.hash.Blake3.init(.{});
    hasher.update("silex-hlsl-v1");
    hasher.update(source);
    if (self.target) |target| hasher.update(target.name());
    var digest: [std.crypto.hash.Blake3.digest_length]u8 = undefined;
    hasher.final(&digest);
    const encoded = std.fmt.bytesToHex(digest, .lower);
    const directory = try std.fmt.allocPrint(self.allocator, ".silex/cache/shaders/{s}", .{encoded});
    return std.fs.path.join(self.allocator, &.{ directory, filename });
}

fn writeFile(self: anytype, path: []const u8, bytes: []const u8) !void {
    const io = self.io orelse return error.InvalidSource;
    var atomic = try std.Io.Dir.cwd().createFileAtomic(io, path, .{ .make_path = true, .replace = true });
    defer atomic.deinit(io);
    try atomic.file.writeStreamingAll(io, bytes);
    try atomic.replace(io);
}

fn hex(allocator: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    const digits = "0123456789abcdef";
    const result = try allocator.alloc(u8, bytes.len * 2);
    for (bytes, 0..) |byte, index| {
        result[index * 2] = digits[byte >> 4];
        result[index * 2 + 1] = digits[byte & 0x0f];
    }
    return result;
}

test "parse Shadercross HLSL diagnostics" {
    const diagnostic = parseDiagnostic(
        "ERROR: HLSL compilation failed: hlsl.hlsl:12:7: error: use of undeclared identifier 'light'\n",
    ).?;
    try std.testing.expectEqual(@as(usize, 12), diagnostic.line);
    try std.testing.expectEqual(@as(usize, 7), diagnostic.column);
    try std.testing.expectEqualStrings("hlsl.hlsl", diagnostic.path);
    try std.testing.expectEqualStrings("use of undeclared identifier 'light'", diagnostic.message);
}

test "parse diagnostics from an included HLSL file" {
    const diagnostic = parseDiagnostic(
        "ERROR: In file included from hlsl.hlsl:1:\n/Project/Shaders/Common.hlsl:9:4: error: expected expression\n",
    ).?;
    try std.testing.expectEqualStrings("/Project/Shaders/Common.hlsl", diagnostic.path);
    try std.testing.expectEqual(@as(usize, 9), diagnostic.line);
    try std.testing.expectEqual(@as(usize, 4), diagnostic.column);
}

test "parse fatal HLSL diagnostics" {
    const diagnostic = parseDiagnostic(
        "hlsl.hlsl:3:10: fatal error: 'Common.hlsl' file not found\n",
    ).?;
    try std.testing.expectEqualStrings("hlsl.hlsl", diagnostic.path);
    try std.testing.expectEqual(@as(usize, 3), diagnostic.line);
    try std.testing.expectEqual(@as(usize, 10), diagnostic.column);
    try std.testing.expectEqualStrings("'Common.hlsl' file not found", diagnostic.message);
}

test "decode Shadercross reflection contracts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const graphics = try std.json.parseFromSliceLeaky(
        GraphicsReflection,
        allocator,
        "{\"samplers\":2,\"storage_buffers\":1,\"inputs\":[]}",
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqual(@as(i64, 2), graphics.samplers);
    try std.testing.expectEqual(@as(i64, 1), graphics.storage_buffers);

    const compute = try std.json.parseFromSliceLeaky(
        ComputeReflection,
        allocator,
        "{\"readwrite_storage_buffers\":1,\"threadcount_x\":8,\"threadcount_y\":2,\"threadcount_z\":1}",
        .{ .ignore_unknown_fields = true },
    );
    try std.testing.expectEqual(@as(i64, 1), compute.readwrite_storage_buffers);
    try std.testing.expectEqual(@as(i64, 8), compute.threadcount_x);
}
