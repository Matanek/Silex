const std = @import("std");
const CompilationCache = @import("../CompilationCache.zig");
const Result = @import("../Intrinsics/Result.zig");
const ParserModule = @import("../Parser.zig");
const Fragments = @import("Fragments.zig");
const Reexports = @import("Reexports.zig");
const Names = @import("Names.zig");

const Binding = Reexports.Binding;

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

fn parse(self: anytype, fragment: usize) !void {
    const provider = self.index.providers[fragment];
    const source = try std.Io.Dir.cwd().readFileAlloc(self.io, provider.path, self.allocator, .limited(1024 * 1024));
    const cached = if (self.cache_modules) CompilationCache.loadAst(self.allocator, self.io, provider.path, source) else null;
    self.units[fragment].program = cached orelse parsed: {
        var parser = ParserModule.Parser.initFile(self.allocator, source, provider.file);
        const parsed_program = parser.parse() catch |err| {
            self.diagnostic = parser.diagnostic;
            return err;
        };
        const installed = try Result.install(self.allocator, parsed_program);
        if (self.cache_modules) CompilationCache.storeAst(self.allocator, self.io, provider.path, source, installed);
        break :parsed installed;
    };
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
        if (binding.module) |dependency| try self.loadModule(dependency, module);
    }
    self.units[module].bindings = try bindings.toOwnedSlice(self.allocator);
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
