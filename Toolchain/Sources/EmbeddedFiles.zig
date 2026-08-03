const std = @import("std");
const Ast = @import("Ast.zig");
const Model = @import("Semantic/Model.zig");
const Source = @import("Source.zig");

const maximum_file_size = 16 * 1024 * 1024;

const Kind = enum { text, bytes };

pub fn analyze(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    if (call.receiver != null) return null;
    const kind: Kind = if (std.mem.eql(u8, call.name, "embed_text"))
        .text
    else if (std.mem.eql(u8, call.name, "embed_bytes"))
        .bytes
    else
        return null;
    if (call.type_arguments.len != 0 or call.safe) {
        const message = try std.fmt.allocPrint(self.allocator, "{s} does not accept type arguments or safe dispatch", .{call.name});
        return self.fail(call.name_position, message);
    }
    const file_expression = try fileArgument(self, call, call.name);
    const requested = try compileTimeString(self, builder, file_expression);
    if (requested.len == 0) return self.fail(file_expression.position, "embedded file path cannot be empty");

    const owner_path = sourcePath(self, file_expression.position);
    const owner_directory = std.fs.path.dirname(owner_path) orelse ".";
    const file_path = if (std.fs.path.isAbsolute(requested))
        try self.allocator.dupe(u8, requested)
    else
        try std.fs.path.resolve(self.allocator, &.{ owner_directory, requested });
    const io = self.io orelse return self.fail(file_expression.position, "file embedding is unavailable in this compiler context");
    const content = std.Io.Dir.cwd().readFileAlloc(io, file_path, self.allocator, .limited(maximum_file_size)) catch |err| {
        const message = try std.fmt.allocPrint(self.allocator, "cannot read embedded file '{s}': {t}", .{ file_path, err });
        return self.fail(file_expression.position, message);
    };
    if (kind == .text and !std.unicode.utf8ValidateSlice(content)) {
        return self.fail(file_expression.position, "embed_text requires valid UTF-8 text");
    }
    try rememberFile(self, file_path);

    if (kind == .text) {
        const result = try self.newValue(builder, .str);
        try self.emit(builder, .{ .constant_str = .{ .result = result, .value = content } });
        return .{ .type = .str, .value = result };
    }
    const result_type = byteListType(self) orelse return error.InvalidSource;
    const result = try self.newValue(builder, result_type);
    try self.emit(builder, .{ .constant_bytes = .{ .result = result, .value = content } });
    return .{ .type = result_type, .value = result };
}

fn fileArgument(self: anytype, call: Ast.Expression.Call, name: []const u8) !*Ast.Expression {
    if (call.arguments.len > 1) {
        const message = try std.fmt.allocPrint(self.allocator, "{s} expects one file path", .{name});
        return self.fail(call.name_position, message);
    }
    var named: ?*Ast.Expression = null;
    for (call.named_arguments, 0..) |argument, index| {
        if (!std.mem.eql(u8, argument.name, "file")) {
            const message = try std.fmt.allocPrint(self.allocator, "unknown {s} option '{s}'", .{ name, argument.name });
            return self.fail(argument.position, message);
        }
        if (call.arguments.len != 0 or index != 0) {
            const message = try std.fmt.allocPrint(self.allocator, "{s} file path is provided more than once", .{name});
            return self.fail(argument.position, message);
        }
        named = argument.value;
    }
    if (call.arguments.len == 1) return call.arguments[0];
    if (named) |value| return value;
    const message = try std.fmt.allocPrint(self.allocator, "{s} expects one file path", .{name});
    return self.fail(call.name_position, message);
}

fn compileTimeString(self: anytype, builder: anytype, expression: *Ast.Expression) ![]const u8 {
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
    return self.fail(expression.position, "embedded file path must be a string known at compile time");
}

fn sourcePath(self: anytype, position: Source.Position) []const u8 {
    if (position.file < self.source_files.len) return self.source_files[position.file];
    return "<source>";
}

fn byteListType(self: anytype) ?Ast.Type {
    for (self.structures, 0..) |structure, index| if (structure.collection) |collection| {
        if (collection.element == .uint8 and collection.length == null and !collection.view) {
            return .structure(index);
        }
    };
    return null;
}

fn rememberFile(self: anytype, path: []const u8) !void {
    for (self.embedded_files.items) |existing| if (std.mem.eql(u8, existing, path)) return;
    try self.embedded_files.append(self.allocator, path);
}
