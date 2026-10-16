const std = @import("std");
const Ast = @import("../Ast.zig");
const Model = @import("Model.zig");
const Optionals = @import("Optionals.zig");

const AnalyzeError = error{ InvalidSource, OutOfMemory };

pub const Scope = struct {
    owner: usize,
    module: ?[]const u8,
    member: ?usize = null,
    extension: bool = false,
    specialization_file: ?usize = null,
};

fn moduleName(name: []const u8) ?[]const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, name, '.') orelse return null;
    return name[0..separator];
}

fn register(self: anytype, parameters: []const Ast.Parameter, scope: Scope) !void {
    for (parameters) |parameter| if (parameter.default) |expression| {
        try self.default_scopes.put(self.allocator, expression, scope);
    };
}

pub fn prepare(self: anytype) !void {
    self.default_scopes.clearRetainingCapacity();
    for (self.program.functions) |function| {
        try register(self, function.parameters, .{
            .owner = function.owner,
            .module = moduleName(function.name),
            .specialization_file = function.specialization_file,
        });
    }
    for (self.program.structures) |structure| {
        const member = self.structureIndex(structure.name);
        for (structure.constructors) |constructor| {
            try register(self, constructor.parameters, .{
                .owner = structure.owner,
                .module = null,
                .member = member,
                .specialization_file = constructor.specialization_file,
            });
        }
        for (structure.methods) |method| {
            try register(self, method.parameters, .{
                .owner = method.owner,
                .module = if (method.extension) |extension| extension.provider else null,
                .member = member,
                .extension = method.extension != null,
                .specialization_file = method.specialization_file,
            });
        }
    }
}

pub fn validate(self: anytype) AnalyzeError!void {
    for (self.program.functions) |function| {
        if (function.specialization_file == null) try validateParameters(self, function.parameters);
    }
    for (self.program.structures) |structure| {
        for (structure.constructors) |constructor| {
            if (constructor.specialization_file == null) try validateParameters(self, constructor.parameters);
        }
        for (structure.methods) |method| {
            if (method.specialization_file == null) try validateParameters(self, method.parameters);
        }
    }
}

fn validateParameters(self: anytype, parameters: []const Ast.Parameter) AnalyzeError!void {
    var builder: Model.FunctionBuilder = .{};
    try builder.blocks.append(self.allocator, .{});
    for (parameters) |parameter| {
        if (parameter.mode == .mutable and parameter.default != null) {
            return self.fail(parameter.position, "a mutable-reference parameter cannot have a default value");
        }
        if (parameter.default == null) continue;
        _ = try analyze(self, &builder, parameter);
    }
}

pub fn analyze(
    self: anytype,
    builder: *Model.FunctionBuilder,
    parameter: Ast.Parameter,
) AnalyzeError!Model.TypedValue {
    const expression = parameter.default orelse return error.InvalidSource;
    const scope = self.default_scopes.get(expression) orelse return error.InvalidSource;
    const previous_owner = self.owner_context;
    const previous_module = self.module_context;
    const previous_member = self.member_context;
    const previous_extension = self.extension_context;
    const previous_specialization = self.specialization_file;
    self.owner_context = scope.owner;
    self.module_context = scope.module;
    self.member_context = scope.member;
    self.extension_context = scope.extension;
    self.specialization_file = scope.specialization_file;
    defer {
        self.owner_context = previous_owner;
        self.module_context = previous_module;
        self.member_context = previous_member;
        self.extension_context = previous_extension;
        self.specialization_file = previous_specialization;
    }
    for (self.default_expansions.items) |active| {
        if (active == expression) {
            return self.fail(expression.position, "default parameter expansion is recursive");
        }
    }
    try self.default_expansions.append(self.allocator, expression);
    defer _ = self.default_expansions.pop();
    const caller_bindings = builder.bindings;
    const caller_return_type = builder.return_type;
    builder.bindings = .empty;
    builder.return_type = null;
    defer {
        builder.bindings = caller_bindings;
        builder.return_type = caller_return_type;
    }
    var value = try self.analyzeExpressionExpected(
        builder,
        expression,
        Optionals.expectedContext(parameter.type, expression),
    );
    if (value.type != parameter.type and self.canImplicitlyConvert(value.type, parameter.type)) {
        value = try self.coerce(builder, value, parameter.type, expression.position);
    }
    if (value.type != parameter.type) {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "default for parameter '{s}' expects '{s}', found '{s}'",
            .{ parameter.name, self.typeName(parameter.type), self.typeName(value.type) },
        );
        return self.fail(expression.position, message);
    }
    return value;
}

test "parameter defaults retain declaration visibility for package enums" {
    const Compiler = @import("../Project.zig").Compiler;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data =
        \\package enum Mode { ready; other }
        \\func choose(mode:Mode = Mode.ready) bool {return mode==Mode.ready}
        \\package class Box {
        \\    var mode:Mode
        \\    init(mode:Mode = Mode.ready) {self.mode=mode}
        \\    func read(mode:Mode = Mode.ready) bool {return mode==self.mode}
        \\    static func check(mode:Mode = Mode.ready) bool {return mode==Mode.ready}
        \\}
        \\func main() {var box=Box();assert(choose() && box.read() && Box.check())}
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const result = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}
