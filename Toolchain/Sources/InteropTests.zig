const std = @import("std");
const builtin = @import("builtin");

const Ir = @import("Ir.zig");
const Interpreter = @import("Interpreter.zig");
const Lower = @import("Arm64/Lower.zig");
const MachO = @import("MacOS/MachO.zig");
const Project = @import("Project.zig");

const source =
    \\use Interop.C
    \\use Interop.MacOS
    \\
    \\let write = C.function<
    \\    func(int32, C.Pointer<uint8>, C.Size) C.SignedSize
    \\>(
    \\    library:MacOS.lib_system,
    \\    name:"write"
    \\)
    \\
    \\func main() {
    \\    let text = "Silex écrit par interop.\n"
    \\    let written = write(1, C.pointer(text), C.byte_count(text))
    \\    assert(written == C.byte_count(text) as C.SignedSize, "unexpected write count")
    \\}
;

const random_source =
    \\use Interop.C
    \\use Interop.MacOS
    \\
    \\let system_seed = C.function<func() uint32>(
    \\    library:MacOS.lib_system,
    \\    name:"arc4random"
    \\)
    \\
    \\func main() { print(system_seed()) }
;

const linux_random_source =
    \\use Interop.C
    \\use Interop.Linux
    \\
    \\let getrandom = C.function<func(C.MutablePointer<uint32>, C.Size, uint32) C.SignedSize>(
    \\    library:Linux.kernel,
    \\    name:"getrandom"
    \\)
    \\
    \\func main() {
    \\    var seed:uint32 = 0
    \\    let written = getrandom(C.mutable_pointer(seed), 4 as C.Size, 0)
    \\    assert(written == 4 as C.SignedSize, "incomplete seed")
    \\}
;

const windows_random_source =
    \\use Interop.C
    \\use Interop.Windows
    \\
    \\let process_random = C.function<func(C.MutablePointer<uint32>, C.Size) int32>(
    \\    library:Windows.bcrypt_primitives,
    \\    name:"ProcessPrng"
    \\)
    \\
    \\func main() {
    \\    var seed:uint32 = 0
    \\    assert(process_random(C.mutable_pointer(seed), 4 as C.Size) != 0, "seed failed")
    \\}
;

test "compose a C.function declaration into a deterministic boundary call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.boundaries.len);
    try std.testing.expectEqualStrings("Main.write", compilation.boundaries[0].name);
    try std.testing.expectEqualStrings("MacOS.lib_system", compilation.boundaries[0].provider);
    try std.testing.expectEqualStrings("write", compilation.boundaries[0].source_name);
    try std.testing.expect(!Interpreter.supportsBoundary(compilation.boundaries[0]));

    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.call #0") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.address") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "str.byte_count") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "_write") == null);
}

test "compose the typed macOS WebKit Objective-C system surface" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Interop.C
        \\use Interop.MacOS
        \\let get_class = C.function<func(C.Pointer<uint8>) C.Pointer<uint8> >(library:MacOS.web_kit, name:"objc_getClass")
        \\let selector = C.function<func(C.Pointer<uint8>) C.Pointer<uint8> >(library:MacOS.web_kit, name:"sel_registerName")
        \\let message = C.function<func(C.Pointer<uint8>, C.Pointer<uint8>) C.Pointer<uint8> >(library:MacOS.web_kit, name:"objc_msgSend")
        \\let user_script = C.function<func(C.Pointer<uint8>, C.Pointer<uint8>, C.Pointer<uint8>, uint, int32) C.Pointer<uint8> >(library:MacOS.web_kit, name:"objc_msgSend")
        \\func main() {}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    compiler.target = .macos_arm64;
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 4), compilation.boundaries.len);
    for (compilation.boundaries) |boundary| try std.testing.expectEqualStrings("MacOS.web_kit", boundary.provider);
    const machine = try Lower.lowerBoundaries(allocator, compilation.ir, compilation.boundaries);
    try std.testing.expectEqualStrings("MacOS.web_kit", machine.external_functions[3].provider);
}

test "compose and interpret exact float32 and float64 math signatures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Interop.C
        \\use Interop.MacOS
        \\let sqrt32 = C.function<func(float32) float32>(library:MacOS.lib_system, name:"sqrtf")
        \\let sqrt64 = C.function<func(float64) float64>(library:MacOS.lib_system, name:"sqrt")
        \\func main() {
        \\    assert(sqrt32(4.0) == 2.0)
        \\    assert(sqrt64(4.0 as float64) == 2.0 as float64)
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 2), compilation.boundaries.len);
    try std.testing.expectEqual(Ir.Type.float32, compilation.boundaries[0].return_type);
    try std.testing.expectEqual(Ir.Type.float64, compilation.boundaries[1].return_type);
    try std.testing.expect(Interpreter.supportsBoundary(compilation.boundaries[0]));
    try std.testing.expect(Interpreter.supportsBoundary(compilation.boundaries[1]));
    const result = try Interpreter.runCaptureWithBoundaries(
        allocator,
        std.testing.io,
        compilation.ir,
        compilation.boundaries,
    );
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
}

test "compose typed loads and stores from explicit interop address bits" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Interop.C
        \\func main() {
        \\    var storage:uint32 = 0
        \\    let address = C.address_bits(C.mutable_pointer(storage))
        \\    let stored = C.store<uint8>(address, 0 as uint, 83 as uint8)
        \\    assert(C.load<uint8>(address, 0 as uint) == 83 as uint8, "byte load")
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.load") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.store") != null);
}

test "compose float32 loads and stores for private platform layouts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Interop.C
        \\func main() {
        \\    var storage:uint = 0
        \\    let address = C.address_bits(C.mutable_pointer(storage))
        \\    let stored = C.store<float32>(address, 0 as uint, 1.5)
        \\    assert(C.load<float32>(address, 0 as uint) == 1.5 as float32)
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.load") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.store") != null);
    _ = try Lower.lowerBoundaries(allocator, compilation.ir, compilation.boundaries);
}

test "expose stable int32 storage to a foreign mutable pointer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Interop.C
        \\func main() {
        \\    var value:int32 = 0
        \\    let address = C.address_bits(C.mutable_pointer(value))
        \\    C.store<int32>(address, 0 as uint, 42)
        \\    assert(value == 42)
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.store") != null);
}

test "specialize a named generic callback before exposing its address" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Interop.C
        \\struct Marker { let value:int }
        \\func worker<T>(context:uint) uint { return context }
        \\func address<T>() uint { return C.function_address<T>(worker) }
        \\func main() { assert(address<Marker>() != 0, "generic callback address") }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "function @Main.worker<Main.Marker>") != null);
}

test "expose a private mutable string buffer to a direct foreign call" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Interop.C
        \\use Interop.MacOS
        \\let write = C.function<func(int32, C.Pointer<uint8>, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() {
        \\    var buffer = "abc"
        \\    let count = write(1, C.mutable_string_pointer(buffer), 0 as C.Size)
        \\    assert(count == 0, "zero-length mutable buffer write")
        \\}
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.address") != null);
}

test "compose a void foreign call as an instruction without a result value" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{
        .sub_path = "Main.sx",
        .data =
        \\use Interop.C
        \\use Interop.MacOS
        \\let release = C.function<func(C.Pointer<uint8>) void>(library:MacOS.lib_system, name:"freeaddrinfo")
        \\func main() { release(C.pointer_bits(0 as uint)) }
        ,
    });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@import("Types.zig").Type.void, compilation.boundaries[0].return_type);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.call #0") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, ": void = boundary.call") == null);
    _ = try Lower.lowerBoundaries(allocator, compilation.ir, compilation.boundaries);
}

test "emit and execute C.function write from Silex source" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = source });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Main.sx" });
    const output = try std.fs.path.join(allocator, &.{ base, "interop-write" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    const machine = try Lower.lowerBoundaries(allocator, compilation.ir, compilation.boundaries);
    const bytes = try MachO.emit(allocator, machine);
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, output, .{ .permissions = .executable_file });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, bytes);
    try file.setPermissions(std.testing.io, .executable_file);

    const result = try std.process.run(allocator, std.testing.io, .{ .argv = &.{output} });
    try std.testing.expectEqual(@as(u8, 0), switch (result.term) {
        .exited => |code| code,
        else => 255,
    });
    try std.testing.expectEqualStrings("Silex écrit par interop.\n", result.stdout);
    try std.testing.expectEqual(@as(usize, 0), result.stderr.len);
}

test "compose emit and execute a private arc4random seed boundary" {
    if (builtin.os.tag != .macos or builtin.cpu.arch != .aarch64) return error.SkipZigTest;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = random_source });
    const base = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path });
    const input = try std.fs.path.join(allocator, &.{ base, "Main.sx" });
    const output = try std.fs.path.join(allocator, &.{ base, "interop-random" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expectEqual(@as(usize, 1), compilation.boundaries.len);
    try std.testing.expectEqualStrings("arc4random", compilation.boundaries[0].source_name);
    try std.testing.expectEqual(@import("Types.zig").Type.uint32, compilation.boundaries[0].return_type);
    const machine = try Lower.lowerBoundaries(allocator, compilation.ir, compilation.boundaries);
    const bytes = try MachO.emit(allocator, machine);
    const file = try std.Io.Dir.cwd().createFile(std.testing.io, output, .{ .permissions = .executable_file });
    defer file.close(std.testing.io);
    try file.writeStreamingAll(std.testing.io, bytes);
    try file.setPermissions(std.testing.io, .executable_file);

    const result = try std.process.run(allocator, std.testing.io, .{ .argv = &.{output} });
    try std.testing.expectEqual(@as(u8, 0), switch (result.term) {
        .exited => |code| code,
        else => 255,
    });
    const text = std.mem.trim(u8, result.stdout, "\n");
    const value = try std.fmt.parseInt(u64, text, 10);
    try std.testing.expect(value <= std.math.maxInt(u32));
    try std.testing.expectEqual(@as(usize, 0), result.stderr.len);
}

test "interpret an arc4random seed boundary" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = random_source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    const compilation = try compiler.compile(input);
    try std.testing.expect(Interpreter.supportsBoundary(compilation.boundaries[0]));
    const result = try Interpreter.runCaptureWithBoundaries(
        allocator,
        std.testing.io,
        compilation.ir,
        compilation.boundaries,
    );
    const text = std.mem.trim(u8, result.stdout, "\n");
    const value = try std.fmt.parseInt(u64, text, 10);
    try std.testing.expect(value <= std.math.maxInt(u32));
    try std.testing.expectEqual(@as(u8, 0), result.exit_code);
    try std.testing.expectEqual(@as(usize, 0), result.stderr.len);
}

test "compose Linux getrandom with a private mutable uint32 buffer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = linux_random_source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    compiler.target = .linux_x64;
    const compilation = try compiler.compile(input);
    try std.testing.expectEqualStrings("Linux.kernel", compilation.boundaries[0].provider);
    try std.testing.expectEqualStrings("getrandom", compilation.boundaries[0].source_name);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "address $") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.call #0") != null);
}

test "compose Windows ProcessPrng with a private mutable uint32 buffer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = windows_random_source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    compiler.target = .windows_x64;
    const compilation = try compiler.compile(input);
    try std.testing.expectEqualStrings("Windows.bcrypt_primitives", compilation.boundaries[0].provider);
    try std.testing.expectEqualStrings("ProcessPrng", compilation.boundaries[0].source_name);
    const text = try Ir.writeText(allocator, compilation.ir);
    try std.testing.expect(std.mem.indexOf(u8, text, "address $") != null);
    try std.testing.expect(std.mem.indexOf(u8, text, "boundary.call #0") != null);
}

test "lower Windows ProcessPrng through the shared ARM64 machine contract" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = windows_random_source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });

    var compiler = Project.Compiler.init(allocator, std.testing.io);
    compiler.target = .windows_arm64;
    const compilation = try compiler.compile(input);
    const machine = try Lower.lowerBoundaries(allocator, compilation.ir, compilation.boundaries);
    try std.testing.expectEqualStrings("Windows.bcrypt_primitives", machine.external_functions[0].provider);
    try std.testing.expectEqualStrings("ProcessPrng", machine.external_functions[0].source_name);
}

test "reject incomplete and invalid C.function declarations" {
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let message = C.function<func(int32) int32>(library:MacOS.web_kit, name:"objc_msgSend")
        \\func main() {}
    ,
        "interop library or function is not supported yet",
    );
    try expectError(
        \\use Interop.C
        \\let native = C.function<func() int32>(library:Boundary.Native, name:"answer")
        \\func main() {}
    ,
        "Boundary library requires 'use Interop.Boundary'",
    );
    try expectError(
        \\use Interop.C
        \\let write = C.function<func(int32, C.Pointer<uint8>, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() {}
    ,
        "MacOS library requires 'use Interop.MacOS'",
    );
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let write = C.function<func(int32, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() {}
    ,
        "write expects func(int32, C.Pointer<uint8>, C.Size) C.SignedSize",
    );
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let seed = C.function<func() int32>(library:MacOS.lib_system, name:"arc4random")
        \\func main() {}
    ,
        "arc4random expects func() uint32",
    );
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let write = C.function<func(int32, C.Pointer<uint8>, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() { write(1, C.pointer(42), 1 as C.Size) }
    ,
        "C.pointer expects a string",
    );
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let write = C.function<func(int32, C.Pointer<uint8>, C.Size) C.SignedSize>(library:MacOS.lib_system, name:"write")
        \\func main() { let text = "x"; let pointer = C.pointer(text); write(1, pointer, 1 as C.Size) }
    ,
        "a C pointer can only be passed directly to a foreign function",
    );
}

test "worker-safe job analysis rejects an unclassified external boundary" {
    try expectError(
        \\use Interop.C
        \\use Interop.MacOS
        \\let process_id = C.function<func() int32>(library:MacOS.lib_system, name:"getpid")
        \\protocol Job { func execute() }
        \\class Executor { func submit<T:Job>(job:T) {} }
        \\struct ExternalJob:Job { func execute() { process_id() } }
        \\func main() { var executor = Executor(); executor.submit(ExternalJob()) }
    ,
        "job 'ExternalJob' is not worker-safe: external call 'getpid' is not classified",
    );
}

fn expectError(input_source: []const u8, message: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try temporary.dir.writeFile(std.testing.io, .{ .sub_path = "Main.sx", .data = input_source });
    const input = try std.fs.path.join(allocator, &.{ ".zig-cache", "tmp", &temporary.sub_path, "Main.sx" });
    var compiler = Project.Compiler.init(allocator, std.testing.io);
    try std.testing.expectError(error.InvalidSource, compiler.compile(input));
    try std.testing.expectEqualStrings(message, compiler.diagnostic.?.message);
}
