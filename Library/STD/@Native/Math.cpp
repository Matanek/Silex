#include <cmath>
#include <SilexNative/STD.h>

extern "C" float silexNative_STD_Math_sqrt(float value) {
    return std::sqrt(value);
}

extern "C" float silexNative_STD_Math_sin(float value) {
    return std::sin(value);
}

extern "C" float silexNative_STD_Math_cos(float value) {
    return std::cos(value);
}

extern "C" float silexNative_STD_Math_tan(float value) {
    return std::tan(value);
}

extern "C" float silexNative_STD_Math_asin(float value) {
    return std::asin(value);
}

extern "C" float silexNative_STD_Math_atan2(float y, float x) {
    return std::atan2(y, x);
}
