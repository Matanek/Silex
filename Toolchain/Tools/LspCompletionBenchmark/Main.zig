const std = @import("std");
const Lsp = @import("silex_lsp");
const Workspace = Lsp.Workspace;
const Types = Lsp.Types;

const canonical_source =
    \\use Module.Transform
    \\func update(transform:&Transform.Transform2D) {
    \\    transform.position.
    \\}
    \\func main() {}
;

const edited_math_source =
    \\public struct Vec2 {
    \\    func edited() int { return 1 }
    \\    func length() float { return 1.0 }
    \\    func normalized() Vec2 { return self }
    \\}
;

const Sample = struct {
    nanoseconds: u64,
    allocation_calls: usize,
    requested_bytes: usize,
};

const Summary = struct {
    median_ns: u64,
    p95_ns: u64,
    minimum_ns: u64,
    maximum_ns: u64,
    standard_deviation_ns: f64,
    mean_allocation_calls: usize,
    mean_requested_bytes: usize,
};

pub fn main(init: std.process.Init) u8 {
    return run(init) catch |err| {
        std.debug.print("LSP completion benchmark: {t}\n", .{err});
        return 1;
    };
}

fn run(init: std.process.Init) !u8 {
    const allocator = init.arena.allocator();
    const arguments = try init.minimal.args.toSlice(allocator);
    if (arguments.len < 2 or arguments.len > 3) return error.InvalidArguments;
    const iterations = if (arguments.len == 3) try std.fmt.parseInt(usize, arguments[2], 10) else 31;
    if (iterations < 5 or iterations % 2 == 0) return error.InvalidIterations;

    const root = arguments[1];
    const root_uri = try std.fmt.allocPrint(allocator, "file://{s}", .{root});
    const main_uri = try std.fmt.allocPrint(allocator, "file://{s}/Main.sx", .{root});
    const math_uri = try std.fmt.allocPrint(allocator, "file://{s}/Math.sx", .{root});

    const fresh = try collect(init.io, allocator, iterations, root_uri, main_uri, math_uri, false);
    _ = try measure(init.io, root_uri, main_uri, math_uri, false);
    const warm = try collect(init.io, allocator, iterations, root_uri, main_uri, math_uri, false);
    const overlay = try collect(init.io, allocator, iterations, root_uri, main_uri, math_uri, true);

    const fresh_summary = summarize(fresh);
    const warm_summary = summarize(warm);
    const overlay_summary = summarize(overlay);
    const output = try std.fmt.allocPrint(
        allocator,
        "mode\titerations\tmedian_us\tp95_us\tmin_us\tmax_us\tstddev_us\tmean_alloc_calls\tmean_requested_bytes\n" ++
            "fresh_workspace\t{d}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\t{d}\n" ++
            "warmed_filesystem\t{d}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\t{d}\n" ++
            "overlay_after_edit\t{d}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d:.3}\t{d}\t{d}\n" ++
            "allocation_scope\tarena_backing_allocator\n",
        .{
            iterations,
            microseconds(fresh_summary.median_ns),
            microseconds(fresh_summary.p95_ns),
            microseconds(fresh_summary.minimum_ns),
            microseconds(fresh_summary.maximum_ns),
            fresh_summary.standard_deviation_ns / std.time.ns_per_us,
            fresh_summary.mean_allocation_calls,
            fresh_summary.mean_requested_bytes,
            iterations,
            microseconds(warm_summary.median_ns),
            microseconds(warm_summary.p95_ns),
            microseconds(warm_summary.minimum_ns),
            microseconds(warm_summary.maximum_ns),
            warm_summary.standard_deviation_ns / std.time.ns_per_us,
            warm_summary.mean_allocation_calls,
            warm_summary.mean_requested_bytes,
            iterations,
            microseconds(overlay_summary.median_ns),
            microseconds(overlay_summary.p95_ns),
            microseconds(overlay_summary.minimum_ns),
            microseconds(overlay_summary.maximum_ns),
            overlay_summary.standard_deviation_ns / std.time.ns_per_us,
            overlay_summary.mean_allocation_calls,
            overlay_summary.mean_requested_bytes,
        },
    );
    try std.Io.File.stdout().writeStreamingAll(init.io, output);
    return 0;
}

fn collect(
    io: std.Io,
    allocator: std.mem.Allocator,
    iterations: usize,
    root_uri: []const u8,
    main_uri: []const u8,
    math_uri: []const u8,
    overlay: bool,
) ![]Sample {
    const samples = try allocator.alloc(Sample, iterations);
    for (samples) |*sample| sample.* = try measure(io, root_uri, main_uri, math_uri, overlay);
    return samples;
}

fn measure(
    io: std.Io,
    root_uri: []const u8,
    main_uri: []const u8,
    math_uri: []const u8,
    overlay: bool,
) !Sample {
    var counter = CountingAllocator.init(std.heap.page_allocator);
    var arena = std.heap.ArenaAllocator.init(counter.allocator());
    defer arena.deinit();
    const documents = if (overlay)
        &[_]Types.Document{.{ .uri = math_uri, .text = edited_math_source, .version = 2 }}
    else
        &[_]Types.Document{};
    const expected = if (overlay) "edited" else "length";
    const started = std.Io.Clock.Timestamp.now(io, .awake);
    const items = (try Workspace.itemsAt(
        arena.allocator(),
        io,
        null,
        root_uri,
        main_uri,
        documents,
        canonical_source,
        std.mem.indexOf(u8, canonical_source, "position.").? + "position.".len,
    )) orelse return error.MissingCompletionResult;
    const finished = std.Io.Clock.Timestamp.now(io, .awake);
    if (!hasLabel(items, expected)) return error.MissingExpectedCandidate;
    return .{
        .nanoseconds = @intCast(started.durationTo(finished).raw.nanoseconds),
        .allocation_calls = counter.allocation_calls,
        .requested_bytes = counter.requested_bytes,
    };
}

fn hasLabel(items: []const Types.CompletionItem, expected: []const u8) bool {
    for (items) |item| if (std.mem.eql(u8, item.label, expected)) return true;
    return false;
}

fn summarize(samples: []Sample) Summary {
    std.mem.sort(Sample, samples, {}, struct {
        fn lessThan(_: void, left: Sample, right: Sample) bool {
            return left.nanoseconds < right.nanoseconds;
        }
    }.lessThan);
    const median = samples.len / 2;
    const p95 = @min(samples.len - 1, (samples.len * 95 + 99) / 100 - 1);
    var allocation_calls: usize = 0;
    var requested_bytes: usize = 0;
    var mean_nanoseconds: f64 = 0.0;
    for (samples) |sample| {
        allocation_calls += sample.allocation_calls;
        requested_bytes += sample.requested_bytes;
        mean_nanoseconds += @floatFromInt(sample.nanoseconds);
    }
    mean_nanoseconds /= @floatFromInt(samples.len);
    var variance: f64 = 0.0;
    for (samples) |sample| {
        const distance = @as(f64, @floatFromInt(sample.nanoseconds)) - mean_nanoseconds;
        variance += distance * distance;
    }
    variance /= @floatFromInt(samples.len);
    return .{
        .median_ns = samples[median].nanoseconds,
        .p95_ns = samples[p95].nanoseconds,
        .minimum_ns = samples[0].nanoseconds,
        .maximum_ns = samples[samples.len - 1].nanoseconds,
        .standard_deviation_ns = @sqrt(variance),
        .mean_allocation_calls = allocation_calls / samples.len,
        .mean_requested_bytes = requested_bytes / samples.len,
    };
}

fn microseconds(nanoseconds: u64) f64 {
    return @as(f64, @floatFromInt(nanoseconds)) / std.time.ns_per_us;
}

const CountingAllocator = struct {
    child: std.mem.Allocator,
    allocation_calls: usize = 0,
    requested_bytes: usize = 0,

    fn init(child: std.mem.Allocator) CountingAllocator {
        return .{ .child = child };
    }

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &vtable };
    }

    const vtable: std.mem.Allocator.VTable = .{
        .alloc = allocate,
        .resize = resize,
        .remap = remap,
        .free = free,
    };

    fn allocate(context: *anyopaque, length: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(context));
        const result = self.child.rawAlloc(length, alignment, return_address);
        if (result != null) {
            self.allocation_calls += 1;
            self.requested_bytes += length;
        }
        return result;
    }

    fn resize(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_length: usize,
        return_address: usize,
    ) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(context));
        const resized = self.child.rawResize(memory, alignment, new_length, return_address);
        if (resized and new_length > memory.len) self.requested_bytes += new_length - memory.len;
        return resized;
    }

    fn remap(
        context: *anyopaque,
        memory: []u8,
        alignment: std.mem.Alignment,
        new_length: usize,
        return_address: usize,
    ) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(context));
        const result = self.child.rawRemap(memory, alignment, new_length, return_address);
        if (result != null and new_length > memory.len) self.requested_bytes += new_length - memory.len;
        return result;
    }

    fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(context));
        self.child.rawFree(memory, alignment, return_address);
    }
};
