const std = @import("std");
const Support = @import("Support.zig");
const Server = @import("../Server.zig").Server;
const Workspace = @import("../Workspace.zig");
const Protocol = @import("../Protocol.zig");

test "protocol defaults preserve an independent semantic member oracle" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const scenario = for (@import("../CompletionContract.zig").scenarios) |candidate| {
        if (std.mem.eql(u8, candidate.id, "member-protocol-default")) break candidate;
    } else return error.MissingDefaultScenario;
    const expected = try @import("CompletionOracleSupport.zig").publicInstanceMembers(allocator, scenario.canonical_source, "Legacy");
    const actual = try Support.complete(allocator, scenario.partial_source);
    try Support.expectExactLabels(expected, actual);
    try Support.expectItem(.{ .label = "read", .kind = 2, .detail = "read() int", .insert_text = "read()" }, actual);
}

test "protocol defaults completion exposes inherited defaults without duplicate overrides" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_][]const u8{ "struct Plain:Reading {}", "struct Plain:Reading {func read() int {return 2}}", "class Base:Reading {} class Plain:Base {}" }) |declaration| {
        const source = try std.fmt.allocPrint(allocator, "protocol Reading {{func read() int {{return 1}}}}\n{s}\nfunc main() {{var value=Plain();value.<|>}}", .{declaration});
        const items = try Support.complete(allocator, source);
        try Support.expectPresent("read", items);
        try Support.expectAbsent("$default$result", items);
        try Support.expectNoDuplicates(items);
        try Support.expectItem(.{ .label = "read", .kind = 2, .detail = "read() int", .insert_text = "read()" }, items);
    }
}

test "protocol defaults completion keeps self nominal inside an unfinished body" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const items = try Support.complete(arena.allocator(), "protocol Reading {func seed() int;func read() int {return self.se<|>}}\nstruct Plain:Reading {var secret:int=3;func seed() int {return self.secret}}\nfunc main() {}");
    try Support.expectPresent("seed", items);
    try Support.expectAbsent("secret", items);
    try Support.expectNoDuplicates(items);
}

test "protocol defaults abstract requirements do not create lexical bodies" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "protocol Reading {func seed(outside:int) int;func read(inside:int) int {return <|>}}\nfunc main() {}";
    const items = try Support.complete(arena.allocator(), source);
    try Support.expectPresent("inside", items);
    try Support.expectAbsent("outside", items);
}

test "protocol defaults unsaved consumers preserve file atom and visibility identity" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.createDirPath(std.testing.io, "Nodes");
    const api = "public protocol Reading {func read() int {return 1}}";
    const sibling = "protocol Sibling {func own_read() int {return 2}}";
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package.json", .data = "{\"sources\":\".\"}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api.sx", .data = api });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Nodes/@Api.sx", .data = sibling });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "func main() {}" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    for ([_]struct { path: []const u8, header: []const u8, member: []const u8, definition: []const u8 }{
        .{ .path = "Scratch.sx", .header = "use Api\nstruct Local:Api.Reading {}", .member = "read", .definition = "Api.sx" },
        .{ .path = "Nodes/@Draft.sx", .header = "struct Local:Sibling {}", .member = "own_read", .definition = "Nodes/@Api.sx" },
    }) |fixture| {
        const canonical = try std.fmt.allocPrint(allocator, "{s}\nfunc main() {{var value=Local();value.{s}()}}", .{ fixture.header, fixture.member });
        try temporary.dir.writeFile(std.testing.io, .{ .sub_path = fixture.path, .data = canonical });
        var compiler = @import("../../Project.zig").Compiler.init(allocator, std.testing.io);
        _ = compiler.compile(try std.fs.path.join(allocator, &.{ root, fixture.path })) catch |err| {
            if (compiler.diagnostic) |diagnostic| std.debug.print("canonical {s}: {s}\n", .{ fixture.path, diagnostic.message });
            return err;
        };
        try temporary.dir.deleteFile(std.testing.io, fixture.path);
        const uri = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root_uri, fixture.path });
        const partial = try std.fmt.allocPrint(allocator, "{s}\nfunc main() {{var value=Local();value.<|>}}", .{fixture.header});
        const items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, partial, ".");
        try Support.expectExactLabels(&.{fixture.member}, items);
        try Support.expectEqualItems(items, try Support.serverCompletion(&server, allocator, uri, partial));
        const use_site = try std.fmt.allocPrint(allocator, "{s}\nfunc main() {{var value=Local();value.{s}<|>()}}", .{ fixture.header, fixture.member });
        const definition = (try Support.serverDefinition(&server, allocator, uri, use_site)) orelse return error.MissingUnsavedDefinition;
        const target_uri = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ root_uri, fixture.definition });
        try std.testing.expectEqualStrings(try Workspace.pathFromUri(allocator, target_uri), try Workspace.pathFromUri(allocator, definition.uri));
    }
    const scratch_uri = try std.fmt.allocPrint(allocator, "{s}/Scratch.sx", .{root_uri});
    const invisible = try Support.serverCompletion(&server, allocator, scratch_uri, "use Nodes\nstruct Local:Nodes.Sibling {}\nfunc main() {var value=Local();value.<|>}");
    try Support.expectExactLabels(&.{}, invisible);
}

test "protocol defaults completion covers optional and constrained receivers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    for ([_][]const u8{
        "func inspect<T:Reading>(value:T) {value.re<|>}",
        "func main() {var value:Plain?=Plain();value?.re<|>}",
        "func main() {var value:Reading=Plain();value.re<|>}",
    }) |body| {
        const source = try std.fmt.allocPrint(allocator, "protocol Reading {{func read() int {{return 1}}}}\nstruct Plain:Reading {{}}\n{s}", .{body});
        const items = try Support.complete(allocator, source);
        try Support.expectExactLabels(&.{"read"}, items);
    }
}

test "protocol defaults workspace preserves imported signatures definitions and overlays" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    const api = "public struct Node {var id:int=1}\npublic protocol Reading {func read(label:int) int {return label} func child() Node {return Node()} func apply(callback:func(int) int) int {return callback(1)} func required() int}\nlocal func secret() {}";
    try temporary.dir.createDirPath(std.testing.io, "Api/Module");
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Package.json", .data = "{\"sources\":\".\",\"dependencies\":{\"Api\":\"=1.0.0\"}}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Package.json", .data = "{\"name\":\"Api\",\"version\":\"1.0.0\"}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Api/Module/@Api.sx", .data = api });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Base.sx", .data = "public class Base {}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Extras.sx", .data = "use Base;extend Base.Base {func read(other:int) int {return other+9}}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Model.sx", .data = "use Api;use Base\npublic class Legacy:Api.Reading {func required() int {return 0}}\npublic class Custom:Legacy {override func read(other:int) int {return other} override func apply(other:func(int) int) int {return other(2)}}\npublic struct Empty {}\npublic class Scoped:Base.Base,Api.Reading {func required() int {return 0}}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Adapt.sx", .data = "use Api;use Model;extend Model.Empty:Api.Reading {func required() int {return 0}}" });
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = "use Model;use Extras\nfunc main() {var value=Model.Legacy();assert(value.read(label:4)==4);var scoped=Model.Scoped();assert(scoped.read(label:4)==4)}" });
    const root = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    var compiler = @import("../../Project.zig").Compiler.init(allocator, std.testing.io);
    _ = compiler.compile(try std.fs.path.join(allocator, &.{ root, "Main.sx" })) catch |err| {
        if (compiler.diagnostic) |diagnostic| std.debug.print("canonical default: {s}\n", .{diagnostic.message});
        return err;
    };
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const uri = try std.fmt.allocPrint(allocator, "{s}/Main.sx", .{root_uri});
    const api_uri = try std.fmt.allocPrint(allocator, "{s}/Api/Module/@Api.sx", .{root_uri});
    var server = Server.init(std.testing.allocator, std.testing.io);
    defer server.deinit();
    try Support.initializeServer(&server, allocator, root_uri);
    for ([_][]const u8{
        "use Api\nstruct Local:Api.Reading {func required() int {return 0}}\nfunc main() {var value=Local();value.re<|>}",
        "use Model\nfunc inspect(value:Model.Legacy) {value.re<|>}",
        "use Model\nfunc inspect(value:Model.Legacy?) {value?.re<|>}",
        "use Model.Legacy as Legacy\nfunc inspect(value:Legacy) {value.re<|>}",
        "use Api.Reading as Reading\nstruct Local:Reading {func required() int {return 0}}\nfunc inspect(value:Local) {value.re<|>}",
        "use Model;use Adapt\nfunc inspect(value:Model.Empty) {value.re<|>}",
        "use Model;use Extras\nfunc inspect(value:Model.Scoped) {value.re<|>}",
    }) |source| {
        const items = try Support.serverCompletionAfterTrigger(&server, allocator, uri, source, ".");
        try Support.expectExactLabels(&.{ "read", "required" }, items);
        try Support.expectNoDuplicates(items);
        try Support.expectItem(.{ .label = "read", .kind = 2, .detail = "read(label:int) int", .insert_text = "read(${1:label})$0", .insert_text_format = 2 }, items);
        try Support.expectEqualItems(items, try Support.serverCompletion(&server, allocator, uri, source));
    }
    const labels = try Support.serverCompletion(&server, allocator, uri, "use Model\nfunc inspect(value:Model.Legacy) {value.read(la<|>)}");
    try Support.expectPresent("label", labels);
    const overridden = try Support.serverCompletion(&server, allocator, uri, "use Model\nfunc inspect(value:Model.Custom) {value.re<|>}");
    try Support.expectExactLabels(&.{ "read", "required" }, overridden);
    try Support.expectItem(.{ .label = "read", .kind = 2, .detail = "read(other:int) int", .insert_text = "read(${1:other})$0", .insert_text_format = 2 }, overridden);
    const callback_override = try Support.serverCompletion(&server, allocator, uri, "use Model\nfunc inspect(value:Model.Custom) {value.ap<|>}");
    try Support.expectExactLabels(&.{"apply"}, callback_override);
    try Support.expectItem(.{ .label = "apply", .kind = 2, .detail = "apply(other:function) int", .insert_text = "apply(${1:other})$0", .insert_text_format = 2 }, callback_override);
    const chained = try Support.serverCompletion(&server, allocator, uri, "use Model\nfunc inspect(value:Model.Legacy) {value.child().<|>}");
    try Support.expectExactLabels(&.{"id"}, chained);
    for ([_][]const u8{
        "use Model\nfunc inspect(value:Model.Legacy) {value.re<|>ad(1)}",
        "use Model;use Extras\nfunc inspect(value:Model.Scoped) {value.re<|>ad(1)}",
        "use Api\nstruct Local:Api.Reading {func required() int {return 0}}\nfunc main() {var value=Local();value.re<|>ad(1)}",
    }) |source| {
        const definition = (try Support.serverDefinition(&server, allocator, uri, source)) orelse return error.MissingDefaultDefinition;
        try std.testing.expectEqualStrings(try Workspace.pathFromUri(allocator, api_uri), try Workspace.pathFromUri(allocator, definition.uri));
        try std.testing.expectEqual(Protocol.positionAtByteOffset(api, std.mem.indexOf(u8, api, "read(").?, .utf16).?, definition.range.start);
    }
    try Support.openDocument(&server, allocator, api_uri, 2, "public protocol Reading {func overlay() int {return 2} func required() int}");
    const overlay = try Support.serverCompletion(&server, allocator, uri, "use Model\nfunc inspect(value:Model.Legacy) {value.<|>}");
    try Support.expectExactLabels(&.{ "overlay", "required" }, overlay);
}
