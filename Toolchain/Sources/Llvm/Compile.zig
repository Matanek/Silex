const std = @import("std");
const CliProgress = @import("../CliProgress.zig");
const Workers = @import("../Workers.zig");
const Allocator = std.mem.Allocator;

pub const Job = struct {
    text: []const u8,
    raw_path: []const u8,
    optimized_path: []const u8,
    object_path: []const u8,
    digest: [32]u8,
    succeeded: bool = false,
};

pub const Options = struct {
    allocator: Allocator,
    io: std.Io,
    opt: []const u8,
    llc: []const u8,
    passes: []const u8,
    level: []const u8,
    cpu: []const u8,
    workers: u16,
    progress: ?*CliProgress.Build,
};

pub fn run(options: Options, jobs: []Job) bool {
    if (jobs.len == 0) return true;
    var next = std.atomic.Value(usize).init(0);
    var finished = std.atomic.Value(usize).init(0);
    var failed = std.atomic.Value(bool).init(false);
    var contexts: [Workers.max_count]Worker = undefined;
    const count = @max(1, @min(@min(jobs.len, options.workers), Workers.max_count));
    for (contexts[0..count]) |*worker| worker.* = .{
        .options = options,
        .jobs = jobs,
        .next = &next,
        .finished = &finished,
        .failed = &failed,
    };
    Workers.run(Worker, contexts[0..count], Worker.run);
    return !failed.load(.monotonic);
}

const Worker = struct {
    options: Options,
    jobs: []Job,
    next: *std.atomic.Value(usize),
    finished: *std.atomic.Value(usize),
    failed: *std.atomic.Value(bool),

    fn run(self: *Worker) void {
        while (!self.failed.load(.monotonic)) {
            const index = self.next.fetchAdd(1, .monotonic);
            if (index >= self.jobs.len) return;
            self.compile(&self.jobs[index]) catch |err| {
                if (err != error.LlvmToolFailed) std.debug.print("silex: LLVM compilation failed: {t}\n", .{err});
                self.failed.store(true, .monotonic);
                return;
            };
            const completed = self.finished.fetchAdd(1, .monotonic) + 1;
            if (self.options.progress) |progress| {
                var buffer: [96]u8 = undefined;
                const message = std.fmt.bufPrint(&buffer, "{d}/{d} functions", .{ completed, self.jobs.len }) catch "functions";
                progress.source(.emit, message);
            }
        }
    }

    fn compile(self: *Worker, job: *Job) !void {
        const o = self.options;
        try std.Io.Dir.cwd().writeFile(o.io, .{ .sub_path = job.raw_path, .data = job.text });
        defer std.Io.Dir.cwd().deleteFile(o.io, job.raw_path) catch {};
        defer std.Io.Dir.cwd().deleteFile(o.io, job.optimized_path) catch {};
        try stage(o, "opt", &.{ o.opt, "-S", o.passes, job.raw_path, "-o", job.optimized_path });
        try stage(o, "llc", &.{
            o.llc,           "-filetype=obj",    o.level,            "-mtriple=arm64-apple-macosx26.0.0",
            o.cpu,           "-fp-contract=off", job.optimized_path, "-o",
            job.object_path,
        });
        job.succeeded = true;
    }
};

fn stage(options: Options, name: []const u8, arguments: []const []const u8) !void {
    const result = try std.process.run(options.allocator, options.io, .{ .argv = arguments });
    if (result.term == .exited and result.term.exited == 0) return;
    if (result.stdout.len != 0) std.debug.print("{s}", .{result.stdout});
    if (result.stderr.len != 0) std.debug.print("{s}", .{result.stderr});
    std.debug.print("silex: LLVM {s} stage failed\n", .{name});
    return error.LlvmToolFailed;
}
