#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

#if defined(_WIN32)
#include <direct.h>
#else
#include <unistd.h>
#endif

int main(int count, char** values) {
    if (count < 2) return 90;
    const std::string mode = values[1];
    if (mode == "exit") return 23;
    if (mode == "signal") {
#if defined(_WIN32)
        return 23;
#else
        std::raise(SIGTERM);
        return 91;
#endif
    }
    if (count != 5 || std::string(values[2]) != "space value" ||
        std::string(values[3]) != "" || std::string(values[4]) != "été") return 92;
    char directory[4096]{};
#if defined(_WIN32)
    if (_getcwd(directory, sizeof(directory)) == nullptr) return 95;
#else
    if (getcwd(directory, sizeof(directory)) == nullptr) return 95;
#endif
    const std::string current(directory);
    if (current.size() < 6 || current.substr(current.size() - 6) != ".silex") return 96;
    const char* added = std::getenv("SILEX_SUBPROCESS_ADDED");
    if (added == nullptr || std::string(added) != "yes" ||
        std::getenv("SILEX_SUBPROCESS_REMOVED") != nullptr) return 93;
    unsigned char input[3]{};
    if (std::fread(input, 1, sizeof(input), stdin) != sizeof(input) ||
        input[0] != 0 || input[1] != 1 || input[2] != 2) return 94;
    for (int index = 0; index < 70000; ++index) {
        std::fputc('O', stdout);
        std::fputc('E', stderr);
    }
    return 0;
}
