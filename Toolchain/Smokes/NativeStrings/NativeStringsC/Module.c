#include <stdint.h>
#include <stdlib.h>
#include <string.h>

void silexNative_NativeStringsC_native_copy(
    const char* value_bytes,
    int64_t value_length,
    char** output_bytes,
    int64_t* output_length
) {
    if (value_length == 0) {
        *output_bytes = NULL;
        *output_length = 0;
        return;
    }

    *output_bytes = malloc((size_t)value_length);
    if (*output_bytes != NULL) {
        memcpy(*output_bytes, value_bytes, (size_t)value_length);
    }
    *output_length = value_length;
}
