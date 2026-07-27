const std = @import("std");

pub const Gate = struct {
    mutex: std.atomic.Mutex = .unlocked,

    pub fn capture(self: *Gate) Guard {
        self.lock();
        return .{ .gate = self };
    }

    pub fn mutation(self: *Gate) Guard {
        self.lock();
        return .{ .gate = self };
    }

    fn lock(self: *Gate) void {
        while (!self.mutex.tryLock()) std.Thread.yield() catch {};
    }
};

pub const Guard = struct {
    gate: *Gate,

    pub fn release(self: Guard) void {
        self.gate.mutex.unlock();
    }
};
