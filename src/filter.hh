#pragma once

namespace sst::filter {

    /**
     * Check if a given file is an image
     *
     * @param fd
     * The file descriptor
     *
     * @param max_retries
     * The number of retries to make if an I/O problem occurs
     *
     * @return
     * `true` if the file is an image; `false` otherwise
     */
    extern "C" [[nodiscard]] bool is_image(
            int fd, unsigned max_retries = 5U) noexcept;

} // namespace sst::filter
