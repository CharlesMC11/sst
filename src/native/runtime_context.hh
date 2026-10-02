#ifndef SST__RUNTIME_CONTEXT__HH
#define SST__RUNTIME_CONTEXT__HH

#include "file_monitor.hh"

namespace sst::runtime {

    struct context final {
        const dispatch_queue_t queue;
        const CFMutableArrayRef buffer;
        const filesystem::monitor& monitor;
    };

} // namespace sst::runtime

#endif // SST__RUNTIME_CONTEXT__HH
