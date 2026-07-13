#include <cstdio>

namespace {

struct SmokeHook {
    SmokeHook() {
        std::puts("Native wrapper initialized");
    }
};

SmokeHook hook;

}
