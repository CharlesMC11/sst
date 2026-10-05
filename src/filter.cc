#include "filter.hh"

#include <unistd.h>

#include <cstdint>

constexpr std::int64_t kAlignment{16L};

/**
 * Check if a given array of bytes matches an image's magic pattern
 *
 * @param buffer
 * The bytes to check
 *
 * @returns
 * `true` if `buffer` contains magic bytes from common image formats
 */
extern "C" [[nodiscard]] bool has_image_signature(
        const std::uint8_t buffer[]) noexcept;

[[nodiscard]] bool sst::filter::is_image(const int fd) noexcept
{
    alignas(kAlignment) std::uint8_t buffer[kAlignment];

    // TODO: Handle failed reads
    return read(fd, buffer, sizeof(buffer)) >= kAlignment &&
            has_image_signature(buffer);
}
