#ifndef SST__CONTEXT
#define SST__CONTEXT

#include "file_monitor.hh"

namespace sst::runtime {

struct context final {
  const dispatch_queue_t queue;
  const CFMutableArrayRef buffer;
  const filesystem::monitor& monitor;
};

}  // namespace sst::runtime

#endif  // SST__CONTEXT
