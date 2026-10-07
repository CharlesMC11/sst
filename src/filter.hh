#pragma once

namespace sst::filter {

    /**
     * Check if a given file is an image
     *
     * @param fd
     * The file descriptor
     *
     * @param max_retries
     * The number of attempts to make if an I/O problem is encountered
     *
     * @return
     * `true` if the file is an image; `false` otherwise
     */
    [[nodiscard]] bool is_image(int fd, unsigned max_retries) noexcept;

} // namespace sst::filter
