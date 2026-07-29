const std = @import("std");
const Ast = @import("../Ast.zig");
const Boundary = @import("../Boundary.zig");
const Ir = @import("../Ir.zig");
const Model = @import("Model.zig");
const Types = @import("../Types.zig");
const Collections = @import("Collections.zig");
const Support = @import("Support.zig");

pub fn prepare(self: anytype) ![]const Boundary.Function {
    var result: std.ArrayList(Boundary.Function) = .empty;
    for (self.program.external_functions, 0..) |external, index| {
        for (self.program.external_functions[0..index]) |previous| {
            if (std.mem.eql(u8, external.name, previous.name)) {
                return self.fail(external.name_position, "foreign function binding is already declared");
            }
        }
        for (self.program.functions) |function| {
            if (std.mem.eql(u8, external.name, function.name)) {
                return self.fail(external.name_position, "foreign function binding collides with a function declaration");
            }
        }
        if (self.target) |target| {
            const expected = target.platform.directoryName();
            const separator = std.mem.indexOfScalar(u8, external.library, '.') orelse return self.fail(
                external.position,
                "interop provider must name its platform",
            );
            if (!std.mem.eql(u8, external.library[0..separator], expected)) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "interop provider '{s}' is unavailable for target '{s}'",
                    .{ external.library, target.name() },
                );
                return self.fail(external.position, message);
            }
        }
        const parameters = try self.allocator.alloc(Types.Type, external.parameters.len);
        for (external.parameters, 0..) |parameter, parameter_index| {
            parameters[parameter_index] = try externalType(self, parameter, external.position);
        }
        const return_type = try externalType(self, external.return_type, external.position);
        if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "write")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .uint or return_type != .int)
            {
                return self.fail(external.position, "write expects func(int32, C.Pointer<uint8>, C.Size) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "arc4random")) {
            if (parameters.len != 0 or return_type != .uint32) {
                return self.fail(external.position, "arc4random expects func() uint32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "clock_gettime_nsec_np")) {
            if (parameters.len != 1 or parameters[0] != .uint32 or return_type != .uint) {
                return self.fail(external.position, "clock_gettime_nsec_np expects func(uint32) uint");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "read")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .uint or return_type != .int)
            {
                return self.fail(external.position, "read expects func(int32, C.MutablePointer<uint32>, C.Size) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "isatty")) {
            if (parameters.len != 1 or parameters[0] != .int32 or return_type != .int32) {
                return self.fail(external.position, "isatty expects func(int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "__ioctl")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .uint or
                parameters[2] != .address or return_type != .int32)
            {
                return self.fail(external.position, "__ioctl expects func(int32, uint, C.MutablePointer<T>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "__open")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .int32 or
                parameters[2] != .uint32 or return_type != .int32)
            {
                return self.fail(external.position, "__open expects func(C.Pointer<uint8>, int32, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "close") or std.mem.eql(u8, external.source_name, "fsync")))
        {
            if (parameters.len != 1 or parameters[0] != .int32 or return_type != .int32) {
                return self.fail(external.position, "close and fsync expect func(int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "lseek")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .int or
                parameters[2] != .int32 or return_type != .int)
            {
                return self.fail(external.position, "lseek expects func(int32, int, int32) int");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "ftruncate")) {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int or return_type != .int32) {
                return self.fail(external.position, "ftruncate expects func(int32, int) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "poll")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .uint or
                parameters[2] != .int32 or return_type != .int32)
            {
                return self.fail(external.position, "poll expects func(C.MutablePointer<uint>, C.Size, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "getenv")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .address) {
                return self.fail(external.position, "getenv expects func(C.Pointer<uint8>) C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "setenv")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .address or
                parameters[2] != .int32 or return_type != .int32)
            {
                return self.fail(external.position, "setenv expects func(C.Pointer<uint8>, C.Pointer<uint8>, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "unsetenv")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "unsetenv expects func(C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "_NSGetEnviron")) {
            if (parameters.len != 0 or return_type != .address) {
                return self.fail(external.position, "_NSGetEnviron expects func() C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "_NSGetArgc") or std.mem.eql(u8, external.source_name, "_NSGetArgv")))
        {
            if (parameters.len != 0 or return_type != .address) {
                return self.fail(external.position, "process argument accessors expect func() C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "getcwd")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .uint or return_type != .address) {
                return self.fail(external.position, "getcwd expects func(C.MutablePointer<int>, C.Size) C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "chdir")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "chdir expects func(C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "_NSGetExecutablePath")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "_NSGetExecutablePath expects func(C.MutablePointer<int>, C.MutablePointer<uint32>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "getpid")) {
            if (parameters.len != 0 or return_type != .int32) return self.fail(external.position, "getpid expects func() int32");
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "stat") or std.mem.eql(u8, external.source_name, "lstat")))
        {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "stat and lstat expect func(C.Pointer<uint8>, C.MutablePointer<int>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "opendir")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .address) {
                return self.fail(external.position, "opendir expects func(C.Pointer<uint8>) C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "readdir")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .address) {
                return self.fail(external.position, "readdir expects func(C.Pointer<uint8>) C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "closedir") or std.mem.eql(u8, external.source_name, "unlink") or
                std.mem.eql(u8, external.source_name, "rmdir")))
        {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "closedir, unlink, and rmdir expect func(C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "mkdir") or std.mem.eql(u8, external.source_name, "chmod")))
        {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .uint32 or return_type != .int32) {
                return self.fail(external.position, "mkdir and chmod expect func(C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "rename")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "rename expects func(C.Pointer<uint8>, C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "realpath")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .address or return_type != .address) {
                return self.fail(external.position, "realpath expects func(C.Pointer<uint8>, C.MutablePointer<int>) C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "copyfile")) {
            if (parameters.len != 4 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .address or
                parameters[3] != .uint32 or return_type != .int32)
            {
                return self.fail(external.position, "copyfile expects func(C.Pointer<uint8>, C.Pointer<uint8>, C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "getaddrinfo")) {
            if (parameters.len != 4 or parameters[0] != .address or parameters[1] != .address or
                parameters[2] != .address or parameters[3] != .address or return_type != .int32)
            {
                return self.fail(external.position, "getaddrinfo expects func(C.Pointer<uint8>, C.Pointer<uint8>, C.Pointer<uint8>, C.MutablePointer<uint>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "freeaddrinfo")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .void) {
                return self.fail(external.position, "freeaddrinfo expects func(C.Pointer<uint8>) void");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "__error")) {
            if (parameters.len != 0 or return_type != .address) {
                return self.fail(external.position, "__error expects func() C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "socket")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .int32 or parameters[2] != .int32 or return_type != .int32) {
                return self.fail(external.position, "socket expects func(int32, int32, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "connect") or std.mem.eql(u8, external.source_name, "bind")))
        {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .uint32 or return_type != .int32) {
                return self.fail(external.position, "connect and bind expect func(int32, C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "listen") or std.mem.eql(u8, external.source_name, "shutdown")))
        {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int32 or return_type != .int32) {
                return self.fail(external.position, "listen and shutdown expect func(int32, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "accept") or std.mem.eql(u8, external.source_name, "getsockname") or
                std.mem.eql(u8, external.source_name, "getpeername")))
        {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .address or return_type != .int32) {
                return self.fail(external.position, "socket address queries expect func(int32, C.MutablePointer<int>, C.MutablePointer<uint32>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and
            (std.mem.eql(u8, external.source_name, "recv") or std.mem.eql(u8, external.source_name, "send")))
        {
            if (parameters.len != 4 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .uint or parameters[3] != .int32 or return_type != .int) {
                return self.fail(external.position, "recv and send expect func(int32, C.Pointer<uint8>, C.Size, int32) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "setsockopt")) {
            if (parameters.len != 5 or parameters[0] != .int32 or parameters[1] != .int32 or parameters[2] != .int32 or
                parameters[3] != .address or parameters[4] != .uint32 or return_type != .int32)
            {
                return self.fail(external.position, "setsockopt expects func(int32, int32, int32, C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "sendto")) {
            if (parameters.len != 6 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .uint or
                parameters[3] != .int32 or parameters[4] != .address or parameters[5] != .uint32 or return_type != .int)
            {
                return self.fail(external.position, "sendto expects func(int32, C.Pointer<uint8>, C.Size, int32, C.Pointer<uint8>, uint32) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "recvfrom")) {
            if (parameters.len != 6 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .uint or
                parameters[3] != .int32 or parameters[4] != .address or parameters[5] != .address or return_type != .int)
            {
                return self.fail(external.position, "recvfrom expects func(int32, C.MutablePointer<uint8>, C.Size, int32, C.MutablePointer<int>, C.MutablePointer<uint32>) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "pipe")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "pipe expects func(C.MutablePointer<int>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "fork")) {
            if (parameters.len != 0 or return_type != .int32) return self.fail(external.position, "fork expects func() int32");
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "dup2")) {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int32 or return_type != .int32) {
                return self.fail(external.position, "dup2 expects func(int32, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "execve")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .address or return_type != .int32) {
                return self.fail(external.position, "execve expects func(C.Pointer<uint8>, C.Pointer<uint8>, C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "_exit")) {
            if (parameters.len != 1 or parameters[0] != .int32 or return_type != .void) return self.fail(external.position, "_exit expects func(int32) void");
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "waitpid")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .int32 or return_type != .int32) {
                return self.fail(external.position, "waitpid expects func(int32, C.MutablePointer<int>, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "kill")) {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int32 or return_type != .int32) {
                return self.fail(external.position, "kill expects func(int32, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "pthread_create")) {
            if (parameters.len != 4 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .address or parameters[3] != .address or return_type != .int32) return self.fail(external.position, "pthread_create expects four pointer parameters and int32 result");
        } else if (std.mem.eql(u8, external.library, "MacOS.lib_system") and std.mem.eql(u8, external.source_name, "pthread_join")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .address or return_type != .int32) return self.fail(external.position, "pthread_join expects func(uint, C.Pointer<uint8>) int32");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "write")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .uint or return_type != .int)
            {
                return self.fail(external.position, "write expects func(int32, C.Pointer<uint8>, C.Size) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "read")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .uint or return_type != .int)
            {
                return self.fail(external.position, "read expects func(int32, C.MutablePointer<uint32>, C.Size) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "ioctl")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .uint or
                parameters[2] != .address or return_type != .int32)
            {
                return self.fail(external.position, "ioctl expects func(int32, uint, C.MutablePointer<uint32>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "openat")) {
            if (parameters.len != 4 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .int32 or parameters[3] != .uint32 or return_type != .int32)
            {
                return self.fail(external.position, "openat expects func(int32, C.Pointer<uint8>, int32, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and
            (std.mem.eql(u8, external.source_name, "close") or std.mem.eql(u8, external.source_name, "fsync")))
        {
            if (parameters.len != 1 or parameters[0] != .int32 or return_type != .int32) {
                return self.fail(external.position, "close and fsync expect func(int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "lseek")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .int or parameters[2] != .int32 or return_type != .int) {
                return self.fail(external.position, "lseek expects func(int32, int, int32) int");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "ftruncate")) {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int or return_type != .int32) {
                return self.fail(external.position, "ftruncate expects func(int32, int) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "poll")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .uint or parameters[2] != .int32 or return_type != .int32) {
                return self.fail(external.position, "poll expects func(C.MutablePointer<uint>, C.Size, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "getrandom")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .uint or
                parameters[2] != .uint32 or return_type != .int)
            {
                return self.fail(external.position, "getrandom expects func(C.MutablePointer<uint32>, C.Size, uint32) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "clock_gettime")) {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "clock_gettime expects func(int32, C.MutablePointer<int>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "getcwd")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .uint or return_type != .int) {
                return self.fail(external.position, "getcwd expects func(C.MutablePointer<int>, C.Size) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "chdir")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int) {
                return self.fail(external.position, "chdir expects func(C.Pointer<uint8>) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "readlink")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .uint or return_type != .int) {
                return self.fail(external.position, "readlink expects func(C.Pointer<uint8>, C.MutablePointer<int>, C.Size) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "getpid")) {
            if (parameters.len != 0 or return_type != .int) return self.fail(external.position, "getpid expects func() C.SignedSize");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "socket")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .int32 or parameters[2] != .int32 or return_type != .int32) {
                return self.fail(external.position, "socket expects func(int32, int32, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "connect")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .uint32 or return_type != .int32) {
                return self.fail(external.position, "connect expects func(int32, C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "bind")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .uint32 or return_type != .int32) {
                return self.fail(external.position, "bind expects func(int32, C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and
            (std.mem.eql(u8, external.source_name, "listen") or std.mem.eql(u8, external.source_name, "shutdown")))
        {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int32 or return_type != .int32) {
                return self.fail(external.position, "listen and shutdown expect func(int32, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and
            (std.mem.eql(u8, external.source_name, "accept") or std.mem.eql(u8, external.source_name, "getsockname") or
                std.mem.eql(u8, external.source_name, "getpeername")))
        {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .address or return_type != .int32) {
                return self.fail(external.position, "socket address query expects func(int32, C.MutablePointer<int>, C.MutablePointer<uint32>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "setsockopt")) {
            if (parameters.len != 5 or parameters[0] != .int32 or parameters[1] != .int32 or parameters[2] != .int32 or
                parameters[3] != .address or parameters[4] != .uint32 or return_type != .int32)
            {
                return self.fail(external.position, "setsockopt expects func(int32, int32, int32, C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "sendto")) {
            if (parameters.len != 6 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .uint or
                parameters[3] != .int32 or parameters[4] != .address or parameters[5] != .uint32 or return_type != .int)
            {
                return self.fail(external.position, "sendto expects func(int32, C.Pointer<uint8>, C.Size, int32, C.Pointer<uint8>, uint32) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "recvfrom")) {
            if (parameters.len != 6 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .uint or
                parameters[3] != .int32 or parameters[4] != .address or parameters[5] != .address or return_type != .int)
            {
                return self.fail(external.position, "recvfrom expects func(int32, C.MutablePointer<uint8>, C.Size, int32, C.MutablePointer<int>, C.MutablePointer<uint32>) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "pipe")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) return self.fail(external.position, "pipe expects func(C.MutablePointer<int>) int32");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "fork")) {
            if (parameters.len != 0 or return_type != .int32) return self.fail(external.position, "fork expects func() int32");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "dup2")) {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int32 or return_type != .int32) return self.fail(external.position, "dup2 expects func(int32, int32) int32");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "execve")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .address or return_type != .int32) return self.fail(external.position, "execve expects func(C.Pointer<uint8>, C.Pointer<uint8>, C.Pointer<uint8>) int32");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "exit")) {
            if (parameters.len != 1 or parameters[0] != .int32 or return_type != .int) return self.fail(external.position, "exit expects func(int32) C.SignedSize");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "wait4")) {
            if (parameters.len != 4 or parameters[0] != .int32 or parameters[1] != .address or parameters[2] != .int32 or parameters[3] != .address or return_type != .int32) return self.fail(external.position, "wait4 expects func(int32, C.MutablePointer<int>, int32, C.Pointer<uint8>) int32");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "kill")) {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int32 or return_type != .int32) return self.fail(external.position, "kill expects func(int32, int32) int32");
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "newfstatat")) {
            if (parameters.len != 4 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .address or parameters[3] != .int32 or return_type != .int32)
            {
                return self.fail(external.position, "newfstatat expects func(int32, C.Pointer<uint8>, C.MutablePointer<int>, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "getdents64")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .uint or return_type != .int)
            {
                return self.fail(external.position, "getdents64 expects func(int32, C.MutablePointer<int>, C.Size) C.SignedSize");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and
            (std.mem.eql(u8, external.source_name, "mkdir") or std.mem.eql(u8, external.source_name, "chmod")))
        {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .uint32 or return_type != .int32) {
                return self.fail(external.position, "mkdir and chmod expect func(C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and
            (std.mem.eql(u8, external.source_name, "unlink") or std.mem.eql(u8, external.source_name, "rmdir")))
        {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "unlink and rmdir expect func(C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "rename")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "rename expects func(C.Pointer<uint8>, C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "thread_spawn")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .uint or return_type != .uint) {
                return self.fail(external.position, "thread_spawn expects func(uint, uint) uint");
            }
        } else if (std.mem.eql(u8, external.library, "Linux.kernel") and std.mem.eql(u8, external.source_name, "thread_join")) {
            if (parameters.len != 1 or parameters[0] != .uint or return_type != .int32) {
                return self.fail(external.position, "thread_join expects func(uint) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.bcrypt_primitives") and std.mem.eql(u8, external.source_name, "ProcessPrng")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .uint or return_type != .int32) {
                return self.fail(external.position, "ProcessPrng expects func(C.MutablePointer<uint32>, C.Size) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and
            (std.mem.eql(u8, external.source_name, "QueryPerformanceCounter") or
                std.mem.eql(u8, external.source_name, "QueryPerformanceFrequency")))
        {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "performance counter functions expect func(C.MutablePointer<int>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_write")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .uint32 or return_type != .int32)
            {
                return self.fail(external.position, "_write expects func(int32, C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_read")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .address or
                parameters[2] != .uint32 or return_type != .int32)
            {
                return self.fail(external.position, "_read expects func(int32, C.MutablePointer<uint32>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_isatty")) {
            if (parameters.len != 1 or parameters[0] != .int32 or return_type != .int32) {
                return self.fail(external.position, "_isatty expects func(int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_wopen")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .int32 or
                parameters[2] != .int32 or return_type != .int32)
            {
                return self.fail(external.position, "_wopen expects func(C.Pointer<uint8>, int32, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ucrtbase") and
            (std.mem.eql(u8, external.source_name, "_close") or std.mem.eql(u8, external.source_name, "_commit")))
        {
            if (parameters.len != 1 or parameters[0] != .int32 or return_type != .int32) {
                return self.fail(external.position, "_close and _commit expect func(int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_lseeki64")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .int or
                parameters[2] != .int32 or return_type != .int)
            {
                return self.fail(external.position, "_lseeki64 expects func(int32, int, int32) int");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ucrtbase") and std.mem.eql(u8, external.source_name, "_chsize_s")) {
            if (parameters.len != 2 or parameters[0] != .int32 or parameters[1] != .int or return_type != .int32) {
                return self.fail(external.position, "_chsize_s expects func(int32, int) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ucrtbase") and
            (std.mem.eql(u8, external.source_name, "__p___argc") or std.mem.eql(u8, external.source_name, "__p___wargv")))
        {
            if (parameters.len != 0 or return_type != .address) {
                return self.fail(external.position, "Windows argument accessors expect func() C.Pointer<uint8>");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetStdHandle")) {
            if (parameters.len != 1 or parameters[0] != .int32 or return_type != .uint) {
                return self.fail(external.position, "GetStdHandle expects func(int32) uint");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleScreenBufferInfo")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "GetConsoleScreenBufferInfo expects func(uint, C.MutablePointer<int>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleMode")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "GetConsoleMode expects func(uint, C.MutablePointer<uint32>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetConsoleMode")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .uint32 or return_type != .int32) {
                return self.fail(external.position, "SetConsoleMode expects func(uint, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetConsoleCP")) {
            if (parameters.len != 0 or return_type != .uint32) return self.fail(external.position, "GetConsoleCP expects func() uint32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetConsoleCP")) {
            if (parameters.len != 1 or parameters[0] != .uint32 or return_type != .int32) return self.fail(external.position, "SetConsoleCP expects func(uint32) int32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "WaitForSingleObject")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .uint32 or return_type != .uint32) {
                return self.fail(external.position, "WaitForSingleObject expects func(uint, uint32) uint32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetCurrentDirectoryW")) {
            if (parameters.len != 2 or parameters[0] != .uint32 or parameters[1] != .address or return_type != .uint32) {
                return self.fail(external.position, "GetCurrentDirectoryW expects func(uint32, C.MutablePointer<int>) uint32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetCurrentDirectoryW")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "SetCurrentDirectoryW expects func(C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetModuleFileNameW")) {
            if (parameters.len != 3 or parameters[0] != .uint or parameters[1] != .address or parameters[2] != .uint32 or return_type != .uint32) {
                return self.fail(external.position, "GetModuleFileNameW expects func(uint, C.MutablePointer<int>, uint32) uint32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetCurrentProcessId")) {
            if (parameters.len != 0 or return_type != .uint32) return self.fail(external.position, "GetCurrentProcessId expects func() uint32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetEnvironmentVariableW")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .uint32 or return_type != .uint32) {
                return self.fail(external.position, "GetEnvironmentVariableW expects func(C.Pointer<uint8>, C.MutablePointer<int>, uint32) uint32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetEnvironmentVariableW")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "SetEnvironmentVariableW expects func(C.Pointer<uint8>, C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetEnvironmentStringsW")) {
            if (parameters.len != 0 or return_type != .address) return self.fail(external.position, "GetEnvironmentStringsW expects func() C.Pointer<uint8>");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FreeEnvironmentStringsW")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "FreeEnvironmentStringsW expects func(C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetFileAttributesExW")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .int32 or parameters[2] != .address or return_type != .int32) {
                return self.fail(external.position, "GetFileAttributesExW expects func(C.Pointer<uint8>, int32, C.MutablePointer<int>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindFirstFileW")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .address or return_type != .uint) {
                return self.fail(external.position, "FindFirstFileW expects func(C.Pointer<uint8>, C.MutablePointer<int>) uint");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindNextFileW")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "FindNextFileW expects func(uint, C.MutablePointer<int>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "FindClose")) {
            if (parameters.len != 1 or parameters[0] != .uint or return_type != .int32) {
                return self.fail(external.position, "FindClose expects func(uint) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and
            (std.mem.eql(u8, external.source_name, "CreateDirectoryW") or std.mem.eql(u8, external.source_name, "CopyFileW")))
        {
            if (std.mem.eql(u8, external.source_name, "CreateDirectoryW")) {
                if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .address or return_type != .int32) {
                    return self.fail(external.position, "CreateDirectoryW expects func(C.Pointer<uint8>, C.Pointer<uint8>) int32");
                }
            } else if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .int32 or return_type != .int32) {
                return self.fail(external.position, "CopyFileW expects func(C.Pointer<uint8>, C.Pointer<uint8>, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and
            (std.mem.eql(u8, external.source_name, "DeleteFileW") or std.mem.eql(u8, external.source_name, "RemoveDirectoryW")))
        {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .int32) {
                return self.fail(external.position, "DeleteFileW and RemoveDirectoryW expect func(C.Pointer<uint8>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "MoveFileExW")) {
            if (parameters.len != 3 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .uint32 or return_type != .int32) {
                return self.fail(external.position, "MoveFileExW expects func(C.Pointer<uint8>, C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetFileAttributesW")) {
            if (parameters.len != 2 or parameters[0] != .address or parameters[1] != .uint32 or return_type != .int32) {
                return self.fail(external.position, "SetFileAttributesW expects func(C.Pointer<uint8>, uint32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetFullPathNameW")) {
            if (parameters.len != 4 or parameters[0] != .address or parameters[1] != .uint32 or parameters[2] != .address or parameters[3] != .address or return_type != .uint32) {
                return self.fail(external.position, "GetFullPathNameW expects func(C.Pointer<uint8>, uint32, C.MutablePointer<int>, C.MutablePointer<int>) uint32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreatePipe")) {
            if (parameters.len != 4 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .address or parameters[3] != .uint32 or return_type != .int32) return self.fail(external.position, "CreatePipe expects func(C.MutablePointer<uint>, C.MutablePointer<uint>, C.Pointer<uint8>, uint32) int32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "SetHandleInformation")) {
            if (parameters.len != 3 or parameters[0] != .uint or parameters[1] != .uint32 or parameters[2] != .uint32 or return_type != .int32) return self.fail(external.position, "SetHandleInformation expects func(uint, uint32, uint32) int32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreateProcessW")) {
            if (parameters.len != 10 or parameters[0] != .address or parameters[1] != .address or parameters[2] != .address or parameters[3] != .address or parameters[4] != .int32 or parameters[5] != .uint32 or parameters[6] != .address or parameters[7] != .address or parameters[8] != .address or parameters[9] != .address or return_type != .int32) return self.fail(external.position, "CreateProcessW expects its ten Win32 parameters");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and
            (std.mem.eql(u8, external.source_name, "ReadFile") or std.mem.eql(u8, external.source_name, "WriteFile")))
        {
            if (parameters.len != 5 or parameters[0] != .uint or parameters[1] != .address or parameters[2] != .uint32 or parameters[3] != .address or parameters[4] != .address or return_type != .int32) return self.fail(external.position, "ReadFile and WriteFile expect func(uint, C.Pointer<uint8>, uint32, C.MutablePointer<uint32>, C.Pointer<uint8>) int32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "PeekNamedPipe")) {
            if (parameters.len != 6 or parameters[0] != .uint or parameters[1] != .address or parameters[2] != .uint32 or parameters[3] != .address or parameters[4] != .address or parameters[5] != .address or return_type != .int32) return self.fail(external.position, "PeekNamedPipe expects its six Win32 parameters");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CloseHandle")) {
            if (parameters.len != 1 or parameters[0] != .uint or return_type != .int32) return self.fail(external.position, "CloseHandle expects func(uint) int32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "TerminateProcess")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .uint32 or return_type != .int32) return self.fail(external.position, "TerminateProcess expects func(uint, uint32) int32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetExitCodeProcess")) {
            if (parameters.len != 2 or parameters[0] != .uint or parameters[1] != .address or return_type != .int32) return self.fail(external.position, "GetExitCodeProcess expects func(uint, C.MutablePointer<uint32>) int32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "GetLastError")) {
            if (parameters.len != 0 or return_type != .uint32) return self.fail(external.position, "GetLastError expects func() uint32");
        } else if (std.mem.eql(u8, external.library, "Windows.kernel32") and std.mem.eql(u8, external.source_name, "CreateThread")) {
            if (parameters.len != 6 or parameters[0] != .address or parameters[1] != .uint or parameters[2] != .address or parameters[3] != .address or parameters[4] != .uint32 or parameters[5] != .address or return_type != .uint) return self.fail(external.position, "CreateThread expects its six Win32 parameters");
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "GetAddrInfoW")) {
            if (parameters.len != 4 or parameters[0] != .address or parameters[1] != .address or
                parameters[2] != .address or parameters[3] != .address or return_type != .int32)
            {
                return self.fail(external.position, "GetAddrInfoW expects func(C.Pointer<uint8>, C.Pointer<uint8>, C.Pointer<uint8>, C.MutablePointer<uint>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "FreeAddrInfoW")) {
            if (parameters.len != 1 or parameters[0] != .address or return_type != .void) {
                return self.fail(external.position, "FreeAddrInfoW expects func(C.Pointer<uint8>) void");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "WSAStartup")) {
            if (parameters.len != 2 or parameters[0] != .uint32 or parameters[1] != .address or return_type != .int32) {
                return self.fail(external.position, "WSAStartup expects func(uint32, C.MutablePointer<int>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "WSACleanup")) {
            if (parameters.len != 0 or return_type != .int32) {
                return self.fail(external.position, "WSACleanup expects func() int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "socket")) {
            if (parameters.len != 3 or parameters[0] != .int32 or parameters[1] != .int32 or parameters[2] != .int32 or return_type != .int) {
                return self.fail(external.position, "socket expects func(int32, int32, int32) int");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and
            (std.mem.eql(u8, external.source_name, "connect") or std.mem.eql(u8, external.source_name, "bind")))
        {
            if (parameters.len != 3 or parameters[0] != .int or parameters[1] != .address or parameters[2] != .int32 or return_type != .int32) {
                return self.fail(external.position, "connect and bind expect func(int, C.Pointer<uint8>, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and
            (std.mem.eql(u8, external.source_name, "listen") or std.mem.eql(u8, external.source_name, "shutdown")))
        {
            if (parameters.len != 2 or parameters[0] != .int or parameters[1] != .int32 or return_type != .int32) {
                return self.fail(external.position, "listen and shutdown expect func(int, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "accept")) {
            if (parameters.len != 3 or parameters[0] != .int or parameters[1] != .address or parameters[2] != .address or return_type != .int) {
                return self.fail(external.position, "accept expects func(int, C.MutablePointer<int>, C.MutablePointer<int32>) int");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and
            (std.mem.eql(u8, external.source_name, "recv") or std.mem.eql(u8, external.source_name, "send")))
        {
            if (parameters.len != 4 or parameters[0] != .int or parameters[1] != .address or parameters[2] != .int32 or parameters[3] != .int32 or return_type != .int32) {
                return self.fail(external.position, "recv and send expect func(int, C.MutablePointer<uint8>, int32, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "closesocket")) {
            if (parameters.len != 1 or parameters[0] != .int or return_type != .int32) {
                return self.fail(external.position, "closesocket expects func(int) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and
            (std.mem.eql(u8, external.source_name, "getsockname") or std.mem.eql(u8, external.source_name, "getpeername")))
        {
            if (parameters.len != 3 or parameters[0] != .int or parameters[1] != .address or parameters[2] != .address or return_type != .int32) {
                return self.fail(external.position, "socket address query expects func(int, C.MutablePointer<int>, C.MutablePointer<int32>) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "setsockopt")) {
            if (parameters.len != 5 or parameters[0] != .int or parameters[1] != .int32 or parameters[2] != .int32 or parameters[3] != .address or parameters[4] != .int32 or return_type != .int32) {
                return self.fail(external.position, "setsockopt expects func(int, int32, int32, C.Pointer<uint8>, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "sendto")) {
            if (parameters.len != 6 or parameters[0] != .int or parameters[1] != .address or parameters[2] != .int32 or parameters[3] != .int32 or parameters[4] != .address or parameters[5] != .int32 or return_type != .int32) {
                return self.fail(external.position, "sendto expects func(int, C.Pointer<uint8>, int32, int32, C.Pointer<uint8>, int32) int32");
            }
        } else if (std.mem.eql(u8, external.library, "Windows.ws2_32") and std.mem.eql(u8, external.source_name, "recvfrom")) {
            if (parameters.len != 6 or parameters[0] != .int or parameters[1] != .address or parameters[2] != .int32 or parameters[3] != .int32 or parameters[4] != .address or parameters[5] != .address or return_type != .int32) {
                return self.fail(external.position, "recvfrom expects func(int, C.MutablePointer<uint8>, int32, int32, C.MutablePointer<int>, C.MutablePointer<int32>) int32");
            }
        } else return self.fail(external.position, "interop library or function is not supported yet");
        try result.append(self.allocator, .{
            .name = external.name,
            .provider = external.library,
            .source_name = external.source_name,
            .parameters = parameters,
            .return_type = return_type,
        });
    }
    return result.toOwnedSlice(self.allocator);
}

fn externalType(self: anytype, value: Ast.ExternalType, position: anytype) !Types.Type {
    return switch (value) {
        .void => .void,
        .int32 => .int32,
        .int64 => .int,
        .uint32 => .uint32,
        .uint64 => .uint,
        .size => .uint,
        .signed_size => .int,
        .read_pointer => |child| if (child == .uint8)
            .address
        else
            self.fail(position, "C.Pointer currently supports only uint8"),
        .mutable_pointer => |child| if (child == .uint8 or child == .uint32 or child == .int or child == .uint)
            .address
        else
            self.fail(position, "C.MutablePointer currently supports uint32, int, and uint"),
    };
}

pub fn analyzeIntrinsic(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.load")) {
        if (call.type_arguments.len != 1 or call.named_arguments.len != 0 or call.arguments.len != 2) {
            return self.fail(call.name_position, "C.load<T> expects an address and a uint byte offset");
        }
        const loaded_type = call.type_arguments[0];
        if (!loaded_type.isInteger()) return self.fail(call.name_position, "C.load<T> supports integer scalar types");
        const address = try self.analyzeExpression(builder, call.arguments[0]);
        if (address.type != .address and address.type != .uint) return self.fail(call.arguments[0].position, "C.load<T> expects an interop address or address bits");
        const byte_offset = try self.analyzeExpressionExpected(builder, call.arguments[1], .uint);
        if (byte_offset.type != .uint) return self.fail(call.arguments[1].position, "C.load<T> byte offset expects uint");
        const result = try self.newValue(builder, loaded_type);
        try self.emit(builder, .{ .address_load = .{
            .result = result,
            .address = address.value,
            .byte_offset = byte_offset.value,
            .type = loaded_type,
        } });
        return .{ .type = loaded_type, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.store")) {
        if (call.type_arguments.len != 1 or call.named_arguments.len != 0 or call.arguments.len != 3) {
            return self.fail(call.name_position, "C.store<T> expects an address, a uint byte offset, and a value");
        }
        const stored_type = call.type_arguments[0];
        if (!stored_type.isInteger()) return self.fail(call.name_position, "C.store<T> supports integer scalar types");
        const address = try self.analyzeExpression(builder, call.arguments[0]);
        if (address.type != .address and address.type != .uint) return self.fail(call.arguments[0].position, "C.store<T> expects an interop address or address bits");
        const byte_offset = try self.analyzeExpressionExpected(builder, call.arguments[1], .uint);
        if (byte_offset.type != .uint) return self.fail(call.arguments[1].position, "C.store<T> byte offset expects uint");
        const operand = try self.analyzeExpressionExpected(builder, call.arguments[2], stored_type);
        try self.emit(builder, .{ .address_store = .{
            .address = address.value,
            .byte_offset = byte_offset.value,
            .operand = operand.value,
            .type = stored_type,
        } });
        return operand;
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.address_at")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 2) {
            return self.fail(call.name_position, "C.address_at expects an address and a uint byte offset");
        }
        const address = try self.analyzeExpression(builder, call.arguments[0]);
        if (address.type != .address and address.type != .uint) return self.fail(call.arguments[0].position, "C.address_at expects an interop address or address bits");
        const byte_offset = try self.analyzeExpressionExpected(builder, call.arguments[1], .uint);
        if (byte_offset.type != .uint) return self.fail(call.arguments[1].position, "C.address_at byte offset expects uint");
        const result = try self.newValue(builder, .uint);
        try self.emit(builder, .{ .address_load = .{
            .result = result,
            .address = address.value,
            .byte_offset = byte_offset.value,
            .type = .uint,
        } });
        return .{ .type = .uint, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.address_bits")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.address_bits expects one interop address");
        }
        const address = try self.analyzeExpression(builder, call.arguments[0]);
        if (address.type != .address) return self.fail(call.arguments[0].position, "C.address_bits expects an interop address");
        const result = try self.newValue(builder, .uint);
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = address.value } });
        return .{ .type = .uint, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.pointer_bits")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.pointer_bits expects one uint address value");
        }
        const bits = try self.analyzeExpressionExpected(builder, call.arguments[0], .uint);
        if (bits.type != .uint) return self.fail(call.arguments[0].position, "C.pointer_bits expects uint address bits");
        const result = try self.newValue(builder, .address);
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = bits.value } });
        return .{ .type = .address, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.function_address")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.function_address expects one function value");
        }
        const function = try self.analyzeExpression(builder, call.arguments[0]);
        if (function.type.functionIndex() == null) return self.fail(call.arguments[0].position, "C.function_address expects a function value");
        const result = try self.newValue(builder, .uint);
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = function.value } });
        return .{ .type = .uint, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.object_address")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.object_address expects one class value");
        }
        const object = try self.analyzeExpression(builder, call.arguments[0]);
        const structure = object.type.structureIndex() orelse return self.fail(call.arguments[0].position, "C.object_address expects a class value");
        if (structure >= self.structures.len or !self.structures[structure].is_class) return self.fail(call.arguments[0].position, "C.object_address expects a class value");
        const result = try self.newValue(builder, .uint);
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = object.value } });
        return .{ .type = .uint, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.object_from_address")) {
        if (call.type_arguments.len != 1 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.object_from_address<T> expects one uint address");
        }
        const target = call.type_arguments[0];
        const structure = target.structureIndex() orelse return self.fail(call.name_position, "C.object_from_address<T> requires a class type");
        if (structure >= self.structures.len or !self.structures[structure].is_class) return self.fail(call.name_position, "C.object_from_address<T> requires a class type");
        const address = try self.analyzeExpressionExpected(builder, call.arguments[0], .uint);
        if (address.type != .uint) return self.fail(call.arguments[0].position, "C.object_from_address<T> expects uint address bits");
        const result = try self.newValue(builder, target);
        try self.emit(builder, .{ .copy = .{ .result = result, .operand = address.value } });
        return .{ .type = target, .value = result };
    }
    if (call.receiver == null and (std.mem.eql(u8, call.name, "C.pointer") or std.mem.eql(u8, call.name, "C.terminated_pointer"))) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.pointer expects one string");
        }
        const source = try self.analyzeExpression(builder, call.arguments[0]);
        if (source.type != .str) return self.fail(call.arguments[0].position, "C.pointer expects a string");
        const result = try self.newValue(builder, .address);
        try self.emit(builder, .{ .string_address = .{ .result = result, .operand = source.value } });
        return .{ .type = .address, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.byte_count")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.byte_count expects one string");
        }
        const source = try self.analyzeExpression(builder, call.arguments[0]);
        if (source.type != .str) return self.fail(call.arguments[0].position, "C.byte_count expects a string");
        const result = try self.newValue(builder, .uint);
        try self.emit(builder, .{ .string_byte_count = .{ .result = result, .operand = source.value } });
        return .{ .type = .uint, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.byte_at")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 2) {
            return self.fail(call.name_position, "C.byte_at expects one string and one uint index");
        }
        const source = try self.analyzeExpression(builder, call.arguments[0]);
        if (source.type != .str) return self.fail(call.arguments[0].position, "C.byte_at expects a string");
        const index = try self.analyzeExpressionExpected(builder, call.arguments[1], .uint);
        if (index.type != .uint) return self.fail(call.arguments[1].position, "C.byte_at index expects uint");
        const result = try self.newValue(builder, .uint8);
        try self.emit(builder, .{ .string_byte_at = .{ .result = result, .operand = source.value, .index = index.value } });
        return .{ .type = .uint8, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.string")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.string expects one uint8 view");
        }
        const source = try self.analyzeExpression(builder, call.arguments[0]);
        const collection = Collections.collectionForType(self.structures, source.type) orelse
            return self.fail(call.arguments[0].position, "C.string expects a uint8 view");
        if (!collection.view or collection.element != .uint8) {
            return self.fail(call.arguments[0].position, "C.string expects a uint8 view");
        }
        const result = try self.newValue(builder, .str);
        try self.emit(builder, .{ .string_from_bytes = .{ .result = result, .bytes = source.value } });
        return .{ .type = .str, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.mutable_string_pointer")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.mutable_string_pointer expects one private mutable string");
        }
        if (call.arguments[0].value != .identifier) {
            return self.fail(call.arguments[0].position, "C.mutable_string_pointer requires a direct var string binding");
        }
        const binding = Support.findBinding(builder.bindings.items, call.arguments[0].value.identifier) orelse
            return self.fail(call.arguments[0].position, "C.mutable_string_pointer requires a direct var string binding");
        if (!binding.mutable or binding.type != .str) {
            return self.fail(call.arguments[0].position, "C.mutable_string_pointer requires a direct var string binding");
        }
        const source = try self.analyzeExpression(builder, call.arguments[0]);
        const result = try self.newValue(builder, .address);
        try self.emit(builder, .{ .string_address = .{ .result = result, .operand = source.value } });
        return .{ .type = .address, .value = result };
    }
    if (call.receiver == null and std.mem.eql(u8, call.name, "C.mutable_pointer")) {
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0 or call.arguments.len != 1) {
            return self.fail(call.name_position, "C.mutable_pointer expects one stable mutable value");
        }
        const prepared = try @import("MutableReferences.zig").prepare(self, builder, call.arguments[0], null);
        const supported_scalar = prepared.type == .uint32 or prepared.type == .int or prepared.type == .uint;
        const supported_array = if (Collections.collectionForType(self.structures, prepared.type)) |collection|
            collection.length != null and (collection.element == .uint32 or collection.element == .int or collection.element == .uint)
        else
            false;
        if (!supported_scalar and !supported_array) {
            return self.fail(call.name_position, "C.mutable_pointer supports uint32, int, uint, and their fixed arrays");
        }
        if (prepared.temporary != null) {
            return self.fail(call.arguments[0].position, "C.mutable_pointer requires stable mutable storage");
        }
        return .{ .type = .address, .value = prepared.reference };
    }
    return null;
}

pub fn analyzeCall(self: anytype, builder: anytype, call: Ast.Expression.Call) !?Model.TypedValue {
    for (self.external_functions, 0..) |external, external_index| {
        if (!std.mem.eql(u8, external.name, call.name)) continue;
        if (call.type_arguments.len != 0 or call.named_arguments.len != 0) {
            return self.fail(call.name_position, "foreign function calls use positional arguments");
        }
        if (call.arguments.len != external.parameters.len) {
            const message = try std.fmt.allocPrint(
                self.allocator,
                "foreign function '{s}' expects {d} arguments, found {d}",
                .{ call.name, external.parameters.len, call.arguments.len },
            );
            return self.fail(call.name_position, message);
        }
        var arguments: std.ArrayList(Ir.ValueId) = .empty;
        for (call.arguments, external.parameters, 0..) |argument_expression, expected, argument_index| {
            var argument = try self.analyzeExpressionExpected(builder, argument_expression, expected);
            if (argument.type != expected and self.canImplicitlyConvert(argument.type, expected)) {
                argument = try self.coerce(builder, argument, expected, argument_expression.position);
            }
            if (argument.type != expected) {
                const message = try std.fmt.allocPrint(
                    self.allocator,
                    "argument {d} of foreign function '{s}' expects '{s}', found '{s}'",
                    .{ argument_index + 1, call.name, self.typeName(expected), self.typeName(argument.type) },
                );
                return self.fail(argument_expression.position, message);
            }
            try arguments.append(self.allocator, argument.value);
        }
        const result: ?Ir.ValueId = if (external.return_type == .void) null else try self.newValue(builder, external.return_type);
        try self.emit(builder, .{ .boundary_call = .{
            .result = result,
            .function = external_index,
            .arguments = try arguments.toOwnedSlice(self.allocator),
        } });
        return if (result) |value| .{ .type = external.return_type, .value = value } else null;
    }
    return null;
}

pub fn hasFunction(self: anytype, name: []const u8) bool {
    for (self.external_functions) |external| {
        if (std.mem.eql(u8, external.name, name)) return true;
    }
    return false;
}
