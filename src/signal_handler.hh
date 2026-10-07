#pragma once

#include <dispatch/dispatch.h>

namespace sst::signals {

    void register_handler(int sig, dispatch_queue_t queue) noexcept;

} // namespace sst::signals
