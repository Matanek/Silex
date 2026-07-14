#include "Runtime.hpp"

#include <stdio.h>

__attribute__((constructor)) static void announce_native_runtime(void) {
    puts(SILEX_NATIVE_RUNTIME_MESSAGE);
}
