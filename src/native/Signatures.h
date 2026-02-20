#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
namespace sst::signatures {
extern "C" {
#endif

bool is_image(uint8_t buffer[]);

#ifdef __cplusplus
}  // extern "C"
}  // namespace sst::signatures
#endif
