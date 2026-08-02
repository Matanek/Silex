const std = @import("std");
const Ast = @import("../Ast.zig");
const Ir = @import("../Ir.zig");
const Arguments = @import("Arguments.zig");
const Borrowing = @import("Borrowing.zig");
const Collections = @import("Collections.zig");
const Conversions = @import("Conversions.zig");
const Model = @import("Model.zig");
const MutableReferences = @import("MutableReferences.zig");
const Optionals = @import("Optionals.zig");
const Resources = @import("Resources.zig");
const Support = @import("Support.zig");

pub fn analyzeFunction(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    var total_named: usize = 0;
    var visible: usize = 0;
    var candidates: std.ArrayList(Ir.FunctionId) = .empty;
    var first_problem: ?Arguments.Problem = null;
    var template: ?[]const ?*Ast.Expression = null;
    for (self.program.functions, 0..) |function, function_id| {
        if (!std.mem.eql(u8, function.name, call.name)) continue;
        total_named += 1;
        if (!Support.functionVisible(call, function)) continue;
        visible += 1;
        switch (try Arguments.map(self.allocator, function.parameters, call.arguments, call.named_arguments)) {
            .arguments => |mapped| {
                try candidates.append(self.allocator, function_id);
                if (template == null) template = mapped;
            },
            .problem => |problem| if (first_problem == null) {
                first_problem = problem;
            },
        }
    }
    if (total_named == 0) return self.fail(call.name_position, try std.fmt.allocPrint(self.allocator, "unknown function '{s}'", .{call.name}));
    if (visible == 0) return self.fail(call.name_position, try std.fmt.allocPrint(self.allocator, "function '{s}' is unavailable in this context", .{call.name}));
    if (candidates.items.len == 0) {
        try failProblem(self, call, first_problem.?);
        unreachable;
    }

    const sources = template.?;
    const typed = try self.allocator.alloc(?Model.TypedValue, sources.len);
    @memset(typed, null);
    for (sources, 0..) |maybe_source, index| {
        const source = maybe_source orelse continue;
        const expected = if (candidates.items.len == 1)
            Optionals.expectedContext(self.program.functions[candidates.items[0]].parameters[index].type, source)
        else
            null;
        typed[index] = try self.analyzeExpressionExpected(builder, source, expected);
    }

    var viable: std.ArrayList(Ir.FunctionId) = .empty;
    for (candidates.items) |function_id| {
        const function = self.program.functions[function_id];
        const mapped = (try Arguments.map(self.allocator, function.parameters, call.arguments, call.named_arguments)).arguments;
        for (mapped, 0..) |source, index| {
            if (source != null and Conversions.cost(self, typed[index].?.type, function.parameters[index].type) == null) break;
        } else try viable.append(self.allocator, function_id);
    }
    var resolved: ?Ir.FunctionId = null;
    var nondominated: usize = 0;
    for (viable.items) |candidate_id| {
        var dominated = false;
        for (viable.items) |other_id| {
            if (candidate_id != other_id and dominates(self, self.program.functions[other_id].parameters, self.program.functions[candidate_id].parameters, typed)) {
                dominated = true;
                break;
            }
        }
        if (!dominated) {
            resolved = candidate_id;
            nondominated += 1;
        }
    }
    if (nondominated > 1) return self.fail(call.name_position, try std.fmt.allocPrint(self.allocator, "call to '{s}' is ambiguous", .{call.name}));
    const function_id = resolved orelse {
        if (candidates.items.len == 1) {
            const function = self.program.functions[candidates.items[0]];
            for (sources, typed, 0..) |source, value, index| {
                const expression = source orelse continue;
                if (self.canImplicitlyConvert(value.?.type, function.parameters[index].type)) continue;
                return self.fail(expression.position, try std.fmt.allocPrint(self.allocator, "argument for parameter '{s}' of '{s}' expects '{s}', found '{s}'", .{
                    function.parameters[index].name, call.name, self.typeName(function.parameters[index].type), self.typeName(value.?.type),
                }));
            }
        }
        return self.fail(call.name_position, try std.fmt.allocPrint(self.allocator, "no overload of function '{s}' matches the argument types", .{call.name}));
    };
    const function = self.program.functions[function_id];
    const mapped = (try Arguments.map(self.allocator, function.parameters, call.arguments, call.named_arguments)).arguments;
    try Borrowing.validateMappedReadArguments(self, function.parameters, mapped);
    var ids: std.ArrayList(Ir.ValueId) = .empty;
    const MutableArgument = struct { source: *const Ast.Expression, prepared: MutableReferences.Prepared };
    var mutable: std.ArrayList(MutableArgument) = .empty;
    for (function.parameters, mapped, 0..) |parameter, maybe_source, index| {
        const source = maybe_source orelse {
            try ids.append(self.allocator, (try self.analyzeParameterDefault(builder, parameter)).value);
            continue;
        };
        const argument = typed[index].?;
        if (parameter.mode == .mutable) {
            if (Collections.isViewType(self.structures, parameter.type)) {
                if (argument.borrowed_mode != .mutable) return self.fail(source.position, "mutable view parameter requires an '&T[..]' argument");
                try ids.append(self.allocator, argument.value);
                continue;
            }
            var reused: ?Ir.ValueId = null;
            for (mutable.items) |previous| if (MutableReferences.samePlace(previous.source, source)) {
                reused = previous.prepared.reference;
                break;
            };
            if (reused) |reference| try ids.append(self.allocator, reference) else {
                const prepared = try MutableReferences.prepare(self, builder, source, parameter.type);
                try mutable.append(self.allocator, .{ .source = source, .prepared = prepared });
                try ids.append(self.allocator, prepared.reference);
            }
            continue;
        }
        if (parameter.mode != .read) try Borrowing.requireOwned(self, argument, source.position, "passed by value");
        const converted = try self.coerce(builder, argument, parameter.type, source.position);
        if (parameter.mode == .value and Resources.containsClass(self, parameter.type)) try Resources.retainValue(self, builder, parameter.type, converted.value);
        try ids.append(self.allocator, converted.value);
    }
    const result_type = Collections.loweredBorrowType(self.structures, function.return_mode, function.return_type);
    const result: ?Ir.ValueId = if (function.return_type == .void) null else try self.newValue(builder, result_type);
    try self.emit(builder, .{ .call = .{ .result = result, .function = function_id, .arguments = try ids.toOwnedSlice(self.allocator) } });
    for (mutable.items) |argument| try MutableReferences.writeBack(self, builder, argument.prepared);
    if (result == null) return null;
    if (function.return_mode == .value) return .{ .type = function.return_type, .value = result.?, .transferred = Resources.containsClass(self, function.return_type) };
    const provenance = function.return_provenance.?;
    var parameter_index: ?usize = null;
    for (function.parameters, 0..) |parameter, index| if (std.mem.eql(u8, parameter.name, provenance)) {
        parameter_index = index;
        break;
    };
    const source = mapped[parameter_index.?] orelse return self.fail(call.name_position, "borrowed return cannot originate from a default value");
    const value = typed[parameter_index.?].?;
    const root = value.borrowed_root orelse Borrowing.rootName(source) orelse return self.fail(call.name_position, "borrowed return cannot originate from a temporary");
    return .{ .type = function.return_type, .value = result.?, .borrowed_root = root, .borrowed_mode = function.return_mode };
}

fn failProblem(self: anytype, call: Ast.Expression.Call, problem: Arguments.Problem) !void {
    const message = switch (problem) {
        .too_many => "too many arguments for this call",
        .unknown => |argument| try std.fmt.allocPrint(self.allocator, "unknown parameter label '{s}'", .{argument.name}),
        .duplicate => |argument| try std.fmt.allocPrint(self.allocator, "parameter '{s}' is provided more than once", .{argument.name}),
        .missing => |parameter| try std.fmt.allocPrint(self.allocator, "required parameter '{s}' is missing", .{parameter.name}),
    };
    const position = switch (problem) {
        .unknown => |a| a.position,
        .duplicate => |a| a.position,
        else => call.name_position,
    };
    return self.fail(position, message);
}

fn dominates(self: anytype, better: []const Ast.Parameter, worse: []const Ast.Parameter, arguments: []const ?Model.TypedValue) bool {
    var strictly_better = false;
    for (arguments, 0..) |maybe_argument, index| {
        const argument = maybe_argument orelse continue;
        if (index >= better.len or index >= worse.len) return false;
        const better_cost = Conversions.cost(self, argument.type, better[index].type) orelse return false;
        const worse_cost = Conversions.cost(self, argument.type, worse[index].type) orelse return false;
        if (better_cost > worse_cost) return false;
        if (better_cost < worse_cost) strictly_better = true;
    }
    return strictly_better;
}
