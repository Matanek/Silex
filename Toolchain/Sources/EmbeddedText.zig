const std = @import("std");
const Ast = @import("Ast.zig");
const Model = @import("Semantic/Model.zig");
const Source = @import("Source.zig");

const maximum_text_size = 16 * 1024 * 1024;

pub fn analyze(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    if (call.receiver != null or !std.mem.eql(u8, call.name, "embed_text")) return null;
    if (call.type_arguments.len != 0 or call.safe) {
        return self.fail(call.name_position, "embed_text does not accept type arguments or safe dispatch");
    }
    const file_expression = try fileArgument(self, call);
    const requested = try compileTimeString(self, builder, file_expression);
    if (requested.len == 0) return self.fail(file_expression.position, "embedded text file path cannot be empty");

    const owner_path = sourcePath(self, file_expression.position);
    const owner_directory = std.fs.path.dirname(owner_path) orelse ".";
    const file_path = if (std.fs.path.isAbsolute(requested))
        try self.allocator.dupe(u8, requested)
    else
        try std.fs.path.resolve(self.allocator, &.{ owner_directory, requested });
    const io = self.io orelse return self.fail(file_expression.position, "text embedding is unavailable in this compiler context");
    const content = std.Io.Dir.cwd().readFileAlloc(io, file_path, self.allocator, .limited(maximum_text_size)) catch |err| {
        const message = try std.fmt.allocPrint(self.allocator, "cannot read embedded text '{s}': {t}", .{ file_path, err });
        return self.fail(file_expression.position, message);
    };
    if (!std.unicode.utf8ValidateSlice(content)) {
        return self.fail(file_expression.position, "embed_text requires valid UTF-8 text");
    }
    try rememberFile(self, file_path);

    const result = try self.newValue(builder, .str);
    try self.emit(builder, .{ .constant_str = .{ .result = result, .value = content } });
    return .{ .type = .str, .value = result };
}

fn fileArgument(self: anytype, call: Ast.Expression.Call) !*Ast.Expression {
    if (call.arguments.len > 1) return self.fail(call.name_position, "embed_text expects one file path");
    var named: ?*Ast.Expression = null;
    for (call.named_arguments, 0..) |argument, index| {
        if (!std.mem.eql(u8, argument.name, "file")) {
            const message = try std.fmt.allocPrint(self.allocator, "unknown embed_text option '{s}'", .{argument.name});
            return self.fail(argument.position, message);
        }
        if (call.arguments.len != 0 or index != 0) {
            return self.fail(argument.position, "embed_text file path is provided more than once");
        }
        named = argument.value;
    }
    if (call.arguments.len == 1) return call.arguments[0];
    return named orelse self.fail(call.name_position, "embed_text expects one file path");
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
    return self.fail(expression.position, "embedded text file path must be a string known at compile time");
}

fn sourcePath(self: anytype, position: Source.Position) []const u8 {
    if (position.file < self.source_files.len) return self.source_files[position.file];
    return "<source>";
}

fn rememberFile(self: anytype, path: []const u8) !void {
    for (self.embedded_text_files.items) |existing| if (std.mem.eql(u8, existing, path)) return;
    try self.embedded_text_files.append(self.allocator, path);
}
