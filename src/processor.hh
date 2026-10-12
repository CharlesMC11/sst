#pragma once

#include <sys/types.h>
#include <sys/uio.h>

#include <cstddef>
#include <string_view>

#include "exiftool_args.hh"

namespace sst {

    /**
     * Manages the lifecycle of an ExifTool subprocess
     *
     */
    class processor final {
    public:
        explicit processor(
                const exiftool_args& args, unsigned max_retries = 5U);

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
        [[nodiscard]] bool send_to_exiftool(std::string_view file_paths) const;

        [[nodiscard]] bool shutdown() noexcept;

    private:
        static constexpr ::iovec kExecuteCmd{
                .iov_base = const_cast<char*>("-execute\n"), .iov_len = 9UZ};

        static constexpr ::iovec kShutdownCmd[2UZ]{
                {.iov_base = const_cast<char*>("-stay_open\nFalse\n"),
                        .iov_len = 17UZ},
                kExecuteCmd};

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

        pipe stdout_pipe_;
        ::pid_t pid_{-1};
        unsigned max_retries_;

        [[nodiscard]] bool send_payload(const ::iovec[]) const noexcept;
    };

} // namespace sst
