const std = @import("std");
const Machine = @import("../Arm64/Machine.zig");
const MathBoundary = @import("../Math/Boundary.zig");
const WindowsImports = @import("../Windows/Imports.zig");

const Allocator = std.mem.Allocator;
const Register = enum(u4) { rax = 0, rcx = 1, rdx = 2, rbx = 3, rsp = 4, rbp = 5, rsi = 6, rdi = 7, r8 = 8, r9 = 9, r10 = 10, r11 = 11, r12 = 12, r13 = 13, r14 = 14, r15 = 15 };

pub const Platform = enum { linux, windows };
pub const Error = Machine.Error || Allocator.Error || error{UnsupportedInstruction};
pub const Site = struct { displacement_offset: u32, function: usize };

pub fn emit(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    import_sites: *std.ArrayList(WindowsImports.X64Site),
    external_sites: *std.ArrayList(Site),
    platform: Platform,
    program: Machine.Program,
    function: Machine.Function,
    call: Machine.Instruction.ExternalCall,
) Error!void {
    if (call.function >= program.external_functions.len) return error.InvalidMachineProgram;
    const external = program.external_functions[call.function];
    if (external.package_private or MathBoundary.identify(external.source_name) != null) {
        return emitBoundaryCall(allocator, bytes, external_sites, platform, external, call);
    }
    switch (platform) {
        .linux => {
            if (!std.mem.eql(u8, external.provider, "Linux.kernel")) {
                std.debug.print("x64 unsupported Linux boundary: {s}.{s}\n", .{ external.provider, external.source_name });
                return unsupported("Linux external boundary");
            }
            if (std.mem.eql(u8, external.source_name, "thread_spawn") and call.arguments.len == 2) {
                try emitLinuxThreadSpawn(allocator, bytes, call.arguments);
                if (call.result) |result| try emitStoreStack(allocator, bytes, .rax, result);
                return;
            } else if (std.mem.eql(u8, external.source_name, "thread_join") and call.arguments.len == 1) {
                try emitLinuxThreadJoin(allocator, bytes, call.arguments[0]);
                if (call.result) |result| try emitStoreStack(allocator, bytes, .rax, result);
                return;
            } else if (std.mem.eql(u8, external.source_name, "getrandom") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 318);
            } else if (std.mem.eql(u8, external.source_name, "clock_gettime") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 228);
            } else if (std.mem.eql(u8, external.source_name, "read") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 0);
            } else if (std.mem.eql(u8, external.source_name, "write") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 1);
            } else if (std.mem.eql(u8, external.source_name, "ioctl") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 16);
            } else if (std.mem.eql(u8, external.source_name, "openat") and call.arguments.len == 4) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitLoadStack(allocator, bytes, .r10, call.arguments[3]);
                try emitImmediate(allocator, bytes, .rax, 257);
            } else if (std.mem.eql(u8, external.source_name, "close") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitImmediate(allocator, bytes, .rax, 3);
            } else if (std.mem.eql(u8, external.source_name, "fsync") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitImmediate(allocator, bytes, .rax, 74);
            } else if (std.mem.eql(u8, external.source_name, "lseek") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 8);
            } else if (std.mem.eql(u8, external.source_name, "ftruncate") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 77);
            } else if (std.mem.eql(u8, external.source_name, "poll") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 7);
            } else if (std.mem.eql(u8, external.source_name, "getcwd") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 79);
            } else if (std.mem.eql(u8, external.source_name, "chdir") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitImmediate(allocator, bytes, .rax, 80);
            } else if (std.mem.eql(u8, external.source_name, "readlink") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 89);
            } else if (std.mem.eql(u8, external.source_name, "getpid") and call.arguments.len == 0) {
                try emitImmediate(allocator, bytes, .rax, 39);
            } else if (std.mem.eql(u8, external.source_name, "socket") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 41);
            } else if (std.mem.eql(u8, external.source_name, "connect") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 42);
            } else if (std.mem.eql(u8, external.source_name, "bind") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 49);
            } else if (std.mem.eql(u8, external.source_name, "listen") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 50);
            } else if (std.mem.eql(u8, external.source_name, "accept") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 43);
            } else if (std.mem.eql(u8, external.source_name, "shutdown") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 48);
            } else if (std.mem.eql(u8, external.source_name, "getsockname") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 51);
            } else if (std.mem.eql(u8, external.source_name, "getpeername") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 52);
            } else if (std.mem.eql(u8, external.source_name, "setsockopt") and call.arguments.len == 5) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitLoadStack(allocator, bytes, .r10, call.arguments[3]);
                try emitLoadStack(allocator, bytes, .r8, call.arguments[4]);
                try emitImmediate(allocator, bytes, .rax, 54);
            } else if (std.mem.eql(u8, external.source_name, "sendto") and call.arguments.len == 6) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitLoadStack(allocator, bytes, .r10, call.arguments[3]);
                try emitLoadStack(allocator, bytes, .r8, call.arguments[4]);
                try emitLoadStack(allocator, bytes, .r9, call.arguments[5]);
                try emitImmediate(allocator, bytes, .rax, 44);
            } else if (std.mem.eql(u8, external.source_name, "recvfrom") and call.arguments.len == 6) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitLoadStack(allocator, bytes, .r10, call.arguments[3]);
                try emitLoadStack(allocator, bytes, .r8, call.arguments[4]);
                try emitLoadStack(allocator, bytes, .r9, call.arguments[5]);
                try emitImmediate(allocator, bytes, .rax, 45);
            } else if (std.mem.eql(u8, external.source_name, "pipe") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitImmediate(allocator, bytes, .rax, 22);
            } else if (std.mem.eql(u8, external.source_name, "fork") and call.arguments.len == 0) {
                try emitImmediate(allocator, bytes, .rax, 57);
            } else if (std.mem.eql(u8, external.source_name, "dup2") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 33);
            } else if (std.mem.eql(u8, external.source_name, "execve") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 59);
            } else if (std.mem.eql(u8, external.source_name, "exit") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitImmediate(allocator, bytes, .rax, 60);
            } else if (std.mem.eql(u8, external.source_name, "wait4") and call.arguments.len == 4) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitLoadStack(allocator, bytes, .r10, call.arguments[3]);
                try emitImmediate(allocator, bytes, .rax, 61);
            } else if (std.mem.eql(u8, external.source_name, "kill") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 62);
            } else if (std.mem.eql(u8, external.source_name, "newfstatat") and call.arguments.len == 4) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitLoadStack(allocator, bytes, .r10, call.arguments[3]);
                try emitImmediate(allocator, bytes, .rax, 262);
            } else if (std.mem.eql(u8, external.source_name, "getdents64") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[2]);
                try emitImmediate(allocator, bytes, .rax, 217);
            } else if (std.mem.eql(u8, external.source_name, "mkdir") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 83);
            } else if (std.mem.eql(u8, external.source_name, "rmdir") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitImmediate(allocator, bytes, .rax, 84);
            } else if (std.mem.eql(u8, external.source_name, "unlink") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitImmediate(allocator, bytes, .rax, 87);
            } else if (std.mem.eql(u8, external.source_name, "rename") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 82);
            } else if (std.mem.eql(u8, external.source_name, "chmod") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rdi, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rsi, call.arguments[1]);
                try emitImmediate(allocator, bytes, .rax, 90);
            } else {
                std.debug.print("x64 unsupported Linux boundary: {s}.{s}\n", .{ external.provider, external.source_name });
                return unsupported("Linux external boundary");
            }
            try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
        },
        .windows => {
            if (std.mem.eql(u8, external.provider, "Windows.bcrypt_primitives") and
                std.mem.eql(u8, external.source_name, "ProcessPrng") and call.arguments.len == 2)
            {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                try emitWindowsImportCall(allocator, bytes, import_sites, .process_prng);
            } else if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .r8, call.arguments[2]);
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "_write"))
                    .crt_write
                else if (std.mem.eql(u8, external.source_name, "_read"))
                    .crt_read
                else if (std.mem.eql(u8, external.source_name, "_wopen"))
                    .crt_wopen
                else if (std.mem.eql(u8, external.source_name, "_lseeki64"))
                    .crt_lseeki64
                else
                    return unsupported("Windows external boundary");
                try emitWindowsImportCall(allocator, bytes, import_sites, symbol);
            } else if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "_isatty"))
                    .crt_isatty
                else if (std.mem.eql(u8, external.source_name, "_close"))
                    .crt_close
                else if (std.mem.eql(u8, external.source_name, "_commit"))
                    .crt_commit
                else
                    return unsupported("Windows external boundary");
                try emitWindowsImportCall(allocator, bytes, import_sites, symbol);
            } else if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and call.arguments.len == 2 and
                std.mem.eql(u8, external.source_name, "_chsize_s"))
            {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                try emitWindowsImportCall(allocator, bytes, import_sites, .crt_chsize_s);
            } else if (std.mem.eql(u8, external.provider, "Windows.ucrtbase") and call.arguments.len == 0) {
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "__p___argc"))
                    .crt_p_argc
                else if (std.mem.eql(u8, external.source_name, "__p___wargv"))
                    .crt_p_wargv
                else
                    return unsupported("Windows external boundary");
                try emitWindowsImportCall(allocator, bytes, import_sites, symbol);
            } else if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and call.arguments.len == 4 and
                std.mem.eql(u8, external.source_name, "GetAddrInfoW"))
            {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .r8, call.arguments[2]);
                try emitLoadStack(allocator, bytes, .r9, call.arguments[3]);
                try emitWindowsImportCall(allocator, bytes, import_sites, .get_addr_info_w);
            } else if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and call.arguments.len == 1 and
                std.mem.eql(u8, external.source_name, "FreeAddrInfoW"))
            {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitWindowsImportCall(allocator, bytes, import_sites, .free_addr_info_w);
            } else if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and call.arguments.len == 2 and
                std.mem.eql(u8, external.source_name, "WSAStartup"))
            {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                try emitWindowsImportCall(allocator, bytes, import_sites, .wsa_startup);
            } else if (std.mem.eql(u8, external.provider, "Windows.ws2_32") and call.arguments.len == 0 and
                std.mem.eql(u8, external.source_name, "WSACleanup"))
            {
                try emitWindowsImportCall(allocator, bytes, import_sites, .wsa_cleanup);
            } else if (std.mem.eql(u8, external.provider, "Windows.ws2_32")) {
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "socket"))
                    .wsa_socket
                else if (std.mem.eql(u8, external.source_name, "connect"))
                    .wsa_connect
                else if (std.mem.eql(u8, external.source_name, "bind"))
                    .wsa_bind
                else if (std.mem.eql(u8, external.source_name, "listen"))
                    .wsa_listen
                else if (std.mem.eql(u8, external.source_name, "accept"))
                    .wsa_accept
                else if (std.mem.eql(u8, external.source_name, "recv"))
                    .wsa_recv
                else if (std.mem.eql(u8, external.source_name, "send"))
                    .wsa_send
                else if (std.mem.eql(u8, external.source_name, "shutdown"))
                    .wsa_shutdown
                else if (std.mem.eql(u8, external.source_name, "closesocket"))
                    .wsa_close_socket
                else if (std.mem.eql(u8, external.source_name, "getsockname"))
                    .wsa_getsockname
                else if (std.mem.eql(u8, external.source_name, "getpeername"))
                    .wsa_getpeername
                else if (std.mem.eql(u8, external.source_name, "setsockopt"))
                    .wsa_setsockopt
                else if (std.mem.eql(u8, external.source_name, "sendto"))
                    .wsa_sendto
                else if (std.mem.eql(u8, external.source_name, "recvfrom"))
                    .wsa_recvfrom
                else
                    return unsupported("Windows external boundary");
                try emitWindowsImportCallArguments(allocator, bytes, import_sites, call.arguments, symbol);
            } else if (std.mem.eql(u8, external.provider, "Windows.kernel32") and
                (std.mem.eql(u8, external.source_name, "CreatePipe") or std.mem.eql(u8, external.source_name, "SetHandleInformation") or
                    std.mem.eql(u8, external.source_name, "CreateProcessW") or std.mem.eql(u8, external.source_name, "ReadFile") or
                    std.mem.eql(u8, external.source_name, "WriteFile") or std.mem.eql(u8, external.source_name, "PeekNamedPipe") or
                    std.mem.eql(u8, external.source_name, "CloseHandle") or std.mem.eql(u8, external.source_name, "TerminateProcess") or
                    std.mem.eql(u8, external.source_name, "GetExitCodeProcess") or std.mem.eql(u8, external.source_name, "GetLastError") or
                    std.mem.eql(u8, external.source_name, "CreateThread")))
            {
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "CreatePipe")) .create_pipe else if (std.mem.eql(u8, external.source_name, "SetHandleInformation")) .set_handle_information else if (std.mem.eql(u8, external.source_name, "CreateProcessW")) .create_process_w else if (std.mem.eql(u8, external.source_name, "ReadFile")) .read_file else if (std.mem.eql(u8, external.source_name, "WriteFile")) .write_file else if (std.mem.eql(u8, external.source_name, "PeekNamedPipe")) .peek_named_pipe else if (std.mem.eql(u8, external.source_name, "CloseHandle")) .close_handle else if (std.mem.eql(u8, external.source_name, "TerminateProcess")) .terminate_process else if (std.mem.eql(u8, external.source_name, "GetExitCodeProcess")) .get_exit_code_process else if (std.mem.eql(u8, external.source_name, "CreateThread")) .create_thread else .get_last_error;
                try emitWindowsImportCallArguments(allocator, bytes, import_sites, call.arguments, symbol);
            } else if (std.mem.eql(u8, external.provider, "Windows.kernel32") and call.arguments.len == 1) {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "QueryPerformanceCounter"))
                    .query_performance_counter
                else if (std.mem.eql(u8, external.source_name, "QueryPerformanceFrequency"))
                    .query_performance_frequency
                else if (std.mem.eql(u8, external.source_name, "GetSystemTimeAsFileTime"))
                    .get_system_time_as_file_time
                else if (std.mem.eql(u8, external.source_name, "GetStdHandle"))
                    .get_std_handle
                else if (std.mem.eql(u8, external.source_name, "SetConsoleCP"))
                    .set_console_cp
                else if (std.mem.eql(u8, external.source_name, "SetCurrentDirectoryW"))
                    .set_current_directory_w
                else if (std.mem.eql(u8, external.source_name, "FreeEnvironmentStringsW"))
                    .free_environment_strings_w
                else if (std.mem.eql(u8, external.source_name, "FindClose"))
                    .find_close
                else if (std.mem.eql(u8, external.source_name, "DeleteFileW"))
                    .delete_file_w
                else if (std.mem.eql(u8, external.source_name, "RemoveDirectoryW"))
                    .remove_directory_w
                else
                    return unsupported("Windows external boundary");
                try emitWindowsImportCall(allocator, bytes, import_sites, symbol);
            } else if (std.mem.eql(u8, external.provider, "Windows.kernel32") and call.arguments.len == 2 and
                std.mem.eql(u8, external.source_name, "GetConsoleScreenBufferInfo"))
            {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                try emitWindowsImportCall(allocator, bytes, import_sites, .get_console_screen_buffer_info);
            } else if (std.mem.eql(u8, external.provider, "Windows.kernel32") and call.arguments.len == 2) {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "GetConsoleMode"))
                    .get_console_mode
                else if (std.mem.eql(u8, external.source_name, "SetConsoleMode"))
                    .set_console_mode
                else if (std.mem.eql(u8, external.source_name, "WaitForSingleObject"))
                    .wait_for_single_object
                else if (std.mem.eql(u8, external.source_name, "GetCurrentDirectoryW"))
                    .get_current_directory_w
                else if (std.mem.eql(u8, external.source_name, "SetEnvironmentVariableW"))
                    .set_environment_variable_w
                else if (std.mem.eql(u8, external.source_name, "FindFirstFileW"))
                    .find_first_file_w
                else if (std.mem.eql(u8, external.source_name, "FindNextFileW"))
                    .find_next_file_w
                else if (std.mem.eql(u8, external.source_name, "CreateDirectoryW"))
                    .create_directory_w
                else if (std.mem.eql(u8, external.source_name, "SetFileAttributesW"))
                    .set_file_attributes_w
                else
                    return unsupported("Windows external boundary");
                try emitWindowsImportCall(allocator, bytes, import_sites, symbol);
            } else if (std.mem.eql(u8, external.provider, "Windows.kernel32") and call.arguments.len == 3) {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .r8, call.arguments[2]);
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "GetModuleFileNameW"))
                    .get_module_file_name_w
                else if (std.mem.eql(u8, external.source_name, "GetEnvironmentVariableW"))
                    .get_environment_variable_w
                else if (std.mem.eql(u8, external.source_name, "GetFileAttributesExW"))
                    .get_file_attributes_ex_w
                else if (std.mem.eql(u8, external.source_name, "MoveFileExW"))
                    .move_file_ex_w
                else if (std.mem.eql(u8, external.source_name, "CopyFileW"))
                    .copy_file_w
                else
                    return unsupported("Windows external boundary");
                try emitWindowsImportCall(allocator, bytes, import_sites, symbol);
            } else if (std.mem.eql(u8, external.provider, "Windows.kernel32") and call.arguments.len == 4 and
                std.mem.eql(u8, external.source_name, "GetFullPathNameW"))
            {
                try emitLoadStack(allocator, bytes, .rcx, call.arguments[0]);
                try emitLoadStack(allocator, bytes, .rdx, call.arguments[1]);
                try emitLoadStack(allocator, bytes, .r8, call.arguments[2]);
                try emitLoadStack(allocator, bytes, .r9, call.arguments[3]);
                try emitWindowsImportCall(allocator, bytes, import_sites, .get_full_path_name_w);
            } else if (std.mem.eql(u8, external.provider, "Windows.kernel32") and call.arguments.len == 0) {
                const symbol: WindowsImports.Symbol = if (std.mem.eql(u8, external.source_name, "GetConsoleCP"))
                    .get_console_cp
                else if (std.mem.eql(u8, external.source_name, "GetCurrentProcessId"))
                    .get_current_process_id
                else if (std.mem.eql(u8, external.source_name, "GetEnvironmentStringsW"))
                    .get_environment_strings_w
                else
                    return unsupported("Windows external boundary");
                try emitWindowsImportCall(allocator, bytes, import_sites, symbol);
            } else return unsupported("Windows external boundary");
        },
    }
    if (call.result) |result| try emitStoreStack(allocator, bytes, .rax, result);
    _ = function;
}

const linux_thread_stack_size: u64 = 1024 * 1024;

fn emitLinuxThreadSpawn(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    arguments: []const Machine.Slot,
) Error!void {
    if (arguments.len != 2) return error.InvalidMachineProgram;

    // Allocate a private stack. The returned base also stores the kernel-managed
    // child TID used by thread_join's futex wait.
    try emitImmediate(allocator, bytes, .rdi, 0);
    try emitImmediate(allocator, bytes, .rsi, linux_thread_stack_size);
    try emitImmediate(allocator, bytes, .rdx, 3);
    try emitImmediate(allocator, bytes, .r10, 0x20022);
    try emitImmediate(allocator, bytes, .r8, std.math.maxInt(u64));
    try emitImmediate(allocator, bytes, .r9, 0);
    try emitImmediate(allocator, bytes, .rax, 9);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0x48, 0x85, 0xc0, 0x0f, 0x88 });
    const mmap_failed = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    // r10 keeps the mapping base; the top two words carry the entry and context
    // into the child without depending on the parent's frame after clone.
    try bytes.appendSlice(allocator, &.{ 0x49, 0x89, 0xc2, 0x48, 0x89, 0xc6, 0x48, 0x81, 0xc6 });
    try appendInt(allocator, bytes, u32, linux_thread_stack_size - 16);
    try emitLoadStack(allocator, bytes, .rcx, arguments[0]);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x0e });
    try emitLoadStack(allocator, bytes, .rcx, arguments[1]);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x4e, 0x08 });

    // clone(CLONE_VM | CLONE_FS | CLONE_FILES | CLONE_SIGHAND |
    //       CLONE_THREAD | CLONE_SYSVSEM | CLONE_PARENT_SETTID |
    //       CLONE_CHILD_CLEARTID | CLONE_CHILD_SETTID,
    //       stack_top, stack_base, stack_base, null)
    try emitImmediate(allocator, bytes, .rdi, 0x01350f00);
    try bytes.appendSlice(allocator, &.{ 0x4c, 0x89, 0xd2 });
    // mov r10 is already the child_tid pointer.
    try emitImmediate(allocator, bytes, .r8, 0);
    try emitImmediate(allocator, bytes, .rax, 56);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0x48, 0x85, 0xc0, 0x0f, 0x88 });
    const clone_failed = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x84 });
    const child_branch = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    // Parent result: the mapping base is the opaque join handle.
    try bytes.appendSlice(allocator, &.{ 0x4c, 0x89, 0xd0, 0xe9 });
    const parent_finished = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);

    const child = bytes.items.len;
    try patchRelative(bytes.items, child_branch, child);
    try bytes.appendSlice(allocator, &.{
        0x48, 0x8b, 0x04, 0x24, // mov rax, [rsp]
        0x48, 0x8b, 0x7c, 0x24, 0x08, // mov rdi, [rsp+8]
        0xff, 0xd0, // call rax
        0x31, 0xff, // xor edi, edi
    });
    try emitImmediate(allocator, bytes, .rax, 60);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });

    const clone_cleanup = bytes.items.len;
    try patchRelative(bytes.items, clone_failed, clone_cleanup);
    try bytes.appendSlice(allocator, &.{ 0x4c, 0x89, 0xd7 });
    try emitImmediate(allocator, bytes, .rsi, linux_thread_stack_size);
    try emitImmediate(allocator, bytes, .rax, 11);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });

    const failed = bytes.items.len;
    try patchRelative(bytes.items, mmap_failed, failed);
    try bytes.appendSlice(allocator, &.{ 0x31, 0xc0 });

    const finished = bytes.items.len;
    try patchRelative(bytes.items, parent_finished, finished);
}

fn emitLinuxThreadJoin(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    thread: Machine.Slot,
) Error!void {
    const wait = bytes.items.len;
    try emitLoadStack(allocator, bytes, .rdi, thread);
    try bytes.appendSlice(allocator, &.{ 0x8b, 0x17, 0x85, 0xd2, 0x0f, 0x84 });
    const complete = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try emitImmediate(allocator, bytes, .rsi, 128); // FUTEX_WAIT_PRIVATE
    try emitImmediate(allocator, bytes, .r10, 0);
    try emitImmediate(allocator, bytes, .r8, 0);
    try emitImmediate(allocator, bytes, .r9, 0);
    try emitImmediate(allocator, bytes, .rax, 202);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05, 0xe9 });
    const repeat = bytes.items.len;
    try bytes.appendNTimes(allocator, 0, 4);
    try patchRelative(bytes.items, repeat, wait);

    try patchRelative(bytes.items, complete, bytes.items.len);
    try emitLoadStack(allocator, bytes, .rdi, thread);
    try emitImmediate(allocator, bytes, .rsi, linux_thread_stack_size);
    try emitImmediate(allocator, bytes, .rax, 11);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x05 });
    try emitImmediate(allocator, bytes, .rax, 1);
}

fn emitBoundaryCall(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    sites: *std.ArrayList(Site),
    platform: Platform,
    external: Machine.ExternalFunction,
    call: Machine.Instruction.ExternalCall,
) Error!void {
    if (external.signature.arguments.len != call.arguments.len or call.arguments.len > Machine.max_external_arguments) {
        return error.InvalidMachineProgram;
    }
    switch (platform) {
        .linux => try emitLinuxBoundaryArguments(allocator, bytes, external.signature.arguments, call.arguments),
        .windows => try emitWindowsBoundaryArguments(allocator, bytes, external.signature.arguments, call.arguments),
    }
    try bytes.append(allocator, 0xe8);
    const displacement_offset: u32 = @intCast(bytes.items.len);
    try bytes.appendNTimes(allocator, 0, 4);
    try sites.append(allocator, .{ .displacement_offset = displacement_offset, .function = call.function });
    const stack_size = boundaryStackSize(platform, external.signature.arguments);
    if (stack_size != 0) try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc4, stack_size });
    if (call.result) |result| {
        if (external.signature.result) |kind| {
            if (kind == .float32) {
                try bytes.appendSlice(allocator, &.{ 0x66, 0x0f, 0x7e, 0xc0 });
            } else if (kind == .float64) {
                try bytes.appendSlice(allocator, &.{ 0x66, 0x48, 0x0f, 0x7e, 0xc0 });
            }
        }
        try emitStoreStack(allocator, bytes, .rax, result);
    }
}

fn emitLinuxBoundaryArguments(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    kinds: []const Machine.AbiValue,
    arguments: []const Machine.Slot,
) Allocator.Error!void {
    const stack_size = boundaryStackSize(.linux, kinds);
    if (stack_size != 0) try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xec, stack_size });
    const integer_registers = [_]Register{ .rdi, .rsi, .rdx, .rcx, .r8, .r9 };
    var integer_index: usize = 0;
    var float_index: usize = 0;
    var stack_index: usize = 0;
    for (arguments, kinds) |argument, kind| {
        if (isFloat(kind)) {
            if (float_index < 8) {
                try emitLoadFloatStack(allocator, bytes, @intCast(float_index), argument, kind == .float64);
                float_index += 1;
            } else {
                try emitLoadStack(allocator, bytes, .rax, argument);
                try emitStoreRsp(allocator, bytes, .rax, @intCast(stack_index * 8));
                stack_index += 1;
            }
        } else if (integer_index < integer_registers.len) {
            try emitLoadStack(allocator, bytes, integer_registers[integer_index], argument);
            integer_index += 1;
        } else {
            try emitLoadStack(allocator, bytes, .rax, argument);
            try emitStoreRsp(allocator, bytes, .rax, @intCast(stack_index * 8));
            stack_index += 1;
        }
    }
}

fn emitWindowsBoundaryArguments(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    kinds: []const Machine.AbiValue,
    arguments: []const Machine.Slot,
) Allocator.Error!void {
    const stack_size = boundaryStackSize(.windows, kinds);
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xec, stack_size });
    const registers = [_]Register{ .rcx, .rdx, .r8, .r9 };
    for (arguments, kinds, 0..) |argument, kind, index| {
        if (index < 4) {
            if (isFloat(kind)) {
                try emitLoadFloatStack(allocator, bytes, @intCast(index), argument, kind == .float64);
            } else try emitLoadStack(allocator, bytes, registers[index], argument);
        } else {
            try emitLoadStack(allocator, bytes, .rax, argument);
            try emitStoreRsp(allocator, bytes, .rax, @intCast(32 + (index - 4) * 8));
        }
    }
}

fn boundaryStackSize(platform: Platform, kinds: []const Machine.AbiValue) u8 {
    var count: usize = 0;
    switch (platform) {
        .linux => {
            var integers: usize = 0;
            var floats: usize = 0;
            for (kinds) |kind| if (isFloat(kind)) {
                if (floats >= 8) count += 1;
                floats += 1;
            } else {
                if (integers >= 6) count += 1;
                integers += 1;
            };
            return @intCast(std.mem.alignForward(usize, count * 8, 16));
        },
        .windows => return @intCast(std.mem.alignForward(usize, 32 + @max(kinds.len, 4) * 8 - 32, 16)),
    }
}

fn isFloat(kind: Machine.AbiValue) bool {
    return kind == .float32 or kind == .float64;
}

fn emitLoadFloatStack(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    register: u3,
    slot: Machine.Slot,
    double: bool,
) Allocator.Error!void {
    try bytes.append(allocator, if (double) 0xf2 else 0xf3);
    try bytes.appendSlice(allocator, &.{ 0x0f, 0x10, 0x85 | (@as(u8, register) << 3) });
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitStoreRsp(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, offset: u8) Allocator.Error!void {
    const rex: u8 = 0x48 | (if (@intFromEnum(register) >= 8) @as(u8, 4) else 0);
    try bytes.appendSlice(allocator, &.{ rex, 0x89, 0x44 | ((@as(u8, @intFromEnum(register)) & 7) << 3), 0x24, offset });
}

pub fn emitWindowsImportCall(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    sites: *std.ArrayList(WindowsImports.X64Site),
    symbol: WindowsImports.Symbol,
) Allocator.Error!void {
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xec, 32, 0xff, 0x15 });
    const displacement_offset: u32 = @intCast(bytes.items.len);
    try bytes.appendNTimes(allocator, 0, 4);
    try sites.append(allocator, .{ .displacement_offset = displacement_offset, .symbol = symbol });
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc4, 32 });
}

fn emitWindowsImportCallArguments(
    allocator: Allocator,
    bytes: *std.ArrayList(u8),
    sites: *std.ArrayList(WindowsImports.X64Site),
    arguments: []const Machine.Slot,
    symbol: WindowsImports.Symbol,
) Error!void {
    if (arguments.len > Machine.max_external_arguments) return unsupported("Windows call with too many arguments");
    const reservation: u8 = if (arguments.len > 4)
        @intCast(std.mem.alignForward(usize, 32 + (arguments.len - 4) * 8, 16))
    else
        32;
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xec, reservation });
    const registers = [_]Register{ .rcx, .rdx, .r8, .r9 };
    for (arguments[0..@min(arguments.len, 4)], registers[0..@min(arguments.len, 4)]) |argument, register| {
        try emitLoadStack(allocator, bytes, register, argument);
    }
    if (arguments.len > 4) for (arguments[4..], 0..) |argument, index| {
        try emitLoadStack(allocator, bytes, .rax, argument);
        try bytes.appendSlice(allocator, &.{ 0x48, 0x89, 0x44, 0x24, @intCast(32 + index * 8) });
    };
    try bytes.appendSlice(allocator, &.{ 0xff, 0x15 });
    const displacement_offset: u32 = @intCast(bytes.items.len);
    try bytes.appendNTimes(allocator, 0, 4);
    try sites.append(allocator, .{ .displacement_offset = displacement_offset, .symbol = symbol });
    try bytes.appendSlice(allocator, &.{ 0x48, 0x83, 0xc4, reservation });
}

fn emitLoadStack(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, slot: Machine.Slot) Allocator.Error!void {
    try emitRex(allocator, bytes, true, register);
    try bytes.append(allocator, 0x8b);
    try bytes.append(allocator, 0x85 | (@as(u8, @intFromEnum(register) & 7) << 3));
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitStoreStack(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, slot: Machine.Slot) Allocator.Error!void {
    try emitRex(allocator, bytes, true, register);
    try bytes.append(allocator, 0x89);
    try bytes.append(allocator, 0x85 | (@as(u8, @intFromEnum(register) & 7) << 3));
    try appendInt(allocator, bytes, i32, slotDisplacement(slot));
}

fn emitImmediate(allocator: Allocator, bytes: *std.ArrayList(u8), register: Register, value: u64) Allocator.Error!void {
    try bytes.append(allocator, 0x48 | @as(u8, @intFromBool(@intFromEnum(register) >= 8)));
    try bytes.append(allocator, 0xb8 + (@as(u8, @intFromEnum(register)) & 7));
    try appendInt(allocator, bytes, u64, value);
}

fn emitMoveRegister(allocator: Allocator, bytes: *std.ArrayList(u8), destination: Register, source: Register) Allocator.Error!void {
    const rex: u8 = 0x48 | (if (@intFromEnum(source) >= 8) @as(u8, 4) else 0) | (if (@intFromEnum(destination) >= 8) @as(u8, 1) else 0);
    try bytes.appendSlice(allocator, &.{ rex, 0x89, 0xc0 | ((@as(u8, @intFromEnum(source)) & 7) << 3) | (@as(u8, @intFromEnum(destination)) & 7) });
}

fn emitRex(allocator: Allocator, bytes: *std.ArrayList(u8), wide: bool, register: Register) Allocator.Error!void {
    try bytes.append(allocator, 0x40 | (if (wide) @as(u8, 8) else 0) | (if (@intFromEnum(register) >= 8) @as(u8, 4) else 0));
}

fn slotDisplacement(slot: Machine.Slot) i32 {
    return -@as(i32, @intCast((@as(usize, slot) + 1) * Machine.slot_size));
}

fn patchRelative(bytes: []u8, displacement_at: usize, target: anytype) error{InvalidMachineProgram}!void {
    if (displacement_at + 4 > bytes.len) return error.InvalidMachineProgram;
    const origin: i64 = @intCast(displacement_at + 4);
    const destination: i64 = @intCast(target);
    std.mem.writeInt(i32, bytes[displacement_at..][0..4], @intCast(destination - origin), .little);
}

fn appendInt(allocator: Allocator, bytes: *std.ArrayList(u8), comptime T: type, value: anytype) Allocator.Error!void {
    var storage: [@sizeOf(T)]u8 = undefined;
    std.mem.writeInt(T, &storage, @as(T, @intCast(value)), .little);
    try bytes.appendSlice(allocator, &storage);
}

fn unsupported(reason: []const u8) error{UnsupportedInstruction} {
    std.debug.print("x64 unsupported: {s}\n", .{reason});
    return error.UnsupportedInstruction;
}

test "encode syscall immediates in extended registers" {
    var bytes: std.ArrayList(u8) = .empty;
    defer bytes.deinit(std.testing.allocator);
    try emitImmediate(std.testing.allocator, &bytes, .r9, 4);
    try std.testing.expectEqualSlices(u8, &.{ 0x49, 0xb9, 4, 0, 0, 0, 0, 0, 0, 0 }, bytes.items);
}
