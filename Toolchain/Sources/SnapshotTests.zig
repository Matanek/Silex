const std = @import("std");
const SnapshotGate = @import("Runtime/SnapshotGate.zig");

const Node = struct {
    value: usize,
    next: ?*Node,
};

const Shared = struct {
    gate: SnapshotGate.Gate = .{},
    first: Node,
    second: Node,
    alias: *Node,
    capture_started: std.atomic.Value(bool) = .init(false),
    release_capture: std.atomic.Value(bool) = .init(false),
    mutation_finished: std.atomic.Value(bool) = .init(false),
    drop_count: std.atomic.Value(usize) = .init(0),
    snapshot_values: [2]usize = .{ 0, 0 },
    snapshot_alias: bool = false,
    snapshot_cycle: bool = false,
    drop_during_capture: bool = false,
};

fn capture(shared: *Shared) void {
    const guard = shared.gate.capture();
    defer guard.release();
    shared.capture_started.store(true, .release);
    shared.snapshot_values[0] = shared.first.value;
    while (!shared.release_capture.load(.acquire)) std.Thread.yield() catch {};
    shared.snapshot_values[1] = shared.first.next.?.value;
    shared.snapshot_alias = shared.alias == &shared.first;
    shared.snapshot_cycle = shared.first.next.?.next.? == &shared.first;
    shared.drop_during_capture = shared.drop_count.load(.acquire) != 0;
}

fn mutate(shared: *Shared) void {
    while (!shared.capture_started.load(.acquire)) std.Thread.yield() catch {};
    const guard = shared.gate.mutation();
    shared.first.value = 10;
    shared.second.value = 20;
    shared.first.next = null;
    shared.alias = &shared.second;
    _ = shared.drop_count.fetchAdd(1, .release);
    shared.mutation_finished.store(true, .release);
    guard.release();
}

test "snapshot gate linearizes fields topology aliases cycles lifetime and drop" {
    var shared: Shared = undefined;
    shared = .{
        .first = .{ .value = 1, .next = undefined },
        .second = .{ .value = 2, .next = undefined },
        .alias = undefined,
    };
    shared.first.next = &shared.second;
    shared.second.next = &shared.first;
    shared.alias = &shared.first;

    const capture_thread = try std.Thread.spawn(.{}, capture, .{&shared});
    const mutation_thread = try std.Thread.spawn(.{}, mutate, .{&shared});
    while (!shared.capture_started.load(.acquire)) std.Thread.yield() catch {};
    try std.testing.expect(!shared.mutation_finished.load(.acquire));
    shared.release_capture.store(true, .release);
    capture_thread.join();
    mutation_thread.join();

    try std.testing.expectEqual([2]usize{ 1, 2 }, shared.snapshot_values);
    try std.testing.expect(shared.snapshot_alias);
    try std.testing.expect(shared.snapshot_cycle);
    try std.testing.expect(!shared.drop_during_capture);
    try std.testing.expectEqual(@as(usize, 10), shared.first.value);
    try std.testing.expectEqual(@as(usize, 20), shared.second.value);
    try std.testing.expect(shared.first.next == null);
    try std.testing.expect(shared.alias == &shared.second);
    try std.testing.expectEqual(@as(usize, 1), shared.drop_count.load(.acquire));
}

test "concurrent captures are independently coherent" {
    const State = struct {
        gate: SnapshotGate.Gate = .{},
        pair: [2]usize = .{ 1, 1 },
        stop: std.atomic.Value(bool) = .init(false),
        violations: std.atomic.Value(usize) = .init(0),
    };
    const Worker = struct {
        fn mutate(state: *State) void {
            var next: usize = 2;
            while (!state.stop.load(.acquire)) : (next += 1) {
                const guard = state.gate.mutation();
                state.pair = .{ next, next };
                guard.release();
            }
        }

        fn capture(state: *State) void {
            for (0..2_000) |_| {
                const guard = state.gate.capture();
                const first = state.pair[0];
                std.Thread.yield() catch {};
                const second = state.pair[1];
                guard.release();
                if (first != second) _ = state.violations.fetchAdd(1, .monotonic);
            }
        }
    };
    var state: State = .{};
    const mutation_thread = try std.Thread.spawn(.{}, Worker.mutate, .{&state});
    const first_capture = try std.Thread.spawn(.{}, Worker.capture, .{&state});
    const second_capture = try std.Thread.spawn(.{}, Worker.capture, .{&state});
    first_capture.join();
    second_capture.join();
    state.stop.store(true, .release);
    mutation_thread.join();
    try std.testing.expectEqual(@as(usize, 0), state.violations.load(.acquire));
}
