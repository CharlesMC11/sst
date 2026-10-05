#pragma once

namespace sst::filter {

    /**
     * Check if a given file is an image
     *
     * @param fd
     * The file descriptor
     *
     * @return
     * `true` if the file is an image; `false` otherwise
     */
    [[nodiscard]] bool is_image(int fd) noexcept;

} // namespace sst::filter
