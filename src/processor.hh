#pragma once

#include <sys/types.h>

#include <array>
#include <string>
#include <vector>

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
                unsigned max_retries = 5U);

        ~processor() noexcept;

        processor(const processor&) = delete;
        processor(processor&&) = delete;

        auto operator=(const processor&) -> processor& = delete;
        auto operator=(processor&&) -> processor& = delete;

        [[nodiscard]] constexpr bool is_running() const noexcept
        {
            return pid_ != -1;
        }

        /**
         * Send the filenames to ExifTool
         *
         * @param filenames
         * The relative filenames to send
         */
        [[nodiscard]] bool send_filenames(
                const std::vector<std::string>& filenames) const;

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

        const char* const input_dir_;
        sst::processor::pipe pipe_;
        ::pid_t pid_{-1};
        unsigned max_retries_;

        [[nodiscard]] bool send_payload(std::string_view args) const noexcept;
    };

} // namespace sst
