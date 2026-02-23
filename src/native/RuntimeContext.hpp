#pragma once

#include "FileMonitor.hpp"

namespace sst::runtime {

struct Context {
  const dispatch_queue_t queue;
  const CFMutableArrayRef buffer;
  const filesystem::Monitor &monitor;
};

} // namespace sst::runtime
