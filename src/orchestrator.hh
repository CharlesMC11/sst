#pragma once

#include <CoreServices/CoreServices.h>
#include <fcntl.h>

#include <cstddef>
#include <string>

namespace sst {

    constexpr unsigned kIOFlags{O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_CLOFORK};

    class processor;

    class orchestrator final {
    public:
        static void run(::ConstFSEventStreamRef stream_ref,
                void* client_callback_info, std::size_t num_events,
                void* event_paths,
                const ::FSEventStreamEventFlags event_flags[],
                const ::FSEventStreamEventId event_ids[]);

        explicit orchestrator(processor& processor,
                std::string_view input_dir_path, int input_dir_fd,
                std::string& buffer, unsigned max_retries = 5U);

        [[nodiscard]] auto processor() const noexcept -> processor&
        {
            return processor_;
        }

        [[nodiscard]] auto input_dir_path() const noexcept -> std::string_view
        {
            return input_dir_path_;
        }

        [[nodiscard]] int input_dir_fd() const noexcept
        {
            return input_dir_fd_;
        }

        [[nodiscard]] auto buffer() const noexcept -> std::string&
        {
            return buffer_;
        }

        /**
         * Manually clean up a directory
         *
         * @returns
         * `true` if the function executed without any issues; `false`
         * otherwise
         */
        [[nodiscard]] bool cleanup() const noexcept;

    private:
        sst::processor& processor_;
        std::string_view input_dir_path_;
        int input_dir_fd_;
        unsigned max_retries_;
        std::string& buffer_;

        void inspect(const char* filename, std::size_t length) const noexcept;
    };

} // namespace sst
