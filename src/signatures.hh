#ifndef SST__SIGNATURES__H
#define SST__SIGNATURES__H

#include <fcntl.h>
#include <unistd.h>

#include <cstdint>

namespace sst::inspector {

    inline constexpr std::int64_t kAlignment{16L};

    /**
     * Check if a given array of bytes matches an image's magic pattern
     *
     * @param buffer
     * The bytes to check
     *
     * @returns
     * `true` if `buffer` contains magic bytes from common image formats
     */
    extern "C" bool has_image_signature(const std::uint8_t buffer[]) noexcept;

    [[nodiscard]] inline bool is_image(int fd)
    {
        alignas(kAlignment) std::uint8_t buffer[kAlignment];

        // TODO: Handle failed reads
        return read(fd, buffer, sizeof(buffer)) >= kAlignment &&
                has_image_signature(buffer);
    }

} // namespace sst::inspector

#endif // SST__SIGNATURES__H
