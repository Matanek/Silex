const std = @import("std");
const Ast = @import("../Ast.zig");
const Frontend = @import("../Frontend.zig");
const Lexer = @import("../Lexer.zig");
const Parser = @import("../Parser.zig");
const LspTypes = @import("Types.zig");
const Axes = @import("CompletionContract/Axes.zig");
const WorkspaceFixtures = @import("CompletionContract/WorkspaceFixtures.zig");

pub const marker = "<|>";

pub const Capability = enum {
    declarations,
    types,
    statements,
    expressions,
    call_arguments,
    aggregate_fields,
    lexical_scope,
    member_local,
    member_imported,
    cascade_local,
    cascade_imported,
    topology,
    visibility,
    overlay_protocol,
    lsp_contract,
    invariants,
};

pub const GapOwner = enum { part_02, part_03, part_04, part_05, part_06 };

pub const Status = union(enum) {
    protected: []const u8,
    assigned_gap: GapOwner,
    irrelevant: []const u8,
};

pub const CanonicalValidation = enum { frontend, workspace };

pub const Scenario = struct {
    id: []const u8,
    capability: Capability,
    canonical_source: []const u8,
    canonical_validation: CanonicalValidation = .frontend,
    workspace_fixture: ?WorkspaceFixtures.Id = null,
    partial_source: []const u8,
    required: []const []const u8,
    forbidden: []const []const u8,
    provenance: []const u8,
    status: Status,
};

pub const scenarios = [_]Scenario{
    .{
        .id = "declaration-module-empty",
        .capability = .declarations,
        .canonical_source = "public struct Player {}\nfunc main() {}",
        .partial_source = "pub<|>",
        .required = &.{"public"},
        .forbidden = &.{"break"},
        .provenance = "FR/Language/Declarations",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "declaration-structure-member",
        .capability = .declarations,
        .canonical_source = "struct Player { var health:int }\nfunc main() {}",
        .partial_source = "struct Player { va<|> }\nfunc main() {}",
        .required = &.{"var"},
        .forbidden = &.{"while"},
        .provenance = "FR/Language/Data-types",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "type-qualified-import",
        .capability = .types,
        .canonical_source = "use STD.Math\nstruct Player { var position:Math.Vec2 = Math.Vec2() }\nfunc main() {}",
        .canonical_validation = .workspace,
        .workspace_fixture = .std_math,
        .partial_source = "use STD.Math\nstruct Player { var position:Math.<|> }\nfunc main() {}",
        .required = &.{"Vec2"},
        .forbidden = &.{"print"},
        .provenance = "FR/Language/Types",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 completes a qualified field type from the workspace" },
    },
    .{
        .id = "nominal-relation-type",
        .capability = .types,
        .canonical_source = "protocol Drawable { func draw() }\nstruct Sprite : Drawable { func draw() {} }\nfunc main() {}",
        .partial_source = "protocol Drawable { func draw() }\nstruct Sprite : Dra<|> { func draw() {} }\nfunc main() {}",
        .required = &.{"Drawable"},
        .forbidden = &.{"print"},
        .provenance = "FR/Language/Data-types",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "use-path-qualified",
        .capability = .topology,
        .canonical_source = "use STD.Math\nfunc main() {}",
        .canonical_validation = .workspace,
        .workspace_fixture = .std_math,
        .partial_source = "use STD.Ma<|>\nfunc main() {}",
        .required = &.{"Math"},
        .forbidden = &.{"while"},
        .provenance = "FR/Language/Modules",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "statement-loop-control",
        .capability = .statements,
        .canonical_source = "func main() { while true { break } }",
        .partial_source = "func main() { while true { br<|> } }",
        .required = &.{"break"},
        .forbidden = &.{"public"},
        .provenance = "FR/Language/Statements",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "expression-typed-prefix",
        .capability = .expressions,
        .canonical_source = "struct Recipe {}\nfunc world_factory() Recipe { return Recipe() }\nfunc main() { var value:Recipe = world_factory() }",
        .partial_source = "struct Recipe {}\nfunc world_factory() Recipe { return Recipe() }\nfunc main() { var value:Recipe = world_f<|> }",
        .required = &.{"world_factory"},
        .forbidden = &.{"while"},
        .provenance = "regression 38742fd",
        .status = .{ .protected = "Lsp.Tests.WorkspaceContracts: typed initializers preserve prefixed workspace expression roots" },
    },
    .{
        .id = "call-label-middle",
        .capability = .call_arguments,
        .canonical_source = "func spawn(health:int, force:int) {}\nfunc main() { spawn(health:100, force:10) }",
        .partial_source = "func spawn(health:int, force:int) {}\nfunc main() { spawn(health:100, <|>) }",
        .required = &.{"force"},
        .forbidden = &.{"health"},
        .provenance = "FR/Language/Functions",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "call-argument-expression",
        .capability = .call_arguments,
        .canonical_source = "func paint(color:int) {}\nfunc main() { let red = 1; paint(red) }",
        .partial_source = "func paint(color:int) {}\nfunc main() { let red = 1; paint(<|>) }",
        .required = &.{"red"},
        .forbidden = &.{"public"},
        .provenance = "FR/Language/Functions",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "aggregate-remaining-field",
        .capability = .aggregate_fields,
        .canonical_source = "struct Player { var health:int; var force:int }\nfunc main() { let player = Player(health:100, force:10); print(player.health) }",
        .partial_source = "struct Player { var health:int; var force:int }\nfunc main() { Player(health:100, <|>) }",
        .required = &.{"force"},
        .forbidden = &.{"health"},
        .provenance = "FR/Language/Structures",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "lexical-query-destructuring",
        .capability = .lexical_scope,
        .canonical_source = "struct Target {}\nstruct Motion {}\nfunc update(query:(Target, Motion)[]) { for pair in query { let (target, motion) = pair; let current = motion } }",
        .partial_source = "struct Target {}\nstruct Motion {}\nfunc update(query:(Target, Motion)[]) { for pair in query { let (target, motion) = pair; mot<|> } }",
        .required = &.{"motion"},
        .forbidden = &.{"query_internal"},
        .provenance = "FR/Language/Control-flow",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "intrinsic-expression-root",
        .capability = .lexical_scope,
        .canonical_source = "func main() { print(1) }",
        .partial_source = "func main() { pri<|> }",
        .required = &.{"print"},
        .forbidden = &.{"public"},
        .provenance = "FR/Language/Program-output",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "member-local-incomplete-if",
        .capability = .member_local,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input(); if input.pressed() {} }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input() if input.<|> }",
        .required = &.{"pressed"},
        .forbidden = &.{"if"},
        .provenance = "incomplete condition neighbour",
        .status = .{ .protected = "Lsp.Completion: recover member completion in an unfinished conditional" },
    },
    .{
        .id = "member-self-receiver",
        .capability = .member_local,
        .canonical_source = "struct Counter { var value:int; func read() int { return self.value } }\nfunc main() {}",
        .partial_source = "struct Counter { var value:int; func read() int { return self.<|> } }\nfunc main() {}",
        .required = &.{ "value", "read" },
        .forbidden = &.{"static_only"},
        .provenance = "FR/Language/Data-types self members",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 local receiver registry gaps are executable contracts" },
    },
    .{
        .id = "member-local-extension",
        .capability = .member_local,
        .canonical_source = "struct Adapter {}\nextend Adapter { func choose() int { return 1 } }\nfunc main() { print(Adapter().choose()) }",
        .partial_source = "struct Adapter {}\nextend Adapter { func choose() int { return 1 } }\nfunc main() { Adapter().<|> }",
        .required = &.{"choose"},
        .forbidden = &.{"public"},
        .provenance = "FR/Language/Data-types extensions",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 local receiver registry gaps are executable contracts" },
    },
    .{
        .id = "member-dynamic-protocol",
        .capability = .member_local,
        .canonical_source = "protocol Readable { func read() int }\nstruct Text : Readable { func read() int { return 1 } }\nfunc main() { var value:Readable = Text(); print(value.read()) }",
        .partial_source = "protocol Readable { func read() int }\nstruct Text : Readable { func read() int { return 1 } }\nfunc main() { var value:Readable = Text(); value.<|> }",
        .required = &.{"read"},
        .forbidden = &.{"secret"},
        .provenance = "FR/Language/Data-types protocols",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 local receiver registry gaps are executable contracts" },
    },
    .{
        .id = "member-optional-safe-access",
        .capability = .member_local,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input:Input? = Input(); if input?.pressed() ?? false {} }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input:Input? = Input(); if input?.<|> }",
        .required = &.{"pressed"},
        .forbidden = &.{"if"},
        .provenance = "FR/Language/Data-types optionals",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 local receiver registry gaps are executable contracts" },
    },
    .{
        .id = "member-static-type",
        .capability = .member_local,
        .canonical_source = "struct Palette { static func red() int { return 1 } }\nfunc main() { print(Palette.red()) }",
        .partial_source = "struct Palette { static func red() int { return 1 } }\nfunc main() { Palette.<|> }",
        .required = &.{"red"},
        .forbidden = &.{"instance"},
        .provenance = "FR/Language/Data-types static members",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 local receiver registry gaps are executable contracts" },
    },
    .{
        .id = "member-specialized-generic",
        .capability = .member_local,
        .canonical_source = "struct Box<T> { let value:T; func get() T { return self.value } }\nfunc main() { print(Box<int>(value:1).get()) }",
        .partial_source = "struct Box<T> { let value:T; func get() T { return self.value } }\nfunc main() { Box<int>(value:1).<|> }",
        .required = &.{"get"},
        .forbidden = &.{"T"},
        .provenance = "FR/Language/Data-types generics",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 local receiver registry gaps are executable contracts" },
    },
    .{
        .id = "member-named-tuple",
        .capability = .member_local,
        .canonical_source = "func main() { let size:(width:int, height:int) = (width:1, height:2); print(size.width) }",
        .partial_source = "func main() { let size:(width:int, height:int) = (width:1, height:2); size.<|> }",
        .required = &.{ "width", "height" },
        .forbidden = &.{"length"},
        .provenance = "FR/Language/Data-types tuples",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 local receiver registry gaps are executable contracts" },
    },
    .{
        .id = "member-imported-field-chain",
        .capability = .member_imported,
        .canonical_source = "use STD.Math\nstruct Transform2D { var position:Math.Vec2 }\nfunc update(transform:&Transform2D) { if transform.position.length() > 0.0 {} }\nfunc main() {}",
        .canonical_validation = .workspace,
        .workspace_fixture = .std_math,
        .partial_source = "use STD.Math\nstruct Transform2D { var position:Math.Vec2 }\nfunc update(transform:&Transform2D) { if transform.position.<|> }\nfunc main() {}",
        .required = &.{ "length", "normalized" },
        .forbidden = &.{"position"},
        .provenance = "Sandbox/Main.sx transform.position : Math.Vec2",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 preserves an imported field type through query and local bindings" },
    },
    .{
        .id = "member-imported-alias",
        .capability = .member_imported,
        .canonical_source = "use Api.Widget as Button\nfunc main() { Button().paint() }",
        .canonical_validation = .workspace,
        .workspace_fixture = .widget_alias,
        .partial_source = "use Api.Widget as Button\nfunc main() { Button().<|> }",
        .required = &.{"paint"},
        .forbidden = &.{"Widget"},
        .provenance = "FR/Language/Modules aliases",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "origin-current-module",
        .capability = .member_imported,
        .canonical_source = "use Module.Tools\nfunc main() { Tools.build() }",
        .canonical_validation = .workspace,
        .workspace_fixture = .current_module,
        .partial_source = "use Module.Tools\nfunc main() { Tools.<|> }",
        .required = &.{"build"},
        .forbidden = &.{"other_module_private"},
        .provenance = "FR/Language/Modules current folder anchor",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "member-imported-atom",
        .capability = .member_imported,
        .canonical_source = "use Api.Math\nfunc main() { Math.Vec2().length() }",
        .canonical_validation = .workspace,
        .workspace_fixture = .atom_math,
        .partial_source = "use Api.Math\nfunc main() { Math.Vec2().<|> }",
        .required = &.{"length"},
        .forbidden = &.{"internal"},
        .provenance = "package source atom @Vec2.sx",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "cascade-local-incomplete",
        .capability = .cascade_local,
        .canonical_source = "class Recipe { func with(value:int) Recipe { return self } }\nfunc main() { Recipe()..with(1) }",
        .partial_source = "class Recipe { func with(value:int) Recipe { return self } }\nfunc main() { Recipe()..<|> }",
        .required = &.{"with"},
        .forbidden = &.{"if"},
        .provenance = "regression 3e96726",
        .status = .{ .protected = "Lsp.Completion: incomplete cascade recovery" },
    },
    .{
        .id = "cascade-imported-principal-reexport",
        .capability = .cascade_imported,
        .canonical_source = "use GFX.Canvas\nfunc draw_player() Canvas { return Canvas()..paint(func () {}) }\nfunc main() { draw_player() }",
        .canonical_validation = .workspace,
        .workspace_fixture = .canvas_principal_reexport,
        .partial_source = "use GFX.Canvas\nfunc draw_player() Canvas { return Canvas()..<|> }\nfunc main() { draw_player() }",
        .required = &.{ "paint", "clear" },
        .forbidden = &.{"spawn"},
        .provenance = "Sandbox/Main.sx and GFX.Canvas principal reexport",
        .status = .{ .protected = "Lsp.Tests.WorkspaceContracts: server completes a cascade on an imported homonymous principal type" },
    },
    .{
        .id = "topology-catalog-fragment-field-chain",
        .capability = .topology,
        .canonical_source = "use GFX.Components\nuse STD.Math\nfunc update(transform:&Components.Transform2D) { var pos:Math.Vec2 = transform.position; print(pos.length()) }\nfunc main() {}",
        .canonical_validation = .workspace,
        .workspace_fixture = .catalog_field_chain,
        .partial_source = "use GFX.Components\nuse STD.Math\nfunc update(transform:&Components.Transform2D) { var pos:Math.Vec2 = transform.position if pos.<|> }\nfunc main() {}",
        .required = &.{ "length", "normalized" },
        .forbidden = &.{"position"},
        .provenance = "Sandbox/Main.sx catalog plus @Vec2.sx fragment",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "topology-development-dependency",
        .capability = .topology,
        .canonical_source = "use TestKit.Assertions\nfunc main() { Assertions.equal(1, 1) }",
        .canonical_validation = .workspace,
        .workspace_fixture = .development_dependency,
        .partial_source = "use TestKit.Assertions\nfunc main() { Assertions.<|> }",
        .required = &.{"equal"},
        .forbidden = &.{"private_helper"},
        .provenance = "development dependency package graph",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "topology-friend-package",
        .capability = .topology,
        .canonical_source = "use GFX.Core\nfunc main() { print(Core.package_visible()) }",
        .canonical_validation = .workspace,
        .workspace_fixture = .friend_package,
        .partial_source = "use GFX.Core\nfunc main() { Core.<|> }",
        .required = &.{"package_visible"},
        .forbidden = &.{"private_visible"},
        .provenance = "friend package visibility graph",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "topology-submodule",
        .capability = .topology,
        .canonical_source = "use Api.Rendering.Canvas\nfunc main() { Canvas().paint() }",
        .canonical_validation = .workspace,
        .workspace_fixture = .submodule,
        .partial_source = "use Api.Rendering.Canvas\nfunc main() { Canvas().<|> }",
        .required = &.{"paint"},
        .forbidden = &.{"internal"},
        .provenance = "FR/Language/Modules submodules",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "topology-merged-extension",
        .capability = .topology,
        .canonical_source = "use GFX.Physics\nfunc main() { print(Physics.Adapter().choose()) }",
        .canonical_validation = .workspace,
        .workspace_fixture = .merged_extension,
        .partial_source = "use GFX.Physics\nfunc main() { Physics.Adapter().<|> }",
        .required = &.{"choose"},
        .forbidden = &.{"private_helper"},
        .provenance = "merged extension from a dependency",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "topology-platform-fragment",
        .capability = .topology,
        .canonical_source = "use Bridge.Window\nfunc main() { Window.current().show() }",
        .canonical_validation = .workspace,
        .workspace_fixture = .platform_fragment,
        .partial_source = "use Bridge.Window\nfunc main() { Window.current().<|> }",
        .required = &.{"show"},
        .forbidden = &.{"unsupported_backend"},
        .provenance = "target-selected package fragment",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 workspace registry fixtures are executable completion contracts" },
    },
    .{
        .id = "visibility-imported-private-negative",
        .capability = .visibility,
        .canonical_source = "public class Api {\nprivate func secret() {}\nfunc visible() {}\n}",
        .partial_source = "use Package.Api\nfunc main(api:&Api) { api.<|> }",
        .required = &.{"visible"},
        .forbidden = &.{"secret"},
        .provenance = "FR/Language/Visibility",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 excludes non-public members from an ordinary dependency" },
    },
    .{
        .id = "visibility-package-member",
        .capability = .visibility,
        .canonical_source = "package class Api { package func shared() {} }",
        .partial_source = "func consume(api:&Api) { api.<|> }",
        .required = &.{"shared"},
        .forbidden = &.{"private_member"},
        .provenance = "FR/Language/Modules package visibility",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 enforces private and protected visibility in the current file" },
    },
    .{
        .id = "visibility-module-member",
        .capability = .visibility,
        .canonical_source = "class Api { module func shared() {} }",
        .partial_source = "func consume(api:&Api) { api.<|> }",
        .required = &.{"shared"},
        .forbidden = &.{"local_member"},
        .provenance = "FR/Language/Modules module visibility",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 enforces private and protected visibility in the current file" },
    },
    .{
        .id = "visibility-local-member",
        .capability = .visibility,
        .canonical_source = "local class Api { local func shared() {} }",
        .partial_source = "func consume(api:&Api) { api.<|> }",
        .required = &.{"shared"},
        .forbidden = &.{"other_file_member"},
        .provenance = "FR/Language/Modules local visibility",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 enforces private and protected visibility in the current file" },
    },
    .{
        .id = "visibility-protected-member",
        .capability = .visibility,
        .canonical_source = "class Base { protected func shared() {} }\nclass Child : Base { func call() { self.shared() } }",
        .partial_source = "class Base { protected func shared() {} }\nclass Child : Base { func call() { self.<|> } }",
        .required = &.{"shared"},
        .forbidden = &.{"unrelated_private"},
        .provenance = "FR/Language/Data-types protected class members",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 enforces private and protected visibility in the current file" },
    },
    .{
        .id = "overlay-unsaved-import",
        .capability = .overlay_protocol,
        .canonical_source = "public struct BufferType {}",
        .partial_source = "use Api\nfunc test() Result<Api.<|>, str>",
        .required = &.{"BufferType"},
        .forbidden = &.{"DiskType"},
        .provenance = "unsaved imported document overlay",
        .status = .{ .protected = "Lsp.Tests.Part05Contracts: part 05 imported overlays are authoritative ordered and recover without stale members" },
    },
    .{
        .id = "lsp-utf16-trigger-metadata",
        .capability = .lsp_contract,
        .canonical_source = "func paint() {}\nfunc main() { print(\"café\"); paint() }",
        .partial_source = "func paint() {}\nfunc main() { print(\"café\"); pai<|> }",
        .required = &.{"paint"},
        .forbidden = &.{"duplicate:paint"},
        .provenance = "LSP UTF-16 completion contract",
        .status = .{ .protected = "Lsp.Tests.Part06Contracts: part 06 UTF-16 completion metadata and JSON response are byte deterministic" },
    },
    .{
        .id = "symbol-parameter-binding",
        .capability = .lexical_scope,
        .canonical_source = "func paint(color:int) { print(color) }\nfunc main() {}",
        .partial_source = "func paint(color:int) { col<|> }\nfunc main() {}",
        .required = &.{"color"},
        .forbidden = &.{"private compiler symbol"},
        .provenance = "FR/Language/Functions parameters",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "symbol-constructor-root",
        .capability = .expressions,
        .canonical_source = "struct Widget {}\nfunc main() { let value = Widget() }",
        .partial_source = "struct Widget {}\nfunc main() { let value = Wid<|> }",
        .required = &.{"Widget"},
        .forbidden = &.{"while"},
        .provenance = "FR/Language/Data-types construction",
        .status = .{ .protected = "Lsp.Tests.Part03Contracts: part 03 local registry gaps are executable contracts" },
    },
    .{
        .id = "symbol-enum-case",
        .capability = .member_local,
        .canonical_source = "enum Direction { north; south }\nfunc main() { let value = Direction.north() }",
        .partial_source = "enum Direction { north; south }\nfunc main() { let value = Direction.<|> }",
        .required = &.{ "north", "south" },
        .forbidden = &.{"private compiler symbol"},
        .provenance = "FR/Language/Data-types enums",
        .status = .{ .protected = "Lsp.Tests.Part04Contracts: part 04 local receiver registry gaps are executable contracts" },
    },
    .{
        .id = "invariant-deterministic-no-duplicates",
        .capability = .invariants,
        .canonical_source = "func paint() {}\nfunc main() { paint() }",
        .partial_source = "func paint() {}\nfunc main() { pa<|> }",
        .required = &.{"same response twice"},
        .forbidden = &.{ "duplicate identity", "internal compiler name" },
        .provenance = "universal completion invariants",
        .status = .{ .protected = "Lsp.Tests.Part06Contracts: part 06 UTF-16 completion metadata and JSON response are byte deterministic" },
    },
    .{
        .id = "editing-empty-expression",
        .capability = .invariants,
        .canonical_source = "func paint() {}\nfunc main() { paint() }",
        .partial_source = "func paint() {}\nfunc main() { <|> }",
        .required = &.{"paint"},
        .forbidden = &.{"private compiler symbol"},
        .provenance = "empty explicitly invoked completion",
        .status = .{ .protected = "Lsp.ContextContracts: server invalidates completion across deletion and retyping" },
    },
    .{
        .id = "editing-delete-and-retype",
        .capability = .invariants,
        .canonical_source = "func paint() {}\nfunc main() { paint() }",
        .partial_source = "func paint() {}\nfunc main() { pai<|> }",
        .required = &.{"paint"},
        .forbidden = &.{"stale deleted candidate"},
        .provenance = "didChange deletion followed by retyping",
        .status = .{ .protected = "Lsp.ContextContracts: server invalidates completion across deletion and retyping" },
    },
    .{
        .id = "editing-interpolation-expression",
        .capability = .invariants,
        .canonical_source = "func main() { let value = 42; print(\"$(value)\") }",
        .partial_source = "func main() { let value = 42; print(\"$(val<|>)\") }",
        .required = &.{"value"},
        .forbidden = &.{"class"},
        .provenance = "Lsp.Server interpolation binding contract",
        .status = .{ .protected = "Lsp.Server: completion exposes an interpolation binding without historical types" },
    },
    .{
        .id = "trigger-type-colon",
        .capability = .lsp_contract,
        .canonical_source = "struct Error { let message:str }\nfunc main() {}",
        .partial_source = "struct Error { let message:<|> }\nfunc main() {}",
        .required = &.{"str"},
        .forbidden = &.{"if"},
        .provenance = "Lsp.Server ':' trigger in type position",
        .status = .{ .protected = "Lsp.Server: publish diagnostics after open and change" },
    },
    .{
        .id = "trigger-generic-less",
        .capability = .lsp_contract,
        .canonical_source = "struct Box<T> { let value:T }\nfunc main() { let box = Box<int>(value:1) }",
        .partial_source = "struct Box<T> { let value:T }\nfunc main() { let box = Box<<|> }",
        .required = &.{"int"},
        .forbidden = &.{"while"},
        .provenance = "announced '<' completion trigger",
        .status = .{ .protected = "Lsp.Tests.Part06Contracts: part 06 every advertised trigger reaches its exact completion context" },
    },
    .{
        .id = "trigger-argument-comma",
        .capability = .lsp_contract,
        .canonical_source = "func spawn(health:int, force:int) {}\nfunc main() { spawn(health:100, force:10) }",
        .partial_source = "func spawn(health:int, force:int) {}\nfunc main() { spawn(health:100,<|>) }",
        .required = &.{"force"},
        .forbidden = &.{"health"},
        .provenance = "announced ',' completion trigger",
        .status = .{ .protected = "Lsp.Tests.Part06Contracts: part 06 every advertised trigger reaches its exact completion context" },
    },
    .{
        .id = "trigger-try-space",
        .capability = .lsp_contract,
        .canonical_source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() else { return } }",
        .partial_source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() <|> }",
        .required = &.{ "else", "else error" },
        .forbidden = &.{"public"},
        .provenance = "Lsp.Server ' ' trigger after try",
        .status = .{ .protected = "Lsp.Server: space triggers only contextual try completions" },
    },
    .{
        .id = "trigger-try-closing-parenthesis",
        .capability = .lsp_contract,
        .canonical_source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() else { return } }",
        .partial_source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read()<|> }",
        .required = &.{ "else", "else error" },
        .forbidden = &.{"public"},
        .provenance = "Lsp.Server ')' trigger after try call",
        .status = .{ .protected = "Lsp.Server: space triggers only contextual try completions" },
    },
    .{
        .id = "trigger-try-else-prefix",
        .capability = .lsp_contract,
        .canonical_source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() else { return } }",
        .partial_source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() e<|> }",
        .required = &.{ "else", "else error" },
        .forbidden = &.{"public"},
        .provenance = "Lsp.Server 'e' trigger after try",
        .status = .{ .protected = "Lsp.Server: space triggers only contextual try completions" },
    },
    .{
        .id = "observable-metadata-and-insertion",
        .capability = .lsp_contract,
        .canonical_source = "func main() { let value = 42; print(\"$(value)\") }",
        .partial_source = "func main() { let value = 42; print(\"$(val<|>)\") }",
        .required = &.{ "value", "filterText:value", "sortText:present" },
        .forbidden = &.{"class"},
        .provenance = "Lsp.Server completion item metadata",
        .status = .{ .protected = "Lsp.Server: completion exposes an interpolation binding without historical types" },
    },
    .{
        .id = "observable-kind-detail-snippet",
        .capability = .lsp_contract,
        .canonical_source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() else { return } }",
        .partial_source = "func read() Result<int,str> { return Result<int,str>.success(1) }\nfunc main() { var value = try read() <|> }",
        .required = &.{ "detail", "kind", "insertText:else {$0}" },
        .forbidden = &.{"duplicate:else"},
        .provenance = "Lsp.Server contextual snippet contract",
        .status = .{ .protected = "Lsp.Tests.Part06Contracts: part 06 contextual alternatives expose exact kinds details snippets and stable order" },
    },
    .{
        .id = "recovery-error-before-cursor",
        .capability = .invariants,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc helper() {}\nfunc main() { let input = Input(); input.pressed() }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc helper( { }\nfunc main() {\n    let input = Input()\n    input.<|>\n}",
        .required = &.{"pressed"},
        .forbidden = &.{"empty response caused by unrelated parse error"},
        .provenance = "global completion loss after a syntax error",
        .status = .{ .protected = "Lsp.ContextContracts: server keeps member completion across independent syntax errors" },
    },
    .{
        .id = "recovery-error-at-cursor",
        .capability = .invariants,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input(); if input.pressed() {} }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc main() {\n    let input = Input()\n    if (input.<|>\n}",
        .required = &.{"pressed"},
        .forbidden = &.{"empty response caused by the incomplete expression"},
        .provenance = "completion site is itself a syntax error while typing",
        .status = .{ .protected = "Lsp.ContextContracts: server keeps member completion across independent syntax errors" },
    },
    .{
        .id = "recovery-error-after-cursor",
        .capability = .invariants,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc main() { let input = Input(); input.pressed() }\nfunc helper() {}",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc main() {\n    let input = Input()\n    input.<|>\n}\nfunc helper( { }",
        .required = &.{"pressed"},
        .forbidden = &.{"empty response caused by following parse error"},
        .provenance = "global completion loss after a syntax error",
        .status = .{ .protected = "Lsp.ContextContracts: server keeps member completion across independent syntax errors" },
    },
    .{
        .id = "recovery-error-neighbour-block",
        .capability = .invariants,
        .canonical_source = "struct Input { func pressed() bool { return true } }\nfunc helper() {}\nfunc main() { let input = Input(); input.pressed() }",
        .partial_source = "struct Input { func pressed() bool { return true } }\nfunc helper() { if }\nfunc main() {\n    let input = Input()\n    input.<|>\n}",
        .required = &.{"pressed"},
        .forbidden = &.{"context imported from broken neighbour"},
        .provenance = "global completion loss after a syntax error",
        .status = .{ .protected = "Lsp.ContextContracts: server keeps member completion across independent syntax errors" },
    },
};

pub const Position = Axes.Position;
pub const Origin = Axes.Origin;
pub const Receiver = Axes.Receiver;
pub const Topology = Axes.Topology;
pub const Visibility = Axes.Visibility;
pub const Symbol = Axes.Symbol;
pub const Editing = Axes.Editing;
pub const Trigger = Axes.Trigger;
pub const Observable = Axes.Observable;

pub fn positionCapability(value: Position) Capability {
    return switch (value) {
        .module, .structure, .modifier => .declarations,
        .type_name, .nominal_relation => .types,
        .statement => .statements,
        .expression => .expressions,
        .member => .member_local,
        .argument, .call_label => .call_arguments,
        .aggregate_field => .aggregate_fields,
        .use_path => .topology,
    };
}

pub fn originCapability(value: Origin) Capability {
    return switch (value) {
        .intrinsic, .lexical => .lexical_scope,
        .self_member, .local => .member_local,
        .current_module, .dependency, .extension, .protocol_member, .alias, .reexport, .contribution, .catalog, .atom => .member_imported,
    };
}

pub fn receiverCapability(value: Receiver) Capability {
    return switch (value) {
        .value, .reference, .optional, .generic, .tuple, .dynamic_protocol => .member_local,
        .static_type, .module, .principal_type, .call_result, .field_result, .chain => .member_imported,
        .cascade => .cascade_imported,
    };
}

pub fn topologyCapability(value: Topology) Capability {
    return switch (value) {
        .loose, .same_file, .module_file, .package, .dependency, .development_dependency, .friend, .submodule, .merged_extension, .suite_extension, .catalog, .platform_fragment => .topology,
        .overlay => .overlay_protocol,
    };
}

pub fn visibilityCapability(value: Visibility) Capability {
    return switch (value) {
        .public, .package, .module, .local, .protected, .private, .friend => .visibility,
    };
}

pub fn symbolCapability(value: Symbol) Capability {
    return switch (value) {
        .keyword => .declarations,
        .variable, .parameter => .lexical_scope,
        .function, .constructor => .expressions,
        .field, .method, .enum_case => .member_local,
        .type => .types,
        .module, .alias => .topology,
    };
}

pub fn editingCapability(value: Editing) Capability {
    return switch (value) {
        .empty,
        .prefixed,
        .deleted,
        .delimiter_missing,
        .body_missing,
        .nested,
        .interpolation,
        .unicode_before_cursor,
        .syntax_error_before_cursor,
        .syntax_error_at_cursor,
        .syntax_error_after_cursor,
        .syntax_error_neighbour_block,
        => .invariants,
    };
}

pub fn triggerCapability(value: Trigger) Capability {
    return switch (value) {
        .invoked, .dot, .colon, .less, .comma, .space, .closing_parenthesis, .else_prefix => .lsp_contract,
    };
}

pub fn protocolTrigger(value: LspTypes.CompletionTriggerCharacter) Trigger {
    return switch (value) {
        .dot => .dot,
        .colon => .colon,
        .less => .less,
        .comma => .comma,
        .space => .space,
        .closing_parenthesis => .closing_parenthesis,
        .else_prefix => .else_prefix,
    };
}

pub fn observableCapability(value: Observable) Capability {
    return switch (value) {
        .labels, .order, .kind, .detail, .filter_text, .sort_text, .insertion, .snippet => .lsp_contract,
        .duplicates, .deterministic => .invariants,
    };
}

pub fn parserProductionCapability(value: Parser.CompletionSites.Production) Capability {
    return switch (value) {
        .use_path => .topology,
        .use_alias, .module_declaration, .structure_declaration, .modifier => .declarations,
        .type_annotation, .generic_parameter, .generic_argument, .nominal_relation, .parameter, .return_type => .types,
        .statement => .statements,
        .expression => .expressions,
        .member_access => .member_local,
        .cascade_operation => .cascade_local,
        .call_argument, .call_label => .call_arguments,
        .aggregate_field => .aggregate_fields,
        .interpolation_expression, .match_branch, .for_source => .expressions,
        .try_alternative => .statements,
    };
}

pub const TokenPolicy = enum { choice, context, recovery, irrelevant };

pub fn tokenPolicy(tag: Lexer.TokenTag) TokenPolicy {
    return switch (tag) {
        .keyword_let,
        .keyword_var,
        .keyword_if,
        .keyword_elif,
        .keyword_else,
        .keyword_while,
        .keyword_mutex,
        .keyword_for,
        .keyword_range,
        .keyword_in,
        .keyword_break,
        .keyword_continue,
        .keyword_return,
        .keyword_try,
        .keyword_move,
        .keyword_copy,
        .keyword_struct,
        .keyword_class,
        .keyword_protocol,
        .keyword_extend,
        .keyword_contribute,
        .keyword_enum,
        .keyword_match,
        .keyword_init,
        .keyword_drop,
        .keyword_super,
        .keyword_override,
        .keyword_static,
        .keyword_func,
        .keyword_use,
        .keyword_private,
        .keyword_package,
        .keyword_module,
        .keyword_local,
        .keyword_protected,
        .keyword_public,
        .keyword_as,
        => .choice,

        .keyword_void,
        .keyword_self,
        .keyword_true,
        .keyword_false,
        .keyword_null,
        .keyword_int,
        .keyword_int8,
        .keyword_int16,
        .keyword_int32,
        .keyword_int64,
        .keyword_uint,
        .keyword_uint8,
        .keyword_uint16,
        .keyword_uint32,
        .keyword_uint64,
        .keyword_float,
        .keyword_float32,
        .keyword_float64,
        .keyword_bool,
        .keyword_str,
        .keyword_print,
        .keyword_assert,
        .keyword_panic,
        .identifier,
        .integer,
        .floating,
        .string,
        .string_start,
        .string_text,
        .interpolation_start,
        .interpolation_end,
        .string_end,
        => .context,

        .plus,
        .plus_plus,
        .plus_equal,
        .minus,
        .minus_minus,
        .minus_equal,
        .star,
        .star_equal,
        .slash,
        .slash_equal,
        .percent,
        .percent_equal,
        .bang,
        .equal,
        .equal_equal,
        .fat_arrow,
        .bang_equal,
        .less,
        .less_equal,
        .shift_left,
        .greater,
        .greater_equal,
        .shift_right,
        .amp_amp,
        .amp,
        .at,
        .caret,
        .question,
        .question_question,
        .question_dot,
        .pipe_pipe,
        .colon,
        .comma,
        .dot,
        .dot_dot,
        .dot_dot_dot,
        .left_parenthesis,
        .right_parenthesis,
        .left_brace,
        .right_brace,
        .left_bracket,
        .right_bracket,
        .semicolon,
        => .recovery,

        .legacy_internal, .end => .irrelevant,
    };
}

pub fn expressionCapability(tag: std.meta.Tag(Ast.Expression.Value)) Capability {
    return switch (tag) {
        .integer,
        .floating,
        .boolean,
        .null_value,
        .string,
        .interpolated_string,
        .identifier,
        .generic_reference,
        .unary,
        .binary,
        .conversion,
        .string_count,
        .sequence_literal,
        .tuple_literal,
        .index_access,
        .slice_access,
        .match_expression,
        => .expressions,
        .call, .field_access => .member_local,
        .cascade => .cascade_local,
    };
}

pub fn statementCapability(tag: std.meta.Tag(Ast.Statement)) Capability {
    return switch (tag) {
        .variable_declaration => .lexical_scope,
        .assignment_statement,
        .return_statement,
        .expression_statement,
        .print_statement,
        .assert_statement,
        .panic_statement,
        .if_statement,
        .while_statement,
        .for_statement,
        .mutex_statement,
        .break_statement,
        .continue_statement,
        => .statements,
    };
}

const AstFieldDecision = struct {
    name: []const u8,
    witness: ?[]const u8 = null,
    irrelevant_reason: ?[]const u8 = null,
};

const program_field_decisions = [_]AstFieldDecision{
    .{ .name = "uses", .witness = "use-path-qualified" },
    .{ .name = "catalog_contributions", .witness = "topology-catalog-fragment-field-chain" },
    .{ .name = "type_names", .witness = "type-qualified-import" },
    .{ .name = "test_only_type_names", .irrelevant_reason = "test-only semantic filtering does not create completion symbols" },
    .{ .name = "generic_types", .witness = "member-specialized-generic" },
    .{ .name = "function_types", .witness = "observable-metadata-and-insertion" },
    .{ .name = "structures", .witness = "declaration-structure-member" },
    .{ .name = "enums", .witness = "symbol-enum-case" },
    .{ .name = "extensions", .witness = "member-local-extension" },
    .{ .name = "external_functions", .witness = "origin-current-module" },
    .{ .name = "functions", .witness = "origin-current-module" },
};

const function_field_decisions = [_]AstFieldDecision{
    .{ .name = "is_anonymous", .witness = "call-argument-expression" },
    .{ .name = "is_test", .irrelevant_reason = "test execution metadata does not change the public completion surface" },
    .{ .name = "is_test_entry", .irrelevant_reason = "test entry metadata does not change the public completion surface" },
    .{ .name = "test_name", .irrelevant_reason = "test display metadata does not change the public completion surface" },
    .{ .name = "test_owner", .irrelevant_reason = "test ownership metadata does not change the public completion surface" },
    .{ .name = "test_source_name", .irrelevant_reason = "test source metadata does not change the public completion surface" },
    .{ .name = "is_static", .witness = "member-static-type" },
    .{ .name = "is_override", .witness = "visibility-protected-member" },
    .{ .name = "is_public", .witness = "origin-current-module" },
    .{ .name = "is_internal", .witness = "visibility-package-member" },
    .{ .name = "is_local", .witness = "visibility-local-member" },
    .{ .name = "is_private", .witness = "visibility-imported-private-negative" },
    .{ .name = "is_protected", .witness = "visibility-protected-member" },
    .{ .name = "visibility_explicit", .witness = "visibility-module-member" },
    .{ .name = "extension", .witness = "member-local-extension" },
    .{ .name = "specialization_file", .witness = "member-specialized-generic" },
    .{ .name = "owner", .witness = "origin-current-module" },
    .{ .name = "position", .irrelevant_reason = "source coordinates affect navigation, not symbol classification" },
    .{ .name = "name_position", .irrelevant_reason = "source coordinates affect navigation, not symbol classification" },
    .{ .name = "name", .witness = "origin-current-module" },
    .{ .name = "type_parameters", .witness = "member-specialized-generic" },
    .{ .name = "parameters", .witness = "symbol-parameter-binding" },
    .{ .name = "return_type", .witness = "member-imported-field-chain" },
    .{ .name = "return_mode", .witness = "member-self-receiver" },
    .{ .name = "return_provenance", .witness = "member-self-receiver" },
    .{ .name = "intrinsic", .witness = "intrinsic-expression-root" },
    .{ .name = "is_intrinsic_declaration", .witness = "intrinsic-expression-root" },
    .{ .name = "accessor", .witness = "member-imported-field-chain" },
    .{ .name = "statements", .witness = "lexical-query-destructuring" },
};

const stored_field_decisions = [_]AstFieldDecision{
    .{ .name = "is_static", .witness = "member-static-type" },
    .{ .name = "is_public", .witness = "member-imported-field-chain" },
    .{ .name = "is_internal", .witness = "visibility-package-member" },
    .{ .name = "is_local", .witness = "visibility-local-member" },
    .{ .name = "is_private", .witness = "visibility-imported-private-negative" },
    .{ .name = "is_protected", .witness = "visibility-protected-member" },
    .{ .name = "visibility_explicit", .witness = "visibility-module-member" },
    .{ .name = "position", .irrelevant_reason = "source coordinates affect navigation, not symbol classification" },
    .{ .name = "name_position", .irrelevant_reason = "source coordinates affect navigation, not symbol classification" },
    .{ .name = "name", .witness = "member-imported-field-chain" },
    .{ .name = "mutable", .witness = "member-self-receiver" },
    .{ .name = "access_mode", .witness = "lexical-query-destructuring" },
    .{ .name = "type", .witness = "member-imported-field-chain" },
    .{ .name = "default", .witness = "aggregate-remaining-field" },
    .{ .name = "property", .witness = "member-imported-field-chain" },
};

const structure_decisions = [_]AstFieldDecision{
    .{ .name = "is_test", .irrelevant_reason = "test ownership metadata does not change the public completion surface" },
    .{ .name = "is_public", .witness = "type-qualified-import" },
    .{ .name = "is_internal", .witness = "visibility-package-member" },
    .{ .name = "is_local", .witness = "visibility-local-member" },
    .{ .name = "is_private", .witness = "visibility-imported-private-negative" },
    .{ .name = "is_protected", .witness = "visibility-protected-member" },
    .{ .name = "is_class", .witness = "member-imported-alias" },
    .{ .name = "is_copyable", .witness = "member-local-incomplete-if" },
    .{ .name = "is_intrinsic", .witness = "intrinsic-expression-root" },
    .{ .name = "is_static", .witness = "member-static-type" },
    .{ .name = "is_protocol", .witness = "member-dynamic-protocol" },
    .{ .name = "is_tuple", .witness = "member-named-tuple" },
    .{ .name = "tuple_named", .witness = "member-named-tuple" },
    .{ .name = "tuple_placeholder", .irrelevant_reason = "frontend placeholder metadata is never an editor-visible declaration" },
    .{ .name = "query_pattern", .witness = "lexical-query-destructuring" },
    .{ .name = "enclosing", .witness = "topology-submodule" },
    .{ .name = "owner", .witness = "origin-current-module" },
    .{ .name = "position", .irrelevant_reason = "source coordinates affect navigation, not symbol classification" },
    .{ .name = "name_position", .irrelevant_reason = "source coordinates affect navigation, not symbol classification" },
    .{ .name = "name", .witness = "type-qualified-import" },
    .{ .name = "base", .witness = "nominal-relation-type" },
    .{ .name = "base_position", .irrelevant_reason = "source coordinates affect navigation, not symbol classification" },
    .{ .name = "conformances", .witness = "member-dynamic-protocol" },
    .{ .name = "extension_conformances", .witness = "member-local-extension" },
    .{ .name = "type_parameters", .witness = "member-specialized-generic" },
    .{ .name = "fields", .witness = "member-imported-field-chain" },
    .{ .name = "static_fields", .witness = "member-static-type" },
    .{ .name = "constructors", .witness = "symbol-constructor-root" },
    .{ .name = "methods", .witness = "member-local-incomplete-if" },
    .{ .name = "drop", .irrelevant_reason = "destructor bodies never contribute callable completion symbols" },
    .{ .name = "collection", .witness = "lexical-query-destructuring" },
};

fn assertAstFieldDecisions(comptime T: type, comptime decisions: []const AstFieldDecision) void {
    const fields = std.meta.fields(T);
    if (fields.len != decisions.len) {
        @compileError(std.fmt.comptimePrint(
            "completion contract has {d} decisions for {s}, but the AST exposes {d} fields; classify every new field and add its witness",
            .{ decisions.len, @typeName(T), fields.len },
        ));
    }
    inline for (fields, decisions) |field, decision| {
        if (!std.mem.eql(u8, field.name, decision.name)) {
            @compileError(std.fmt.comptimePrint(
                "completion contract expected {s}.{s}, found {s}; update the explicit field decision and its witness",
                .{ @typeName(T), decision.name, field.name },
            ));
        }
        if (decision.witness) |witness| {
            if (!hasScenario(witness)) {
                @compileError(std.fmt.comptimePrint("AST field {s}.{s} names missing completion witness '{s}'", .{ @typeName(T), field.name, witness }));
            }
        } else if (decision.irrelevant_reason == null or decision.irrelevant_reason.?.len == 0) {
            @compileError(std.fmt.comptimePrint("AST field {s}.{s} needs a completion witness or an irrelevance reason", .{ @typeName(T), field.name }));
        }
    }
}

fn hasScenario(comptime identifier: []const u8) bool {
    inline for (scenarios) |scenario| if (std.mem.eql(u8, scenario.id, identifier)) return true;
    return false;
}

pub fn audit(registry: []const Scenario) !void {
    var covered = [_]bool{false} ** @typeInfo(Capability).@"enum".fields.len;
    var workspace_fixtures = [_]bool{false} ** @typeInfo(WorkspaceFixtures.Id).@"enum".fields.len;
    for (registry, 0..) |scenario, index| {
        if (scenario.id.len == 0) return error.MissingIdentifier;
        if (scenario.canonical_source.len == 0) return error.MissingCanonicalSource;
        if (countOccurrences(scenario.partial_source, marker) != 1) return error.InvalidCursorCount;
        if (scenario.required.len == 0) return error.MissingRequiredCandidate;
        if (scenario.forbidden.len == 0) return error.MissingForbiddenCandidate;
        if (scenario.provenance.len == 0) return error.MissingProvenance;
        if (containsInfrastructurePath(scenario)) return error.InfrastructureDependency;
        switch (scenario.canonical_validation) {
            .frontend => if (scenario.workspace_fixture != null) return error.UnexpectedWorkspaceFixture,
            .workspace => {
                const fixture = scenario.workspace_fixture orelse return error.MissingWorkspaceFixture;
                workspace_fixtures[@intFromEnum(fixture)] = true;
            },
        }
        switch (scenario.status) {
            .protected => |proof| if (proof.len == 0) return error.MissingProof,
            .assigned_gap => {},
            .irrelevant => |reason| if (reason.len == 0) return error.MissingReason,
        }
        for (registry[index + 1 ..]) |other| {
            if (std.mem.eql(u8, scenario.id, other.id)) return error.DuplicateIdentifier;
        }
        covered[@intFromEnum(scenario.capability)] = true;
    }
    for (covered) |present| if (!present) return error.MissingCapability;
    for (workspace_fixtures) |present| if (!present) return error.UnusedWorkspaceFixture;
    try auditAxisWitnesses(registry);
}

pub fn auditRelease(registry: []const Scenario) !void {
    try audit(registry);
    for (registry) |scenario| switch (scenario.status) {
        .assigned_gap => return error.UnresolvedCompletionGap,
        .protected, .irrelevant => {},
    };
}

fn auditAxisWitnesses(registry: []const Scenario) !void {
    inline for (std.meta.fields(Position)) |field| try requireScenario(
        registry,
        Axes.positionWitness(@enumFromInt(field.value)),
    );
    inline for (std.meta.fields(Origin)) |field| try requireScenario(
        registry,
        Axes.originWitness(@enumFromInt(field.value)),
    );
    inline for (std.meta.fields(Receiver)) |field| try requireScenario(
        registry,
        Axes.receiverWitness(@enumFromInt(field.value)),
    );
    inline for (std.meta.fields(Topology)) |field| try requireScenario(
        registry,
        Axes.topologyWitness(@enumFromInt(field.value)),
    );
    inline for (std.meta.fields(Visibility)) |field| try requireScenario(
        registry,
        Axes.visibilityWitness(@enumFromInt(field.value)),
    );
    inline for (std.meta.fields(Symbol)) |field| try requireScenario(
        registry,
        Axes.symbolWitness(@enumFromInt(field.value)),
    );
    inline for (std.meta.fields(Editing)) |field| try requireScenario(
        registry,
        Axes.editingWitness(@enumFromInt(field.value)),
    );
    inline for (std.meta.fields(Trigger)) |field| try requireScenario(
        registry,
        Axes.triggerWitness(@enumFromInt(field.value)),
    );
    inline for (std.meta.fields(Observable)) |field| try requireScenario(
        registry,
        Axes.observableWitness(@enumFromInt(field.value)),
    );
}

fn requireScenario(registry: []const Scenario, identifier: []const u8) !void {
    for (registry) |scenario| {
        if (std.mem.eql(u8, scenario.id, identifier)) return;
    }
    return error.MissingAxisWitness;
}

fn countOccurrences(haystack: []const u8, needle: []const u8) usize {
    var count: usize = 0;
    var offset: usize = 0;
    while (std.mem.indexOfPos(u8, haystack, offset, needle)) |index| {
        count += 1;
        offset = index + needle.len;
    }
    return count;
}

fn containsInfrastructurePath(scenario: Scenario) bool {
    const values = [_][]const u8{
        scenario.canonical_source,
        scenario.partial_source,
        scenario.provenance,
    };
    for (values) |value| {
        if (std.mem.indexOf(u8, value, ".specs/") != null or
            std.mem.indexOf(u8, value, ".agents/") != null or
            std.mem.indexOf(u8, value, "/Users/") != null) return true;
    }
    return false;
}

test "completion registry is classified and self contained" {
    try auditRelease(&scenarios);
}

test "canonical completion sources pass their declared frontend boundary" {
    for (scenarios) |scenario| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        var parser = Parser.Parser.init(arena.allocator(), scenario.canonical_source);
        _ = parser.parse() catch |err| {
            std.debug.print("completion canonical source '{s}' does not parse\n", .{scenario.id});
            return err;
        };
        switch (scenario.canonical_validation) {
            .frontend => {
                var frontend = Frontend.Frontend.init(arena.allocator());
                frontend.checkDocument(scenario.canonical_source) catch |err| {
                    std.debug.print(
                        "completion canonical source '{s}' is not semantically valid: {s}\n",
                        .{ scenario.id, if (frontend.diagnostic) |diagnostic| diagnostic.message else @errorName(err) },
                    );
                    return err;
                };
            },
            .workspace => {
                WorkspaceFixtures.validate(scenario.workspace_fixture.?, scenario.canonical_source) catch |err| {
                    std.debug.print("completion workspace source '{s}' failed its fixture\n", .{scenario.id});
                    return err;
                };
            },
        }
    }
}

test "closed compiler and completion inventories require exhaustive policies" {
    comptime {
        @setEvalBranchQuota(100_000);
        assertAstFieldDecisions(Ast.Program, &program_field_decisions);
        assertAstFieldDecisions(Ast.Function, &function_field_decisions);
        assertAstFieldDecisions(Ast.StructureField, &stored_field_decisions);
        assertAstFieldDecisions(Ast.Structure, &structure_decisions);
    }
    inline for (@typeInfo(Position).@"enum".fields) |field| _ = positionCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Origin).@"enum".fields) |field| _ = originCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Receiver).@"enum".fields) |field| _ = receiverCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Topology).@"enum".fields) |field| _ = topologyCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Visibility).@"enum".fields) |field| _ = visibilityCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Symbol).@"enum".fields) |field| _ = symbolCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Editing).@"enum".fields) |field| _ = editingCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Trigger).@"enum".fields) |field| _ = triggerCapability(@enumFromInt(field.value));
    inline for (@typeInfo(LspTypes.CompletionTriggerCharacter).@"enum".fields) |field| {
        _ = protocolTrigger(@enumFromInt(field.value));
    }
    inline for (@typeInfo(Observable).@"enum".fields) |field| _ = observableCapability(@enumFromInt(field.value));
    inline for (@typeInfo(Parser.CompletionSites.Production).@"enum".fields) |field| {
        const production: Parser.CompletionSites.Production = @enumFromInt(field.value);
        _ = Parser.CompletionSites.policy(production);
        _ = parserProductionCapability(production);
    }
    inline for (@typeInfo(Lexer.TokenTag).@"enum".fields) |field| _ = tokenPolicy(@enumFromInt(field.value));
    inline for (@typeInfo(std.meta.Tag(Ast.Expression.Value)).@"enum".fields) |field| {
        _ = expressionCapability(@enumFromInt(field.value));
    }
    inline for (@typeInfo(std.meta.Tag(Ast.Statement)).@"enum".fields) |field| {
        _ = statementCapability(@enumFromInt(field.value));
    }
}

test "registry mutations expose missing rows and missing proofs" {
    var without_declarations: std.ArrayList(Scenario) = .empty;
    defer without_declarations.deinit(std.testing.allocator);
    for (scenarios) |scenario| {
        if (scenario.capability != .declarations) try without_declarations.append(std.testing.allocator, scenario);
    }
    try std.testing.expectError(error.MissingCapability, audit(without_declarations.items));
    try std.testing.expectError(error.MissingAxisWitness, audit(scenarios[1..]));
    var missing_proof = scenarios;
    missing_proof[3].status = .{ .protected = "" };
    try std.testing.expectError(error.MissingProof, audit(&missing_proof));
    var assigned_gap = scenarios;
    assigned_gap[3].status = .{ .assigned_gap = .part_02 };
    try std.testing.expectError(error.UnresolvedCompletionGap, auditRelease(&assigned_gap));
    var missing_negative = scenarios;
    missing_negative[3].forbidden = &.{};
    try std.testing.expectError(error.MissingForbiddenCandidate, audit(&missing_negative));
    var missing_cursor = scenarios;
    missing_cursor[0].partial_source = "public";
    try std.testing.expectError(error.InvalidCursorCount, audit(&missing_cursor));
    var missing_fixture = scenarios;
    missing_fixture[2].workspace_fixture = null;
    try std.testing.expectError(error.MissingWorkspaceFixture, audit(&missing_fixture));
}
