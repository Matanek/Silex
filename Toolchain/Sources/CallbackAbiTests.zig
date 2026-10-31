const std = @import("std");
const builtin = @import("builtin");
const Project = @import("Project.zig");
const Ir = @import("Ir.zig");
const Source = @import("Source.zig");
const ProgramScope = @import("ProgramScope.zig");
const Lower = @import("Arm64/Lower.zig");
const Machine = @import("Arm64/Machine.zig");
const Arm = @import("Arm64/Encoder.zig");
const X64 = @import("X64/Encoder.zig");
const Platform = @import("Arm64/System.zig").Platform;
const windows_cc: std.builtin.CallingConvention = switch (builtin.cpu.arch) {
    // The tested ARM64 signatures fit x0-x7 / v0-v7, where these
    // non-variadic ABIs coincide. This executes emitter code, not Windows OS.
    .aarch64 => .c,
    .x86_64 => .{ .x86_64_win = .{} },
    else => .c,
};
const oracle_platforms = .{ Platform.darwin, Platform.linux, Platform.windows };
extern "c" fn silex_oracle_spilled_tail(callback: usize, windows: c_int) u64;
extern "c" fn silex_oracle_spilled_value(callback: usize, windows: c_int) f64;
extern "c" fn sys_icache_invalidate(start: *anyopaque, length: usize) void;

fn compileSource(allocator: std.mem.Allocator, source: []const u8) !Ir.Program {
    return compileObserved(allocator, source, null);
}
fn compileObserved(allocator: std.mem.Allocator, source: []const u8, diagnostic: ?*?Source.Diagnostic) !Ir.Program {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = compiler.compile(input) catch |err| {
        if (diagnostic) |destination| destination.* = compiler.diagnostic else if (compiler.diagnostic) |detail| std.debug.print("{d}:{d}: {s}\n", .{ detail.position.line, detail.position.column, detail.message });
        return err;
    };
    return compilation.ir;
}

const Mapping = struct {
    memory: []align(std.heap.page_size_min) u8,
    callback: usize,
    fn init(allocator: std.mem.Allocator, source: []const u8, mode: Lower.Mode, platform: Platform) !Mapping {
        if (builtin.os.tag != .macos or (builtin.cpu.arch != .aarch64 and builtin.cpu.arch != .x86_64)) return error.SkipZigTest;
        const ir = try compileSource(allocator, source);
        const original_expose = for (ir.functions, 0..) |function, index| {
            if (std.mem.eql(u8, function.name, "Main.expose")) break index;
        } else return error.InvalidMachineProgram;
        // The CLI closes the reachable graph before lowering. Its rewrites
        // must preserve the distinct native callback entry, too.
        const closed = try ProgramScope.close(allocator, ir, &.{original_expose});
        // Mirror the CLI: X64 starts from the stack-compatible form and
        // applies its own allocation, never the ARM64 register colors.
        var program = try Lower.lowerWithMode(allocator, closed.program, if (builtin.cpu.arch == .x86_64) .debug else mode);
        if (builtin.cpu.arch == .x86_64 and mode == .release) program = try @import("X64/RegisterAllocation.zig").allocateProgram(allocator, program);
        const expose = closed.function(original_expose).?;
        const image = if (builtin.cpu.arch == .aarch64) switch (platform) {
            .darwin => try Arm.encode(allocator, program, .{ .test_function = expose }),
            .windows => try Arm.encodeWindows(allocator, program, .{ .test_function = expose }),
            .linux => try Arm.encodeLinux(allocator, program, .{ .test_function = expose }),
        } else switch (platform) {
            .darwin => try X64.encodeDarwinFunctionObject(allocator, program, expose),
            .windows => try X64.encodeWindowsFunctionObject(allocator, program, expose),
            .linux => try X64.encodeLinuxFunctionObject(allocator, program, expose),
        };
        defer image.deinit(allocator);
        if (image.external_call_sites.len != 0) std.debug.print("unexpected imports: {s}/{s}: {any}\n", .{ @tagName(platform), @tagName(mode), image.external_call_sites });
        try std.testing.expectEqual(@as(usize, 0), image.external_call_sites.len);
        try std.testing.expectEqual(@as(usize, 1), image.callback_entries.len);
        const mapped_size = std.mem.alignForward(usize, image.code.len, std.heap.page_size_min);
        const memory = try std.posix.mmap(null, mapped_size, .{ .READ = true, .WRITE = true }, .{ .TYPE = .PRIVATE, .ANONYMOUS = true }, -1, 0);
        errdefer std.posix.munmap(memory);
        @memcpy(memory[0..image.code.len], image.code);
        try std.process.protectMemory(memory, .{ .read = true, .execute = true });
        if (builtin.cpu.arch == .aarch64) sys_icache_invalidate(memory.ptr, image.code.len);
        return .{ .memory = memory, .callback = @intFromPtr(memory.ptr) + image.callback_entries[0].offset };
    }
    fn deinit(self: Mapping) void {
        std.posix.munmap(self.memory);
    }
};

test "C callback ABI floating entry and return agree with independent native callers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (oracle_platforms) |platform| {
        inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
            const mapping = try Mapping.init(arena.allocator(),
                \\use Interop.C
                \\func worker(value:float64) float64 { return value+value }
                \\func expose() uint { return C.function_address(worker) }
                \\func main() {}
            , mode, platform);
            defer mapping.deinit();
            errdefer std.debug.print("oracle failed: {s}/{s}\n", .{ @tagName(platform), @tagName(mode) });
            const cc = if (platform == .windows) windows_cc else std.builtin.CallingConvention.c;
            const callback: *const fn (f64) callconv(cc) f64 = @ptrFromInt(mapping.callback);
            try std.testing.expectEqual(@as(f64, 2.5), callback(1.25));
            try std.testing.expectEqual(@as(f64, -7.0), callback(-3.5));
        }
    }
}

test "C callback ABI mixed registers and internal stack arguments agree with independent native callers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (oracle_platforms) |platform| {
        inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
            const mapping = try Mapping.init(arena.allocator(),
                \\use Interop.C
                \\func worker(a:uint,b:float64,c:uint,d:float32,e:uint,f:uint,g:uint,h:uint,i:uint,j:uint) uint {
                \\    if b != 1.25 || d != 0.5 { return 0 }
                \\    return a+c+e+f+g+h+i+j
                \\}
                \\func expose() uint { return C.function_address(worker) }
                \\func main() {}
            , mode, platform);
            defer mapping.deinit();
            errdefer std.debug.print("oracle failed: {s}/{s}\n", .{ @tagName(platform), @tagName(mode) });
            const cc = if (platform == .windows) windows_cc else std.builtin.CallingConvention.c;
            const callback: *const fn (u64, f64, u64, f32, u64, u64, u64, u64, u64, u64) callconv(cc) u64 = @ptrFromInt(mapping.callback);
            try std.testing.expectEqual(@as(u64, 49), callback(1, 1.25, 3, 0.5, 5, 6, 7, 8, 9, 10));
        }
    }
}

test "C callback ABI accepts static generic aliases and rejects lost environments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ir = try compileSource(arena.allocator(),
        \\use Interop.C
        \\func worker<T>(value:float64) float64 { return value+value }
        \\func plain(value:float32) float32 { return value+value }
        \\func main() {
        \\    let alias=plain
        \\    let first=C.function_address(alias)
        \\    let second=C.function_address<int>(worker)
        \\}
    );
    const text = try Ir.writeText(arena.allocator(), ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "c_function @Main.plain") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "c_function @Main.worker<int>") != null);
    for ([_]struct { source: []const u8, message: []const u8 }{
        .{ .source = "use Interop.C\nfunc main() { let captured=2; let callback:func(int) int=func(value:int) int { return value+captured }; let entry=C.function_address(callback) }", .message = "statically resolved function without captures" },
        .{ .source = "use Interop.C\nfunc worker(value:float64) float64 { return value }\nfunc main() { var callback=worker; let entry=C.function_address(callback) }", .message = "statically resolved function without captures" },
        .{ .source = "use Interop.C\nfunc worker(value:str) int { return 0 }\nfunc main() { let entry=C.function_address(worker) }", .message = "requires C scalar or flat 64-bit numeric record parameters" },
        .{ .source = "use Interop.C\nfunc expose(callback:func(float64) float64) uint { return C.function_address(callback) }\nfunc main() {}", .message = "statically resolved function without captures" },
        .{ .source = "use Interop.C\nstruct Record { let value:float32 }\nfunc worker(value:Record) uint { return 0 }\nfunc main() { let entry=C.function_address(worker) }", .message = "requires C scalar or flat 64-bit numeric record parameters" },
        .{ .source = "use Interop.C\nstruct Record { let value:uint }\nfunc worker() Record { return Record(value:0) }\nfunc main() { let entry=C.function_address(worker) }", .message = "requires a C scalar or void result" },
    }) |case| {
        var diagnostic: ?Source.Diagnostic = null;
        try std.testing.expectError(error.InvalidSource, compileObserved(arena.allocator(), case.source, &diagnostic));
        try std.testing.expect(diagnostic != null);
        try std.testing.expect(std.mem.indexOf(u8, diagnostic.?.message, case.message) != null);
    }
}

const Point = extern struct { x: f64, y: f64 };
const VariantWords = extern struct { tag: u64, value: u64, extra: u64 };

test "C callback ABI records match independent native HFA and large composite callers" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (oracle_platforms) |platform| {
        inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
            errdefer std.debug.print("oracle failed: {s}/{s}\n", .{ @tagName(platform), @tagName(mode) });
            const cc = if (platform == .windows) windows_cc else std.builtin.CallingConvention.c;
            const point = try Mapping.init(arena.allocator(),
                \\use Interop.C
                \\struct Point { let x:float64; let y:float64 }
                \\func worker(context:uint,point:Point,tail:uint) float64 { if context != 3 || tail != 7 { return 0.0 } return point.x+point.y }
                \\func expose() uint { return C.function_address(worker) }
                \\func main() {}
            , mode, platform);
            defer point.deinit();
            const call_point: *const fn (u64, Point, u64) callconv(cc) f64 = @ptrFromInt(point.callback);
            try std.testing.expectEqual(@as(f64, 1.75), call_point(3, .{ .x = 1.25, .y = 0.5 }, 7));
            const variant = try Mapping.init(arena.allocator(),
                \\use Interop.C
                \\struct Variant { let tag:uint; let value:uint; let extra:uint }
                \\func worker(context:uint,attribute:int32,value:Variant,backward:int32,tail:uint) uint { if attribute != -3 || backward != 1 { return 0 } return context+value.tag+value.value+value.extra+tail }
                \\func expose() uint { return C.function_address(worker) }
                \\func main() {}
            , mode, platform);
            defer variant.deinit();
            const call_variant: *const fn (u64, i32, VariantWords, i32, u64) callconv(cc) u64 = @ptrFromInt(variant.callback);
            try std.testing.expectEqual(@as(u64, 33), call_variant(2, -3, .{ .tag = 5, .value = 7, .extra = 11 }, 1, 8));
        }
    }
}

test "C callback ABI uint16 parameters preserve native packed Darwin stack" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
        const mapping = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\func worker(a:uint16,b:uint16,c:uint16,d:uint16,e:uint16,f:uint16,g:uint16,h:uint16,i:uint16,j:uint16) uint16 { return a+b+c+d+e+f+g+h+i+j }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, .darwin);
        defer mapping.deinit();
        const callback: *const fn (u16, u16, u16, u16, u16, u16, u16, u16, u16, u16) callconv(.c) u16 = @ptrFromInt(mapping.callback);
        try std.testing.expectEqual(@as(u16, 55), callback(1, 2, 3, 4, 5, 6, 7, 8, 9, 10));
    }
}

test "C callback ABI plans separate Windows point HFA and indirect records" {
    const CAbi = @import("Arm64/CAbi.zig");
    const point = [_]Machine.AbiValue{ .float64, .float64 };
    const variant = [_]Machine.AbiValue{ .uint64, .uint64, .uint64 };
    const signature = Machine.ExternalFunction.Signature{ .arguments = &.{ .uint64, .record, .record, .uint16 }, .record_fields = &.{ &.{}, &point, &variant, &.{} }, .result = .int32 };
    inline for (.{ CAbi.Architecture.arm64, CAbi.Architecture.x64 }) |architecture| {
        const native = try CAbi.plan(std.testing.allocator, architecture, Platform.windows, signature);
        defer native.deinit(std.testing.allocator);
        if (architecture == .arm64) {
            try std.testing.expect(!native.arguments[1].indirect);
            try std.testing.expectEqual(CAbi.Location{ .floating = 0 }, native.arguments[1].locations[0]);
            try std.testing.expectEqual(CAbi.Location{ .floating = 1 }, native.arguments[1].locations[1]);
        } else {
            try std.testing.expect(native.arguments[1].indirect);
            try std.testing.expectEqual(CAbi.Location{ .general = 1 }, native.arguments[1].locations[0]);
        }
        try std.testing.expect(native.arguments[2].indirect);
        try std.testing.expectEqual(CAbi.Location{ .general = if (architecture == .arm64) 1 else 2 }, native.arguments[2].locations[0]);
    }
    const unix = try CAbi.plan(std.testing.allocator, .x64, Platform.linux, signature);
    defer unix.deinit(std.testing.allocator);
    try std.testing.expect(!unix.arguments[2].indirect);
    try std.testing.expectEqual(CAbi.Location{ .stack = 0 }, unix.arguments[2].locations[0]);
    try std.testing.expectEqual(@as(usize, 24), @sizeOf(VariantWords));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Point));
}

test "C callback ABI indirect record calls agree with independent native callees" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (oracle_platforms) |platform| {
        inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
            errdefer std.debug.print("oracle failed: {s}/{s}\n", .{ @tagName(platform), @tagName(mode) });
            const cc = if (platform == .windows) windows_cc else std.builtin.CallingConvention.c;
            const Oracle = struct {
                fn point(context: u64, value: Point, tail: u64) callconv(cc) f64 {
                    if (context != 3 or tail != 7) return 0;
                    return value.x + value.y;
                }
                fn variant(context: u64, attribute: i32, value: VariantWords, backward: i32, tail: u64) callconv(cc) u64 {
                    if (attribute != -3 or backward != 1) return 0;
                    return context + value.tag + value.value + value.extra + tail;
                }
            };
            const point = try Mapping.init(arena.allocator(),
                \\use Interop.C
                \\struct Point { let x:float64; let y:float64 }
                \\func worker(address:uint,context:uint,point:Point,tail:uint) float64 { return C.call<func(uint,Point,uint) float64>(address,context,point,tail) }
                \\func expose() uint { return C.function_address(worker) }
                \\func main() {}
            , mode, platform);
            defer point.deinit();
            const call_point: *const fn (usize, u64, Point, u64) callconv(cc) f64 = @ptrFromInt(point.callback);
            try std.testing.expectEqual(@as(f64, 1.75), call_point(@intFromPtr(&Oracle.point), 3, .{ .x = 1.25, .y = 0.5 }, 7));
            const variant = try Mapping.init(arena.allocator(),
                \\use Interop.C
                \\struct Variant { let tag:uint; let value:uint; let extra:uint }
                \\func worker(address:uint,context:uint,attribute:int32,value:Variant,backward:int32,tail:uint) uint { return C.call<func(uint,int32,Variant,int32,uint) uint>(address,context,attribute,value,backward,tail) }
                \\func expose() uint { return C.function_address(worker) }
                \\func main() {}
            , mode, platform);
            defer variant.deinit();
            const call_variant: *const fn (usize, u64, i32, VariantWords, i32, u64) callconv(cc) u64 = @ptrFromInt(variant.callback);
            try std.testing.expectEqual(@as(u64, 33), call_variant(@intFromPtr(&Oracle.variant), 2, -3, .{ .tag = 5, .value = 7, .extra = 11 }, 1, 8));
        }
    }
}

const Mixed = extern struct { tag: u64, value: f64 };
const Hfa3 = extern struct { x: f64, y: f64, z: f64 };
const Hfa4 = extern struct { x: f64, y: f64, z: f64, w: f64 };
const IntegerRecord = extern struct { value: u64 };

test "C callback ABI classifies one-field mixed and homogeneous records" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (oracle_platforms) |platform| inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
        const cc = if (platform == .windows) windows_cc else std.builtin.CallingConvention.c;
        errdefer std.debug.print("record shapes: {s}/{s}\n", .{ @tagName(platform), @tagName(mode) });
        const single = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\struct Record { let value:uint }
            \\func worker(value:Record) uint { return value.value }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, platform);
        defer single.deinit();
        const call_single: *const fn (IntegerRecord) callconv(cc) u64 = @ptrFromInt(single.callback);
        try std.testing.expectEqual(@as(u64, 0xf1234567), call_single(.{ .value = 0xf1234567 }));
        const mixed = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\struct Record { let tag:uint; let value:float64 }
            \\func worker(context:uint,value:Record,tail:uint) float64 { if context != 3 || value.tag != 42 || tail != 7 { return 0.0 } return value.value }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, platform);
        defer mixed.deinit();
        const call_mixed: *const fn (u64, Mixed, u64) callconv(cc) f64 = @ptrFromInt(mixed.callback);
        try std.testing.expectEqual(@as(f64, 3.5), call_mixed(3, .{ .tag = 42, .value = 3.5 }, 7));
        const hfa3 = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\struct Record { let x:float64; let y:float64; let z:float64 }
            \\func worker(value:Record) float64 { return value.x+value.y+value.z }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, platform);
        defer hfa3.deinit();
        const call_hfa3: *const fn (Hfa3) callconv(cc) f64 = @ptrFromInt(hfa3.callback);
        try std.testing.expectEqual(@as(f64, 7), call_hfa3(.{ .x = 1, .y = 2, .z = 4 }));
        const hfa4 = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\struct Record { let x:float64; let y:float64; let z:float64; let w:float64 }
            \\func worker(value:Record) float64 { return value.x+value.y+value.z+value.w }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, platform);
        defer hfa4.deinit();
        const call_hfa4: *const fn (Hfa4) callconv(cc) f64 = @ptrFromInt(hfa4.callback);
        try std.testing.expectEqual(@as(f64, 15), call_hfa4(.{ .x = 1, .y = 2, .z = 4, .w = 8 }));
    };
}

test "C callback ABI keeps records whole when native register banks saturate" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (oracle_platforms) |platform| inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
        const cc = if (platform == .windows) windows_cc else std.builtin.CallingConvention.c;
        errdefer std.debug.print("record register exhaustion: {s}/{s}\n", .{ @tagName(platform), @tagName(mode) });
        const floating = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\struct Point { let x:float64; let y:float64 }
            \\func worker(a:float64,b:float64,c:float64,d:float64,e:float64,f:float64,g:float64,point:Point,tail:float64) float64 { return a+b+c+d+e+f+g+point.x+point.y+tail }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, platform);
        defer floating.deinit();
        const call_floating: *const fn (f64, f64, f64, f64, f64, f64, f64, Point, f64) callconv(cc) f64 = @ptrFromInt(floating.callback);
        try std.testing.expectEqual(@as(f64, 1023), call_floating(1, 2, 4, 8, 16, 32, 64, .{ .x = 128, .y = 256 }, 512));
        const tail = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\struct Record { let tag:uint; let value:float64 }
            \\func worker(a:uint,b:uint,c:uint,d:uint,e:uint,f:uint,g:uint,value:Record,tail:uint) uint { return tail }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, platform);
        defer tail.deinit();
        const windows: c_int = @intFromBool(builtin.cpu.arch == .x86_64 and platform == .windows);
        try std.testing.expectEqual(@as(u64, 99), silex_oracle_spilled_tail(tail.callback, windows));
        const general = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\struct Record { let tag:uint; let value:float64 }
            \\func worker(a:uint,b:uint,c:uint,d:uint,e:uint,f:uint,g:uint,value:Record,tail:uint) float64 { if a != 1 { return -1.0 } if b != 2 { return -2.0 } if c != 3 { return -3.0 } if d != 4 { return -4.0 } if e != 5 { return -5.0 } if f != 6 { return -6.0 } if g != 7 { return -7.0 } if value.tag != 42 { return -8.0 } if tail != 99 { return -9.0 } return value.value }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, platform);
        defer general.deinit();
        try std.testing.expectEqual(@as(f64, 3.5), silex_oracle_spilled_value(general.callback, windows));
    };
}

test "C callback ABI preserves caller floating values across a native callback" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (oracle_platforms) |platform| inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
        const cc = if (platform == .windows) windows_cc else std.builtin.CallingConvention.c;
        const Oracle = struct {
            fn invoke(callback: *const fn (f64, usize) callconv(cc) f64, values: *[12]f64) f64 {
                const a = values[0];
                const b = values[1];
                const c = values[2];
                const d = values[3];
                const e = values[4];
                const f = values[5];
                const g = values[6];
                const h = values[7];
                const i = values[8];
                const j = values[9];
                const k = values[10];
                const l = values[11];
                // The opaque callee receives the storage address, so a native caller
                // must preserve the values loaded before that call.
                const r = callback(0.125, @intFromPtr(values));
                return (((((((((((r + a) * b + r) * c + r) * d + r) * e + r) * f + r) * g + r) * h + r) * i + r) * j + r) * k + r) * l + r;
            }
        };
        const mapping = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\func worker(value:float64,context:uint) float64 { return value+value }
            \\func expose() uint { return C.function_address(worker) }
            \\func main() {}
        , mode, platform);
        defer mapping.deinit();
        const callback: *const fn (f64, usize) callconv(cc) f64 = @ptrFromInt(mapping.callback);
        var values = [_]f64{ 1.25, 2, 0.5, 4, 0.75, 1.5, 3, 2.5, 1.125, 4, 0.5, 2 };
        var expected: f64 = 0.25 + values[0];
        for (values[1..]) |value| expected = expected * value + 0.25;
        try std.testing.expectEqual(expected, @call(.never_inline, Oracle.invoke, .{ callback, &values }));
    };
}

test "C callback ABI marks static anonymous references without environments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const ir = try compileSource(arena.allocator(),
        \\use Interop.C
        \\func expose() uint {
        \\    let callback:func(float64) float64=func(value:float64) float64 { return value+value }
        \\    return C.function_address(callback)
        \\}
        \\func main() {}
    );
    const text = try Ir.writeText(arena.allocator(), ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "c_function @") != null);
    // The local function value also allocates its ordinary Silex closure.
    // Its complete linked execution belongs to Tests/Native/CallbackScalarABI;
    // the raw mmap oracle deliberately has no heap/import linker.
}

test "C callback ABI infers static member entries without an environment" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (oracle_platforms) |platform| inline for (.{ Lower.Mode.debug, Lower.Mode.release }) |mode| {
        const mapping = try Mapping.init(arena.allocator(),
            \\use Interop.C
            \\struct Worker { static func twice(value:float64) float64 { return value+value } }
            \\func expose() uint { return C.function_address(Worker.twice) }
            \\func main() {}
        , mode, platform);
        defer mapping.deinit();
        const cc = if (platform == .windows) windows_cc else std.builtin.CallingConvention.c;
        const callback: *const fn (f64) callconv(cc) f64 = @ptrFromInt(mapping.callback);
        try std.testing.expectEqual(@as(f64, 2.5), callback(1.25));
    };
}
