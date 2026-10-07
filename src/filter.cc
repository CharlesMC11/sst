#include "filter.hh"

#include <unistd.h>

#include <cerrno>
#include <cstddef>
#include <cstdint>

static inline constexpr std::ptrdiff_t kAlignment{16Z};

/**
 * Check if a given array of bytes matches an image’s magic pattern
 *
 * @param buffer
 * The bytes to check
 *
 * @returns
 * `true` if `buffer` contains magic bytes from common image formats
 */
extern "C" [[nodiscard]] bool has_image_signature(
        const std::uint8_t buffer[]) noexcept;

[[nodiscard]] bool sst::filter::is_image(
        const int fd, const unsigned max_retries) noexcept
{
    alignas(kAlignment) std::uint8_t buffer[kAlignment];

    unsigned retries{0U};
    while (retries <= max_retries) {
        const std::ptrdiff_t bytes_read{::read(fd, buffer, sizeof(buffer))};

        if (bytes_read >= kAlignment) [[likely]] {
            return has_image_signature(buffer);
        }
        if (bytes_read < 0Z && errno == EINTR) [[unlikely]] {
            continue;
        }
        ::lseek(fd, 0Z, SEEK_SET);
        ++retries;
    }

    return false;
}
