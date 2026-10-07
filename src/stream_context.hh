#pragma once

#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>

#include <string>
#include <vector>

#include "memory.hh"

namespace sst {

    class processor;

    class stream_context final {
    public:
        explicit stream_context(::FSEventStreamCallback callback,
                ::dispatch_queue_t queue, sst::processor& processor,
                const char* input_dir, int input_dir_fd,
                CFTimeInterval latency = 0.25);

        ~stream_context() noexcept;

        stream_context(const stream_context&) = delete;
        stream_context(stream_context&&) = delete;

        auto operator=(const stream_context&) -> stream_context& = delete;
        auto operator=(stream_context&&) -> stream_context& = delete;

        [[nodiscard]] int dir_fd() const noexcept { return dir_fd_; }

        [[nodiscard]] auto buffer() noexcept -> std::vector<std::string>&
        {
            return buffer_;
        }

        [[nodiscard]] auto processor() const noexcept -> sst::processor&
        {
            return processor_;
        }

        void shutdown() noexcept;

    private:
        sst::processor& processor_;
        int dir_fd_{-1};
        sst::memory::cf_ptr<::FSEventStreamRef> stream_{nullptr};
        std::vector<std::string> buffer_;
    };

} // namespace sst
