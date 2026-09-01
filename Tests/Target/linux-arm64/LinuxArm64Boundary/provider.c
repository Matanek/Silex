#include <stdint.h>

int32_t boundary_answer(void) {
    return 42;
}

int32_t boundary_sum_ten(
    int32_t a,
    int32_t b,
    int32_t c,
    int32_t d,
    int32_t e,
    int32_t f,
    int32_t g,
    int32_t h,
    int32_t i,
    int32_t j
) {
    return a + b + c + d + e + f + g + h + i + j;
}

double boundary_scale(double value) {
    return value * 2.0;
}

int32_t boundary_invoke(uintptr_t address, int32_t left, int32_t right) {
    int32_t (*callback)(int32_t, int32_t) = (int32_t (*)(int32_t, int32_t))address;
    return callback(left, right);
}
