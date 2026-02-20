#pragma once

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
namespace sst::signatures {
extern "C" {
#endif

/*!
 * Check if a given array of bytes matches an image's magic pattern
 *
 * @param buffer
 * The bytes to check
 *
 * @returns
 * `true` if `buffer` contains magic bytes from common image formats
 */
bool is_image(uint8_t buffer[]);

#ifdef __cplusplus
}  // extern "C"
}  // namespace sst::signatures
#endif
