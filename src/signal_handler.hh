#pragma once

#include <dispatch/dispatch.h>

namespace sst {

    class stream_context;

    namespace runtime {

        struct context final {
            ::dispatch_queue_t queue;
            const sst::stream_context& monitor;
        };

        void register_signal_handler(
                int sig, sst::runtime::context context) noexcept;

    } // namespace runtime

} // namespace sst
