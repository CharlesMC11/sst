#pragma once

#include <CoreServices/CoreServices.h>
#include <dispatch/dispatch.h>

#include "memory.hh"

namespace sst {

    class orchestrator;

    class stream_context final {
    public:
        explicit stream_context(orchestrator& orchestrator,
                ::dispatch_queue_t queue, CFTimeInterval latency = 0.25);

        ~stream_context() noexcept;

        stream_context(const stream_context&) = delete;
        stream_context(stream_context&&) = delete;

        auto operator=(const stream_context&) -> stream_context& = delete;
        auto operator=(stream_context&&) -> stream_context& = delete;

        void shutdown() noexcept;

    private:
        sst::memory::cf_ptr<::FSEventStreamRef> stream_{nullptr};
    };

} // namespace sst
