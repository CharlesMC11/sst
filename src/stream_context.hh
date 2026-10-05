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
        [[nodiscard]] explicit stream_context(::FSEventStreamCallback callback,
                ::dispatch_queue_t queue, sst::processor& processor,
                const char directory[], CFTimeInterval latency = 0.25);

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

        [[nodiscard]] auto processor() const noexcept -> const sst::processor&
        {
            return processor_;
        }

    private:
        const sst::processor& processor_;
        const char* const dir_path_{nullptr};
        int dir_fd_{-1};
        sst::memory::CFPtr<::FSEventStreamRef> stream_{nullptr};
        std::vector<std::string> buffer_;
    };

} // namespace sst
