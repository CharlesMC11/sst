#pragma once

#include <sys/types.h>

#include <climits>
#include <cstddef>
#include <string>
#include <string_view>

#include "metadata.hh"

namespace sst {

    /**
     * Manages the lifecycle of an ExifTool subprocess
     *
     */
    class processor final {
    public:
        processor(const char* exiftool_path,
                const sst::image::metadata& metadata,
                unsigned max_retries = 5U,
                std::size_t init_buffer_size = PATH_MAX);

        ~processor() noexcept;

        processor(const processor&) = delete;
        processor(processor&&) = delete;

        auto operator=(const processor&) -> processor& = delete;
        auto operator=(processor&&) -> processor& = delete;

        [[nodiscard]] constexpr bool is_running() const noexcept
        {
            return pid_ != -1;
        }

        [[nodiscard]] constexpr unsigned max_retries() const noexcept
        {
            return max_retries_;
        }

        /**
         * Send a string of line feed-separated file paths to ExifTool
         *
         * @param file_paths
         * The absolute filenames to send
         */
        [[nodiscard]] bool send_to_exiftool(std::string_view file_paths);

        [[nodiscard]] bool shutdown() noexcept;

    private:
        class pipe final {
        public:
            int fds[2UZ]{-1, -1};

            [[nodiscard]] pipe();
            ~pipe() noexcept;

            pipe(const pipe&) = delete;
            pipe(pipe&&) = delete;

            auto operator=(const pipe&) -> pipe& = delete;
            auto operator=(pipe&&) -> pipe& = delete;

            void close(std::size_t idx) noexcept;
        };

        sst::processor::pipe pipe_;
        ::pid_t pid_{-1};
        unsigned max_retries_;
        std::string buffer_;

        [[nodiscard]] bool send_payload() const noexcept;
    };

} // namespace sst
