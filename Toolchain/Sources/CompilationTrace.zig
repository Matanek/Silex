const std = @import("std");

const Allocator = std.mem.Allocator;
const Io = std.Io;

pub const environment_name = "SILEX_COMPILATION_TRACE";

pub const Command = enum {
    compile,
    run,
};

pub const CacheResult = enum {
    disabled,
    miss,
    hit_before_frontend,
    hit_after_frontend,
};

pub const Phase = enum(u8) {
    cache_validation,
    frontend_total,
    package_resolution,
    module_discovery,
    module_loading,
    composition,
    specialization,
    interface_building,
    semantic_analysis,
    cache_update,
    program_closure,
    optimization,
    lowering,
    register_allocation,
    emission,
    linking,
    output_write,
    cache_publication,
};

const phase_count = @typeInfo(Phase).@"enum".fields.len;

pub const Metrics = struct {
    packages: usize = 0,
    discovered_modules: usize = 0,
    loaded_modules: usize = 0,
    parsed_modules: usize = 0,
    indexed_declarations: usize = 0,
    source_bytes_read: usize = 0,
    ast_functions: usize = 0,
    portable_functions: usize = 0,
    reachable_portable_functions: usize = 0,
    boundaries: usize = 0,
    boundary_providers: usize = 0,
    dependency_files: usize = 0,
    machine_functions: usize = 0,
    output_bytes: usize = 0,
};

pub const Metadata = struct {
    command: Command,
    source_path: []const u8,
    target: []const u8,
    mode: []const u8,
    cache_enabled: bool,
    compiler_version: []const u8,
};

const PhaseSample = struct {
    name: []const u8,
    nanoseconds: u64,
    invocations: u32,
};

const Report = struct {
    schema_version: u8 = 1,
    command: Command,
    source_path: []const u8,
    target: []const u8,
    mode: []const u8,
    compiler_version: []const u8,
    worker_count: u16 = 1,
    cache_enabled: bool,
    cache_result: CacheResult,
    success: bool,
    total_nanoseconds: u64,
    phases: []const PhaseSample,
    metrics: Metrics,
};

pub const Reporter = struct {
    io: Io,
    output_path: ?[]const u8 = null,
    metadata: Metadata,
    started: Io.Timestamp,
    phase_nanoseconds: [phase_count]u64 = @splat(0),
    phase_invocations: [phase_count]u32 = @splat(0),
    cache_result: CacheResult,
    success: bool = false,
    metrics: Metrics = .{},

    pub fn init(
        io: Io,
        environment: *const std.process.Environ.Map,
        metadata: Metadata,
    ) Reporter {
        return .{
            .io = io,
            .output_path = environment.get(environment_name),
            .metadata = metadata,
            .started = Io.Clock.awake.now(io),
            .cache_result = if (metadata.cache_enabled) .miss else .disabled,
        };
    }

    fn initEnabled(io: Io, output_path: []const u8, metadata: Metadata) Reporter {
        return .{
            .io = io,
            .output_path = output_path,
            .metadata = metadata,
            .started = Io.Clock.awake.now(io),
            .cache_result = if (metadata.cache_enabled) .miss else .disabled,
        };
    }

    pub fn enabled(self: Reporter) bool {
        return self.output_path != null;
    }

    pub fn span(self: *Reporter, phase: Phase) Span {
        if (!self.enabled()) return .{};
        return .{
            .reporter = self,
            .phase = phase,
            .started = Io.Clock.awake.now(self.io),
        };
    }

    pub fn record(self: *Reporter, phase: Phase, nanoseconds: u64) void {
        if (!self.enabled()) return;
        const index = @intFromEnum(phase);
        self.phase_nanoseconds[index] +|= nanoseconds;
        self.phase_invocations[index] +|= 1;
    }

    pub fn cacheHit(self: *Reporter, result: CacheResult) void {
        if (!self.enabled()) return;
        std.debug.assert(result == .hit_before_frontend or result == .hit_after_frontend);
        self.cache_result = result;
    }

    pub fn succeeded(self: *Reporter) void {
        if (!self.enabled()) return;
        self.success = true;
    }

    pub fn write(self: *Reporter, allocator: Allocator) void {
        const output_path = self.output_path orelse return;
        const encoded = self.payload(allocator) catch |err| {
            std.debug.print("silex: unable to encode compilation trace: {t}\n", .{err});
            return;
        };
        if (std.fs.path.dirname(output_path)) |directory| {
            if (directory.len != 0) Io.Dir.cwd().createDirPath(self.io, directory) catch |err| {
                std.debug.print("silex: unable to create compilation trace directory: {t}\n", .{err});
                return;
            };
        }
        const file = Io.Dir.cwd().createFile(self.io, output_path, .{}) catch |err| {
            std.debug.print("silex: unable to create compilation trace '{s}': {t}\n", .{ output_path, err });
            return;
        };
        defer file.close(self.io);
        file.writeStreamingAll(self.io, encoded) catch |err| {
            std.debug.print("silex: unable to write compilation trace '{s}': {t}\n", .{ output_path, err });
        };
    }

    fn payload(self: *Reporter, allocator: Allocator) ![]const u8 {
        var samples: [phase_count]PhaseSample = undefined;
        for (0..phase_count) |index| {
            const phase: Phase = @enumFromInt(index);
            samples[index] = .{
                .name = @tagName(phase),
                .nanoseconds = self.phase_nanoseconds[index],
                .invocations = self.phase_invocations[index],
            };
        }
        const elapsed = self.started.durationTo(Io.Clock.awake.now(self.io)).toNanoseconds();
        return std.json.Stringify.valueAlloc(allocator, Report{
            .command = self.metadata.command,
            .source_path = self.metadata.source_path,
            .target = self.metadata.target,
            .mode = self.metadata.mode,
            .compiler_version = self.metadata.compiler_version,
            .worker_count = 1,
            .cache_enabled = self.metadata.cache_enabled,
            .cache_result = self.cache_result,
            .success = self.success,
            .total_nanoseconds = @intCast(@max(0, elapsed)),
            .phases = &samples,
            .metrics = self.metrics,
        }, .{ .whitespace = .indent_2 });
    }
};

pub const Span = struct {
    reporter: ?*Reporter = null,
    phase: Phase = .cache_validation,
    started: Io.Timestamp = .zero,
    finished: bool = false,

    pub fn finish(self: *Span) void {
        if (self.finished) return;
        self.finished = true;
        const reporter = self.reporter orelse return;
        const elapsed = self.started.durationTo(Io.Clock.awake.now(reporter.io)).toNanoseconds();
        reporter.record(self.phase, @intCast(@max(0, elapsed)));
    }
};

const test_metadata: Metadata = .{
    .command = .compile,
    .source_path = "Example.sx",
    .target = "macos-arm64",
    .mode = "release",
    .cache_enabled = true,
    .compiler_version = "test",
};

test "disabled compilation trace records no phase" {
    var environment = std.process.Environ.Map.init(std.testing.allocator);
    defer environment.deinit();
    var reporter = Reporter.init(std.testing.io, &environment, test_metadata);
    var span = reporter.span(.frontend_total);
    span.finish();
    try std.testing.expect(!reporter.enabled());
    try std.testing.expectEqual(@as(u32, 0), reporter.phase_invocations[@intFromEnum(Phase.frontend_total)]);
}

test "compilation trace encodes stable structured phases and metrics" {
    var reporter = Reporter.initEnabled(std.testing.io, "trace.json", test_metadata);
    reporter.record(.frontend_total, 42);
    reporter.metrics.loaded_modules = 7;
    reporter.cacheHit(.hit_after_frontend);
    reporter.succeeded();
    const payload = try reporter.payload(std.testing.allocator);
    defer std.testing.allocator.free(payload);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"schema_version\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"worker_count\": 1") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"name\": \"frontend_total\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"nanoseconds\": 42") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"loaded_modules\": 7") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"cache_result\": \"hit_after_frontend\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"success\": true") != null);
}

test "compilation trace preserves a diagnosed unsuccessful state" {
    var reporter = Reporter.initEnabled(std.testing.io, "trace.json", test_metadata);
    reporter.record(.module_loading, 17);
    const payload = try reporter.payload(std.testing.allocator);
    defer std.testing.allocator.free(payload);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"success\": false") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"name\": \"module_loading\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, payload, "\"nanoseconds\": 17") != null);
}
