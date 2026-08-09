const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");

const Error = Source.Error || std.mem.Allocator.Error || error{WorkerUnsafe};

const Binding = struct {
    name: []const u8,
    type: Ast.Type,
};

pub fn validateSubmission(
    self: anytype,
    executor_type: Ast.Type,
    template: Ast.Function,
    arguments: []const Ast.Type,
    position: Source.Position,
) Error!void {
    _ = position;
    const contract = submissionContract(self, template) orelse return;
    if (arguments.len < 1) return;
    const executor_index = executor_type.structureIndex() orelse return;
    if (executor_index >= self.structures.items.len) return;
    const executor = self.structures.items[executor_index];
    if (!isExecutorName(executor.name)) return;

    const job_index = arguments[0].structureIndex() orelse return self.fail(
        template.name_position,
        if (contract == .parallel)
            "STD.Threading.Executor.submit_parallel requires a concrete worker-safe ParallelJob"
        else
            "STD.Threading.Executor.submit requires a concrete worker-safe Job",
    );
    if (job_index >= self.structures.items.len) return error.InvalidSource;
    const job = self.structures.items[job_index];

    // GFX submits this compiler-fed envelope only after its generated access
    // descriptor has classified the actual system callback. The dynamic
    // callback stored by the envelope is therefore not a user-controlled
    // worker-safety escape hatch.
    if (std.mem.eql(u8, job.name, "GFX.Application.SystemJob")) return;

    if (try containsExecutor(self, arguments[0], &.{})) |capture_position| {
        const message = try std.fmt.allocPrint(
            self.allocator,
            "job '{s}' cannot own or capture 'Executor'",
            .{shortName(job.name)},
        );
        return self.fail(capture_position, message);
    }

    const execute = for (job.methods) |method| {
        if (!std.mem.eql(u8, method.name, "execute") or method.is_static) continue;
        if (contract == .job and method.parameters.len == 0) break method;
        if (contract == .parallel and method.parameters.len == 2 and method.parameters[0].type == .int and method.parameters[1].type == .int) break method;
    } else return self.fail(
        job.name_position,
        if (contract == .parallel)
            "ParallelJob must implement 'func execute(start:int, end:int)'"
        else
            "Job must implement 'func execute()'",
    );

    var checker = Checker(@TypeOf(self.*)){
        .self = self,
        .parallel = contract == .parallel,
        .subject_name = shortName(job.name),
        .diagnose = true,
    };
    checker.validateMethod(job_index, execute) catch |err| switch (err) {
        error.WorkerUnsafe => return error.InvalidSource,
        else => return err,
    };
    checker.validateTypeDrop(arguments[0]) catch |err| switch (err) {
        error.WorkerUnsafe => return error.InvalidSource,
        else => return err,
    };
}

pub fn systemIsWorkerSafe(self: anytype, target_name: []const u8, target_position: Source.Position) std.mem.Allocator.Error!bool {
    const target = findSystemFunction(self.functions.items, target_name, target_position) orelse
        findSystemFunction(self.source.functions, target_name, target_position) orelse return false;

    if (std.mem.startsWith(u8, target.name, "GFX.Window.") or
        std.mem.startsWith(u8, target.name, "GFX.Rendering.GPU.")) return false;

    var checker = Checker(@TypeOf(self.*)){
        .self = self,
        .parallel = false,
        .subject_name = shortName(target.name),
        .diagnose = false,
    };
    checker.validateFunction(target) catch |err| {
        if (err == error.OutOfMemory) return error.OutOfMemory;
        return false;
    };
    return true;
}

fn Checker(comptime Self: type) type {
    return struct {
        self: *Self,
        parallel: bool,
        subject_name: []const u8,
        diagnose: bool,
        visited_functions: std.ArrayList(Source.Position) = .empty,
        visited_methods: std.ArrayList(Source.Position) = .empty,
        visited_drops: std.ArrayList(Ast.Type) = .empty,

        const This = @This();

        fn validateMethod(checker: *This, owner: usize, method: Ast.Function) Error!void {
            if (visited(checker.visited_methods.items, method.name_position)) return;
            try checker.visited_methods.append(checker.self.allocator, method.name_position);
            var bindings: std.ArrayList(Binding) = .empty;
            try bindings.append(checker.self.allocator, .{ .name = "self", .type = .structure(owner) });
            for (method.parameters) |parameter| {
                if (isExecutor(checker.self, parameter.type)) return checker.reject(
                    parameter.position,
                    "receive an Executor",
                );
                try bindings.append(checker.self.allocator, .{ .name = parameter.name, .type = parameter.type });
            }
            try checker.validateStatements(method.statements, &bindings, false);
        }

        fn validateFunction(checker: *This, function: Ast.Function) Error!void {
            if (visited(checker.visited_functions.items, function.name_position)) return;
            try checker.visited_functions.append(checker.self.allocator, function.name_position);
            var bindings: std.ArrayList(Binding) = .empty;
            for (function.parameters) |parameter| {
                if (isExecutor(checker.self, parameter.type)) return checker.reject(
                    parameter.position,
                    "pass an Executor through its worker call graph",
                );
                try bindings.append(checker.self.allocator, .{ .name = parameter.name, .type = parameter.type });
            }
            try checker.validateStatements(function.statements, &bindings, false);
        }

        fn validateStatements(
            checker: *This,
            statements: []const Ast.Statement,
            bindings: *std.ArrayList(Binding),
            synchronized: bool,
        ) Error!void {
            for (statements) |statement| switch (statement) {
                .variable_declaration => |declaration| {
                    if (declaration.initializer) |value| try checker.validateExpression(value, bindings, synchronized);
                    if (declaration.annotation) |type_value| try bindings.append(
                        checker.self.allocator,
                        .{ .name = declaration.name, .type = type_value },
                    );
                },
                .assignment_statement => |assignment| {
                    if (!synchronized and staticMutation(checker.self, assignment.target)) {
                        const target_name = if (assignment.target.fields.len == 0)
                            assignment.target.name
                        else
                            try std.fmt.allocPrint(
                                checker.self.allocator,
                                "{s}.{s}",
                                .{ assignment.target.name, assignment.target.fields[0].name },
                            );
                        return checker.unsafe(
                            assignment.target.name_position,
                            try std.fmt.allocPrint(checker.self.allocator, "static mutation '{s}' is unsynchronized", .{target_name}),
                        );
                    }
                    for (assignment.target.indices) |index| try checker.validateExpression(index.value, bindings, synchronized);
                    if (assignment.value) |value| try checker.validateExpression(value, bindings, synchronized);
                },
                .return_statement => |returned| if (returned.value) |value| try checker.validateExpression(value, bindings, synchronized),
                .expression_statement => |expression| try checker.validateExpression(expression, bindings, synchronized),
                .print_statement => |effect| {
                    return checker.unsafe(effect.position, "print requires the main thread");
                },
                .assert_statement => |effect| {
                    try checker.validateExpression(effect.condition, bindings, synchronized);
                    try checker.validateExpression(effect.message, bindings, synchronized);
                },
                .panic_statement => |effect| try checker.validateExpression(effect.value, bindings, synchronized),
                .if_statement => |conditional| {
                    for (conditional.branches) |branch| {
                        try checker.validateExpression(branch.condition.source(), bindings, synchronized);
                        try checker.validateStatements(branch.statements, bindings, synchronized);
                    }
                    if (conditional.else_statements) |body| try checker.validateStatements(body, bindings, synchronized);
                },
                .while_statement => |loop| {
                    try checker.validateExpression(loop.condition.source(), bindings, synchronized);
                    try checker.validateStatements(loop.statements, bindings, synchronized);
                },
                .for_statement => |loop| {
                    switch (loop.source) {
                        .collection => |collection| try checker.validateExpression(collection, bindings, synchronized),
                        .range => |range| {
                            try checker.validateExpression(range.start, bindings, synchronized);
                            try checker.validateExpression(range.end, bindings, synchronized);
                        },
                    }
                    try checker.validateStatements(loop.statements, bindings, synchronized);
                },
                .mutex_statement => |mutex| try checker.validateStatements(mutex.statements, bindings, true),
                .break_statement, .continue_statement => {},
            };
        }

        fn validateExpression(
            checker: *This,
            expression: *const Ast.Expression,
            bindings: *std.ArrayList(Binding),
            synchronized: bool,
        ) Error!void {
            switch (expression.value) {
                .call => |call| try checker.validateCall(call, bindings, synchronized),
                .cascade => |cascade| {
                    try checker.validateExpression(cascade.receiver, bindings, synchronized);
                    for (cascade.operations) |operation| switch (operation) {
                        .method_call => |method| {
                            if (inferType(checker.self, cascade.receiver, bindings.items)) |receiver_type| {
                                if (checker.parallel and structuralCollectionMutation(checker.self, receiver_type, method.name)) {
                                    return checker.reject(method.name_position, "mutate collection structure from a ParallelJob");
                                }
                                if (workerMethodPolicy(checker.self, receiver_type, method.name) == .reject) {
                                    return checker.reject(method.name_position, "call an Executor or JobHandle operation");
                                }
                            }
                            for (method.arguments) |argument| try checker.validateExpression(argument, bindings, synchronized);
                            for (method.named_arguments) |argument| try checker.validateExpression(argument.value, bindings, synchronized);
                        },
                        .field_assignment => |assignment| try checker.validateExpression(assignment.value, bindings, synchronized),
                    };
                },
                .field_access => |access| try checker.validateExpression(access.base, bindings, synchronized),
                .unary => |unary| try checker.validateExpression(unary.operand, bindings, synchronized),
                .binary => |binary| {
                    try checker.validateExpression(binary.left, bindings, synchronized);
                    try checker.validateExpression(binary.right, bindings, synchronized);
                },
                .conversion => |conversion| try checker.validateExpression(conversion.operand, bindings, synchronized),
                .string_count => |value| try checker.validateExpression(value, bindings, synchronized),
                .sequence_literal => |sequence| for (sequence.values) |value| try checker.validateExpression(value, bindings, synchronized),
                .tuple_literal => |tuple| for (tuple.elements) |element| try checker.validateExpression(element.value, bindings, synchronized),
                .index_access => |access| {
                    try checker.validateExpression(access.base, bindings, synchronized);
                    try checker.validateExpression(access.index, bindings, synchronized);
                },
                .slice_access => |access| {
                    try checker.validateExpression(access.base, bindings, synchronized);
                    try checker.validateExpression(access.start, bindings, synchronized);
                    try checker.validateExpression(access.end, bindings, synchronized);
                },
                .match_expression => |match| {
                    try checker.validateExpression(match.subject, bindings, synchronized);
                    for (match.branches) |branch| {
                        if (branch.value) |value| try checker.validateExpression(value, bindings, synchronized);
                        if (branch.statements) |body| try checker.validateStatements(body, bindings, synchronized);
                    }
                },
                .interpolated_string => |string| for (string.parts) |part| switch (part) {
                    .text => {},
                    .expression => |value| try checker.validateExpression(value, bindings, synchronized),
                },
                else => {},
            }
        }

        fn validateCall(
            checker: *This,
            call: Ast.Expression.Call,
            bindings: *std.ArrayList(Binding),
            synchronized: bool,
        ) Error!void {
            if (call.receiver) |receiver| try checker.validateExpression(receiver, bindings, synchronized);
            for (call.arguments) |argument| try checker.validateExpression(argument, bindings, synchronized);
            for (call.named_arguments) |argument| try checker.validateExpression(argument.value, bindings, synchronized);

            if (call.receiver == null) for (checker.self.structures.items) |structure| {
                if (isExecutorName(structure.name) and nameMatches(structure.name, call.name)) {
                    return checker.reject(call.name_position, "construct an Executor on a worker");
                }
            };

            if (call.receiver) |receiver| {
                const receiver_type = inferType(checker.self, receiver, bindings.items) orelse return checker.reject(
                    call.name_position,
                    "use a dispatch whose target cannot be proven worker-safe",
                );
                const owner = receiver_type.structureIndex() orelse return;
                if (owner >= checker.self.structures.items.len) return error.InvalidSource;
                const structure = checker.self.structures.items[owner];
                if (checker.parallel and structuralCollectionMutation(checker.self, receiver_type, call.name)) {
                    return checker.reject(call.name_position, "mutate collection structure from a ParallelJob");
                }
                switch (workerMethodPolicy(checker.self, receiver_type, call.name)) {
                    .allow_boundary => return,
                    .reject => return checker.reject(call.name_position, "call an Executor or JobHandle operation"),
                    .inspect => {},
                }
                if (structure.collection != null or receiver_type == .str) return;
                if (structure.is_protocol) return checker.reject(call.name_position, "use dynamic protocol dispatch");
                var selected: ?Ast.Function = null;
                for (structure.methods) |method| {
                    if (!std.mem.eql(u8, method.name, call.name) or method.parameters.len != call.arguments.len + call.named_arguments.len) continue;
                    if (selected != null) return checker.reject(call.name_position, "use ambiguous method dispatch");
                    selected = method;
                }
                const method = selected orelse return checker.reject(call.name_position, "call an unknown worker method");
                return checker.validateMethod(owner, method);
            }

            for (checker.self.functions.items) |function| {
                if (!nameMatches(function.name, call.name) or function.parameters.len != call.arguments.len + call.named_arguments.len) continue;
                return checker.validateFunction(function);
            }
            for (checker.self.source.functions) |function| {
                if (!nameMatches(function.name, call.name) or function.parameters.len != call.arguments.len + call.named_arguments.len) continue;
                return checker.validateFunction(function);
            }
            for (checker.self.structures.items, 0..) |structure, owner| if (nameMatches(structure.name, call.name)) {
                for (structure.constructors) |constructor| {
                    if (constructor.parameters.len != call.arguments.len + call.named_arguments.len) continue;
                    var constructor_bindings: std.ArrayList(Binding) = .empty;
                    try constructor_bindings.append(checker.self.allocator, .{ .name = "self", .type = .structure(owner) });
                    for (constructor.parameters) |parameter| try constructor_bindings.append(
                        checker.self.allocator,
                        .{ .name = parameter.name, .type = parameter.type },
                    );
                    try checker.validateStatements(constructor.statements, &constructor_bindings, false);
                    try checker.validateTypeDrop(.structure(owner));
                    return;
                }
            };
            for (checker.self.source.external_functions) |external| if (nameMatches(external.name, call.name)) {
                if (workerSafeExternal(external.source_name)) return;
                return checker.unsafe(
                    call.name_position,
                    try std.fmt.allocPrint(checker.self.allocator, "external call '{s}' is not classified", .{external.source_name}),
                );
            };
            return checker.reject(call.name_position, "use a callback or call target that cannot be proven worker-safe");
        }

        fn validateTypeDrop(checker: *This, type_value: Ast.Type) Error!void {
            const concrete = type_value.optionalChild() orelse type_value;
            const index = concrete.structureIndex() orelse return;
            for (checker.visited_drops.items) |known| if (known == concrete) return;
            try checker.visited_drops.append(checker.self.allocator, concrete);
            if (index < checker.self.structures.items.len) {
                const structure = checker.self.structures.items[index];
                if (structure.drop) |drop| {
                    var bindings: std.ArrayList(Binding) = .empty;
                    try bindings.append(checker.self.allocator, .{ .name = "self", .type = concrete });
                    try checker.validateStatements(drop.statements, &bindings, false);
                }
                for (structure.fields) |field| try checker.validateTypeDrop(field.type);
                if (structure.collection) |collection| try checker.validateTypeDrop(collection.element);
                return;
            }
            const enum_index = index - checker.self.structures.items.len;
            if (enum_index >= checker.self.enums.items.len) return;
            for (checker.self.enums.items[enum_index].variants) |variant| {
                for (variant.associated_types) |associated| try checker.validateTypeDrop(associated);
            }
        }

        fn reject(checker: *This, position: Source.Position, action: []const u8) Error!void {
            return checker.unsafe(
                position,
                try std.fmt.allocPrint(checker.self.allocator, "cannot {s}", .{action}),
            );
        }

        fn unsafe(checker: *This, position: Source.Position, reason: []const u8) Error!void {
            if (!checker.diagnose) return error.WorkerUnsafe;
            const message = try std.fmt.allocPrint(
                checker.self.allocator,
                "job '{s}' is not worker-safe: {s}",
                .{ checker.subject_name, reason },
            );
            return checker.self.fail(position, message);
        }
    };
}

fn containsExecutor(self: anytype, type_value: Ast.Type, visited_types: []const Ast.Type) Error!?Source.Position {
    const concrete = type_value.optionalChild() orelse type_value;
    if (isExecutor(self, concrete)) return null;
    for (visited_types) |visited_type| if (visited_type == concrete) return null;
    const index = concrete.structureIndex() orelse return null;
    var nested = try std.ArrayList(Ast.Type).initCapacity(self.allocator, visited_types.len + 1);
    nested.appendSliceAssumeCapacity(visited_types);
    nested.appendAssumeCapacity(concrete);
    if (index < self.structures.items.len) {
        const structure = self.structures.items[index];
        for (structure.fields) |field| {
            if (isExecutor(self, field.type)) return field.name_position;
            if (try containsExecutor(self, field.type, nested.items)) |captured| return captured;
        }
        if (structure.collection) |collection| {
            if (isExecutor(self, collection.element)) return structure.name_position;
            if (try containsExecutor(self, collection.element, nested.items)) |captured| return captured;
        }
        return null;
    }
    const enum_index = index - self.structures.items.len;
    if (enum_index < self.enums.items.len) {
        const enumeration = self.enums.items[enum_index];
        for (enumeration.variants) |variant| for (variant.associated_types) |associated| {
            if (isExecutor(self, associated)) return variant.position;
            if (try containsExecutor(self, associated, nested.items)) |captured| return captured;
        };
    }
    return null;
}

fn inferType(self: anytype, expression: *const Ast.Expression, bindings: []const Binding) ?Ast.Type {
    return switch (expression.value) {
        .identifier => |name| for (bindings) |binding| {
            if (std.mem.eql(u8, binding.name, name)) break binding.type;
        } else for (self.structures.items, 0..) |structure, index| {
            if (nameMatches(structure.name, name)) break Ast.Type.structure(index);
        } else null,
        .field_access => |access| field: {
            const base = inferType(self, access.base, bindings) orelse break :field null;
            const index = base.structureIndex() orelse break :field null;
            if (index >= self.structures.items.len) break :field null;
            for (self.structures.items[index].fields) |candidate| {
                if (std.mem.eql(u8, candidate.name, access.name)) break :field candidate.type;
            }
            break :field null;
        },
        .conversion => |conversion| conversion.target,
        else => null,
    };
}

fn staticMutation(self: anytype, target: Ast.AssignmentTarget) bool {
    for (self.structures.items) |structure| {
        if (nameMatches(structure.name, target.name) and target.fields.len != 0) {
            for (structure.static_fields) |field| if (std.mem.eql(u8, field.name, target.fields[0].name)) return true;
        }
        for (structure.static_fields) |field| if (target.fields.len == 0 and std.mem.eql(u8, field.name, target.name)) return true;
    }
    return false;
}

fn isExecutor(self: anytype, type_value: Ast.Type) bool {
    const concrete = type_value.optionalChild() orelse type_value;
    const index = concrete.structureIndex() orelse return false;
    return index < self.structures.items.len and isExecutorName(self.structures.items[index].name);
}

fn isExecutorName(name: []const u8) bool {
    return std.mem.eql(u8, shortName(name), "Executor");
}

const SubmissionContract = enum { job, parallel };

fn submissionContract(self: anytype, template: Ast.Function) ?SubmissionContract {
    if (template.type_parameters.len != 1) return null;
    if (!std.mem.eql(u8, template.name, "submit") and !std.mem.eql(u8, template.name, "submit_parallel")) return null;
    const constraint = template.type_parameters[0].constraint orelse return null;
    const index = constraint.structureIndex() orelse return null;
    const name = if (index < self.structures.items.len)
        shortName(self.structures.items[index].name)
    else if (index < self.source.structures.len)
        shortName(self.source.structures[index].name)
    else
        return null;
    if (std.mem.eql(u8, name, "Job") and std.mem.eql(u8, template.name, "submit")) return .job;
    if (std.mem.eql(u8, name, "ParallelJob") and std.mem.eql(u8, template.name, "submit_parallel")) return .parallel;
    return null;
}

const WorkerMethodPolicy = enum { inspect, allow_boundary, reject };

fn workerMethodPolicy(self: anytype, receiver_type: Ast.Type, name: []const u8) WorkerMethodPolicy {
    const concrete = receiver_type.optionalChild() orelse receiver_type;
    const index = concrete.structureIndex() orelse return .inspect;
    if (index >= self.structures.items.len) return .inspect;
    const owner = shortName(self.structures.items[index].name);
    if (isExecutorName(owner) and (std.mem.eql(u8, name, "submit") or std.mem.startsWith(u8, name, "submit<") or std.mem.eql(u8, name, "submit_parallel") or std.mem.startsWith(u8, name, "submit_parallel<") or std.mem.eql(u8, name, "complete"))) {
        return .reject;
    }
    if ((std.mem.eql(u8, owner, "JobHandle") or std.mem.startsWith(u8, owner, "JobHandle<")) and std.mem.eql(u8, name, "complete")) {
        return .reject;
    }
    if (std.mem.eql(u8, owner, "Fence") and (std.mem.eql(u8, name, "complete") or std.mem.eql(u8, name, "is_complete"))) {
        return .allow_boundary;
    }
    return .inspect;
}

fn structuralCollectionMutation(self: anytype, receiver_type: Ast.Type, name: []const u8) bool {
    const index = receiver_type.structureIndex() orelse return false;
    if (index >= self.structures.items.len or self.structures.items[index].collection == null) return false;
    const mutations = [_][]const u8{ "append", "prepend", "insert", "remove", "remove_at", "clear", "take", "take_first", "reserve" };
    for (mutations) |mutation| if (std.mem.eql(u8, name, mutation)) return true;
    return false;
}

fn workerSafeExternal(name: []const u8) bool {
    const approved = [_][]const u8{
        "clock_gettime_nsec_np",   "arc4random",                "sysconf",
        "dispatch_semaphore_wait", "dispatch_semaphore_signal", "sin",
        "cos",                     "tan",                       "asin",
        "acos",                    "atan",                      "atan2",
        "sinh",                    "cosh",                      "tanh",
        "asinh",                   "acosh",                     "atanh",
        "exp",                     "exp2",                      "log",
        "log2",                    "log10",                     "pow",
        "sqrt",                    "cbrt",                      "hypot",
        "floor",                   "ceil",                      "round",
        "trunc",                   "fmod",                      "remainder",
        "copysign",                "pthread_self",
    };
    for (approved) |candidate| if (std.mem.eql(u8, candidate, name)) return true;
    return false;
}

fn nameMatches(candidate: []const u8, requested: []const u8) bool {
    if (std.mem.eql(u8, candidate, requested)) return true;
    if (candidate.len <= requested.len or !std.mem.endsWith(u8, candidate, requested)) return false;
    return candidate[candidate.len - requested.len - 1] == '.';
}

fn shortName(name: []const u8) []const u8 {
    const separator = std.mem.lastIndexOfScalar(u8, name, '.') orelse return name;
    return name[separator + 1 ..];
}

fn visited(positions: []const Source.Position, position: Source.Position) bool {
    for (positions) |known| if (known.file == position.file and known.offset == position.offset) return true;
    return false;
}

fn findSystemFunction(functions: []const Ast.Function, name: []const u8, position: Source.Position) ?Ast.Function {
    for (functions) |function| if (std.mem.eql(u8, function.name, name)) return function;
    for (functions) |function| {
        if (function.position.file == position.file and nameMatches(function.name, name)) return function;
    }
    for (functions) |function| if (nameMatches(function.name, name)) return function;
    return null;
}
