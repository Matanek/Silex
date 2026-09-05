#include <stdint.h>

int64_t silex_boundary_integer_sum(
    int64_t a,
    int64_t b,
    int64_t c,
    int64_t d,
    int64_t e,
    int64_t f,
    int64_t g,
    int64_t h,
    int64_t i,
    int64_t j
) {
    return a + b + c + d + e + f + g + h + i + j;
}

double silex_boundary_float(int64_t value) {
    return (double)value;
}

int64_t silex_boundary_call(uintptr_t callback, int64_t value) {
    int64_t (*function)(int64_t) = (int64_t (*)(int64_t))callback;
    return function(value);
}

double silex_boundary_float_sum(
    double a,
    double b,
    double c,
    double d,
    double e,
    double f,
    double g,
    double h,
    double i,
    double j
) {
    return a + b + c + d + e + f + g + h + i + j;
}
