const std = @import("std");
const Ast = @import("../Ast.zig");
const CompilationCache = @import("../CompilationCache.zig");
const LexerModule = @import("../Lexer.zig");
const Result = @import("../Intrinsics/Result.zig");
const ParserModule = @import("../Parser.zig");
const Fragments = @import("Fragments.zig");
const Reexports = @import("Reexports.zig");
const Names = @import("Names.zig");

const Binding = Reexports.Binding;

pub const PublicDeclarations = struct {
    functions: usize = 0,
    structures: usize = 0,
    enumerations: usize = 0,

    pub fn isUnambiguous(self: PublicDeclarations) bool {
        const kinds = @as(u2, @intFromBool(self.functions != 0)) +
            @as(u2, @intFromBool(self.structures != 0)) +
            @as(u2, @intFromBool(self.enumerations != 0));
        return kinds == 1 and self.structures <= 1 and self.enumerations <= 1;
    }
};

pub fn indexPublicDeclarations(self: anytype, module: usize, name: []const u8) !PublicDeclarations {
    return indexPublicDeclarationsOwnedBy(self, module, name, null);
}

fn indexPublicDeclarationsOwnedBy(
    self: anytype,
    module: usize,
    name: []const u8,
    owner: ?usize,
) !PublicDeclarations {
    var declarations: PublicDeclarations = .{};
    const fragments = self.units[module].fragments;
    const candidates = if (fragments.len == 0) &[_]usize{module} else fragments;
    for (candidates) |fragment| {
        if (owner) |required_owner| {
            if (self.index.providers[fragment].owner != required_owner) continue;
        }
        try indexPublicSurface(self, fragment);
        for (self.units[fragment].public_declarations) |declaration| {
            if (!std.mem.eql(u8, declaration.name, name)) continue;
            switch (declaration.kind) {
                .function => declarations.functions += 1,
                .structure => declarations.structures += 1,
                .enumeration => declarations.enumerations += 1,
            }
        }
    }
    return declarations;
}

fn indexPublicSurface(self: anytype, fragment: usize) !void {
    if (self.units[fragment].public_surface_indexed) return;
    const provider = self.index.providers[fragment];
    const source = self.units[fragment].source orelse source: {
        const loaded = try std.Io.Dir.cwd().readFileAlloc(self.io, provider.path, self.allocator, .limited(1024 * 1024));
        self.source_bytes_read += loaded.len;
        self.units[fragment].source = loaded;
        break :source loaded;
    };
    var declarations: std.ArrayList(Reexports.PublicDeclaration) = .empty;
    try scanPublicDeclarations(self.allocator, source, &declarations);
    self.units[fragment].public_declarations = try declarations.toOwnedSlice(self.allocator);
    self.units[fragment].public_surface_indexed = true;
    self.indexed_declarations += self.units[fragment].public_declarations.len;
}

fn scanPublicDeclarations(
    allocator: std.mem.Allocator,
    source: []const u8,
    declarations: *std.ArrayList(Reexports.PublicDeclaration),
) std.mem.Allocator.Error!void {
    var lexer = LexerModule.Lexer.init(source);
    var depth: usize = 0;
    while (true) {
        const token = lexer.next() catch return;
        switch (token.tag) {
            .left_brace => depth += 1,
            .right_brace => depth -|= 1,
            .keyword_public => if (depth == 0) try scanPublicDeclaration(allocator, &lexer, declarations),
            .end => return,
            else => {},
        }
    }
}

fn scanPublicDeclaration(
    allocator: std.mem.Allocator,
    lexer: *LexerModule.Lexer,
    declarations: *std.ArrayList(Reexports.PublicDeclaration),
) std.mem.Allocator.Error!void {
    var marker = lexer.next() catch return;
    if (marker.tag == .keyword_static) marker = lexer.next() catch return;
    if (marker.tag == .identifier and std.mem.eql(u8, marker.lexeme, "intrinsic")) {
        marker = lexer.next() catch return;
    }
    const kind = marker.tag;
    const declaration_name = lexer.next() catch return;
    if (declaration_name.tag != .identifier) return;
    const declaration_kind: Reexports.DeclarationKind = switch (kind) {
        .keyword_func => .function,
        .keyword_struct, .keyword_class, .keyword_protocol => .structure,
        .keyword_enum => .enumeration,
        else => return,
    };
    try declarations.append(allocator, .{ .name = declaration_name.lexeme, .kind = declaration_kind });
}

pub fn discoverCatalogContributions(self: anytype) !void {
    var contributions: std.ArrayList(Reexports.CatalogContribution) = .empty;
    for (self.index.providers, 0..) |provider, module| {
        if (provider.origin != .portable) continue;
        const package_name = self.packages.packages[provider.owner].name orelse continue;
        if (!std.mem.eql(u8, provider.name, package_name)) continue;

        const source = try std.Io.Dir.cwd().readFileAlloc(self.io, provider.path, self.allocator, .limited(1024 * 1024));
        self.source_bytes_read += source.len;
        self.units[module].source = source;
        if (!containsContribution(source)) continue;
        var parser = ParserModule.Parser.initFile(self.allocator, source, provider.file);
        const parsed = parser.parse() catch |err| {
            self.diagnostic = parser.diagnostic;
            return err;
        };
        self.parsed_modules += 1;
        const program = try Result.install(self.allocator, parsed);
        self.units[module].program = program;
        for (program.catalog_contributions) |contribution| {
            const target = catalogTarget(self, provider.owner, contribution.target) orelse {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "package '{s}' cannot contribute to '{s}'; its parent must declare that existing module in catalogs",
                    .{ package_name, contribution.target },
                );
                return self.fail(contribution.target_position, message);
            };
            for (contribution.uses) |use| try contributions.append(self.allocator, .{
                .contributor = module,
                .target = target,
                .use = use,
            });
        }
    }
    self.catalog_contributions = try contributions.toOwnedSlice(self.allocator);
}

fn containsContribution(source: []const u8) bool {
    var lexer = LexerModule.Lexer.init(source);
    while (true) {
        const token = lexer.next() catch return false;
        if (token.tag == .keyword_contribute) return true;
        if (token.tag == .end) return false;
    }
}

fn catalogTarget(self: anytype, contributor: usize, name: []const u8) ?usize {
    for (self.index.providers, 0..) |provider, module| {
        if (!std.mem.eql(u8, provider.name, name)) continue;
        if (self.packages.canContributeToCatalog(contributor, provider.owner, name)) return module;
    }
    return null;
}

pub fn load(self: anytype, module: usize, from: ?usize) !void {
    if (from) |source| {
        if (!Fragments.same(self.index, source, module)) try recordActivation(self, source, module);
    }

    var all_loaded = true;
    var loading = false;
    for (self.units, 0..) |unit, fragment| {
        if (!Fragments.same(self.index, module, fragment)) continue;
        all_loaded = all_loaded and unit.state == .loaded;
        loading = loading or unit.state == .loading;
    }
    if (all_loaded) return;
    if (loading) {
        if (from) |source| {
            if (!Fragments.same(self.index, source, module) and
                !Names.sameParent(self.index.providers[source].name, self.index.providers[module].name))
            {
                return self.fail(
                    .{ .offset = 0, .line = 1, .column = 1, .file = self.index.providers[source].file },
                    "module dependency cycle crosses logical parents",
                );
            }
        }
        return;
    }

    for (self.units, 0..) |*unit, fragment| {
        if (!Fragments.same(self.index, module, fragment)) continue;
        unit.state = .loading;
        try parse(self, fragment);
    }
    try validateMergedDeclarations(self, module);
    for (self.units, 0..) |unit, fragment| {
        if (!Fragments.same(self.index, module, fragment) or unit.state != .loading) continue;
        try bind(self, fragment);
    }
    for (self.units, 0..) |*unit, fragment| {
        if (!Fragments.same(self.index, module, fragment) or unit.state != .loading) continue;
        try self.activateQualifiedReferences(fragment);
        unit.state = .loaded;
    }
}

fn validateMergedDeclarations(self: anytype, module: usize) !void {
    const fragments = self.units[module].fragments;
    for (fragments, 0..) |left, left_index| {
        const left_provider = self.index.providers[left];
        const left_program = self.units[left].program orelse continue;
        for (fragments[left_index + 1 ..]) |right| {
            const right_provider = self.index.providers[right];
            if (left_provider.owner == right_provider.owner) continue;
            const right_program = self.units[right].program orelse continue;
            for (right_program.functions) |function| {
                if (function.is_public and hasPublicName(left_program, function.name)) {
                    return mergedDeclarationCollision(self, right, function.name, function.name_position, left_provider.owner);
                }
            }
            for (right_program.structures) |structure| {
                if (publicStructureDeclaration(right_program, structure) and hasPublicName(left_program, structure.name)) {
                    return mergedDeclarationCollision(self, right, structure.name, structure.name_position, left_provider.owner);
                }
            }
            for (right_program.enums) |enumeration| {
                if (enumeration.is_public and hasPublicName(left_program, enumeration.name)) {
                    return mergedDeclarationCollision(self, right, enumeration.name, enumeration.name_position, left_provider.owner);
                }
            }
            for (right_program.uses) |use| {
                if (!use.is_public) continue;
                const alias = use.alias orelse Names.lastSegment(use.path);
                if (hasPublicName(left_program, alias)) {
                    return mergedDeclarationCollision(
                        self,
                        right,
                        alias,
                        use.alias_position orelse use.position,
                        left_provider.owner,
                    );
                }
            }
        }
    }
}

fn hasPublicName(program: Ast.Program, name: []const u8) bool {
    if (std.mem.eql(u8, name, Result.name)) return false;
    for (program.functions) |function| if (function.is_public and std.mem.eql(u8, function.name, name)) return true;
    for (program.structures) |structure| {
        if (publicStructureDeclaration(program, structure) and std.mem.eql(u8, structure.name, name)) return true;
    }
    for (program.enums) |enumeration| if (enumeration.is_public and std.mem.eql(u8, enumeration.name, name)) return true;
    for (program.uses) |use| {
        if (!use.is_public) continue;
        const alias = use.alias orelse Names.lastSegment(use.path);
        if (std.mem.eql(u8, alias, name)) return true;
    }
    return false;
}

fn publicStructureDeclaration(program: Ast.Program, structure: Ast.Structure) bool {
    if (structure.collection != null or structure.is_tuple) return false;
    return Reexports.structureExported(program, structure);
}

fn mergedDeclarationCollision(
    self: anytype,
    provider: usize,
    name: []const u8,
    position: @import("../Source.zig").Position,
    previous_owner: usize,
) !void {
    const message = try std.fmt.allocPrint(
        self.allocator,
        "public declaration '{s}' from extension package '{s}' collides with package '{s}' in merged module '{s}'",
        .{
            name,
            self.packages.label(self.index.providers[provider].owner),
            self.packages.label(previous_owner),
            self.index.providers[provider].name,
        },
    );
    return self.fail(position, message);
}

fn parse(self: anytype, fragment: usize) !void {
    const provider = self.index.providers[fragment];
    if (self.units[fragment].program == null) {
        const source = self.units[fragment].source orelse source: {
            const loaded = try std.Io.Dir.cwd().readFileAlloc(self.io, provider.path, self.allocator, .limited(1024 * 1024));
            self.source_bytes_read += loaded.len;
            self.units[fragment].source = loaded;
            break :source loaded;
        };
        const cached = if (self.cache_modules) CompilationCache.loadAst(self.allocator, self.io, provider.path, source) else null;
        self.units[fragment].program = cached orelse parsed: {
            var parser = ParserModule.Parser.initFile(self.allocator, source, provider.file);
            const parsed_program = parser.parse() catch |err| {
                self.diagnostic = parser.diagnostic;
                return err;
            };
            const installed = try Result.install(self.allocator, parsed_program);
            self.parsed_modules += 1;
            if (self.cache_modules) CompilationCache.storeAst(self.allocator, self.io, provider.path, source, installed);
            break :parsed installed;
        };
    }
    if (self.units[fragment].program.?.catalog_contributions.len != 0) {
        const package_name = self.packages.packages[provider.owner].name;
        if (package_name == null or provider.origin != .portable or !std.mem.eql(u8, provider.name, package_name.?)) {
            return self.fail(
                self.units[fragment].program.?.catalog_contributions[0].position,
                "umbrella contributions must be declared in a named package's portable principal module",
            );
        }
    }
    for (self.units[fragment].program.?.functions) |function| {
        if (function.is_public and std.mem.eql(u8, function.name, "main")) {
            return self.fail(function.name_position, "'main' cannot be public");
        }
    }
}

fn bind(self: anytype, module: usize) !void {
    const program = self.units[module].program.?;
    var bindings: std.ArrayList(Binding) = .empty;
    for (program.uses) |use| {
        const binding = try self.resolveUse(module, use);
        for (program.functions) |function| {
            if (std.mem.eql(u8, function.name, binding.alias)) return aliasCollision(self, use, binding.alias);
        }
        for (program.external_functions) |external| {
            if (std.mem.eql(u8, external.name, binding.alias)) return aliasCollision(self, use, binding.alias);
        }
        for (program.structures) |structure| {
            if (std.mem.eql(u8, structure.name, binding.alias)) return aliasCollision(self, use, binding.alias);
        }
        for (program.enums) |enumeration| {
            if (std.mem.eql(u8, enumeration.name, binding.alias)) return aliasCollision(self, use, binding.alias);
        }
        for (bindings.items) |existing| {
            if (!std.mem.eql(u8, existing.alias, binding.alias)) continue;
            const position = use.alias_position orelse use.position;
            const message = try std.fmt.allocPrint(self.allocator, "use alias '{s}' is already declared", .{binding.alias});
            return self.fail(position, message);
        }
        try bindings.append(self.allocator, binding);
        // Public uses describe a module's exported catalog. Keep the binding
        // discoverable, but load its provider only when a declaration from
        // that catalog enters the active semantic closure.
        if (!binding.is_public) if (binding.module) |dependency| try self.loadModule(dependency, module);
    }
    for (self.catalog_contributions) |contribution| {
        if (contribution.target != module) continue;
        const binding = try self.resolveUse(contribution.contributor, contribution.use);
        const dependency = binding.module orelse return invalidContributionSource(self, contribution);
        const declaration = binding.declaration orelse return invalidContributionSource(self, contribution);
        const contributor_owner = self.index.providers[contribution.contributor].owner;
        const indexed = try indexPublicDeclarationsOwnedBy(self, dependency, declaration, contributor_owner);
        if (!indexed.isUnambiguous()) {
            try self.loadModule(dependency, module);
        }
        if (!indexed.isUnambiguous() and !directPublicDeclarationOwnedBy(self, dependency, declaration, contributor_owner)) {
            return invalidContributionSource(self, contribution);
        }
        try requireAvailableContributionAlias(self, module, program, bindings.items, contribution, binding.alias);
        try bindings.append(self.allocator, binding);
    }
    self.units[module].bindings = try bindings.toOwnedSlice(self.allocator);
}

fn invalidContributionSource(self: anytype, contribution: Reexports.CatalogContribution) !void {
    const package_name = self.packages.label(self.index.providers[contribution.contributor].owner);
    const message = try std.fmt.allocPrint(
        self.allocator,
        "an umbrella contribution can only reexport a declaration owned by package '{s}'",
        .{package_name},
    );
    return self.fail(contribution.use.position, message);
}

fn directPublicDeclarationOwnedBy(self: anytype, module: usize, name: []const u8, owner: usize) bool {
    for (self.units, 0..) |unit, fragment| {
        if (!Fragments.same(self.index, module, fragment)) continue;
        if (self.index.providers[fragment].owner != owner) continue;
        const program = unit.program orelse continue;
        for (program.functions) |function| {
            if (function.is_public and std.mem.eql(u8, function.name, name)) return true;
        }
        for (program.structures) |structure| {
            if (Reexports.structureExported(program, structure) and std.mem.eql(u8, structure.name, name)) return true;
        }
        for (program.enums) |enumeration| {
            if (enumeration.is_public and std.mem.eql(u8, enumeration.name, name)) return true;
        }
    }
    return false;
}

fn requireAvailableContributionAlias(
    self: anytype,
    target: usize,
    program: @import("../Ast.zig").Program,
    pending: []const Binding,
    contribution: Reexports.CatalogContribution,
    alias: []const u8,
) !void {
    for (program.functions) |function| if (std.mem.eql(u8, function.name, alias)) return contributionCollision(self, contribution, alias);
    for (program.external_functions) |external| if (std.mem.eql(u8, external.name, alias)) return contributionCollision(self, contribution, alias);
    for (program.structures) |structure| if (std.mem.eql(u8, structure.name, alias)) return contributionCollision(self, contribution, alias);
    for (program.enums) |enumeration| if (std.mem.eql(u8, enumeration.name, alias)) return contributionCollision(self, contribution, alias);
    for (pending) |binding| if (std.mem.eql(u8, binding.alias, alias)) return contributionCollision(self, contribution, alias);
    for (self.units, 0..) |unit, fragment| {
        if (fragment == target or !Fragments.same(self.index, target, fragment)) continue;
        if (unit.program) |fragment_program| {
            for (fragment_program.functions) |function| if (std.mem.eql(u8, function.name, alias)) return contributionCollision(self, contribution, alias);
            for (fragment_program.external_functions) |external| if (std.mem.eql(u8, external.name, alias)) return contributionCollision(self, contribution, alias);
            for (fragment_program.structures) |structure| if (std.mem.eql(u8, structure.name, alias)) return contributionCollision(self, contribution, alias);
            for (fragment_program.enums) |enumeration| if (std.mem.eql(u8, enumeration.name, alias)) return contributionCollision(self, contribution, alias);
        }
        for (unit.bindings) |binding| if (std.mem.eql(u8, binding.alias, alias)) return contributionCollision(self, contribution, alias);
    }
    const child = try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ self.index.providers[target].name, alias });
    if (self.index.isNamespace(child)) return contributionCollision(self, contribution, alias);
}

fn contributionCollision(self: anytype, contribution: Reexports.CatalogContribution, alias: []const u8) !void {
    const message = try std.fmt.allocPrint(
        self.allocator,
        "umbrella contribution '{s}' collides with an existing declaration or child namespace",
        .{alias},
    );
    return self.fail(contribution.use.alias_position orelse contribution.use.position, message);
}

fn aliasCollision(self: anytype, use: anytype, alias: []const u8) !void {
    const position = use.alias_position orelse use.position;
    const message = try std.fmt.allocPrint(self.allocator, "use alias '{s}' collides with a local declaration", .{alias});
    return self.fail(position, message);
}

fn recordActivation(self: anytype, source: usize, dependency: usize) !void {
    if (source == dependency) return;
    for (self.units[source].activated_modules) |existing| {
        if (existing == dependency) return;
    }
    const previous = self.units[source].activated_modules;
    const expanded = try self.allocator.alloc(usize, previous.len + 1);
    @memcpy(expanded[0..previous.len], previous);
    expanded[previous.len] = dependency;
    self.units[source].activated_modules = expanded;
}
