const std = @import("std");
const Ast = @import("../Ast.zig");
const Source = @import("../Source.zig");
const Methods = @import("Methods.zig");

pub fn materialize(self: anytype, source: Ast.Program) !Ast.Program {
    if (!@import("../ProtocolDefaults.zig").present(source)) return source;
    var expansion = @import("../ProtocolDefaults.zig").Expander{ .allocator = self.allocator };
    var result = expansion.expand(source) catch |err| {
        self.diagnostic = expansion.diagnostic;
        return err;
    };
    var structures: std.ArrayList(Ast.Structure) = .empty;
    try structures.appendSlice(self.allocator, result.structures);
    var names: std.ArrayList([]const u8) = .empty;
    try names.appendSlice(self.allocator, result.type_names);
    var functions: std.ArrayList(Ast.Function) = .empty;
    try functions.appendSlice(self.allocator, result.functions);
    const original_count = structures.items.len;
    for (0..original_count) |index| {
        structures.items[index].methods = try self.allocator.dupe(Ast.Function, structures.items[index].methods);
        if (!structures.items[index].is_protocol) continue;
        const protocol = structures.items[index];
        for (protocol.methods, 0..) |requirement, method_index| {
            if (!requirement.protocol_default) continue;
            if (requirement.return_mode != .value) return self.fail(requirement.name_position, "default protocol methods cannot return '@T' or '&T'");
            if (requirement.return_type != .void) {
                const name = try std.fmt.allocPrint(self.allocator, "{s}.$default$result{d}", .{ protocol.name, method_index });
                const fields = try self.allocator.alloc(Ast.StructureField, 2);
                fields[0] = .{ .position = requirement.position, .name_position = requirement.position, .name = "self", .type = Ast.Type.structure(index), .mutable = true, .default = null };
                fields[1] = .{ .position = requirement.position, .name_position = requirement.position, .name = "value", .type = requirement.return_type, .mutable = true, .default = null };
                const result_type = Ast.Type.structure(names.items.len);
                try names.append(self.allocator, name);
                try structures.append(self.allocator, .{ .name = name, .position = requirement.position, .name_position = requirement.position, .owner = protocol.owner, .is_internal = true, .fields = fields });
                @constCast(structures.items[index].methods)[method_index].protocol_result = result_type;
            }
            var helper = requirement;
            helper.protocol_default = false;
            helper.protocol_body = .{ .protocol = protocol.name, .method = method_index };
            helper.name = try std.fmt.allocPrint(self.allocator, "{s}.$default$body{d}", .{ protocol.name, method_index });
            helper.is_public = false;
            helper.is_internal = true;
            helper.is_private = false;
            helper.is_local = false;
            const parameters = try self.allocator.alloc(Ast.Parameter, requirement.parameters.len + 1);
            parameters[0] = .{ .position = requirement.position, .name = "$self", .type = Ast.Type.structure(index) };
            @memcpy(parameters[1..], requirement.parameters);
            helper.parameters = parameters;
            try functions.append(self.allocator, helper);
        }
    }
    result.structures = try structures.toOwnedSlice(self.allocator);
    result.type_names = try names.toOwnedSlice(self.allocator);
    result.functions = try functions.toOwnedSlice(self.allocator);
    return result;
}

pub fn prepare(self: anytype) !void {
    if (!@import("../ProtocolDefaults.zig").present(self.program)) return;
    // These arrays are owned copies made by materialize. Keep the source
    // signature logical while exposing the already-lowered helper ABI only
    // to generated witness calls.
    for (@constCast(self.program.functions)) |*function| if (function.protocol_body) |origin| {
        const protocol_index = self.structureIndex(origin.protocol) orelse return error.InvalidSource;
        const method = self.program.structures[protocol_index].methods[origin.method];
        const flat = Methods.flatMethodIndex(self.program, protocol_index, origin.method);
        function.return_type = Methods.methodIrReturnType(self, protocol_index, flat, method);
        @constCast(function.parameters)[0].mode = if (self.method_mutability[flat]) .value else .read;
    };
    for (@constCast(self.program.structures)) |*structure| {
        for (@constCast(structure.methods)) |*method| if (method.protocol_witness) |origin| {
            const protocol_index = self.structureIndex(origin.protocol) orelse return error.InvalidSource;
            const prototype = self.program.structures[protocol_index].methods[origin.method];
            const flat = Methods.flatMethodIndex(self.program, protocol_index, origin.method);
            const mutating = self.method_mutability[flat];
            var helper_id: ?usize = null;
            for (self.program.functions, 0..) |function, index| if (function.protocol_body) |body| {
                if (std.mem.eql(u8, origin.protocol, body.protocol) and origin.method == body.method) {
                    helper_id = index;
                    break;
                }
            };
            const helper = self.program.functions[helper_id orelse return error.InvalidSource];
            const position = prototype.name_position;
            const arguments = try self.allocator.alloc(*Ast.Expression, method.parameters.len + 1);
            arguments[0] = try node(self.allocator, position, .{ .identifier = "self" });
            for (method.parameters, 1..) |parameter, index| arguments[index] = try node(self.allocator, position, .{ .identifier = parameter.name });
            const call = try node(self.allocator, position, .{ .call = .{ .name = helper.name, .name_position = position, .compiler_generated = true, .owner = prototype.owner, .capture_result = @import("Try.zig").findResult(self.enums, helper.return_type) != null, .arguments = arguments } });
            var statements: std.ArrayList(Ast.Statement) = .empty;
            var value: ?*Ast.Expression = null;
            if (mutating) {
                try statements.append(self.allocator, .{ .variable_declaration = .{ .position = position, .name_position = position, .name = "$default$result", .mutable = true, .annotation = null, .initializer = call } });
                const output = try node(self.allocator, position, .{ .identifier = "$default$result" });
                const receiver = if (method.return_type == .void) output else try field(self.allocator, position, output, "self");
                const concrete = try node(self.allocator, position, .{ .conversion = .{ .operand = receiver, .target = Ast.Type.structure(self.structureIndex(structure.name) orelse return error.InvalidSource), .operator_position = position, .protocol_witness = true } });
                try statements.append(self.allocator, .{ .assignment_statement = .{ .position = position, .target = .{ .name = "self", .name_position = position }, .operator = .assign, .value = concrete } });
                if (method.return_type != .void) value = try field(self.allocator, position, output, "value");
            } else if (method.return_type == .void) {
                try statements.append(self.allocator, .{ .expression_statement = call });
            } else value = call;
            try statements.append(self.allocator, .{ .return_statement = .{ .position = position, .value = value } });
            method.statements = try statements.toOwnedSlice(self.allocator);
        };
    }
}

fn node(allocator: std.mem.Allocator, position: Source.Position, value: @FieldType(Ast.Expression, "value")) !*Ast.Expression {
    const expression = try allocator.create(Ast.Expression);
    expression.* = .{ .position = position, .value = value };
    return expression;
}

fn field(allocator: std.mem.Allocator, position: Source.Position, base: *Ast.Expression, name: []const u8) !*Ast.Expression {
    return node(allocator, position, .{ .field_access = .{ .base = base, .name = name, .name_position = position } });
}

fn verify(code: []const u8, expected: []const u8) !void {
    return verifyProvider(code, expected, null, null);
}

fn verifyProvider(code: []const u8, expected: []const u8, provider: ?[]const u8, expected_error: ?[]const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    if (provider) |source| {
        try temporary.dir.createDirPath(std.testing.io, "Api/Module");
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package.json", .data = "{\"sources\":\".\",\"dependencies\":{\"Api\":\"=1.0.0\"}}" });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Package.json", .data = "{\"name\":\"Api\",\"version\":\"1.0.0\"}" });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Module/@Api.sx", .data = source });
    } else try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package.json", .data = "{\"sources\":\".\"}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = code });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = @import("../Project.zig").Compiler.init(allocator, std.testing.io);
    const compilation = compiler.compile(input) catch |err| {
        if (expected_error) |message| {
            if (err != error.InvalidSource) return err;
            const diagnostic = compiler.diagnostic orelse return error.TestUnexpectedResult;
            try std.testing.expect(std.mem.indexOf(u8, diagnostic.message, message) != null);
            return;
        }
        if (compiler.diagnostic) |diagnostic| std.debug.print("{d}:{d} {s}\n", .{ diagnostic.position.line, diagnostic.position.column, diagnostic.message });
        return err;
    };
    if (expected_error != null) return error.TestUnexpectedResult;
    const outcome = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings(expected, outcome.stdout);
    try std.testing.expectEqual(@as(u8, 0), outcome.exit_code);
}

test "protocol defaults preserve absence overrides nominal calls and generic inference" {
    try verify(
        \\protocol Reading {
        \\    func seed(label:int) int
        \\    func optional() int? { return null }
        \\    func doubled() int { return self.seed(label:2) * 2 }
        \\}
        \\struct Plain:Reading { func seed(other:int) int { return other+19 } }
        \\struct Custom:Reading {
        \\    func seed(other:int) int { return other+4 }
        \\    func optional() int? { return 7 }
        \\}
        \\func identity<T>(value:T) T { return value }
        \\func read<T:Reading>(value:T) int { var active=value;return identity(active.doubled()) }
        \\func main() {
        \\    var plain=Plain(); assert(plain.optional()==null && plain.doubled()==42)
        \\    var custom=Custom(); assert(custom.optional()==7 && custom.doubled()==12)
        \\    var erased:Reading=plain; assert(erased.optional()==null && erased.doubled()==42)
        \\    var maybe:Reading?=plain;assert(maybe?.seed(label:2)==21)
        \\    assert(read(plain)==42 && read(custom)==12)
        \\    print("protocol defaults verified")
        \\}
    , "protocol defaults verified\n");
}

test "protocol defaults write back value receivers and Result propagation" {
    try verify(
        \\func attempt(ok:bool) Result<int,str> {
        \\    if ok {return Result<int,str>.success(7)}
        \\    return Result<int,str>.failure("denied")
        \\}
        \\protocol Counter {
        \\    value:int {get set}
        \\    func advance(by:int) int { self.value+=by;return self.value }
        \\    func reset() {self.value=0}
        \\    func noop() {}
        \\    func read(ok:bool) Result<int,str> {
        \\        self.value++
        \\        let value=try attempt(ok) else error {return Result<int,str>.failure(error)}
        \\        self.value+=10
        \\        return Result<int,str>.success(value)
        \\    }
        \\}
        \\struct ValueCounter:Counter {var value:int=0}
        \\class ObjectCounter:Counter {var value:int=0}
        \\func main() {
        \\    var value=ValueCounter();assert(value.advance(by:3)==3 && value.value==3)
        \\    match (try value.read(false)) {failure(error)=>{assert(error=="denied")}; success(answer)=>{panic("unexpected")}}
        \\    assert(value.value==4)
        \\    assert((try value.read(true) else error {panic(error)})==7 && value.value==15)
        \\    var erased:Counter=value;assert(erased.advance(by:2)==17 && value.value==15)
        \\    var object=ObjectCounter();var alias=object;var dynamic:Counter=object
        \\    assert(dynamic.advance(by:4)==4 && alias.value==4)
        \\    match (try object.read(false)) {failure(error)=>{assert(error=="denied")}; success(answer)=>{panic("unexpected")}}
        \\    assert(alias.value==5)
        \\    value.reset();assert(value.value==0);value.noop()
        \\    erased.reset();assert(erased.value==0)
        \\    print("mutation verified")
        \\}
    , "mutation verified\n");
}

test "protocol defaults capture nominal self once for different conformers" {
    try verify(
        \\protocol Reading {
        \\    func seed() int
        \\    func snapshot() int {let read=func() int {return self.seed()};return read()}
        \\}
        \\struct Value:Reading {var number:int;func seed() int{return self.number}}
        \\class Object:Reading {var number:int;func seed() int{return self.number}}
        \\func main() {
        \\    var value=Value(number:1);assert(value.snapshot()==1);value.number=10;assert(value.snapshot()==10)
        \\    var object=Object(number:2);assert(object.snapshot()==2);object.number=12;assert(object.snapshot()==12)
        \\    var erased:Reading=Value(number:3);assert(erased.snapshot()==3)
        \\    print("captures verified")
        \\}
    , "captures verified\n");
}

test "protocol defaults remain overridable through inherited conformances" {
    try verify(
        \\protocol Reading {func value() int {return 1}}
        \\class Base:Reading {}
        \\class Derived:Base {override func value() int {return 9}}
        \\func main() {
        \\    var child=Derived();var parent:Base=child;assert(parent.value()==9)
        \\    var erased:Reading=parent;assert(erased.value()==9)
        \\    print("inheritance verified")
        \\}
    , "inheritance verified\n");
}

test "protocol defaults retain provider scope across a package boundary" {
    try verifyProvider(
        \\use Api
        \\func main() {var value=Api.Legacy();assert(value.read()==23);print("provider verified")}
    , "provider verified\n",
        \\package func seed() int {return 23}
        \\public protocol Reading {func read() int {return seed()}}
        \\public class Legacy:Reading {}
    , null);
}

test "protocol defaults retain declaration visibility across packages" {
    try verifyProvider(
        \\use Api
        \\struct Consumer:Api.Reading {}
        \\func main() {var value=Consumer();value.provider_only()}
    , "",
        \\public protocol Reading {package func provider_only() int {return 2}}
    , "package-visible");
}

test "protocol defaults preserve named requirement mutation" {
    try verify(
        \\protocol Stepping {
        \\    func step(amount:int) int
        \\    func twice() int {return self.step(amount:1)+self.step(amount:1)}
        \\}
        \\struct Stateful:Stepping {var count:int=0;func step(other:int) int {self.count+=other;return self.count}}
        \\func main() {
        \\    var value=Stateful();assert(value.twice()==3 && value.count==2)
        \\    var erased:Stepping=value;assert(erased.twice()==7 && erased.step(0)==4 && value.count==2)
        \\}
    , "");
}

fn reject(code: []const u8, expected: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package.json", .data = "{\"sources\":\".\"}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = code });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = @import("../Project.zig").Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    const diagnostic = compiler.diagnostic orelse return error.TestUnexpectedResult;
    if (std.mem.indexOf(u8, diagnostic.message, expected) == null) {
        std.debug.print("expected {s}, got {s}\n", .{ expected, diagnostic.message });
        return error.TestUnexpectedResult;
    }
}

test "protocol defaults validate unused bodies and reject ambiguous defaults" {
    try reject(
        \\protocol Reading {func read() int {return self.secret}}
        \\struct Plain:Reading {var secret:int=7}
        \\func main() {}
    , "secret");
    try reject(
        \\protocol Reading {func read() int {return "wrong"}}
        \\func main() {}
    , "return expects");
    try reject(
        \\protocol First {func read() int {return 1}}
        \\protocol Second {func read() int {return 2}}
        \\struct Mixed:First,Second {}
        \\func main() {}
    , "conflicting defaults");
    try verify(
        \\protocol First {func read() int {return 1}}
        \\protocol Second {func read() int {return 2}}
        \\struct Mixed:First,Second {func read() int {return 3}}
        \\func main() {var value=Mixed();var first:First=value;var second:Second=value;assert(first.read()==3 && second.read()==3)}
    , "");
}

test "protocol defaults preserve the concrete self invariant including captured roots" {
    try reject(
        \\protocol Reading {func replace(other:Reading) {self=other}}
        \\struct Plain:Reading {}
        \\func main() {}
    , "cannot replace self");
    try reject(
        \\protocol Reading {func replace(other:Reading) {let update=func(){self=other};update()}}
        \\struct Plain:Reading {}
        \\func main() {}
    , "cannot replace self");
}

test "protocol defaults qualify optional protocol capabilities and resource lifetimes" {
    const source = try std.Io.Dir.cwd().readFileAlloc(std.testing.io, "../Tests/Types/Protocols/Defaults.sx", std.testing.allocator, .limited(1024 * 1024));
    defer std.testing.allocator.free(source);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var frontend = @import("../Frontend.zig").Frontend.init(allocator);
    const compilation = frontend.compileTests(source) catch |err| {
        if (frontend.diagnostic) |diagnostic| std.debug.print("capabilities line {d}: {s}\n", .{ diagnostic.position.line, diagnostic.message });
        return err;
    };
    var count: usize = 0;
    for (compilation.ast.functions, 0..) |function, index| {
        if (!function.is_test_entry) continue;
        const outcome = @import("../Interpreter.zig").runFunctionCaptureWithBoundaries(allocator, null, compilation.ir, index, &.{}) catch |err| {
            std.debug.print("default fixture {s} failed\n", .{function.test_name orelse "unnamed"});
            return err;
        };
        try std.testing.expectEqual(@as(u8, 0), outcome.exit_code);
        try std.testing.expectEqualStrings("", outcome.stdout);
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 5), count);
}

test "protocol defaults optional presence does not introduce protocol equality" {
    try verify(
        \\protocol Reading {func value() int}
        \\struct Plain:Reading {func value() int {return 1}}
        \\func main() {
        \\    var value:Reading?=null
        \\    assert(value==null && null==value && !(value!=null) && !(null!=value))
        \\    value=Plain()
        \\    assert(value!=null && null!=value && !(value==null) && !(null==value))
        \\}
    , "");
    try reject(
        \\protocol Reading {func value() int}
        \\func main() {var first:Reading?=null;var second:Reading?=null;print(first==second)}
    , "operator '==' does not accept");
}

test "protocol defaults ignore inherited extensions inactive at the conformance" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const files = .{
        .{ "Package.json", "{\"sources\":\".\"}" },
        .{ "Api.sx", "public protocol Reading {func read() int {return 1}}" },
        .{ "Base.sx", "public class Base {}" },
        .{ "Extras.sx", "use Base;extend Base.Base {func read() int {return 9}}" },
        .{ "Model.sx", "use Api;use Base;public class Derived:Base.Base,Api.Reading {}" },
        .{ "Main.sx", "use Model;use Extras;func main() {var value=Model.Derived();assert(value.read()==1);print(\"scope verified\")}" },
    };
    inline for (files) |file| try temporary.dir.writeFile(std.testing.io, .{ .sub_path = file[0], .data = file[1] });
    var compiler = @import("../Project.zig").Compiler.init(allocator, std.testing.io);
    const compilation = compiler.compile(try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" })) catch |err| {
        if (compiler.diagnostic) |diagnostic| std.debug.print("extension scope: {s}\n", .{diagnostic.message});
        return err;
    };
    const outcome = try @import("../Interpreter.zig").runCapture(allocator, compilation.ir);
    try std.testing.expectEqualStrings("scope verified\n", outcome.stdout);
    try std.testing.expectEqual(@as(u8, 0), outcome.exit_code);
}
