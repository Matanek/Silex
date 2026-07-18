#include <cstdint>
#include <csignal>
#include <cstdio>
#include <stdexcept>
#include <string>

#if defined(_WIN32)
#include <windows.h>
#else
#include <cerrno>
#include <sys/ioctl.h>
#include <unistd.h>
#endif

namespace {

// -----------------------------------------------------------------------------

[[noreturn]] void fail(const char* operation, const char* detail) {
    throw std::runtime_error(std::string{"Console."} + operation + " failed: " + detail);
}

// -----------------------------------------------------------------------------

#if defined(_WIN32)

HANDLE handle(bool errorOutput) {
    const auto value = GetStdHandle(errorOutput ? STD_ERROR_HANDLE : STD_OUTPUT_HANDLE);
    if (value == nullptr || value == INVALID_HANDLE_VALUE) fail(errorOutput ? "write_error" : "write", "standard handle is unavailable");
    return value;
}

bool interactive() {
    DWORD mode = 0;
    return GetConsoleMode(handle(false), &mode) != 0;
}

bool ansi() {
    const auto output = handle(false);
    DWORD mode = 0;
    if (GetConsoleMode(output, &mode) == 0) return false;
    return (mode & ENABLE_VIRTUAL_TERMINAL_PROCESSING) != 0 ||
        SetConsoleMode(output, mode | ENABLE_VIRTUAL_TERMINAL_PROCESSING) != 0;
}

void writeAll(bool errorOutput, const char* bytes, std::int64_t length, const char* operation) {
    const auto output = handle(errorOutput);
    std::size_t offset = 0;
    const auto size = static_cast<std::size_t>(length);
    while (offset < size) {
        const auto remaining = size - offset;
        const auto chunk = static_cast<DWORD>(remaining > 0xffffffffu ? 0xffffffffu : remaining);
        DWORD written = 0;
        if (WriteFile(output, bytes + offset, chunk, &written, nullptr) == 0 || written == 0) fail(operation, "unable to write");
        offset += written;
    }
}

std::int64_t dimension(bool columns) {
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (GetConsoleScreenBufferInfo(handle(false), &info) == 0) return 0;
    return columns
        ? static_cast<std::int64_t>(info.srWindow.Right - info.srWindow.Left + 1)
        : static_cast<std::int64_t>(info.srWindow.Bottom - info.srWindow.Top + 1);
}

constexpr const char* k_lineEnding = "\r\n";

#else

bool interactive() {
    return isatty(STDOUT_FILENO) == 1;
}

bool ansi() {
    return interactive();
}

void writeAll(bool errorOutput, const char* bytes, std::int64_t length, const char* operation) {
    std::signal(SIGPIPE, SIG_IGN);
    const int output = errorOutput ? STDERR_FILENO : STDOUT_FILENO;
    std::size_t offset = 0;
    const auto size = static_cast<std::size_t>(length);
    while (offset < size) {
        const auto written = write(output, bytes + offset, size - offset);
        if (written > 0) {
            offset += static_cast<std::size_t>(written);
            continue;
        }
        if (written < 0 && errno == EINTR) continue;
        fail(operation, "unable to write");
    }
}

std::int64_t dimension(bool columns) {
    winsize size {};
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) != 0) return 0;
    return columns ? size.ws_col : size.ws_row;
}

constexpr const char* k_lineEnding = "\n";

#endif

// -----------------------------------------------------------------------------

void line(bool errorOutput, const char* bytes, std::int64_t length, const char* operation) {
    writeAll(errorOutput, bytes, length, operation);
    writeAll(errorOutput, k_lineEnding, std::char_traits<char>::length(k_lineEnding), operation);
}

void control(const std::string& value, const char* operation) {
    if (!ansi()) return;
    writeAll(false, value.data(), static_cast<std::int64_t>(value.size()), operation);
}

void flush() {
    if (std::fflush(stdout) != 0 || std::fflush(stderr) != 0) fail("flush", "unable to flush");
}

// -----------------------------------------------------------------------------

} // namespace

extern "C" void silexNative_STD_Console_native_write(const char* text, std::int64_t length) {
    writeAll(false, text, length, "write");
}

extern "C" void silexNative_STD_Console_native_write_line(const char* text, std::int64_t length) {
    line(false, text, length, "write_line");
}

extern "C" void silexNative_STD_Console_native_write_error(const char* text, std::int64_t length) {
    writeAll(true, text, length, "write_error");
}

extern "C" void silexNative_STD_Console_native_write_error_line(const char* text, std::int64_t length) {
    line(true, text, length, "write_error_line");
}

extern "C" void silexNative_STD_Console_native_flush() {
    flush();
}

extern "C" bool silexNative_STD_Console_native_is_interactive() {
    return interactive();
}

extern "C" std::int64_t silexNative_STD_Console_native_columns() {
    return interactive() ? dimension(true) : 0;
}

extern "C" std::int64_t silexNative_STD_Console_native_rows() {
    return interactive() ? dimension(false) : 0;
}

extern "C" void silexNative_STD_Console_native_clear_screen() {
    control("\x1b[2J\x1b[H", "clear_screen");
}

extern "C" void silexNative_STD_Console_native_clear_line() {
    control("\x1b[2K\x1b[1G", "clear_line");
}

extern "C" void silexNative_STD_Console_native_move_cursor(std::int64_t column, std::int64_t row) {
    control("\x1b[" + std::to_string(static_cast<std::uint64_t>(row) + 1) + ";" + std::to_string(static_cast<std::uint64_t>(column) + 1) + "H", "move_cursor");
}

extern "C" void silexNative_STD_Console_native_show_cursor() {
    control("\x1b[?25h", "show_cursor");
}

extern "C" void silexNative_STD_Console_native_hide_cursor() {
    control("\x1b[?25l", "hide_cursor");
}

extern "C" void silexNative_STD_Console_native_set_foreground(std::int64_t code) {
    control("\x1b[" + std::to_string(code) + "m", "set_foreground");
}

extern "C" void silexNative_STD_Console_native_set_background(std::int64_t code) {
    control("\x1b[" + std::to_string(code) + "m", "set_background");
}

extern "C" void silexNative_STD_Console_native_enable_style(std::int64_t code) {
    control("\x1b[" + std::to_string(code) + "m", "enable_style");
}

extern "C" void silexNative_STD_Console_native_reset_style() {
    control("\x1b[0m", "reset_style");
}
